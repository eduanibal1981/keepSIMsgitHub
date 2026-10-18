-- Captured live definitions, 2026-10-17. Isolated test input, never deploy.
-- The migration under test replaces five user APIs; all other bodies are real.
CREATE OR REPLACE FUNCTION public.admin_delete_whatsapp_profile(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_before jsonb;
  v_used_count int;
BEGIN
  PERFORM public.assert_admin();

  SELECT to_jsonb(p) INTO v_before
  FROM public.whatsapp_provider_profiles p WHERE p.id = p_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'KS461';
  END IF;

  SELECT count(*) INTO v_used_count
  FROM public.whatsapp_country_routes
  WHERE profile_id = p_id AND route_mode <> 'disabled';

  IF v_used_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete profile: % active country route(s) are assigned to it. Reassign or disable them first.', v_used_count USING ERRCODE = 'KS467';
  END IF;

  DELETE FROM public.whatsapp_provider_profiles WHERE id = p_id;

  PERFORM public.admin_log('whatsapp_profile.delete', 'whatsapp_profile', p_id::text, v_before, NULL, 'Deleted WhatsApp provider profile');

  RETURN jsonb_build_object('success', true, 'deleted_id', p_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_alert_clock_overview()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_counts RECORD;
  v_dry_run jsonb;
BEGIN
  PERFORM public.assert_admin();

  SELECT 
    count(*) AS total,
    count(*) FILTER (WHERE state = 'eligible') AS eligible,
    count(*) FILTER (WHERE state = 'eligible' AND is_within_48h = true) AS within_48h,
    count(*) FILTER (WHERE alert_emitted_at IS NOT NULL) AS alerted,
    count(*) FILTER (WHERE state = 'needs_activity_date') AS needs_date,
    count(*) FILTER (WHERE state = 'needs_qualifying_usage') AS needs_usage,
    count(*) FILTER (WHERE state = 'needs_amount') AS needs_amount,
    count(*) FILTER (WHERE state = 'stale_rule') AS stale_rule,
    count(*) FILTER (WHERE state = 'missing_rule') AS missing_rule
  INTO v_counts
  FROM public.sim_line_alert_clock_states;

  v_dry_run := public.emit_urgent_deactivation_alerts(true);

  RETURN jsonb_build_object(
    'success', true,
    'total_lines', v_counts.total,
    'eligible_count', v_counts.eligible,
    'within_48h_count', v_counts.within_48h,
    'alerted_count', v_counts.alerted,
    'needs_date_count', v_counts.needs_date,
    'needs_usage_count', v_counts.needs_usage,
    'needs_amount_count', v_counts.needs_amount,
    'stale_rule_count', v_counts.stale_rule,
    'missing_rule_count', v_counts.missing_rule,
    'dry_run_preview', v_dry_run
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_alert_clocks(p_state text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_res jsonb;
  v_total INT;
BEGIN
  PERFORM public.assert_admin();

  SELECT count(*) INTO v_total
  FROM public.sim_line_alert_clock_states
  WHERE (p_state IS NULL OR state = p_state);

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'sim_line_id', cs.sim_line_id,
      'phone_number', sl.phone_number,
      'nickname', sl.nickname,
      'carrier_name', cs.carrier_name,
      'activity_requirement', cs.activity_requirement,
      'inactivity_limit_days', cs.inactivity_limit_days,
      'qualifying_activity_type', cs.qualifying_activity_type,
      'qualifying_activity_at', cs.qualifying_activity_at,
      'deactivation_cutoff_at', cs.deactivation_cutoff_at,
      'hours_remaining', cs.hours_remaining,
      'is_within_48h', cs.is_within_48h,
      'state', cs.state,
      'ineligibility_reason', cs.ineligibility_reason,
      'precision', cs.precision,
      'rule_source_url', cs.rule_source_url,
      'rule_last_verified_at', cs.rule_last_verified_at,
      'alert_emitted_at', cs.alert_emitted_at,
      'evaluated_at', cs.evaluated_at
    ) ORDER BY cs.hours_remaining ASC NULLS LAST
  ), '[]'::jsonb) INTO v_res
  FROM (
    SELECT * FROM public.sim_line_alert_clock_states
    WHERE (p_state IS NULL OR state = p_state)
    ORDER BY hours_remaining ASC NULLS LAST
    LIMIT LEAST(GREATEST(p_limit, 1), 200)
    OFFSET GREATEST(p_offset, 0)
  ) cs
  JOIN public.sim_lines sl ON sl.id = cs.sim_line_id;

  RETURN jsonb_build_object(
    'success', true,
    'total', v_total,
    'items', v_res
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_app_fee_rules()
 RETURNS TABLE(id uuid, appfees_item text, version integer, free_percentage numeric, free_minimum numeric, stand_percentage numeric, stand_minimum numeric, prem_percentage numeric, prem_minimum numeric, currency text, fee_basis text, charge_unit text, status text, effective_from timestamp with time zone, effective_to timestamp with time zone, change_reason text, created_at timestamp with time zone, created_by uuid, published_at timestamp with time zone, published_by uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_country_verification_prices(p_search text DEFAULT NULL::text, p_only_zero boolean DEFAULT false, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_total INT;
  v_items JSONB;
BEGIN
  PERFORM public.assert_admin();

  SELECT count(*) INTO v_total
  FROM public.countries c
  WHERE (p_search IS NULL OR c.name ILIKE '%' || p_search || '%' OR c.iso_code ILIKE '%' || p_search || '%')
    AND (NOT p_only_zero OR (COALESCE(c.sms_verify_cost, 0) = 0 AND COALESCE(c.call_verify_cost, 0) = 0));

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', c.id,
    'name', c.name,
    'iso_code', c.iso_code,
    'dialing_code', c.dialing_code,
    'flag_emoji', COALESCE(c.flag_emoji, '🌐'),
    'currency_code', c.currency_code,
    'sms_verify_cost', COALESCE(c.sms_verify_cost, 0.00),
    'call_verify_cost', COALESCE(c.call_verify_cost, 0.00),
    'verification_price_version', c.verification_price_version,
    'is_supported', c.is_supported
  ) ORDER BY c.name ASC), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT *
    FROM public.countries c
    WHERE (p_search IS NULL OR c.name ILIKE '%' || p_search || '%' OR c.iso_code ILIKE '%' || p_search || '%')
      AND (NOT p_only_zero OR (COALESCE(c.sms_verify_cost, 0) = 0 AND COALESCE(c.call_verify_cost, 0) = 0))
    ORDER BY c.name ASC
    LIMIT p_limit OFFSET p_offset
  ) c;

  RETURN jsonb_build_object(
    'total', v_total,
    'items', v_items
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_line_verification_attempts(p_sim_line_id uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_total INT;
  v_items JSONB;
BEGIN
  PERFORM public.assert_admin();

  SELECT count(*) INTO v_total
  FROM public.line_verification_attempts a
  WHERE (p_sim_line_id IS NULL OR a.sim_line_id = p_sim_line_id)
    AND (p_status IS NULL OR a.status = p_status);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', a.id,
    'sim_line_id', a.sim_line_id,
    'user_id', a.user_id,
    'method', a.method,
    'destination_phone', a.destination_phone,
    'retail_price', a.retail_price,
    'funding_kind', a.funding_kind,
    'status', a.status,
    'outcome', a.outcome,
    'settlement_status', a.settlement_status,
    'carrier_name', a.carrier_name,
    'error_message', a.error_message,
    'created_at', a.created_at
  ) ORDER BY a.created_at DESC), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT *
    FROM public.line_verification_attempts a
    WHERE (p_sim_line_id IS NULL OR a.sim_line_id = p_sim_line_id)
      AND (p_status IS NULL OR a.status = p_status)
    ORDER BY a.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) a;

  RETURN jsonb_build_object(
    'total', v_total,
    'items', v_items
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_whatsapp_attempts(p_country_id uuid DEFAULT NULL::uuid, p_purpose text DEFAULT NULL::text, p_provider text DEFAULT NULL::text, p_state text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_res jsonb;
  v_total int;
BEGIN
  PERFORM public.assert_admin();

  SELECT count(*) INTO v_total
  FROM public.whatsapp_message_attempts a
  WHERE (p_country_id IS NULL OR a.recipient_country_id = p_country_id)
    AND (p_purpose IS NULL OR a.purpose = p_purpose)
    AND (p_provider IS NULL OR a.route_mode = p_provider)
    AND (p_state IS NULL OR a.state = p_state);

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', a.id,
      'purpose', a.purpose,
      'notification_id', a.notification_id,
      'command_id', a.command_id,
      'recipient_phone', (
        CASE
          WHEN length(a.recipient_phone) > 6 THEN
            left(a.recipient_phone, 4) || '***' || right(a.recipient_phone, 3)
          ELSE '***'
        END
      ),
      'recipient_country_id', a.recipient_country_id,
      'country_name', c.name,
      'country_iso', c.iso_code,
      'sim_line_id', a.sim_line_id,
      'sim_country_id', a.sim_country_id,
      'route_mode', a.route_mode,
      'profile_id', a.profile_id,
      'profile_label', p.label,
      'sender_number', a.sender_number,
      'idempotency_key', a.idempotency_key,
      'template_name', a.template_name,
      'template_language', a.template_language,
      'attempt_count', a.attempt_count,
      'state', a.state,
      'provider_message_id', a.provider_message_id,
      'error_category', a.error_category,
      'error_detail', a.error_detail,
      'created_at', a.created_at,
      'updated_at', a.updated_at,
      'delivered_at', a.delivered_at
    ) ORDER BY a.created_at DESC
  ), '[]'::jsonb) INTO v_res
  FROM (
    SELECT * FROM public.whatsapp_message_attempts
    WHERE (p_country_id IS NULL OR recipient_country_id = p_country_id)
      AND (p_purpose IS NULL OR purpose = p_purpose)
      AND (p_provider IS NULL OR route_mode = p_provider)
      AND (p_state IS NULL OR state = p_state)
    ORDER BY created_at DESC
    LIMIT LEAST(GREATEST(p_limit, 1), 200)
    OFFSET GREATEST(p_offset, 0)
  ) a
  LEFT JOIN public.countries c ON c.id = a.recipient_country_id
  LEFT JOIN public.whatsapp_provider_profiles p ON p.id = a.profile_id;

  RETURN jsonb_build_object(
    'success', true,
    'total', v_total,
    'items', v_res
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_whatsapp_profiles()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_res jsonb;
BEGIN
  PERFORM public.assert_admin();

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'provider_kind', p.provider_kind,
      'label', p.label,
      'expected_sender_number', p.expected_sender_number,
      'observed_sender_number', p.observed_sender_number,
      'is_enabled', p.is_enabled,
      'ready_state', p.ready_state,
      'version', p.version,
      'last_probe_at', p.last_probe_at,
      'last_error_category', p.last_error_category,
      'last_error_detail', p.last_error_detail,
      'connection_metadata', p.connection_metadata - 'access_token' - 'app_secret' - 'api_key',
      'has_access_token', ((p.connection_metadata ? 'access_token_vault_id') OR (p.connection_metadata ? 'access_token_masked')),
      'has_app_secret', (p.connection_metadata ? 'app_secret_vault_id'),
      'has_verify_token', (p.connection_metadata ? 'webhook_verify_token_vault_id'),
      'has_api_key', (p.connection_metadata ? 'auth_secret_vault_id'),
      'created_at', p.created_at,
      'updated_at', p.updated_at
    ) ORDER BY p.provider_kind, p.label
  ), '[]'::jsonb) INTO v_res
  FROM public.whatsapp_provider_profiles p;

  RETURN jsonb_build_object('success', true, 'items', v_res);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_whatsapp_routes()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_res jsonb;
