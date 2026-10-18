-- Task 2: a write-only admin control plane. No credentials are seeded here.
-- Deploy selectively after review; this does not rotate/revoke provider keys or
-- update VM environments, webhook validators, other Edge functions, or Coturn.
BEGIN;

CREATE TABLE public.provider_credential_registry (
  credential_key text PRIMARY KEY,
  label text NOT NULL,
  provider text NOT NULL,
  consumers text[] NOT NULL,
  rotation_notes text NOT NULL,
  requires_external_sync boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_rotated_at timestamptz,
  verified_version integer NOT NULL DEFAULT 0 CHECK (verified_version >= 0 AND verified_version <= version),
  verified_at timestamptz,
  verified_by uuid
);
ALTER TABLE public.provider_credential_registry ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.provider_credential_registry FROM PUBLIC, anon, authenticated, service_role;

INSERT INTO public.provider_credential_registry
  (credential_key, label, provider, consumers, rotation_notes) VALUES
('PAYPAL_CLIENT_ID','Client ID','PayPal',ARRAY['create-paypal-order','capture-paypal-order','paypal-webhook','process-wallet-refund','personal MCP PayPal configuration'], 'Stored for coordinated rotation. Matching Edge consumers read Vault after their release. Synchronize personal PayPal tooling and any older deployed consumer; never store temporary access tokens here.'),
('PAYPAL_CLIENT_SECRET','Client secret','PayPal',ARRAY['create-paypal-order','capture-paypal-order','paypal-webhook','process-wallet-refund','personal MCP PayPal configuration'], 'Stored for coordinated rotation. Matching Edge consumers read Vault after their compatible release. Update older deployed refund processing/tooling and account for outstanding access tokens before recording completion.'),
('TELNYX_API_KEY','API key','Telnyx',ARRAY['liveness-verification','liveness-verification-webhook','validate-sim-liveness','send-sim-otp','verify-sim-otp','make-call','manage-caller-id','manage-dids','telnyx-cdr','admin-telnyx-billing'], 'All listed handlers use Vault after the matching release. Verify each consumer and the provider account before revoking the old key.'),
('TWILIO_ACCOUNT_SID','Account SID','Twilio',ARRAY['liveness-verification','liveness-verification-webhook','sms-webhook','twilio-voice-webhook','account-linked WhatsApp profiles if applicable'], 'Coordinate the SID and auth token; legacy direct-provider admin verification is disabled.'),
('TWILIO_AUTH_TOKEN','Auth token','Twilio',ARRAY['liveness-verification','liveness-verification-webhook','sms-webhook','twilio-voice-webhook','account-linked WhatsApp profiles if applicable'], 'Update every signature validator and Twilio consumer before revoking the previous token.'),
('ZENDIT_API_SECRET','API secret','Zendit',ARRAY['validate-sim-liveness','fetch_zendit_offers','sync-esim-catalogue','VM refill/catalogue workers'], 'Matching Edge consumers read Vault. VM workers still require an approved environment update/restart; resolve the legacy Zendit aliases before completion.'),
('DTONE_API_KEY','API key','DT One',ARRAY['validate-sim-liveness','VM refill/catalogue workers'], 'Coordinate with the API secret and update VM environments before revocation.'),
('DTONE_API_SECRET','API secret','DT One',ARRAY['validate-sim-liveness','VM refill/catalogue workers'], 'Coordinate with the API key and update VM environments before revocation.'),
('FIRSTY_CLIENT_ID','Sandbox client ID','Firsty',ARRAY['recovery-service (disabled by default)'], 'Sandbox only. Storing credentials does not enable recovery or authorize purchases.'),
('FIRSTY_CLIENT_SECRET','Sandbox client secret','Firsty',ARRAY['recovery-service (disabled by default)'], 'Sandbox only. Keep recovery disabled; do not enable a provider during rotation.'),
('TURN_SHARED_SECRET','Shared authentication secret','TURN',ARRAY['get-turn-credentials','initiate-voip-call','Coturn VM'], 'Coordinate the Coturn secret and Edge issuer. Existing short-lived credentials expire separately.'),
('TURN_USERNAME','Static relay username','TURN',ARRAY['get-turn-credentials','initiate-voip-call','external TURN service'], 'Only used when no shared secret is configured. Coordinate with the static relay credential.'),
('TURN_CREDENTIAL','Static relay credential','TURN',ARRAY['get-turn-credentials','initiate-voip-call','external TURN service'], 'Only used when no shared secret is configured. Explicit static credentials reach authenticated calling clients.');

