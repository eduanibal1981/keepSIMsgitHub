-- Migration: Align max_authorized_usd in calculate_topup_fees
-- Ensures customer spending cap is never lower than the retail amount (base_cost_usd + app_fee_usd)

CREATE OR REPLACE FUNCTION public.calculate_topup_fees()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_line_tier       TEXT := 'free';
  v_entitlement     JSONB;
  v_app_fee         NUMERIC;
  v_msg_fee         NUMERIC := 0.00;
  v_msg_fee_key     TEXT;
  pm                RECORD;
BEGIN
  IF NEW.payment_gateway_code IS NOT NULL AND NEW.base_cost_usd IS NOT NULL THEN
    SELECT * INTO pm FROM public.payment_gateways WHERE code = NEW.payment_gateway_code;

    IF FOUND THEN
      -- Resolve line tier
      IF NEW.sim_line_id IS NOT NULL THEN
        v_entitlement := public.resolve_line_entitlement(NEW.sim_line_id);
        v_line_tier := COALESCE(v_entitlement->>'effective_tier', 'free');
      END IF;

      -- Resolve app fee from app_fee_rules
      v_app_fee := public.resolve_app_fee('refills', v_line_tier, NEW.base_cost_usd);

      -- Fallback if no published rule existed
      IF v_app_fee IS NULL OR v_app_fee = 0 THEN
        v_app_fee := round(greatest(NEW.base_cost_usd * 0.03, 0.03), 2);
      END IF;

      -- Offline messaging fees if applicable
      IF NEW.refill_channel IS NOT NULL THEN
        v_msg_fee_key := CASE NEW.refill_channel
          WHEN 'whatsapp'    THEN 'OFFLINE_WHATSAPP_MESSAGE_FEE_USD'
          WHEN 'sms'         THEN 'OFFLINE_SMS_MESSAGE_FEE_USD'
          WHEN 'missed_call' THEN 'OFFLINE_MISSED_CALL_FEE_USD'
        END;
        BEGIN
          SELECT config_value::numeric INTO v_msg_fee
          FROM public.system_configs
          WHERE config_key = v_msg_fee_key;
        EXCEPTION WHEN others THEN
          v_msg_fee := 0;
        END;
        v_msg_fee := coalesce(v_msg_fee, 0);
      END IF;

      NEW.app_fee_usd := v_app_fee;
      NEW.amount := round(NEW.base_cost_usd + v_app_fee + v_msg_fee, 2);

      -- Ensure customer authorization cap scales to at least the total retail amount
      IF NEW.max_authorized_usd IS NULL OR NEW.max_authorized_usd < NEW.amount THEN
        NEW.max_authorized_usd := NEW.amount;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