BEGIN
  PERFORM public.assert_admin();

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'country_id', c.id,
      'country_name', c.name,
      'iso_code', c.iso_code,
      'dialing_code', c.dialing_code,
      'flag_emoji', c.flag_emoji,
      'route_mode', COALESCE(r.route_mode, 'disabled'),
      'profile_id', r.profile_id,
      'profile_label', p.label,
      'profile_kind', p.provider_kind,
      'profile_ready_state', p.ready_state,
      'expected_sender', p.expected_sender_number,
      'observed_sender', p.observed_sender_number,
      'health_status', COALESCE(r.health_status, 'disabled'),
      'health_reason', r.health_reason,
      'version', COALESCE(r.version, 1),
      'updated_at', r.updated_at
    ) ORDER BY c.name
  ), '[]'::jsonb) INTO v_res
  FROM public.countries c
  LEFT JOIN public.whatsapp_country_routes r ON r.country_id = c.id
  LEFT JOIN public.whatsapp_provider_profiles p ON p.id = r.profile_id;

  RETURN jsonb_build_object('success', true, 'items', v_res);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_prune_database_logs(p_cron_retention_days integer DEFAULT 14, p_alerts_retention_days integer DEFAULT 90)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor_id uuid;
  v_actor_email text;
  v_result jsonb;
