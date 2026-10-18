-- =============================================================================
-- K9 · Convert supplier prices to USD, and record HOW
-- =============================================================================
-- Three of the four top-up suppliers settle in OMR, not USD. Both proven
-- against live payloads rather than assumed:
--   DTOne  — all 16,172 rows of its product export carry SOURCE CURRENCY = OMR
--   Ding   — `"SendValue":0.18,"SendCurrencyIso":"OMR"` for a PKR 100 top-up
--   Zendit — the only one quoting USD
--
-- Both adapters stored the native figure in a column named `*_usd`. Ding's
-- PKR 100 top-up costs OMR 0.18 = **$0.47** and was cached as **$0.18** — a 2.6x
-- understatement, and a guaranteed loss on every sale. It is invisible precisely
-- because $0.18 looks like a plausible price for a top-up.
--
-- CONVERTING IS NOT ENOUGH ON ITS OWN. A conversion nobody can trace is the same
-- class of problem as the fabricated DTOne catalogue: a number with no
-- provenance. So every converted row now carries what it was and which rate was
-- applied —
--
--   source_currency        'OMR'       what the supplier actually quoted
--   source_amount_native   0.1800      before any conversion
--   fx_usd_to_local        0.38450000  the exact fx_rates value used
--   fx_rate_as_of          timestamp   how old that rate was at ingest
--
-- With those four, price_fixed_usd is reproducible from first principles months
-- later. Without them it is an assertion. NULL source_currency means the
-- supplier quoted USD and nothing was converted — which keeps every pre-K9
-- Zendit row correct and untouched.
-- =============================================================================

ALTER TABLE public.provider_offers_cache
  ADD COLUMN IF NOT EXISTS source_currency      text,
  ADD COLUMN IF NOT EXISTS source_amount_native numeric(14,4),
  ADD COLUMN IF NOT EXISTS fx_usd_to_local      numeric(18,8),
  ADD COLUMN IF NOT EXISTS fx_rate_as_of        timestamptz;

COMMENT ON COLUMN public.provider_offers_cache.source_currency IS
  'The currency the SUPPLIER quoted. NULL means it quoted USD and no conversion '
  'happened. Non-NULL means price_*_usd is converted and the fx columns say how.';
COMMENT ON COLUMN public.provider_offers_cache.fx_usd_to_local IS
  'The fx_rates.usd_to_local applied at ingest. usd = native / usd_to_local. '
  'Stored rather than re-looked-up, because the rate moves and the price does not.';

ALTER TABLE public.provider_offers
  ADD COLUMN IF NOT EXISTS source_currency      text,
  ADD COLUMN IF NOT EXISTS source_amount_native numeric(14,4),
  ADD COLUMN IF NOT EXISTS fx_usd_to_local      numeric(18,8);

-- -----------------------------------------------------------------------------
-- The rates the cache is ALLOWED to convert with
-- -----------------------------------------------------------------------------
-- A rate that merely EXISTS is not enough. G11 established that rendering a
-- stale rate as today's is worse than having no feature at all; that applies
-- doubly here, because this rate decides what we pay a supplier.
--
-- Pegs age in DAYS, floating rates in HOURS. The Omani rial has been fixed at
-- 2.6008 USD since 1986 — expiring it after FX_MAX_AGE_HOURS (72) would take
-- DTOne and Ding offline every three days for a number that cannot drift.
--
-- The base currency never expires: USD's row exists so joins resolve, not
-- because a rate needs refreshing. The first cut of this view applied the age
-- check uniformly and duly reported USD as unusable — latent (adapters mark USD
-- as needing no conversion) but it would have made any future caller skip every
-- Zendit offer.
CREATE OR REPLACE VIEW public.fx_rates_for_costing AS
SELECT
  f.currency_code, f.usd_to_local, f.rate_source, f.rate_as_of,
  (f.rate_source = 'peg') AS is_peg,
  CASE
    WHEN f.rate_source = 'base' OR f.currency_code = 'USD' THEN NULL
    WHEN f.usd_to_local IS NULL OR f.usd_to_local <= 0 THEN 'rate is missing or non-positive'
    WHEN f.rate_source = 'peg'
     AND f.rate_as_of < now() - make_interval(days =>
           COALESCE((SELECT NULLIF(config_value,'')::int FROM public.system_configs
                      WHERE config_key = 'FX_PEG_MAX_AGE_DAYS'), 90))
      THEN 'pegged rate has not been reviewed in months'
    WHEN f.rate_source <> 'peg'
     AND f.rate_as_of < now() - make_interval(hours =>
           COALESCE((SELECT NULLIF(config_value,'')::int FROM public.system_configs
                      WHERE config_key = 'FX_MAX_AGE_HOURS'), 72))
      THEN 'rate is older than FX_MAX_AGE_HOURS'
    ELSE NULL
  END AS unusable_reason
