-- Independent read-only shelves for saved DT One and Reloadly environments.
BEGIN;

CREATE VIEW carrier_availability_private.airtime_catalogue_credentials AS
SELECT 'dtone'::text provider,c.environment,c.version,v.secret_id,v.validated_at
FROM dtone_private.configs c
JOIN dtone_private.versions v ON v.environment=c.environment AND v.version=c.version
JOIN vault.secrets s ON s.id=v.secret_id
WHERE v.validated_at IS NOT NULL
UNION ALL
SELECT 'reloadly',c.environment,c.version,c.vault_secret_id,c.validated_at
FROM reloadly_private.reloadly_credentials c
JOIN vault.secrets s ON s.id=c.vault_secret_id
WHERE c.version>0 AND c.validated_at IS NOT NULL;

CREATE TABLE carrier_availability_private.airtime_catalogue_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  carrier_id uuid NOT NULL REFERENCES public.carriers(id) ON DELETE CASCADE,
  provider text NOT NULL,
  environment text NOT NULL,
  country_code text NOT NULL,
  operator_code text NOT NULL,
  credential_version integer NOT NULL CHECK (credential_version>0),
  requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  finished_at timestamptz,
  state text NOT NULL DEFAULT 'queued' CHECK (state IN ('queued','running','ready','failed')),
  lease uuid,
  lease_until timestamptz,
  CHECK ((provider='dtone' AND environment IN ('production','preproduction'))
    OR (provider='reloadly' AND environment IN ('live','sandbox')))
);
CREATE UNIQUE INDEX airtime_catalogue_one_pending
  ON carrier_availability_private.airtime_catalogue_jobs(carrier_id,provider,environment)
  WHERE state IN ('queued','running');
CREATE INDEX airtime_catalogue_job_history
  ON carrier_availability_private.airtime_catalogue_jobs(carrier_id,provider,environment,requested_at DESC);

CREATE TABLE carrier_availability_private.airtime_catalogue_snapshots (
  carrier_id uuid NOT NULL REFERENCES public.carriers(id) ON DELETE CASCADE,
  provider text NOT NULL,
  environment text NOT NULL,
  country_code text NOT NULL,
  operator_code text NOT NULL,
  credential_version integer NOT NULL CHECK (credential_version>0),
  refreshed_at timestamptz NOT NULL,
  offers jsonb NOT NULL CHECK (jsonb_typeof(offers)='array'),
  PRIMARY KEY (carrier_id,provider,environment),
  CHECK ((provider='dtone' AND environment IN ('production','preproduction'))
    OR (provider='reloadly' AND environment IN ('live','sandbox')))
);

ALTER TABLE carrier_availability_private.airtime_catalogue_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE carrier_availability_private.airtime_catalogue_snapshots ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON carrier_availability_private.airtime_catalogue_credentials,
  carrier_availability_private.airtime_catalogue_jobs,
  carrier_availability_private.airtime_catalogue_snapshots
FROM PUBLIC,anon,authenticated,service_role;

-- Only the legacy DT One preview has explicit environment and version
-- provenance. Preserve it while the new worker refreshes both shelves.
INSERT INTO carrier_availability_private.airtime_catalogue_snapshots
  (carrier_id,provider,environment,country_code,operator_code,credential_version,refreshed_at,offers)
SELECT m.carrier_id,'dtone','preproduction',p.country_code,p.carrier_code,
  p.credential_version,p.refreshed_at,p.offers
FROM dtone_private.preview_catalogues p
JOIN carrier_availability_private.airtime_catalogue_credentials c ON c.provider='dtone'
  AND c.environment='preproduction' AND c.version=p.credential_version
JOIN public.carrier_provider_map m ON m.provider='dtone'
  AND m.provider_country_code=p.country_code AND m.provider_carrier_code=p.carrier_code;

