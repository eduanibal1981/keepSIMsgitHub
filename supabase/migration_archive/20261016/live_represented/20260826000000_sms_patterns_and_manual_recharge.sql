-- ============================================================================
-- 20260826000000_sms_patterns_and_manual_recharge.sql
--
-- 1. Extend carrier_rules with SMS Ingestion & Balance Patterns (Admin configurable)
-- 2. Update admin_update_carrier_rule to accept SMS pattern configurations
-- 3. Add record_manual_external_recharge RPC to log external recharges & update last_topup_at
-- ============================================================================

-- 1. Extend carrier_rules
ALTER TABLE public.carrier_rules
  ADD COLUMN IF NOT EXISTS sms_sender_ids text[],
  ADD COLUMN IF NOT EXISTS sms_balance_regex text,
  ADD COLUMN IF NOT EXISTS sms_expiry_regex text,
  ADD COLUMN IF NOT EXISTS sms_keywords text[],
  ADD COLUMN IF NOT EXISTS sms_language text DEFAULT 'auto';

-- 2. Update admin_update_carrier_rule to allow new fields
CREATE OR REPLACE FUNCTION public.admin_update_carrier_rule(
  p_carrier_id uuid,
  p_patch      jsonb,
  p_note       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_allowed text[] := ARRAY['minimum_topup_amount','recommended_topup_amount','topup_validity_days',
                            'inactivity_limit_days','grace_period_days','notes','inapp_pricing',
                            'offer_id','offer_value','sms_sender_ids','sms_balance_regex',
                            'sms_expiry_regex','sms_keywords','sms_language',
                            'activity_requirement','validity_qualifying_topup_amount',
                            'activity_requirement_note','balance_validity_days',
                            'refill_interval_days_override','rule_source_url'];
  v_bad     text;
  v_before  jsonb;
  v_after   jsonb;
BEGIN
  PERFORM public.assert_admin();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Nothing to change' USING ERRCODE = 'KS467';
  END IF;

  SELECT string_agg(k, ', ') INTO v_bad
  FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'Unknown field(s): %', v_bad USING ERRCODE = 'KS467';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.carriers WHERE id = p_carrier_id) THEN
    RAISE EXCEPTION 'Carrier % not found', p_carrier_id USING ERRCODE = 'KS461';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.carrier_rules WHERE carrier_id = p_carrier_id) THEN
    INSERT INTO public.carrier_rules
      (carrier_id, rule_type, inactivity_limit_days, minimum_topup_amount, topup_validity_days)
    VALUES
      (p_carrier_id, 'prepaid', 90, 1.00, 90);
  END IF;

  SELECT to_jsonb(cr) INTO v_before FROM public.carrier_rules cr WHERE cr.carrier_id = p_carrier_id;

  UPDATE public.carrier_rules SET
    minimum_topup_amount     = COALESCE(CASE WHEN p_patch ? 'minimum_topup_amount'
                                    THEN (p_patch ->> 'minimum_topup_amount')::numeric
                                    ELSE minimum_topup_amount END, minimum_topup_amount),
    recommended_topup_amount = CASE WHEN p_patch ? 'recommended_topup_amount'
                                    THEN (p_patch ->> 'recommended_topup_amount')::numeric
                                    ELSE recommended_topup_amount END,
    topup_validity_days      = COALESCE(CASE WHEN p_patch ? 'topup_validity_days'
                                    THEN (p_patch ->> 'topup_validity_days')::integer
                                    ELSE topup_validity_days END, topup_validity_days),
    inactivity_limit_days    = COALESCE(CASE WHEN p_patch ? 'inactivity_limit_days'
                                    THEN (p_patch ->> 'inactivity_limit_days')::integer
                                    ELSE inactivity_limit_days END, inactivity_limit_days),
    grace_period_days        = CASE WHEN p_patch ? 'grace_period_days'
                                    THEN (p_patch ->> 'grace_period_days')::integer
                                    ELSE grace_period_days END,
    inapp_pricing            = CASE WHEN p_patch ? 'inapp_pricing'
                                    THEN (p_patch ->> 'inapp_pricing')::numeric
                                    ELSE inapp_pricing END,
    offer_id                 = CASE WHEN p_patch ? 'offer_id'
                                    THEN NULLIF(btrim(p_patch ->> 'offer_id'), '')
                                    ELSE offer_id END,
    offer_value              = CASE WHEN p_patch ? 'offer_value'
                                    THEN (p_patch ->> 'offer_value')::bigint
                                    ELSE offer_value END,
    notes                    = CASE WHEN p_patch ? 'notes'
                                    THEN NULLIF(btrim(p_patch ->> 'notes'), '')
                                    ELSE notes END,
    sms_sender_ids           = CASE WHEN p_patch ? 'sms_sender_ids'
                                    THEN ARRAY(SELECT jsonb_array_elements_text(p_patch -> 'sms_sender_ids'))
                                    ELSE sms_sender_ids END,
    sms_balance_regex        = CASE WHEN p_patch ? 'sms_balance_regex'
                                    THEN NULLIF(btrim(p_patch ->> 'sms_balance_regex'), '')
                                    ELSE sms_balance_regex END,
    sms_expiry_regex         = CASE WHEN p_patch ? 'sms_expiry_regex'
                                    THEN NULLIF(btrim(p_patch ->> 'sms_expiry_regex'), '')
                                    ELSE sms_expiry_regex END,
    sms_keywords             = CASE WHEN p_patch ? 'sms_keywords'
                                    THEN ARRAY(SELECT jsonb_array_elements_text(p_patch -> 'sms_keywords'))
                                    ELSE sms_keywords END,
    sms_language             = CASE WHEN p_patch ? 'sms_language'
                                    THEN COALESCE(NULLIF(btrim(p_patch ->> 'sms_language'), ''), 'auto')
                                    ELSE sms_language END,
    activity_requirement     = CASE WHEN p_patch ? 'activity_requirement'
                                    THEN NULLIF(btrim(p_patch ->> 'activity_requirement'), '')
                                    ELSE activity_requirement END,
    validity_qualifying_topup_amount = CASE WHEN p_patch ? 'validity_qualifying_topup_amount'
                                    THEN (p_patch ->> 'validity_qualifying_topup_amount')::numeric
                                    ELSE validity_qualifying_topup_amount END,
    activity_requirement_note= CASE WHEN p_patch ? 'activity_requirement_note'
                                    THEN NULLIF(btrim(p_patch ->> 'activity_requirement_note'), '')
                                    ELSE activity_requirement_note END,
    balance_validity_days    = CASE WHEN p_patch ? 'balance_validity_days'
                                    THEN (p_patch ->> 'balance_validity_days')::integer
                                    ELSE balance_validity_days END,
    refill_interval_days_override = CASE WHEN p_patch ? 'refill_interval_days_override'
                                    THEN (p_patch ->> 'refill_interval_days_override')::integer
                                    ELSE refill_interval_days_override END,
    rule_source_url          = CASE WHEN p_patch ? 'rule_source_url'
                                    THEN NULLIF(btrim(p_patch ->> 'rule_source_url'), '')
                                    ELSE rule_source_url END,
    last_verified_at         = now(),
    updated_at               = now()
  WHERE carrier_id = p_carrier_id;

  SELECT to_jsonb(cr) INTO v_after FROM public.carrier_rules cr WHERE cr.carrier_id = p_carrier_id;

  PERFORM public.admin_log(
    'carrier_rule.update', 'carrier_rule', p_carrier_id::text,
    v_before, v_after,
    COALESCE(p_note, 'via admin app')
  );

  RETURN jsonb_build_object('success', true, 'carrier_id', p_carrier_id, 'updated', v_after);
