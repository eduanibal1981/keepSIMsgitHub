-- Migration: 20260721000000_provider_offers_cache_and_dtone.sql
-- Provider-aware top-up offers cache supporting both Zendit and DTone.

-- 1. Create provider_offers_cache table
CREATE TABLE IF NOT EXISTS public.provider_offers_cache (
  api_provider            text NOT NULL DEFAULT 'zendit',
  offer_id                text NOT NULL,
  country_code            text NOT NULL,          -- ISO-2, matches countries.iso_code
  carrier_code            text NOT NULL,          -- Brand/operator code: matches carriers.zen_carrier for zendit or carriers.dt_carrier for dtone
  offer_name              text,
  price_type              text NOT NULL CHECK (price_type IN ('FIXED', 'RANGE')),
  price_fixed_usd         numeric,                -- FIXED only
  price_min_usd           numeric,                -- RANGE only
  price_max_usd           numeric,
  send_min                numeric,                -- RANGE only: receiver-value bounds
  send_max                numeric,
  send_currency           text,
  send_currency_divisor   numeric DEFAULT 100,
  refreshed_at            timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (api_provider, offer_id),
  CONSTRAINT provider_offers_cache_fixed_priced CHECK (price_type <> 'FIXED' OR price_fixed_usd IS NOT NULL),
  CONSTRAINT provider_offers_cache_range_priced CHECK (price_type <> 'RANGE' OR (price_min_usd IS NOT NULL AND price_max_usd IS NOT NULL AND send_min IS NOT NULL AND send_max IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_provider_offers_cache_catalog 
  ON public.provider_offers_cache (api_provider, country_code, carrier_code);

-- 2. Migrate existing zendit_offers_cache data if existing
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
      AND table_name = 'zendit_offers_cache'
      AND table_type = 'BASE TABLE'
  ) THEN
    INSERT INTO public.provider_offers_cache (
      api_provider, offer_id, country_code, carrier_code, offer_name, price_type,
      price_fixed_usd, price_min_usd, price_max_usd, send_min, send_max,
      send_currency, send_currency_divisor, refreshed_at
    )
    SELECT 
      'zendit', offer_id, country_code, zen_carrier, offer_name, price_type,
      price_fixed_usd, price_min_usd, price_max_usd, send_min, send_max,
      send_currency, send_currency_divisor, refreshed_at
    FROM public.zendit_offers_cache
    ON CONFLICT (api_provider, offer_id) DO NOTHING;

    DROP TABLE public.zendit_offers_cache CASCADE;
  END IF;
END $$;

-- 3. Create backward-compatible zendit_offers_cache view
CREATE OR REPLACE VIEW public.zendit_offers_cache AS
SELECT 
  offer_id,
  country_code,
  carrier_code AS zen_carrier,
  offer_name,
  price_type,
  price_fixed_usd,
  price_min_usd,
  price_max_usd,
  send_min,
  send_max,
  send_currency,
  refreshed_at,
  send_currency_divisor
FROM public.provider_offers_cache
WHERE api_provider = 'zendit';

-- 4. Set RLS policies on provider_offers_cache
ALTER TABLE public.provider_offers_cache ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can read provider offers cache" ON public.provider_offers_cache;
CREATE POLICY "Authenticated can read provider offers cache" ON public.provider_offers_cache
  FOR SELECT TO authenticated USING (true);

REVOKE ALL ON public.provider_offers_cache FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.provider_offers_cache FROM authenticated;

-- 5. Update request_instant_refill RPC to handle provider routing dynamically
CREATE OR REPLACE FUNCTION public.request_instant_refill(
  p_sim_line_id uuid,
  p_offer_id text,
  p_payment_gateway_code text,
  p_amount_usd numeric DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_iso text;
  v_api_provider text;
  v_zen_carrier text;
  v_dt_carrier text;
  v_carrier_code text;
  v_offer RECORD;
  v_base numeric;
  v_value numeric;
  v_execution_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Line ownership check & provider carrier resolution
  SELECT co.iso_code, COALESCE(ca.api_provider, 'zendit'), ca.zen_carrier, ca.dt_carrier
  INTO v_iso, v_api_provider, v_zen_carrier, v_dt_carrier
  FROM public.sim_lines sl
  JOIN public.countries co ON co.id = sl.country_id
  JOIN public.carriers ca ON ca.id = sl.carrier_id
  WHERE sl.id = p_sim_line_id
    AND (sl.user_id = auth.uid()
         OR EXISTS (SELECT 1 FROM public.household_members hm
                    WHERE hm.owner_id = sl.user_id
                      AND hm.member_id = auth.uid()
                      AND hm.invite_status = 'accepted'
                      AND hm.role = 'manager'));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not authorized to refill this SIM line';
  END IF;

  v_carrier_code := CASE WHEN v_api_provider = 'dtone' THEN v_dt_carrier ELSE v_zen_carrier END;

  IF v_carrier_code IS NULL THEN
    RAISE EXCEPTION 'This carrier has no online top-up catalog for provider %', v_api_provider;
  END IF;

  -- Verify offer exists in the target provider's cache for this country & carrier
  SELECT * INTO v_offer
  FROM public.provider_offers_cache p
  WHERE p.api_provider = v_api_provider
    AND p.offer_id = p_offer_id
    AND p.country_code = v_iso
    AND p.carrier_code = v_carrier_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Offer % is not available for this SIM line', p_offer_id;
  END IF;

  -- 24-hour staleness refusal
  IF v_offer.refreshed_at < now() - interval '24 hours' THEN
    RAISE EXCEPTION 'Offer pricing is temporarily unavailable. Please try again later.';
  END IF;

  IF v_offer.price_type = 'FIXED' THEN
    v_base := v_offer.price_fixed_usd;
    v_value := NULL;
  ELSE
    IF p_amount_usd IS NULL THEN
      RAISE EXCEPTION 'This offer requires an amount';
    END IF;
    v_base := round(p_amount_usd, 2);
    IF v_base < v_offer.price_min_usd - 0.01 OR v_base > v_offer.price_max_usd + 0.01 THEN
      RAISE EXCEPTION 'Amount % is outside this offer''s %-% USD range',
        v_base, v_offer.price_min_usd, v_offer.price_max_usd;
    END IF;

    -- Interpolate send value based on price bounds
    v_value := least(v_offer.send_max, greatest(v_offer.send_min, round(
      v_offer.send_min
      + CASE WHEN v_offer.price_max_usd - v_offer.price_min_usd > 0
             THEN (v_base - v_offer.price_min_usd)
                  * (v_offer.send_max - v_offer.send_min)
                  / (v_offer.price_max_usd - v_offer.price_min_usd)
             ELSE 0 END)));
  END IF;

  IF v_base IS NULL OR v_base <= 0 THEN
    RAISE EXCEPTION 'Offer % has no usable price', p_offer_id;
  END IF;

  -- Insert topup execution (triggers will route, stamp fees, and set status)
  INSERT INTO public.topup_executions (
    sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code,
    currency, status, execution_type, execution_time, offer_id, offer_value,
    api_provider
  ) VALUES (
    p_sim_line_id, auth.uid(), v_base, v_base, p_payment_gateway_code,
    'USD', 'pending', 'refill_instant', now(), p_offer_id, v_value,
    v_api_provider
  )
  RETURNING id INTO v_execution_id;

  RETURN v_execution_id;
END;
$$;

REVOKE ALL ON FUNCTION public.request_instant_refill(uuid, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_instant_refill(uuid, text, text, numeric) TO authenticated;