BEGIN
  PERFORM public.assert_admin();

  v_actor_id := auth.uid();
  v_actor_email := public.current_user_email();

  v_result := public.prune_database_logs(p_cron_retention_days, p_alerts_retention_days);

  INSERT INTO public.admin_audit_log (
    actor_id,
    actor_email,
    action,
    target_type,
    target_id,
    details
  ) VALUES (
    v_actor_id,
    v_actor_email,
    'prune_database_logs',
    'maintenance',
    'database_logs',
    v_result
  );

  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_publish_app_fee_rule(p_item text, p_free_percentage numeric, p_free_minimum numeric, p_stand_percentage numeric, p_stand_minimum numeric, p_prem_percentage numeric, p_prem_minimum numeric, p_charge_unit text DEFAULT 'purchase'::text, p_change_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_record_whatsapp_probe(p_profile_id uuid, p_observed_sender text, p_ready_state text, p_error_category text DEFAULT NULL::text, p_error_detail text DEFAULT NULL::text, p_metadata_patch jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid;
  v_profile public.whatsapp_provider_profiles%ROWTYPE;
BEGIN
  v_uid := public.assert_admin();

  SELECT * INTO v_profile FROM public.whatsapp_provider_profiles WHERE id = p_profile_id;
  IF v_profile.id IS NULL THEN
    RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'KS461';
  END IF;

  UPDATE public.whatsapp_provider_profiles SET
    observed_sender_number = COALESCE(NULLIF(btrim(p_observed_sender), ''), observed_sender_number),
    ready_state = p_ready_state,
    last_probe_at = now(),
    last_error_category = p_error_category,
    last_error_detail = p_error_detail,
    connection_metadata = connection_metadata || COALESCE(p_metadata_patch, '{}'::jsonb),
    updated_at = now(),
    updated_by = v_uid
  WHERE id = p_profile_id;

  -- Update associated country routes health
  UPDATE public.whatsapp_country_routes SET
    last_health_check_at = now(),
    health_status = CASE
      WHEN route_mode = 'disabled' THEN 'disabled'
      WHEN p_ready_state = 'ready' THEN 'healthy'
      ELSE 'degraded'
    END,
    health_reason = CASE
      WHEN route_mode = 'disabled' THEN 'Route disabled'
      WHEN p_ready_state = 'ready' THEN 'Profile probe verified ready'
      ELSE COALESCE(p_error_detail, 'Probe status: ' || p_ready_state)
    END
  WHERE profile_id = p_profile_id;

  RETURN jsonb_build_object('success', true, 'profile_id', p_profile_id, 'ready_state', p_ready_state);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_save_draft_app_fee_rule(p_item text, p_free_percentage numeric, p_free_minimum numeric, p_stand_percentage numeric, p_stand_minimum numeric, p_prem_percentage numeric, p_prem_minimum numeric, p_charge_unit text DEFAULT 'purchase'::text, p_change_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_save_whatsapp_profile(p_id uuid, p_provider_kind text, p_label text, p_expected_sender text, p_is_enabled boolean, p_metadata jsonb, p_secrets jsonb DEFAULT '{}'::jsonb, p_expected_version integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid;
  v_profile_id uuid := p_id;
  v_before jsonb;
  v_after jsonb;
  v_cur_version int;
  v_meta jsonb := COALESCE(p_metadata, '{}'::jsonb);
  v_secret_val text;
  v_sec_id uuid;
  v_clean_kind text := lower(btrim(p_provider_kind));
  v_ready text := 'unconfigured';
BEGIN
  v_uid := public.assert_admin();

  IF v_clean_kind NOT IN ('baileys', 'meta_cloud') THEN
    RAISE EXCEPTION 'Invalid provider_kind: %', p_provider_kind USING ERRCODE = 'KS467';
  END IF;

  IF p_label IS NULL OR btrim(p_label) = '' THEN
    RAISE EXCEPTION 'Profile label is required' USING ERRCODE = 'KS467';
  END IF;

  IF v_profile_id IS NULL THEN
    v_profile_id := gen_random_uuid();
  END IF;

  -- Handle secret storage in Vault
  IF p_secrets ? 'access_token' AND NULLIF(btrim(p_secrets ->> 'access_token'), '') IS NOT NULL THEN
    v_secret_val := btrim(p_secrets ->> 'access_token');
    v_sec_id := public.admin_set_vault_secret('wa_meta_token_' || v_profile_id, v_secret_val, 'Meta Cloud API access token');
    v_meta := jsonb_set(v_meta, '{access_token_vault_id}', to_jsonb(v_sec_id::text));
    v_meta := jsonb_set(v_meta, '{access_token_masked}', to_jsonb('...' || right(v_secret_val, 4)));
  END IF;

  IF p_secrets ? 'app_secret' AND NULLIF(btrim(p_secrets ->> 'app_secret'), '') IS NOT NULL THEN
    v_secret_val := btrim(p_secrets ->> 'app_secret');
    v_sec_id := public.admin_set_vault_secret('wa_meta_app_secret_' || v_profile_id, v_secret_val, 'Meta Cloud API app secret');
    v_meta := jsonb_set(v_meta, '{app_secret_vault_id}', to_jsonb(v_sec_id::text));
  END IF;

  IF p_secrets ? 'webhook_verify_token' AND NULLIF(btrim(p_secrets ->> 'webhook_verify_token'), '') IS NOT NULL THEN
    v_secret_val := btrim(p_secrets ->> 'webhook_verify_token');
    v_sec_id := public.admin_set_vault_secret('wa_meta_verify_' || v_profile_id, v_secret_val, 'Meta Cloud webhook verify token');
    v_meta := jsonb_set(v_meta, '{webhook_verify_token_vault_id}', to_jsonb(v_sec_id::text));
  END IF;

  IF p_secrets ? 'api_key' AND NULLIF(btrim(p_secrets ->> 'api_key'), '') IS NOT NULL THEN
    v_secret_val := btrim(p_secrets ->> 'api_key');
    v_sec_id := public.admin_set_vault_secret('wa_baileys_key_' || v_profile_id, v_secret_val, 'Baileys worker API key');
    v_meta := jsonb_set(v_meta, '{auth_secret_vault_id}', to_jsonb(v_sec_id::text));
  END IF;

  -- Check existing profile
  SELECT to_jsonb(p), p.version INTO v_before, v_cur_version
  FROM public.whatsapp_provider_profiles p WHERE p.id = v_profile_id;

  IF v_before IS NOT NULL THEN
    IF p_expected_version IS NOT NULL AND v_cur_version <> p_expected_version THEN
      RAISE EXCEPTION 'Stale profile version conflict (expected %, current %)', p_expected_version, v_cur_version USING ERRCODE = 'KS409';
    END IF;

    -- preserve existing vault secret references if not replaced
    IF (v_before -> 'connection_metadata' ? 'access_token_vault_id') AND NOT (v_meta ? 'access_token_vault_id') THEN
      v_meta := jsonb_set(v_meta, '{access_token_vault_id}', v_before -> 'connection_metadata' -> 'access_token_vault_id');
      v_meta := jsonb_set(v_meta, '{access_token_masked}', v_before -> 'connection_metadata' -> 'access_token_masked');
    END IF;
    IF (v_before -> 'connection_metadata' ? 'app_secret_vault_id') AND NOT (v_meta ? 'app_secret_vault_id') THEN
      v_meta := jsonb_set(v_meta, '{app_secret_vault_id}', v_before -> 'connection_metadata' -> 'app_secret_vault_id');
    END IF;
    IF (v_before -> 'connection_metadata' ? 'webhook_verify_token_vault_id') AND NOT (v_meta ? 'webhook_verify_token_vault_id') THEN
      v_meta := jsonb_set(v_meta, '{webhook_verify_token_vault_id}', v_before -> 'connection_metadata' -> 'webhook_verify_token_vault_id');
    END IF;
    IF (v_before -> 'connection_metadata' ? 'auth_secret_vault_id') AND NOT (v_meta ? 'auth_secret_vault_id') THEN
      v_meta := jsonb_set(v_meta, '{auth_secret_vault_id}', v_before -> 'connection_metadata' -> 'auth_secret_vault_id');
    END IF;

    UPDATE public.whatsapp_provider_profiles SET
      label = btrim(p_label),
      expected_sender_number = NULLIF(btrim(p_expected_sender), ''),
      is_enabled = COALESCE(p_is_enabled, is_enabled),
      connection_metadata = v_meta,
      version = version + 1,
      updated_at = now(),
      updated_by = v_uid
    WHERE id = v_profile_id;
  ELSE
    INSERT INTO public.whatsapp_provider_profiles (
      id,
      provider_kind,
      label,
      expected_sender_number,
      is_enabled,
      ready_state,
      version,
      connection_metadata,
      created_by,
      updated_by
    ) VALUES (
      v_profile_id,
      v_clean_kind,
      btrim(p_label),
      NULLIF(btrim(p_expected_sender), ''),
      COALESCE(p_is_enabled, true),
      'unconfigured',
      1,
      v_meta,
      v_uid,
      v_uid
    );
  END IF;

  SELECT to_jsonb(p) INTO v_after
  FROM public.whatsapp_provider_profiles p WHERE p.id = v_profile_id;

  PERFORM public.admin_log(
    CASE WHEN v_before IS NULL THEN 'whatsapp_profile.create' ELSE 'whatsapp_profile.update' END,
    'whatsapp_profile',
    v_profile_id::text,
    v_before,
    v_after - 'connection_metadata',
    'Saved WhatsApp provider profile: ' || p_label
  );

  RETURN jsonb_build_object('success', true, 'profile_id', v_profile_id, 'version', (v_after ->> 'version')::int);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_update_country_verification_prices(p_country_id uuid, p_sms_verify_cost numeric, p_call_verify_cost numeric, p_expected_version integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_actor UUID;
  v_country RECORD;
  v_sms NUMERIC(12,2);
  v_call NUMERIC(12,2);
BEGIN
  v_actor := public.assert_admin();

  IF p_sms_verify_cost IS NULL OR p_sms_verify_cost < 0 THEN
    v_sms := 0.00;
  ELSE
    v_sms := ROUND(p_sms_verify_cost, 2);
  END IF;

  IF p_call_verify_cost IS NULL OR p_call_verify_cost < 0 THEN
    v_call := 0.00;
  ELSE
    v_call := ROUND(p_call_verify_cost, 2);
  END IF;

  SELECT * INTO v_country
  FROM public.countries
  WHERE id = p_country_id
  FOR UPDATE;

  IF v_country.id IS NULL THEN
    RAISE EXCEPTION 'Country not found' USING ERRCODE = 'KS404';
  END IF;

  IF p_expected_version IS NOT NULL AND v_country.verification_price_version != p_expected_version THEN
    RAISE EXCEPTION 'Pricing version conflict. Stale edit detected.' USING ERRCODE = 'KS409';
  END IF;

  UPDATE public.countries
  SET sms_verify_cost = v_sms,
      call_verify_cost = v_call,
      verification_price_version = v_country.verification_price_version + 1
  WHERE id = p_country_id;

  -- Write to admin audit log
  INSERT INTO public.admin_audit_log (
    actor_id, action, target_type, target_id, before_value, after_value, note
  ) VALUES (
    v_actor,
    'update_verification_pricing',
    'country',
    p_country_id,
    jsonb_build_object(
      'sms_verify_cost', v_country.sms_verify_cost,
      'call_verify_cost', v_country.call_verify_cost,
      'version', v_country.verification_price_version
    ),
    jsonb_build_object(
      'sms_verify_cost', v_sms,
      'call_verify_cost', v_call,
      'version', v_country.verification_price_version + 1
    ),
    'Updated real live verification prices for ' || v_country.name
  );

  RETURN jsonb_build_object(
    'success', true,
    'country_id', p_country_id,
    'sms_verify_cost', v_sms,
    'call_verify_cost', v_call,
    'verification_price_version', v_country.verification_price_version + 1
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_update_whatsapp_route(p_country_id uuid, p_route_mode text, p_profile_id uuid, p_expected_version integer, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid;
  v_clean_mode text := lower(btrim(p_route_mode));
  v_before jsonb;
  v_after jsonb;
  v_cur_version int;
  v_profile public.whatsapp_provider_profiles%ROWTYPE;
  v_health text;
  v_reason text;
  v_rows int;
BEGIN
  v_uid := public.assert_admin();

  IF v_clean_mode NOT IN ('disabled', 'baileys', 'meta_cloud') THEN
    RAISE EXCEPTION 'Invalid route_mode: %', p_route_mode USING ERRCODE = 'KS467';
  END IF;

  SELECT to_jsonb(r), r.version INTO v_before, v_cur_version
  FROM public.whatsapp_country_routes r WHERE r.country_id = p_country_id;

  IF v_before IS NOT NULL AND p_expected_version IS NOT NULL AND v_cur_version <> p_expected_version THEN
    RAISE EXCEPTION 'Stale route version conflict (expected %, current %)', p_expected_version, v_cur_version USING ERRCODE = 'KS409';
  END IF;

  IF v_clean_mode = 'disabled' THEN
    v_health := 'disabled';
    v_reason := 'Route explicitly disabled by administrator';
    p_profile_id := NULL;
  ELSE
    IF p_profile_id IS NULL THEN
      RAISE EXCEPTION 'Profile ID is required when route_mode is %', v_clean_mode USING ERRCODE = 'KS467';
    END IF;

    SELECT * INTO v_profile FROM public.whatsapp_provider_profiles WHERE id = p_profile_id;
    IF v_profile.id IS NULL THEN
      RAISE EXCEPTION 'Selected profile not found' USING ERRCODE = 'KS461';
    END IF;

    IF v_profile.provider_kind <> v_clean_mode THEN
      RAISE EXCEPTION 'Selected profile kind (%) does not match route mode (%)', v_profile.provider_kind, v_clean_mode USING ERRCODE = 'KS467';
    END IF;

    IF v_profile.ready_state = 'ready' THEN
      v_health := 'healthy';
      v_reason := 'Profile is ready and verified';
    ELSE
      v_health := 'degraded';
      v_reason := COALESCE(v_profile.last_error_detail, 'Profile state is ' || v_profile.ready_state);
    END IF;
  END IF;

  INSERT INTO public.whatsapp_country_routes (
    country_id,
    route_mode,
    profile_id,
    version,
    last_health_check_at,
    health_status,
    health_reason,
    updated_at,
    updated_by
  ) VALUES (
    p_country_id,
    v_clean_mode,
    p_profile_id,
    1,
    now(),
    v_health,
    v_reason,
    now(),
    v_uid
  )
  ON CONFLICT (country_id) DO UPDATE SET
    route_mode = v_clean_mode,
    profile_id = p_profile_id,
    version = public.whatsapp_country_routes.version + 1,
    last_health_check_at = now(),
    health_status = v_health,
    health_reason = v_reason,
    updated_at = now(),
    updated_by = v_uid
  WHERE public.whatsapp_country_routes.country_id = p_country_id
    AND (p_expected_version IS NULL OR public.whatsapp_country_routes.version = p_expected_version);

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    RAISE EXCEPTION 'Update failed: country not found or stale version conflict' USING ERRCODE = 'KS409';
  END IF;

  -- Also update legacy countries table columns for transition synchronization
  IF v_clean_mode = 'baileys' AND v_profile.connection_metadata ? 'endpoint_url' THEN
    UPDATE public.countries SET
      whatsapp_server_url = v_profile.connection_metadata ->> 'endpoint_url',
      whatsapp_account_phone = v_profile.expected_sender_number
    WHERE id = p_country_id;
  ELSIF v_clean_mode = 'disabled' THEN
    UPDATE public.countries SET
      whatsapp_server_url = NULL,
      whatsapp_account_phone = NULL
    WHERE id = p_country_id;
  END IF;

  SELECT to_jsonb(r) INTO v_after
  FROM public.whatsapp_country_routes r WHERE r.country_id = p_country_id;

  PERFORM public.admin_log(
    'whatsapp_route.update',
    'whatsapp_country_route',
    p_country_id::text,
    v_before,
    v_after,
    COALESCE(p_note, 'Updated WhatsApp route to ' || v_clean_mode)
  );

  RETURN jsonb_build_object(
    'success', true,
    'country_id', p_country_id,
    'route_mode', v_clean_mode,
    'version', (v_after ->> 'version')::int,
    'health_status', v_health
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.assert_admin()
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE
  v_raw   text;
  v_role  text;
  v_uid   uuid;
BEGIN
  v_raw := current_setting('request.jwt.claims', true);
  IF v_raw IS NOT NULL AND v_raw <> '' THEN
    v_role := (v_raw::jsonb) ->> 'role';
  END IF;

  IF v_role = 'service_role' THEN
    RETURN NULL;
  END IF;

  v_uid := auth.uid();

  IF v_uid IS NULL
     OR NOT public.is_power_user(v_uid)
     OR public.is_user_suspended() THEN
    RAISE EXCEPTION 'Admin access required'
      USING ERRCODE = 'KS460',
            HINT = 'This action needs a power-user session.';
  END IF;

  RETURN v_uid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_scheduled_jobs_health()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_job record;
  v_stale_count integer := 0;
  v_failing_count integer := 0;
  v_healthy_count integer := 0;
  v_total_jobs integer := 0;
  v_health_state text;
BEGIN
  FOR v_job IN
    SELECT 
      reg.job_name,
      reg.job_id,
      reg.owner,
      reg.category,
      reg.freshness_threshold_minutes,
      reg.max_consecutive_failures,
      reg.is_critical,
      reg.created_at,
      latest.start_time AS last_run_at,
      latest.status AS last_status,
      fail_count.failures AS consecutive_failures
    FROM public.scheduled_job_registry reg
    LEFT JOIN LATERAL (
      SELECT status, start_time
        FROM cron.job_run_details d
       WHERE d.jobid = reg.job_id
       ORDER BY d.start_time DESC
       LIMIT 1
    ) latest ON true
    LEFT JOIN LATERAL (
      SELECT count(*)::integer AS failures
        FROM (
          SELECT status
            FROM cron.job_run_details d2
           WHERE d2.jobid = reg.job_id
           ORDER BY d2.start_time DESC
           LIMIT reg.max_consecutive_failures
        ) sub
       WHERE sub.status != 'succeeded'
    ) fail_count ON true
  LOOP
    v_total_jobs := v_total_jobs + 1;
    v_health_state := 'healthy';

    -- Check failure streak
    IF COALESCE(v_job.consecutive_failures, 0) >= v_job.max_consecutive_failures THEN
      v_health_state := 'failing';
      v_failing_count := v_failing_count + 1;
      
      INSERT INTO public.system_alerts (
        kind,
        message,
        details
      ) VALUES (
        'scheduled_job_failed',
        'Scheduled job ' || v_job.job_name || ' failed ' || v_job.consecutive_failures || ' consecutive times',
        pg_catalog.jsonb_build_object(
          'job_name', v_job.job_name,
          'job_id', v_job.job_id,
          'owner', v_job.owner,
          'consecutive_failures', v_job.consecutive_failures,
          'last_status', v_job.last_status,
          'last_run_at', v_job.last_run_at
        )
      );

    -- Check staleness: no run within threshold minutes
    ELSIF v_job.last_run_at IS NULL THEN
      -- Sane grace period: newly registered jobs get until their first threshold before alert
      IF v_job.created_at > pg_catalog.now() - (v_job.freshness_threshold_minutes || ' minutes')::interval THEN
        v_health_state := 'healthy';
        v_healthy_count := v_healthy_count + 1;
      ELSE
        v_health_state := 'stale';
        v_stale_count := v_stale_count + 1;

        INSERT INTO public.system_alerts (
          kind,
          message,
          details
        ) VALUES (
          'scheduled_job_stale',
          'Scheduled job ' || v_job.job_name || ' has never run since registration',
          pg_catalog.jsonb_build_object(
            'job_name', v_job.job_name,
            'job_id', v_job.job_id,
            'owner', v_job.owner,
            'created_at', v_job.created_at
          )
        );
      END IF;

    ELSIF v_job.last_run_at < pg_catalog.now() - (v_job.freshness_threshold_minutes || ' minutes')::interval THEN
      v_health_state := 'stale';
      v_stale_count := v_stale_count + 1;

      INSERT INTO public.system_alerts (
        kind,
        message,
        details
      ) VALUES (
        'scheduled_job_stale',
        'Scheduled job ' || v_job.job_name || ' has not run within ' || v_job.freshness_threshold_minutes || 'm freshness SLA',
        pg_catalog.jsonb_build_object(
          'job_name', v_job.job_name,
          'job_id', v_job.job_id,
          'owner', v_job.owner,
          'last_run_at', v_job.last_run_at,
          'freshness_threshold_minutes', v_job.freshness_threshold_minutes
        )
      );

    ELSE
      v_healthy_count := v_healthy_count + 1;
    END IF;
  END LOOP;

  RETURN pg_catalog.jsonb_build_object(
    'total_registered', v_total_jobs,
    'healthy', v_healthy_count,
    'stale', v_stale_count,
    'failing', v_failing_count,
    'checked_at', pg_catalog.now()
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_active_return_trip_for_line(p_sim_line_id uuid, p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(trip_id uuid, sim_line_id uuid, destination_country_id uuid, arrival_date date, status text, package_id uuid, package_type text, package_title text, carrier_name text, data_allowance_mb integer, duration_days integer, is_unlimited boolean, effective_price_usd numeric, ussd_recharge_code text, activation_instructions text, badge_label text, notes text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    t.id AS trip_id,
    t.sim_line_id,
    t.destination_country_id,
    t.arrival_date,
    t.status,
    p.id AS package_id,
    coalesce(p.package_type, t.chosen_package_type) AS package_type,
    coalesce(p.title, 'Curated Return Pack') AS package_title,
    c.name AS carrier_name,
    coalesce(p.data_allowance_mb, 0) AS data_allowance_mb,
    coalesce(p.duration_days, 1) AS duration_days,
    coalesce(p.is_unlimited, false) AS is_unlimited,
    coalesce(p.retail_price_usd, 0.00) AS effective_price_usd,
    p.ussd_recharge_code,
    p.activation_instructions,
    p.badge_label,
    t.notes,
    t.created_at
  FROM public.return_trips t
  LEFT JOIN public.return_trip_packages p ON p.id = t.chosen_package_id
  LEFT JOIN public.carriers c ON c.id = p.carrier_id
  WHERE t.sim_line_id = p_sim_line_id
    AND t.user_id = p_user_id
    AND t.status IN ('planning', 'data_ready', 'arrived')
  ORDER BY t.created_at DESC
  LIMIT 1;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_call_rate_for_number(p_phone_number text, p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(id uuid, country_code text, country_name text, phone_prefix text, rate_per_minute_usd numeric, cost_per_minute_usd numeric, connection_fee_usd numeric, billing_increment_seconds integer, account_tier text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_clean_number TEXT;
  v_tier         TEXT;
  v_rate         RECORD;
  v_effective    NUMERIC;
  v_fee          NUMERIC;
BEGIN
  -- 1. Resolve Halo tier for this account
  v_tier := public.resolve_account_commerce_benefit(p_user_id);

  -- 2. Normalize number format
  v_clean_number := regexp_replace(p_phone_number, '[^0-9+]', '', 'g');
  IF NOT (v_clean_number LIKE '+%') THEN
    v_clean_number := '+' || v_clean_number;
  END IF;

  SELECT
    cr.id,
    cr.country_code,
    cr.country_name,
    cr.phone_prefix,
    cr.rate_per_minute_usd,
    cr.cost_per_minute_usd,
    0.00::NUMERIC AS connection_fee_usd, -- Strictly $0 connection fee per C12
    cr.billing_increment_seconds
  INTO v_rate
  FROM public.call_rates cr
  WHERE cr.is_active = TRUE
    AND v_clean_number LIKE (cr.phone_prefix || '%')
  ORDER BY length(cr.phone_prefix) DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- 3. Calculate effective rate per minute with intelcallfee app fee rule
  IF v_rate.cost_per_minute_usd IS NOT NULL AND v_rate.cost_per_minute_usd > 0 THEN
    v_fee := public.resolve_app_fee('intelcallfee', v_tier, v_rate.cost_per_minute_usd);
    IF v_fee IS NULL THEN
      -- Fallback to default draft percentages if no rule in table
      v_fee := CASE v_tier
        WHEN 'premium'  THEN round(v_rate.cost_per_minute_usd * 0.05, 4)
        WHEN 'standard' THEN round(v_rate.cost_per_minute_usd * 0.10, 4)
        ELSE round(v_rate.cost_per_minute_usd * 0.15, 4)
      END;
    END IF;
    v_effective := round(v_rate.cost_per_minute_usd + v_fee, 4);
  ELSE
    v_effective := v_rate.rate_per_minute_usd;
  END IF;

  RETURN QUERY
  SELECT
    v_rate.id,
    v_rate.country_code,
    v_rate.country_name,
    v_rate.phone_prefix,
    v_effective AS rate_per_minute_usd,
    v_rate.cost_per_minute_usd,
    0.00::NUMERIC AS connection_fee_usd,
    v_rate.billing_increment_seconds,
    v_tier AS account_tier;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_return_trip_history_for_line(p_sim_line_id uuid, p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(trip_id uuid, sim_line_id uuid, destination_country_id uuid, arrival_date date, status text, package_id uuid, package_type text, package_title text, carrier_name text, data_allowance_mb integer, duration_days integer, is_unlimited boolean, effective_price_usd numeric, ussd_recharge_code text, activation_instructions text, badge_label text, notes text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    t.id AS trip_id,
    t.sim_line_id,
    t.destination_country_id,
    t.arrival_date,
    t.status,
    p.id AS package_id,
    coalesce(p.package_type, t.chosen_package_type) AS package_type,
    coalesce(p.title, 'Curated Return Pack') AS package_title,
    c.name AS carrier_name,
    coalesce(p.data_allowance_mb, 0) AS data_allowance_mb,
    coalesce(p.duration_days, 1) AS duration_days,
    coalesce(p.is_unlimited, false) AS is_unlimited,
    coalesce(p.retail_price_usd, 0.00) AS effective_price_usd,
    p.ussd_recharge_code,
    p.activation_instructions,
    p.badge_label,
    t.notes,
    t.created_at
  FROM public.return_trips t
  LEFT JOIN public.return_trip_packages p ON p.id = t.chosen_package_id
  LEFT JOIN public.carriers c ON c.id = p.carrier_id
  WHERE t.sim_line_id = p_sim_line_id
    AND t.user_id = p_user_id
  ORDER BY t.arrival_date DESC, t.created_at DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_return_trip_packages_for_line(p_sim_line_id uuid, p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(id uuid, country_id uuid, carrier_id uuid, carrier_name text, package_type text, title text, description text, data_allowance_mb integer, duration_days integer, is_unlimited boolean, supplier_cost_usd numeric, retail_price_usd numeric, effective_price_usd numeric, app_fee_usd numeric, discount_usd numeric, ussd_recharge_code text, activation_instructions text, badge_label text, account_tier text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_line_country_id UUID;
  v_line_carrier_id UUID;
  v_tier            TEXT := 'free';
  v_discount_rate   NUMERIC := 0.00;
BEGIN
  -- Resolve line country and carrier
  SELECT sl.country_id, sl.carrier_id INTO v_line_country_id, v_line_carrier_id
  FROM public.sim_lines sl
  WHERE sl.id = p_sim_line_id;

  IF v_line_country_id IS NULL THEN
    RETURN;
  END IF;

  v_tier := public.resolve_account_commerce_benefit(p_user_id);
  IF v_tier IS NULL THEN
    v_tier := 'free';
  END IF;

  IF v_tier = 'premium' THEN
    v_discount_rate := 1.00;
  ELSIF v_tier = 'standard' THEN
    v_discount_rate := 0.50;
  ELSE
    v_discount_rate := 0.00;
  END IF;

  RETURN QUERY
  SELECT 
    pkg.id,
    pkg.country_id,
    pkg.carrier_id,
    c.name AS carrier_name,
    pkg.package_type,
    pkg.title,
    pkg.description,
    pkg.data_allowance_mb,
    pkg.duration_days,
    pkg.is_unlimited,
    pkg.supplier_cost_usd,
    pkg.retail_price_usd,
    round(
      pkg.supplier_cost_usd + ((pkg.retail_price_usd - pkg.supplier_cost_usd) * (1.00 - v_discount_rate)),
      2
    ) AS effective_price_usd,
    round((pkg.retail_price_usd - pkg.supplier_cost_usd) * (1.00 - v_discount_rate), 2) AS app_fee_usd,
    round((pkg.retail_price_usd - pkg.supplier_cost_usd) * v_discount_rate, 2) AS discount_usd,
    pkg.ussd_recharge_code,
    pkg.activation_instructions,
    pkg.badge_label,
    v_tier AS account_tier
  FROM public.return_trip_packages pkg
  LEFT JOIN public.carriers c ON c.id = pkg.carrier_id
  WHERE pkg.country_id = v_line_country_id
    AND pkg.is_active = true
  ORDER BY 
    CASE 
      WHEN pkg.package_type = 'esim' THEN 0
      WHEN v_line_carrier_id IS NOT NULL AND pkg.carrier_id = v_line_carrier_id THEN 1
      ELSE 2
    END,
    effective_price_usd ASC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_user_calling_rates(p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(id uuid, country_code text, country_name text, phone_prefix text, destination_type text, cost_per_minute_usd numeric, base_rate_per_minute_usd numeric, effective_rate_per_minute_usd numeric, connection_fee_usd numeric, billing_increment_seconds integer, account_tier text, is_active boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_tier TEXT;
BEGIN
  v_tier := public.resolve_account_commerce_benefit(p_user_id);
  
  RETURN QUERY
  SELECT 
    r.id,
    r.country_code,
    r.country_name,
    r.phone_prefix,
    r.destination_type,
    r.cost_per_minute_usd,
    r.rate_per_minute_usd AS base_rate_per_minute_usd,
    round(
      CASE 
        WHEN r.cost_per_minute_usd IS NOT NULL AND r.cost_per_minute_usd > 0 THEN
          r.cost_per_minute_usd + COALESCE(
            public.resolve_app_fee('intelcallfee', v_tier, r.cost_per_minute_usd),
            CASE v_tier
              WHEN 'premium'  THEN round(r.cost_per_minute_usd * 0.05, 4)
              WHEN 'standard' THEN round(r.cost_per_minute_usd * 0.10, 4)
              ELSE round(r.cost_per_minute_usd * 0.15, 4)
            END
          )
        ELSE r.rate_per_minute_usd
      END,
      4
    ) AS effective_rate_per_minute_usd,
    0.00::NUMERIC AS connection_fee_usd, -- Strictly $0 connection fee per C12
    r.billing_increment_seconds,
    v_tier AS account_tier,
    r.is_active
  FROM public.call_rates r
  WHERE r.is_active = true
  ORDER BY r.country_name;
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_power_user(user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
BEGIN
  RETURN COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_power_user')::boolean, false);
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_user_suspended()
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_suspended')::boolean, false);
END;
$function$;

CREATE OR REPLACE FUNCTION public.prune_database_logs(p_cron_retention_days integer DEFAULT 14, p_alerts_retention_days integer DEFAULT 90)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_cron_deleted integer := 0;
  v_alerts_deleted integer := 0;
  v_cutoff_cron timestamptz;
  v_cutoff_alerts timestamptz;
BEGIN
  -- Validate sane bounds to prevent accidental total wipe
  IF p_cron_retention_days < 3 THEN
    RAISE EXCEPTION 'p_cron_retention_days must be at least 3 days';
  END IF;
  IF p_alerts_retention_days < 7 THEN
    RAISE EXCEPTION 'p_alerts_retention_days must be at least 7 days';
  END IF;

  v_cutoff_cron := pg_catalog.now() - (p_cron_retention_days || ' days')::interval;
  v_cutoff_alerts := pg_catalog.now() - (p_alerts_retention_days || ' days')::interval;

  -- Prune cron.job_run_details
  WITH deleted_cron AS (
    DELETE FROM cron.job_run_details
    WHERE start_time < v_cutoff_cron
    RETURNING 1
  )
  SELECT count(*)::integer INTO v_cron_deleted FROM deleted_cron;

  -- Prune public.system_alerts
  WITH deleted_alerts AS (
    DELETE FROM public.system_alerts
    WHERE created_at < v_cutoff_alerts
    RETURNING 1
  )
  SELECT count(*)::integer INTO v_alerts_deleted FROM deleted_alerts;

  RETURN pg_catalog.jsonb_build_object(
    'status', 'success',
    'cron_runs_pruned', v_cron_deleted,
    'cron_retention_days', p_cron_retention_days,
    'cron_cutoff', v_cutoff_cron,
    'alerts_pruned', v_alerts_deleted,
    'alerts_retention_days', p_alerts_retention_days,
    'alerts_cutoff', v_cutoff_alerts,
    'executed_at', pg_catalog.now()
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.quote_line_verification(p_sim_line_id uuid, p_user_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID;
  v_line RECORD;
  v_country RECORD;
  v_is_paid BOOLEAN := false;
  v_has_allowance BOOLEAN := false;
  v_period_start TIMESTAMPTZ;
  v_period_end TIMESTAMPTZ;
  v_allowance RECORD;
  v_wallet_balance NUMERIC(12,2) := 0.00;
  v_wallet_available NUMERIC(12,2) := 0.00;
  v_held_amount NUMERIC(12,2) := 0.00;
  v_in_flight_id UUID := NULL;
  v_effective_sms_cost NUMERIC(12,2) := 0.00;
  v_effective_call_cost NUMERIC(12,2) := 0.00;
BEGIN
  v_user_id := COALESCE(auth.uid(), p_user_id);
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'KS401';
  END IF;

  -- 1. Fetch SIM Line
  SELECT sl.id, sl.user_id, sl.phone_number, sl.country_id, sl.plan_type, 
         sl.protection_tier, sl.plan_expires_at, sl.verification_status, sl.carrier_status
  INTO v_line
  FROM public.sim_lines sl
  WHERE sl.id = p_sim_line_id;

  IF v_line.id IS NULL THEN
    RAISE EXCEPTION 'SIM line not found' USING ERRCODE = 'KS404';
  END IF;

  IF v_line.user_id != v_user_id AND NOT public.is_power_user(v_user_id) THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = 'KS403';
  END IF;

  -- Check existing in-flight attempt
  SELECT id INTO v_in_flight_id
  FROM public.line_verification_attempts
  WHERE sim_line_id = p_sim_line_id
    AND status IN ('reserved', 'dispatching', 'pending')
  LIMIT 1;

  -- 2. Fetch Country Pricing
  SELECT id, name, iso_code, COALESCE(sms_verify_cost, 0.00) AS sms_cost,
         COALESCE(call_verify_cost, 0.00) AS call_cost, verification_price_version
  INTO v_country
  FROM public.countries
  WHERE id = v_line.country_id;

  IF v_country.id IS NULL THEN
    -- Fallback: default zero
    v_effective_sms_cost := 0.00;
    v_effective_call_cost := 0.00;
  ELSE
    v_effective_sms_cost := v_country.sms_cost;
    v_effective_call_cost := v_country.call_cost;
  END IF;

  -- 3. Determine Paid Plan Entitlement & Allowance
  IF LOWER(COALESCE(v_line.plan_type, 'free')) IN ('standard', 'premium') 
     OR LOWER(COALESCE(v_line.protection_tier, 'standard')) = 'premium' THEN
    IF v_line.plan_expires_at IS NULL OR v_line.plan_expires_at > now() THEN
      v_is_paid := true;
      v_period_end := COALESCE(v_line.plan_expires_at, now() + interval '365 days');
      v_period_start := v_period_end - interval '365 days';

      INSERT INTO public.line_verification_allowances (
        sim_line_id, period_start, period_end
      ) VALUES (
        p_sim_line_id, v_period_start, v_period_end
      )
      ON CONFLICT (sim_line_id, period_start, period_end) DO NOTHING;

      SELECT * INTO v_allowance
      FROM public.line_verification_allowances
      WHERE sim_line_id = p_sim_line_id
        AND period_start = v_period_start
        AND period_end = v_period_end;

      IF v_allowance.id IS NOT NULL 
         AND v_allowance.consumed_attempt_id IS NULL 
         AND (v_allowance.reserved_attempt_id IS NULL OR v_allowance.reserved_attempt_id = v_in_flight_id) THEN
        v_has_allowance := true;
      END IF;
    END IF;
  END IF;

  -- 4. Check Wallet Available Funds
  SELECT COALESCE(balance, 0.00) INTO v_wallet_balance
  FROM public.wallets
  WHERE user_id = v_user_id;

  SELECT COALESCE(SUM(amount), 0.00) INTO v_held_amount
  FROM public.wallet_holds
  WHERE user_id = v_user_id AND status = 'active';

  v_wallet_available := GREATEST(0.00, v_wallet_balance - v_held_amount);

  RETURN jsonb_build_object(
    'sim_line_id', v_line.id,
    'phone_number', v_line.phone_number,
    'country_id', v_country.id,
    'country_name', v_country.name,
    'sms_verify_cost_usd', v_effective_sms_cost,
    'call_verify_cost_usd', v_effective_call_cost,
    'is_paid_plan', v_is_paid,
    'has_annual_allowance', v_has_allowance,
    'allowance_period_end', v_period_end,
    'wallet_balance_usd', v_wallet_balance,
    'wallet_available_usd', v_wallet_available,
    'price_version', COALESCE(v_country.verification_price_version, 1),
    'in_flight_attempt_id', v_in_flight_id
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.reap_stuck_executions(p_stuck_after_minutes integer DEFAULT 10, p_max_retries integer DEFAULT 3)
 RETURNS TABLE(requeued integer, dead_lettered integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_requeued integer := 0;
  v_dead integer := 0;
  v_in_flight_count integer := 0;
BEGIN
  -- 1. Identify stuck processing executions
  -- Distinguish between safe-to-requeue (pre-submission) and in-flight/ambiguous (post-submission)
  WITH stuck_all AS (
    SELECT t.id, t.reaper_retries, COALESCE(t.pre_processing_status, 'pending') AS back_to,
           t.reloadly_transaction_id,
           (COALESCE(h.carrier_in_flight, false) OR COALESCE(t.carrier_in_flight, false)) AS carrier_in_flight
    FROM public.topup_executions t
    LEFT JOIN public.wallet_holds h ON h.id = t.wallet_hold_id
    WHERE t.status = 'processing'
      AND COALESCE(t.processing_since, t.created_at) < now() - make_interval(mins => p_stuck_after_minutes)
    FOR UPDATE OF t SKIP LOCKED
  ),
  -- In-flight / ambiguous submissions: MUST NOT be requeued to pending (F06 double-purchase prevention)
  in_flight_flagged AS (
    UPDATE public.topup_executions t
    SET status = 'failed',
        carrier_in_flight = true,
        failure_reason = 'Stuck in processing with in-flight carrier submission. Dead-lettered for manual reconciliation to prevent duplicate purchase.',
        completed_at = now()
    FROM stuck_all s
    WHERE t.id = s.id
      AND (s.reloadly_transaction_id IS NOT NULL OR s.carrier_in_flight)
    RETURNING t.id
  ),
  -- Dead-letter pre-submission executions that have exhausted retries
  dead AS (
    UPDATE public.topup_executions t
    SET status = 'failed',
        failure_reason = 'Dead-lettered by reaper: repeatedly stuck in processing before provider submission (worker crash?)',
        completed_at = now()
    FROM stuck_all s
    WHERE t.id = s.id
      AND s.reloadly_transaction_id IS NULL
      AND NOT s.carrier_in_flight
      AND s.reaper_retries >= p_max_retries
    RETURNING t.id
  ),
  -- Safe to requeue: pre-submission executions with retries remaining
  requeue AS (
    UPDATE public.topup_executions t
    SET status = s.back_to,
        reaper_retries = t.reaper_retries + 1,
        processing_since = NULL
    FROM stuck_all s
    WHERE t.id = s.id
      AND s.reloadly_transaction_id IS NULL
      AND NOT s.carrier_in_flight
      AND s.reaper_retries < p_max_retries
    RETURNING t.id
  )
  SELECT 
    (SELECT count(*) FROM requeue),
    (SELECT count(*) FROM dead) + (SELECT count(*) FROM in_flight_flagged),
    (SELECT count(*) FROM in_flight_flagged)
  INTO v_requeued, v_dead, v_in_flight_count;

  IF v_in_flight_count > 0 THEN
    INSERT INTO public.system_alerts (kind, message, details)
    VALUES (
      'in_flight_execution_stuck',
      v_in_flight_count || ' execution(s) were stuck in processing with in-flight submissions and dead-lettered to prevent duplicate purchases.',
      jsonb_build_object('in_flight_count', v_in_flight_count, 'stuck_after_minutes', p_stuck_after_minutes)
    );
  END IF;

  IF (v_dead - v_in_flight_count) > 0 THEN
    INSERT INTO public.system_alerts (kind, message, details)
    VALUES (
      'execution_dead_lettered',
      (v_dead - v_in_flight_count) || ' execution(s) dead-lettered after repeatedly getting stuck in processing.',
      jsonb_build_object('dead_lettered', v_dead - v_in_flight_count, 'requeued', v_requeued)
    );
  END IF;

  RETURN QUERY SELECT v_requeued, v_dead;
END;
$function$;

CREATE OR REPLACE FUNCTION public.settle_line_verification_attempt(p_attempt_id uuid, p_outcome text, p_carrier_name text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_attempt RECORD;
  v_channel_label TEXT;
  v_desc TEXT;
BEGIN
  SELECT * INTO v_attempt
  FROM public.line_verification_attempts
  WHERE id = p_attempt_id
  FOR UPDATE;

  IF v_attempt.id IS NULL THEN
    RAISE EXCEPTION 'Attempt not found: %', p_attempt_id;
  END IF;

  IF v_attempt.status = 'terminal' THEN
    RETURN jsonb_build_object('success', true, 'status', 'terminal', 'outcome', v_attempt.outcome);
  END IF;

  IF p_outcome = 'succeeded' THEN
    -- 1. Settle Funds or Allowance
    IF v_attempt.funding_kind = 'wallet' AND v_attempt.wallet_hold_id IS NOT NULL THEN
      PERFORM public.capture_wallet_hold(
        v_attempt.wallet_hold_id,
        'verification_debit',
        'Real Live Verification (' || UPPER(v_attempt.method) || ')',
        jsonb_build_object('attempt_id', p_attempt_id, 'sim_line_id', v_attempt.sim_line_id)
      );
    ELSIF v_attempt.funding_kind = 'annual_allowance' THEN
      UPDATE public.line_verification_allowances
      SET consumed_attempt_id = p_attempt_id,
          reserved_attempt_id = NULL,
          updated_at = now()
      WHERE sim_line_id = v_attempt.sim_line_id
        AND (reserved_attempt_id = p_attempt_id OR consumed_attempt_id IS NULL);
    END IF;

    -- 2. Update SIM line verification & health score
    UPDATE public.sim_lines
    SET verification_status = 'verified',
        health_score = 100,
        carrier_verified_at = now(),
        detected_operator_name = COALESCE(p_carrier_name, detected_operator_name),
        updated_at = now()
    WHERE id = v_attempt.sim_line_id;

    -- 3. Log Activity
    v_channel_label := CASE WHEN v_attempt.method = 'sms' THEN 'SMS DLR Handshake' ELSE 'Missed Call Ring' END;
    v_desc := 'SIM line live verified active via ' || v_channel_label;
    IF p_carrier_name IS NOT NULL AND p_carrier_name <> '' THEN
      v_desc := v_desc || ' on ' || p_carrier_name;
    END IF;
    v_desc := v_desc || '. Health optimized to 100.';

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, created_at
    ) VALUES (
      v_attempt.sim_line_id, v_attempt.user_id, 'health_update', v_desc, now()
    );

    -- 4. Mark attempt terminal succeeded
    UPDATE public.line_verification_attempts
    SET status = 'terminal',
        outcome = 'succeeded',
        settlement_status = CASE 
          WHEN funding_kind = 'wallet' THEN 'captured'
          WHEN funding_kind = 'annual_allowance' THEN 'consumed'
          ELSE 'no_charge'
        END,
        carrier_name = COALESCE(p_carrier_name, carrier_name),
        completed_at = now(),
        updated_at = now()
    WHERE id = p_attempt_id;

  ELSE
    -- FAILED or INCONCLUSIVE: Release hold / allowance
    IF v_attempt.funding_kind = 'wallet' AND v_attempt.wallet_hold_id IS NOT NULL THEN
      PERFORM public.release_wallet_hold(
        v_attempt.wallet_hold_id,
        COALESCE(p_error_message, 'Verification check was unsuccessful')
      );
    ELSIF v_attempt.funding_kind = 'annual_allowance' THEN
      UPDATE public.line_verification_allowances
      SET reserved_attempt_id = NULL,
          updated_at = now()
      WHERE sim_line_id = v_attempt.sim_line_id
        AND reserved_attempt_id = p_attempt_id;
    END IF;

    UPDATE public.line_verification_attempts
    SET status = 'terminal',
        outcome = p_outcome,
        settlement_status = 'released',
        error_message = p_error_message,
        completed_at = now(),
        updated_at = now()
    WHERE id = p_attempt_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'attempt_id', p_attempt_id,
    'outcome', p_outcome,
    'settlement_status', CASE WHEN p_outcome = 'succeeded' THEN 'captured_or_consumed' ELSE 'released' END
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_fn_log_topup_activity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_event_type TEXT;
  v_metadata JSONB;
BEGIN
  -- Guard: If sim_line does not exist (e.g. being deleted in the current transaction),
  -- skip inserting into line_activity_log to avoid FK constraint violation.
  IF NEW.sim_line_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.sim_lines WHERE id = NEW.sim_line_id
  ) THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    v_event_type := CASE 
      WHEN NEW.retry_of IS NOT NULL THEN 'topup_retry_queued'
      ELSE 'topup_requested'
    END;

    v_metadata := jsonb_build_object(
      'amount', NEW.amount,
      'base_cost_usd', NEW.base_cost_usd,
      'execution_id', NEW.id,
      'execution_type', NEW.execution_type,
      'funding_kind', NEW.funding_kind,
      'provider', COALESCE(NEW.api_provider, 'zendit'),
      'offer_id', NEW.offer_id,
      'refill_channel', NEW.refill_channel
    );

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, metadata, created_at
    ) VALUES (
      NEW.sim_line_id, NEW.user_id, v_event_type, NULL, v_metadata, clock_timestamp()
    );

  ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF NEW.status = 'success' THEN
      v_event_type := 'topup_success';
      v_metadata := jsonb_build_object(
        'amount', NEW.amount,
        'execution_id', NEW.id,
        'execution_type', NEW.execution_type,
        'funding_kind', NEW.funding_kind,
        'provider', COALESCE(NEW.api_provider, 'zendit'),
        'transaction_id', NEW.reloadly_transaction_id,
        'refill_channel', NEW.refill_channel
      );
    ELSIF NEW.status = 'failed' THEN
      v_event_type := 'topup_failed';
      v_metadata := jsonb_build_object(
        'amount', NEW.amount,
        'execution_id', NEW.id,
        'execution_type', NEW.execution_type,
        'funding_kind', NEW.funding_kind,
        'provider', COALESCE(NEW.api_provider, 'zendit'),
        'failure_reason', COALESCE(NEW.failure_reason, 'Execution failed'),
        'refill_channel', NEW.refill_channel
      );
    ELSIF NEW.status = 'refunded' THEN
      v_event_type := 'topup_refunded';
      v_metadata := jsonb_build_object(
        'amount', NEW.amount,
        'execution_id', NEW.id,
        'execution_type', NEW.execution_type,
        'funding_kind', NEW.funding_kind,
        'refund_reason', COALESCE(NEW.failure_reason, 'Wallet refunded')
      );
    ELSIF NEW.status = 'cancelled' THEN
      v_event_type := 'topup_cancelled';
      v_metadata := jsonb_build_object(
        'amount', NEW.amount,
        'execution_id', NEW.id,
        'execution_type', NEW.execution_type,
        'funding_kind', NEW.funding_kind
      );
    ELSE
      RETURN NEW;
    END IF;

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, metadata, created_at
    ) VALUES (
      NEW.sim_line_id, NEW.user_id, v_event_type, NULL, v_metadata, clock_timestamp()
    );
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_fn_notify_topup_result()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_phone  text;
  v_amount text;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;
  IF NEW.status NOT IN ('success', 'failed') THEN
    RETURN NEW;
  END IF;

  IF NEW.sim_line_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.sim_lines WHERE id = NEW.sim_line_id) THEN
    RETURN NEW;
  END IF;

  SELECT phone_number INTO v_phone FROM public.sim_lines WHERE id = NEW.sim_line_id;
  v_amount := to_char(COALESCE(NEW.amount, 0), 'FM99999990.00');

  IF NEW.status = 'success' THEN
    INSERT INTO public.notifications
      (user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read)
    VALUES
      (NEW.user_id, 'top_up_success', 'Recharge successful',
       'Your recharge of $' || v_amount || ' for ' || COALESCE(v_phone, 'your line') || ' completed.',
       '/sim_lines/' || NEW.sim_line_id, NEW.sim_line_id, ARRAY['push']::text[], false);
  ELSE
    INSERT INTO public.notifications
      (user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read)
    VALUES
      (NEW.user_id, 'top_up_failed', 'Recharge failed',
       'We could not complete your $' || v_amount || ' recharge for ' || COALESCE(v_phone, 'your line') || '. Please review your wallet and line.',
       '/sim_lines/' || NEW.sim_line_id, NEW.sim_line_id, ARRAY['push']::text[], false);
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_scheduled_topup_health_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF EXISTS (SELECT 1 FROM public.sim_lines WHERE id = OLD.sim_line_id) THEN
      UPDATE public.sim_lines SET updated_at = NOW() WHERE id = OLD.sim_line_id;
    END IF;
    RETURN OLD;
  ELSE
    IF EXISTS (SELECT 1 FROM public.sim_lines WHERE id = NEW.sim_line_id) THEN
      UPDATE public.sim_lines SET updated_at = NOW() WHERE id = NEW.sim_line_id;
    END IF;
    RETURN NEW;
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.resolve_account_commerce_benefit(p_user_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_highest_tier   TEXT := 'free';
  v_line           RECORD;
  v_entitlement    JSONB;
  v_tier           TEXT;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN 'free';
  END IF;

  FOR v_line IN
    SELECT id FROM public.sim_lines
    WHERE user_id = p_user_id
      AND status = 'active'
  LOOP
    v_entitlement := public.resolve_line_entitlement(v_line.id);
    v_tier := v_entitlement->>'effective_tier';
    
    IF v_tier = 'premium' THEN
      RETURN 'premium';
    ELSIF v_tier = 'standard' AND v_highest_tier <> 'premium' THEN
      v_highest_tier := 'standard';
    END IF;
  END LOOP;

  RETURN v_highest_tier;
END;
$function$;

CREATE OR REPLACE FUNCTION public.resolve_app_fee(p_item text, p_tier text, p_base_amount numeric)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_rule RECORD;
  v_pct  NUMERIC;
  v_min  NUMERIC;
  v_fee  NUMERIC;
  v_tier TEXT := lower(coalesce(p_tier, 'free'));
BEGIN
  IF p_base_amount IS NULL OR p_base_amount <= 0 THEN
    RETURN 0.00;
  END IF;

  -- 1. Look for active published rule
  SELECT * INTO v_rule
  FROM public.app_fee_rules
  WHERE appfees_item = p_item
    AND status = 'published'
    AND (effective_from IS NULL OR effective_from <= now())
    AND (effective_to IS NULL OR effective_to > now())
  ORDER BY version DESC
  LIMIT 1;

  -- 2. Fallback to latest draft rule if no published rule exists
  IF NOT FOUND THEN
    SELECT * INTO v_rule
    FROM public.app_fee_rules
    WHERE appfees_item = p_item
    ORDER BY version DESC
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    RETURN 0.00;
  END IF;

  IF v_tier = 'premium' THEN
    v_pct := v_rule.prem_percentage;
    v_min := v_rule.prem_minimum;
  ELSIF v_tier = 'standard' THEN
    v_pct := v_rule.stand_percentage;
    v_min := v_rule.stand_minimum;
  ELSE
    v_pct := v_rule.free_percentage;
    v_min := v_rule.free_minimum;
  END IF;

  v_pct := coalesce(v_pct, 0.0);
  v_min := coalesce(v_min, 0.0);

  -- Calling fees are percentage-only and require 4 decimal places of precision ($0.0001/min)
  IF p_item = 'intelcallfee' THEN
    v_fee := round((p_base_amount * v_pct) / 100.0, 4);
  ELSE
    v_fee := round(greatest((p_base_amount * v_pct) / 100.0, v_min), 2);
  END IF;

  RETURN v_fee;
END;
$function$;

CREATE OR REPLACE FUNCTION public.format_sim_line_tier_defaults()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.plan_type = 'free' THEN
    NEW.plan_expires_at := NULL;
    NEW.protection_tier := 'basic';
  END IF;
  RETURN NEW;
END;
$function$;

