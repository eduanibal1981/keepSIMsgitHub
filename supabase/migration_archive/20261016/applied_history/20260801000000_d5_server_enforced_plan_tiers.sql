-- Migration 20260801000000_d5_server_enforced_plan_tiers.sql
-- D5: Server-Enforced Plan Tier Updates & Stale eSIM Order Reap Engine

BEGIN;

-- Extend wallet_transactions_type_check to support 'esim_purchase_refund'
ALTER TABLE public.wallet_transactions
  DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;

ALTER TABLE public.wallet_transactions
  ADD CONSTRAINT wallet_transactions_type_check
  CHECK (type IN (
    'deposit', 'topup_debit', 'refund', 'referral_credit',
    'welcome_home_debit', 'auto_fund', 'plan_fee_debit',
    'esim_purchase_debit', 'esim_purchase_refund',
    'wallet_settlement', 'wallet_forfeit'
  ));

-- ============================================================================
-- 1. Server-Enforced Plan Tier Trigger on plan_payments
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_fn_apply_plan_tier_from_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_plan text;
BEGIN
  -- Only apply when kind = 'plan' and sim_line_id is provided
  IF NEW.kind = 'plan' AND NEW.sim_line_id IS NOT NULL THEN
    v_plan := NEW.metadata ->> 'plan';
    IF v_plan IS NOT NULL AND v_plan <> '' THEN
      UPDATE public.sim_lines
      SET plan_type = v_plan,
          updated_at = NOW()
      WHERE id = NEW.sim_line_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS trg_apply_plan_tier_on_payment ON public.plan_payments;
CREATE TRIGGER trg_apply_plan_tier_on_payment
  AFTER INSERT ON public.plan_payments
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_apply_plan_tier_from_payment();

-- Revoke EXECUTE from PUBLIC/authenticated for trigger function
REVOKE EXECUTE ON FUNCTION public.trg_fn_apply_plan_tier_from_payment() FROM PUBLIC, authenticated, anon;


-- ============================================================================
-- 2. Stale-Pending eSIM Order Sweep RPC (public.reap_stale_esim_orders)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.reap_stale_esim_orders()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_reaped_count integer := 0;
  v_refund_ref text;
BEGIN
  -- Select all pending esim_orders older than 1 hour
  FOR v_order IN
    SELECT id, user_id, retail_price_usd, created_at
    FROM public.esim_orders
    WHERE status = 'pending'
      AND created_at < NOW() - INTERVAL '1 hour'
    FOR UPDATE
  LOOP
    -- 1. Update order status to failed and set error message
    UPDATE public.esim_orders
    SET status = 'failed',
        error_message = 'stale_timeout_reaped',
        updated_at = NOW()
    WHERE id = v_order.id;

    -- 2. Refund user wallet atomically via credit_wallet
    v_refund_ref := 'ref_reap_' || v_order.id::text;
    PERFORM public.credit_wallet(
      v_order.user_id,
      v_order.retail_price_usd,
      'esim_purchase_refund',
      'Stale eSIM order auto-refund',
      v_refund_ref
    );

    -- 3. Log system alert
    INSERT INTO public.system_alerts (
      kind,
      message,
      details,
      created_at
    ) VALUES (
      'stale_esim_order_reaped',
      'Stale pending eSIM order ' || v_order.id::text || ' auto-reaped and refunded after 1 hour timeout.',
      jsonb_build_object(
        'order_id', v_order.id,
        'user_id', v_order.user_id,
        'amount_usd', v_order.retail_price_usd,
        'created_at', v_order.created_at
      ),
      NOW()
    );

    v_reaped_count := v_reaped_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'status', 'SUCCESS',
    'reaped_count', v_reaped_count
  );
END;
$$;

-- Restrict execution to service_role / postgres (pg_cron)
REVOKE EXECUTE ON FUNCTION public.reap_stale_esim_orders() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.reap_stale_esim_orders() TO service_role;

-- ============================================================================
-- 3. Schedule Hourly Cron Job for Stale eSIM Order Reaper
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'reap-stale-esim-orders-hourly',
      '0 * * * *',
      'SELECT public.reap_stale_esim_orders()'
    );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron not available or schedule failed: %', SQLERRM;
END;
$$;

COMMIT;
