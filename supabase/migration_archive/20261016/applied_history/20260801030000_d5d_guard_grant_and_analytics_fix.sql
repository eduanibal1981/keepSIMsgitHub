-- Migration: 20260801030000_d5d_guard_grant_and_analytics_fix.sql
-- Goal: 1. Redefine tamper guard trigger as SECURITY INVOKER so current_user checks PostgREST role.
--       2. Create dedicated analytics_events table with RLS for client event tracking.
--       3. Add check_worker_heartbeat_health() procedure to alert when worker heartbeat is stale.

BEGIN;

-- ============================================================================
-- 1. Redefine Tamper Guard Trigger Function as SECURITY INVOKER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_fn_prevent_sim_line_plan_tampering()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $$
BEGIN
  IF (NEW.plan_type IS DISTINCT FROM OLD.plan_type OR NEW.plan_expires_at IS DISTINCT FROM OLD.plan_expires_at) THEN
    -- Under SECURITY INVOKER, current_user is PostgREST role ('authenticated' / 'anon').
    -- System routines (like trg_fn_apply_plan_tier_from_payment) run as SECURITY DEFINER owned by postgres (current_user = 'postgres').
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

-- ============================================================================
-- 2. Dedicated analytics_events Table & RLS Policies
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  details JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert own analytics events" ON public.analytics_events;
CREATE POLICY "Users can insert own analytics events"
  ON public.analytics_events FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can select own analytics events" ON public.analytics_events;
CREATE POLICY "Users can select own analytics events"
  ON public.analytics_events FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- ============================================================================
-- 3. Worker Heartbeat Staleness Alert Check
-- ============================================================================

CREATE OR REPLACE FUNCTION public.check_worker_heartbeat_health()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_updated_at timestamptz;
  v_minutes numeric;
BEGIN
  SELECT updated_at INTO v_updated_at
  FROM public.system_configs
  WHERE config_key = 'WORKER_ESIM_FULFILLMENT_HEARTBEAT';

  IF v_updated_at IS NULL OR v_updated_at < NOW() - INTERVAL '15 minutes' THEN
    v_minutes := ROUND(EXTRACT(EPOCH FROM (NOW() - COALESCE(v_updated_at, NOW() - INTERVAL '1 day')))::numeric / 60.0, 1);
    INSERT INTO public.system_alerts (kind, message, details, created_at)
    VALUES (
      'worker_heartbeat_stale',
      'eSIM Fulfillment Worker heartbeat is stale (last seen ' || v_minutes || ' minutes ago).',
      jsonb_build_object('worker', 'worker-esim-fulfillment', 'last_seen', v_updated_at, 'stale_minutes', v_minutes),
      NOW()
    );
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_worker_heartbeat_health() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.check_worker_heartbeat_health() TO service_role, postgres;

-- ============================================================================
-- 4. Register Migration
-- ============================================================================

INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20260801030000', 'd5d_guard_grant_and_analytics_fix')
ON CONFLICT (version) DO UPDATE SET name = EXCLUDED.name;

COMMIT;
