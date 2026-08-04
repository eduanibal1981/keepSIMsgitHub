-- ============================================================================
-- H3c — the per-carrier refill economics editor.
--
-- Two defects were found by RUNNING this path rather than reading it, and the
-- final body below is what passed. Both are worth remembering:
--
--   1. 23502. The upsert seeded only (carrier_id, rule_type), but carrier_rules
--      has three more NOT NULL columns with no defaults —
--      inactivity_limit_days, minimum_topup_amount, topup_validity_days. It
--      raised for exactly the case the upsert exists to serve: the one carrier
--      of 50 with no rule row.
--
--   2. 23514. Replacing that with `INSERT … ON CONFLICT (carrier_id) DO
--      NOTHING` and a placeholder rule_type of 'standard' failed on all 49
--      carriers that already HAVE a rule, because Postgres evaluates CHECK
--      constraints BEFORE it detects the conflict. rule_type is
--      prepaid/postpaid/data_only and every existing row is 'prepaid'. The fix
--      is an explicit NOT EXISTS guard, not ON CONFLICT.
--
-- The seed values (90 days validity, 90 days inactivity, $1 floor) match what
-- FORECAST_DEFAULT_VALIDITY_DAYS implies. They are a starting point the admin
-- edits in the same call, not a claim about the carrier.
-- ============================================================================
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
                            'offer_id','offer_value'];
  v_bad     text;
  v_before  jsonb;
  v_after   jsonb;
  v_min     numeric;
  v_rec     numeric;
  v_val     integer;
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

  -- Explicit NOT EXISTS, not ON CONFLICT: see the 23514 note above.
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
    last_verified_at         = now(),
    updated_at               = now()
  WHERE carrier_id = p_carrier_id;

  SELECT to_jsonb(cr) INTO v_after FROM public.carrier_rules cr WHERE cr.carrier_id = p_carrier_id;

  v_min := (v_after ->> 'minimum_topup_amount')::numeric;
  v_rec := (v_after ->> 'recommended_topup_amount')::numeric;
  v_val := (v_after ->> 'topup_validity_days')::integer;

  IF v_min IS NULL OR v_min <= 0 OR v_min > 1000 THEN
    RAISE EXCEPTION 'Minimum top-up must be between 0.01 and 1000 USD' USING ERRCODE = 'KS466';
  END IF;
  IF v_rec IS NOT NULL AND (v_rec <= 0 OR v_rec > 1000) THEN
    RAISE EXCEPTION 'Recommended top-up must be between 0.01 and 1000 USD' USING ERRCODE = 'KS466';
  END IF;
  -- G7 found the live version of this: some G1 suggested_amount_usd sit BELOW
  -- the carrier's own floor, so anything reading that column quotes a price the
  -- carrier will not sell. Refusing the inversion here stops it being created.
  IF v_rec IS NOT NULL AND v_rec < v_min THEN
    RAISE EXCEPTION 'Recommended top-up (%) cannot be below the minimum (%)', v_rec, v_min
      USING ERRCODE = 'KS466';
  END IF;
  IF v_val IS NULL OR v_val < 1 OR v_val > 3650 THEN
    RAISE EXCEPTION 'Validity must be 1..3650 days' USING ERRCODE = 'KS466';
  END IF;
  IF (v_after ->> 'inactivity_limit_days')::integer < 1 THEN
    RAISE EXCEPTION 'Inactivity limit must be at least 1 day' USING ERRCODE = 'KS466';
  END IF;

  PERFORM public.admin_log('carrier_rule.update', 'carrier', p_carrier_id::text, v_before, v_after, p_note);

  RETURN jsonb_build_object('success', true, 'carrier_id', p_carrier_id);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_carrier_rule(uuid,jsonb,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_carrier_rule(uuid,jsonb,text) TO authenticated, service_role;
