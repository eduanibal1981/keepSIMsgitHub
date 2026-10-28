BEGIN;
SET LOCAL statement_timeout='20s';
DO $$DECLARE r record;BEGIN
 IF EXISTS(SELECT 1 FROM esim_private.accounts WHERE group_orders_enabled OR new_sales_enabled OR recharge_enabled OR automation_enabled OR cancellation_enabled OR service_controls_enabled OR daily_duration_enabled) THEN RAISE EXCEPTION 'Paid acceptance gates unexpectedly open'; END IF;
 IF (SELECT max_group_members FROM esim_private.accounts WHERE account_key='primary')<>3 THEN RAISE EXCEPTION 'Unexpected group cap'; END IF;
 FOR r IN SELECT p.oid,p.proname,p.proconfig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN('set_esim_profile_label','quote_esim_group','accept_esim_group','get_esim_organization','admin_esim_group','admin_pause_esim_group_orders','prune_esim_group_quotes') LOOP
  IF has_function_privilege('anon',r.oid,'EXECUTE') THEN RAISE EXCEPTION 'Anonymous RPC exposure'; END IF;
  IF NOT('search_path=""'=ANY(r.proconfig)) THEN RAISE EXCEPTION 'Unsafe function path'; END IF;
  IF r.proname='prune_esim_group_quotes' AND has_function_privilege('authenticated',r.oid,'EXECUTE') THEN RAISE EXCEPTION 'Service cleanup exposed'; END IF;
 END LOOP;
 FOR r IN SELECT c.oid,c.relrowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='esim_private' AND c.relname IN('group_quotes','group_batches','group_members','profile_labels') LOOP
  IF NOT r.relrowsecurity OR has_table_privilege('authenticated',r.oid,'SELECT') OR has_table_privilege('anon',r.oid,'SELECT') THEN RAISE EXCEPTION 'Private group rows exposed'; END IF;
 END LOOP;
END $$;
SELECT set_config('request.jwt.claim.role','authenticated',true),set_config('request.jwt.claim.sub',(SELECT p.id::text FROM public.profiles p JOIN auth.users u ON u.id=p.id WHERE NOT coalesce(p.is_suspended,false) AND u.deleted_at IS NULL AND (u.banned_until IS NULL OR u.banned_until<=now()) LIMIT 1),true);
SELECT set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',auth.uid(),'user_metadata',jsonb_build_object('is_power_user',true))::text,true);
SELECT set_config('keepsims.esim14.fixed_members',(SELECT jsonb_agg(jsonb_build_object('offer_id','esimaccess_'||bundle_name,'traveller_label',market||' traveller'))::text FROM(SELECT market,c.bundle_name FROM(VALUES('OM'),('EG')) markets(market) CROSS JOIN LATERAL(SELECT bundle_name FROM public.esim_offers_cache WHERE provider='esimaccess' AND is_active AND market=ANY(countries) AND cardinality(countries)=1 AND catalogue_details->>'plan_type'='total' ORDER BY wholesale_price_usd LIMIT 1)c) x),true);
SELECT set_config('keepsims.esim14.daily_package',(SELECT bundle_name FROM public.esim_offers_cache WHERE provider='esimaccess' AND is_active AND 'OM'=ANY(countries) AND catalogue_details->>'plan_type'='daily_throttled' ORDER BY wholesale_price_usd LIMIT 1),true);
SET LOCAL ROLE authenticated;
DO $$DECLARE result jsonb;preview jsonb;BEGIN
 result:=public.get_esim_organization();
 IF result->'groups'<>'[]'::jsonb OR result->'labels'<>'[]'::jsonb THEN RAISE EXCEPTION 'Unexpected owned acceptance records'; END IF;
 IF public.set_esim_profile_label('00000000-0000-4000-8000-000000000001','Private','Trip')->>'status'<>'PROFILE_UNAVAILABLE' THEN RAISE EXCEPTION 'Profile ownership bypass'; END IF;
 preview:=public.quote_esim_group('Read-only acceptance',current_setting('keepsims.esim14.fixed_members')::jsonb);
 IF preview->>'status'<>'QUOTED' OR preview->>'acceptance_enabled'<>'false' OR jsonb_array_length(preview->'members')<>2 OR position('wholesale' in preview::text)>0 THEN RAISE EXCEPTION 'Real OM/EG fixed quote failed closed validation'; END IF;
 result:=public.quote_esim_group('Daily unavailable',jsonb_build_array(jsonb_build_object('offer_id',current_setting('keepsims.esim14.daily_package'),'traveller_label','Daily traveller','period_count',5)));
 IF result->>'status'<>'DURATION_PRICE_UNAVAILABLE' THEN RAISE EXCEPTION 'Unverified duration price became available'; END IF;
 IF (SELECT count(*) FROM public.compare_esim_offers_v2('OM',p_limit=>3,p_plan_types=>ARRAY['total']))=0 THEN RAISE EXCEPTION 'Retail catalogue regression'; END IF;
 BEGIN PERFORM public.accept_esim_group((preview->>'quote_id')::uuid,(preview->>'acceptance_key')::uuid,gen_random_uuid());RAISE EXCEPTION 'Missing money session allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.admin_esim_group(gen_random_uuid());RAISE EXCEPTION 'Mutable metadata admin bypass';EXCEPTION WHEN SQLSTATE 'KS460' THEN NULL;END;
 BEGIN PERFORM public.admin_pause_esim_group_orders('Acceptance denial');RAISE EXCEPTION 'Admin group pause bypass';EXCEPTION WHEN SQLSTATE 'KS460' THEN NULL;END;
END $$;
SET LOCAL ROLE anon;
DO $$BEGIN
 BEGIN PERFORM public.get_esim_organization();RAISE EXCEPTION 'Anonymous organization access';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $$;
RESET ROLE;
ROLLBACK;
SELECT 'ESIM-13/14 live ACL, ownership, private labels, real OM/EG retail/group quotes, daily fail-closed price, session and admin checks passed; transaction rolled back' result;
