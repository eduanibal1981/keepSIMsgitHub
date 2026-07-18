-- ═══════════════════════════════════════════════════════════════════════════
-- C4 — Offline recharge: per-channel message fees + server-side ingestion
-- ═══════════════════════════════════════════════════════════════════════════
-- Offline recharge is always wallet-funded. The user's phone is offline, so the
-- request arrives out-of-band — a WhatsApp message, an SMS, or a missed call to
-- one of our numbers — and a webhook (Edge Function, service_role) turns it into
-- a real `topup_executions` row via `ingest_offline_refill` here. The client
-- never writes `topup_executions` (C3b-2 lockdown stays intact); the existing
-- BEFORE INSERT triggers price and route it and `worker_instant_refill` debits
-- the wallet and buys, exactly as for an in-app instant refill.
--
-- The one new cost: the official WhatsApp Business API / SMS gateway / Twilio
-- voice number each bill us per inbound message. That per-channel fee is passed
-- through to the wallet the same way the app fee is — configured in the DB, one
-- row per channel, tunable with no redeploy.

-- ── 1. Per-channel offline message-fee configs ──────────────────────────────
-- Small defaults; a power user tunes them in the dashboard. Kept as free text
-- like every other system_configs row so the app reads one source of truth.
INSERT INTO public.system_configs (config_key, config_value) VALUES
  ('OFFLINE_WHATSAPP_MESSAGE_FEE_USD', '0.05'),
  ('OFFLINE_SMS_MESSAGE_FEE_USD',      '0.03'),
  ('OFFLINE_MISSED_CALL_FEE_USD',      '0.02')
ON CONFLICT (config_key) DO NOTHING;

-- ── 2. topup_executions: which offline channel triggered this, and its fee ──
-- NULL for every normal (in-app / scheduled) refill, so the amount math below is
-- unchanged for them.
ALTER TABLE public.topup_executions
  ADD COLUMN IF NOT EXISTS refill_channel text
    CHECK (refill_channel IN ('whatsapp','sms','missed_call')),
  ADD COLUMN IF NOT EXISTS message_fee_usd numeric;

-- ── 3. Fold the per-channel message fee into the fee trigger ─────────────────
-- Same defensive parse as APP_FEE_PERCENT: a typo in the config row must fall
-- back to 0, never abort the refill insert. A NULL channel adds nothing, so the
-- amount for every existing refill path is byte-identical.
CREATE OR REPLACE FUNCTION public.calculate_topup_fees()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    pm                RECORD;
    v_app_fee_percent numeric;
    v_msg_fee         numeric;
    v_msg_fee_key     text;
BEGIN
    IF NEW.payment_gateway_code IS NOT NULL AND NEW.base_cost_usd IS NOT NULL THEN
        SELECT * INTO pm FROM public.payment_gateways WHERE code = NEW.payment_gateway_code;

        IF FOUND THEN
            -- config_value is free-text, so a typo must not break every refill
            -- insert: fall back to 3 rather than raising. The same guard rejects
            -- a nonsense rate outside 0–100.
            BEGIN
                SELECT config_value::numeric INTO v_app_fee_percent
                FROM public.system_configs
                WHERE config_key = 'APP_FEE_PERCENT';
            EXCEPTION WHEN others THEN
                v_app_fee_percent := NULL;
            END;

            IF v_app_fee_percent IS NULL
               OR v_app_fee_percent < 0
               OR v_app_fee_percent > 100 THEN
                v_app_fee_percent := 3;
            END IF;

            -- Per-channel offline message fee: the WhatsApp Business API, the SMS
            -- gateway and the Twilio voice number each cost us per inbound
            -- message. Deducted from the wallet the same way the app fee is.
            -- NULL channel (every in-app / scheduled refill) means no fee; a bad
            -- or absent config row falls back to 0 rather than aborting.
            v_msg_fee := 0;
            IF NEW.refill_channel IS NOT NULL THEN
                v_msg_fee_key := CASE NEW.refill_channel
                    WHEN 'whatsapp'    THEN 'OFFLINE_WHATSAPP_MESSAGE_FEE_USD'
                    WHEN 'sms'         THEN 'OFFLINE_SMS_MESSAGE_FEE_USD'
                    WHEN 'missed_call' THEN 'OFFLINE_MISSED_CALL_FEE_USD'
                END;
                BEGIN
                    SELECT config_value::numeric INTO v_msg_fee
                    FROM public.system_configs
                    WHERE config_key = v_msg_fee_key;
                EXCEPTION WHEN others THEN
                    v_msg_fee := NULL;
                END;
                IF v_msg_fee IS NULL OR v_msg_fee < 0 OR v_msg_fee > 100 THEN
                    v_msg_fee := 0;
                END IF;
            END IF;

            NEW.gateway_fee_usd := ROUND((NEW.base_cost_usd * (pm.fee_percentage / 100.0) + pm.fee_fixed), 2);
            NEW.app_fee_usd     := ROUND((NEW.base_cost_usd * (v_app_fee_percent / 100.0)), 2);
            NEW.message_fee_usd := ROUND(v_msg_fee, 2);
            NEW.amount          := ROUND(NEW.base_cost_usd + NEW.gateway_fee_usd + NEW.app_fee_usd + NEW.message_fee_usd, 2);
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;

