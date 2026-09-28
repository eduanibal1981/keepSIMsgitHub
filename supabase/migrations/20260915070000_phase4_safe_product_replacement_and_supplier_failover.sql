-- ==============================================================================
-- Migration: 20260915070000_phase4_safe_product_replacement_and_supplier_failover.sql
-- Description: Phase 4 - Guard trg_fn_supplier_failover for v2 auto-refill executions.
--              V2 auto-refill executions handle safe product replacement and multi-supplier
--              failover inside the resilience worker engine, retaining single occurrence identity.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.trg_fn_supplier_failover()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_on   text;
  v_skip text;
  v_pat  text;
BEGIN
  IF NEW.status <> 'failed' OR OLD.status = 'failed' THEN
    RETURN NEW;
  END IF;

  -- Guard for v2 auto-refill resilience: v2 executions handle replacement and
  -- failover directly within the worker engine, retaining the same occurrence identity.
  -- This prevents legacy trigger from spawning duplicate topup_executions rows.
  IF COALESCE(NEW.engine_version, 1) >= 2 THEN
    RETURN NEW;
  END IF;

  BEGIN
    SELECT config_value INTO v_on FROM public.system_configs WHERE config_key = 'SUPPLIER_RETRY_ENABLED';
  EXCEPTION WHEN OTHERS THEN v_on := NULL;
  END;
  IF lower(COALESCE(v_on, 'false')) <> 'true' THEN
    RETURN NEW;
  END IF;

  -- Do not retry a failure that will fail identically at any supplier.
  BEGIN
    SELECT config_value INTO v_skip FROM public.system_configs WHERE config_key = 'SUPPLIER_RETRY_SKIP_REASONS';
  EXCEPTION WHEN OTHERS THEN v_skip := NULL;
  END;

  IF NEW.failure_reason IS NOT NULL AND COALESCE(v_skip, '') <> '' THEN
    FOREACH v_pat IN ARRAY string_to_array(v_skip, ',') LOOP
      IF btrim(v_pat) <> '' AND position(lower(btrim(v_pat)) in lower(NEW.failure_reason)) > 0 THEN
        RETURN NEW;
      END IF;
    END LOOP;
  END IF;

  -- Never let a failover error abort the failure write itself: the row must end
  -- up 'failed' even if the retry cannot be built.
  BEGIN
    PERFORM public.retry_execution_at_next_supplier(NEW.id);
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO public.system_alerts (kind, message, details, created_at)
    VALUES ('supplier_failover_failed',
            'Failover could not queue a retry for execution ' || NEW.id::text,
            jsonb_build_object('error', SQLERRM), now());
  END;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.trg_fn_supplier_failover() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_fn_supplier_failover() TO service_role;
