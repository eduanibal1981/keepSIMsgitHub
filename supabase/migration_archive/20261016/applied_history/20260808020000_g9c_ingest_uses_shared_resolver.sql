-- ============================================================================
-- G9c — `ingest_offline_refill` now uses the shared sender resolver.
--
-- It carried its own inline copy of the "who is texting us?" logic. Two copies
-- of that question on a money path is one too many, and — more to the point —
-- the copy it had matched only `profiles.phone`, which is NULL for all 8 users
-- and is never written by the app. Left alone, `BAL` would resolve senders via
-- the new `sim_lines.phone_number` fallback while `REFILL` from the same
-- handset would still come back `unknown_sender`. Half a working channel is
-- worse than none, because only one half of it is testable.
--
-- The whole function is restated so the deployed body is unambiguous. The diff
-- against the pre-G9 definition is exactly the resolution block collapsing
-- into `v_user_id := public.resolve_sender_user(p_sender_phone);`. Every guard,
-- rejection reason, price clamp and idempotency check is byte-identical.
-- ============================================================================

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
SET search_path = public
AS $fn$
DECLARE
  v_event_id     uuid;
  v_user_id      uuid;
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

  SELECT * INTO v_existing
  FROM public.offline_refill_events
  WHERE provider = p_provider AND provider_msg_id = p_provider_msg_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'status', 'duplicate', 'event_id', v_existing.id,
      'execution_id', v_existing.execution_id, 'original_status', v_existing.status);
  END IF;

  INSERT INTO public.offline_refill_events
    (provider, provider_msg_id, channel, sender_phone, raw)
  VALUES
    (p_provider, p_provider_msg_id, p_channel, p_sender_phone, COALESCE(p_raw, '{}'::jsonb))
  RETURNING id INTO v_event_id;

  IF regexp_replace(COALESCE(p_sender_phone,''), '\D', '', 'g') = '' THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='no_sender' WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','no_sender','event_id',v_event_id);
  END IF;

  -- G9: one resolver, shared with handle_inbound_command().
  v_user_id := public.resolve_sender_user(p_sender_phone);

  IF v_user_id IS NULL THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='unknown_sender' WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','unknown_sender','event_id',v_event_id);
  END IF;

  UPDATE public.offline_refill_events SET user_id = v_user_id WHERE id = v_event_id;

  SELECT COALESCE(s.is_enabled,false), s.target_sim_line_id, COALESCE(s.default_refill_amount,10.00)
  INTO v_enabled, v_line_id, v_default_amt
  FROM public.offline_refill_settings s
  WHERE s.user_id = v_user_id;

  IF v_enabled IS DISTINCT FROM true THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='disabled' WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','disabled','event_id',v_event_id);
  END IF;

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

  SELECT co.iso_code, ca.zen_carrier, cr.offer_id
  INTO v_iso, v_zen_carrier, v_offer_id
  FROM public.sim_lines sl
  JOIN public.countries co ON co.id = sl.country_id
  JOIN public.carriers ca ON ca.id = sl.carrier_id
  LEFT JOIN LATERAL (
    SELECT crx.offer_id FROM public.carrier_rules crx
    WHERE crx.carrier_id = sl.carrier_id AND crx.offer_id IS NOT NULL
    ORDER BY (crx.rule_type = 'default') DESC, crx.updated_at DESC LIMIT 1
  ) cr ON true
  WHERE sl.id = v_line_id;

  IF v_zen_carrier IS NULL OR v_offer_id IS NULL THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='no_offer', sim_line_id=v_line_id WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','no_offer','event_id',v_event_id);
  END IF;

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
    'sim_line_id',v_line_id,'base_cost_usd',v_base,'channel',p_channel);
END $fn$;

REVOKE ALL     ON FUNCTION public.ingest_offline_refill(text, text, text, text, numeric, jsonb) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.ingest_offline_refill(text, text, text, text, numeric, jsonb) TO service_role;
