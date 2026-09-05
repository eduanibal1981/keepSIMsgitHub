-- Add single-flight advisory lock guard to refresh_provider_offers()
CREATE OR REPLACE FUNCTION public.refresh_provider_offers()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_topup integer := 0; v_esim integer := 0; v_retired integer := 0;
  v_src_top integer; v_src_esim integer;
BEGIN
  -- Advisory xact lock: If another worker/session is already executing catalogue refresh,
  -- exit immediately instead of queuing and acquiring table locks.
  IF NOT pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtext('refresh_provider_offers')) THEN
    RETURN pg_catalog.jsonb_build_object(
      'status', 'skipped',
      'reason', 'Job already running in another session'
    );
  END IF;

  SELECT count(*) INTO v_src_top  FROM public.provider_offers_cache;
  SELECT count(*) INTO v_src_esim FROM public.esim_offers_cache WHERE is_active;

  IF v_src_top = 0 AND v_src_esim = 0 THEN
    RETURN pg_catalog.jsonb_build_object('status', 'skipped',
      'reason', 'both upstream caches are empty — refusing to retire the catalogue');
  END IF;

  IF v_src_top > 0 THEN
    INSERT INTO public.provider_offers AS po (
      provider_code, offer_kind, offer_code, country_code, carrier_id,
      source_name, source_price_type, source_price_usd,
      source_price_min_usd, source_price_max_usd,
      source_send_min, source_send_max, source_send_currency, source_send_divisor,
      source_is_active, source_refreshed_at,
      source_currency, source_amount_native, fx_usd_to_local)
    SELECT DISTINCT ON (p.api_provider, p.offer_id, p.country_code, m.carrier_id)
      p.api_provider, 'topup', p.offer_id, p.country_code, m.carrier_id,
      p.offer_name, p.price_type, COALESCE(p.price_fixed_usd, p.price_min_usd),
      p.price_min_usd, p.price_max_usd,
      p.send_min, p.send_max, p.send_currency, p.send_currency_divisor,
      true, p.refreshed_at,
      p.source_currency, p.source_amount_native, p.fx_usd_to_local
    FROM public.provider_offers_cache p
    JOIN public.carrier_provider_map m
      ON m.provider = p.api_provider
     AND m.provider_country_code = p.country_code
     AND m.provider_carrier_code = p.carrier_code
    JOIN public.countries co ON co.iso_code = p.country_code
    ORDER BY p.api_provider, p.offer_id, p.country_code, m.carrier_id,
             m.is_primary DESC, m.priority ASC
    ON CONFLICT (provider_code, offer_kind, offer_code, country_code,
                 COALESCE(carrier_id, '00000000-0000-0000-0000-000000000000'::uuid))
    DO UPDATE SET
      source_name = EXCLUDED.source_name, source_price_type = EXCLUDED.source_price_type,
      source_price_usd = EXCLUDED.source_price_usd,
      source_price_min_usd = EXCLUDED.source_price_min_usd,
      source_price_max_usd = EXCLUDED.source_price_max_usd,
      source_send_min = EXCLUDED.source_send_min, source_send_max = EXCLUDED.source_send_max,
      source_send_currency = EXCLUDED.source_send_currency,
      source_send_divisor = EXCLUDED.source_send_divisor,
      source_is_active = true, source_refreshed_at = EXCLUDED.source_refreshed_at,
      source_currency = EXCLUDED.source_currency,
      source_amount_native = EXCLUDED.source_amount_native,
      fx_usd_to_local = EXCLUDED.fx_usd_to_local,
      updated_at = pg_catalog.now();
    GET DIAGNOSTICS v_topup = ROW_COUNT;
  END IF;

  IF v_src_esim > 0 THEN
    INSERT INTO public.provider_offers AS po (
      provider_code, offer_kind, offer_code, country_code, carrier_id,
      source_name, source_price_type, source_price_usd,
      source_data_mb, source_duration_days, source_is_unlimited, source_speed_tier,
      source_is_active, source_refreshed_at)
    SELECT DISTINCT ON (e.provider, e.bundle_name, co.iso_code)
      e.provider, 'esim', e.bundle_name, co.iso_code, NULL::uuid,
      COALESCE(e.description, e.bundle_name), 'FIXED', e.wholesale_price_usd,
      CASE WHEN e.is_unlimited OR e.data_amount_mb <= 0 THEN NULL ELSE e.data_amount_mb END,
      NULLIF(e.duration_days, 0), e.is_unlimited, e.speed_tier,
      true, e.updated_at
    FROM public.esim_offers_cache e
    JOIN public.countries co
      ON co.iso_code = ANY (e.countries) OR co.iso_code = ANY (e.roaming_enabled)
    WHERE e.is_active
    ORDER BY e.provider, e.bundle_name, co.iso_code, e.updated_at DESC
    ON CONFLICT (provider_code, offer_kind, offer_code, country_code,
                 COALESCE(carrier_id, '00000000-0000-0000-0000-000000000000'::uuid))
    DO UPDATE SET
      source_name = EXCLUDED.source_name, source_price_usd = EXCLUDED.source_price_usd,
      source_data_mb = EXCLUDED.source_data_mb,
      source_duration_days = EXCLUDED.source_duration_days,
      source_is_unlimited = EXCLUDED.source_is_unlimited,
      source_speed_tier = EXCLUDED.source_speed_tier,
      source_is_active = true, source_refreshed_at = EXCLUDED.source_refreshed_at,
      updated_at = pg_catalog.now();
    GET DIAGNOSTICS v_esim = ROW_COUNT;
  END IF;

  UPDATE public.provider_offers o
     SET source_is_active = false, updated_at = pg_catalog.now()
   WHERE o.source_is_active
     AND ((o.offer_kind = 'topup' AND v_src_top > 0
           AND NOT EXISTS (
             SELECT 1 FROM public.provider_offers_cache p
              JOIN public.carrier_provider_map m
                ON m.provider = p.api_provider
               AND m.provider_country_code = p.country_code
               AND m.provider_carrier_code = p.carrier_code
              WHERE p.api_provider = o.provider_code AND p.offer_id = o.offer_code
                AND p.country_code = o.country_code AND m.carrier_id = o.carrier_id))
       OR (o.offer_kind = 'esim' AND v_src_esim > 0
           AND NOT EXISTS (
             SELECT 1 FROM public.esim_offers_cache e
              WHERE e.provider = o.provider_code AND e.bundle_name = o.offer_code
                AND e.is_active
                AND (o.country_code = ANY (e.countries) OR o.country_code = ANY (e.roaming_enabled)))));
  GET DIAGNOSTICS v_retired = ROW_COUNT;

  RETURN pg_catalog.jsonb_build_object(
    'status', 'ok',
    'topup_upserted', v_topup,
    'esim_upserted', v_esim,
    'retired', v_retired,
    'source_topup', v_src_top,
    'source_esim', v_src_esim,
    'refreshed_at', pg_catalog.now()
  );
END;
$function$;
