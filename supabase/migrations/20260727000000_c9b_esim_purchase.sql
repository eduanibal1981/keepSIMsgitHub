-- Migration: 20260727000000_c9b_esim_purchase.sql
-- Description: C9b eSIM purchase pipeline, user eSIM management, wallet debit ledger type, and security definer purchase RPC.

-- 1. Create esim_orders table
CREATE TABLE IF NOT EXISTS public.esim_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL DEFAULT 'esim_go',
  bundle_name TEXT NOT NULL,
  quantity INT NOT NULL DEFAULT 1 CHECK (quantity >= 1 AND quantity <= 3),
  wholesale_price_usd NUMERIC(10,4) NOT NULL,
  retail_price_usd NUMERIC(10,2) NOT NULL,
  markup_percent NUMERIC(5,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' 
    CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'refunded')),
  provider_order_ref TEXT,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS on esim_orders
ALTER TABLE public.esim_orders ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to prevent conflicts
DROP POLICY IF EXISTS "Users can read own esim orders" ON public.esim_orders;

-- Grant SELECT only to authenticated users for their own orders (NO direct client INSERT/UPDATE/DELETE)
CREATE POLICY "Users can read own esim orders"
  ON public.esim_orders FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

GRANT SELECT ON public.esim_orders TO authenticated;
-- Do NOT grant INSERT, UPDATE, or DELETE on esim_orders to authenticated or anon.


-- 2. Create user_esims table
CREATE TABLE IF NOT EXISTS public.user_esims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES public.esim_orders(id) ON DELETE CASCADE,
  iccid TEXT NOT NULL UNIQUE,
  smdp_address TEXT NOT NULL,
  matching_id TEXT NOT NULL,
  lpa_string TEXT NOT NULL,
  bundle_name TEXT NOT NULL,
  provider TEXT NOT NULL DEFAULT 'esim_go',
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'expired', 'depleted', 'installed')),
  purchased_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  data_total_mb BIGINT NOT NULL,
  data_remaining_mb BIGINT NOT NULL,
  last_usage_check TIMESTAMPTZ,
  low_data_notified BOOLEAN NOT NULL DEFAULT FALSE
);

-- Enable RLS on user_esims
ALTER TABLE public.user_esims ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can read own user esims" ON public.user_esims;

-- Grant SELECT only to authenticated users for their own eSIMs
CREATE POLICY "Users can read own user esims"
  ON public.user_esims FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

GRANT SELECT ON public.user_esims TO authenticated;
-- Do NOT grant INSERT, UPDATE, or DELETE on user_esims to authenticated or anon.


-- 3. Extend wallet_transactions_type_check to include 'esim_purchase_debit'
ALTER TABLE public.wallet_transactions 
  DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;

ALTER TABLE public.wallet_transactions 
  ADD CONSTRAINT wallet_transactions_type_check 
  CHECK (type IN (
    'deposit', 
    'topup_debit', 
    'refund', 
    'referral_credit', 
    'welcome_home_debit', 
    'auto_fund', 
    'plan_fee_debit',
    'esim_purchase_debit'
  ));

-- Add partial unique index for idempotent eSIM purchase debits
CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_txns_esim_debit 
  ON public.wallet_transactions(reference_id) 
  WHERE (type = 'esim_purchase_debit');


-- 4. Seed system_configs for low data threshold percent
INSERT INTO public.system_configs (config_key, config_value)
VALUES ('ESIM_LOW_DATA_THRESHOLD_PERCENT', '20')
ON CONFLICT (config_key) DO UPDATE 
SET config_value = EXCLUDED.config_value;