END;
$$;

-- 3. Add RPC to record a manual external recharge
CREATE OR REPLACE FUNCTION public.record_manual_external_recharge(
  p_sim_line_id     uuid,
  p_recharge_date   timestamptz DEFAULT now(),
  p_amount          numeric     DEFAULT NULL,
  p_note            text        DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_line RECORD;
  v_user_id uuid;
  v_exec_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'KS401';
  END IF;

  SELECT * INTO v_line
  FROM public.sim_lines
  WHERE id = p_sim_line_id
    AND (user_id = v_user_id
         OR EXISTS (
           SELECT 1 FROM public.household_members hm
           WHERE hm.owner_id = sim_lines.user_id
             AND hm.member_id = v_user_id
             AND hm.invite_status = 'accepted'
             AND hm.role = 'manager'
         ));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'SIM line not found or unauthorized' USING ERRCODE = 'KS404';
  END IF;

  -- 1. Insert completed topup_execution record for history & triggers
  INSERT INTO public.topup_executions (
    sim_line_id,
    user_id,
    amount,
    base_cost_usd,
    gateway_fee_usd,
    app_fee_usd,
    status,
    execution_type,
    payment_gateway_code,
    execution_time,
    executed_at,
    completed_at,
    notes,
    error_message
  ) VALUES (
    p_sim_line_id,
    v_line.user_id,
    COALESCE(p_amount, 0.00),
    COALESCE(p_amount, 0.00),
    0.00,
    0.00,
    'completed',
    'manual_external',
    'EXTERNAL',
    p_recharge_date,
    p_recharge_date,
    p_recharge_date,
    COALESCE(p_note, 'Manual external recharge logged by user'),
    NULL
  )
  RETURNING id INTO v_exec_id;

  -- 2. Explicitly update sim_lines last_topup_at
  UPDATE public.sim_lines
  SET last_topup_at = p_recharge_date,
      updated_at = now()
  WHERE id = p_sim_line_id;

  -- 3. Clear any pending auto-rescue warning clock
  UPDATE public.sim_line_rescue_policy
  SET last_warned_at = NULL
  WHERE sim_line_id = p_sim_line_id;

  -- 4. Recompute usage forecast asynchronously / best-effort
  BEGIN
    PERFORM public.compute_usage_forecasts();
  EXCEPTION WHEN OTHERS THEN
    -- Best effort, do not block
  END;

  RETURN jsonb_build_object(
    'success', true,
    'execution_id', v_exec_id,
    'sim_line_id', p_sim_line_id,
    'last_topup_at', p_recharge_date
  );
END;
$$;

REVOKE ALL ON FUNCTION public.record_manual_external_recharge(uuid, timestamptz, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_manual_external_recharge(uuid, timestamptz, numeric, text) TO authenticated, service_role;

-- 4. Update admin_list_carriers to return SMS pattern columns
DROP FUNCTION IF EXISTS public.admin_list_carriers();

CREATE OR REPLACE FUNCTION public.admin_list_carriers()
RETURNS TABLE (
  id                       uuid,
  name                     text,
  country_id               uuid,
  country_name             text,
  country_iso              text,
  is_supported             boolean,
  fulfillment_gateway      text,
  api_provider             text,
  default_refill_amount    numeric,
  gateway_phone_number     text,
  zen_carrier              text,
  ding_carrier             text,
  dt_carrier               text,
  reloadly_operator_id     text,
  active_lines             bigint,
  offers_available         bigint,
  min_offer_usd            numeric,
  max_offer_usd            numeric,
  rule_minimum_topup       numeric,
  rule_recommended_topup   numeric,
  rule_validity_days       integer,
  rule_inactivity_days     integer,
  rule_grace_days          integer,
  rule_notes               text,
  rule_last_verified_at    timestamptz,
  sms_sender_ids           text[],
  sms_balance_regex        text,
  sms_expiry_regex         text,
  sms_keywords             text[],
  sms_language             text,
  routing_problem          text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT
    ca.id, ca.name, ca.country_id,
    co.name           AS country_name,
    co.iso_code::text AS country_iso,
    COALESCE(ca.is_supported, true),
    ca.fulfillment_gateway::text,
    ca.api_provider::text,
    ca.default_refill_amount,
    ca.gateway_phone_number,
    ca.zen_carrier::text,
    ca.ding_carrier::text,
    ca.dt_carrier::text,
    ca.reloadly_operator_id,
    (SELECT count(*) FROM public.sim_lines sl WHERE sl.carrier_id = ca.id),
    o.n_offers, o.min_usd, o.max_usd,
    cr.minimum_topup_amount, cr.recommended_topup_amount, cr.topup_validity_days,
    cr.inactivity_limit_days, cr.grace_period_days, cr.notes, cr.last_verified_at,
    cr.sms_sender_ids, cr.sms_balance_regex, cr.sms_expiry_regex, cr.sms_keywords, cr.sms_language,
    CASE
      WHEN ca.fulfillment_gateway = 'API' AND ca.api_provider IS NULL
        THEN 'Routed to API with no provider — no worker can claim these refills'
      WHEN ca.fulfillment_gateway = 'API' AND COALESCE(o.n_offers, 0) = 0
        THEN 'Routed to API but the offer cache holds nothing for this carrier'
      WHEN ca.fulfillment_gateway = 'MANUAL' AND ca.gateway_phone_number IS NULL
        THEN 'Manual fulfilment with no gateway number recorded'
      ELSE NULL
    END AS routing_problem
  FROM public.carriers ca
  JOIN public.countries co ON co.id = ca.country_id
  LEFT JOIN public.carrier_rules cr ON cr.carrier_id = ca.id
  LEFT JOIN LATERAL (
    SELECT count(*) AS n_offers,
           min(COALESCE(p.price_fixed_usd, p.price_min_usd)) AS min_usd,
           max(COALESCE(p.price_fixed_usd, p.price_max_usd)) AS max_usd
    FROM public.provider_offers_cache p
    WHERE p.country_code = co.iso_code
      AND p.api_provider = COALESCE(ca.api_provider::text, 'zendit')
      AND p.carrier_code = CASE COALESCE(ca.api_provider::text, 'zendit')
                             WHEN 'ding'  THEN ca.ding_carrier::text
                             WHEN 'dtone' THEN ca.dt_carrier::text
                             ELSE ca.zen_carrier::text
                           END
  ) o ON true
  ORDER BY co.name, ca.name;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_carriers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_carriers() TO authenticated, service_role;

