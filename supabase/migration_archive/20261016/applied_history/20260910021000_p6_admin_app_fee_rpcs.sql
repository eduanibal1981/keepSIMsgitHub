-- =============================================================================
-- Migration: 20260910021000_p6_admin_app_fee_rpcs.sql
-- Description:
--   Admin RPCs for managing app_fee_rules:
--   - admin_list_app_fee_rules(): list all published, draft, and retired rules
--   - admin_save_draft_app_fee_rule(): create or update a draft rule
--   - admin_publish_app_fee_rule(): atomically retire published & promote rule
-- =============================================================================

-- 1. admin_list_app_fee_rules
CREATE OR REPLACE FUNCTION public.admin_list_app_fee_rules()
RETURNS TABLE (
  id UUID,
  appfees_item TEXT,
  version INT,
  free_percentage NUMERIC,
  free_minimum NUMERIC,
  stand_percentage NUMERIC,
  stand_minimum NUMERIC,
  prem_percentage NUMERIC,
  prem_minimum NUMERIC,
  currency TEXT,
  fee_basis TEXT,
  charge_unit TEXT,
  status TEXT,
  effective_from TIMESTAMPTZ,
  effective_to TIMESTAMPTZ,
  change_reason TEXT,
  created_at TIMESTAMPTZ,
  created_by UUID,
  published_at TIMESTAMPTZ,
  published_by UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
  SELECT 
    r.id, r.appfees_item, r.version,
    r.free_percentage, r.free_minimum,
    r.stand_percentage, r.stand_minimum,
    r.prem_percentage, r.prem_minimum,
    r.currency, r.fee_basis, r.charge_unit,
    r.status, r.effective_from, r.effective_to,
    r.change_reason, r.created_at, r.created_by,
    r.published_at, r.published_by
  FROM public.app_fee_rules r
  ORDER BY r.appfees_item, r.version DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_app_fee_rules() TO authenticated, service_role;

-- 2. admin_save_draft_app_fee_rule
CREATE OR REPLACE FUNCTION public.admin_save_draft_app_fee_rule(
  p_item             TEXT,
  p_free_percentage  NUMERIC,
  p_free_minimum     NUMERIC,
  p_stand_percentage NUMERIC,
  p_stand_minimum    NUMERIC,
  p_prem_percentage  NUMERIC,
  p_prem_minimum     NUMERIC,
  p_charge_unit      TEXT DEFAULT 'purchase',
  p_change_reason    TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_draft_id UUID;
  v_latest_version INT;
  v_rule_id UUID;
BEGIN
  PERFORM public.assert_admin();

  -- Validate zero minima for calling
  IF p_item = 'intelcallfee' AND (p_free_minimum <> 0 OR p_stand_minimum <> 0 OR p_prem_minimum <> 0) THEN
    RAISE EXCEPTION 'Calling fee minima must be zero ($0.00)' USING ERRCODE = 'KS422';
  END IF;

  -- Validate hierarchy
  IF p_free_percentage < p_stand_percentage OR p_stand_percentage < p_prem_percentage OR
     p_free_minimum < p_stand_minimum OR p_stand_minimum < p_prem_minimum THEN
    RAISE EXCEPTION 'Invalid tier hierarchy: Free must be >= Standard >= Premium' USING ERRCODE = 'KS422';
  END IF;

  SELECT id INTO v_draft_id
  FROM public.app_fee_rules
  WHERE appfees_item = p_item AND status = 'draft'
  ORDER BY version DESC
  LIMIT 1;

  IF v_draft_id IS NOT NULL THEN
    UPDATE public.app_fee_rules
    SET free_percentage  = p_free_percentage,
        free_minimum     = p_free_minimum,
        stand_percentage = p_stand_percentage,
        stand_minimum    = p_stand_minimum,
        prem_percentage  = p_prem_percentage,
        prem_minimum     = p_prem_minimum,
        charge_unit      = coalesce(p_charge_unit, charge_unit),
        change_reason    = coalesce(p_change_reason, change_reason),
        created_by       = v_admin_id
    WHERE id = v_draft_id
    RETURNING id INTO v_rule_id;

    RETURN jsonb_build_object(
      'success', true,
      'rule_id', v_rule_id,
      'appfees_item', p_item,
      'action', 'updated_draft'
    );
  ELSE
    SELECT COALESCE(MAX(version), 0) + 1 INTO v_latest_version
    FROM public.app_fee_rules
    WHERE appfees_item = p_item;

    INSERT INTO public.app_fee_rules (
      appfees_item, version,
      free_percentage, free_minimum,
      stand_percentage, stand_minimum,
      prem_percentage, prem_minimum,
      currency, fee_basis, charge_unit,
      status, change_reason, created_by
    ) VALUES (
      p_item, v_latest_version,
      p_free_percentage, p_free_minimum,
      p_stand_percentage, p_stand_minimum,
      p_prem_percentage, p_prem_minimum,
      'USD', 'base_amount_usd', coalesce(p_charge_unit, 'purchase'),
      'draft', p_change_reason, v_admin_id
    ) RETURNING id INTO v_rule_id;

    RETURN jsonb_build_object(
      'success', true,
      'rule_id', v_rule_id,
      'appfees_item', p_item,
      'version', v_latest_version,
      'action', 'created_draft'
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_save_draft_app_fee_rule(TEXT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT, TEXT) TO authenticated, service_role;

-- 3. Update admin_publish_app_fee_rule with assert_admin
CREATE OR REPLACE FUNCTION public.admin_publish_app_fee_rule(
  p_item             TEXT,
  p_free_percentage  NUMERIC,
  p_free_minimum     NUMERIC,
  p_stand_percentage NUMERIC,
  p_stand_minimum    NUMERIC,
  p_prem_percentage  NUMERIC,
  p_prem_minimum     NUMERIC,
  p_charge_unit      TEXT DEFAULT 'purchase',
  p_change_reason    TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_latest_version INT;
  v_new_version INT;
  v_rule_id UUID;
BEGIN
  PERFORM public.assert_admin();

  -- Validate zero minima for calling
  IF p_item = 'intelcallfee' AND (p_free_minimum <> 0 OR p_stand_minimum <> 0 OR p_prem_minimum <> 0) THEN
    RAISE EXCEPTION 'Calling fee minima must be zero ($0.00)' USING ERRCODE = 'KS422';
  END IF;

  -- Validate hierarchy
  IF p_free_percentage < p_stand_percentage OR p_stand_percentage < p_prem_percentage OR
     p_free_minimum < p_stand_minimum OR p_stand_minimum < p_prem_minimum THEN
    RAISE EXCEPTION 'Invalid tier hierarchy: Free must be >= Standard >= Premium' USING ERRCODE = 'KS422';
  END IF;

  SELECT COALESCE(MAX(version), 0) INTO v_latest_version
  FROM public.app_fee_rules
  WHERE appfees_item = p_item;

  v_new_version := v_latest_version + 1;

  -- Retire active rule
  UPDATE public.app_fee_rules
  SET status = 'retired',
      effective_to = now()
  WHERE appfees_item = p_item
    AND status = 'published';

  -- Remove existing draft if any
  DELETE FROM public.app_fee_rules
  WHERE appfees_item = p_item
    AND status = 'draft';

  -- Insert new published rule
  INSERT INTO public.app_fee_rules (
    appfees_item, version,
    free_percentage, free_minimum,
    stand_percentage, stand_minimum,
    prem_percentage, prem_minimum,
    currency, fee_basis, charge_unit,
    status, effective_from,
    change_reason, created_by, published_by, published_at
  ) VALUES (
    p_item, v_new_version,
    p_free_percentage, p_free_minimum,
    p_stand_percentage, p_stand_minimum,
    p_prem_percentage, p_prem_minimum,
    'USD', 'base_amount_usd', coalesce(p_charge_unit, 'purchase'),
    'published', now(),
    p_change_reason, v_admin_id, v_admin_id, now()
  ) RETURNING id INTO v_rule_id;

  RETURN jsonb_build_object(
    'success', true,
    'rule_id', v_rule_id,
    'appfees_item', p_item,
    'version', v_new_version,
    'status', 'published'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_publish_app_fee_rule(TEXT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT, TEXT) TO authenticated, service_role;
