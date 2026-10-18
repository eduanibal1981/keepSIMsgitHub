-- L2 — the four RPCs the customer app calls, and the only place a PIN is
-- ever handed out.
--
-- `offline_voucher_stock` is deny-all. Nothing outside these functions can read
-- a PIN, decrypt one, or invent a grant, which is what makes it possible to say
-- exactly where entitlement is decided: here, once, in
-- `provision_offline_voucher`.
--
-- ── ON DEVICE-RISK GUARDS, deliberately absent ────────────────────────────
-- G10's `guard_money_action` sits in front of every other money path. Neither
-- of the two money-shaped calls here uses it, and both omissions are chosen:
--
--   * PROVISIONING hands over a bearer instrument, so it looks like a spend.
--     But the whole point of the voucher is to be on the handset BEFORE the
--     handset loses connectivity. A risk engine that declines to provision has
--     not prevented a loss — it has removed the safety net from a subscriber who
--     already paid for it, and they find out at the worst possible moment. The
--     exposure is bounded instead by structure: premium entitlement must be paid
--     for, and `offline_voucher_grants_one_live_per_line` makes a second live
--     voucher on a line impossible at the index level.
--
--   * SETTLEMENT is the subscriber PAYING US. Blocking it would leave a debt
--     open, keep them ineligible for the next voucher, and punish the exact
--     behaviour we want. It is rate-limited, not risk-scored.

BEGIN;

-- ───────────────────────────────────────────────────────────────────────────
-- 0. Rate-limit bucket
-- ───────────────────────────────────────────────────────────────────────────
INSERT INTO public.system_configs (config_key, config_value)
VALUES ('RATE_LIMIT_VOUCHER_PROVISION', '10/60')
ON CONFLICT (config_key) DO NOTHING;

INSERT INTO public.system_config_meta
  (config_key, label, group_name, value_type, description, sort_order)
VALUES
  ('RATE_LIMIT_VOUCHER_PROVISION', 'Voucher provision', 'Rate limits', 'rate_limit',
   'Calls per minutes for provision_offline_voucher. Re-provisioning is idempotent, so a '
   || 'generous limit is safe; this only stops a script walking the stock table.', 640)
ON CONFLICT (config_key) DO NOTHING;

-- ───────────────────────────────────────────────────────────────────────────
-- 1. What a subscriber owes for a voucher
-- ───────────────────────────────────────────────────────────────────────────
-- One function, called from exactly one place (the reveal), because a price
-- computed in two places drifts — J8 is the whole story of that. Priced at
-- REVEAL and then frozen on the grant: a fee change next month must not
-- re-price a voucher somebody already spent.
CREATE OR REPLACE FUNCTION public.offline_voucher_amount_due(p_face_value_usd numeric)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_fee_pct numeric;
BEGIN
  SELECT COALESCE(NULLIF(config_value, '')::numeric, 0)
    INTO v_fee_pct
    FROM public.system_configs
   WHERE config_key = 'OFFLINE_VOUCHER_SERVICE_FEE_PERCENT';

  RETURN round(p_face_value_usd * (1 + COALESCE(v_fee_pct, 0) / 100.0), 2);
END;
$fn$;

REVOKE ALL ON FUNCTION public.offline_voucher_amount_due(numeric) FROM PUBLIC, anon, authenticated;

