-- ============================================================================
-- 20260829000000_zendit_esim_integration.sql
-- Zendit eSIM Integration: Enable Zendit eSIM supplier, update constraints,
-- and support supplier-level markup override in pricing & purchase pipeline.
-- ============================================================================

BEGIN;

-- 1. Enable supports_esim on service_providers for zendit
UPDATE public.service_providers
SET supports_esim = true,
    updated_at = now()
WHERE code = 'zendit';

-- 2. Ensure zendit is registered and active in esim_suppliers
INSERT INTO public.esim_suppliers (
  code,
  name,
  website_url,
  api_base_url,
  docs_url,
  credential_secret,
  is_active,
  priority,
  notes
) VALUES (
  'zendit',
  'Zendit',
  'https://www.zendit.io',
  'https://api.zendit.io/v1',
  'https://docs.zendit.io',
  'ZENDIT_API_SECRET',
  true,
  20,
  'Zendit global eSIM provider offering high speed and unlimited roaming bundles.'
)
ON CONFLICT (code) DO UPDATE
SET is_active = true,
    website_url = EXCLUDED.website_url,
    api_base_url = EXCLUDED.api_base_url,
    docs_url = EXCLUDED.docs_url,
    credential_secret = EXCLUDED.credential_secret,
    updated_at = now();

-- 3. Expand speed_tier check constraint on esim_offers_cache
ALTER TABLE public.esim_offers_cache
  DROP CONSTRAINT IF EXISTS esim_offers_cache_speed_tier_check;

ALTER TABLE public.esim_offers_cache
  ADD CONSTRAINT esim_offers_cache_speed_tier_check
  CHECK (
    speed_tier IS NULL OR
    speed_tier IN (
      'fixed', 'lite', 'essential', 'plus', 'long_duration',
      'standard', 'fast', 'faster', 'fastest'
    )
  );

-- 4. Update esim_offers retail view to respect per-supplier markup override
CREATE OR REPLACE VIEW public.esim_offers AS
  SELECT (c.provider || '_'::text) || c.bundle_name AS id,
    c.provider,
    c.bundle_name,
    c.description,
    c.countries,
    c.roaming_enabled,
    c.data_amount_mb,
    c.duration_days,
    round(
      c.wholesale_price_usd * (1.0 + COALESCE(
        s.markup_percent_override,
        (SELECT NULLIF(system_configs.config_value::text, ''::text)::numeric
           FROM system_configs
          WHERE system_configs.config_key::text = 'ESIM_MARKUP_PERCENT'::text),
        30.0
      ) / 100.0),
      2
    )::numeric(10,2) AS retail_price_usd,
    c.image_url,
    c.is_active,
    c.updated_at,
    c.is_unlimited,
    c.bundle_group,
    c.speed_tier,
    c.region,
    c.country_count,
    CASE
      WHEN c.is_unlimited OR c.data_amount_mb <= 0 THEN NULL
      ELSE round(
        round(
          c.wholesale_price_usd * (1.0 + COALESCE(
            s.markup_percent_override,
            (SELECT NULLIF(system_configs.config_value::text, ''::text)::numeric
               FROM system_configs
              WHERE system_configs.config_key::text = 'ESIM_MARKUP_PERCENT'::text),
            30.0
          ) / 100.0),
          2
        ) / (c.data_amount_mb::numeric / 1024.0),
        2
      )
    END::numeric(10,2) AS price_per_gb_usd
  FROM public.esim_offers_cache c
  LEFT JOIN public.esim_suppliers s ON s.code = c.provider
  WHERE c.is_active = true;

-- 5. Update request_esim_purchase RPC to resolve per-supplier markup override and support multi-supplier matching
CREATE OR REPLACE FUNCTION public.request_esim_purchase(
  p_offer_id text,
  p_quantity integer DEFAULT 1,
  p_device_id text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_offer RECORD;
  v_supplier_markup numeric;
  v_markup_percent numeric := 30.0;
  v_retail_price numeric(10,2);
  v_total_cost numeric(10,2);
  v_wallet_balance numeric(10,2);
  v_order_id uuid;
  v_txn_ref text;
  v_guard jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is suspended. Purchases are disabled.');
  END IF;

  PERFORM public.enforce_rate_limit('esim_purchase', v_user_id::text);

  IF p_quantity IS NULL OR p_quantity < 1 OR p_quantity > 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Quantity must be between 1 and 3');
  END IF;

  SELECT * INTO v_offer
  FROM public.esim_offers_cache
  WHERE (bundle_name = p_offer_id OR (provider || '_' || bundle_name = p_offer_id))
    AND is_active = true
  ORDER BY updated_at DESC
  LIMIT 1;

  IF v_offer IS NULL OR v_offer.bundle_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'eSIM offer not found or inactive');
  END IF;

  -- Prioritize per-supplier markup override
  SELECT markup_percent_override INTO v_supplier_markup
  FROM public.esim_suppliers
  WHERE code = v_offer.provider;

  IF v_supplier_markup IS NOT NULL THEN
    v_markup_percent := v_supplier_markup;
  ELSE
    BEGIN
      SELECT config_value::numeric INTO v_markup_percent
      FROM public.system_configs WHERE config_key = 'ESIM_MARKUP_PERCENT';
    EXCEPTION WHEN OTHERS THEN v_markup_percent := 30.0; END;
  END IF;
  IF v_markup_percent IS NULL THEN v_markup_percent := 30.0; END IF;

  v_retail_price := round(v_offer.wholesale_price_usd * (1.0 + (v_markup_percent / 100.0)), 2);
  v_total_cost := v_retail_price * p_quantity;

  SELECT COALESCE(balance, 0.00) INTO v_wallet_balance
  FROM public.wallets WHERE user_id = v_user_id;

  IF v_wallet_balance < v_total_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INSUFFICIENT_FUNDS',
      'error', 'Insufficient wallet balance. Required: $' || v_total_cost::text || ', Available: $' || v_wallet_balance::text
    );
  END IF;

  v_guard := public.guard_money_action('esim_purchase', v_total_cost, p_device_id, NULL, v_user_id);
  IF (v_guard ->> 'blocked')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'DEVICE_BLOCKED',
      'reason', v_guard ->> 'reason',
      'error', 'This purchase was stopped by a security check on this device. Contact support if this is a mistake.'
    );
  END IF;

  INSERT INTO public.esim_orders (
    user_id, offer_id, bundle_name, provider, quantity, wholesale_price_usd, retail_price_usd, markup_percent, total_amount_usd, status
  ) VALUES (
    v_user_id, p_offer_id, v_offer.bundle_name, v_offer.provider, p_quantity, v_offer.wholesale_price_usd, v_retail_price, v_markup_percent, v_total_cost, 'pending'
  ) RETURNING id INTO v_order_id;

  v_txn_ref := 'esim_' || v_order_id::text;

  PERFORM public.debit_wallet_for_topup(
    p_user_id => v_user_id,
    p_sim_line_id => NULL,
    p_amount => v_total_cost,
    p_description => 'eSIM Purchase: ' || v_offer.bundle_name,
    p_reference_id => v_txn_ref,
    p_txn_type => 'esim_purchase_debit'
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'retail_price_usd', v_retail_price,
    'total_amount_usd', v_total_cost,
    'status', 'pending'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.request_esim_purchase(text, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_esim_purchase(text, integer, text) TO authenticated, service_role;

COMMIT;
