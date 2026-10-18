-- Migration: Add MIN_APP_FEE_USD floor to system_configs and calculate_topup_fees trigger
-- Prevents app fee from dropping below $0.03 on micro-topups when APP_FEE_PERCENT is configured.

INSERT INTO public.system_configs (config_key, config_value)
VALUES ('MIN_APP_FEE_USD', '0.03')
ON CONFLICT (config_key) DO UPDATE SET config_value = '0.03', updated_at = now();

CREATE OR REPLACE FUNCTION public.calculate_topup_fees()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    pm                RECORD;
    v_app_fee_percent numeric;
    v_min_app_fee     numeric;
    v_msg_fee         numeric;
    v_msg_fee_key     text;
    v_calc_app_fee    numeric;
BEGIN
    IF NEW.payment_gateway_code IS NOT NULL AND NEW.base_cost_usd IS NOT NULL THEN
        SELECT * INTO pm FROM public.payment_gateways WHERE code = NEW.payment_gateway_code;

        IF FOUND THEN
            BEGIN
                SELECT config_value::numeric INTO v_app_fee_percent
                FROM public.system_configs
                WHERE config_key = 'APP_FEE_PERCENT';
            EXCEPTION WHEN others THEN
                v_app_fee_percent := NULL;
            END;

            IF v_app_fee_percent IS NULL
               OR v_app_fee_percent < 0
               OR v_app_fee_percent > 100 THEN
                v_app_fee_percent := 3;
            END IF;

            BEGIN
                SELECT config_value::numeric INTO v_min_app_fee
                FROM public.system_configs
                WHERE config_key = 'MIN_APP_FEE_USD';
            EXCEPTION WHEN others THEN
                v_min_app_fee := NULL;
            END;

            IF v_min_app_fee IS NULL OR v_min_app_fee < 0 THEN
                v_min_app_fee := 0.03;
            END IF;

            v_msg_fee := 0;
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
                    v_msg_fee := NULL;
                END;
                IF v_msg_fee IS NULL OR v_msg_fee < 0 OR v_msg_fee > 100 THEN
                    v_msg_fee := 0;
                END IF;
            END IF;

            v_calc_app_fee := ROUND((NEW.base_cost_usd * (v_app_fee_percent / 100.0)), 2);
            IF v_app_fee_percent > 0 AND v_calc_app_fee < v_min_app_fee THEN
                v_calc_app_fee := v_min_app_fee;
            END IF;

            NEW.gateway_fee_usd := ROUND((NEW.base_cost_usd * (pm.fee_percentage / 100.0) + pm.fee_fixed), 2);
            NEW.app_fee_usd     := v_calc_app_fee;
            NEW.message_fee_usd := ROUND(v_msg_fee, 2);
            NEW.amount          := ROUND(NEW.base_cost_usd + NEW.gateway_fee_usd + NEW.app_fee_usd + NEW.message_fee_usd, 2);
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;
