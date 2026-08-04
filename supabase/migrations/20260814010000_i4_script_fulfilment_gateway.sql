-- =============================================================================
-- I4 · SCRIPT fulfilment gateway — direct-from-telecom recharges, admin-controlled
-- =============================================================================
-- THE ASK: "I plan to make a Task-script to do a recharge of a specific plan or
-- amount for a specific carrier (a try at direct recharge from the Telecom, so I
-- can give users a better price than API providers like Zendit). I need to
-- control that through the Admin UI. My prepared script, if present, will be for
-- **scheduled refills only** of specific carriers — instant cannot go through
-- manual, or it is risky through the task-script way."
--
-- That last sentence is the whole safety model, so it is enforced in SQL rather
-- than left to admin discipline: **`refill_instant` can never be routed to
-- SCRIPT.** A user tapping "top up now" is waiting on a screen; a scripted
-- recharge is asynchronous, human-paced and best-effort. If a carrier is set to
-- SCRIPT, instant refills for it silently fall back to API — see the rewritten
-- `route_topup_execution()` below.
--
-- WHY THIS SHAPE
--   `topup_executions.fulfillment_gateway` already carries 'API' / 'MANUAL' and
--   `route_topup_execution()` already stamps it from `carriers`. SCRIPT is a
--   third value in that same slot, so the queue, the reaper, the fee trigger,
--   the notification trigger and the admin Operations screen all keep working
--   with no change. What is new is (a) a registry describing what each script
--   can do and what it costs, and (b) a claim/complete protocol so an external
--   runner can pull work without holding a database session open.
--
-- WHAT IS DELIBERATELY NOT HERE
--   The runner itself. It has to live where the SIM/USSD/portal access is — the
--   owner-gated GCE VM or a phone — and it authenticates with the service-role
--   key like every other worker. This migration is the contract it will speak.
--   Nothing routes to SCRIPT until an admin both registers a script AND sets a
--   carrier's `fulfillment_gateway`, so applying this file changes no behaviour.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.refill_scripts (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  carrier_id         uuid NOT NULL REFERENCES public.carriers(id) ON DELETE CASCADE,
  name               text NOT NULL,
  script_kind        text NOT NULL DEFAULT 'ussd'
                       CHECK (script_kind IN ('ussd', 'app_automation', 'web_portal', 'other')),

  -- What it can buy. 'fixed' = one denomination; 'range' = any amount between
  -- min and max. Kept separate from the offer cache because a script is not a
  -- supplier catalogue — it is one repeatable action.
  amount_mode        text NOT NULL DEFAULT 'fixed'
                       CHECK (amount_mode IN ('fixed', 'range')),
  fixed_amount_usd   numeric(10,2),
  min_amount_usd     numeric(10,2),
  max_amount_usd     numeric(10,2),

  -- The reason the feature exists: what this costs KeepSIMs, so it can be
  -- compared with the supplier price for the same top-up.
  cost_usd           numeric(10,4),

  is_enabled         boolean NOT NULL DEFAULT false,

  -- Safety envelope. `refill_instant` is NOT permitted here and the CHECK below
  -- refuses it outright — the guard must not depend on an admin remembering.
  allowed_execution_types text[] NOT NULL DEFAULT ARRAY['refill_mini','refill_custom'],
  max_daily_executions    integer NOT NULL DEFAULT 50 CHECK (max_daily_executions > 0),

  runner_id          text,
  last_heartbeat_at  timestamptz,
  last_error         text,
  notes              text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT refill_scripts_no_instant
    CHECK (NOT ('refill_instant' = ANY (allowed_execution_types))),
  CONSTRAINT refill_scripts_amounts_sane CHECK (
    (amount_mode = 'fixed' AND fixed_amount_usd IS NOT NULL AND fixed_amount_usd > 0)
    OR (amount_mode = 'range' AND min_amount_usd IS NOT NULL AND max_amount_usd IS NOT NULL
        AND min_amount_usd > 0 AND max_amount_usd >= min_amount_usd)
  ),
  UNIQUE (carrier_id, name)
);

