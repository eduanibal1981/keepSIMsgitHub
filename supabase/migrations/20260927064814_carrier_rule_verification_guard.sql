-- Restore the activity fields accidentally omitted by the later carrier-rule
-- RPC replacement. Verification is explicit and rule edits invalidate it.
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
                            'refill_interval_days_override','rule_source_url',
                            'balance_check_ussd','recharge_ussd','customer_support_phone',
                            'verify_source'];
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
    balance_check_ussd       = CASE WHEN p_patch ? 'balance_check_ussd'
                                    THEN NULLIF(btrim(p_patch ->> 'balance_check_ussd'), '')
                                    ELSE balance_check_ussd END,
    recharge_ussd            = CASE WHEN p_patch ? 'recharge_ussd'
                                    THEN NULLIF(btrim(p_patch ->> 'recharge_ussd'), '')
                                    ELSE recharge_ussd END,
    customer_support_phone   = CASE WHEN p_patch ? 'customer_support_phone'
                                    THEN NULLIF(btrim(p_patch ->> 'customer_support_phone'), '')
                                    ELSE customer_support_phone END,
    last_verified_at         = CASE
      WHEN coalesce((p_patch->>'verify_source')::boolean,false)
       AND (CASE WHEN p_patch ? 'rule_source_url'
                 THEN NULLIF(btrim(p_patch->>'rule_source_url'),'')
                 ELSE rule_source_url END) IS NOT NULL
        THEN now()
      WHEN p_patch ?| ARRAY['inactivity_limit_days','activity_requirement',
                            'validity_qualifying_topup_amount','rule_source_url']
        THEN NULL
      ELSE last_verified_at END,
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

