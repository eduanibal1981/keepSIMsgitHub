CREATE FUNCTION public.admin_esim_support(p_query text DEFAULT '') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 PERFORM public.assert_admin();
 IF length(coalesce(p_query,''))>100 THEN RAISE EXCEPTION 'Invalid search'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO result FROM (
 SELECT e.id,e.user_id AS owner_id,right(e.iccid,4) AS iccid_suffix,e.profile_state,e.installation_state,e.bundle_state,e.last_observation_at,e.usage_observed_at,e.usage_error_code,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('id',c.id,'action',c.action,'state',c.state,'submitted_at',c.submitted_at,'error_code',c.error_code)),'[]'::jsonb) FROM esim_private.controls c WHERE c.profile_id=e.id) AS controls,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('order_id',o.id,'kind',o.operation_kind,'status',o.status,'state',r.state,'error_code',r.error_code)),'[]'::jsonb) FROM public.esim_orders o LEFT JOIN esim_private.order_runs r ON r.order_id=o.id WHERE o.id=e.order_id OR o.recharge_profile_id=e.id) AS operations
 FROM public.user_esims e WHERE e.provider='esimaccess' AND (e.id::text=p_query OR e.user_id::text=p_query OR
 (p_query~'^[0-9]{4}$' AND right(e.iccid,4)=p_query) OR (coalesce(p_query,'')='' AND (esim_private.control_pending(e.id)
 OR EXISTS(SELECT 1 FROM esim_private.order_runs r JOIN public.esim_orders o ON o.id=r.order_id WHERE (o.id=e.order_id OR o.recharge_profile_id=e.id) AND r.state IN('reconciling','support_required')))))
 ORDER BY e.last_observation_at NULLS FIRST LIMIT 50) x;
 PERFORM public.admin_log('esim.support.search','esim',NULL,NULL,jsonb_build_object('returned',jsonb_array_length(result)),'Redacted support search');
 RETURN jsonb_build_object('profiles',result,'runtime',public.admin_esim_runtime_status(),
 'switches',(SELECT jsonb_build_object('cancellation_enabled',cancellation_enabled,'service_controls_enabled',service_controls_enabled,'automation_enabled',automation_enabled) FROM esim_private.accounts WHERE account_key='primary'),
 'funding_health','UNKNOWN','credential_health','UNKNOWN',
 'catalogue_last_sync',(SELECT max(updated_at) FROM public.esim_offers_cache WHERE provider='esimaccess'));
END $$;
CREATE FUNCTION public.admin_esim_support_action(p_profile_id uuid,p_action text,p_reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_admin();
 IF p_action IS NULL OR p_action NOT IN('refresh','escalate','reconcile') OR p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 8 AND 500 THEN RAISE EXCEPTION 'A reason is required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.user_esims WHERE id=p_profile_id AND provider='esimaccess') THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 IF p_action='refresh' THEN
  INSERT INTO esim_private.profile_work(profile_id,next_check_at,requested_at) VALUES(p_profile_id,now(),now())
  ON CONFLICT(profile_id) DO UPDATE SET next_check_at=now(),requested_at=now(),terminal_checks=0;
 ELSIF p_action='escalate' THEN
  INSERT INTO esim_private.support_cases(profile_id,actor_id,reason) VALUES(p_profile_id,auth.uid(),p_reason);
 ELSE
  -- Read-only recovery can inspect a quarantined request, never POST again.
  UPDATE esim_private.controls SET state='reconciling',next_check_at=now(),attempts=0 WHERE profile_id=p_profile_id AND state='support_required' AND submitted_at IS NOT NULL;
 END IF;
 PERFORM public.admin_log('esim.support.'||p_action,'esim_profile',p_profile_id::text,NULL,jsonb_build_object('read_only',true),p_reason);
 RETURN '{"status":"QUEUED","read_only":true}'::jsonb;
END $$;
CREATE FUNCTION public.admin_pause_esim_capability(p_capability text,p_reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_admin();
 IF p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 8 AND 500 OR p_capability IS NULL OR p_capability NOT IN('cancel','service_controls','automation') THEN RAISE EXCEPTION 'Invalid capability or reason'; END IF;
 UPDATE esim_private.accounts SET cancellation_enabled=CASE WHEN p_capability='cancel' THEN false ELSE cancellation_enabled END,
 service_controls_enabled=CASE WHEN p_capability='service_controls' THEN false ELSE service_controls_enabled END,
 automation_enabled=CASE WHEN p_capability='automation' THEN false ELSE automation_enabled END WHERE account_key='primary';
 PERFORM public.admin_log('esim.capability.pause','esim',p_capability,NULL,jsonb_build_object('enabled',false),p_reason);
 RETURN '{"status":"PAUSED","recovery_preserved":true}'::jsonb;
END $$;

DO $acl$ DECLARE n text;r record; BEGIN
 FOREACH n IN ARRAY ARRAY['refund_scopes','control_quotes','controls','cancellation_refunds','support_cases','automation_consents','automation_orders','automation_audit'] LOOP
  EXECUTE format('ALTER TABLE esim_private.%I ENABLE ROW LEVEL SECURITY',n);
  EXECUTE format('REVOKE ALL ON esim_private.%I FROM PUBLIC,anon,authenticated',n);
  EXECUTE format('GRANT SELECT ON esim_private.%I TO service_role',n);
 END LOOP;
 -- The schema is private. Revoke every newly added helper explicitly.
 FOR r IN SELECT p.oid::regprocedure ident FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='esim_private'
 AND p.proname IN('refund_context','control_pending','control_refusal','automation_exposure','stop_automation','accept_recharge','quote_auto_daily','quote_auto_fixed') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.ident);
 END LOOP;
 FOR r IN SELECT p.oid::regprocedure ident,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
 AND p.proname IN('service_esim_set_refund_scope','get_esim_controls','request_esim_control','service_esim_claim_control','service_esim_mark_control_submitted','service_esim_finish_control','service_esim_settle_cancellation','get_esim_automation','set_esim_automation','service_esim_evaluate_automation','admin_esim_support','admin_esim_support_action','admin_pause_esim_capability') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.ident);
  IF r.proname LIKE 'service_%' THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.ident);
  ELSE EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',r.ident); END IF;
 END LOOP;
END $acl$;
NOTIFY pgrst,'reload schema';