CREATE INDEX IF NOT EXISTS idx_refill_scripts_live
  ON public.refill_scripts (carrier_id) WHERE is_enabled;

ALTER TABLE public.refill_scripts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.refill_scripts FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.refill_scripts TO service_role;

COMMENT ON TABLE public.refill_scripts IS
  'I4: scripted direct-from-carrier recharges. Scheduled refills only — the '
  'refill_scripts_no_instant CHECK makes refill_instant unrepresentable.';

-- -----------------------------------------------------------------------------
-- Routing: SCRIPT is scheduled-only, and only when a script actually exists
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.route_topup_execution()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
DECLARE
  v_gateway VARCHAR;
  v_api_provider VARCHAR;
BEGIN
  IF NEW.status IN ('pending', 'pending_payment', 'routing') AND NEW.fulfillment_gateway IS NULL THEN

    SELECT ca.fulfillment_gateway, ca.api_provider
    INTO v_gateway, v_api_provider
    FROM public.sim_lines sl
    JOIN public.carriers ca ON sl.carrier_id = ca.id
    WHERE sl.id = NEW.sim_line_id;

    IF v_gateway IS NULL THEN
      SELECT config_value
      INTO v_gateway
      FROM public.system_configs
      WHERE config_key = 'ACTIVE_FULFILLMENT_METHOD'
      LIMIT 1;

      IF v_gateway IS NULL THEN
        v_gateway := 'MANUAL';
      END IF;
    END IF;

    -- I4: SCRIPT never takes an instant refill. The user is on a screen waiting
    -- for it; a scripted recharge is asynchronous and best-effort. Fall back to
    -- the API supplier, which is exactly what this carrier used before anyone
    -- registered a script.
    IF v_gateway = 'TASKER_SCRIPT' AND NEW.execution_type = 'refill_instant' THEN
      v_gateway := 'API';
    END IF;

    -- I4: and never when there is no enabled script that permits this kind of
    -- execution — otherwise the row parks in 'routing' forever with no claimant,
    -- which is the same silent-stall shape as the 13 stuck executions Phase H
    -- surfaced.
    IF v_gateway = 'TASKER_SCRIPT' AND NOT EXISTS (
      SELECT 1
      FROM public.sim_lines sl
      JOIN public.refill_scripts rs ON rs.carrier_id = sl.carrier_id
      WHERE sl.id = NEW.sim_line_id
        AND rs.is_enabled
        AND NEW.execution_type = ANY (rs.allowed_execution_types)
    ) THEN
      v_gateway := 'API';
    END IF;

    NEW.fulfillment_gateway := v_gateway;
    -- I1: carrier default is a fallback, not an override.
    NEW.api_provider := COALESCE(NEW.api_provider, v_api_provider);

    IF NEW.execution_type = 'refill_instant' AND NEW.status = 'pending' THEN
      NEW.status := 'routing';
    END IF;

  END IF;

  RETURN NEW;
END;
$function$;

