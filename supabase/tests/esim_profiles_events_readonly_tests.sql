-- ESIM-03/04 live, read-only permission checks. No provider/wallet calls.
BEGIN;
DO $test$
DECLARE owner_id uuid; expected integer; actual integer;
BEGIN
 SELECT user_id INTO owner_id FROM public.user_esims WHERE user_id IS NOT NULL LIMIT 1;
 IF owner_id IS NOT NULL THEN
  SELECT count(*) INTO expected FROM public.user_esims WHERE user_id=owner_id;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',owner_id)::text,true);
  PERFORM set_config('role','authenticated',true);
  SELECT count(*) INTO actual FROM public.customer_esim_profiles;
  IF actual<>expected THEN RAISE EXCEPTION 'Owner projection mismatch'; END IF;
  IF EXISTS(SELECT 1 FROM public.customer_esim_profiles WHERE NOT issuance_verified AND (lpa_string IS NOT NULL OR expires_at IS NOT NULL)) THEN
   RAISE EXCEPTION 'Unverified legacy delivery exposed'; END IF;
  BEGIN PERFORM public.service_esim_claim_order(); RAISE EXCEPTION 'Service RPC exposed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('role','postgres',true);
 END IF;
 IF has_schema_privilege('authenticated','esim_private','USAGE') OR
    has_column_privilege('authenticated','public.esim_orders','wholesale_price_usd','SELECT') OR
    has_function_privilege('anon','public.service_esim_accept_event(text,text,jsonb)','EXECUTE') THEN
  RAISE EXCEPTION 'Internal eSIM access exposed'; END IF;
END $test$;
ROLLBACK;
SELECT 'eSIM profile/event read-only permission checks passed' AS result;
