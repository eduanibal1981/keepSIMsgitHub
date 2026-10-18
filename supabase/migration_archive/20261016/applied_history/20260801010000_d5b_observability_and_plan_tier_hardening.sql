-- Migration 20260801010000_d5b_observability_and_plan_tier_hardening.sql
-- D5b: Plan Tier Lockdown, Stale eSIM Reaper Fix, and Schema Reconciliation

BEGIN;

-- ============================================================================
-- 1. Reconcile esim_orders Schema (Add offer_id and total_amount_usd)
-- ============================================================================

ALTER TABLE public.esim_orders
  ADD COLUMN IF NOT EXISTS offer_id text,
  ADD COLUMN IF NOT EXISTS total_amount_usd numeric(10,2);

-- ============================================================================
-- 2. Lock Down sim_lines plan_type and plan_expires_at
-- ============================================================================

-- Layer 1: Column-level REVOKE UPDATE from authenticated and anon
REVOKE UPDATE (plan_type, plan_expires_at) ON public.sim_lines FROM authenticated, anon;

-- Layer 2: BEFORE UPDATE trigger to prevent direct plan_type / plan_expires_at tampering
CREATE OR REPLACE FUNCTION public.trg_fn_prevent_sim_line_plan_tampering()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF (NEW.plan_type IS DISTINCT FROM OLD.plan_type OR NEW.plan_expires_at IS DISTINCT FROM OLD.plan_expires_at) THEN
    -- Block direct updates by authenticated or anon client roles
    IF auth.role() IN ('authenticated', 'anon') THEN
      RAISE EXCEPTION 'Direct modification of plan_type or plan_expires_at is forbidden.' USING ERRCODE = 'KS403';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_sim_line_plan_tampering ON public.sim_lines;
CREATE TRIGGER trg_prevent_sim_line_plan_tampering
  BEFORE UPDATE ON public.sim_lines
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_prevent_sim_line_plan_tampering();

REVOKE EXECUTE ON FUNCTION public.trg_fn_prevent_sim_line_plan_tampering() FROM PUBLIC, authenticated, anon;

-- ============================================================================
-- 3. Harden trg_fn_apply_plan_tier_from_payment (Layer 3 sole write path)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_fn_apply_plan_tier_from_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_plan text;
  v_owner_id uuid;
BEGIN
  -- Only apply when kind = 'plan' and sim_line_id is provided
  IF NEW.kind = 'plan' AND NEW.sim_line_id IS NOT NULL THEN
    v_plan := NEW.metadata ->> 'plan';

    -- Whitelist valid plan types
    IF v_plan IS NOT NULL AND v_plan IN ('standard', 'premium', 'basic', 'free') THEN
      -- Verify NEW.user_id owns NEW.sim_line_id
      SELECT user_id INTO v_owner_id
      FROM public.sim_lines
      WHERE id = NEW.sim_line_id;

      IF v_owner_id IS NOT NULL AND (NEW.user_id IS NULL OR v_owner_id = NEW.user_id) THEN
        BEGIN
          UPDATE public.sim_lines
          SET plan_type = v_plan,
              plan_expires_at = NOW() + INTERVAL '1 year',
              updated_at = NOW()
          WHERE id = NEW.sim_line_id;
        EXCEPTION WHEN OTHERS THEN
          INSERT INTO public.system_alerts (kind, message, details, created_at)
          VALUES (
            'plan_tier_update_failed',
            'Failed to update plan_type for sim_line ' || NEW.sim_line_id::text,
            jsonb_build_object('error', SQLERRM, 'payment_id', NEW.id),
            NOW()
          );
        END;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Ensure trigger exists
DROP TRIGGER IF EXISTS trg_apply_plan_tier_on_payment ON public.plan_payments;
CREATE TRIGGER trg_apply_plan_tier_on_payment
  AFTER INSERT ON public.plan_payments
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_apply_plan_tier_from_payment();

REVOKE EXECUTE ON FUNCTION public.trg_fn_apply_plan_tier_from_payment() FROM PUBLIC, authenticated, anon;

-- ============================================================================
-- 4. Unique Partial Index on wallet_transactions for esim_purchase_refund
-- ============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_txns_esim_refund_ref
  ON public.wallet_transactions (reference_id)
  WHERE type = 'esim_purchase_refund';

-- ============================================================================
-- 5. Updated credit_wallet_for_refund (supports p_type parameter)
-- ============================================================================

DROP FUNCTION IF EXISTS public.credit_wallet_for_refund(uuid, uuid, numeric, text, text);
DROP FUNCTION IF EXISTS public.credit_wallet_for_refund(uuid, numeric, text, text, uuid, text);