-- ── 4. Inbound inbox / dedupe / audit for offline events ────────────────────
-- Every webhook hit lands here first: it is the idempotency key (a provider can
-- redeliver the same message) and the audit trail of what we did with it.
-- service_role only — clients never read the raw inbound stream.
CREATE TABLE IF NOT EXISTS public.offline_refill_events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider        text NOT NULL CHECK (provider IN ('whatsapp','sms','twilio')),
  provider_msg_id text NOT NULL,
  channel         text NOT NULL CHECK (channel IN ('whatsapp','sms','missed_call')),
  sender_phone    text,
  raw             jsonb NOT NULL DEFAULT '{}'::jsonb,
  user_id         uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  sim_line_id     uuid REFERENCES public.sim_lines(id) ON DELETE SET NULL,
  execution_id    uuid REFERENCES public.topup_executions(id) ON DELETE SET NULL,
  status          text NOT NULL DEFAULT 'received'
                  CHECK (status IN ('received','queued','rejected')),
  reject_reason   text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_msg_id)
);

ALTER TABLE public.offline_refill_events ENABLE ROW LEVEL SECURITY;
-- No policies on purpose: only service_role (Edge Functions / workers) touches
-- this. Revoke the default client grants so an authenticated user cannot read
-- other users' inbound numbers.
REVOKE ALL ON public.offline_refill_events FROM anon, authenticated;

CREATE INDEX IF NOT EXISTS idx_offline_refill_events_user
  ON public.offline_refill_events (user_id, created_at DESC);

