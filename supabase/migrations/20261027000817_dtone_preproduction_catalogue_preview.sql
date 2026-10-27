-- DT One read-only Pre-production catalogue. No runtime activation, shelf
-- publication, execution, hold, wallet, or credential mutation is performed.
BEGIN;
CREATE TABLE dtone_private.preview_catalogues (
  country_code text NOT NULL CHECK (country_code ~ '^[A-Z]{3}$'),
  carrier_code text NOT NULL CHECK (carrier_code ~ '^[0-9]+$'),
  environment text NOT NULL DEFAULT 'preproduction' CHECK (environment='preproduction'),
  credential_version integer NOT NULL CHECK (credential_version>0),
  activation_revision integer NOT NULL CHECK (activation_revision>=0),
  offers jsonb NOT NULL CHECK (jsonb_typeof(offers)='array'),
  refreshed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (country_code,carrier_code)
);
ALTER TABLE dtone_private.preview_catalogues ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON dtone_private.preview_catalogues FROM PUBLIC,anon,authenticated,service_role;

-- This resolver is intentionally separate from get_dtone_runtime_credentials.
-- Saved Pre-production can be browsed while no purchase environment is active.
CREATE FUNCTION public.get_dtone_catalog_credentials() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r dtone_private.runtime%ROWTYPE; c dtone_private.configs%ROWTYPE;
        v dtone_private.versions%ROWTYPE; pair jsonb;
BEGIN
  SELECT * INTO STRICT r FROM dtone_private.runtime WHERE id=true;
  IF r.environment='production' THEN
    RETURN public.get_dtone_runtime_credentials(NULL);
  END IF;
  SELECT * INTO c FROM dtone_private.configs WHERE environment='preproduction';
  SELECT * INTO v FROM dtone_private.versions WHERE environment=c.environment AND version=c.version;
  SELECT decrypted_secret::jsonb INTO pair FROM vault.decrypted_secrets WHERE id=v.secret_id;
  IF c.version IS NULL OR c.version<1 OR nullif(pair->>'api_key','') IS NULL
     OR nullif(pair->>'api_secret','') IS NULL THEN
    RAISE EXCEPTION 'DT One catalogue configuration unavailable' USING ERRCODE='DT503';
  END IF;
  RETURN jsonb_build_object('environment','preproduction','version',c.version,
    'activation_revision',r.revision,'api_key',pair->>'api_key','api_secret',pair->>'api_secret',
    'callback_configured',false,'account','[]'::jsonb,'catalogue_only',true);
END$$;

CREATE FUNCTION public.service_sync_dtone_preview_catalog(
  p_environment text,p_version integer,p_activation_revision integer,
  p_country_code text,p_carrier_code text,p_rows jsonb) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r dtone_private.runtime%ROWTYPE; c dtone_private.configs%ROWTYPE; cleaned jsonb;
BEGIN
  -- Same lock used by credential save/activation: a response in flight cannot
  -- overwrite a newer configuration, even when the product IDs overlap.
  PERFORM pg_advisory_xact_lock(7381202601);
  SELECT * INTO STRICT r FROM dtone_private.runtime WHERE id=true FOR SHARE;
  SELECT * INTO c FROM dtone_private.configs WHERE environment='preproduction';
  IF r.environment='production' OR p_environment IS DISTINCT FROM 'preproduction'
     OR p_version IS DISTINCT FROM c.version OR p_version IS NULL OR p_version<1
     OR p_activation_revision IS DISTINCT FROM r.revision THEN RETURN false; END IF;
  IF p_country_code IS NULL OR p_country_code!~'^[A-Z]{3}$'
     OR p_carrier_code IS NULL OR p_carrier_code!~'^[0-9]+$'
     OR p_rows IS NULL OR jsonb_typeof(p_rows)<>'array' THEN
    RAISE EXCEPTION 'Invalid DT One preview catalogue' USING ERRCODE='DT400';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.carrier_provider_map m
    JOIN public.carriers carrier ON carrier.id=m.carrier_id
    JOIN public.supplier_policy policy ON policy.provider=m.provider
    WHERE m.provider='dtone' AND m.is_enabled AND carrier.is_supported
      AND policy.is_globally_enabled AND m.provider_country_code=p_country_code
      AND m.provider_carrier_code=p_carrier_code) THEN RETURN false; END IF;
  IF jsonb_array_length(p_rows)>5000 OR octet_length(p_rows::text)>10000000
    OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_rows) x WHERE
      jsonb_typeof(x)<>'object' OR x->>'api_provider' IS DISTINCT FROM 'dtone'
      OR x->>'country_code' IS DISTINCT FROM p_country_code
      OR x->>'carrier_code' IS DISTINCT FROM p_carrier_code
      OR coalesce(x->>'offer_id','')!~'^[0-9]{1,20}$')
    OR (SELECT count(*)<>count(DISTINCT x->>'offer_id') FROM jsonb_array_elements(p_rows) x) THEN
    RAISE EXCEPTION 'Invalid DT One preview catalogue' USING ERRCODE='DT400';
  END IF;
  -- The typed record removes unknown fields; the allowlist excludes all raw
  -- supplier response bodies and overrides. Provenance is server generated.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'offer_id',x.offer_id,'offer_name',x.offer_name,'price_type',x.price_type,
    'price_fixed_usd',x.price_fixed_usd,'price_min_usd',x.price_min_usd,'price_max_usd',x.price_max_usd,
    'send_min',x.send_min,'send_max',x.send_max,'send_currency',x.send_currency,
    'send_currency_divisor',x.send_currency_divisor,'source_currency',x.source_currency,
    'source_amount_native',x.source_amount_native,'fx_usd_to_local',x.fx_usd_to_local,
    'delivery_type',x.delivery_type,'service_type',x.service_type,'benefit_summary',x.benefit_summary,
    'data_mb',x.data_mb,'duration_days',x.duration_days)), '[]'::jsonb) INTO cleaned
  FROM jsonb_populate_recordset(NULL::public.provider_offers_cache,p_rows) x;
  INSERT INTO dtone_private.preview_catalogues(country_code,carrier_code,credential_version,
    activation_revision,offers,refreshed_at)
  VALUES(p_country_code,p_carrier_code,p_version,p_activation_revision,cleaned,clock_timestamp())
  ON CONFLICT(country_code,carrier_code) DO UPDATE SET
    credential_version=excluded.credential_version,activation_revision=excluded.activation_revision,
    offers=excluded.offers,refreshed_at=excluded.refreshed_at;
  -- Empty successful results replace the snapshot; failed fetches never call here.
  RETURN true;