CREATE OR REPLACE FUNCTION public.credit_wallet_for_refund(
  p_user_id UUID,
  p_amount NUMERIC,
  p_reference_id TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_sim_line_id UUID DEFAULT NULL,
  p_type TEXT DEFAULT 'refund'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_wallet_id UUID;
  v_balance_before NUMERIC;
  v_balance_after NUMERIC;
  v_txn_id UUID;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Refund amount must be positive, got %', p_amount;
  END IF;

  SELECT id, balance INTO v_wallet_id, v_balance_before
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  v_balance_after := v_balance_before + p_amount;

  UPDATE public.wallets
  SET balance = v_balance_after,
      total_spent = GREATEST(0, total_spent - p_amount)
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, sim_line_id, status
  ) VALUES (
    v_wallet_id, p_user_id, COALESCE(p_type, 'refund'), p_amount, v_balance_before, v_balance_after,
    p_description, p_reference_id, p_sim_line_id, 'completed'
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.credit_wallet_for_refund FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.credit_wallet_for_refund TO authenticated, service_role;

-- ============================================================================
-- 6. Config Seed for Staleness Hours
-- ============================================================================

INSERT INTO public.system_configs (config_key, config_value)
VALUES ('ESIM_STALE_ORDER_HOURS', '3')
ON CONFLICT (config_key) DO NOTHING;

-- ============================================================================
-- 7. Fix reap_stale_esim_orders RPC
-- ============================================================================

CREATE OR REPLACE FUNCTION public.reap_stale_esim_orders()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_order RECORD;
  v_reaped_count integer := 0;
  v_refund_ref text;
  v_debit_amount numeric;
  v_stale_hours integer := 3;
  v_refund_type text := 'esim_purchase_refund';
BEGIN
  -- Read staleness threshold from system_configs
  BEGIN
    SELECT config_value::integer INTO v_stale_hours
    FROM public.system_configs
    WHERE config_key = 'ESIM_STALE_ORDER_HOURS';
  EXCEPTION WHEN OTHERS THEN
    v_stale_hours := 3;
  END;
  IF v_stale_hours IS NULL OR v_stale_hours < 1 THEN
    v_stale_hours := 3;
  END IF;

  -- Select pending esim_orders older than threshold with provider_order_ref IS NULL
  FOR v_order IN
    SELECT id, user_id, retail_price_usd, quantity, created_at
    FROM public.esim_orders
    WHERE status = 'pending'
      AND provider_order_ref IS NULL
      AND created_at < NOW() - (v_stale_hours || ' hours')::interval
    FOR UPDATE SKIP LOCKED
  LOOP
    v_refund_ref := 'esim_refund_' || v_order.id::text;

    -- Check if a refund already exists for this order
    IF EXISTS (
      SELECT 1 FROM public.wallet_transactions
      WHERE reference_id = v_refund_ref
        AND type = v_refund_type
    ) THEN
      CONTINUE;
    END IF;

    -- Read the actual debit transaction for this order
    SELECT amount INTO v_debit_amount
    FROM public.wallet_transactions
    WHERE reference_id = 'esim_' || v_order.id::text
      AND type = 'esim_purchase_debit'
    LIMIT 1;

    IF v_debit_amount IS NULL OR v_debit_amount <= 0 THEN
      -- No debit row found: mark failed without refund and log alert
      UPDATE public.esim_orders
      SET status = 'failed',
          error_message = 'stale_unpaid_order_reaped',
          updated_at = NOW()
      WHERE id = v_order.id;

      INSERT INTO public.system_alerts (kind, message, details, created_at)
      VALUES (
        'stale_esim_order_unpaid',
        'Stale eSIM order ' || v_order.id::text || ' reaped but no wallet debit transaction was found.',
        jsonb_build_object('order_id', v_order.id, 'user_id', v_order.user_id),
        NOW()
      );
    ELSE
      -- Debit row found: mark failed and issue exact refund
      UPDATE public.esim_orders
      SET status = 'failed',
          error_message = 'stale_timeout_reaped',
          updated_at = NOW()
      WHERE id = v_order.id;

      PERFORM public.credit_wallet_for_refund(
        v_order.user_id,
        v_debit_amount,
        v_refund_ref,
        'Stale eSIM order auto-refund',
        NULL,
        v_refund_type
      );

      INSERT INTO public.system_alerts (kind, message, details, created_at)
      VALUES (
        'stale_esim_order_reaped',
        'Stale pending eSIM order ' || v_order.id::text || ' auto-reaped and refunded after ' || v_stale_hours || ' hours timeout.',
        jsonb_build_object(
          'order_id', v_order.id,
          'user_id', v_order.user_id,
          'amount_usd', v_debit_amount,
          'created_at', v_order.created_at
        ),
        NOW()
      );

      v_reaped_count := v_reaped_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'status', 'SUCCESS',
    'reaped_count', v_reaped_count
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.reap_stale_esim_orders() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.reap_stale_esim_orders() TO service_role;

-- ============================================================================
-- 8. Reconcile request_esim_purchase RPC
-- ============================================================================

CREATE OR REPLACE FUNCTION public.request_esim_purchase(
  p_offer_id text,
  p_quantity integer DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_offer RECORD;
  v_markup_percent numeric := 30.0;
  v_retail_price numeric(10,2);
  v_total_cost numeric(10,2);
  v_wallet_balance numeric(10,2);
  v_order_id uuid;
  v_txn_ref text;
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
  WHERE bundle_name = p_offer_id AND is_active = true
  LIMIT 1;

  IF v_offer IS NULL OR v_offer.bundle_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'eSIM offer not found or inactive');
  END IF;

  BEGIN
    SELECT config_value::numeric INTO v_markup_percent
    FROM public.system_configs WHERE config_key = 'ESIM_MARKUP_PERCENT';
  EXCEPTION WHEN OTHERS THEN v_markup_percent := 30.0; END;
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
$$;

REVOKE EXECUTE ON FUNCTION public.request_esim_purchase(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_esim_purchase(text, integer) TO authenticated, service_role;

COMMIT;
