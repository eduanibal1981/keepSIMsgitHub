-- ============================================================================
-- G3 — Gift / send wallet credit to another user
--
-- Feature suggestion #3 in doc/PRODUCTION_PLAN_REVIEW.md § 6. One RPC,
-- `transfer_wallet_credit(p_recipient_email, p_amount)`, moves money between
-- two KeepSIMs wallets in a single transaction, writing a `gift_sent` row on
-- the sender's ledger and a `gift_received` row on the recipient's, both
-- carrying the SAME reference_id so the two halves are joinable forever.
--
-- ── Three deliberate departures from the sketch in the review ───────────────
--
-- 1. THE CREDIT HALF IS INLINE, NOT `credit_wallet_for_refund`. The sketch says
--    "reusing the existing atomic helpers". The debit half does exactly that —
--    `debit_wallet_for_topup` carries F2's CALL-DEPTH guard, so a nested call
--    from here passes (this is the same thing `pay_plan_fee_from_wallet`
--    already does). The credit half cannot: F1 gave
--    `credit_wallet_for_refund` an ABSOLUTE guard that raises KS403 whenever
--    `request.jwt.claims` names any role other than service_role, at any call
--    depth. Probed on the live database before writing a line of this:
--
--      SELECT zz_probe_nested_credit(...)   -- SECURITY DEFINER wrapper,
--                                           -- JWT role = authenticated
--      → "BLOCKED [KS403] credit_wallet_for_refund is not callable by role
--         authenticated"
--
--    Reusing it would therefore mean relaxing the strictest guard on the one
--    function in this database that mints balance out of nothing — the exact
--    F-1 hole, reopened, to save fifteen lines. Inlining the credit instead
--    means there is STILL no function reachable from an authenticated JWT that
--    credits a wallet without first debiting another one in the same
--    transaction. That containment is the point; it is stronger than reuse.
--
-- 2. A GIFT IS NOT A REFUND, SO IT MUST NOT BE BOOKED AS ONE. Even if the guard
--    allowed it, `credit_wallet_for_refund` does
--    `total_spent = GREATEST(0, total_spent - p_amount)` — it reverses a spend,
--    because that is what a refund is. Crediting a gift through it would erase
--    lifetime spend the recipient really did incur, and two friends passing $20
--    back and forth would drive both counters to zero. A gift is an inflow:
--    the recipient's `total_deposited` goes up, exactly as `credit_wallet` and
--    `credit_wallet_for_deposit` do it.
--
-- 3. ONLY REAL MONEY IS GIFTABLE. "Strong referral flywheel" cuts both ways:
--    the frictionless version of this feature is also a promo-credit
--    laundromat — register n accounts, collect n referral bonuses, gift them
--    all into one wallet. So the transferable amount is capped at
--
--      LEAST(balance, deposits + gifts_received - gifts_sent)
--
--    computed FROM THE LEDGER, not from `wallets.total_deposited`. That counter
--    is unusable here: on this database it reads 0.00 for six of eight users
--    who demonstrably have `deposit` rows (legacy/seeded credits never touched
--    it), so a rule keyed on it would block three quarters of the user base
--    from a feature they are entitled to. The ledger cannot drift — it is what
--    the balance is made of. On live data this leaves every user $43.20-$85.20
--    of headroom while correctly excluding each one's $2.00 referral credit.
--
-- ── Anti-abuse, in one place ────────────────────────────────────────────────
-- Rate limit (5/hour, `RATE_LIMIT_GIFT_CREDIT`) is consumed BEFORE the
-- recipient lookup, which is what bounds email enumeration — this RPC is the
-- only place in the app where an arbitrary email can be tested against the user
-- table, and 5 guesses an hour with a failed-lookup trail in `security_logs` is
-- not a usable oracle. Per-transfer min/max and a rolling 24h cap come from
-- `system_configs` so the owner can retune without a deploy. Suspended accounts
-- and accounts with an open deletion request are refused on BOTH sides: the D3
-- purge pipeline freezes and then drains a leaving user's wallet, so gifting
-- into one burns the money and gifting out of one is the drain D3 exists to
-- prevent.
--
-- ── Concurrency ────────────────────────────────────────────────────────────
-- Both wallets are locked in ascending user_id order before either is touched,
-- so simultaneous A→B and B→A transfers queue instead of deadlocking. The
-- debit helper's own FOR UPDATE then re-locks a row this transaction already
-- holds, which is free.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. Two new ledger types.
--
-- `wallet_transactions.type` is a CHECK-constrained enum-by-convention; an
-- INSERT of an unlisted type raises 23514 rather than silently mis-filing, so
-- the constraint has to be replaced rather than merely extended.
-- ---------------------------------------------------------------------------
ALTER TABLE public.wallet_transactions
  DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;