FROM public.fx_rates f;

COMMENT ON VIEW public.fx_rates_for_costing IS
  'K9: rates the offer cache may convert supplier prices with. unusable_reason '
  'NULL means safe to use. worker_offers_cache excludes anything flagged, so '
  'offerCacheRow() throws rather than pricing off a bad number.';

ALTER VIEW public.fx_rates_for_costing SET (security_invoker = on);
REVOKE ALL ON public.fx_rates_for_costing FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.fx_rates_for_costing TO service_role;

INSERT INTO public.system_configs (config_key, config_value)
VALUES ('FX_PEG_MAX_AGE_DAYS', '90')
ON CONFLICT (config_key) DO NOTHING;

-- J6: a system_configs key with no system_config_meta row is UNSETTABLE (KS466).
-- Shipping the value without the metadata ships a dead knob.
INSERT INTO public.system_config_meta
  (config_key, label, group_name, value_type, min_value, max_value, unit, description,
   is_sensitive, is_readonly, sort_order)
VALUES
  ('FX_PEG_MAX_AGE_DAYS', 'Pegged FX rate max age', 'Pricing', 'int', 1, 3650, 'days',
   'How long a rate_source=peg FX rate stays usable for converting supplier costs. Pegs do not drift, so they are exempt from the hours-based FX_MAX_AGE_HOURS check — ageing the Omani rial peg out after 72h would take DTOne and Ding offline for a rate that has not moved since 1986.',
   false, false, 620)
ON CONFLICT (config_key) DO NOTHING;

-- -----------------------------------------------------------------------------
-- refresh_provider_offers() carries the provenance into the curated shelf
-- -----------------------------------------------------------------------------
-- Body is otherwise unchanged from K2; only the three provenance columns are
-- added to the top-up INSERT and its ON CONFLICT update. See the deployed
-- definition for the canonical text.
-- (Applied in full at 20260821080000 — reproduced here for a clean replay.)
CREATE OR REPLACE FUNCTION public.refresh_provider_offers()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_topup integer := 0; v_esim integer := 0; v_retired integer := 0;
  v_src_top integer; v_src_esim integer;
BEGIN
  SELECT count(*) INTO v_src_top  FROM public.provider_offers_cache;
  SELECT count(*) INTO v_src_esim FROM public.esim_offers_cache WHERE is_active;

  IF v_src_top = 0 AND v_src_esim = 0 THEN
    RETURN jsonb_build_object('status', 'skipped',
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
      updated_at = now();
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
      updated_at = now();
    GET DIAGNOSTICS v_esim = ROW_COUNT;
  END IF;

  UPDATE public.provider_offers o
     SET source_is_active = false, updated_at = now()
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

  RETURN jsonb_build_object('status','ok','topup_upserted',v_topup,'esim_upserted',v_esim,
    'retired',v_retired,'source_topup',v_src_top,'source_esim',v_src_esim,'refreshed_at',now());
END;
$function$;