-- -----------------------------------------------------------------------------
-- Runner protocol (service_role only — this is a worker contract, not a client one)
-- -----------------------------------------------------------------------------
-- Claim: atomically hand out due work and mark it in flight, so two runners
-- cannot take the same row. `FOR UPDATE SKIP LOCKED` is what makes that true
-- under concurrency; the existing reaper already recovers rows stuck in
-- 'processing' past its timeout, so a crashed runner self-heals.
CREATE OR REPLACE FUNCTION public.script_claim_next_execution(
  p_runner_id text,
  p_max       integer DEFAULT 1
)
RETURNS TABLE (
  execution_id   uuid,
  sim_line_id    uuid,
  phone_number   text,
  carrier_name   text,
  country_iso    text,
  amount_usd     numeric,
  execution_type text,
  script_id      uuid,
  script_kind    text,
  script_name    text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_role text;
BEGIN
  BEGIN
    v_role := current_setting('request.jwt.claims', true)::json ->> 'role';
  EXCEPTION WHEN OTHERS THEN
    v_role := NULL;
  END;
  -- Fail closed: a NULL role is not service_role.
  IF v_role IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Only a runner may claim scripted executions' USING ERRCODE = 'KS403';
  END IF;

  IF p_max IS NULL OR p_max < 1 OR p_max > 25 THEN
    p_max := 1;
  END IF;

  UPDATE public.refill_scripts
  SET last_heartbeat_at = now(), runner_id = p_runner_id, updated_at = now()
  WHERE runner_id IS NULL OR runner_id = p_runner_id;

  RETURN QUERY
  WITH due AS (
    SELECT te.id
    FROM public.topup_executions te
    JOIN public.sim_lines sl   ON sl.id = te.sim_line_id
    JOIN public.refill_scripts rs ON rs.carrier_id = sl.carrier_id AND rs.is_enabled
    WHERE te.fulfillment_gateway = 'TASKER_SCRIPT'
      AND te.status IN ('pending', 'routing')
      AND te.execution_time <= now()
      AND te.execution_type = ANY (rs.allowed_execution_types)
      -- Per-script daily throttle, counted from what actually went out today.
      AND (SELECT count(*) FROM public.topup_executions t2
           JOIN public.sim_lines s2 ON s2.id = t2.sim_line_id
           WHERE s2.carrier_id = rs.carrier_id
             AND t2.fulfillment_gateway = 'TASKER_SCRIPT'
             AND t2.processing_since >= date_trunc('day', now())) < rs.max_daily_executions
    ORDER BY te.execution_time
    LIMIT p_max
    FOR UPDATE OF te SKIP LOCKED
  ),
  claimed AS (
    UPDATE public.topup_executions te
    SET status = 'processing', processing_since = now()
    FROM due
    WHERE te.id = due.id
    -- Aliased: `sim_line_id` and `execution_type` are also OUT parameter names
    -- of this function, and an unaliased reference is ambiguous inside plpgsql.
    RETURNING te.id, te.sim_line_id AS line_id, te.amount, te.execution_type AS etype
  )
  SELECT c.id, c.line_id, sl.phone_number, ca.name, co.iso_code,
         c.amount, c.etype, rs.id, rs.script_kind, rs.name
  FROM claimed c
  JOIN public.sim_lines sl ON sl.id = c.line_id
  JOIN public.carriers  ca ON ca.id = sl.carrier_id
  JOIN public.countries co ON co.id = sl.country_id
  JOIN public.refill_scripts rs ON rs.carrier_id = sl.carrier_id AND rs.is_enabled;
END;
$function$;

REVOKE ALL ON FUNCTION public.script_claim_next_execution(text, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.script_claim_next_execution(text, integer) TO service_role;

-- Complete: the money half. Mirrors `admin_complete_manual_refill` exactly,
-- including the unique_violation swallow that makes a retry idempotent.
--
-- The `refill_mini` exemption is NOT an oversight: a premium mini-refill was
-- pre-paid by the yearly plan (that is why `worker_auto_mini_refill.js` has no
-- debit either), so charging here would bill the user twice for one top-up.
CREATE OR REPLACE FUNCTION public.script_complete_execution(
  p_execution_id uuid,
  p_success      boolean,
  p_provider_ref text DEFAULT NULL,
  p_note         text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_exec    RECORD;
  v_txn_id  uuid;
  v_debited boolean := false;
  v_role    text;
BEGIN
  BEGIN
    v_role := current_setting('request.jwt.claims', true)::json ->> 'role';
  EXCEPTION WHEN OTHERS THEN
    v_role := NULL;
  END;
  IF v_role IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Only a runner may complete scripted executions' USING ERRCODE = 'KS403';
  END IF;

  SELECT * INTO v_exec FROM public.topup_executions WHERE id = p_execution_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Execution % not found', p_execution_id USING ERRCODE = 'KS461';
  END IF;

  IF v_exec.status IN ('success', 'failed', 'refunded', 'cancelled') THEN
    RAISE EXCEPTION 'Execution % is already %', p_execution_id, v_exec.status
      USING ERRCODE = 'KS462';
  END IF;

  IF COALESCE(v_exec.fulfillment_gateway, '') <> 'TASKER_SCRIPT' THEN
    RAISE EXCEPTION 'Execution % is routed to %, not TASKER_SCRIPT',
      p_execution_id, v_exec.fulfillment_gateway USING ERRCODE = 'KS463';
  END IF;

  IF NOT p_success THEN
    UPDATE public.topup_executions
    SET status = 'failed', failure_reason = COALESCE(p_note, 'script reported failure'),
        completed_at = now()
    WHERE id = p_execution_id;
    RETURN jsonb_build_object('success', true, 'execution_id', p_execution_id,
                              'status', 'failed', 'debited', false);
  END IF;

  IF v_exec.execution_type <> 'refill_mini' THEN
    BEGIN
      v_txn_id := public.debit_wallet_for_topup(
        v_exec.user_id, v_exec.sim_line_id, v_exec.amount,
        'Scripted top-up completed', 'exec_' || p_execution_id::text, 'topup_debit');
      v_debited := true;
    EXCEPTION WHEN unique_violation THEN
      v_debited := false;
    END;
  END IF;

  UPDATE public.topup_executions
  SET status = 'success', completed_at = now(),
      reloadly_transaction_id = COALESCE(p_provider_ref, reloadly_transaction_id)
  WHERE id = p_execution_id;

  RETURN jsonb_build_object(
    'success', true, 'execution_id', p_execution_id, 'status', 'success',
    'debited', v_debited, 'amount_usd', v_exec.amount, 'transaction_id', v_txn_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.script_complete_execution(uuid, boolean, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.script_complete_execution(uuid, boolean, text, text)
  TO service_role;

-- -----------------------------------------------------------------------------
-- Admin surface
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_refill_scripts()
RETURNS TABLE (
  id uuid, carrier_id uuid, carrier_name text, country_iso text, name text,
  script_kind text, amount_mode text, fixed_amount_usd numeric,
  min_amount_usd numeric, max_amount_usd numeric, cost_usd numeric,
  is_enabled boolean, allowed_execution_types text[], max_daily_executions integer,
  runner_id text, last_heartbeat_at timestamptz, last_error text,
  carrier_gateway text, supplier_price_usd numeric, queued bigint, done_today bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
  SELECT rs.id, rs.carrier_id, ca.name, co.iso_code, rs.name,
         rs.script_kind, rs.amount_mode, rs.fixed_amount_usd,
         rs.min_amount_usd, rs.max_amount_usd, rs.cost_usd,
         rs.is_enabled, rs.allowed_execution_types, rs.max_daily_executions,
         rs.runner_id, rs.last_heartbeat_at, rs.last_error,
         ca.fulfillment_gateway::text,
         -- The comparison that justifies the whole feature: what the cheapest
         -- supplier charges for the same carrier right now.
         (SELECT min(coalesce(p.price_fixed_usd, p.price_min_usd))
          FROM public.carrier_provider_map m
          JOIN public.provider_offers_cache p
            ON p.api_provider = m.provider
           AND p.country_code = m.provider_country_code
           AND p.carrier_code = m.provider_carrier_code
          WHERE m.carrier_id = rs.carrier_id AND m.is_enabled),
         (SELECT count(*) FROM public.topup_executions t
          JOIN public.sim_lines s ON s.id = t.sim_line_id
          WHERE s.carrier_id = rs.carrier_id AND t.fulfillment_gateway = 'TASKER_SCRIPT'
            AND t.status IN ('pending','routing','processing')),
         (SELECT count(*) FROM public.topup_executions t
          JOIN public.sim_lines s ON s.id = t.sim_line_id
          WHERE s.carrier_id = rs.carrier_id AND t.fulfillment_gateway = 'TASKER_SCRIPT'
            AND t.completed_at >= date_trunc('day', now()))
  FROM public.refill_scripts rs
  JOIN public.carriers  ca ON ca.id = rs.carrier_id
  JOIN public.countries co ON co.id = ca.country_id
  ORDER BY co.iso_code, ca.name, rs.name;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_list_refill_scripts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_refill_scripts() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_upsert_refill_script(
  p_id    uuid,
  p_patch jsonb,
  p_note  text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_id  uuid;
  v_key text;
  v_types text[];
  v_allowed text[] := ARRAY[
    'carrier_id','name','script_kind','amount_mode','fixed_amount_usd',
    'min_amount_usd','max_amount_usd','cost_usd','is_enabled',
    'allowed_execution_types','max_daily_executions','runner_id','notes'
  ];
BEGIN
  PERFORM public.assert_admin();

  FOR v_key IN SELECT jsonb_object_keys(p_patch) LOOP
    IF NOT (v_key = ANY (v_allowed)) THEN
      RAISE EXCEPTION 'Unknown refill_script field: %', v_key USING ERRCODE = 'KS422';
    END IF;
  END LOOP;

  IF p_patch ? 'allowed_execution_types' THEN
    v_types := ARRAY(SELECT e FROM jsonb_array_elements_text(p_patch -> 'allowed_execution_types') e);
    -- Belt and braces over the table CHECK, so the admin gets a sentence
    -- instead of a constraint name.
    IF 'refill_instant' = ANY (v_types) THEN
      RAISE EXCEPTION 'Instant refills cannot be fulfilled by a script — a user is waiting on that screen. Scripts are for scheduled refills only.'
        USING ERRCODE = 'KS422';
    END IF;
  END IF;

  IF p_id IS NULL THEN
    IF NOT (p_patch ? 'carrier_id' AND p_patch ? 'name') THEN
      RAISE EXCEPTION 'A new script needs carrier_id and name' USING ERRCODE = 'KS422';
    END IF;
    INSERT INTO public.refill_scripts (carrier_id, name, fixed_amount_usd)
    VALUES ((p_patch ->> 'carrier_id')::uuid, p_patch ->> 'name',
            COALESCE((p_patch ->> 'fixed_amount_usd')::numeric, 1.00))
    RETURNING id INTO v_id;
  ELSE
    v_id := p_id;
    IF NOT EXISTS (SELECT 1 FROM public.refill_scripts WHERE id = v_id) THEN
      RAISE EXCEPTION 'Refill script % not found', v_id USING ERRCODE = 'KS404';
    END IF;
  END IF;

  UPDATE public.refill_scripts rs SET
    carrier_id = COALESCE((p_patch ->> 'carrier_id')::uuid, rs.carrier_id),
    name       = COALESCE(p_patch ->> 'name', rs.name),
    script_kind = COALESCE(p_patch ->> 'script_kind', rs.script_kind),
    amount_mode = COALESCE(p_patch ->> 'amount_mode', rs.amount_mode),
    fixed_amount_usd = CASE WHEN p_patch ? 'fixed_amount_usd'
                            THEN NULLIF(p_patch ->> 'fixed_amount_usd','')::numeric ELSE rs.fixed_amount_usd END,
    min_amount_usd   = CASE WHEN p_patch ? 'min_amount_usd'
                            THEN NULLIF(p_patch ->> 'min_amount_usd','')::numeric ELSE rs.min_amount_usd END,
    max_amount_usd   = CASE WHEN p_patch ? 'max_amount_usd'
                            THEN NULLIF(p_patch ->> 'max_amount_usd','')::numeric ELSE rs.max_amount_usd END,
    cost_usd         = CASE WHEN p_patch ? 'cost_usd'
                            THEN NULLIF(p_patch ->> 'cost_usd','')::numeric ELSE rs.cost_usd END,
    is_enabled = COALESCE((p_patch ->> 'is_enabled')::boolean, rs.is_enabled),
    allowed_execution_types = COALESCE(v_types, rs.allowed_execution_types),
    max_daily_executions = COALESCE((p_patch ->> 'max_daily_executions')::integer, rs.max_daily_executions),
    runner_id = CASE WHEN p_patch ? 'runner_id' THEN NULLIF(p_patch ->> 'runner_id','') ELSE rs.runner_id END,
    notes = CASE WHEN p_patch ? 'notes' THEN p_patch ->> 'notes' ELSE rs.notes END,
    updated_at = now()
  WHERE rs.id = v_id;

  PERFORM public.admin_log('refill_script_upsert', 'refill_scripts', v_id::text,
                           NULL::jsonb, p_patch, p_note);
  RETURN v_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_upsert_refill_script(uuid, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_refill_script(uuid, jsonb, text) TO authenticated, service_role;