ALTER TABLE public.wallet_transactions
  ADD CONSTRAINT wallet_transactions_type_check CHECK (type = ANY (ARRAY[
    'deposit',
    'topup_debit',
    'refund',
    'referral_credit',
    'welcome_home_debit',
    'auto_fund',
    'plan_fee_debit',
    'esim_purchase_debit',
    'esim_purchase_refund',
    'wallet_settlement',
    'wallet_forfeit',
    'gift_sent',
    'gift_received'
  ]));


-- ---------------------------------------------------------------------------
-- 2. Idempotency, enforced by the database and not only by the pre-check.
--
-- One partial unique index per side, both on reference_id: the two halves of a
-- transfer deliberately SHARE a reference_id, so a single index across both
-- types would reject every legitimate gift. A replayed submit therefore either
-- short-circuits on the pre-check or, if two retries race, loses the insert to
-- 23505 and rolls the whole transfer back. It cannot pay twice.
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_txns_gift_sent_ref
  ON public.wallet_transactions (reference_id)
  WHERE (type = 'gift_sent' AND reference_id IS NOT NULL);

CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_txns_gift_received_ref
  ON public.wallet_transactions (reference_id)
  WHERE (type = 'gift_received' AND reference_id IS NOT NULL);


-- ---------------------------------------------------------------------------
-- 3. Owner-tunable limits. Every one of these is read at call time, so raising
--    a cap is an UPDATE, not a migration.
-- ---------------------------------------------------------------------------
INSERT INTO public.system_configs (config_key, config_value) VALUES
  ('GIFT_MIN_USD',           '1.00'),
  ('GIFT_MAX_USD',           '100.00'),
  ('GIFT_DAILY_MAX_USD',     '250.00'),
  ('RATE_LIMIT_GIFT_CREDIT', '5/60')
ON CONFLICT (config_key) DO NOTHING;


