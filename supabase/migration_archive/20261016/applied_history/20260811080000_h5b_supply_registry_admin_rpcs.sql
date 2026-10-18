-- H5b — admin surface for the two registries H5 created.

CREATE OR REPLACE FUNCTION public.admin_list_esim_suppliers()
RETURNS TABLE (
  code             text,
  name             text,
  website_url      text,
  api_base_url     text,
  docs_url         text,
  credential_secret text,
  is_active        boolean,
  priority         integer,
  markup_percent_override numeric,
  effective_markup_percent numeric,
  countries_supported text[],
  last_sync_at     timestamptz,
  last_sync_status text,
  last_sync_count  integer,
  last_sync_error  text,
  notes            text,
  live_offers      bigint,
  cheapest_usd_per_gb numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_default numeric;
BEGIN
  PERFORM public.assert_admin();

  SELECT NULLIF(config_value,'')::numeric INTO v_default
  FROM public.system_configs WHERE config_key = 'ESIM_MARKUP_PERCENT';

  RETURN QUERY
  SELECT s.code, s.name, s.website_url, s.api_base_url, s.docs_url, s.credential_secret,
         s.is_active, s.priority, s.markup_percent_override,
         COALESCE(s.markup_percent_override, v_default, 0),
         s.countries_supported, s.last_sync_at, s.last_sync_status, s.last_sync_count,
         s.last_sync_error, s.notes,
         COALESCE(o.n, 0), o.cheapest
  FROM public.esim_suppliers s
  LEFT JOIN LATERAL (
    SELECT count(*) n,
           min(CASE WHEN e.data_amount_mb > 0
                    THEN round(e.wholesale_price_usd / (e.data_amount_mb / 1024.0), 4) END) cheapest
    FROM public.esim_offers_cache e
    WHERE e.provider = s.code AND e.is_active
  ) o ON true
  ORDER BY s.priority, s.code;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_esim_suppliers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_esim_suppliers() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_upsert_esim_supplier(
  p_code  text,
  p_patch jsonb,
  p_note  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_allowed text[] := ARRAY['name','website_url','api_base_url','docs_url','credential_secret',
                            'is_active','priority','markup_percent_override','notes'];
  v_bad    text;
  v_before jsonb;
  v_after  jsonb;
  v_markup numeric;
  v_url    text;
BEGIN
  PERFORM public.assert_admin();

  IF p_code IS NULL OR p_code !~ '^[a-z0-9_]{2,32}$' THEN
    RAISE EXCEPTION 'Supplier code must be lower-case letters, digits or underscore (2-32 chars)'
      USING ERRCODE = 'KS466';
  END IF;

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Nothing to change' USING ERRCODE = 'KS467';
  END IF;

  SELECT string_agg(k, ', ') INTO v_bad
  FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'Unknown field(s): %', v_bad USING ERRCODE = 'KS467';
  END IF;

  FOREACH v_url IN ARRAY ARRAY['website_url','api_base_url','docs_url'] LOOP
    IF p_patch ? v_url AND NULLIF(btrim(p_patch ->> v_url),'') IS NOT NULL
       AND (p_patch ->> v_url) !~ '^https?://[^\s]+$' THEN
      RAISE EXCEPTION '% must be an http(s) URL', v_url USING ERRCODE = 'KS466';
    END IF;
  END LOOP;

  IF p_patch ? 'markup_percent_override' THEN
    v_markup := NULLIF(p_patch ->> 'markup_percent_override','')::numeric;
    IF v_markup IS NOT NULL AND (v_markup < 0 OR v_markup > 500) THEN
      RAISE EXCEPTION 'Markup override must be 0..500 percent' USING ERRCODE = 'KS466';
    END IF;
  END IF;

  SELECT to_jsonb(s) INTO v_before FROM public.esim_suppliers s WHERE s.code = p_code;

  IF v_before IS NULL THEN
    INSERT INTO public.esim_suppliers (code, name)
    VALUES (p_code, COALESCE(NULLIF(btrim(p_patch ->> 'name'),''), p_code));
  END IF;

  UPDATE public.esim_suppliers SET
    name         = COALESCE(NULLIF(btrim(p_patch ->> 'name'),''), name),
    website_url  = CASE WHEN p_patch ? 'website_url'  THEN NULLIF(btrim(p_patch ->> 'website_url'),'')  ELSE website_url END,
    api_base_url = CASE WHEN p_patch ? 'api_base_url' THEN NULLIF(btrim(p_patch ->> 'api_base_url'),'') ELSE api_base_url END,
    docs_url     = CASE WHEN p_patch ? 'docs_url'     THEN NULLIF(btrim(p_patch ->> 'docs_url'),'')     ELSE docs_url END,
    credential_secret = CASE WHEN p_patch ? 'credential_secret'
                             THEN NULLIF(btrim(p_patch ->> 'credential_secret'),'') ELSE credential_secret END,
    is_active    = COALESCE((p_patch ->> 'is_active')::boolean, is_active),
    priority     = COALESCE((p_patch ->> 'priority')::integer, priority),
    markup_percent_override = CASE WHEN p_patch ? 'markup_percent_override'
                                   THEN NULLIF(p_patch ->> 'markup_percent_override','')::numeric
                                   ELSE markup_percent_override END,
    notes        = CASE WHEN p_patch ? 'notes' THEN NULLIF(btrim(p_patch ->> 'notes'),'') ELSE notes END,
    updated_at   = now()
  WHERE code = p_code;

  SELECT to_jsonb(s) INTO v_after FROM public.esim_suppliers s WHERE s.code = p_code;

  PERFORM public.admin_log(
    CASE WHEN v_before IS NULL THEN 'esim_supplier.create' ELSE 'esim_supplier.update' END,
    'esim_supplier', p_code, v_before, v_after, p_note);

  RETURN jsonb_build_object('success', true, 'code', p_code, 'created', v_before IS NULL);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_esim_supplier(text,jsonb,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_esim_supplier(text,jsonb,text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_list_offline_endpoints()
RETURNS TABLE (
  id           uuid,
  channel      text,
  phone_number text,
  label        text,
  country_code text,
  provider     text,
  is_active    boolean,
  is_primary   boolean,
  sort_order   integer,
  notes        text,
  mirrored_config_key   text,
  mirrored_config_value text,
  in_sync      boolean,
  inbound_30d  bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT e.id, e.channel, e.phone_number, e.label, e.country_code, e.provider,
         e.is_active, e.is_primary, e.sort_order, e.notes,
         k.key, c.config_value::text,
         (NOT e.is_primary) OR c.config_value::text = e.phone_number,
         COALESCE(l.n, 0)
  FROM public.offline_refill_endpoints e
  CROSS JOIN LATERAL (SELECT CASE e.channel
                               WHEN 'sms'      THEN 'OFFLINE_SMS_NUMBER'
                               WHEN 'whatsapp' THEN 'OFFLINE_WHATSAPP_NUMBER'
                               WHEN 'ivr'      THEN 'OFFLINE_IVR_NUMBER'
                             END AS key) k
  LEFT JOIN public.system_configs c ON c.config_key = k.key
  LEFT JOIN LATERAL (
    SELECT count(*) n FROM public.offline_command_log ocl
    WHERE ocl.created_at > now() - interval '30 days'
  ) l ON e.is_primary
  ORDER BY e.channel, e.sort_order, e.label;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_offline_endpoints() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_offline_endpoints() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_upsert_offline_endpoint(
  p_id    uuid,
  p_patch jsonb,
  p_note  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_allowed text[] := ARRAY['channel','phone_number','label','country_code','provider',
                            'is_active','is_primary','sort_order','notes'];
  v_bad     text;
  v_before  jsonb;
  v_after   jsonb;
  v_id      uuid := p_id;
  v_channel text;
BEGIN
  PERFORM public.assert_admin();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Nothing to change' USING ERRCODE = 'KS467';
  END IF;

  SELECT string_agg(k, ', ') INTO v_bad
  FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'Unknown field(s): %', v_bad USING ERRCODE = 'KS467';
  END IF;

  IF v_id IS NULL THEN
    v_channel := p_patch ->> 'channel';
    IF v_channel IS NULL THEN
      RAISE EXCEPTION 'A new endpoint needs a channel' USING ERRCODE = 'KS466';
    END IF;
    INSERT INTO public.offline_refill_endpoints (channel, phone_number, label, is_primary)
    VALUES (v_channel,
            COALESCE(p_patch ->> 'phone_number', '+000000000'),
            COALESCE(NULLIF(btrim(p_patch ->> 'label'),''), initcap(v_channel) || ' line'),
            false)
    RETURNING id INTO v_id;
  END IF;

  SELECT to_jsonb(e) INTO v_before FROM public.offline_refill_endpoints e WHERE e.id = v_id;
  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Endpoint % not found', v_id USING ERRCODE = 'KS461';
  END IF;

  -- Promoting a row demotes its sibling first. The partial unique index makes
  -- the alternative a constraint violation rather than a silent second primary,
  -- but the operator asked to promote this one, not to be told no.
  IF COALESCE((p_patch ->> 'is_primary')::boolean, false) THEN
    UPDATE public.offline_refill_endpoints
    SET is_primary = false, updated_at = now()
    WHERE channel = (v_before ->> 'channel') AND id <> v_id AND is_primary;
  END IF;

  UPDATE public.offline_refill_endpoints SET
    channel      = COALESCE(p_patch ->> 'channel', channel),
    phone_number = COALESCE(NULLIF(btrim(p_patch ->> 'phone_number'),''), phone_number),
    label        = COALESCE(NULLIF(btrim(p_patch ->> 'label'),''), label),
    country_code = CASE WHEN p_patch ? 'country_code'
                        THEN upper(NULLIF(btrim(p_patch ->> 'country_code'),'')) ELSE country_code END,
    provider     = CASE WHEN p_patch ? 'provider'
                        THEN NULLIF(btrim(p_patch ->> 'provider'),'') ELSE provider END,
    is_active    = COALESCE((p_patch ->> 'is_active')::boolean, is_active),
    is_primary   = COALESCE((p_patch ->> 'is_primary')::boolean, is_primary),
    sort_order   = COALESCE((p_patch ->> 'sort_order')::integer, sort_order),
    notes        = CASE WHEN p_patch ? 'notes' THEN NULLIF(btrim(p_patch ->> 'notes'),'') ELSE notes END,
    updated_at   = now()
  WHERE id = v_id;

  SELECT to_jsonb(e) INTO v_after FROM public.offline_refill_endpoints e WHERE e.id = v_id;

  -- A primary must be reachable. Deactivating it would leave the mirrored
  -- system_configs key pointing at a number we have just declared dead, and the
  -- client caches that key on-device.
  IF (v_after ->> 'is_primary')::boolean AND NOT (v_after ->> 'is_active')::boolean THEN
    RAISE EXCEPTION 'The primary % endpoint cannot be inactive — promote another one first',
      (v_after ->> 'channel') USING ERRCODE = 'KS466';
  END IF;

  PERFORM public.admin_log(
    CASE WHEN p_id IS NULL THEN 'offline_endpoint.create' ELSE 'offline_endpoint.update' END,
    'offline_endpoint', v_id::text, v_before, v_after, p_note);

  RETURN jsonb_build_object('success', true, 'id', v_id, 'created', p_id IS NULL);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_offline_endpoint(uuid,jsonb,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_offline_endpoint(uuid,jsonb,text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_delete_offline_endpoint(p_id uuid, p_note text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE v_before jsonb;
BEGIN
  PERFORM public.assert_admin();

  SELECT to_jsonb(e) INTO v_before FROM public.offline_refill_endpoints e WHERE e.id = p_id;
  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Endpoint % not found', p_id USING ERRCODE = 'KS461';
  END IF;
  IF (v_before ->> 'is_primary')::boolean THEN
    RAISE EXCEPTION 'Cannot delete the primary % endpoint — promote another one first',
      (v_before ->> 'channel') USING ERRCODE = 'KS466';
  END IF;

  DELETE FROM public.offline_refill_endpoints WHERE id = p_id;
  PERFORM public.admin_log('offline_endpoint.delete', 'offline_endpoint', p_id::text, v_before, NULL, p_note);
  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_delete_offline_endpoint(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_offline_endpoint(uuid,text) TO authenticated, service_role;
