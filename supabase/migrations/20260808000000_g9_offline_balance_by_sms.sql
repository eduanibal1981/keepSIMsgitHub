-- ============================================================================
-- G9 — Offline balance check by SMS ("BAL")
--
-- Feature suggestion #9 in doc/PRODUCTION_PLAN_REVIEW.md § 6. The C4 inbound
-- plumbing already resolves sender → user; this adds the keyword that answers
-- back, so the offline channel stops being fire-and-forget.
--
-- ── 🔴 IT ALSO FIXES SOMETHING THAT SHOULD NOT HAVE SHIPPED ────────────────
--
-- Today **every** inbound message triggers a refill. `sms-webhook` and
-- `waba-webhook` both hand the message straight to `ingest_offline_refill()`,
-- which reads the body only through `parseAmount()` — a regex for the first
-- number. Text "hi", "stop", "who is this" or indeed "BAL" to the C4 number
-- and `parseAmount` returns NULL, so the function falls back to
-- `offline_refill_settings.default_refill_amount` and **queues a $10 top-up**.
-- There is no keyword check anywhere in the path.
--
-- So the first thing G9 adds is not a feature, it is a router: the body is now
-- classified before anything happens, and only `REFILL` (with or without an
-- amount) or a bare amount spends money. The app has always documented exactly
-- that — `app_en.arb` says *Send REFILL 5, REFILL 10 or REFILL 25* — so the
-- documented contract is unchanged. What changes is that the undocumented
-- "any text at all" path no longer costs the user $10.
--
-- ── Four decisions worth not re-deriving ───────────────────────────────────
--
-- 1. THE WHOLE CONVERSATION LIVES IN THE DATABASE. `handle_inbound_command()`
--    classifies, acts, logs and returns the text to send. The two webhooks
--    become thin: parse the provider's envelope, call one function, send back
--    what it returns. That is what keeps SMS and WhatsApp behaving identically
--    instead of drifting into two dialects, and it means the reply wording is
--    testable in SQL.
--
-- 2. AN UNKNOWN SENDER GETS SILENCE, NOT AN ERROR. Replying "we don't know you"
--    turns the number into an oracle for testing which phone numbers hold
--    KeepSIMs accounts, and bills us for an SMS to a stranger. Unknown senders
--    are logged and ignored.
--
-- 3. THE REPLY IS DELIBERATELY THIN. Caller ID is spoofable and SMS is
--    plaintext, so a balance reply carries the wallet total, per-line
--    nicknames (or a `••••1234` mask when there is no nickname) and days
--    remaining — never a full phone number, never an ICCID, never a
--    transaction. `BAL` is gated on the same `offline_refill_settings.is_enabled`
--    consent that already governs this channel: if a user has not switched the
--    offline channel on, we do not discuss their money over it.
--
-- 4. REPLIES ARE IDEMPOTENT PER PROVIDER MESSAGE ID. Twilio retries webhooks.
--    A retry must re-send the *same* answer rather than either double-charging
--    a refill (already handled by `ingest_offline_refill`) or going silent
--    (which is what a naive `ON CONFLICT DO NOTHING` would do). The stored
--    reply is replayed.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. The command log.
--
-- Separate from `offline_refill_events` on purpose: that table is the refill
-- funnel, and its `status`/`reject_reason` vocabulary is about money. Folding
-- balance checks into it would make every "how many refills were rejected"
-- query wrong. Deny-all — it holds raw sender phone numbers.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.offline_command_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider        text NOT NULL,
  provider_msg_id text NOT NULL,
  channel         text NOT NULL CHECK (channel IN ('whatsapp','sms','missed_call')),
  sender_phone    text,
  command         text NOT NULL
    CHECK (command IN ('balance','refill','help','stop','ignored')),
  user_id         uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reply_text      text,
  outcome         text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT offline_command_log_provider_msg_unique UNIQUE (provider, provider_msg_id)
);

CREATE INDEX IF NOT EXISTS offline_command_log_user_time_idx
  ON public.offline_command_log (user_id, created_at DESC);

ALTER TABLE public.offline_command_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.offline_command_log FROM PUBLIC, anon, authenticated;
GRANT ALL  ON TABLE public.offline_command_log TO service_role;

COMMENT ON TABLE public.offline_command_log IS
  'G9: every inbound SMS/WhatsApp command and the reply we sent. Deny-all by design (RLS on, zero policies) — it holds raw sender phone numbers. Unique on (provider, provider_msg_id) so a provider retry replays the same reply instead of re-running the command.';


