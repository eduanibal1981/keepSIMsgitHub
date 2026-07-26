-- Migration: 20260801020000_d5c_fail_closed_guard_and_grants_fix.sql

BEGIN;

-- 1. Revoke table-level UPDATE from authenticated and anon
REVOKE UPDATE ON public.sim_lines FROM authenticated, anon;

-- Grant column-level UPDATE ONLY for legitimate client-writable fields (excluding plan_type, plan_expires_at)
GRANT UPDATE (
  phone_number, nickname, avatar_icon, status, country_id, carrier_id,
  carrier_rule_id, carrier_pricing_id, household_id, is_home_mode,
  protection_paused, requires_protection_at_home, updated_at
) ON public.sim_lines TO authenticated;

-- 2. Fail-Closed Tamper Guard Trigger Function
CREATE OR REPLACE FUNCTION public.trg_fn_prevent_sim_line_plan_tampering()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF (NEW.plan_type IS DISTINCT FROM OLD.plan_type OR NEW.plan_expires_at IS DISTINCT FROM OLD.plan_expires_at) THEN
    -- Fail-closed allow-list on Postgres role (never NULL): only system roles can mutate plan_type / plan_expires_at
    IF current_user NOT IN ('service_role', 'postgres', 'supabase_admin') THEN
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

-- 3. Fix reap_stale_esim_orders RPC (Count Unpaid & Filter status='completed')
CREATE OR REPLACE FUNCTION public.reap_stale_esim_orders()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_order RECORD;
  v_reaped_refund_count integer := 0;
  v_reaped_unpaid_count integer := 0;
  v_refund_ref text;
  v_debit_amount numeric;
  v_stale_hours integer := 3;
  v_refund_type text := 'esim_purchase_refund';
BEGIN
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

  FOR v_order IN
    SELECT id, user_id, retail_price_usd, quantity, created_at
    FROM public.esim_orders
    WHERE status = 'pending'
      AND provider_order_ref IS NULL
      AND created_at < NOW() - (v_stale_hours || ' hours')::interval
    FOR UPDATE SKIP LOCKED
  LOOP
    v_refund_ref := 'esim_refund_' || v_order.id::text;

    IF EXISTS (
      SELECT 1 FROM public.wallet_transactions
      WHERE reference_id = v_refund_ref
        AND type = v_refund_type
    ) THEN
      CONTINUE;
    END IF;

    SELECT amount INTO v_debit_amount
    FROM public.wallet_transactions
    WHERE reference_id = 'esim_' || v_order.id::text
      AND type = 'esim_purchase_debit'
      AND status = 'completed'
    LIMIT 1;

    IF v_debit_amount IS NULL OR v_debit_amount <= 0 THEN
      UPDATE public.esim_orders
      SET status = 'failed',
          error_message = 'stale_unpaid_order_reaped',
          updated_at = NOW()
      WHERE id = v_order.id;

      INSERT INTO public.system_alerts (kind, message, details, created_at)
      VALUES (
        'stale_esim_order_unpaid',
        'Stale eSIM order ' || v_order.id::text || ' reaped but no completed wallet debit transaction was found.',
        jsonb_build_object('order_id', v_order.id, 'user_id', v_order.user_id),
        NOW()
      );

      v_reaped_unpaid_count := v_reaped_unpaid_count + 1;
    ELSE
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

      v_reaped_refund_count := v_reaped_refund_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'status', 'SUCCESS',
    'reaped_refund_count', v_reaped_refund_count,
    'reaped_unpaid_count', v_reaped_unpaid_count,
    'reaped_count', (v_reaped_refund_count + v_reaped_unpaid_count)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.reap_stale_esim_orders() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.reap_stale_esim_orders() TO service_role;

-- 4. Reconcile Order 41861f0f-a5ad-4755-96c4-0a1c28e7e3d0
UPDATE public.esim_orders
SET offer_id = COALESCE(offer_id, bundle_name),
    total_amount_usd = COALESCE(total_amount_usd, retail_price_usd * quantity),
    status = 'failed',
    updated_at = NOW()
WHERE id = '41861f0f-a5ad-4755-96c4-0a1c28e7e3d0';

-- 5. Clean Committed Test Residue
DELETE FROM public.wallet_transactions WHERE user_id = 'a1111111-1111-1111-1111-111111111111';
DELETE FROM public.sim_lines WHERE user_id = 'a1111111-1111-1111-1111-111111111111';
DELETE FROM public.wallets WHERE user_id = 'a1111111-1111-1111-1111-111111111111';
DELETE FROM public.profiles WHERE id = 'a1111111-1111-1111-1111-111111111111';
DELETE FROM auth.users WHERE id = 'a1111111-1111-1111-1111-111111111111';

DELETE FROM public.esim_orders WHERE bundle_name IN ('d5b_offer_101', 'D5b Test Unpaid');
DELETE FROM public.esim_offers_cache WHERE bundle_name = 'd5b_offer_101';
DELETE FROM public.system_alerts WHERE kind IN ('stale_esim_order_reaped', 'stale_esim_order_unpaid', 'plan_tier_update_failed') AND details->>'order_id' IS NOT NULL;

-- 6. Register Migration
INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20260801020000', 'd5c_fail_closed_guard_and_grants_fix')
ON CONFLICT (version) DO UPDATE SET name = EXCLUDED.name;

COMMIT;
