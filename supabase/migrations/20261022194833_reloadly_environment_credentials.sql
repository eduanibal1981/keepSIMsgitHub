-- Reloadly's two credential pairs are encrypted and replaced atomically.
-- No values are seeded; runtime remains on the existing VM environment until
-- an administrator explicitly activates a validated Vault environment.
BEGIN;
CREATE SCHEMA reloadly_private;
REVOKE ALL ON SCHEMA reloadly_private FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE reloadly_private.reloadly_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  environment text NOT NULL UNIQUE CHECK (environment IN ('sandbox','live')),
  vault_secret_id uuid,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  validated_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE reloadly_private.reloadly_runtime (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  singleton boolean NOT NULL DEFAULT true UNIQUE CHECK (singleton),
  active_environment text REFERENCES reloadly_private.reloadly_credentials(environment),
  runtime_ready boolean NOT NULL DEFAULT false,
  revision integer NOT NULL DEFAULT 0 CHECK (revision >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE reloadly_private.reloadly_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE reloadly_private.reloadly_runtime ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA reloadly_private FROM PUBLIC, anon, authenticated, service_role;
INSERT INTO reloadly_private.reloadly_credentials(environment) VALUES ('sandbox'),('live');
INSERT INTO reloadly_private.reloadly_runtime(singleton) VALUES (true);

-- Only trusted server code may pass an actor. Check current trusted auth data
-- again at commit, rather than trusting a caller-supplied flag or user_metadata.
CREATE FUNCTION reloadly_private.reloadly_assert_actor(p_actor uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
  IF p_actor IS NULL OR NOT EXISTS (
    SELECT 1 FROM auth.users u WHERE u.id=p_actor AND u.deleted_at IS NULL
      AND (u.banned_until IS NULL OR u.banned_until <= now())
      AND u.raw_app_meta_data->>'is_power_user' = 'true'
      AND coalesce(u.raw_app_meta_data->>'is_suspended','false') <> 'true'
  ) THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='KS460'; END IF;
END;
$$;
REVOKE ALL ON FUNCTION reloadly_private.reloadly_assert_actor(uuid) FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION public.admin_reloadly_credentials_status()
RETURNS TABLE(environment text, configured boolean, version integer,
  validated_at timestamptz, updated_at timestamptz, is_active boolean,
  active_environment text, activation_revision integer, runtime_ready boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
  PERFORM public.assert_admin();
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Admin identity required' USING ERRCODE='KS460'; END IF;
  RETURN QUERY SELECT c.environment,
    EXISTS(SELECT 1 FROM vault.secrets s WHERE s.id=c.vault_secret_id),
    c.version,c.validated_at,c.updated_at,
    coalesce(c.environment=r.active_environment,false),r.active_environment,r.revision,r.runtime_ready
    FROM reloadly_private.reloadly_credentials c
    CROSS JOIN reloadly_private.reloadly_runtime r ORDER BY c.environment;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_reloadly_credentials_status() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_reloadly_credentials_status() TO authenticated;

CREATE FUNCTION public.service_store_reloadly_credentials(
  p_actor uuid,p_environment text,p_client_id text,p_client_secret text,p_expected_version integer
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE c reloadly_private.reloadly_credentials%ROWTYPE; v_id uuid; v_pair text;
BEGIN
  PERFORM reloadly_private.reloadly_assert_actor(p_actor);
  SELECT * INTO c FROM reloadly_private.reloadly_credentials WHERE environment=p_environment FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Invalid environment' USING ERRCODE='RL400'; END IF;
  IF p_expected_version IS NULL OR p_expected_version <> c.version THEN
    RAISE EXCEPTION 'Credential version changed' USING ERRCODE='RL409'; END IF;
  IF p_client_id IS NULL OR p_client_secret IS NULL
    OR length(p_client_id)=0 OR length(p_client_secret)=0
    OR octet_length(p_client_id)>4096 OR octet_length(p_client_secret)>4096
    OR p_client_id ~ '[[:space:]]' OR p_client_secret ~ '[[:space:]]' THEN
    RAISE EXCEPTION 'Invalid credentials' USING ERRCODE='RL400'; END IF;
  v_pair := jsonb_build_object('client_id',p_client_id,'client_secret',p_client_secret)::text;
  BEGIN
    -- Nameless secrets are addressed by private UUID, so the existing generic
    -- name-based admin Vault writer cannot bypass this versioned pair API.
    IF c.vault_secret_id IS NULL THEN
      SELECT vault.create_secret(v_pair,NULL,'Reloadly '||p_environment||' credential pair') INTO v_id;
    ELSE
      v_id := c.vault_secret_id;
      IF NOT EXISTS(SELECT 1 FROM vault.secrets WHERE id=v_id) THEN
        RAISE EXCEPTION 'Missing stored pair'; END IF;
      PERFORM vault.update_secret(v_id,v_pair,NULL,'Reloadly '||p_environment||' credential pair');
    END IF;
    UPDATE reloadly_private.reloadly_credentials SET vault_secret_id=v_id,
      version=version+1,validated_at=clock_timestamp(),updated_at=clock_timestamp()
      WHERE environment=p_environment;
    INSERT INTO public.admin_audit_log(actor_id,actor_email,action,target_type,target_id,after_value,note)
      SELECT p_actor,p.email,'reloadly.credentials_saved','provider_credentials',p_environment,
        jsonb_build_object('environment',p_environment,'version',c.version+1),
        'Authentication validated; environment unchanged'
      FROM public.profiles p WHERE p.id=p_actor;
    IF NOT FOUND THEN RAISE EXCEPTION 'Missing admin profile'; END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Credential storage failed' USING ERRCODE='RL500';
  END;
END;
$$;
REVOKE ALL ON FUNCTION public.service_store_reloadly_credentials(uuid,text,text,text,integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.service_store_reloadly_credentials(uuid,text,text,text,integer) TO service_role;

-- This is the only read-back API. Both SDK callers and HTTP callers must use a
-- server service key. It is never granted to either Flutter application's role.
CREATE FUNCTION public.get_reloadly_runtime_credentials(p_environment text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE c reloadly_private.reloadly_credentials%ROWTYPE; r reloadly_private.reloadly_runtime%ROWTYPE; v_pair jsonb; v_env text;
BEGIN
  SELECT * INTO STRICT r FROM reloadly_private.reloadly_runtime FOR SHARE;
  v_env := coalesce(p_environment,r.active_environment);
  IF v_env IS NULL THEN RETURN NULL; END IF;
  SELECT * INTO c FROM reloadly_private.reloadly_credentials WHERE environment=v_env FOR SHARE;
  IF NOT FOUND OR c.vault_secret_id IS NULL THEN
    RAISE EXCEPTION 'Reloadly is not configured' USING ERRCODE='RL503'; END IF;
  BEGIN
    SELECT decrypted_secret::jsonb INTO STRICT v_pair FROM vault.decrypted_secrets WHERE id=c.vault_secret_id;
    IF coalesce(v_pair->>'client_id','')='' OR coalesce(v_pair->>'client_secret','')='' THEN
      RAISE EXCEPTION 'Invalid pair'; END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Reloadly credentials unavailable' USING ERRCODE='RL503';
  END;
  RETURN v_pair || jsonb_build_object('environment',v_env,'version',c.version,'activation_revision',r.revision);
END;
$$;
REVOKE ALL ON FUNCTION public.get_reloadly_runtime_credentials(text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_reloadly_runtime_credentials(text) TO service_role;

CREATE FUNCTION public.service_activate_reloadly_environment(
  p_actor uuid,p_environment text,p_expected_version integer,p_expected_activation_revision integer
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE c reloadly_private.reloadly_credentials%ROWTYPE; r reloadly_private.reloadly_runtime%ROWTYPE;
BEGIN
  PERFORM reloadly_private.reloadly_assert_actor(p_actor);
  SELECT * INTO STRICT r FROM reloadly_private.reloadly_runtime FOR UPDATE;
  IF NOT r.runtime_ready THEN
    RAISE EXCEPTION 'Worker release verification required' USING ERRCODE='RL503'; END IF;
  SELECT * INTO c FROM reloadly_private.reloadly_credentials WHERE environment=p_environment FOR UPDATE;
  IF NOT FOUND OR c.vault_secret_id IS NULL OR c.version<1 OR c.validated_at IS NULL THEN
    RAISE EXCEPTION 'Store a validated pair first' USING ERRCODE='RL400'; END IF;
  IF p_expected_version IS NULL OR p_expected_version<>c.version OR p_expected_activation_revision IS NULL
    OR p_expected_activation_revision<>r.revision THEN
    RAISE EXCEPTION 'Configuration changed' USING ERRCODE='RL409'; END IF;
  IF r.active_environment=p_environment THEN RETURN; END IF;
  -- Prevent a queue insertion or status update racing the environment check.
  -- The short lock lasts only for this database transaction, never OAuth I/O.
  SET LOCAL lock_timeout='3s';
  BEGIN
    LOCK TABLE public.topup_executions IN SHARE MODE;
  EXCEPTION WHEN lock_not_available THEN
    RAISE EXCEPTION 'Recharges are busy' USING ERRCODE='RL423';
  END;
  IF EXISTS(SELECT 1 FROM public.topup_executions
    WHERE (api_provider='reloadly' OR api_provider IS NULL)
      AND (status NOT IN ('success','failed','refunded','cancelled') OR carrier_in_flight IS TRUE)) THEN
    RAISE EXCEPTION 'Resolve pending recharges before switching' USING ERRCODE='RL423'; END IF;
  BEGIN
    -- Cache rows have no environment discriminator; clear them on a switch.
    DELETE FROM public.provider_offers_cache WHERE api_provider='reloadly';
    UPDATE reloadly_private.reloadly_runtime SET active_environment=p_environment,
      revision=revision+1,updated_at=clock_timestamp();
    INSERT INTO public.admin_audit_log(actor_id,actor_email,action,target_type,target_id,before_value,after_value,note)
      SELECT p_actor,p.email,'reloadly.environment_activated','provider_credentials',p_environment,
        jsonb_build_object('environment',r.active_environment,'activation_revision',r.revision),
        jsonb_build_object('environment',p_environment,'version',c.version,'activation_revision',r.revision+1),
        'Authentication revalidated; new recharges use selected environment'
      FROM public.profiles p WHERE p.id=p_actor;
    IF NOT FOUND THEN RAISE EXCEPTION 'Missing admin profile'; END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Activation failed' USING ERRCODE='RL500';
  END;
END;
$$;
REVOKE ALL ON FUNCTION public.service_activate_reloadly_environment(uuid,text,integer,integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.service_activate_reloadly_environment(uuid,text,integer,integer) TO service_role;

-- Only commit a catalogue if its credential snapshot still matches runtime.
-- The shared runtime lock makes validation/upsert/prune atomic with activation.
CREATE FUNCTION public.service_sync_reloadly_catalog(
  p_environment text,p_version integer,p_activation_revision integer,
  p_country_code text,p_carrier_code text,p_rows jsonb
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE r reloadly_private.reloadly_runtime%ROWTYPE; c reloadly_private.reloadly_credentials%ROWTYPE;
BEGIN
  SELECT * INTO STRICT r FROM reloadly_private.reloadly_runtime FOR SHARE;
  IF p_activation_revision IS NULL OR r.revision<>p_activation_revision THEN RETURN false; END IF;
  IF r.active_environment IS NOT NULL THEN
    SELECT * INTO c FROM reloadly_private.reloadly_credentials WHERE environment=r.active_environment FOR SHARE;
    IF p_environment IS DISTINCT FROM r.active_environment OR p_version IS DISTINCT FROM c.version THEN RETURN false; END IF;
  ELSIF p_version IS DISTINCT FROM 0 THEN RETURN false;
  END IF;
  IF p_environment IS NULL OR p_environment NOT IN ('sandbox','live')
    OR p_country_code IS NULL OR p_carrier_code IS NULL OR p_rows IS NULL
    OR jsonb_typeof(p_rows)<>'array' THEN RAISE EXCEPTION 'Invalid catalogue' USING ERRCODE='RL400'; END IF;
  IF jsonb_array_length(p_rows)>5000 OR EXISTS(
    SELECT 1 FROM jsonb_array_elements(p_rows) x WHERE
      x->>'api_provider' IS DISTINCT FROM 'reloadly' OR
      x->>'country_code' IS DISTINCT FROM p_country_code OR
      x->>'carrier_code' IS DISTINCT FROM p_carrier_code OR
      coalesce(x->>'offer_id','')=''
  ) THEN RAISE EXCEPTION 'Invalid catalogue' USING ERRCODE='RL400'; END IF;
  IF jsonb_array_length(p_rows)=0 THEN RETURN true; END IF;
  INSERT INTO public.provider_offers_cache(api_provider,offer_id,country_code,carrier_code,offer_name,price_type,price_fixed_usd,price_min_usd,price_max_usd,send_min,send_max,send_currency,send_currency_divisor,source_currency,source_amount_native,fx_usd_to_local,fx_rate_as_of,delivery_type,redeem_instructions,service_type,benefit_summary,data_mb,duration_days,refreshed_at)
    SELECT x.api_provider,x.offer_id,x.country_code,x.carrier_code,x.offer_name,x.price_type,x.price_fixed_usd,x.price_min_usd,x.price_max_usd,x.send_min,x.send_max,x.send_currency,x.send_currency_divisor,x.source_currency,x.source_amount_native,x.fx_usd_to_local,x.fx_rate_as_of,x.delivery_type,x.redeem_instructions,x.service_type,x.benefit_summary,x.data_mb,x.duration_days,x.refreshed_at
    FROM jsonb_populate_recordset(NULL::public.provider_offers_cache,p_rows) x
    ON CONFLICT(api_provider,offer_id) DO UPDATE SET country_code=excluded.country_code,
      carrier_code=excluded.carrier_code,
      offer_name=excluded.offer_name,
      price_type=excluded.price_type,
      price_fixed_usd=excluded.price_fixed_usd,
      price_min_usd=excluded.price_min_usd,
      price_max_usd=excluded.price_max_usd,
      send_min=excluded.send_min,
      send_max=excluded.send_max,
      send_currency=excluded.send_currency,
      send_currency_divisor=excluded.send_currency_divisor,
      source_currency=excluded.source_currency,
      source_amount_native=excluded.source_amount_native,
      fx_usd_to_local=excluded.fx_usd_to_local,
      fx_rate_as_of=excluded.fx_rate_as_of,
      delivery_type=excluded.delivery_type,
      redeem_instructions=excluded.redeem_instructions,
      service_type=excluded.service_type,
      benefit_summary=excluded.benefit_summary,
      data_mb=excluded.data_mb,
      duration_days=excluded.duration_days,
      refreshed_at=excluded.refreshed_at;
  DELETE FROM public.provider_offers_cache p WHERE p.api_provider='reloadly'
    AND p.country_code=p_country_code AND p.carrier_code=p_carrier_code
    AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_rows) x WHERE x->>'offer_id'=p.offer_id);
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.service_sync_reloadly_catalog(text,integer,integer,text,text,jsonb) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.service_sync_reloadly_catalog(text,integer,integer,text,text,jsonb) TO service_role;

NOTIFY pgrst,'reload schema';
COMMIT;