END$$;

CREATE FUNCTION public.admin_dtone_catalogue_offers(p_carrier_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
  PERFORM public.assert_admin();
  SELECT coalesce(jsonb_agg(o.payload ORDER BY o.environment,o.payload->>'offer_id'),'[]'::jsonb)
  INTO result FROM (
    SELECT 'preproduction'::text environment, item || jsonb_build_object(
      'environment','preproduction','simulation',true,'real_money_eligible',false,
      'credential_version',preview.credential_version,'activation_revision',preview.activation_revision,
      'refreshed_at',preview.refreshed_at,'is_stale',preview.refreshed_at<now()-interval '24 hours',
      'is_active',false) payload
    FROM dtone_private.preview_catalogues preview
    JOIN dtone_private.configs config ON config.environment='preproduction'
      AND config.version=preview.credential_version
    JOIN public.carrier_provider_map mapping ON mapping.provider='dtone'
      AND mapping.carrier_id=p_carrier_id AND mapping.is_enabled
      AND mapping.provider_country_code=preview.country_code
      AND mapping.provider_carrier_code=preview.carrier_code
    CROSS JOIN LATERAL jsonb_array_elements(preview.offers) item
    UNION ALL
    SELECT 'production',jsonb_build_object(
      'offer_id',offer.offer_code,'offer_name',offer.effective_name,
      'price_type',offer.source_price_type,'price_fixed_usd',offer.effective_price_usd,
      'price_min_usd',offer.source_price_min_usd,'price_max_usd',offer.source_price_max_usd,
      'send_min',offer.source_send_min,'send_max',offer.source_send_max,
      'send_currency',offer.source_send_currency,'send_currency_divisor',offer.source_send_divisor,
      'delivery_type',offer.delivery_type,'service_type',offer.offer_kind,
      'environment','production','simulation',false,'real_money_eligible',true,
      'credential_version',r.version,'activation_revision',r.revision,
      'refreshed_at',offer.source_refreshed_at,'is_stale',false,'is_active',true)
    FROM public.provider_offers offer
    JOIN dtone_private.runtime r ON r.id=true AND r.environment='production' AND r.release_verified
    WHERE offer.provider_code='dtone' AND offer.carrier_id=p_carrier_id
      AND offer.is_active AND offer.source_is_active
      AND offer.dtone_provenance->>'environment'='production'
      AND offer.dtone_provenance->>'simulation'='false'
      AND offer.dtone_provenance->>'version'=r.version::text
      AND offer.dtone_provenance->>'activation_revision'=r.revision::text
      AND offer.source_refreshed_at>now()-interval '24 hours'
  ) o;
  RETURN result;
END$$;
REVOKE ALL ON FUNCTION public.get_dtone_catalog_credentials() FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.service_sync_dtone_preview_catalog(text,integer,integer,text,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.admin_dtone_catalogue_offers(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_dtone_catalog_credentials() TO service_role;
GRANT EXECUTE ON FUNCTION public.service_sync_dtone_preview_catalog(text,integer,integer,text,text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_dtone_catalogue_offers(uuid) TO authenticated;
COMMENT ON TABLE dtone_private.preview_catalogues IS 'Read-only DT One Pre-production previews; never a source for paid refills or delivery proof.';
NOTIFY pgrst,'reload schema';
COMMIT;