-- ───────────────────────────────────────────────────────────────────────────
-- 2. Open (or refresh) a manual fulfilment request
-- ───────────────────────────────────────────────────────────────────────────
-- Called when an entitled subscriber asks for a voucher and there is none. The
-- alternative — returning "no stock" and forgetting — is how a paid feature
-- quietly does nothing for months.
CREATE OR REPLACE FUNCTION public.open_offline_voucher_request(
  p_user_id     uuid,
  p_sim_line_id uuid,
  p_carrier_id  uuid,
  p_reason      text DEFAULT 'no_stock'
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_sla  integer;
  v_due  timestamptz;
BEGIN
  SELECT COALESCE(NULLIF(config_value, '')::integer, 7)
    INTO v_sla
    FROM public.system_configs
   WHERE config_key = 'OFFLINE_VOUCHER_MANUAL_SLA_DAYS';

  -- The clock starts when the subscriber first needed a voucher, not when they
  -- asked again. Re-stamping due_at on every poll would keep the queue
  -- permanently green while the same person waits forever.
  SELECT due_at INTO v_due
    FROM public.offline_voucher_requests
   WHERE sim_line_id = p_sim_line_id AND status = 'open';

  IF FOUND THEN
    RETURN v_due;
  END IF;

  v_due := now() + make_interval(days => COALESCE(v_sla, 7));

  INSERT INTO public.offline_voucher_requests
    (user_id, sim_line_id, carrier_id, reason, due_at)
  VALUES (p_user_id, p_sim_line_id, p_carrier_id, p_reason, v_due)
  ON CONFLICT DO NOTHING;

  RETURN v_due;
END;
$fn$;

REVOKE ALL ON FUNCTION public.open_offline_voucher_request(uuid, uuid, uuid, text)
  FROM PUBLIC, anon, authenticated;

-- ───────────────────────────────────────────────────────────────────────────
-- 3. provision_offline_voucher — the one place a PIN leaves the database
-- ───────────────────────────────────────────────────────────────────────────
-- Idempotent by design. The handset stores the PIN in the platform keystore,
-- but a reinstall wipes that, and a subscriber who reinstalled and then went
-- offline would be stranded holding a voucher they cannot read. So a call for a
-- line that already has a live grant re-serves THE SAME PIN. That is not a
-- second voucher: the liability is the stock row, and it is already theirs.
CREATE OR REPLACE FUNCTION public.provision_offline_voucher(
  p_sim_line_id uuid,
  p_device_id   text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_uid       uuid := auth.uid();
  v_enabled   boolean;
  v_line      RECORD;
  v_grant     RECORD;
  v_stock     RECORD;
  v_validity  integer;
  v_due       timestamptz;
  v_source    text;
  v_redeem    RECORD;
  -- A plain flag rather than re-assigning the RECORD: a plpgsql RECORD that has
  -- been set to NULL raises "record is not assigned yet" on the next field
  -- read, which would turn the expired-stock path into a 500.
  v_reuse     boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED');
  END IF;

  SELECT COALESCE(NULLIF(config_value, ''), 'false')::boolean INTO v_enabled
    FROM public.system_configs WHERE config_key = 'OFFLINE_VOUCHER_ENABLED';
  IF NOT COALESCE(v_enabled, false) THEN
    RETURN jsonb_build_object('success', false, 'code', 'FEATURE_OFF');
  END IF;

  PERFORM public.enforce_rate_limit('voucher_provision', v_uid::text);

  -- Owner only. A household manager may refill a shared line but has never been
  -- able to buy or upgrade its plan (I7), and a voucher is an entitlement of
  -- that plan — issuing one to a manager would hand the owner's debt to someone
  -- who cannot settle it.
  SELECT sl.id, sl.user_id, sl.carrier_id, sl.phone_number
    INTO v_line
    FROM public.sim_lines sl
   WHERE sl.id = p_sim_line_id AND sl.user_id = v_uid;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'code', 'LINE_NOT_FOUND');
  END IF;

  IF v_line.carrier_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'NO_CARRIER');
  END IF;

  -- ── An existing grant decides the answer before any stock is touched ──────
  SELECT g.*, s.expires_at AS stock_expires_at
    INTO v_grant
    FROM public.offline_voucher_grants g
    JOIN public.offline_voucher_stock s ON s.id = g.stock_id
   WHERE g.sim_line_id = p_sim_line_id
     AND g.status IN ('provisioned', 'revealed')
   FOR UPDATE OF g;

  IF FOUND THEN
    IF v_grant.status = 'revealed' THEN
      -- The debt is the gate. This is the whole commercial loop.
      RETURN jsonb_build_object(
        'success', false,
        'code', 'SETTLEMENT_DUE',
        'grant_id', v_grant.id,
        'amount_due_usd', v_grant.amount_due_usd,
        'revealed_at', v_grant.revealed_at
      );
    END IF;

    -- Provisioned but the PIN died on the shelf: retire both and fall through
    -- to issue a fresh one, rather than handing over a code that will be
    -- refused by the carrier at the moment it is dialled.
    IF v_grant.stock_expires_at IS NOT NULL AND v_grant.stock_expires_at <= now() THEN
      UPDATE public.offline_voucher_grants
         SET status = 'expired', updated_at = now()
       WHERE id = v_grant.id;
      UPDATE public.offline_voucher_stock
         SET status = 'expired', updated_at = now()
       WHERE id = v_grant.stock_id;
    ELSE
      v_reuse := true;
    END IF;
  END IF;

  IF v_reuse THEN
    -- Re-serve. Record the device that asked, so a support question about
    -- "which handset holds this PIN" has an answer.
    UPDATE public.offline_voucher_grants
       SET device_id = COALESCE(p_device_id, device_id), updated_at = now()
     WHERE id = v_grant.id;

    SELECT * INTO v_stock FROM public.offline_voucher_stock WHERE id = v_grant.stock_id;

    SELECT * INTO v_redeem FROM public.carrier_voucher_redemption
     WHERE carrier_id = v_line.carrier_id;

    RETURN jsonb_build_object(
      'success', true,
      'reissued', true,
      'grant_id', v_grant.id,
      'sim_line_id', p_sim_line_id,
      'pin', public.voucher_decrypt_pin(v_stock.pin_encrypted),
      'serial', v_stock.serial,
      'face_value_usd', v_stock.face_value_usd,
      'face_value_native', v_stock.face_value_native,
      'face_value_currency', v_stock.face_value_currency,
      'amount_due_usd', public.offline_voucher_amount_due(v_stock.face_value_usd),
      'expires_at', v_stock.expires_at,
      -- Supplier wording, then the carrier's, then a generic line. NULL is not
      -- an option: the one thing a subscriber staring at a PIN with no signal
      -- must have is a sentence telling them what to do with it.
      'instructions', COALESCE(
        v_stock.redeem_instructions,
        v_redeem.instructions,
        'Dial your carrier''s recharge code and enter this PIN when prompted.'),
      -- A dial-able code only when a human has confirmed it works. An
      -- unverified USSD string dialled by someone with no connectivity and no
      -- credit cannot be undone — same stance as I8's carrier app links.
      'redeem_ussd_template',
        CASE WHEN v_redeem.verified_at IS NOT NULL THEN v_redeem.redeem_ussd_template END
    );
  END IF;

  -- ── Entitlement, checked only when a NEW voucher would be issued ──────────
  -- Deliberately after the re-serve branch: a subscriber whose premium year has
  -- lapsed still holds whatever PIN we already gave them, and hiding it would
  -- not take it back — it would just make it unreadable.
  IF NOT public.has_paid_premium_entitlement(p_sim_line_id) THEN
    RETURN jsonb_build_object('success', false, 'code', 'NOT_PREMIUM');
  END IF;

  SELECT COALESCE(NULLIF(config_value, '')::integer, 365) INTO v_validity
    FROM public.system_configs WHERE config_key = 'OFFLINE_VOUCHER_VALIDITY_DAYS';

  -- Cheapest usable PIN first, then soonest to expire — sell the perishable
  -- stock before it rots, but never hand out something already dead.
  SELECT * INTO v_stock
    FROM public.offline_voucher_stock
   WHERE carrier_id = v_line.carrier_id
     AND status = 'available'
     AND (expires_at IS NULL OR expires_at > now() + interval '7 days')
   ORDER BY face_value_usd ASC, expires_at ASC NULLS LAST, created_at ASC
   FOR UPDATE SKIP LOCKED
   LIMIT 1;

  IF NOT FOUND THEN
    v_source := public.offline_voucher_source_for_carrier(v_line.carrier_id);
    v_due := public.open_offline_voucher_request(
      v_uid, p_sim_line_id, v_line.carrier_id,
      CASE WHEN v_source = 'ding' THEN 'no_stock' ELSE 'no_automatic_source' END
    );
    RETURN jsonb_build_object(
      'success', false,
      'code', 'NO_STOCK',
      'source', v_source,
      'expected_by', v_due
    );
  END IF;

  UPDATE public.offline_voucher_stock
     SET status = 'issued',
         expires_at = COALESCE(expires_at, now() + make_interval(days => COALESCE(v_validity, 365))),
         updated_at = now()
   WHERE id = v_stock.id
  RETURNING * INTO v_stock;

  INSERT INTO public.offline_voucher_grants
    (user_id, sim_line_id, stock_id, device_id, expires_at)
  VALUES (v_uid, p_sim_line_id, v_stock.id, p_device_id, v_stock.expires_at)
  RETURNING * INTO v_grant;

  -- Issuing satisfies whatever the operator was queued to do.
  UPDATE public.offline_voucher_requests
     SET status = 'fulfilled', fulfilled_at = now(), stock_id = v_stock.id, updated_at = now()
   WHERE sim_line_id = p_sim_line_id AND status = 'open';

  SELECT * INTO v_redeem FROM public.carrier_voucher_redemption
   WHERE carrier_id = v_line.carrier_id;

  RETURN jsonb_build_object(
    'success', true,
    'reissued', false,
    'grant_id', v_grant.id,
    'sim_line_id', p_sim_line_id,
    'pin', public.voucher_decrypt_pin(v_stock.pin_encrypted),
    'serial', v_stock.serial,
    'face_value_usd', v_stock.face_value_usd,
    'face_value_native', v_stock.face_value_native,
    'face_value_currency', v_stock.face_value_currency,
    'amount_due_usd', public.offline_voucher_amount_due(v_stock.face_value_usd),
    'expires_at', v_stock.expires_at,
    'instructions', COALESCE(
      v_stock.redeem_instructions,
      v_redeem.instructions,
      'Dial your carrier''s recharge code and enter this PIN when prompted.'),
    'redeem_ussd_template',
      CASE WHEN v_redeem.verified_at IS NOT NULL THEN v_redeem.redeem_ussd_template END
  );
