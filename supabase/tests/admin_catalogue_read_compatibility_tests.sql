-- Synthetic fixtures only; run through tools/financial-tests/admin-catalogue-read.mjs.

-- CASE: anonymous callers cannot inspect either supplier view or authorize reads
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{"role":"anon"}',true);
DO $$ BEGIN
  BEGIN PERFORM * FROM public.admin_internal_provider_offers; RAISE EXCEPTION 'Anonymous curated read allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM * FROM public.admin_internal_provider_offers_cache; RAISE EXCEPTION 'Anonymous cache read allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM public.authorize_admin_catalogue_read(); RAISE EXCEPTION 'Anonymous guard call allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: ordinary authenticated customers cannot read supplier costs
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ BEGIN
  BEGIN PERFORM * FROM public.admin_internal_provider_offers; RAISE EXCEPTION 'Customer curated read allowed'; EXCEPTION WHEN SQLSTATE 'KS460' THEN NULL; END;
  BEGIN PERFORM * FROM public.admin_internal_provider_offers_cache; RAISE EXCEPTION 'Customer cache read allowed'; EXCEPTION WHEN SQLSTATE 'KS460' THEN NULL; END;
END $$;

-- CASE: editable user metadata cannot grant catalogue administration
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001","user_metadata":{"is_power_user":true}}',true);
DO $$ BEGIN
  BEGIN PERFORM * FROM public.admin_internal_provider_offers; RAISE EXCEPTION 'Forged curated read allowed'; EXCEPTION WHEN SQLSTATE 'KS460' THEN NULL; END;
  BEGIN PERFORM * FROM public.admin_internal_provider_offers_cache; RAISE EXCEPTION 'Forged cache read allowed'; EXCEPTION WHEN SQLSTATE 'KS460' THEN NULL; END;
END $$;

-- CASE: a trusted flag without an authenticated user is insufficient
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","app_metadata":{"is_power_user":true}}',true);
DO $$ BEGIN
  BEGIN PERFORM * FROM public.admin_internal_provider_offers; RAISE EXCEPTION 'Missing-user read allowed'; EXCEPTION WHEN SQLSTATE 'KS460' THEN NULL; END;
END $$;

-- CASE: a trusted Admin can inspect the current cache with exact provider and operator filters
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001","app_metadata":{"is_power_user":true}}',true);
DO $$ DECLARE r record; BEGIN
  SELECT * INTO STRICT r FROM public.admin_internal_provider_offers_cache
  WHERE api_provider='dtone' AND carrier_code='3221' ORDER BY price_fixed_usd;
  IF r.offer_id<>'fixture-dtone' OR r.price_fixed_usd<>2 OR r.source_currency<>'OMR' OR r.source_amount_native<>.77 THEN RAISE EXCEPTION 'Supplier fields changed'; END IF;
  IF (SELECT count(*) FROM public.admin_internal_provider_offers_cache)<>2 THEN RAISE EXCEPTION 'Admin cache is incomplete'; END IF;
END $$;

-- CASE: the curated-first Admin query retains pricing and active fields
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001","app_metadata":{"is_power_user":true}}',true);
DO $$ DECLARE r record; BEGIN
  SELECT * INTO STRICT r FROM public.admin_internal_provider_offers
  WHERE provider_code='dtone' AND carrier_id='20000000-0000-4000-8000-000000000001' ORDER BY effective_price_usd;
  IF r.offer_code<>'fixture-dtone' OR r.effective_price_usd<>2 OR NOT r.is_active THEN RAISE EXCEPTION 'Curated projection changed'; END IF;
END $$;

-- CASE: supplier views are read-only even for the trusted Admin
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  BEGIN UPDATE public.admin_internal_provider_offers_cache SET price_fixed_usd=999 WHERE offer_id='fixture-dtone'; RAISE EXCEPTION 'Admin cache write allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM public.admin_internal_provider_offers WHERE offer_code='fixture-dtone'; RAISE EXCEPTION 'Admin curated delete allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: grants, safe function search path and security barriers are explicit
RESET ROLE;
DO $$ DECLARE n text; BEGIN
  FOREACH n IN ARRAY ARRAY['admin_internal_provider_offers','admin_internal_provider_offers_cache'] LOOP
    IF has_table_privilege('anon','public.'||n,'SELECT') OR NOT has_table_privilege('authenticated','public.'||n,'SELECT')
       OR has_table_privilege('authenticated','public.'||n,'INSERT,UPDATE,DELETE') OR has_table_privilege('service_role','public.'||n,'SELECT') THEN RAISE EXCEPTION 'Unexpected view grants: %',n; END IF;
    IF NOT EXISTS(SELECT 1 FROM pg_class c WHERE c.oid=('public.'||n)::regclass AND c.reloptions @> ARRAY['security_barrier=true','security_invoker=false']) THEN RAISE EXCEPTION 'Unsafe view options: %',n; END IF;
  END LOOP;
  IF NOT EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid='public.authorize_admin_catalogue_read()'::regprocedure AND p.prosecdef AND p.proconfig @> ARRAY['search_path=""']) THEN RAISE EXCEPTION 'Unsafe guard context'; END IF;
END $$;
