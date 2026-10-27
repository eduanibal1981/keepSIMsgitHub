-- Run in a transaction and roll back: all catalogue rows below are fixtures.
DO $$
DECLARE env jsonb; result jsonb; rows_before bigint; cache_before bigint;
        mapping public.carrier_provider_map%ROWTYPE; input jsonb; failed boolean;
BEGIN
  SELECT * INTO STRICT mapping FROM public.carrier_provider_map
    WHERE provider='dtone' AND provider_country_code='EGY' AND provider_carrier_code='716';
  SELECT count(*) INTO rows_before FROM public.provider_offers WHERE provider_code='dtone';
  SELECT count(*) INTO cache_before FROM public.provider_offers_cache WHERE api_provider='dtone';
  -- Retain only metadata; never output or store API credential values.
  env:=public.get_dtone_catalog_credentials()-'api_key'-'api_secret';
  ASSERT env->>'environment'='preproduction';
  ASSERT (env->>'version')::int=1;
  ASSERT NOT EXISTS(SELECT 1 FROM dtone_private.runtime WHERE environment IS NOT NULL);
  input:=jsonb_build_array(jsonb_build_object('api_provider','dtone','country_code','EGY',
    'carrier_code','716','offer_id','999716001','offer_name','FIXTURE ONLY',
    'price_type','FIXED','price_fixed_usd',1,'source_currency','USD',
    'send_min',50,'send_max',50,'send_currency','EGP','send_currency_divisor',1,
    'delivery_type','direct','provider_secret','MUST BE STRIPPED'));
  ASSERT public.service_sync_dtone_preview_catalog('preproduction',1,0,'EGY','716',input);
  ASSERT (SELECT count(*) FROM public.provider_offers WHERE provider_code='dtone')=rows_before;
  ASSERT (SELECT count(*) FROM public.provider_offers_cache WHERE api_provider='dtone')=cache_before;
  ASSERT NOT public.service_sync_dtone_catalog('preproduction',1,0,'EGY','716',input);
  ASSERT NOT public.service_sync_dtone_preview_catalog('production',1,0,'EGY','716',input);
  ASSERT NOT public.service_sync_dtone_preview_catalog('preproduction',2,0,'EGY','716',input);
  ASSERT NOT public.service_sync_dtone_preview_catalog('preproduction',1,1,'EGY','716',input);
  ASSERT NOT public.service_sync_dtone_preview_catalog('preproduction',1,0,'EGY','999999999','[]');
  PERFORM set_config('request.jwt.claims','{"role":"service_role"}',true);
  result:=public.admin_dtone_catalogue_offers(mapping.carrier_id);
  ASSERT jsonb_array_length(result)=1;
  ASSERT result->0->>'environment'='preproduction';
  ASSERT result->0->>'simulation'='true';
  ASSERT result->0->>'real_money_eligible'='false';
  ASSERT result->0->>'is_active'='false';
  ASSERT NOT (result->0 ? 'provider_secret');
  ASSERT (public.admin_dtone_preview_status()->>'offer_count')::int>=1;
  ASSERT public.admin_dtone_preview_status()->>'refreshed_at' IS NOT NULL;
  UPDATE dtone_private.preview_catalogues SET refreshed_at=now()-interval '2 days' WHERE country_code='EGY' AND carrier_code='716';
  ASSERT public.admin_dtone_catalogue_offers(mapping.carrier_id)->0->>'is_stale'='true';
  ASSERT public.admin_dtone_catalogue_offers('00000000-0000-4000-8000-000000000000')='[]'::jsonb;
  -- Neither an Admin override nor a raw-cache write can promote previews.
  failed:=false;
  BEGIN
    INSERT INTO public.provider_offers_cache(api_provider,offer_id,country_code,carrier_code,offer_name,price_type,price_fixed_usd,refreshed_at,dtone_provenance)
    VALUES('dtone','999716001','EGY','716','FIXTURE','FIXED',1,now(),
      '{"environment":"preproduction","version":1,"activation_revision":0,"simulation":true}');
  EXCEPTION WHEN SQLSTATE 'DT409' THEN failed:=true; END;
  ASSERT failed;
  failed:=false;
  BEGIN
    UPDATE public.provider_offers SET source_is_active=true
    WHERE id=(SELECT id FROM public.provider_offers WHERE provider_code='dtone' LIMIT 1);
  EXCEPTION WHEN SQLSTATE 'DT409' THEN failed:=true; END;
  ASSERT failed;
  failed:=false;
  BEGIN
    PERFORM public.service_sync_dtone_preview_catalog('preproduction',1,0,'EGY','716',NULL);
  EXCEPTION WHEN SQLSTATE 'DT400' THEN failed:=true; END;
  ASSERT failed;
  failed:=false;
  BEGIN
    PERFORM public.service_sync_dtone_preview_catalog('preproduction',1,0,'EGY','716',input||input);
  EXCEPTION WHEN SQLSTATE 'DT400' THEN failed:=true; END;
  ASSERT failed;
  ASSERT public.service_sync_dtone_preview_catalog('preproduction',1,0,'EGY','716','[]');
  ASSERT public.admin_dtone_catalogue_offers(mapping.carrier_id)='[]'::jsonb;
  -- ACLs and body authorization both enforce the boundary.
  ASSERT NOT has_function_privilege('anon','public.get_dtone_catalog_credentials()','EXECUTE');
  ASSERT NOT has_function_privilege('authenticated','public.get_dtone_catalog_credentials()','EXECUTE');
  ASSERT NOT has_function_privilege('authenticated','public.service_sync_dtone_preview_catalog(text,integer,integer,text,text,jsonb)','EXECUTE');
  ASSERT NOT has_function_privilege('anon','public.admin_dtone_catalogue_offers(uuid)','EXECUTE');
  ASSERT NOT has_function_privilege('anon','public.admin_dtone_preview_status()','EXECUTE');
  ASSERT has_function_privilege('authenticated','public.admin_dtone_catalogue_offers(uuid)','EXECUTE');
  ASSERT NOT has_table_privilege('authenticated','dtone_private.preview_catalogues','SELECT');
  ASSERT NOT has_table_privilege('service_role','dtone_private.preview_catalogues','INSERT');
  PERFORM set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-000000000000"}',true);
  failed:=false;
  BEGIN
    PERFORM public.admin_dtone_catalogue_offers(mapping.carrier_id);
  EXCEPTION WHEN SQLSTATE 'KS460' THEN failed:=true; END;
  ASSERT failed;
END$$;
SELECT 'PASS: preview loading, mapping, fencing, isolation, publish guards, empty refresh and authorization' AS result;
