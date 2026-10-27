-- API sessions load safeupdate, which rejects UPDATE without a predicate.
-- Update only the singleton row already locked by the activation contract.
BEGIN;

CREATE OR REPLACE FUNCTION public.service_activate_reloadly_environment(
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
      revision=revision+1,updated_at=clock_timestamp()
      WHERE id=r.id;
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

NOTIFY pgrst,'reload schema';
COMMIT;