-- ---------------------------------------------------------------------------
-- 4. transfer_wallet_credit — the whole feature.
--
-- Returns jsonb rather than raising for every user-facing outcome, so the
-- Flutter client gets a code it can render instead of a Postgres exception
-- string. The one thing that does raise through is a genuine bug; KS429 from
-- the limiter is caught explicitly (and ONLY KS429 — a WHEN OTHERS catch-all
-- here would swallow the next guard someone adds, which is how D5c's tamper
-- trigger became dead code).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.transfer_wallet_credit(
  p_recipient_email TEXT,
  p_amount          NUMERIC,
  p_reference_id    TEXT DEFAULT NULL,
  p_note            TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_sender_id       UUID := auth.uid();
  v_sender_email    TEXT;
  v_sender_name     TEXT;
  v_recipient_id    UUID;
  v_recipient_email TEXT;
  v_recipient_name  TEXT;
  v_email           TEXT;
  v_amount          NUMERIC(10,2);
  v_ref             TEXT;
  v_note            TEXT;
  v_min             NUMERIC := 1.00;
  v_max             NUMERIC := 100.00;
  v_daily_max       NUMERIC := 250.00;
  v_sent_today      NUMERIC;
  v_balance         NUMERIC;
  v_giftable        NUMERIC;
  v_existing        public.wallet_transactions%ROWTYPE;
  v_wallet_id       UUID;
  v_before          NUMERIC;
  v_after           NUMERIC;
  v_debit_id        UUID;
  v_credit_id       UUID;
  v_lock            RECORD;
  v_amount_text     TEXT;
BEGIN
  ------------------------------------------------------------------------
  -- Caller identity. auth.uid() is the only accepted sender: there is no
  -- p_sender_id parameter to spoof, by construction.
  ------------------------------------------------------------------------
  IF v_sender_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED',
                              'error', 'You must be signed in to send credit.');
  END IF;

  v_note := NULLIF(LEFT(TRIM(COALESCE(p_note, '')), 140), '');
  v_ref  := NULLIF(TRIM(COALESCE(p_reference_id, '')), '');
  IF v_ref IS NULL THEN
    -- The client normally supplies this so a network retry adopts the original
    -- transfer. Generating one here keeps a caller that forgets it correct for
    -- the single attempt it makes, rather than failing outright.
    v_ref := 'gift_' || LEFT(v_sender_id::text, 8) || '_'
             || (EXTRACT(EPOCH FROM clock_timestamp()) * 1000000)::bigint::text;
  END IF;

  ------------------------------------------------------------------------
  -- Idempotency pre-check, BEFORE the limiter: a retry of a transfer that
  -- already went through must not also burn a rate-limit token.
  ------------------------------------------------------------------------
  SELECT * INTO v_existing
  FROM public.wallet_transactions
  WHERE reference_id = v_ref AND type = 'gift_sent' AND user_id = v_sender_id;

  IF v_existing.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_sent', true,
      'transaction_id', v_existing.id,
      'reference_id', v_ref,
      'amount', v_existing.amount,
      'recipient_email', v_existing.metadata #>> '{gift,counterparty_email}',
      'recipient_name', v_existing.metadata #>> '{gift,counterparty_name}'
    );
  END IF;

  ------------------------------------------------------------------------
  -- Amount.
  ------------------------------------------------------------------------
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'code', 'INVALID_AMOUNT',
                              'error', 'Enter an amount greater than zero.');
  END IF;
  v_amount := ROUND(p_amount, 2);

  SELECT COALESCE(MAX(CASE WHEN config_key = 'GIFT_MIN_USD'       THEN config_value::numeric END), 1.00),
         COALESCE(MAX(CASE WHEN config_key = 'GIFT_MAX_USD'       THEN config_value::numeric END), 100.00),
         COALESCE(MAX(CASE WHEN config_key = 'GIFT_DAILY_MAX_USD' THEN config_value::numeric END), 250.00)
    INTO v_min, v_max, v_daily_max
  FROM public.system_configs
  WHERE config_key IN ('GIFT_MIN_USD', 'GIFT_MAX_USD', 'GIFT_DAILY_MAX_USD');

  IF v_amount < v_min THEN
    RETURN jsonb_build_object('success', false, 'code', 'BELOW_MINIMUM',
      'error', 'The smallest gift is $' || to_char(v_min, 'FM99999990.00') || '.',
      'minimum', v_min);
  END IF;

  IF v_amount > v_max THEN
    RETURN jsonb_build_object('success', false, 'code', 'ABOVE_MAXIMUM',
      'error', 'The largest single gift is $' || to_char(v_max, 'FM99999990.00') || '.',
      'maximum', v_max);
  END IF;

  ------------------------------------------------------------------------
  -- Sender eligibility. A frozen/draining account must not be able to push
  -- its balance out ahead of the purge — that is the drain D3 closed.
  ------------------------------------------------------------------------
  IF EXISTS (SELECT 1 FROM public.profiles
             WHERE id = v_sender_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'code', 'SENDER_SUSPENDED',
                              'error', 'Your account is suspended.');
  END IF;

  IF EXISTS (SELECT 1 FROM public.account_deletions
             WHERE user_id = v_sender_id
               AND status IN ('requested', 'frozen', 'draining')) THEN
    RETURN jsonb_build_object('success', false, 'code', 'SENDER_CLOSING',
      'error', 'Your account is scheduled for deletion, so transfers are closed.');
  END IF;

  ------------------------------------------------------------------------
  -- Recipient. Resolved against auth.users, which is the authority for what
  -- someone actually signs in with; profiles.email is a mirror of it.
  ------------------------------------------------------------------------
  v_email := LOWER(TRIM(COALESCE(p_recipient_email, '')));
  IF v_email = '' OR v_email NOT LIKE '%_@_%.__%' THEN
    RETURN jsonb_build_object('success', false, 'code', 'INVALID_EMAIL',
                              'error', 'Enter a valid email address.');
  END IF;

  ------------------------------------------------------------------------
  -- Rate limit, consumed HERE: on the last line before the only statement in
  -- this app that tests an arbitrary email against the user table. Everything
  -- above is either about the caller or about the caller's own money, and
  -- reveals nothing, so a fat-fingered amount must not cost an enumeration
  -- token — the first live probe put the limiter at the top of the function
  -- and locked the sender out after five typos. Every lookup still costs one,
  -- which is what actually bounds the oracle.
  ------------------------------------------------------------------------
  BEGIN
    PERFORM public.enforce_rate_limit('gift_credit', v_sender_id::text);
  EXCEPTION WHEN SQLSTATE 'KS429' THEN
    RETURN jsonb_build_object(
      'success', false, 'code', 'KS429',
      'error', 'Too many transfers just now. Try again in a little while.');
  END;

  SELECT u.id, u.email INTO v_recipient_id, v_recipient_email
  FROM auth.users u
  WHERE LOWER(u.email) = v_email
    AND u.deleted_at IS NULL
    AND COALESCE(u.is_anonymous, false) = false;

  IF v_recipient_id IS NULL THEN
    -- Logged, not silent: five of these an hour from one account is the shape
    -- of an enumeration attempt, and security_logs is where D2/D5 look for it.
    INSERT INTO public.security_logs (user_id, event_type, description, metadata)
    VALUES (v_sender_id, 'gift_recipient_not_found',
            'Wallet gift attempted to an address with no KeepSIMs account',
            jsonb_build_object('email_hash',
                               encode(sha256(v_email::bytea), 'hex')));

    RETURN jsonb_build_object('success', false, 'code', 'RECIPIENT_NOT_FOUND',
      'error', 'No KeepSIMs account uses that email address yet.');
  END IF;

  IF v_recipient_id = v_sender_id THEN
    RETURN jsonb_build_object('success', false, 'code', 'CANNOT_GIFT_SELF',
                              'error', 'You cannot send credit to yourself.');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles
             WHERE id = v_recipient_id AND is_suspended = true)
     OR EXISTS (SELECT 1 FROM public.account_deletions
                WHERE user_id = v_recipient_id
                  AND status IN ('requested', 'frozen', 'draining', 'drained')) THEN
    -- Deliberately the same wording as an unavailable wallet: whether the
    -- recipient is suspended or leaving is their business, not the sender's.
    RETURN jsonb_build_object('success', false, 'code', 'RECIPIENT_UNAVAILABLE',
      'error', 'That account cannot receive credit right now.');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE user_id = v_recipient_id) THEN
    RETURN jsonb_build_object('success', false, 'code', 'RECIPIENT_UNAVAILABLE',
      'error', 'That account cannot receive credit right now.');
  END IF;

  ------------------------------------------------------------------------
  -- Rolling 24h cap, across every recipient.
  ------------------------------------------------------------------------
  SELECT COALESCE(SUM(amount), 0) INTO v_sent_today
  FROM public.wallet_transactions
  WHERE user_id = v_sender_id
    AND type = 'gift_sent'
    AND status = 'completed'
    AND created_at > (clock_timestamp() - INTERVAL '24 hours');

  IF v_sent_today + v_amount > v_daily_max THEN
    RETURN jsonb_build_object('success', false, 'code', 'DAILY_LIMIT',
      'error', 'That would pass your $' || to_char(v_daily_max, 'FM99999990.00')
               || ' daily transfer limit. Sent in the last 24 hours: $'
               || to_char(v_sent_today, 'FM99999990.00') || '.',
      'daily_max', v_daily_max, 'sent_today', v_sent_today);
  END IF;

  ------------------------------------------------------------------------
  -- Lock both wallets, lowest user_id first. See the header note on ordering.
  ------------------------------------------------------------------------
  FOR v_lock IN
    SELECT id FROM public.wallets
    WHERE user_id IN (v_sender_id, v_recipient_id)
    ORDER BY user_id
  LOOP
    PERFORM 1 FROM public.wallets WHERE id = v_lock.id FOR UPDATE;
  END LOOP;

  ------------------------------------------------------------------------
  -- Giftable balance. Computed from the ledger; see departure 3 in the header.
  ------------------------------------------------------------------------
  SELECT COALESCE(balance, 0) INTO v_balance
  FROM public.wallets WHERE user_id = v_sender_id;

  IF v_balance < v_amount THEN
    RETURN jsonb_build_object('success', false, 'code', 'INSUFFICIENT_FUNDS',
      'error', 'Your balance is $' || to_char(v_balance, 'FM99999990.00') || '.',
      'balance', v_balance);
  END IF;

  SELECT LEAST(
           v_balance,
           GREATEST(
             COALESCE(SUM(amount) FILTER (WHERE type IN ('deposit', 'gift_received')), 0)
             - COALESCE(SUM(amount) FILTER (WHERE type = 'gift_sent'), 0),
             0)
         )
    INTO v_giftable
  FROM public.wallet_transactions
  WHERE user_id = v_sender_id AND status = 'completed';

  IF v_amount > COALESCE(v_giftable, 0) THEN
    RETURN jsonb_build_object('success', false, 'code', 'NOT_GIFTABLE',
      'error', 'Only credit you added yourself can be sent on. Available to '
               || 'send: $' || to_char(COALESCE(v_giftable, 0), 'FM99999990.00') || '.',
      'giftable', COALESCE(v_giftable, 0),
      'balance', v_balance);
  END IF;

  SELECT u.email, p.full_name INTO v_sender_email, v_sender_name
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
  WHERE u.id = v_sender_id;

  SELECT full_name INTO v_recipient_name
  FROM public.profiles WHERE id = v_recipient_id;

  ------------------------------------------------------------------------
  -- The debit. Reuses F2's helper: balance re-check, wallet row update and
  -- ledger insert are all inside it, and its call-depth guard passes because
  -- this frame is not the top one.
  ------------------------------------------------------------------------
  v_debit_id := public.debit_wallet_for_topup(
    v_sender_id,
    NULL,
    v_amount,
    'Gift to ' || COALESCE(NULLIF(v_recipient_name, ''), v_recipient_email),
    v_ref,
    'gift_sent'
  );

  ------------------------------------------------------------------------
  -- The credit. Inline; see departure 1 in the header for why this is not a
  -- call to credit_wallet_for_refund.
  ------------------------------------------------------------------------
  SELECT id, balance INTO v_wallet_id, v_before
  FROM public.wallets WHERE user_id = v_recipient_id FOR UPDATE;

  v_after := v_before + v_amount;

  UPDATE public.wallets
  SET balance = v_after,
      total_deposited = COALESCE(total_deposited, 0) + v_amount
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, status, metadata
  ) VALUES (
    v_wallet_id, v_recipient_id, 'gift_received', v_amount, v_before, v_after,
    'Gift from ' || COALESCE(NULLIF(v_sender_name, ''), v_sender_email),
    v_ref, 'completed',
    jsonb_build_object('gift', jsonb_strip_nulls(jsonb_build_object(
      'direction', 'received',
      'counterparty_user_id', v_sender_id,
      'counterparty_email', v_sender_email,
      'counterparty_name', NULLIF(v_sender_name, ''),
      'note', v_note)))
  ) RETURNING id INTO v_credit_id;

  -- The debit helper takes no metadata, so the sender's half is annotated
  -- here. Same shape, opposite direction — the UI reads one field for both.
  UPDATE public.wallet_transactions
  SET metadata = jsonb_build_object('gift', jsonb_strip_nulls(jsonb_build_object(
        'direction', 'sent',
        'counterparty_user_id', v_recipient_id,
        'counterparty_email', v_recipient_email,
        'counterparty_name', NULLIF(v_recipient_name, ''),
        'note', v_note)))
  WHERE id = v_debit_id;

  ------------------------------------------------------------------------
  -- Tell the recipient. `wallet_credit` is a C1 default-ON category, so unlike
  -- G2's promo alerts this one reaches people without an opt-in first —
  -- subject to F1, which is what makes push actually arrive.
  ------------------------------------------------------------------------
  v_amount_text := to_char(v_amount, 'FM99999990.00');

  INSERT INTO public.notifications (user_id, category, title, body, action_url)
  VALUES (
    v_recipient_id,
    'wallet_credit',
    'You received $' || v_amount_text,
    COALESCE(NULLIF(v_sender_name, ''), v_sender_email)
      || ' sent you $' || v_amount_text || ' of KeepSIMs credit.'
      || CASE WHEN v_note IS NULL THEN '' ELSE ' "' || v_note || '"' END,
    '/wallet'
  );

  RETURN jsonb_build_object(
    'success', true,
    'already_sent', false,
    'reference_id', v_ref,
    'amount', v_amount,
    'transaction_id', v_debit_id,
    'credit_transaction_id', v_credit_id,
    'recipient_email', v_recipient_email,
    'recipient_name', NULLIF(v_recipient_name, ''),
    'balance_after', v_balance - v_amount
  );
END;
$$;

-- Callable by signed-in users — that is the whole point — and by nobody else.
-- Signature-qualified, as F1 established: an unqualified REVOKE silently does
-- nothing the day a second overload appears.
REVOKE ALL ON FUNCTION public.transfer_wallet_credit(TEXT, NUMERIC, TEXT, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.transfer_wallet_credit(TEXT, NUMERIC, TEXT, TEXT)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.transfer_wallet_credit(TEXT, NUMERIC, TEXT, TEXT) IS
  'G3: moves wallet credit from auth.uid() to the account owning p_recipient_email, '
  'as a gift_sent/gift_received pair sharing one reference_id. Sender is always '
  'auth.uid() — there is no sender parameter. Rate limited before the recipient '
  'lookup (enumeration bound); only ledger-derived deposits and received gifts are '
  'transferable. Regression test supabase/tests/g3_gift_credit_tests.sql.';
