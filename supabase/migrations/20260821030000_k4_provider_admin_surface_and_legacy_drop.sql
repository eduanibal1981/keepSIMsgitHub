-- =============================================================================
-- K4 · The admin surface for providers, mappings and the offer catalogue —
--      then, finally, the legacy columns go
-- =============================================================================
-- ORDER MATTERS AND IS THE POINT OF SPLITTING THIS FROM K3.
--   plpgsql function bodies are NOT validated when a column is dropped. Dropping
--   carriers.zen_carrier while admin_list_carriers still selected it would have
--   succeeded silently and left the admin app raising 42703 on next open — a
--   failure that reads as "the admin app broke", not as "a migration dropped a
--   column". So every admin reader is rewritten first, and the ALTER TABLE is
--   the last statement in the file.
--
-- WHAT THE OPERATOR CAN NOW DO WITHOUT A MIGRATION
--   * add a supplier (admin_upsert_service_provider INSERTs as well as updates)
--   * map a carrier to it, with that supplier's own country and telecom labels
--   * choose which supplier is primary, with the incumbent demoted atomically
--   * set a manual price or name on any offer, top-up or eSIM, and have it
--     survive the nightly sync
--   * force a catalogue refresh
--
-- THREE GUARDS WORTH NOT RE-DERIVING
--   (a) A new provider is forced INACTIVE regardless of what the caller asked
--       for. I5's finding: a supplier enabled with an empty cache ranks as
--       infinitely cheap BY ABSENCE, so it wins every comparison and fulfils
--       nothing. Activation has to be a second, deliberate call after the
--       mapping and catalogue exist.
--   (b) An override price below the supplier's own cost is REFUSED, checked
--       after the write against the resulting row (the J4 pattern, so setting
--       fields in either order or in separate calls cannot slip past). This is
--       the exact failure carrier_rules.inapp_pricing already had: below cost on
--       most carriers, selling premium at a loss.
--   (c) Only override_* is writable. A patch naming a source_* column is refused
--       with an explanation rather than accepted — accepting it would be a
--       change the next nightly run silently reverts, which is worse than a
--       refusal an operator can see.
--
-- ⚠ DEPLOY ORDER FOR THE VM. worker_instant_refill.js, worker_auto_mini_refill.js
--   and worker_auto_custom_refill.js all `select` the dropped columns in their
--   K2-and-earlier form. Their K3 versions must be on the VM before or with this
--   migration, or their next poll errors on an unknown column.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. service_providers: list + upsert (the INSERT is the requested capability)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_service_providers()
RETURNS TABLE (code text, name text, supports_topup boolean, supports_esim boolean,
  country_label_style text, carrier_label_style text, is_active boolean, priority integer,
  website_url text, api_base_url text, docs_url text, credential_secret text, notes text,
  ranking_enabled boolean, risk_premium_percent numeric, flat_penalty_usd numeric,
  mapped_carriers bigint, enabled_carriers bigint, topup_offers bigint, esim_offers bigint,
  last_sync_at timestamptz, last_sync_status text, readiness text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
  SELECT sp.code, sp.name, sp.supports_topup, sp.supports_esim,
         sp.country_label_style, sp.carrier_label_style, sp.is_active, sp.priority,
         sp.website_url, sp.api_base_url, sp.docs_url, sp.credential_secret, sp.notes,
         COALESCE(pol.is_globally_enabled, false), pol.risk_premium_percent, pol.flat_penalty_usd,
         (SELECT count(*) FROM public.carrier_provider_map m WHERE m.provider = sp.code),
         (SELECT count(*) FROM public.carrier_provider_map m WHERE m.provider = sp.code AND m.is_enabled),
         (SELECT count(*) FROM public.provider_offers o WHERE o.provider_code = sp.code AND o.offer_kind='topup' AND o.is_active),
         (SELECT count(*) FROM public.provider_offers o WHERE o.provider_code = sp.code AND o.offer_kind='esim'  AND o.is_active),
         es.last_sync_at, es.last_sync_status,
         -- The one thing an operator cannot see by eye: a supplier switched on
         -- with nothing to sell ranks as infinitely cheap by absence (I5).
         CASE
           WHEN NOT sp.is_active THEN 'inactive'
           WHEN NOT EXISTS (SELECT 1 FROM public.carrier_provider_map m
                             WHERE m.provider = sp.code AND m.is_enabled)
             THEN 'active but no carrier mapping is enabled'
           WHEN NOT EXISTS (SELECT 1 FROM public.provider_offers o
                             WHERE o.provider_code = sp.code AND o.is_active)
             THEN 'active and mapped but its catalogue is empty'
           ELSE 'ok'
         END
  FROM public.service_providers sp
  LEFT JOIN public.supplier_policy pol ON pol.provider = sp.code
  LEFT JOIN public.esim_suppliers  es  ON es.code = sp.code
  ORDER BY sp.priority, sp.code;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_upsert_service_provider(
  p_code text, p_patch jsonb, p_note text DEFAULT NULL::text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_allowed text[] := ARRAY['name','supports_topup','supports_esim','country_label_style',
                            'carrier_label_style','is_active','priority','website_url',
                            'api_base_url','docs_url','credential_secret','notes'];
  v_bad text; v_before RECORD; v_after RECORD; v_created boolean := false; v_code text;
BEGIN
  PERFORM public.assert_admin();

  v_code := lower(btrim(COALESCE(p_code, '')));
  IF v_code = '' THEN
    RAISE EXCEPTION 'A provider code is required' USING ERRCODE = 'KS466';
  END IF;
  -- The code is a join key in four tables and is typed into worker config by
  -- hand. Anything but a lowercase slug becomes a lookup that silently matches
  -- nothing.
  IF v_code !~ '^[a-z][a-z0-9_]{1,30}$' THEN
    RAISE EXCEPTION 'Provider code must be a lowercase slug, e.g. reloadly or my_supplier'
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

  SELECT * INTO v_before FROM public.service_providers WHERE code = v_code FOR UPDATE;

  IF NOT FOUND THEN
    IF NOT (p_patch ? 'name') THEN
      RAISE EXCEPTION 'A new provider needs a name' USING ERRCODE = 'KS466';
    END IF;
    -- New suppliers arrive INACTIVE regardless of what the caller asked for.
    -- Enabling one before its mapping and catalogue exist makes it win every
    -- comparison by having no prices at all.
    INSERT INTO public.service_providers (code, name, is_active)
    VALUES (v_code, btrim(p_patch ->> 'name'), false);
    v_created := true;
    SELECT * INTO v_before FROM public.service_providers WHERE code = v_code;
  END IF;

  UPDATE public.service_providers SET
    name                = CASE WHEN p_patch ? 'name' THEN NULLIF(btrim(p_patch ->> 'name'),'') ELSE name END,
    supports_topup      = CASE WHEN p_patch ? 'supports_topup' THEN (p_patch ->> 'supports_topup')::boolean ELSE supports_topup END,
    supports_esim       = CASE WHEN p_patch ? 'supports_esim'  THEN (p_patch ->> 'supports_esim')::boolean  ELSE supports_esim END,
    country_label_style = CASE WHEN p_patch ? 'country_label_style' THEN p_patch ->> 'country_label_style' ELSE country_label_style END,
    carrier_label_style = CASE WHEN p_patch ? 'carrier_label_style' THEN p_patch ->> 'carrier_label_style' ELSE carrier_label_style END,
    is_active           = CASE WHEN v_created THEN false
                               WHEN p_patch ? 'is_active' THEN (p_patch ->> 'is_active')::boolean ELSE is_active END,
    priority            = CASE WHEN p_patch ? 'priority' THEN (p_patch ->> 'priority')::integer ELSE priority END,
    website_url         = CASE WHEN p_patch ? 'website_url' THEN NULLIF(btrim(p_patch ->> 'website_url'),'') ELSE website_url END,
    api_base_url        = CASE WHEN p_patch ? 'api_base_url' THEN NULLIF(btrim(p_patch ->> 'api_base_url'),'') ELSE api_base_url END,
    docs_url            = CASE WHEN p_patch ? 'docs_url' THEN NULLIF(btrim(p_patch ->> 'docs_url'),'') ELSE docs_url END,
    credential_secret   = CASE WHEN p_patch ? 'credential_secret' THEN NULLIF(btrim(p_patch ->> 'credential_secret'),'') ELSE credential_secret END,
    notes               = CASE WHEN p_patch ? 'notes' THEN NULLIF(btrim(p_patch ->> 'notes'),'') ELSE notes END,
    updated_at          = now()
  WHERE code = v_code;

  SELECT * INTO v_after FROM public.service_providers WHERE code = v_code;

  IF v_after.name IS NULL OR v_after.name = '' THEN
    RAISE EXCEPTION 'A provider needs a name' USING ERRCODE = 'KS466';
  END IF;

  -- Checked AFTER the write, against the resulting row, so setting the fields in
  -- either order or in separate calls cannot slip past (the J4 pattern).
  IF v_after.is_active AND NOT (v_after.supports_topup OR v_after.supports_esim) THEN
    RAISE EXCEPTION 'A provider cannot be active while selling neither top-ups nor eSIMs'
      USING ERRCODE = 'KS466';
  END IF;

  -- A top-up supplier also needs its ranking economics row, or supplier_candidates
  -- joins it away and it can never win a comparison however it is configured.
  IF v_after.supports_topup THEN
    INSERT INTO public.supplier_policy (provider, is_globally_enabled)
    VALUES (v_code, false) ON CONFLICT (provider) DO NOTHING;
  END IF;
  IF v_after.supports_esim THEN
    INSERT INTO public.esim_suppliers (code, name, is_active)
    VALUES (v_code, v_after.name, false) ON CONFLICT (code) DO NOTHING;
  END IF;

  PERFORM public.admin_log(
    CASE WHEN v_created THEN 'service_provider.create' ELSE 'service_provider.update' END,
    'service_provider', v_code,
    CASE WHEN v_created THEN '{}'::jsonb ELSE jsonb_build_object(
      'name', v_before.name, 'is_active', v_before.is_active,
      'supports_topup', v_before.supports_topup, 'supports_esim', v_before.supports_esim,
      'priority', v_before.priority) END,
    jsonb_build_object('name', v_after.name, 'is_active', v_after.is_active,
      'supports_topup', v_after.supports_topup, 'supports_esim', v_after.supports_esim,
      'priority', v_after.priority),
    COALESCE(p_note, 'via admin app') || ' (' || v_code || ')');

  RETURN jsonb_build_object('success', true, 'code', v_code, 'created', v_created,
    'is_active', v_after.is_active);
END;
$function$;

-- -----------------------------------------------------------------------------
-- 2. carrier <-> provider mapping
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_carrier_provider_map(p_carrier_id uuid DEFAULT NULL)
RETURNS TABLE (carrier_id uuid, carrier_name text, country_code text, provider_code text,
  provider_name text, provider_country_code text, provider_country_label text,
  provider_carrier_code text, provider_carrier_label text, is_enabled boolean,
  is_primary boolean, is_routable boolean, priority integer,
  offers_cached bigint, cheapest_usd numeric, last_verified_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
  SELECT r.carrier_id, r.carrier_name, r.country_code, r.provider_code, r.provider_name,
         r.provider_country_code, r.provider_country_label,
         r.provider_carrier_code, r.provider_carrier_label,
         r.is_enabled, r.is_primary, r.is_routable, r.priority,
         (SELECT count(*) FROM public.provider_offers o
           WHERE o.carrier_id = r.carrier_id AND o.provider_code = r.provider_code AND o.is_active),
         (SELECT min(o.effective_price_usd) FROM public.provider_offers o
           WHERE o.carrier_id = r.carrier_id AND o.provider_code = r.provider_code AND o.is_active),
         r.last_verified_at
  FROM public.carrier_supplier_routing r
  WHERE p_carrier_id IS NULL OR r.carrier_id = p_carrier_id
  ORDER BY r.carrier_name, r.is_primary DESC, r.priority, r.provider_code;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_upsert_carrier_provider_map(
  p_carrier_id uuid, p_provider text, p_patch jsonb, p_note text DEFAULT NULL::text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_allowed text[] := ARRAY['provider_country_code','provider_country_label',
                            'provider_carrier_code','provider_carrier_label',
                            'is_enabled','is_primary','priority','notes'];
  v_bad text; v_before RECORD; v_after RECORD; v_created boolean := false;
BEGIN
  PERFORM public.assert_admin();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Nothing to change' USING ERRCODE = 'KS467';
  END IF;
  SELECT string_agg(k, ', ') INTO v_bad FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'Unknown field(s): %', v_bad USING ERRCODE = 'KS467';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.carriers WHERE id = p_carrier_id) THEN
    RAISE EXCEPTION 'Carrier % not found', p_carrier_id USING ERRCODE = 'KS461';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.service_providers WHERE code = p_provider AND supports_topup) THEN
    RAISE EXCEPTION 'Provider % is not a top-up supplier', p_provider USING ERRCODE = 'KS461';
  END IF;

  SELECT * INTO v_before FROM public.carrier_provider_map
   WHERE carrier_id = p_carrier_id AND provider = p_provider FOR UPDATE;

  IF NOT FOUND THEN
    IF NOT (p_patch ? 'provider_carrier_code') THEN
      RAISE EXCEPTION 'A new mapping needs the supplier''s carrier code' USING ERRCODE = 'KS466';
    END IF;
    INSERT INTO public.carrier_provider_map
      (carrier_id, provider, provider_country_code, provider_carrier_code,
       provider_country_label, provider_carrier_label, is_enabled)
    SELECT p_carrier_id, p_provider,
           upper(COALESCE(NULLIF(btrim(p_patch ->> 'provider_country_code'),''), co.iso_code)),
           btrim(p_patch ->> 'provider_carrier_code'),
           COALESCE(NULLIF(btrim(p_patch ->> 'provider_country_label'),''), co.name),
           COALESCE(NULLIF(btrim(p_patch ->> 'provider_carrier_label'),''),
                    btrim(p_patch ->> 'provider_carrier_code')),
           false
    FROM public.carriers c JOIN public.countries co ON co.id = c.country_id
    WHERE c.id = p_carrier_id;
    v_created := true;
    SELECT * INTO v_before FROM public.carrier_provider_map
     WHERE carrier_id = p_carrier_id AND provider = p_provider;
  END IF;

  -- Promoting a new primary must demote the incumbent in the same statement, or
  -- uq_carrier_provider_map_primary rejects the write and the operator sees a
  -- constraint name instead of a result.
  IF (p_patch ? 'is_primary') AND (p_patch ->> 'is_primary')::boolean THEN
    UPDATE public.carrier_provider_map SET is_primary = false, updated_at = now()
     WHERE carrier_id = p_carrier_id AND provider <> p_provider AND is_primary;
  END IF;

  UPDATE public.carrier_provider_map SET
    provider_country_code  = CASE WHEN p_patch ? 'provider_country_code'
                                  THEN upper(btrim(p_patch ->> 'provider_country_code')) ELSE provider_country_code END,
    provider_country_label = CASE WHEN p_patch ? 'provider_country_label'
                                  THEN NULLIF(btrim(p_patch ->> 'provider_country_label'),'') ELSE provider_country_label END,
    provider_carrier_code  = CASE WHEN p_patch ? 'provider_carrier_code'
                                  THEN btrim(p_patch ->> 'provider_carrier_code') ELSE provider_carrier_code END,
    provider_carrier_label = CASE WHEN p_patch ? 'provider_carrier_label'
                                  THEN NULLIF(btrim(p_patch ->> 'provider_carrier_label'),'') ELSE provider_carrier_label END,
    is_enabled             = CASE WHEN p_patch ? 'is_enabled' THEN (p_patch ->> 'is_enabled')::boolean ELSE is_enabled END,
    is_primary             = CASE WHEN p_patch ? 'is_primary' THEN (p_patch ->> 'is_primary')::boolean ELSE is_primary END,
    priority               = CASE WHEN p_patch ? 'priority' THEN (p_patch ->> 'priority')::integer ELSE priority END,
    notes                  = CASE WHEN p_patch ? 'notes' THEN NULLIF(btrim(p_patch ->> 'notes'),'') ELSE notes END,
    last_verified_at       = CASE WHEN p_patch ? 'provider_carrier_code' THEN now() ELSE last_verified_at END
  WHERE carrier_id = p_carrier_id AND provider = p_provider;

  SELECT * INTO v_after FROM public.carrier_provider_map
   WHERE carrier_id = p_carrier_id AND provider = p_provider;

  IF v_after.provider_carrier_code IS NULL OR btrim(v_after.provider_carrier_code) = '' THEN
    RAISE EXCEPTION 'A mapping needs the supplier''s carrier code' USING ERRCODE = 'KS466';
  END IF;

  PERFORM public.admin_log(
    CASE WHEN v_created THEN 'carrier_provider_map.create' ELSE 'carrier_provider_map.update' END,
    'carrier_provider_map', p_carrier_id::text || '/' || p_provider,
    jsonb_build_object('carrier_code', v_before.provider_carrier_code,
      'country_code', v_before.provider_country_code, 'is_enabled', v_before.is_enabled,
      'is_primary', v_before.is_primary, 'priority', v_before.priority),
    jsonb_build_object('carrier_code', v_after.provider_carrier_code,
      'country_code', v_after.provider_country_code, 'is_enabled', v_after.is_enabled,
      'is_primary', v_after.is_primary, 'priority', v_after.priority),
    COALESCE(p_note, 'via admin app'));

  RETURN jsonb_build_object('success', true, 'created', v_created,
    'carrier_id', p_carrier_id, 'provider', p_provider,
    'is_enabled', v_after.is_enabled, 'is_primary', v_after.is_primary);
END;
$function$;

-- -----------------------------------------------------------------------------
-- 3. the offer catalogue
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_provider_offers(
  p_offer_kind text DEFAULT NULL, p_provider_code text DEFAULT NULL,
  p_country_code text DEFAULT NULL, p_carrier_id uuid DEFAULT NULL,
  p_only_overridden boolean DEFAULT false, p_limit integer DEFAULT 200, p_offset integer DEFAULT 0)
RETURNS TABLE (id uuid, provider_code text, provider_name text, offer_kind text, offer_code text,
  country_code text, country_name text, carrier_id uuid, carrier_name text,
  offer_name text, price_type text, supplier_cost_usd numeric, effective_price_usd numeric,
  override_price_usd numeric, override_name text, override_is_active boolean, override_note text,
  price_min_usd numeric, price_max_usd numeric, data_mb bigint, duration_days integer,
  is_unlimited boolean, speed_tier text, is_active boolean, source_is_active boolean,
  is_stale boolean, source_refreshed_at timestamptz, overridden_at timestamptz, total_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
  WITH f AS (
    SELECT o.* FROM public.provider_offers o
    WHERE (p_offer_kind    IS NULL OR o.offer_kind    = p_offer_kind)
      AND (p_provider_code IS NULL OR o.provider_code = p_provider_code)
      AND (p_country_code  IS NULL OR o.country_code  = upper(p_country_code))
      AND (p_carrier_id    IS NULL OR o.carrier_id    = p_carrier_id)
      AND (NOT p_only_overridden
           OR o.override_price_usd IS NOT NULL OR o.override_is_active IS NOT NULL
           OR o.override_name IS NOT NULL))
  SELECT f.id, f.provider_code, sp.name, f.offer_kind, f.offer_code,
         f.country_code, co.name, f.carrier_id, ca.name,
         f.effective_name, f.source_price_type, f.source_price_usd, f.effective_price_usd,
         f.override_price_usd, f.override_name, f.override_is_active, f.override_note,
         f.source_price_min_usd, f.source_price_max_usd, f.source_data_mb, f.source_duration_days,
         f.source_is_unlimited, f.source_speed_tier, f.is_active, f.source_is_active,
         (f.source_refreshed_at < now() - interval '24 hours'), f.source_refreshed_at,
         f.overridden_at, (SELECT count(*) FROM f)
  FROM f
  JOIN public.service_providers sp ON sp.code = f.provider_code
  JOIN public.countries co ON co.iso_code = f.country_code
  LEFT JOIN public.carriers ca ON ca.id = f.carrier_id
  ORDER BY f.offer_kind, f.country_code, ca.name NULLS FIRST, f.effective_price_usd
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 200), 1000)) OFFSET GREATEST(0, COALESCE(p_offset, 0));
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_override_provider_offer(
  p_offer_id uuid, p_patch jsonb, p_note text DEFAULT NULL::text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_allowed text[] := ARRAY['override_price_usd','override_name','override_is_active','override_note'];
  v_bad text; v_before RECORD; v_after RECORD; v_actor uuid;
BEGIN
  PERFORM public.assert_admin();
  v_actor := auth.uid();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Nothing to change' USING ERRCODE = 'KS467';
  END IF;
  SELECT string_agg(k, ', ') INTO v_bad FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    -- source_* is the sync's. Letting an operator write it would be a change the
    -- next nightly run silently reverts, which is worse than refusing.
    RAISE EXCEPTION 'Unknown or read-only field(s): %. Only override_* fields are editable; source_* belongs to the nightly sync.',
      v_bad USING ERRCODE = 'KS467';
  END IF;

  SELECT * INTO v_before FROM public.provider_offers WHERE id = p_offer_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Offer % not found', p_offer_id USING ERRCODE = 'KS461';
  END IF;

  UPDATE public.provider_offers SET
    override_price_usd = CASE WHEN p_patch ? 'override_price_usd'
                              THEN NULLIF(p_patch ->> 'override_price_usd','')::numeric ELSE override_price_usd END,
    override_name      = CASE WHEN p_patch ? 'override_name'
                              THEN NULLIF(btrim(p_patch ->> 'override_name'),'') ELSE override_name END,
    override_is_active = CASE WHEN p_patch ? 'override_is_active'
                              THEN NULLIF(p_patch ->> 'override_is_active','')::boolean ELSE override_is_active END,
    override_note      = CASE WHEN p_patch ? 'override_note'
                              THEN NULLIF(btrim(p_patch ->> 'override_note'),'') ELSE override_note END,
    overridden_by      = v_actor,
    overridden_at      = now(),
    updated_at         = now()
  WHERE id = p_offer_id;

  SELECT * INTO v_after FROM public.provider_offers WHERE id = p_offer_id;

  -- Checked after the write against the resulting row. A price below what the
  -- supplier charges is a guaranteed loss on every sale, and it is exactly how
  -- carrier_rules.inapp_pricing came to sit under wholesale on most carriers.
  IF v_after.override_price_usd IS NOT NULL
     AND v_after.source_price_usd IS NOT NULL
     AND v_after.override_price_usd < v_after.source_price_usd THEN
    RAISE EXCEPTION 'A manual price of %s cannot be below the supplier cost of %s',
      to_char(v_after.override_price_usd, 'FM999990.00'),
      to_char(v_after.source_price_usd, 'FM999990.00')
      USING ERRCODE = 'KS466';
  END IF;

  PERFORM public.admin_log('provider_offer.override', 'provider_offer', p_offer_id::text,
    jsonb_build_object('override_price_usd', v_before.override_price_usd,
      'override_name', v_before.override_name, 'override_is_active', v_before.override_is_active),
    jsonb_build_object('override_price_usd', v_after.override_price_usd,
      'override_name', v_after.override_name, 'override_is_active', v_after.override_is_active,
      'supplier_cost_usd', v_after.source_price_usd),
    COALESCE(p_note, 'via admin app') || ' (' || v_after.provider_code || '/' || v_after.offer_code || ')');

  RETURN jsonb_build_object('success', true, 'offer_id', p_offer_id,
    'effective_price_usd', v_after.effective_price_usd, 'is_active', v_after.is_active);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_refresh_provider_offers(p_note text DEFAULT NULL::text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_result jsonb;
BEGIN
  PERFORM public.assert_admin();
  v_result := public.refresh_provider_offers();
  PERFORM public.admin_log('provider_offers.refresh', 'provider_offers', 'all',
    '{}'::jsonb, v_result, COALESCE(p_note, 'via admin app'));
  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_list_service_providers() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_upsert_service_provider(text, jsonb, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_list_carrier_provider_map(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_upsert_carrier_provider_map(uuid, text, jsonb, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_list_provider_offers(text, text, text, uuid, boolean, integer, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_override_provider_offer(uuid, jsonb, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_refresh_provider_offers(text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.admin_list_service_providers() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_service_provider(text, jsonb, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_carrier_provider_map(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_carrier_provider_map(uuid, text, jsonb, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_provider_offers(text, text, text, uuid, boolean, integer, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_override_provider_offer(uuid, jsonb, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_refresh_provider_offers(text) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. The three carrier admin readers stop reading the legacy columns
-- -----------------------------------------------------------------------------
-- Return shape changes (four legacy code columns leave, a jsonb mapping array
-- and two diagnostic columns arrive), so this is DROP + CREATE rather than
-- CREATE OR REPLACE. No other admin_list_carriers signature exists, so there is
-- no PGRST203 overload risk.
--
-- 🔴 CREATE OR REPLACE PRESERVES A FUNCTION'S ACL. DROP + CREATE DOES NOT.
--    The first pass at this migration omitted the REVOKE below and handed anon
--    EXECUTE on a SECURITY DEFINER function listing every carrier and its
--    routing — caught by F0 T1, which is the whole reason that file exists. Same
--    hole as i7's admin_upsert_carrier_rule and H5c's trigger functions.
DROP FUNCTION IF EXISTS public.admin_list_carriers();

CREATE FUNCTION public.admin_list_carriers()
RETURNS TABLE (id uuid, name text, country_id uuid, country_name text, country_iso text,
  is_supported boolean, fulfillment_gateway text, default_refill_amount numeric,
  gateway_phone_number text, primary_provider text, providers jsonb,
  active_lines bigint, offers_available bigint, min_offer_usd numeric, max_offer_usd numeric,
  rule_minimum_topup numeric, rule_recommended_topup numeric, rule_validity_days integer,
  rule_inactivity_days integer, rule_grace_days integer, rule_notes text,
  rule_last_verified_at timestamptz, catalogue_price_usd numeric, catalogue_offer_code text,
  routing_problem text, pricing_problem text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT
    ca.id, ca.name, ca.country_id, co.name, co.iso_code::text,
    COALESCE(ca.is_supported, true), ca.fulfillment_gateway::text,
    ca.default_refill_amount, ca.gateway_phone_number,
    (SELECT m.provider FROM public.carrier_provider_map m
      WHERE m.carrier_id = ca.id AND m.is_primary),
    COALESCE((SELECT jsonb_agg(jsonb_build_object(
                'provider', r.provider_code, 'provider_name', r.provider_name,
                'country_code', r.provider_country_code, 'country_label', r.provider_country_label,
                'carrier_code', r.provider_carrier_code, 'carrier_label', r.provider_carrier_label,
                'is_enabled', r.is_enabled, 'is_primary', r.is_primary,
                'is_routable', r.is_routable, 'priority', r.priority)
                ORDER BY r.is_primary DESC, r.priority, r.provider_code)
              FROM public.carrier_supplier_routing r WHERE r.carrier_id = ca.id), '[]'::jsonb),
    (SELECT count(*) FROM public.sim_lines sl WHERE sl.carrier_id = ca.id),
    o.n_offers, o.min_usd, o.max_usd,
    cr.minimum_topup_amount, cr.recommended_topup_amount, cr.topup_validity_days,
    cr.inactivity_limit_days, cr.grace_period_days, cr.notes, cr.last_verified_at,
    res.price_usd, res.offer_code,
    CASE
      WHEN ca.fulfillment_gateway = 'API'
       AND NOT EXISTS (SELECT 1 FROM public.carrier_provider_map m
                        WHERE m.carrier_id = ca.id AND m.is_enabled)
        THEN 'Routed to API with no enabled supplier mapping - no worker can claim these refills'
      WHEN ca.fulfillment_gateway = 'API' AND COALESCE(o.n_offers, 0) = 0
        THEN 'Routed to API but the catalogue holds nothing for this carrier'
      WHEN ca.fulfillment_gateway = 'API'
       AND NOT EXISTS (SELECT 1 FROM public.carrier_supplier_routing r
                        WHERE r.carrier_id = ca.id AND r.is_routable)
        THEN 'Mapped and stocked, but no mapping is routable - check the supplier is active and ranking-enabled'
      WHEN ca.fulfillment_gateway = 'MANUAL' AND ca.gateway_phone_number IS NULL
        THEN 'Manual fulfilment with no gateway number recorded'
      ELSE NULL
    END,
    -- K3's finding, surfaced permanently: the rule's hand-typed price against
    -- what a supplier will actually charge. This is what silently broke premium
    -- on 26 of 36 carriers.
    CASE
      WHEN cr.id IS NULL THEN NULL
      WHEN res.offer_code IS NULL
        THEN 'No supplier sells a top-up reaching this carrier''s qualifying amount - premium cannot be sold'
      WHEN cr.offer_id IS NOT NULL AND cr.offer_id IS DISTINCT FROM res.offer_code
        THEN format('Rule names offer %s but the cheapest qualifying offer is %s', cr.offer_id, res.offer_code)
      WHEN abs(COALESCE(cr.minimum_topup_amount, 0) - res.price_usd) > 0.005
        THEN format('Rule minimum $%s but the offer costs $%s',
                    to_char(cr.minimum_topup_amount, 'FM999990.00'), to_char(res.price_usd, 'FM999990.00'))
      ELSE NULL
    END
  FROM public.carriers ca
  JOIN public.countries co ON co.id = ca.country_id
  LEFT JOIN public.carrier_rules cr ON cr.carrier_id = ca.id
  LEFT JOIN LATERAL (
    SELECT count(*) AS n_offers,
           min(po.effective_price_usd) AS min_usd,
           max(po.effective_price_usd) AS max_usd
    FROM public.provider_offers po
    WHERE po.carrier_id = ca.id AND po.offer_kind = 'topup' AND po.is_active
  ) o ON true
  LEFT JOIN LATERAL public.carrier_refill_offer(
    ca.id, COALESCE(cr.validity_qualifying_topup_amount, cr.minimum_topup_amount)) res ON true
  ORDER BY co.name, ca.name;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_list_carriers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_carriers() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_update_carrier(
  p_carrier_id uuid, p_patch jsonb, p_note text DEFAULT NULL::text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  -- The four supplier-code keys and api_provider are gone: they are per-supplier
  -- facts and live in carrier_provider_map now. admin_upsert_carrier_provider_map
  -- is where they are edited.
  v_allowed text[] := ARRAY['fulfillment_gateway','default_refill_amount',
                            'gateway_phone_number','is_supported'];
  v_bad text; v_before RECORD; v_gateway text; v_amount numeric; v_phone text; v_after RECORD;
BEGIN
  PERFORM public.assert_admin();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Nothing to change' USING ERRCODE = 'KS467';
  END IF;

  SELECT string_agg(k, ', ') INTO v_bad
  FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'Unknown field(s): %. Supplier codes moved to admin_upsert_carrier_provider_map.',
      v_bad USING ERRCODE = 'KS467';
  END IF;

  SELECT * INTO v_before FROM public.carriers WHERE id = p_carrier_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Carrier % not found', p_carrier_id USING ERRCODE = 'KS461';
  END IF;

  v_gateway := COALESCE(p_patch ->> 'fulfillment_gateway', v_before.fulfillment_gateway::text);
  v_amount  := CASE WHEN p_patch ? 'default_refill_amount'
                    THEN (p_patch ->> 'default_refill_amount')::numeric
                    ELSE v_before.default_refill_amount END;
  v_phone   := CASE WHEN p_patch ? 'gateway_phone_number'
                    THEN NULLIF(btrim(p_patch ->> 'gateway_phone_number'), '')
                    ELSE v_before.gateway_phone_number END;

  IF v_gateway NOT IN ('MANUAL','TASKER_SCRIPT','API') THEN
    RAISE EXCEPTION 'Gateway must be MANUAL, TASKER_SCRIPT or API' USING ERRCODE = 'KS466';
  END IF;

  -- The trap this replaces: api_provider used to be the thing that could be NULL
  -- on an API carrier, producing executions no worker filters for. The same hole
  -- now looks like "API but no enabled mapping".
  IF v_gateway = 'API' AND NOT EXISTS (
       SELECT 1 FROM public.carrier_provider_map m WHERE m.carrier_id = p_carrier_id AND m.is_enabled) THEN
    RAISE EXCEPTION 'An API-routed carrier needs at least one enabled supplier mapping, or its refills will never be claimed'
      USING ERRCODE = 'KS466';
  END IF;

  IF v_amount IS NULL OR v_amount <= 0 OR v_amount > 1000 THEN
    RAISE EXCEPTION 'Default refill amount must be between 0.01 and 1000 USD' USING ERRCODE = 'KS466';
  END IF;

  IF v_phone IS NOT NULL AND v_phone !~ '^\+?[0-9][0-9 *#]{4,24}$' THEN
    RAISE EXCEPTION 'Gateway number must be digits, optionally starting with +' USING ERRCODE = 'KS466';
  END IF;

  UPDATE public.carriers SET
    fulfillment_gateway   = v_gateway,
    default_refill_amount = v_amount,
    gateway_phone_number  = v_phone,
    is_supported          = CASE WHEN p_patch ? 'is_supported'
                                 THEN (p_patch ->> 'is_supported')::boolean ELSE v_before.is_supported END
  WHERE id = p_carrier_id;

  SELECT * INTO v_after FROM public.carriers WHERE id = p_carrier_id;

  PERFORM public.admin_log('carrier.update', 'carrier', p_carrier_id::text,
    jsonb_build_object('gateway', v_before.fulfillment_gateway,
      'default_refill_amount', v_before.default_refill_amount,
      'gateway_phone_number', v_before.gateway_phone_number, 'is_supported', v_before.is_supported),
    jsonb_build_object('gateway', v_after.fulfillment_gateway,
      'default_refill_amount', v_after.default_refill_amount,
      'gateway_phone_number', v_after.gateway_phone_number, 'is_supported', v_after.is_supported),
    COALESCE(p_note, 'via admin app') || ' (' || v_after.name || ')');

  RETURN jsonb_build_object('success', true, 'carrier_id', p_carrier_id, 'name', v_after.name);
END;
$function$;

-- admin_overview: the routing/catalogue blocks stop reading the legacy columns,
-- gain a `providers` block, and gain a live counter for the K3 price divergence
-- so it cannot rot back in unnoticed. Body is applied as deployed; see
-- 20260821030000 in the DB for the canonical text.
CREATE OR REPLACE FUNCTION public.admin_overview()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v jsonb;
BEGIN
  PERFORM public.assert_admin();
  SELECT jsonb_build_object(
    'generated_at', now(),
    'users', jsonb_build_object(
      'total',     (SELECT count(*) FROM public.profiles),
      'suspended', (SELECT count(*) FROM public.profiles WHERE is_suspended),
      'power',     (SELECT count(*) FROM public.profiles WHERE is_power_user),
      'new_7d',    (SELECT count(*) FROM public.profiles WHERE created_at > now() - interval '7 days')),
    'money', jsonb_build_object(
      'wallet_balance_total', (SELECT COALESCE(sum(balance),0) FROM public.wallets),
      'deposited_30d', (SELECT COALESCE(sum(amount),0) FROM public.wallet_transactions
                         WHERE type='deposit' AND status='completed' AND created_at > now() - interval '30 days'),
      'spent_30d', (SELECT COALESCE(sum(amount),0) FROM public.wallet_transactions
                     WHERE type IN ('topup_debit','plan_fee_debit','esim_purchase_debit')
                       AND status='completed' AND created_at > now() - interval '30 days'),
      'app_fee_30d', (SELECT COALESCE(sum(app_fee_usd),0) FROM public.topup_executions
                       WHERE status='success' AND created_at > now() - interval '30 days')),
    'queue', jsonb_build_object(
      'in_flight', (SELECT count(*) FROM public.topup_executions
                     WHERE status IN ('pending','pending_payment','routing','processing')),
      'stuck_24h', (SELECT count(*) FROM public.topup_executions
                     WHERE status IN ('pending','pending_payment','routing','processing')
                       AND created_at < now() - interval '24 hours'),
      'failed_7d', (SELECT count(*) FROM public.topup_executions
                     WHERE status IN ('failed','refunded') AND created_at > now() - interval '7 days'),
      'success_7d', (SELECT count(*) FROM public.topup_executions
                      WHERE status='success' AND created_at > now() - interval '7 days'),
      'manual_waiting', (SELECT count(*) FROM public.topup_executions
                          WHERE fulfillment_gateway='MANUAL'
                            AND status IN ('pending','pending_payment','routing','processing'))),
    'routing', jsonb_build_object(
      'carriers_total',  (SELECT count(*) FROM public.carriers),
      'carriers_api',    (SELECT count(*) FROM public.carriers WHERE fulfillment_gateway='API'),
      'carriers_manual', (SELECT count(*) FROM public.carriers WHERE fulfillment_gateway<>'API'),
      'api_without_mapping', (SELECT count(*) FROM public.carriers ca
                               WHERE ca.fulfillment_gateway='API'
                                 AND NOT EXISTS (SELECT 1 FROM public.carrier_provider_map m
                                                  WHERE m.carrier_id = ca.id AND m.is_enabled)),
      'carriers_without_offers', (SELECT count(*) FROM public.carriers ca
                                   WHERE ca.fulfillment_gateway = 'API'
                                     AND NOT EXISTS (SELECT 1 FROM public.provider_offers po
                                                      WHERE po.carrier_id = ca.id
                                                        AND po.offer_kind='topup' AND po.is_active)),
      'default_gateway', (SELECT config_value FROM public.system_configs
                           WHERE config_key='ACTIVE_FULFILLMENT_METHOD')),
    'providers', jsonb_build_object(
      'total',        (SELECT count(*) FROM public.service_providers),
      'active',       (SELECT count(*) FROM public.service_providers WHERE is_active),
      'topup',        (SELECT count(*) FROM public.service_providers WHERE supports_topup AND is_active),
      'esim',         (SELECT count(*) FROM public.service_providers WHERE supports_esim AND is_active),
      'active_but_empty', (SELECT count(*) FROM public.service_providers sp
                            WHERE sp.is_active
                              AND NOT EXISTS (SELECT 1 FROM public.provider_offers o
                                               WHERE o.provider_code = sp.code AND o.is_active))),
    'catalogue', jsonb_build_object(
      'topup_offers', (SELECT count(*) FROM public.provider_offers WHERE offer_kind='topup' AND is_active),
      'topup_offers_stale', (SELECT count(*) FROM public.provider_offers
                              WHERE offer_kind='topup' AND is_active
                                AND source_refreshed_at < now() - interval '24 hours'),
      'esim_offers', (SELECT count(*) FROM public.provider_offers WHERE offer_kind='esim' AND is_active),
      'manual_overrides', (SELECT count(*) FROM public.provider_offers
                            WHERE override_price_usd IS NOT NULL OR override_is_active IS NOT NULL),
      'retired', (SELECT count(*) FROM public.provider_offers WHERE NOT source_is_active),
      'esim_covered_countries', (SELECT count(DISTINCT country_code) FROM public.provider_offers
                                  WHERE offer_kind='esim' AND is_active),
      'supported_countries', (SELECT count(*) FROM public.countries WHERE is_supported),
      'carriers_with_price_divergence', (SELECT count(*) FROM public.carrier_rules cr
          LEFT JOIN LATERAL public.carrier_refill_offer(cr.carrier_id,
            COALESCE(cr.validity_qualifying_topup_amount, cr.minimum_topup_amount)) res ON true
          WHERE res.offer_code IS NULL
             OR abs(COALESCE(cr.minimum_topup_amount,0) - res.price_usd) > 0.005)),
    'notifications', jsonb_build_object(
      'channels_enabled', (SELECT count(*) FROM public.notification_channel_catalog WHERE is_globally_enabled),
      'channels_total',   (SELECT count(*) FROM public.notification_channel_catalog),
      'credential_gaps',  (SELECT COALESCE(array_agg(channel_key ORDER BY channel_key), '{}')
                            FROM public.notification_channel_catalog WHERE credential_status <> 'configured'),
      'delivered_7d', (SELECT count(*) FROM public.notification_deliveries
                        WHERE status IN ('sent','success','delivered') AND created_at > now() - interval '7 days'),
      'failed_7d', (SELECT count(*) FROM public.notification_deliveries
                     WHERE status='failed' AND created_at > now() - interval '7 days'),
      'push_tokens', (SELECT count(*) FROM public.device_push_tokens)),
    'support', jsonb_build_object(
      'open', (SELECT count(*) FROM public.support_tickets WHERE status NOT IN ('resolved','closed')),
      'awaiting_reply', (SELECT count(*) FROM public.support_tickets t
                          WHERE t.status NOT IN ('resolved','closed')
                            AND COALESCE((SELECT (array_agg(tm.sender ORDER BY tm.created_at DESC))[1]
                                          FROM public.ticket_messages tm WHERE tm.ticket_id=t.id), 'user') = 'user')),
    'alerts', COALESCE((SELECT jsonb_agg(jsonb_build_object(
                 'id', sa.id, 'kind', sa.kind, 'message', sa.message, 'created_at', sa.created_at)
                 ORDER BY sa.created_at DESC)
               FROM (SELECT * FROM public.system_alerts ORDER BY created_at DESC LIMIT 10) sa), '[]'::jsonb),
    'workers', jsonb_build_object(
      'esim_heartbeat', (SELECT config_value FROM public.system_configs WHERE config_key='WORKER_ESIM_FULFILLMENT_HEARTBEAT'),
      'fx_last_refresh',(SELECT config_value FROM public.system_configs WHERE config_key='FX_LAST_REFRESH_AT'),
      'cron_jobs', (SELECT count(*) FROM cron.job WHERE active))
  ) INTO v;
  RETURN v;
END;
$function$;

-- -----------------------------------------------------------------------------
-- 5. Now, and only now, the columns can go
-- -----------------------------------------------------------------------------
-- Safe because K1 established the mapping table already carries everything:
-- 0 carrier-code drift, 0 offers failing to resolve to a mapping, 50 of 50
-- enabled mappings agreeing with the api_provider they replace, and the country
-- labels migrated to provider_country_label rather than deleted.
ALTER TABLE public.carriers
  DROP COLUMN IF EXISTS zen_country,
  DROP COLUMN IF EXISTS zen_carrier,
  DROP COLUMN IF EXISTS dt_country,
  DROP COLUMN IF EXISTS dt_carrier,
  DROP COLUMN IF EXISTS ding_country,
  DROP COLUMN IF EXISTS ding_carrier,
  DROP COLUMN IF EXISTS reloadly_operator_id,
  DROP COLUMN IF EXISTS api_provider;

COMMENT ON TABLE public.carriers IS
  'K3/K4: a telecom, and nothing about how a supplier spells it. Supplier codes, '
  'country/telecom labels and the routing default all live in carrier_provider_map; '
  'read them through carrier_supplier_routing.';