CREATE FUNCTION public.admin_airtime_catalogues(p_carrier_id uuid)
RETURNS TABLE(provider text,environment text,state text,credential_version integer,
  refreshed_at timestamptz,offer_count integer,offers jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
  SELECT m.provider,env.name,CASE
      WHEN credentials.version IS NULL THEN 'missing_credentials'
      WHEN NOT r.is_routable THEN 'paused'
      WHEN job.state IN ('queued','running') THEN 'refreshing'
      WHEN job.state='failed' THEN 'failed'
      WHEN shelf.refreshed_at IS NULL THEN 'not_fetched'
      WHEN shelf.credential_version<>credentials.version OR shelf.refreshed_at<=now()-interval '24 hours' THEN 'stale'
      WHEN jsonb_array_length(shelf.offers)=0 THEN 'empty'
      ELSE 'ready' END,
    credentials.version,shelf.refreshed_at,jsonb_array_length(shelf.offers),
    coalesce(shelf.offers,'[]'::jsonb)
  FROM public.carrier_provider_map m
  JOIN public.carrier_supplier_routing r ON r.carrier_id=m.carrier_id AND r.provider_code=m.provider
  CROSS JOIN LATERAL unnest(CASE m.provider WHEN 'dtone' THEN ARRAY['production','preproduction']
    ELSE ARRAY['live','sandbox'] END) env(name)
  LEFT JOIN carrier_availability_private.airtime_catalogue_credentials credentials
    ON credentials.provider=m.provider AND credentials.environment=env.name
  LEFT JOIN carrier_availability_private.airtime_catalogue_snapshots shelf
    ON shelf.carrier_id=m.carrier_id AND shelf.provider=m.provider AND shelf.environment=env.name
    AND shelf.country_code=m.provider_country_code AND shelf.operator_code=m.provider_carrier_code
  LEFT JOIN LATERAL (
    SELECT j.state FROM carrier_availability_private.airtime_catalogue_jobs j
    WHERE j.carrier_id=m.carrier_id AND j.provider=m.provider AND j.environment=env.name
      AND j.credential_version=credentials.version AND j.country_code=m.provider_country_code
      AND j.operator_code=m.provider_carrier_code
    ORDER BY j.requested_at DESC,j.id DESC LIMIT 1
  ) job ON true
  WHERE m.carrier_id=p_carrier_id AND m.provider IN ('dtone','reloadly')
  ORDER BY m.provider,env.name;
END $$;

CREATE FUNCTION public.admin_request_airtime_catalogue(p_carrier_id uuid,p_provider text,p_environment text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.assert_admin();
  IF NOT EXISTS (
    SELECT 1 FROM public.carrier_supplier_routing r
    JOIN carrier_availability_private.airtime_catalogue_credentials c
      ON c.provider=r.provider_code AND c.environment=p_environment
    WHERE r.carrier_id=p_carrier_id AND r.provider_code=p_provider AND r.is_routable
  ) THEN RAISE EXCEPTION 'Enabled carrier and validated supplier credentials required' USING ERRCODE='22023'; END IF;
  INSERT INTO carrier_availability_private.airtime_catalogue_jobs
    (carrier_id,provider,environment,country_code,operator_code,credential_version)
  SELECT r.carrier_id,r.provider_code,c.environment,r.provider_country_code,r.provider_carrier_code,c.version
  FROM public.carrier_supplier_routing r
  JOIN carrier_availability_private.airtime_catalogue_credentials c
    ON c.provider=r.provider_code AND c.environment=p_environment
  WHERE r.carrier_id=p_carrier_id AND r.provider_code=p_provider AND r.is_routable
  ON CONFLICT DO NOTHING;
  RETURN true;
END $$;

CREATE FUNCTION public.service_claim_airtime_catalogue_job(p_enqueue_due boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE job carrier_availability_private.airtime_catalogue_jobs; pair jsonb;
BEGIN
  IF coalesce(auth.role(),'')<>'service_role' THEN RAISE EXCEPTION 'Service role required' USING ERRCODE='42501'; END IF;
  IF p_enqueue_due THEN
    INSERT INTO carrier_availability_private.airtime_catalogue_jobs
      (carrier_id,provider,environment,country_code,operator_code,credential_version)
    SELECT r.carrier_id,r.provider_code,c.environment,r.provider_country_code,r.provider_carrier_code,c.version
    FROM public.carrier_supplier_routing r
    JOIN carrier_availability_private.airtime_catalogue_credentials c ON c.provider=r.provider_code
    WHERE r.is_routable AND NOT EXISTS (
      SELECT 1 FROM carrier_availability_private.airtime_catalogue_jobs j
      WHERE j.carrier_id=r.carrier_id AND j.provider=r.provider_code AND j.environment=c.environment
        AND j.credential_version=c.version AND j.country_code=r.provider_country_code
        AND j.operator_code=r.provider_carrier_code AND j.requested_at>now()-interval '2 hours'
    )
    ON CONFLICT DO NOTHING;
    DELETE FROM carrier_availability_private.airtime_catalogue_jobs j
      WHERE j.finished_at<now()-interval '7 days';
  END IF;

  SELECT j.* INTO job FROM carrier_availability_private.airtime_catalogue_jobs j
    WHERE j.state='queued' OR (j.state='running' AND j.lease_until<clock_timestamp())
    ORDER BY j.requested_at,j.id FOR UPDATE SKIP LOCKED LIMIT 1;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT s.decrypted_secret::jsonb INTO pair
    FROM carrier_availability_private.airtime_catalogue_credentials c
    JOIN vault.decrypted_secrets s ON s.id=c.secret_id
    JOIN public.carrier_supplier_routing r ON r.carrier_id=job.carrier_id AND r.provider_code=job.provider
    WHERE c.provider=job.provider AND c.environment=job.environment AND c.version=job.credential_version
      AND r.is_routable AND r.provider_country_code=job.country_code AND r.provider_carrier_code=job.operator_code;
  IF pair IS NULL THEN
    UPDATE carrier_availability_private.airtime_catalogue_jobs SET state='failed',finished_at=clock_timestamp()
      WHERE id=job.id;
    RETURN NULL;
  END IF;
  UPDATE carrier_availability_private.airtime_catalogue_jobs
    SET state='running',lease=gen_random_uuid(),lease_until=clock_timestamp()+interval '2 minutes'
    WHERE id=job.id RETURNING * INTO job;
  RETURN jsonb_build_object('id',job.id,'lease',job.lease,'provider',job.provider,
    'environment',job.environment,'country_code',job.country_code,'operator_code',job.operator_code,
    'credential_version',job.credential_version,'credentials',pair);
END $$;

CREATE FUNCTION public.service_finish_airtime_catalogue_job(p_id uuid,p_lease uuid,p_offers jsonb)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE job carrier_availability_private.airtime_catalogue_jobs; clean jsonb;
BEGIN
  IF coalesce(auth.role(),'')<>'service_role' THEN RAISE EXCEPTION 'Service role required' USING ERRCODE='42501'; END IF;
  SELECT j.* INTO job FROM carrier_availability_private.airtime_catalogue_jobs j WHERE j.id=p_id FOR UPDATE;
  IF NOT FOUND OR job.state<>'running' OR p_lease IS NULL OR job.lease IS DISTINCT FROM p_lease
    OR job.lease_until<=clock_timestamp() THEN RETURN false; END IF;

  -- The provider's credential rotation and this publication share the row lock.
  IF job.provider='dtone' THEN
    PERFORM 1 FROM dtone_private.configs WHERE environment=job.environment AND version=job.credential_version FOR SHARE;
  ELSE
    PERFORM 1 FROM reloadly_private.reloadly_credentials WHERE environment=job.environment AND version=job.credential_version FOR SHARE;
  END IF;
  IF NOT FOUND OR NOT EXISTS (
    SELECT 1 FROM public.carrier_supplier_routing r
    WHERE r.carrier_id=job.carrier_id AND r.provider_code=job.provider AND r.is_routable
      AND r.provider_country_code=job.country_code AND r.provider_carrier_code=job.operator_code
  ) THEN p_offers:=NULL; END IF;

  IF p_offers IS NOT NULL THEN
    IF jsonb_typeof(p_offers)<>'array' OR octet_length(p_offers::text)>10000000 THEN
      RAISE EXCEPTION 'Invalid catalogue result' USING ERRCODE='22023';
    END IF;
    IF jsonb_array_length(p_offers)>5000 OR EXISTS (
      SELECT 1 FROM jsonb_array_elements(p_offers) AS item(row)
      WHERE jsonb_typeof(item.row)<>'object' OR coalesce(item.row->>'offer_id','') !~ '^[[:alnum:]_.:-]{1,120}$'
    ) OR (
      SELECT count(*)<>count(DISTINCT item.row->>'offer_id') FROM jsonb_array_elements(p_offers) AS item(row)
    ) THEN RAISE EXCEPTION 'Invalid catalogue identity' USING ERRCODE='22023'; END IF;

    SELECT coalesce(jsonb_agg(jsonb_build_object('offer_id',o.offer_id,'offer_name',o.offer_name,
      'price_type',o.price_type,'price_fixed_usd',o.price_fixed_usd,'price_min_usd',o.price_min_usd,
      'price_max_usd',o.price_max_usd,'send_min',o.send_min,'send_max',o.send_max,
      'send_currency',o.send_currency,'send_currency_divisor',o.send_currency_divisor,
      'delivery_type',o.delivery_type,'service_type',o.service_type) ORDER BY o.offer_id),'[]'::jsonb)
    INTO clean
    FROM jsonb_populate_recordset(NULL::public.provider_offers_cache,p_offers) o;
    INSERT INTO carrier_availability_private.airtime_catalogue_snapshots AS shelf
      (carrier_id,provider,environment,country_code,operator_code,credential_version,refreshed_at,offers)
    VALUES(job.carrier_id,job.provider,job.environment,job.country_code,job.operator_code,
      job.credential_version,clock_timestamp(),clean)
    ON CONFLICT (carrier_id,provider,environment) DO UPDATE SET country_code=excluded.country_code,
      operator_code=excluded.operator_code,credential_version=excluded.credential_version,
      refreshed_at=excluded.refreshed_at,offers=excluded.offers;
  END IF;
  UPDATE carrier_availability_private.airtime_catalogue_jobs
    SET state=CASE WHEN p_offers IS NULL THEN 'failed' ELSE 'ready' END,
      lease=NULL,lease_until=NULL,finished_at=clock_timestamp() WHERE id=job.id;
  RETURN true;
END $$;

REVOKE ALL ON FUNCTION public.admin_airtime_catalogues(uuid),
  public.admin_request_airtime_catalogue(uuid,text,text),public.service_claim_airtime_catalogue_job(boolean),
  public.service_finish_airtime_catalogue_job(uuid,uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.admin_airtime_catalogues(uuid),
  public.admin_request_airtime_catalogue(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.service_claim_airtime_catalogue_job(boolean),
  public.service_finish_airtime_catalogue_job(uuid,uuid,jsonb) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