-- 5. Create request_esim_purchase RPC function
CREATE OR REPLACE FUNCTION public.request_esim_purchase(
  p_offer_id TEXT,
  p_quantity INT DEFAULT 1
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_wallet_id UUID;
  v_provider TEXT;
  v_bundle_name TEXT;
  v_offer RECORD;
  v_markup_str TEXT;
  v_markup NUMERIC(5,2);
  v_retail_unit NUMERIC(10,2);
  v_total_cost NUMERIC(10,2);
  v_wallet_balance NUMERIC(10,2);
  v_order_id UUID;
  v_reference_id TEXT;
  v_existing_txn RECORD;
BEGIN
  -- 1. Verify caller authentication
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: User must be authenticated to purchase an eSIM.';
  END IF;

  -- 2. Validate quantity (cap <= 3)
  IF p_quantity IS NULL OR p_quantity < 1 OR p_quantity > 3 THEN
    RAISE EXCEPTION 'INVALID_QUANTITY: Quantity must be between 1 and 3.';
  END IF;

  -- 3. Fetch offer from esim_offers_cache matching (provider || '_' || bundle_name) OR (bundle_name = p_offer_id)
  SELECT * INTO v_offer
  FROM public.esim_offers_cache
  WHERE (provider || '_' || bundle_name = p_offer_id)
     OR (bundle_name = p_offer_id)
  ORDER BY is_active DESC, updated_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'OFFER_NOT_FOUND: Offer % is unknown or invalid.', p_offer_id;
  END IF;

  IF v_offer.is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'OFFER_INACTIVE: Offer % is currently unavailable.', p_offer_id;
  END IF;

  -- Fail-safe: Reject offers with cache older than 24 hours
  IF v_offer.updated_at < (NOW() - INTERVAL '24 hours') THEN
    RAISE EXCEPTION 'STALE_CATALOG_CACHE: Offer catalog is stale (>24h old). Purchase halted for safety.';
  END IF;

  v_provider := v_offer.provider;
  v_bundle_name := v_offer.bundle_name;

  -- 4. Calculate markup and retail price
  SELECT config_value INTO v_markup_str
  FROM public.system_configs
  WHERE config_key = 'ESIM_MARKUP_PERCENT';

  IF v_markup_str IS NULL THEN
    v_markup := 30.00;
  ELSE
    v_markup := v_markup_str::NUMERIC;
  END IF;

  v_retail_unit := round(v_offer.wholesale_price_usd * (1.00 + v_markup / 100.00), 2);
  v_total_cost := v_retail_unit * p_quantity;

  -- 5. Check user wallet balance
  SELECT id, balance INTO v_wallet_id, v_wallet_balance
  FROM public.wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: User wallet does not exist.';
  END IF;

  IF v_wallet_balance < v_total_cost THEN
    RAISE EXCEPTION 'INSUFFICIENT_WALLET_BALANCE: Required $%, Available $%.', v_total_cost, v_wallet_balance;
  END IF;

  -- 6. Insert pending order
  INSERT INTO public.esim_orders (
    user_id,
    provider,
    bundle_name,
    quantity,
    wholesale_price_usd,
    retail_price_usd,
    markup_percent,
    status
  ) VALUES (
    v_user_id,
    v_provider,
    v_bundle_name,
    p_quantity,
    v_offer.wholesale_price_usd,
    v_retail_unit,
    v_markup,
    'pending'
  ) RETURNING id INTO v_order_id;

  -- 7. Debit user wallet idempotently using reference esim_<order_id>
  v_reference_id := 'esim_' || v_order_id::TEXT;

  -- Check if debit already performed (adopt-on-retry)
  SELECT * INTO v_existing_txn
  FROM public.wallet_transactions
  WHERE reference_id = v_reference_id AND type = 'esim_purchase_debit';

  IF NOT FOUND THEN
    UPDATE public.wallets
    SET balance = balance - v_total_cost,
        updated_at = NOW()
    WHERE id = v_wallet_id;

    INSERT INTO public.wallet_transactions (
      user_id,
      wallet_id,
      amount,
      balance_before,
      balance_after,
      type,
      reference_id,
      description
    ) VALUES (
      v_user_id,
      v_wallet_id,
      v_total_cost,
      v_wallet_balance,
      v_wallet_balance - v_total_cost,
      'esim_purchase_debit',
      v_reference_id,
      'eSIM purchase: ' || v_bundle_name || ' (x' || p_quantity::TEXT || ')'
    );
  END IF;

  RETURN v_order_id;
END;
$$;

-- Grant EXECUTE on request_esim_purchase to authenticated users only
REVOKE EXECUTE ON FUNCTION public.request_esim_purchase(TEXT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_esim_purchase(TEXT, INT) TO authenticated;
