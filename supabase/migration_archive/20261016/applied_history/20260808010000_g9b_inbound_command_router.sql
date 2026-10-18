-- ============================================================================
-- G9b — The inbound command router.
--
-- One entry point for both webhooks. It classifies, acts, logs and returns the
-- exact text to send back, so SMS and WhatsApp cannot drift into two dialects
-- and the wording is testable in SQL rather than only in Deno.
--
-- ⚠️ THIS CHANGES BEHAVIOUR ON A MONEY PATH, ON PURPOSE.
-- Before G9, `sms-webhook` and `waba-webhook` passed every inbound message
-- straight to `ingest_offline_refill()`, which never looked at the body except
-- to regex out a number. "hi", "stop", "who is this" and "BAL" all fell through
-- to `default_refill_amount` and queued a **$10 top-up**. After G9 only
-- `REFILL` (with or without an amount) or a bare amount spends money — which is
-- exactly, and only, what the app has always told users to send
-- (`app_en.arb`: *Send REFILL 5, REFILL 10 or REFILL 25*).
--
-- The other thing that used to buy a top-up was **STOP**. It now does what
-- every messaging regulator on earth expects it to do.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_inbound_command(
  p_provider        text,
  p_provider_msg_id text,
  p_sender_phone    text,
  p_channel         text,
  p_body            text,
  p_raw             jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_existing  RECORD;
  v_command   text;
  v_user_id   uuid;
  v_enabled   boolean;
  v_reply     text;
  v_outcome   text;
  v_amount    numeric;
  v_ingest    jsonb;
  v_limit     RECORD;
  v_label     text;
BEGIN
  IF p_channel NOT IN ('whatsapp','sms','missed_call') THEN
    RAISE EXCEPTION 'Unknown offline channel %', p_channel;
  END IF;

  -- ── Idempotency. Providers retry; a retry must replay the same answer, not
  --    re-run the command and not fall silent. ─────────────────────────────
  SELECT * INTO v_existing
  FROM public.offline_command_log
  WHERE provider = p_provider AND provider_msg_id = p_provider_msg_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'status', 'duplicate', 'command', v_existing.command,
      'reply_text', v_existing.reply_text, 'user_id', v_existing.user_id);
  END IF;

  v_command := public.classify_inbound_command(p_body);
  v_user_id := public.resolve_sender_user(p_sender_phone);

  -- ── An unknown sender gets silence. Replying would turn this number into an
  --    oracle for "is this phone a KeepSIMs user?", and bill us for an SMS to
  --    a stranger. Logged, not answered. ───────────────────────────────────
  IF v_user_id IS NULL THEN
    INSERT INTO public.offline_command_log
      (provider, provider_msg_id, channel, sender_phone, command, user_id, reply_text, outcome)
    VALUES (p_provider, p_provider_msg_id, p_channel, p_sender_phone, 'ignored', NULL, NULL, 'unknown_sender');
    RETURN jsonb_build_object('status','ignored','command','ignored','reply_text',NULL);
  END IF;

  -- ── Per-sender rate limit. Not the IP limiter the webhooks already apply:
  --    one spoofed caller ID behind many IPs is the case that matters, and an
  --    unbounded reply loop is a bill. Over the limit we go quiet rather than
  --    answer "you are rate limited", which would itself be a reply per
  --    message. `consume_rate_limit` is called directly, never
  --    `enforce_rate_limit`, whose `WHEN OTHERS THEN RAISE NOTICE` would
  --    swallow a failure here and fail open.
  SELECT * INTO v_limit
  FROM public.consume_rate_limit('offline_command', v_user_id::text, 10, 10.0/60.0, clock_timestamp());

  IF v_limit.allowed IS DISTINCT FROM true THEN
    INSERT INTO public.offline_command_log
      (provider, provider_msg_id, channel, sender_phone, command, user_id, reply_text, outcome)
    VALUES (p_provider, p_provider_msg_id, p_channel, p_sender_phone, v_command, v_user_id, NULL, 'rate_limited');
    RETURN jsonb_build_object('status','rate_limited','command',v_command,'reply_text',NULL);
  END IF;

  SELECT COALESCE(s.is_enabled, false) INTO v_enabled
  FROM public.offline_refill_settings s WHERE s.user_id = v_user_id;
  v_enabled := COALESCE(v_enabled, false);

  -- ── STOP always works, enabled or not. It is the one command a messaging
  --    channel is never allowed to ignore — and before G9 it queued $10. ───
  IF v_command = 'stop' THEN
    UPDATE public.offline_refill_settings SET is_enabled = false, updated_at = now()
     WHERE user_id = v_user_id;
    v_reply := 'KeepSIMs: offline SMS commands are now OFF for this number. Turn them back on in the app.';
    v_outcome := 'stopped';

  ELSIF NOT v_enabled THEN
    -- The same consent that governs spending governs disclosing. We do not
    -- discuss someone's money over a channel they have not switched on.
    v_reply := 'KeepSIMs: offline SMS commands are switched off. Enable Offline Refill in the app to use BAL or REFILL.';
    v_outcome := 'channel_disabled';

  ELSIF v_command = 'balance' THEN
    v_reply := public.build_balance_reply(v_user_id);
    v_outcome := 'answered';

  ELSIF v_command = 'refill' THEN
    -- Amount parsing moved into the database so both channels agree on it.
    -- `regexp_match` returns NULL when there is no number, which is the "use
    -- the user's default_refill_amount" signal ingest_offline_refill expects.
    v_amount := (regexp_match(COALESCE(p_body, ''), '([0-9]+(?:\.[0-9]{1,2})?)'))[1]::numeric;
    IF v_amount IS NOT NULL AND (v_amount <= 0 OR v_amount > 500) THEN
      v_amount := NULL;
    END IF;

    v_ingest := public.ingest_offline_refill(
      p_provider => p_provider, p_provider_msg_id => p_provider_msg_id,
      p_sender_phone => p_sender_phone, p_channel => p_channel,
      p_amount_usd => v_amount, p_raw => p_raw);

    SELECT COALESCE(NULLIF(sl.nickname,''), 'your SIM') INTO v_label
    FROM public.sim_lines sl WHERE sl.id = (v_ingest ->> 'sim_line_id')::uuid;

    v_outcome := COALESCE(v_ingest ->> 'status', 'unknown');
    v_reply := CASE v_outcome
      WHEN 'queued'    THEN 'KeepSIMs: top-up of $'
                            || to_char(COALESCE((v_ingest ->> 'base_cost_usd')::numeric, 0), 'FM999990.00')
                            || ' queued for ' || COALESCE(v_label, 'your SIM')
                            || '. We will confirm when it completes.'
      WHEN 'duplicate' THEN 'KeepSIMs: we already have that request in hand.'
      ELSE CASE v_ingest ->> 'reason'
        WHEN 'no_target'         THEN 'KeepSIMs: we could not tell which SIM to top up. Pick a default line in the app.'
        WHEN 'no_offer'          THEN 'KeepSIMs: top-ups are not available for that line yet.'
        WHEN 'offer_unavailable' THEN 'KeepSIMs: top-ups for that line are unavailable right now. Please try again later.'
        WHEN 'pricing_stale'     THEN 'KeepSIMs: pricing is temporarily unavailable. Please try again shortly.'
        WHEN 'disabled'          THEN 'KeepSIMs: offline SMS commands are switched off. Enable Offline Refill in the app.'
        ELSE 'KeepSIMs: we could not start that top-up. Please try from the app.'
      END
    END;

  ELSE
    v_reply := 'KeepSIMs commands: BAL for your balance, REFILL or REFILL 10 to top up, STOP to switch these off.';
    v_outcome := 'helped';
  END IF;

  INSERT INTO public.offline_command_log
    (provider, provider_msg_id, channel, sender_phone, command, user_id, reply_text, outcome)
  VALUES (p_provider, p_provider_msg_id, p_channel, p_sender_phone, v_command, v_user_id, v_reply, v_outcome);

  RETURN jsonb_build_object(
    'status', 'handled', 'command', v_command, 'outcome', v_outcome,
    'reply_text', v_reply, 'user_id', v_user_id);
END $fn$;

COMMENT ON FUNCTION public.handle_inbound_command(text, text, text, text, text, jsonb) IS
  'G9: the single entry point for inbound SMS/WhatsApp. Classifies the body, acts, logs, and returns the reply text for the webhook to send. Only REFILL or a bare amount spends money — before G9 every message did. Idempotent on (provider, provider_msg_id): a retry replays the stored reply.';

REVOKE ALL     ON FUNCTION public.handle_inbound_command(text, text, text, text, text, jsonb) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.handle_inbound_command(text, text, text, text, text, jsonb) TO service_role;

INSERT INTO public.system_configs (config_key, config_value)
VALUES ('RATE_LIMIT_OFFLINE_COMMAND', '10/60')
ON CONFLICT (config_key) DO NOTHING;
