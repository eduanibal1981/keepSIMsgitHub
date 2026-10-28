-- Deployed boundary checks. No fixture rows, schema changes, provider calls,
-- financial actions or persistent data writes; always roll back.
BEGIN;
DO $$DECLARE u uuid;offer text;BEGIN
 IF EXISTS(SELECT 1 FROM esim_private.daily_prices) THEN RAISE EXCEPTION 'Run quote checks only against unseeded duration pricing';END IF;
 SELECT a.id INTO u FROM auth.users a JOIN public.profiles p ON p.id=a.id
 WHERE a.deleted_at IS NULL AND (a.banned_until IS NULL OR a.banned_until<=now()) AND NOT coalesce(p.is_suspended,false) LIMIT 1;
 IF u IS NULL THEN RAISE EXCEPTION 'No eligible read-test identity'; END IF;
 SELECT bundle_name INTO offer FROM public.esim_offers_cache WHERE provider='esimaccess' AND is_active
 AND catalogue_details->>'plan_type' IN('daily_throttled','daily_cutoff','daily_unlimited') AND catalogue_details->>'duration_unit'='DAY' LIMIT 1;
 IF offer IS NULL THEN RAISE EXCEPTION 'No daily catalogue fixture';END IF;
 PERFORM set_config('request.jwt.claim.sub',u::text,true);
 PERFORM set_config('request.jwt.claim.role','authenticated',true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',u)::text,true);
 PERFORM set_config('esim09.test.offer',offer,true);
END $$;
SET LOCAL ROLE authenticated;
DO $$DECLARE r jsonb;BEGIN
 r:=public.quote_esim_daily_purchase(current_setting('esim09.test.offer'),5,1);
 IF r->>'status' IS DISTINCT FROM 'DURATION_PRICE_UNAVAILABLE' THEN RAISE EXCEPTION 'Unknown pricing did not fail closed';END IF;
 r:=public.quote_esim_daily_purchase(current_setting('esim09.test.offer'),366,1);
 IF r->>'status' IS DISTINCT FROM 'INVALID_DURATION' THEN RAISE EXCEPTION 'Invalid duration accepted';END IF;
 r:=public.quote_esim_daily_extension('00000000-0000-4000-8000-000000000000',current_setting('esim09.test.offer'),'00000000-0000-4000-8000-000000000000',5);
 IF r->>'status' IS DISTINCT FROM 'PROFILE_UNAVAILABLE' THEN RAISE EXCEPTION 'Foreign/missing profile boundary failed';END IF;
 BEGIN PERFORM 1 FROM esim_private.daily_prices;RAISE EXCEPTION 'Private prices exposed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.service_esim_store_daily_price(current_setting('esim09.test.offer'),5,32000,'fixture:unauthorized',now(),now()+interval '1 hour');RAISE EXCEPTION 'Price import exposed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $$;
SET LOCAL ROLE anon;
DO $$BEGIN
 BEGIN PERFORM public.quote_esim_daily_purchase('fixture',5,1);RAISE EXCEPTION 'Anonymous quote exposed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM 1 FROM esim_private.daily_purchase_quotes;RAISE EXCEPTION 'Private quote exposed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $$;
RESET ROLE;
SELECT jsonb_build_object('owner_quote_missing_price_refused',true,'invalid_duration_refused',true,
 'missing_profile_refused',true,'private_price_and_quote_reads_denied',true,'client_import_denied',true,'anonymous_quote_denied',true,
 'daily_price_rows',(SELECT count(*) FROM esim_private.daily_prices),
 'daily_quote_rows',(SELECT count(*) FROM esim_private.daily_purchase_quotes)) result;
ROLLBACK;