CREATE FUNCTION public.admin_list_provider_credentials()
RETURNS TABLE (
  credential_key text, label text, provider text, configured boolean,
  version integer, updated_at timestamptz, last_rotated_at timestamptz,
  consumers text[], rotation_notes text, requires_external_sync boolean,
  rotation_status text, verified_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
    SELECT r.credential_key, r.label, r.provider,
      EXISTS (SELECT 1 FROM vault.secrets s WHERE s.name = r.credential_key),
      r.version, r.updated_at, r.last_rotated_at,
      r.consumers, r.rotation_notes,
      r.requires_external_sync AND (r.version = 0 OR r.verified_version <> r.version),
      CASE WHEN NOT EXISTS (SELECT 1 FROM vault.secrets s WHERE s.name = r.credential_key) THEN 'not_configured'
        WHEN r.version = 0 THEN 'untracked'
        WHEN r.verified_version = r.version THEN 'operator_confirmed'
        ELSE 'stored_pending_external_verification' END,
      CASE WHEN r.verified_version = r.version AND r.version > 0 THEN r.verified_at END
    FROM public.provider_credential_registry r
    ORDER BY r.provider, r.credential_key;
END;
$$;

CREATE FUNCTION public.admin_rotate_provider_credential(
  p_credential_key text, p_secret text, p_reason text, p_expected_version integer
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE
  v_row public.provider_credential_registry%ROWTYPE;
  v_now timestamptz := clock_timestamp();
  v_secret_id uuid;
BEGIN
  -- Authorize before revealing the key allowlist, versions or validation rules.
  PERFORM public.assert_admin();
  SELECT * INTO v_row FROM public.provider_credential_registry
    WHERE credential_key = p_credential_key FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unsupported credential' USING ERRCODE = 'KS701';
  END IF;
  IF p_expected_version IS NULL OR p_expected_version <> v_row.version THEN
    RAISE EXCEPTION 'Credential changed; reload before storing a replacement' USING ERRCODE = 'KS702';
  END IF;
  IF p_secret IS NULL OR length(btrim(p_secret)) < 1 OR octet_length(p_secret) > 16384
    OR p_secret <> btrim(p_secret) OR p_secret ~ E'[\\n\\r]'
    OR p_secret ~ '^<.*>$'
    OR p_secret ~* '^(changeme|replace[_ -]?me|your[_ -].*|placeholder)$' THEN
    RAISE EXCEPTION 'Invalid replacement credential' USING ERRCODE = 'KS703';
  END IF;
  IF p_credential_key = 'TURN_SHARED_SECRET' AND length(p_secret) < 32 THEN
    RAISE EXCEPTION 'Relay signing secrets require at least 32 characters' USING ERRCODE = 'KS703';
  END IF;
  IF p_reason IS NULL OR length(btrim(p_reason)) < 10 OR length(p_reason) > 500
    OR strpos(p_reason, p_secret) > 0 THEN
    RAISE EXCEPTION 'A change reference without credential values is required' USING ERRCODE = 'KS704';
  END IF;

  -- Write directly so the legacy generic helper cannot bypass version tracking.
  -- Discard raw errors: database/provider messages must not echo p_secret.
  BEGIN
    SELECT id INTO v_secret_id FROM vault.secrets WHERE name = p_credential_key;
    IF v_secret_id IS NULL THEN
      SELECT vault.create_secret(p_secret, p_credential_key, 'Admin credential replacement') INTO v_secret_id;
    ELSE
      PERFORM vault.update_secret(v_secret_id, p_secret, p_credential_key, 'Admin credential replacement');
    END IF;
    PERFORM public.admin_log('provider_credential.replacement', 'provider_credential',
      p_credential_key, NULL, jsonb_build_object('name', p_credential_key, 'version', v_row.version + 1),
      'Replacement stored; external verification pending');
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Credential storage failed' USING ERRCODE = 'KS705';
  END;

  UPDATE public.provider_credential_registry
    SET version = version + 1, updated_at = v_now, last_rotated_at = v_now
    WHERE credential_key = p_credential_key RETURNING * INTO v_row;

  -- Free-form reason is intentionally not persisted: it could contain another
  -- secret. The existing audit records the actor, key and time without values.
  RETURN jsonb_build_object(
    'credential_key', v_row.credential_key, 'configured', true,
    'version', v_row.version, 'updated_at', v_row.updated_at,
    'last_rotated_at', v_row.last_rotated_at, 'requires_external_sync', true,
    'rotation_status', 'stored_pending_external_verification'
  );
END;
$$;

-- An operator attestation, not a provider probe. Never accepts or returns a key.
-- The row lock/version check prevents confirming a different replacement.
CREATE FUNCTION public.admin_confirm_provider_credential_rotation(
  p_credential_key text, p_expected_version integer
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE
  v_row public.provider_credential_registry%ROWTYPE;
  v_actor uuid;
BEGIN
  v_actor := public.assert_admin();
  SELECT * INTO v_row FROM public.provider_credential_registry
    WHERE credential_key = p_credential_key FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unsupported credential' USING ERRCODE = 'KS701'; END IF;
  IF p_expected_version IS NULL OR p_expected_version <> v_row.version THEN
    RAISE EXCEPTION 'Credential changed; reload before confirming' USING ERRCODE = 'KS702';
  END IF;
  IF v_actor IS NULL OR v_row.version = 0 OR NOT EXISTS (
    SELECT 1 FROM vault.secrets WHERE name = p_credential_key
  ) THEN RAISE EXCEPTION 'A stored replacement and administrator identity are required' USING ERRCODE = 'KS707'; END IF;
  IF v_row.verified_version = v_row.version THEN RETURN; END IF;
  BEGIN
    UPDATE public.provider_credential_registry SET verified_version = version,
      verified_at = clock_timestamp(), verified_by = v_actor WHERE credential_key = p_credential_key;
    PERFORM public.admin_log('provider_credential.operator_confirmed', 'provider_credential',
      p_credential_key, NULL, jsonb_build_object('version', v_row.version),
      'Operator confirms consumer synchronization, recovery verification and old-key revocation');
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Credential record could not be updated' USING ERRCODE = 'KS705';
  END;
END;
$$;

-- Keep WhatsApp's existing generic secret writer compatible while preventing
-- supported API callers from bypassing managed credential versions.
CREATE OR REPLACE FUNCTION public.admin_set_vault_secret(
  p_name text, p_secret text, p_description text DEFAULT ''
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE
  v_secret_id uuid;
BEGIN
  PERFORM public.assert_admin();
  IF p_name IN ('zendit_api_key', 'ZENDIT_API_KEY', 'COTURN_SHARED_SECRET') OR EXISTS (
    SELECT 1 FROM public.provider_credential_registry WHERE credential_key = p_name
  ) THEN
    RAISE EXCEPTION 'Use the versioned provider credential replacement API' USING ERRCODE = 'KS706';
  END IF;
  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Secret name cannot be empty' USING ERRCODE = 'KS467';
  END IF;
  BEGIN
    SELECT id INTO v_secret_id FROM vault.secrets WHERE name = p_name;
    IF v_secret_id IS NULL THEN
      SELECT vault.create_secret(p_secret, p_name, p_description) INTO v_secret_id;
    ELSE
      PERFORM vault.update_secret(v_secret_id, p_secret, p_name, p_description);
    END IF;
    PERFORM public.admin_log('vault_secret.set', 'vault_secret', p_name, NULL,
      jsonb_build_object('name', p_name, 'id', v_secret_id), 'Secret stored or rotated');
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Credential storage failed' USING ERRCODE = 'KS705';
  END;
  RETURN v_secret_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_set_vault_secret(text,text,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_vault_secret(text,text,text) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_list_provider_credentials() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_rotate_provider_credential(text,text,text,integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_provider_credentials() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_rotate_provider_credential(text,text,text,integer) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_confirm_provider_credential_rotation(text,integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_confirm_provider_credential_rotation(text,integer) TO authenticated;
COMMENT ON FUNCTION public.admin_list_provider_credentials() IS 'Admin metadata only. configured indicates Vault name presence, not provider validity or environment presence.';
COMMENT ON FUNCTION public.admin_rotate_provider_credential(text,text,text,integer) IS 'Write-only admin Vault replacement. Does not revoke old keys or synchronize external environments. Never log request arguments.';
COMMIT;