-- ── 5. The ingestion RPC ────────────────────────────────────────────────────
-- Called only by the offline webhooks (service_role). Resolves the sender phone
-- to a user, finds their target line and the carrier's admin-pinned offer,
-- prices it from the server-side cache (same C3b-1 anti-tamper + 24h freshness
-- guard as request_instant_refill), and inserts a wallet-funded instant refill
-- tagged with the channel so calculate_topup_fees adds the message fee. Every
-- outcome — queued or rejected with a reason — is recorded on the event row, so
-- a webhook never has to decide policy and never 500s on an expected rejection.
CREATE OR REPLACE FUNCTION public.ingest_offline_refill(
  p_provider        text,
  p_provider_msg_id text,
  p_sender_phone    text,
  p_channel         text,
  p_amount_usd      numeric DEFAULT NULL,
  p_raw             jsonb   DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_event_id     uuid;
  v_norm_phone   text;
  v_user_id      uuid;
  v_uids         uuid[];
  v_line_id      uuid;
  v_line_ids     uuid[];
  v_iso          text;
  v_zen_carrier  text;
  v_offer_id     text;
  v_offer        RECORD;
  v_base         numeric;
  v_value        numeric;
  v_amount_req   numeric;
  v_default_amt  numeric;
  v_enabled      boolean;
  v_execution_id uuid;
  v_existing     RECORD;
BEGIN
  IF p_channel NOT IN ('whatsapp','sms','missed_call') THEN
    RAISE EXCEPTION 'Unknown offline channel %', p_channel;
  END IF;

  -- Idempotency: one event per (provider, provider_msg_id). A redelivery returns
  -- the first outcome instead of queuing a second refill.
  SELECT * INTO v_existing
  FROM public.offline_refill_events
  WHERE provider = p_provider AND provider_msg_id = p_provider_msg_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'status', 'duplicate',
      'event_id', v_existing.id,
      'execution_id', v_existing.execution_id,
      'original_status', v_existing.status
    );
  END IF;

  INSERT INTO public.offline_refill_events
    (provider, provider_msg_id, channel, sender_phone, raw)
  VALUES
    (p_provider, p_provider_msg_id, p_channel, p_sender_phone, COALESCE(p_raw, '{}'::jsonb))
  RETURNING id INTO v_event_id;

  -- Normalise the sender to bare digits so "+968…", "00968…" and "968…" all
  -- compare equal to a stored profiles.phone.
  v_norm_phone := regexp_replace(COALESCE(p_sender_phone,''), '\D', '', 'g');
  IF v_norm_phone = '' THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='no_sender' WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','no_sender','event_id',v_event_id);
  END IF;

  -- Strong match first: identical normalised digits. Then an unambiguous match
  -- on the trailing 9 digits (absorbs country-code / formatting drift). If the
  -- trailing-digit match is ambiguous we reject rather than risk debiting the
  -- wrong person's wallet.
  SELECT array_agg(p.id) INTO v_uids
  FROM public.profiles p
  WHERE p.phone IS NOT NULL
    AND regexp_replace(p.phone,'\D','','g') = v_norm_phone;
  IF v_uids IS NOT NULL AND array_length(v_uids,1) = 1 THEN
    v_user_id := v_uids[1];
  ELSIF v_uids IS NULL OR array_length(v_uids,1) = 0 THEN
    SELECT array_agg(p.id) INTO v_uids
    FROM public.profiles p
    WHERE p.phone IS NOT NULL
      AND length(regexp_replace(p.phone,'\D','','g')) >= 9
      AND right(regexp_replace(p.phone,'\D','','g'), 9) = right(v_norm_phone, 9);
    IF v_uids IS NOT NULL AND array_length(v_uids,1) = 1 THEN
      v_user_id := v_uids[1];
    END IF;
  END IF;

  IF v_user_id IS NULL THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='unknown_sender' WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','unknown_sender','event_id',v_event_id);
  END IF;

  UPDATE public.offline_refill_events SET user_id = v_user_id WHERE id = v_event_id;

  -- Offline recharge must be enabled; the settings row carries the target line
  -- and the default amount.
  SELECT COALESCE(s.is_enabled,false), s.target_sim_line_id, COALESCE(s.default_refill_amount,10.00)
  INTO v_enabled, v_line_id, v_default_amt
  FROM public.offline_refill_settings s
  WHERE s.user_id = v_user_id;

  IF v_enabled IS DISTINCT FROM true THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='disabled' WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','disabled','event_id',v_event_id);
  END IF;

  -- Target line: the configured one (must be owned), else the user's single
  -- active line, else reject as ambiguous.
  IF v_line_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.sim_lines sl
                     WHERE sl.id = v_line_id AND sl.user_id = v_user_id) THEN
    v_line_id := NULL;
  END IF;

  IF v_line_id IS NULL THEN
    SELECT array_agg(sl.id) INTO v_line_ids
    FROM public.sim_lines sl
    WHERE sl.user_id = v_user_id AND COALESCE(sl.status,'active') = 'active';
    IF v_line_ids IS NOT NULL AND array_length(v_line_ids,1) = 1 THEN
      v_line_id := v_line_ids[1];
    END IF;
  END IF;

  IF v_line_id IS NULL THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='no_target' WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','no_target','event_id',v_event_id);
  END IF;

  -- The line's catalog coordinates + the carrier's admin-pinned offer.
  SELECT co.iso_code, ca.zen_carrier, cr.offer_id
  INTO v_iso, v_zen_carrier, v_offer_id
  FROM public.sim_lines sl
  JOIN public.countries co ON co.id = sl.country_id
  JOIN public.carriers ca ON ca.id = sl.carrier_id
  LEFT JOIN LATERAL (
    SELECT crx.offer_id
    FROM public.carrier_rules crx
    WHERE crx.carrier_id = sl.carrier_id AND crx.offer_id IS NOT NULL
    ORDER BY (crx.rule_type = 'default') DESC, crx.updated_at DESC
    LIMIT 1
  ) cr ON true
  WHERE sl.id = v_line_id;

  IF v_zen_carrier IS NULL OR v_offer_id IS NULL THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='no_offer', sim_line_id=v_line_id WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','no_offer','event_id',v_event_id);
  END IF;

  -- Price the pinned offer from the server-side cache (same guards as
  -- request_instant_refill).
  SELECT * INTO v_offer
  FROM public.zendit_offers_cache z
  WHERE z.offer_id = v_offer_id AND z.country_code = v_iso AND z.zen_carrier = v_zen_carrier;

  IF NOT FOUND THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='offer_unavailable', sim_line_id=v_line_id WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','offer_unavailable','event_id',v_event_id);
  END IF;

  IF v_offer.refreshed_at < now() - interval '24 hours' THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='pricing_stale', sim_line_id=v_line_id WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','pricing_stale','event_id',v_event_id);
  END IF;

  v_amount_req := COALESCE(p_amount_usd, v_default_amt);

  IF v_offer.price_type = 'FIXED' THEN
    v_base := v_offer.price_fixed_usd;
    v_value := NULL;
  ELSE
    -- RANGE: clamp the requested/default amount into the offer's bounds and
    -- interpolate the send value (same math as offer_validation.js).
    v_base := round(v_amount_req, 2);
    IF v_base < v_offer.price_min_usd THEN v_base := v_offer.price_min_usd; END IF;
    IF v_base > v_offer.price_max_usd THEN v_base := v_offer.price_max_usd; END IF;
    v_value := least(v_offer.send_max, greatest(v_offer.send_min, round(
      v_offer.send_min
      + CASE WHEN v_offer.price_max_usd - v_offer.price_min_usd > 0
             THEN (v_base - v_offer.price_min_usd)
                  * (v_offer.send_max - v_offer.send_min)
                  / (v_offer.price_max_usd - v_offer.price_min_usd)
             ELSE 0 END)));
  END IF;

  IF v_base IS NULL OR v_base <= 0 THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='no_price', sim_line_id=v_line_id WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','no_price','event_id',v_event_id);
  END IF;

  -- Queue the refill. payment_gateway_code='wallet' → 0% gateway fee; the
  -- BEFORE INSERT triggers add the 3% app fee + this channel's message fee and
  -- bump it to 'routing'. worker_instant_refill re-validates the offer against
  -- the cache and debits the wallet. An expected guard (10s/line rate limit,
  -- positive-amount check) is recorded, not raised.
  BEGIN
    INSERT INTO public.topup_executions (
      sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code,
      currency, status, execution_type, execution_time, offer_id, offer_value, refill_channel
    ) VALUES (
      v_line_id, v_user_id, v_base, v_base, 'wallet',
      'USD', 'pending', 'refill_instant', now(), v_offer_id,
      CASE WHEN v_value IS NULL THEN NULL ELSE v_value::bigint END, p_channel
    )
    RETURNING id INTO v_execution_id;
  EXCEPTION WHEN others THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason = left('insert_failed: '||sqlerrm, 200), sim_line_id=v_line_id
      WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','insert_failed','detail',sqlerrm,'event_id',v_event_id);
  END;

  UPDATE public.offline_refill_events
    SET status='queued', sim_line_id=v_line_id, execution_id=v_execution_id
    WHERE id = v_event_id;

  RETURN jsonb_build_object(
    'status','queued','event_id',v_event_id,'execution_id',v_execution_id,
    'sim_line_id',v_line_id,'base_cost_usd',v_base,'channel',p_channel
  );
END;
$function$;

-- Only the webhooks (service_role) may call this — it queues wallet spend for an
-- arbitrary user resolved by phone, which no client role may do.
REVOKE ALL ON FUNCTION public.ingest_offline_refill(text,text,text,text,numeric,jsonb) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ingest_offline_refill(text,text,text,text,numeric,jsonb) TO service_role;
