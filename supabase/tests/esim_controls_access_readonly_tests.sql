BEGIN;
SET LOCAL statement_timeout='15s';
DO $$DECLARE r record;BEGIN
 IF EXISTS(SELECT 1 FROM esim_private.accounts WHERE cancellation_enabled OR service_controls_enabled OR automation_enabled OR new_sales_enabled OR recharge_enabled OR daily_duration_enabled) THEN RAISE EXCEPTION 'Acceptance gates unexpectedly enabled'; END IF;
 FOR r IN SELECT p.oid,p.proname,p.proconfig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN('get_esim_controls','get_esim_automation','set_esim_automation','request_esim_control','service_esim_claim_control','service_esim_mark_control_submitted','service_esim_finish_control','service_esim_set_refund_scope','service_esim_settle_cancellation','service_esim_evaluate_automation','service_esim_prepare_automation','admin_esim_support','admin_esim_support_action','admin_pause_esim_capability') LOOP
  IF has_function_privilege('anon',r.oid,'EXECUTE') THEN RAISE EXCEPTION 'Anonymous execution: %',r.proname; END IF;
  IF r.proname LIKE 'service_%' AND has_function_privilege('authenticated',r.oid,'EXECUTE') THEN RAISE EXCEPTION 'Service execution leaked'; END IF;
  IF NOT ('search_path=""'=ANY(r.proconfig)) THEN RAISE EXCEPTION 'Unsafe path: %',r.proname; END IF;
 END LOOP;
 FOR r IN SELECT c.oid,n.nspname,c.relname,c.relrowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='esim_private' AND c.relkind='r'
 AND c.relname IN('controls','control_quotes','refund_scopes','cancellation_refunds','automation_consents','automation_orders','automation_audit','support_cases') LOOP
  IF NOT r.relrowsecurity OR has_table_privilege('authenticated',r.oid,'SELECT') OR has_table_privilege('anon',r.oid,'SELECT') THEN RAISE EXCEPTION 'Private table leaked'; END IF;
 END LOOP;
END $$;
SELECT set_config('request.jwt.claim.role','authenticated',true),set_config('request.jwt.claim.sub',
 (SELECT p.id::text FROM public.profiles p JOIN auth.users u ON u.id=p.id WHERE NOT coalesce(p.is_suspended,false) AND u.deleted_at IS NULL AND (u.banned_until IS NULL OR u.banned_until<=now()) LIMIT 1),true);
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',auth.uid(),'user_metadata',jsonb_build_object('is_power_user',true))::text,true);
SET LOCAL ROLE authenticated;
DO $$BEGIN
 IF public.get_esim_controls('00000000-0000-4000-8000-000000000001')->>'status'<>'PROFILE_UNAVAILABLE' THEN RAISE EXCEPTION 'Owner lookup leak'; END IF;
 IF public.get_esim_automation('00000000-0000-4000-8000-000000000001')->>'status'<>'PROFILE_UNAVAILABLE' THEN RAISE EXCEPTION 'Automation lookup leak'; END IF;
 BEGIN PERFORM public.request_esim_control('00000000-0000-4000-8000-000000000001','suspend',gen_random_uuid());RAISE EXCEPTION 'Session bypass';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.set_esim_automation('00000000-0000-4000-8000-000000000001',0,true,'{}');RAISE EXCEPTION 'Consent session bypass';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.admin_esim_support();RAISE EXCEPTION 'Mutable user metadata bypass';EXCEPTION WHEN SQLSTATE 'KS460' THEN NULL;END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.role','service_role',true),set_config('request.jwt.claims','{"role":"service_role"}',true);
DO $$DECLARE r jsonb;BEGIN
 IF (SELECT count(*) FROM esim_private.controls)<>0 THEN RAISE EXCEPTION 'Read-only acceptance requires no live controls';END IF;
 PERFORM public.service_esim_prepare_automation();
 IF public.service_esim_claim_control() IS NOT NULL THEN RAISE EXCEPTION 'Unexpected control work';END IF;
 IF public.service_esim_evaluate_automation()->>'status'<>'IDLE' THEN RAISE EXCEPTION 'Unexpected automatic work';END IF;
 r:=public.admin_esim_support();
 IF r->'profiles'<>'[]'::jsonb OR position('matching_id' in r::text)>0 OR position('lpa_string' in r::text)>0 THEN RAISE EXCEPTION 'Support projection leak'; END IF;
END $$;
ROLLBACK;
SELECT 'ESIM-10/11/12 live ACL, owner/session/admin boundaries and disabled worker lanes passed; transaction rolled back' AS result;