EXCEPTION
  WHEN unique_violation THEN
    -- Two devices provisioning the same line at the same instant. The index is
    -- the authority; report the race rather than pretending it did not happen.
    RETURN jsonb_build_object('success', false, 'code', 'RACE_RETRY');
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 4. report_offline_voucher_reveal — the debt is created here, not at reveal
-- ───────────────────────────────────────────────────────────────────────────
-- The actual reveal happens on a handset with no network. This is the handset
-- telling us about it afterwards, which may be minutes or weeks later. The
-- timestamp is therefore CLIENT-SUPPLIED and must be treated as such: clamped
-- into [provisioned_at, now()] so a wrong device clock — or a hand-edited
-- request — cannot backdate a debt out of the grace window or park it in the
-- future where no reminder would ever fire.
CREATE OR REPLACE FUNCTION public.report_offline_voucher_reveal(
  p_grant_id    uuid,
  p_revealed_at timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_uid     uuid := auth.uid();
  v_grant   RECORD;
  v_stock   RECORD;
  v_amount  numeric(10,2);
  v_when    timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED');
  END IF;

  SELECT * INTO v_grant
    FROM public.offline_voucher_grants
   WHERE id = p_grant_id AND user_id = v_uid
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'code', 'GRANT_NOT_FOUND');
  END IF;

  -- Idempotent: the app retries this until it succeeds, and a duplicate report
  -- must not move the clock or re-price the debt.
  IF v_grant.status <> 'provisioned' THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_reported', true,
      'status', v_grant.status,
      'amount_due_usd', v_grant.amount_due_usd,
      'revealed_at', v_grant.revealed_at
    );
  END IF;

  SELECT * INTO v_stock FROM public.offline_voucher_stock WHERE id = v_grant.stock_id;
  v_amount := public.offline_voucher_amount_due(v_stock.face_value_usd);

  v_when := LEAST(GREATEST(COALESCE(p_revealed_at, now()), v_grant.provisioned_at), now());

  UPDATE public.offline_voucher_grants
     SET status = 'revealed',
         revealed_at = v_when,
         reported_at = now(),
         amount_due_usd = v_amount,
         updated_at = now()
   WHERE id = p_grant_id;

  UPDATE public.offline_voucher_stock
     SET status = 'redeemed', updated_at = now()
   WHERE id = v_grant.stock_id;

  -- `system` and not `promo`: a payment request is not marketing, and 0 of 8
  -- accounts consent to promo. Not `top_up_success` either — we do not know the
  -- carrier accepted the PIN, only that the subscriber read it.
  INSERT INTO public.notifications (user_id, category, title, body, sim_line_id, action_url)
  VALUES (
    v_uid, 'system',
    'Emergency top-up PIN used',
    'You used your emergency recharge PIN for $' || trim(to_char(v_stock.face_value_usd, 'FM999990.00'))
      || '. Settle $' || trim(to_char(v_amount, 'FM999990.00'))
      || ' from your wallet to get a new PIN for the next time you are offline.',
    v_grant.sim_line_id,
    '/settings/offline-recharge'
  );

  RETURN jsonb_build_object(
    'success', true,
    'already_reported', false,
    'grant_id', p_grant_id,
    'amount_due_usd', v_amount,
    'revealed_at', v_when
  );
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 5. settle_offline_voucher
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.settle_offline_voucher(p_grant_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_uid      uuid := auth.uid();
  v_grant    RECORD;
  v_balance  numeric(10,2);
  v_ref      text;
  v_txn_id   uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED');
  END IF;

  SELECT * INTO v_grant
    FROM public.offline_voucher_grants
   WHERE id = p_grant_id AND user_id = v_uid
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'code', 'GRANT_NOT_FOUND');
  END IF;

  IF v_grant.status = 'settled' THEN
    RETURN jsonb_build_object(
      'success', true, 'already_settled', true,
      'transaction_id', v_grant.settlement_txn_id, 'amount', v_grant.amount_due_usd
    );
  END IF;

  IF v_grant.status <> 'revealed' THEN
    RETURN jsonb_build_object('success', false, 'code', 'NOTHING_DUE', 'status', v_grant.status);
  END IF;

  v_ref := 'voucher_' || p_grant_id::text;

  -- The ledger, not the grant, is the authority on whether money moved. A
  -- previous attempt that debited and then failed to stamp the grant must not
  -- charge twice — H8's silent-no-op lesson inverted.
  SELECT id INTO v_txn_id
    FROM public.wallet_transactions
   WHERE reference_id = v_ref AND type = 'offline_voucher_debit';

  IF FOUND THEN
    UPDATE public.offline_voucher_grants
       SET status = 'settled', settled_at = COALESCE(settled_at, now()),
           settlement_txn_id = v_txn_id, updated_at = now()
     WHERE id = p_grant_id;
    UPDATE public.offline_voucher_stock
       SET status = 'settled', updated_at = now()
     WHERE id = v_grant.stock_id;
    RETURN jsonb_build_object(
      'success', true, 'already_settled', true,
      'transaction_id', v_txn_id, 'amount', v_grant.amount_due_usd
    );
  END IF;

  SELECT COALESCE(balance, 0.00) INTO v_balance
    FROM public.wallets WHERE user_id = v_uid;

  IF COALESCE(v_balance, 0) < v_grant.amount_due_usd THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INSUFFICIENT_FUNDS',
      'amount_due_usd', v_grant.amount_due_usd,
      'balance', COALESCE(v_balance, 0)
    );
  END IF;

  v_txn_id := public.debit_wallet_for_topup(
    v_uid, v_grant.sim_line_id, v_grant.amount_due_usd,
    'Emergency offline recharge PIN', v_ref, 'offline_voucher_debit'
  );

  UPDATE public.offline_voucher_grants
     SET status = 'settled', settled_at = now(), settlement_txn_id = v_txn_id, updated_at = now()
   WHERE id = p_grant_id;

  UPDATE public.offline_voucher_stock
     SET status = 'settled', updated_at = now()
   WHERE id = v_grant.stock_id;

  RETURN jsonb_build_object(
    'success', true,
    'already_settled', false,
    'transaction_id', v_txn_id,
    'amount', v_grant.amount_due_usd,
    'balance', COALESCE(v_balance, 0) - v_grant.amount_due_usd
  );
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 6. offline_voucher_state — everything the app renders, and no PIN
-- ───────────────────────────────────────────────────────────────────────────
-- Called while ONLINE. The PIN itself is never in this payload: the handset
-- already holds it in the platform keystore, and shipping it on every poll
-- would put a bearer instrument through the response cache of every screen
-- that happens to be open.
CREATE OR REPLACE FUNCTION public.offline_voucher_state()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_uid     uuid := auth.uid();
  v_enabled boolean;
  v_lines   jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED');
  END IF;

  SELECT COALESCE(NULLIF(config_value, ''), 'false')::boolean INTO v_enabled
    FROM public.system_configs WHERE config_key = 'OFFLINE_VOUCHER_ENABLED';

  SELECT COALESCE(jsonb_agg(x ORDER BY x ->> 'phone_number'), '[]'::jsonb)
    INTO v_lines
    FROM (
      SELECT jsonb_build_object(
               'sim_line_id',  sl.id,
               'phone_number', sl.phone_number,
               'nickname',     sl.nickname,
               'carrier_id',   sl.carrier_id,
               'carrier_name', c.name,
               'entitled',     public.has_paid_premium_entitlement(sl.id),
               'grant', CASE WHEN g.id IS NULL THEN NULL ELSE jsonb_build_object(
                          'id',              g.id,
                          'status',          g.status,
                          'amount_due_usd',  g.amount_due_usd,
                          'face_value_usd',  s.face_value_usd,
                          'revealed_at',     g.revealed_at,
                          'provisioned_at',  g.provisioned_at,
                          'expires_at',      g.expires_at
                        ) END,
               'request', CASE WHEN r.id IS NULL THEN NULL ELSE jsonb_build_object(
                            'due_at', r.due_at,
                            'reason', r.reason
                          ) END,
               -- Whether a NEW voucher could be issued right now. The app uses
               -- it to say "ready when you need it" instead of provisioning
               -- speculatively and locking a PIN nobody is going to carry.
               'stock_available', EXISTS (
                 SELECT 1 FROM public.offline_voucher_stock st
                  WHERE st.carrier_id = sl.carrier_id
                    AND st.status = 'available'
                    AND (st.expires_at IS NULL OR st.expires_at > now() + interval '7 days')
               )
             ) AS x
        FROM public.sim_lines sl
        LEFT JOIN public.carriers c ON c.id = sl.carrier_id
        LEFT JOIN public.offline_voucher_grants g
               ON g.sim_line_id = sl.id AND g.status IN ('provisioned','revealed')
        LEFT JOIN public.offline_voucher_stock s ON s.id = g.stock_id
        LEFT JOIN public.offline_voucher_requests r
               ON r.sim_line_id = sl.id AND r.status = 'open'
       WHERE sl.user_id = v_uid
    ) q;

  RETURN jsonb_build_object(
    'success', true,
    'enabled', COALESCE(v_enabled, false),
    'lines', v_lines,
    'outstanding_total_usd', COALESCE((
      SELECT sum(amount_due_usd) FROM public.offline_voucher_grants
       WHERE user_id = v_uid AND status = 'revealed'), 0)
  );
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 7. Grants
-- ───────────────────────────────────────────────────────────────────────────
-- Only these four. Everything else in this migration is internal and was
-- revoked at definition — a SECURITY DEFINER function keeps the default
-- EXECUTE-to-PUBLIC unless told otherwise, which is occurrence #6 of the
-- blanket-grant hole and exactly what F0 T1 exists to catch.
GRANT EXECUTE ON FUNCTION public.provision_offline_voucher(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.report_offline_voucher_reveal(uuid, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.settle_offline_voucher(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.offline_voucher_state() TO authenticated;

REVOKE ALL ON FUNCTION public.provision_offline_voucher(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.report_offline_voucher_reveal(uuid, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.settle_offline_voucher(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.offline_voucher_state() FROM PUBLIC, anon;

COMMIT;
