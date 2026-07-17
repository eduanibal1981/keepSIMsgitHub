-- C3 — Instant recharge: configurable app fee, and a rate limiter that fires.
--
-- 1. App fee was hardcoded in two places that disagreed. The client quoted
--    base * 3% while calculate_topup_fees charged base * 5%, so a $5.00 refill
--    displayed "Confirm $5.15" and debited $5.25 — every refill silently
--    overcharged by the gap. The rate now lives in exactly one place,
--    system_configs.APP_FEE_PERCENT, which a power user can change from the
--    dashboard without a redeploy (RLS already allows authenticated SELECT and
--    power-user UPDATE). The settings UI reads the same row, so the quote and
--    the debit cannot drift apart again. Set to 3 per the user's decision.
--
-- 2. check_topup_rate_limit tested execution_type = 'instant', but the pipeline
--    has always used 'refill_instant' (route_topup_execution and
--    claim_instant_executions both key off it), so the limiter never fired once.
--    C3 puts a user-facing button on this path, which is exactly when a spend
--    throttle starts to matter. Safe to enable: only refill_instant and
--    refill_mini exist, retries update rather than insert (retry_of and
--    reaper_retries are unused), and no two historical refill_instant rows for
--    one line land within 10 seconds.

BEGIN;

INSERT INTO public.system_configs (config_key, config_value)
VALUES ('APP_FEE_PERCENT', '3')
ON CONFLICT (config_key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.calculate_topup_fees()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    pm                RECORD;
    v_app_fee_percent numeric;
BEGIN
    IF NEW.payment_gateway_code IS NOT NULL AND NEW.base_cost_usd IS NOT NULL THEN
        SELECT * INTO pm FROM public.payment_gateways WHERE code = NEW.payment_gateway_code;

        IF FOUND THEN
            -- config_value is free-text, so a typo must not break every refill
            -- insert: fall back to 3 rather than raising. The same guard rejects
            -- a nonsense rate outside 0–100.
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

            NEW.gateway_fee_usd := ROUND((NEW.base_cost_usd * (pm.fee_percentage / 100.0) + pm.fee_fixed), 2);
            NEW.app_fee_usd     := ROUND((NEW.base_cost_usd * (v_app_fee_percent / 100.0)), 2);
            NEW.amount          := ROUND(NEW.base_cost_usd + NEW.gateway_fee_usd + NEW.app_fee_usd, 2);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_topup_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  -- Only instant refills are throttled: they are the ones a user can trigger by
  -- tapping, and each one spends wallet money.
  IF NEW.execution_type = 'refill_instant' THEN
    IF EXISTS (
      SELECT 1 FROM public.topup_executions
      WHERE sim_line_id = NEW.sim_line_id
        AND execution_type = 'refill_instant'
        AND created_at > (NOW() - INTERVAL '10 seconds')
    ) THEN
      RAISE EXCEPTION 'Rate limit exceeded: Please wait 10 seconds before the next instant refill for this SIM line.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

COMMIT;
