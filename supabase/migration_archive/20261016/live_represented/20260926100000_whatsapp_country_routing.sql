-- KeepSIMs WhatsApp Country Routing & Provider Management
-- Migration: 20260926100000_whatsapp_country_routing.sql

-- 1. whatsapp_provider_profiles table
CREATE TABLE IF NOT EXISTS public.whatsapp_provider_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_kind TEXT NOT NULL CHECK (provider_kind IN ('baileys', 'meta_cloud')),
  label TEXT NOT NULL,
  expected_sender_number TEXT,
  observed_sender_number TEXT,
  is_enabled BOOLEAN NOT NULL DEFAULT true,
  ready_state TEXT NOT NULL DEFAULT 'unconfigured' CHECK (ready_state IN ('ready', 'degraded', 'unconfigured', 'error')),
  version INTEGER NOT NULL DEFAULT 1,
  last_probe_at TIMESTAMPTZ,
  last_error_category TEXT,
  last_error_detail TEXT,
  connection_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_provider_profiles_kind ON public.whatsapp_provider_profiles(provider_kind);
CREATE INDEX IF NOT EXISTS idx_whatsapp_provider_profiles_ready ON public.whatsapp_provider_profiles(ready_state);

ALTER TABLE public.whatsapp_provider_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow power users and service role full access on whatsapp_provider_profiles"
  ON public.whatsapp_provider_profiles
  FOR ALL
  USING (
    (current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role')
    OR public.is_power_user(auth.uid())
  )
  WITH CHECK (
    (current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role')
    OR public.is_power_user(auth.uid())
  );

-- 2. whatsapp_country_routes table
CREATE TABLE IF NOT EXISTS public.whatsapp_country_routes (
  country_id UUID PRIMARY KEY REFERENCES public.countries(id) ON DELETE CASCADE,
  route_mode TEXT NOT NULL DEFAULT 'disabled' CHECK (route_mode IN ('disabled', 'baileys', 'meta_cloud')),
  profile_id UUID REFERENCES public.whatsapp_provider_profiles(id) ON DELETE SET NULL,
  version INTEGER NOT NULL DEFAULT 1,
  last_health_check_at TIMESTAMPTZ,
  health_status TEXT NOT NULL DEFAULT 'disabled' CHECK (health_status IN ('healthy', 'degraded', 'unavailable', 'disabled', 'unconfigured')),
  health_reason TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES auth.users(id),
  CONSTRAINT chk_route_profile_required CHECK (
    (route_mode = 'disabled') OR (route_mode IN ('baileys', 'meta_cloud') AND profile_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_country_routes_profile ON public.whatsapp_country_routes(profile_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_country_routes_mode ON public.whatsapp_country_routes(route_mode);

ALTER TABLE public.whatsapp_country_routes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow power users and service role full access on whatsapp_country_routes"
  ON public.whatsapp_country_routes
  FOR ALL
  USING (
    (current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role')
    OR public.is_power_user(auth.uid())
  )
  WITH CHECK (
    (current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role')
    OR public.is_power_user(auth.uid())
  );

-- 3. whatsapp_message_attempts table (durable outbox and delivery tracking)
CREATE TABLE IF NOT EXISTS public.whatsapp_message_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purpose TEXT NOT NULL CHECK (purpose IN ('subscription_alert', 'offline_refill_reply', 'admin_test')),
  notification_id UUID REFERENCES public.notifications(id) ON DELETE SET NULL,
  command_id TEXT,
  recipient_phone TEXT NOT NULL,
  recipient_country_id UUID REFERENCES public.countries(id) ON DELETE SET NULL,
  sim_line_id UUID REFERENCES public.sim_lines(id) ON DELETE SET NULL,
  sim_country_id UUID REFERENCES public.countries(id) ON DELETE SET NULL,
  route_mode TEXT NOT NULL,
  profile_id UUID REFERENCES public.whatsapp_provider_profiles(id) ON DELETE SET NULL,
  profile_version INTEGER NOT NULL DEFAULT 1,
  sender_number TEXT,
  idempotency_key TEXT UNIQUE NOT NULL,
  template_name TEXT,
  template_language TEXT,
  attempt_count INTEGER NOT NULL DEFAULT 1,
  state TEXT NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'accepted', 'sent', 'delivered', 'failed', 'unknown', 'skipped')),
  provider_message_id TEXT,
  error_category TEXT,
  error_detail TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  delivered_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_attempts_created ON public.whatsapp_message_attempts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_whatsapp_attempts_purpose ON public.whatsapp_message_attempts(purpose);
CREATE INDEX IF NOT EXISTS idx_whatsapp_attempts_state ON public.whatsapp_message_attempts(state);
CREATE INDEX IF NOT EXISTS idx_whatsapp_attempts_country ON public.whatsapp_message_attempts(recipient_country_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_attempts_provider_msg ON public.whatsapp_message_attempts(provider_message_id) WHERE provider_message_id IS NOT NULL;

ALTER TABLE public.whatsapp_message_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow power users and service role full access on whatsapp_message_attempts"
  ON public.whatsapp_message_attempts
  FOR ALL
  USING (
    (current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role')
    OR public.is_power_user(auth.uid())
  )
  WITH CHECK (
    (current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role')
    OR public.is_power_user(auth.uid())
  );

-- 4. Longest-Prefix Recipient Country Resolver
CREATE OR REPLACE FUNCTION public.resolve_country_by_phone(p_phone text)
RETURNS uuid
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $$
  SELECT id
  FROM public.countries
  WHERE regexp_replace(p_phone, '^(\+|00)', '') LIKE (replace(dialing_code, '+', '') || '%')
  ORDER BY length(replace(dialing_code, '+', '')) DESC
  LIMIT 1;
$$;

-- 5. Vault Secret Management Helper for Admin
CREATE OR REPLACE FUNCTION public.admin_set_vault_secret(
  p_name text,
  p_secret text,
  p_description text DEFAULT ''
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_secret_id uuid;
  v_existing_id uuid;
BEGIN
  PERFORM public.assert_admin();

  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Secret name cannot be empty' USING ERRCODE = 'KS467';
  END IF;

  SELECT id INTO v_existing_id FROM vault.secrets WHERE name = p_name;
  IF v_existing_id IS NOT NULL THEN
    PERFORM vault.update_secret(v_existing_id, p_secret, p_name, p_description);
    v_secret_id := v_existing_id;
  ELSE
    SELECT vault.create_secret(p_secret, p_name, p_description) INTO v_secret_id;
  END IF;

  PERFORM public.admin_log('vault_secret.set', 'vault_secret', p_name, NULL, jsonb_build_object('name', p_name, 'id', v_secret_id), 'Secret stored or rotated');

  RETURN v_secret_id;
END;
$$;

-- 6. Admin RPC: List WhatsApp Profiles
CREATE OR REPLACE FUNCTION public.admin_list_whatsapp_profiles()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_res jsonb;
BEGIN
  PERFORM public.assert_admin();

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'provider_kind', p.provider_kind,
      'label', p.label,
      'expected_sender_number', p.expected_sender_number,
      'observed_sender_number', p.observed_sender_number,
      'is_enabled', p.is_enabled,
      'ready_state', p.ready_state,
      'version', p.version,
      'last_probe_at', p.last_probe_at,
      'last_error_category', p.last_error_category,
      'last_error_detail', p.last_error_detail,
      'connection_metadata', p.connection_metadata - 'access_token' - 'app_secret' - 'api_key',
      'has_access_token', ((p.connection_metadata ? 'access_token_vault_id') OR (p.connection_metadata ? 'access_token_masked')),
      'has_app_secret', (p.connection_metadata ? 'app_secret_vault_id'),
      'has_verify_token', (p.connection_metadata ? 'webhook_verify_token_vault_id'),
      'has_api_key', (p.connection_metadata ? 'auth_secret_vault_id'),
      'created_at', p.created_at,
      'updated_at', p.updated_at
    ) ORDER BY p.provider_kind, p.label
  ), '[]'::jsonb) INTO v_res
  FROM public.whatsapp_provider_profiles p;

  RETURN jsonb_build_object('success', true, 'items', v_res);
END;
$$;

-- 7. Admin RPC: Save WhatsApp Profile
CREATE OR REPLACE FUNCTION public.admin_save_whatsapp_profile(
  p_id uuid,
  p_provider_kind text,
  p_label text,
  p_expected_sender text,
  p_is_enabled boolean,
  p_metadata jsonb,
  p_secrets jsonb DEFAULT '{}'::jsonb,
  p_expected_version int DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_uid uuid;
  v_profile_id uuid := p_id;
  v_before jsonb;
  v_after jsonb;
  v_cur_version int;
  v_meta jsonb := COALESCE(p_metadata, '{}'::jsonb);
  v_secret_val text;
  v_sec_id uuid;
  v_clean_kind text := lower(btrim(p_provider_kind));
  v_ready text := 'unconfigured';
BEGIN
  v_uid := public.assert_admin();

  IF v_clean_kind NOT IN ('baileys', 'meta_cloud') THEN
    RAISE EXCEPTION 'Invalid provider_kind: %', p_provider_kind USING ERRCODE = 'KS467';
  END IF;

  IF p_label IS NULL OR btrim(p_label) = '' THEN
    RAISE EXCEPTION 'Profile label is required' USING ERRCODE = 'KS467';
  END IF;

  IF v_profile_id IS NULL THEN
    v_profile_id := gen_random_uuid();
  END IF;

  -- Handle secret storage in Vault
  IF p_secrets ? 'access_token' AND NULLIF(btrim(p_secrets ->> 'access_token'), '') IS NOT NULL THEN
    v_secret_val := btrim(p_secrets ->> 'access_token');
    v_sec_id := public.admin_set_vault_secret('wa_meta_token_' || v_profile_id, v_secret_val, 'Meta Cloud API access token');
    v_meta := jsonb_set(v_meta, '{access_token_vault_id}', to_jsonb(v_sec_id::text));
    v_meta := jsonb_set(v_meta, '{access_token_masked}', to_jsonb('...' || right(v_secret_val, 4)));
  END IF;

  IF p_secrets ? 'app_secret' AND NULLIF(btrim(p_secrets ->> 'app_secret'), '') IS NOT NULL THEN
    v_secret_val := btrim(p_secrets ->> 'app_secret');
    v_sec_id := public.admin_set_vault_secret('wa_meta_app_secret_' || v_profile_id, v_secret_val, 'Meta Cloud API app secret');
    v_meta := jsonb_set(v_meta, '{app_secret_vault_id}', to_jsonb(v_sec_id::text));
  END IF;

  IF p_secrets ? 'webhook_verify_token' AND NULLIF(btrim(p_secrets ->> 'webhook_verify_token'), '') IS NOT NULL THEN
    v_secret_val := btrim(p_secrets ->> 'webhook_verify_token');
    v_sec_id := public.admin_set_vault_secret('wa_meta_verify_' || v_profile_id, v_secret_val, 'Meta Cloud webhook verify token');
    v_meta := jsonb_set(v_meta, '{webhook_verify_token_vault_id}', to_jsonb(v_sec_id::text));
  END IF;

  IF p_secrets ? 'api_key' AND NULLIF(btrim(p_secrets ->> 'api_key'), '') IS NOT NULL THEN
    v_secret_val := btrim(p_secrets ->> 'api_key');
    v_sec_id := public.admin_set_vault_secret('wa_baileys_key_' || v_profile_id, v_secret_val, 'Baileys worker API key');
    v_meta := jsonb_set(v_meta, '{auth_secret_vault_id}', to_jsonb(v_sec_id::text));
  END IF;

  -- Check existing profile
  SELECT to_jsonb(p), p.version INTO v_before, v_cur_version
  FROM public.whatsapp_provider_profiles p WHERE p.id = v_profile_id;

  IF v_before IS NOT NULL THEN
    IF p_expected_version IS NOT NULL AND v_cur_version <> p_expected_version THEN
      RAISE EXCEPTION 'Stale profile version conflict (expected %, current %)', p_expected_version, v_cur_version USING ERRCODE = 'KS409';
    END IF;

    -- preserve existing vault secret references if not replaced
    IF (v_before -> 'connection_metadata' ? 'access_token_vault_id') AND NOT (v_meta ? 'access_token_vault_id') THEN
      v_meta := jsonb_set(v_meta, '{access_token_vault_id}', v_before -> 'connection_metadata' -> 'access_token_vault_id');
      v_meta := jsonb_set(v_meta, '{access_token_masked}', v_before -> 'connection_metadata' -> 'access_token_masked');
    END IF;
    IF (v_before -> 'connection_metadata' ? 'app_secret_vault_id') AND NOT (v_meta ? 'app_secret_vault_id') THEN
      v_meta := jsonb_set(v_meta, '{app_secret_vault_id}', v_before -> 'connection_metadata' -> 'app_secret_vault_id');
    END IF;
    IF (v_before -> 'connection_metadata' ? 'webhook_verify_token_vault_id') AND NOT (v_meta ? 'webhook_verify_token_vault_id') THEN
      v_meta := jsonb_set(v_meta, '{webhook_verify_token_vault_id}', v_before -> 'connection_metadata' -> 'webhook_verify_token_vault_id');
    END IF;
    IF (v_before -> 'connection_metadata' ? 'auth_secret_vault_id') AND NOT (v_meta ? 'auth_secret_vault_id') THEN
      v_meta := jsonb_set(v_meta, '{auth_secret_vault_id}', v_before -> 'connection_metadata' -> 'auth_secret_vault_id');
    END IF;

    UPDATE public.whatsapp_provider_profiles SET
      label = btrim(p_label),
      expected_sender_number = NULLIF(btrim(p_expected_sender), ''),
      is_enabled = COALESCE(p_is_enabled, is_enabled),
      connection_metadata = v_meta,
      version = version + 1,
      updated_at = now(),
      updated_by = v_uid
    WHERE id = v_profile_id;
  ELSE
    INSERT INTO public.whatsapp_provider_profiles (
      id,
      provider_kind,
      label,
      expected_sender_number,
      is_enabled,
      ready_state,
      version,
      connection_metadata,
      created_by,
      updated_by
    ) VALUES (
      v_profile_id,
      v_clean_kind,
      btrim(p_label),
      NULLIF(btrim(p_expected_sender), ''),
      COALESCE(p_is_enabled, true),
      'unconfigured',
      1,
      v_meta,
      v_uid,
      v_uid
    );
  END IF;

  SELECT to_jsonb(p) INTO v_after
  FROM public.whatsapp_provider_profiles p WHERE p.id = v_profile_id;

  PERFORM public.admin_log(
    CASE WHEN v_before IS NULL THEN 'whatsapp_profile.create' ELSE 'whatsapp_profile.update' END,
    'whatsapp_profile',
    v_profile_id::text,
    v_before,
    v_after - 'connection_metadata',
    'Saved WhatsApp provider profile: ' || p_label
  );

  RETURN jsonb_build_object('success', true, 'profile_id', v_profile_id, 'version', (v_after ->> 'version')::int);
END;
$$;

-- 8. Admin RPC: Delete WhatsApp Profile
CREATE OR REPLACE FUNCTION public.admin_delete_whatsapp_profile(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_before jsonb;
  v_used_count int;
BEGIN
  PERFORM public.assert_admin();

  SELECT to_jsonb(p) INTO v_before
  FROM public.whatsapp_provider_profiles p WHERE p.id = p_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'KS461';
  END IF;

  SELECT count(*) INTO v_used_count
  FROM public.whatsapp_country_routes
  WHERE profile_id = p_id AND route_mode <> 'disabled';

  IF v_used_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete profile: % active country route(s) are assigned to it. Reassign or disable them first.', v_used_count USING ERRCODE = 'KS467';
  END IF;

  DELETE FROM public.whatsapp_provider_profiles WHERE id = p_id;

  PERFORM public.admin_log('whatsapp_profile.delete', 'whatsapp_profile', p_id::text, v_before, NULL, 'Deleted WhatsApp provider profile');

  RETURN jsonb_build_object('success', true, 'deleted_id', p_id);
END;
$$;

-- 9. Admin RPC: List WhatsApp Country Routes
CREATE OR REPLACE FUNCTION public.admin_list_whatsapp_routes()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_res jsonb;
BEGIN
  PERFORM public.assert_admin();

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'country_id', c.id,
      'country_name', c.name,
      'iso_code', c.iso_code,
      'dialing_code', c.dialing_code,
      'flag_emoji', c.flag_emoji,
      'route_mode', COALESCE(r.route_mode, 'disabled'),
      'profile_id', r.profile_id,
      'profile_label', p.label,
      'profile_kind', p.provider_kind,
      'profile_ready_state', p.ready_state,
      'expected_sender', p.expected_sender_number,
      'observed_sender', p.observed_sender_number,
      'health_status', COALESCE(r.health_status, 'disabled'),
      'health_reason', r.health_reason,
      'version', COALESCE(r.version, 1),
      'updated_at', r.updated_at
    ) ORDER BY c.name
  ), '[]'::jsonb) INTO v_res
  FROM public.countries c
  LEFT JOIN public.whatsapp_country_routes r ON r.country_id = c.id
  LEFT JOIN public.whatsapp_provider_profiles p ON p.id = r.profile_id;

  RETURN jsonb_build_object('success', true, 'items', v_res);
END;
$$;

-- 10. Admin RPC: Update WhatsApp Country Route
CREATE OR REPLACE FUNCTION public.admin_update_whatsapp_route(
  p_country_id uuid,
  p_route_mode text,
  p_profile_id uuid,
  p_expected_version int,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_uid uuid;
  v_clean_mode text := lower(btrim(p_route_mode));
  v_before jsonb;
  v_after jsonb;
  v_cur_version int;
  v_profile public.whatsapp_provider_profiles%ROWTYPE;
  v_health text;
  v_reason text;
  v_rows int;
BEGIN
  v_uid := public.assert_admin();

  IF v_clean_mode NOT IN ('disabled', 'baileys', 'meta_cloud') THEN
    RAISE EXCEPTION 'Invalid route_mode: %', p_route_mode USING ERRCODE = 'KS467';
  END IF;

  SELECT to_jsonb(r), r.version INTO v_before, v_cur_version
  FROM public.whatsapp_country_routes r WHERE r.country_id = p_country_id;

  IF v_before IS NOT NULL AND p_expected_version IS NOT NULL AND v_cur_version <> p_expected_version THEN
    RAISE EXCEPTION 'Stale route version conflict (expected %, current %)', p_expected_version, v_cur_version USING ERRCODE = 'KS409';
  END IF;

  IF v_clean_mode = 'disabled' THEN
    v_health := 'disabled';
    v_reason := 'Route explicitly disabled by administrator';
    p_profile_id := NULL;
  ELSE
    IF p_profile_id IS NULL THEN
      RAISE EXCEPTION 'Profile ID is required when route_mode is %', v_clean_mode USING ERRCODE = 'KS467';
    END IF;

    SELECT * INTO v_profile FROM public.whatsapp_provider_profiles WHERE id = p_profile_id;
    IF v_profile.id IS NULL THEN
      RAISE EXCEPTION 'Selected profile not found' USING ERRCODE = 'KS461';
    END IF;

    IF v_profile.provider_kind <> v_clean_mode THEN
      RAISE EXCEPTION 'Selected profile kind (%) does not match route mode (%)', v_profile.provider_kind, v_clean_mode USING ERRCODE = 'KS467';
    END IF;

    IF v_profile.ready_state = 'ready' THEN
      v_health := 'healthy';
      v_reason := 'Profile is ready and verified';
    ELSE
      v_health := 'degraded';
      v_reason := COALESCE(v_profile.last_error_detail, 'Profile state is ' || v_profile.ready_state);
    END IF;
  END IF;

  INSERT INTO public.whatsapp_country_routes (
    country_id,
    route_mode,
    profile_id,
    version,
    last_health_check_at,
    health_status,
    health_reason,
    updated_at,
    updated_by
  ) VALUES (
    p_country_id,
    v_clean_mode,
    p_profile_id,
    1,
    now(),
    v_health,
    v_reason,
    now(),
    v_uid
  )
  ON CONFLICT (country_id) DO UPDATE SET
    route_mode = v_clean_mode,
    profile_id = p_profile_id,
    version = public.whatsapp_country_routes.version + 1,
    last_health_check_at = now(),
    health_status = v_health,
    health_reason = v_reason,
    updated_at = now(),
    updated_by = v_uid
  WHERE public.whatsapp_country_routes.country_id = p_country_id
    AND (p_expected_version IS NULL OR public.whatsapp_country_routes.version = p_expected_version);

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    RAISE EXCEPTION 'Update failed: country not found or stale version conflict' USING ERRCODE = 'KS409';
  END IF;

  -- Also update legacy countries table columns for transition synchronization
  IF v_clean_mode = 'baileys' AND v_profile.connection_metadata ? 'endpoint_url' THEN
    UPDATE public.countries SET
      whatsapp_server_url = v_profile.connection_metadata ->> 'endpoint_url',
      whatsapp_account_phone = v_profile.expected_sender_number
    WHERE id = p_country_id;
  ELSIF v_clean_mode = 'disabled' THEN
    UPDATE public.countries SET
      whatsapp_server_url = NULL,
      whatsapp_account_phone = NULL
    WHERE id = p_country_id;
  END IF;

  SELECT to_jsonb(r) INTO v_after
  FROM public.whatsapp_country_routes r WHERE r.country_id = p_country_id;

  PERFORM public.admin_log(
    'whatsapp_route.update',
    'whatsapp_country_route',
    p_country_id::text,
    v_before,
    v_after,
    COALESCE(p_note, 'Updated WhatsApp route to ' || v_clean_mode)
  );

  RETURN jsonb_build_object(
    'success', true,
    'country_id', p_country_id,
    'route_mode', v_clean_mode,
    'version', (v_after ->> 'version')::int,
    'health_status', v_health
  );
END;
$$;

-- 11. Admin RPC: List WhatsApp Message Attempts
CREATE OR REPLACE FUNCTION public.admin_list_whatsapp_attempts(
  p_country_id uuid DEFAULT NULL,
  p_purpose text DEFAULT NULL,
  p_provider text DEFAULT NULL,
  p_state text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_res jsonb;
  v_total int;
BEGIN
  PERFORM public.assert_admin();

  SELECT count(*) INTO v_total
  FROM public.whatsapp_message_attempts a
  WHERE (p_country_id IS NULL OR a.recipient_country_id = p_country_id)
    AND (p_purpose IS NULL OR a.purpose = p_purpose)
    AND (p_provider IS NULL OR a.route_mode = p_provider)
    AND (p_state IS NULL OR a.state = p_state);

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', a.id,
      'purpose', a.purpose,
      'notification_id', a.notification_id,
      'command_id', a.command_id,
      'recipient_phone', (
        CASE
          WHEN length(a.recipient_phone) > 6 THEN
            left(a.recipient_phone, 4) || '***' || right(a.recipient_phone, 3)
          ELSE '***'
        END
      ),
      'recipient_country_id', a.recipient_country_id,
      'country_name', c.name,
      'country_iso', c.iso_code,
      'sim_line_id', a.sim_line_id,
      'sim_country_id', a.sim_country_id,
      'route_mode', a.route_mode,
      'profile_id', a.profile_id,
      'profile_label', p.label,
      'sender_number', a.sender_number,
      'idempotency_key', a.idempotency_key,
      'template_name', a.template_name,
      'template_language', a.template_language,
      'attempt_count', a.attempt_count,
      'state', a.state,
      'provider_message_id', a.provider_message_id,
      'error_category', a.error_category,
      'error_detail', a.error_detail,
      'created_at', a.created_at,
      'updated_at', a.updated_at,
      'delivered_at', a.delivered_at
    ) ORDER BY a.created_at DESC
  ), '[]'::jsonb) INTO v_res
  FROM (
    SELECT * FROM public.whatsapp_message_attempts
    WHERE (p_country_id IS NULL OR recipient_country_id = p_country_id)
      AND (p_purpose IS NULL OR purpose = p_purpose)
      AND (p_provider IS NULL OR route_mode = p_provider)
      AND (p_state IS NULL OR state = p_state)
    ORDER BY created_at DESC
    LIMIT LEAST(GREATEST(p_limit, 1), 200)
    OFFSET GREATEST(p_offset, 0)
  ) a
  LEFT JOIN public.countries c ON c.id = a.recipient_country_id
  LEFT JOIN public.whatsapp_provider_profiles p ON p.id = a.profile_id;

  RETURN jsonb_build_object(
    'success', true,
    'total', v_total,
    'items', v_res
  );
END;
$$;

-- 12. Admin RPC: Record WhatsApp Probe Results
CREATE OR REPLACE FUNCTION public.admin_record_whatsapp_probe(
  p_profile_id uuid,
  p_observed_sender text,
  p_ready_state text,
  p_error_category text DEFAULT NULL,
  p_error_detail text DEFAULT NULL,
  p_metadata_patch jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_uid uuid;
  v_profile public.whatsapp_provider_profiles%ROWTYPE;
BEGIN
  v_uid := public.assert_admin();

  SELECT * INTO v_profile FROM public.whatsapp_provider_profiles WHERE id = p_profile_id;
  IF v_profile.id IS NULL THEN
    RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'KS461';
  END IF;

  UPDATE public.whatsapp_provider_profiles SET
    observed_sender_number = COALESCE(NULLIF(btrim(p_observed_sender), ''), observed_sender_number),
    ready_state = p_ready_state,
    last_probe_at = now(),
    last_error_category = p_error_category,
    last_error_detail = p_error_detail,
    connection_metadata = connection_metadata || COALESCE(p_metadata_patch, '{}'::jsonb),
    updated_at = now(),
    updated_by = v_uid
  WHERE id = p_profile_id;

  -- Update associated country routes health
  UPDATE public.whatsapp_country_routes SET
    last_health_check_at = now(),
    health_status = CASE
      WHEN route_mode = 'disabled' THEN 'disabled'
      WHEN p_ready_state = 'ready' THEN 'healthy'
      ELSE 'degraded'
    END,
    health_reason = CASE
      WHEN route_mode = 'disabled' THEN 'Route disabled'
      WHEN p_ready_state = 'ready' THEN 'Profile probe verified ready'
      ELSE COALESCE(p_error_detail, 'Probe status: ' || p_ready_state)
    END
  WHERE profile_id = p_profile_id;

  RETURN jsonb_build_object('success', true, 'profile_id', p_profile_id, 'ready_state', p_ready_state);
END;
$$;

-- 13. Data Migration: Seed Initial Baileys Profile & Assign Country Routes
DO $$
DECLARE
  v_baileys_profile_id uuid := 'a1000000-0000-0000-0000-000000000001'::uuid;
  v_server_url text;
  v_sender_phone text;
  v_country record;
BEGIN
  -- Grab existing configured server url and phone if available
  SELECT whatsapp_server_url, whatsapp_account_phone 
  INTO v_server_url, v_sender_phone
  FROM public.countries
  WHERE whatsapp_server_url IS NOT NULL
  LIMIT 1;

  IF v_server_url IS NULL THEN
    v_server_url := 'http://34.40.33.208:3000';
  END IF;

  -- Insert initial default Baileys profile
  INSERT INTO public.whatsapp_provider_profiles (
    id,
    provider_kind,
    label,
    expected_sender_number,
    observed_sender_number,
    is_enabled,
    ready_state,
    version,
    connection_metadata
  ) VALUES (
    v_baileys_profile_id,
    'baileys',
    'Primary Baileys VPS',
    v_sender_phone,
    v_sender_phone,
    true,
    'ready',
    1,
    jsonb_build_object('endpoint_url', v_server_url)
  )
  ON CONFLICT (id) DO NOTHING;

  -- Create routes for all countries:
  -- Egypt and Oman get Baileys profile; others get Disabled
  FOR v_country IN SELECT id, whatsapp_server_url FROM public.countries LOOP
    IF v_country.whatsapp_server_url IS NOT NULL THEN
      INSERT INTO public.whatsapp_country_routes (
        country_id,
        route_mode,
        profile_id,
        version,
        health_status,
        health_reason,
        updated_at
      ) VALUES (
        v_country.id,
        'baileys',
        v_baileys_profile_id,
        1,
        'healthy',
        'Migrated from legacy country configuration',
        now()
      )
      ON CONFLICT (country_id) DO NOTHING;
    ELSE
      INSERT INTO public.whatsapp_country_routes (
        country_id,
        route_mode,
        profile_id,
        version,
        health_status,
        health_reason,
        updated_at
      ) VALUES (
        v_country.id,
        'disabled',
        NULL,
        1,
        'disabled',
        'Unconfigured route (fails closed)',
        now()
      )
      ON CONFLICT (country_id) DO NOTHING;
    END IF;
  END LOOP;
END;
$$;

COMMENT ON COLUMN public.countries.whatsapp_server_url IS 'DEPRECATED: Use public.whatsapp_country_routes and public.whatsapp_provider_profiles';
COMMENT ON COLUMN public.countries.whatsapp_account_phone IS 'DEPRECATED: Use public.whatsapp_country_routes and public.whatsapp_provider_profiles';

-- 14. Update trg_fn_dispatch_notification with strict entitlement and expiry checks
CREATE OR REPLACE FUNCTION public.trg_fn_dispatch_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_all_channels       text[];
  v_global_on          text[];
  v_channels           text[];
  v_category_chans     text[];
  v_is_enabled         boolean;
  v_url                text;
  v_payload            jsonb;
  v_secret             text;
  v_push_global_on     boolean;
  v_push_user_enabled  boolean;
  v_language           text;
  v_tier               text;
  v_plan_type          text;
  v_line_validity      timestamptz;
  v_effective_tier     text := 'basic';
  v_is_line_expired    boolean := false;
BEGIN
  SELECT ARRAY(SELECT channel_key FROM public.notification_channel_catalog ORDER BY sort_order),
         ARRAY(SELECT channel_key FROM public.notification_channel_catalog
                WHERE is_globally_enabled ORDER BY sort_order)
    INTO v_all_channels, v_global_on;

  IF COALESCE(array_length(v_all_channels, 1), 0) = 0 THEN
    v_all_channels := ARRAY['push','email','telegram','whatsapp'];
    v_global_on    := v_all_channels;
  END IF;

  v_push_global_on := 'push' = ANY (v_global_on);

  -- Strict line-level entitlement and expiry check
  IF NEW.sim_line_id IS NOT NULL THEN
    SELECT protection_tier, plan_type, validity_expires_at
    INTO v_tier, v_plan_type, v_line_validity
    FROM public.sim_lines WHERE id = NEW.sim_line_id;

    v_effective_tier := lower(COALESCE(v_tier, v_plan_type, 'basic'));
    v_is_line_expired := (v_line_validity IS NOT NULL AND v_line_validity < now());
  ELSE
    -- If no sim_line_id is associated (account-level), check user profile tier
    SELECT lower(subscription_tier) INTO v_tier FROM public.profiles WHERE id = NEW.user_id;
    v_effective_tier := COALESCE(v_tier, 'basic');
    v_is_line_expired := false;
  END IF;

  -- Fetch user preferred language
  SELECT language INTO v_language FROM public.user_preferences WHERE user_id = NEW.user_id;
  v_language := COALESCE(v_language, 'en');

  -- Category alert settings
  SELECT is_enabled, channels INTO v_is_enabled, v_category_chans
  FROM public.alert_settings
  WHERE user_id = NEW.user_id AND category = NEW.category;

  v_is_enabled     := COALESCE(v_is_enabled, NEW.category <> 'promo');
  v_category_chans := COALESCE(v_category_chans, v_all_channels);

  -- Inspect explicit push switch from notification_channels
  SELECT is_enabled INTO v_push_user_enabled
  FROM public.notification_channels
  WHERE user_id = NEW.user_id AND channel_type = 'push';

  -- Intersect user opt-in, category opt-in, and global catalog
  SELECT ARRAY(
    SELECT nc.channel_type
    FROM public.notification_channels nc
    WHERE nc.user_id = NEW.user_id
      AND nc.is_enabled = true
      AND nc.channel_type = ANY (v_category_chans)
      AND nc.channel_type = ANY (v_global_on)
  ) INTO v_channels;

  -- GATING: Paid channels (whatsapp and email) require an active Standard or Premium line.
  -- Expired lines, missing tiers, or Basic lines can ONLY receive push and telegram!
  IF v_effective_tier NOT IN ('standard', 'premium') OR v_is_line_expired THEN
    SELECT ARRAY(
      SELECT val FROM unnest(v_channels) AS val 
      WHERE val IN ('push', 'telegram')
    ) INTO v_channels;
  END IF;

  -- Fallback to push ONLY if push was NOT explicitly disabled by the user
  IF COALESCE(array_length(v_channels, 1), 0) = 0
     AND (v_push_user_enabled IS NULL OR v_push_user_enabled = true)
     AND 'push' = ANY (v_category_chans)
     AND v_push_global_on THEN
    v_channels := ARRAY['push'::text];
  END IF;

  UPDATE public.notifications SET delivered_via = v_channels WHERE id = NEW.id;

  IF v_is_enabled AND COALESCE(array_length(v_channels, 1), 0) > 0 THEN
    SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'dispatch_shared_secret';

    v_url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/dispatch-alert';

    v_payload := jsonb_build_object(
      'notification_id', NEW.id,
      'user_id',         NEW.user_id,
      'category',        NEW.category,
      'title',           NEW.title,
      'body',            NEW.body,
      'action_url',      NEW.action_url,
      'sim_line_id',     NEW.sim_line_id,
      'channels',        to_jsonb(v_channels),
      'schema_version',  COALESCE(NEW.schema_version, 1),
      'event_type',      NEW.event_type,
      'template_data',   COALESCE(NEW.template_data, '{}'::jsonb),
      'target',          NEW.target,
      'language',        v_language
    );

    PERFORM net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-keep-sims-secret', COALESCE(v_secret, '')
      ),
      body := v_payload,
      timeout_milliseconds := 5000
    );
  END IF;

  RETURN NEW;
END;
$function$;

NOTIFY pgrst, 'reload schema';
