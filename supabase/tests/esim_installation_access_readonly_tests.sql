-- ESIM-06 uses the existing ESIM-03 owner projection. No schema/data mutation.
BEGIN;
DO $$
DECLARE owner_id uuid; other_id uuid:=gen_random_uuid(); expected integer; actual integer;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_class WHERE oid='public.customer_esim_profiles'::regclass
   AND reloptions @> ARRAY['security_invoker=true','security_barrier=true']) THEN
  RAISE EXCEPTION 'Owner view must be an invoker security barrier'; END IF;
 IF has_table_privilege('anon','public.customer_esim_profiles','SELECT') OR
    has_schema_privilege('authenticated','esim_private','USAGE') THEN
  RAISE EXCEPTION 'Installation boundary exposed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public'
  AND table_name='customer_esim_profiles' AND column_name='last_observation_at') THEN
  RAISE EXCEPTION 'Recovery observation timestamp missing'; END IF;
 SELECT user_id INTO owner_id FROM public.user_esims ORDER BY id LIMIT 1;
 IF owner_id IS NOT NULL THEN
  SELECT count(*) INTO expected FROM public.user_esims WHERE user_id=owner_id;
  PERFORM set_config('request.jwt.claim.sub',owner_id::text,true);
  PERFORM set_config('request.jwt.claim.role','authenticated',true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT count(*) INTO actual FROM public.customer_esim_profiles;
  IF actual<>expected THEN RAISE EXCEPTION 'Owner projection mismatch'; END IF;
  IF EXISTS(SELECT 1 FROM public.customer_esim_profiles WHERE user_id<>auth.uid()) THEN
   RAISE EXCEPTION 'Cross-owner disclosure'; END IF;
  IF EXISTS(SELECT 1 FROM public.customer_esim_profiles WHERE NOT issuance_verified AND lpa_string IS NOT NULL) THEN
   RAISE EXCEPTION 'Unverified activation material disclosed'; END IF;
  EXECUTE 'RESET ROLE';
 END IF;
 PERFORM set_config('request.jwt.claim.sub',other_id::text,true);
 EXECUTE 'SET LOCAL ROLE authenticated';
 IF EXISTS(SELECT 1 FROM public.customer_esim_profiles) THEN RAISE EXCEPTION 'Unrelated account can read profiles'; END IF;
 EXECUTE 'RESET ROLE';
 EXECUTE 'SET LOCAL ROLE anon';
 BEGIN
  PERFORM 1 FROM public.customer_esim_profiles;
  RAISE EXCEPTION 'Anonymous installation read allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 EXECUTE 'RESET ROLE';
END $$;
ROLLBACK;
SELECT 'PASS owner, cross-owner, anon, unverified payload and observation boundary' AS verification;