-- ---------------------------------------------------------------------------
-- 2. The classifier.
--
-- Case- and whitespace-insensitive. Arabic keywords are included because the
-- Gulf/Egypt corridor is this product's largest user base; the other seven
-- supported locales fall back to the English keywords, which is a real gap and
-- is written up rather than papered over.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.classify_inbound_command(p_body text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $fn$
  SELECT CASE
    WHEN btrim(COALESCE(p_body, '')) = '' THEN 'help'
    WHEN upper(btrim(p_body)) ~ '^(STOP|UNSUBSCRIBE|CANCEL|QUIT|END)\M'      THEN 'stop'
    WHEN upper(btrim(p_body)) ~ '^(BAL|BALANCE|STATUS|INFO)\M'               THEN 'balance'
    WHEN btrim(p_body) LIKE 'رصيد%'                                          THEN 'balance'
    WHEN upper(btrim(p_body)) ~ '^(REFILL|TOPUP|TOP\s*UP|RECHARGE)\M'        THEN 'refill'
    WHEN btrim(p_body) LIKE 'شحن%'                                           THEN 'refill'
    -- A bare amount has always meant "refill me this much", and the app's own
    -- copy teaches "REFILL 5". Keep both working.
    WHEN btrim(p_body) ~ '^\$?\d+(\.\d{1,2})?$'                              THEN 'refill'
    WHEN upper(btrim(p_body)) ~ '^(HELP|H|\?)\M'                             THEN 'help'
    ELSE 'help'
  END;
$fn$;

COMMENT ON FUNCTION public.classify_inbound_command(text) IS
  'G9: what did this inbound message ask for? balance | refill | stop | help. Anything unrecognised is help — deliberately NOT refill, which is what the pre-G9 path did and is why texting "hi" used to queue a $10 top-up.';

REVOKE ALL ON FUNCTION public.classify_inbound_command(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.classify_inbound_command(text) TO service_role;


-- ---------------------------------------------------------------------------
-- 3. Sender → user, as ONE function that both the refill and balance paths
--    call, so they cannot disagree about who is texting.
--
-- 🔴 THE REASON THIS HAD TO CHANGE, NOT JUST MOVE.
-- `ingest_offline_refill` resolved the sender against `profiles.phone` alone.
-- **`profiles.phone` is NULL for all 8 users on this database, and nothing in
-- the Flutter app ever writes it** — the column is in `AuthModel` on the read
-- side only. So every inbound message that ever arrived would have been
-- rejected `unknown_sender`, and the C4 channel could never have worked for
-- anybody even after Twilio and WABA are provisioned. § 5 of the review
-- attributes the zero events to provisioning; this is the deeper reason, and
-- it was not written down anywhere.
--
-- So the resolver now falls back to `sim_lines.phone_number`, which IS
-- populated — all 10 live lines, all plausible international numbers, and no
-- number claimed by two users. Texting from a number you have registered as
-- your own SIM line is at least as strong a signal as a self-declared profile
-- phone, and it is the number the top-up is going to anyway.
--
-- The trust model is unchanged and worth stating plainly: this is caller-ID
-- trust over plaintext SMS. It is mitigated by requiring exactly one match,
-- by `offline_refill_settings.is_enabled` being an explicit opt-in that
-- defaults off, and by keeping the reply thin. It is not proof of identity,
-- and a verified-number flow (OTP at capture time) is the real fix — noted as
-- an owner item rather than pretended away here.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_sender_user(p_sender_phone text)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_norm text;
  v_uids uuid[];
BEGIN
  v_norm := regexp_replace(COALESCE(p_sender_phone, ''), '\D', '', 'g');
  IF v_norm = '' OR length(v_norm) < 9 THEN RETURN NULL; END IF;

  -- 1. The self-declared profile number, exact.
  SELECT array_agg(DISTINCT p.id) INTO v_uids
  FROM public.profiles p
  WHERE p.phone IS NOT NULL
    AND regexp_replace(p.phone, '\D', '', 'g') = v_norm;
  IF array_length(v_uids, 1) = 1 THEN RETURN v_uids[1]; END IF;
  IF array_length(v_uids, 1) > 1 THEN RETURN NULL; END IF;

  -- 2. The profile number, last nine digits — survives country-code and
  --    trunk-zero formatting differences.
  SELECT array_agg(DISTINCT p.id) INTO v_uids
  FROM public.profiles p
  WHERE p.phone IS NOT NULL
    AND length(regexp_replace(p.phone, '\D', '', 'g')) >= 9
    AND right(regexp_replace(p.phone, '\D', '', 'g'), 9) = right(v_norm, 9);
  IF array_length(v_uids, 1) = 1 THEN RETURN v_uids[1]; END IF;
  IF array_length(v_uids, 1) > 1 THEN RETURN NULL; END IF;

  -- 3. A SIM line the user registered, exact.
  SELECT array_agg(DISTINCT sl.user_id) INTO v_uids
  FROM public.sim_lines sl
  WHERE sl.phone_number IS NOT NULL
    AND regexp_replace(sl.phone_number, '\D', '', 'g') = v_norm;
  IF array_length(v_uids, 1) = 1 THEN RETURN v_uids[1]; END IF;
  IF array_length(v_uids, 1) > 1 THEN RETURN NULL; END IF;

  -- 4. A SIM line, last nine digits.
  SELECT array_agg(DISTINCT sl.user_id) INTO v_uids
  FROM public.sim_lines sl
  WHERE sl.phone_number IS NOT NULL
    AND length(regexp_replace(sl.phone_number, '\D', '', 'g')) >= 9
    AND right(regexp_replace(sl.phone_number, '\D', '', 'g'), 9) = right(v_norm, 9);
  IF array_length(v_uids, 1) = 1 THEN RETURN v_uids[1]; END IF;

  -- Ambiguous, or nothing. Guessing would show one person another person's
  -- balance, or spend their money. Refuse.
  RETURN NULL;
END $fn$;

COMMENT ON FUNCTION public.resolve_sender_user(text) IS
  'G9: which single user owns this phone number, or NULL. Tries profiles.phone (exact, then last-9) and then sim_lines.phone_number (exact, then last-9) — profiles.phone is NULL for every live user and the app never writes it, so without the sim_lines fallback the whole C4 channel resolves nobody. Ambiguous matches return NULL rather than guessing.';

REVOKE ALL ON FUNCTION public.resolve_sender_user(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_sender_user(text) TO service_role;

REVOKE ALL ON FUNCTION public.resolve_sender_user(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_sender_user(text) TO service_role;


-- ---------------------------------------------------------------------------
-- 4. The balance sentence.
--
-- Sized for SMS. Wallet, then up to three lines with days remaining from G1's
-- forecast, then a nudge. A line with no nickname is masked to its last four
-- digits — the reply travels in plaintext to whatever handset claimed that
-- caller ID.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.build_balance_reply(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_balance numeric;
  v_lines   text;
  v_total   integer;
  v_extra   integer;
BEGIN
  SELECT COALESCE(w.balance, 0) INTO v_balance
  FROM public.wallets w WHERE w.user_id = p_user_id;

  SELECT count(*) INTO v_total
  FROM public.sim_lines sl
  WHERE sl.user_id = p_user_id AND COALESCE(sl.status, 'active') = 'active';

  SELECT string_agg(t.label || ': ' || t.days, E'\n' ORDER BY t.ord)
  INTO v_lines
  FROM (
    SELECT
      COALESCE(
        NULLIF(sl.nickname, ''),
        CASE WHEN length(regexp_replace(sl.phone_number, '\D', '', 'g')) >= 4
             THEN '****' || right(regexp_replace(sl.phone_number, '\D', '', 'g'), 4)
             ELSE 'SIM' END
      ) AS label,
      CASE
        WHEN f.days_remaining IS NULL      THEN 'no estimate'
        WHEN f.days_remaining <= 0         THEN 'EXPIRED'
        WHEN f.days_remaining = 1          THEN '1 day left'
        ELSE f.days_remaining || ' days left'
      END AS days,
      COALESCE(f.days_remaining, 9999) AS ord
    FROM public.sim_lines sl
    LEFT JOIN public.sim_line_usage_forecast f
           ON f.sim_line_id = sl.id AND f.subject_kind = 'sim_line'
    WHERE sl.user_id = p_user_id AND COALESCE(sl.status, 'active') = 'active'
    ORDER BY COALESCE(f.days_remaining, 9999)
    LIMIT 3
  ) t;

  v_extra := GREATEST(COALESCE(v_total, 0) - 3, 0);

  RETURN 'KeepSIMs' || E'\n'
      || 'Wallet: $' || to_char(COALESCE(v_balance, 0), 'FM999990.00') || E'\n'
      || COALESCE(v_lines, 'No active SIM lines.')
      || CASE WHEN v_extra > 0 THEN E'\n+' || v_extra || ' more' ELSE '' END
      || E'\nReply REFILL to top up.';
END $fn$;

COMMENT ON FUNCTION public.build_balance_reply(uuid) IS
  'G9: the SMS body for a BAL request. Wallet total plus the three lines closest to running out. Nicknames or a ****1234 mask only — never a full number, an ICCID or a transaction, because SMS is plaintext and caller ID is spoofable.';

REVOKE ALL ON FUNCTION public.build_balance_reply(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.build_balance_reply(uuid) TO service_role;
