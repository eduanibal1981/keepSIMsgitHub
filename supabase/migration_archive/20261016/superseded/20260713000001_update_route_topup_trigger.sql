-- Migration: 20260713000001_update_route_topup_trigger.sql

-- Updates the existing `route_topup_execution` function which is triggered BEFORE INSERT
-- on `topup_executions`. Previously it queried `telecom_fulfillment_routes` using string names.
-- Now it simply queries the `fulfillment_gateway` and `api_provider` columns directly
-- from the joined `carriers` table using UUID foreign keys.

CREATE OR REPLACE FUNCTION public.route_topup_execution()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_gateway VARCHAR;
  v_api_provider VARCHAR;
BEGIN
  -- We want to assign gateways to any new executions that don't have one yet and are not explicitly failed
  IF NEW.status IN ('pending', 'pending_payment', 'routing') AND NEW.fulfillment_gateway IS NULL THEN
    
    -- 1. Get the carrier's gateway details using UUID foreign keys directly
    SELECT ca.fulfillment_gateway, ca.api_provider
    INTO v_gateway, v_api_provider
    FROM public.sim_lines sl
    JOIN public.carriers ca ON sl.carrier_id = ca.id
    WHERE sl.id = NEW.sim_line_id;

    -- 2. Fallback to global config if no specific route found (or if carrier row somehow didn't return one)
    IF v_gateway IS NULL THEN
      SELECT config_value 
      INTO v_gateway
      FROM public.system_configs
      WHERE config_key = 'ACTIVE_FULFILLMENT_METHOD'
      LIMIT 1;
      
      -- Ultimate fallback
      IF v_gateway IS NULL THEN
        v_gateway := 'MANUAL';
      END IF;
    END IF;

    -- 3. Assign Gateway Logic
    NEW.fulfillment_gateway := v_gateway;
    NEW.api_provider := v_api_provider;
    
    -- 4. If it was 'pending' and it's instant, bump it to 'routing'
    IF NEW.execution_type = 'refill_instant' AND NEW.status = 'pending' THEN
      NEW.status := 'routing';
    END IF;

  END IF;

  RETURN NEW;
END;
$function$;
