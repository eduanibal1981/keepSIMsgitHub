-- ============================================================================
-- H1 — Admin control plane: one guard, one audit log, and the two existing
--      admin RPCs made honest.
--
-- WHY THIS EXISTS
-- ---------------
-- The admin app (keep_sims_admin) writes to tables directly with the anon key
-- and a power-user session. Probed live against a real power-user JWT
-- (app_metadata.is_power_user = true), 2026-07-31:
--
--   UPDATE carriers            -> rows=0   (no UPDATE policy: SILENT no-op —
--                                           the Routing tab reports success and
--                                           changes nothing)
--   UPDATE topup_executions    -> 42501    (SELECT is the only grant: the
--                                           "Complete" and "Switch to Manual"
--                                           buttons are dead)
--   SELECT wallets             -> 1 row    (read-own; an admin cannot see a
--                                           user's balance)
--
-- Widening RLS to fix that would mean every future admin capability is another
-- policy on a user-facing table, which is how F-1..F-4 happened. Instead every
-- admin mutation goes through an `admin_*` SECURITY DEFINER RPC that
--   (1) re-derives the caller's authority from the JWT — never from a parameter,
--   (2) validates the change, and
--   (3) writes an audit row naming the actor.
--
-- THE DEAD GUARD, 5th OCCURRENCE
-- ------------------------------
-- `admin_complete_manual_refill` and `admin_switch_gateway_to_manual` already
-- existed (they are on f0_grant_matrix_tests.sql's allow-list) and both opened:
--
--     IF auth.uid() IS NOT NULL AND NOT (is_power_user AND NOT suspended)
--
-- With no JWT, `auth.uid()` is NULL, the condition is false, and the function
-- proceeds. It is the same shape as D5c's `current_user` guard, F-4's
-- `apply_referral`, and `protect_is_power_user` — fail-open by construction.
-- Not live-exploitable today only because F-3 revoked anon EXECUTE, i.e. the
-- thing standing between it and the internet is a grant somebody else made.
-- Rewritten here to fail closed on its own.
--
-- THE MONEY BUG IN "COMPLETE"
-- ---------------------------
-- Nothing on `topup_executions` debits a wallet: the debit lives in
-- worker_instant_refill.js, which only claims API rows. So a MANUAL execution
-- marked `success` by an admin delivered airtime and charged nobody. Proven
-- harmless so far — every one of the 26 executions ever created is gateway=API
-- and zero MANUAL rows exist — but the whole point of this phase is to make the
-- Routing tab work, and the first carrier flipped to MANUAL makes it live.
-- `admin_complete_manual_refill` now debits exactly like the worker does:
-- `amount` (fee-inclusive, per G6), reference `exec_<id>`, which the partial
-- unique index on wallet_transactions.reference_id makes idempotent.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. The guard. SECURITY INVOKER on purpose: it reads the *caller's* JWT, and
--    under SECURITY DEFINER `current_user` is the owner (D5c), so the claim is
--    the only discriminator that survives nesting.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assert_admin()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $$
DECLARE
  v_raw   text;
  v_role  text;
  v_uid   uuid;
BEGIN
  v_raw := current_setting('request.jwt.claims', true);
  IF v_raw IS NOT NULL AND v_raw <> '' THEN
    v_role := (v_raw::jsonb) ->> 'role';
  END IF;

  -- service_role is the workers, cron and Edge Functions. They already hold
  -- every privilege these functions use; refusing them here would only push
  -- callers back onto raw table writes.
  IF v_role = 'service_role' THEN
    RETURN NULL;
  END IF;

  v_uid := auth.uid();

  -- Note the shape: no `IF v_uid IS NOT NULL AND ...`. An absent identity is a
  -- refusal, not a skipped check.
  IF v_uid IS NULL
     OR NOT public.is_power_user(v_uid)
     OR public.is_user_suspended() THEN
    RAISE EXCEPTION 'Admin access required'
      USING ERRCODE = 'KS460',
            HINT = 'This action needs a power-user session.';
  END IF;

  RETURN v_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.assert_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_admin() TO authenticated, service_role;

COMMENT ON FUNCTION public.assert_admin() IS
  'H1: the single admin gate. Returns the acting power user, NULL for service_role, raises KS460 otherwise. Fails closed on a missing identity — the bug this replaces did not.';

-- ----------------------------------------------------------------------------
-- 2. The audit log. Deny-all: it names actors and carries before/after values,
--    and it is read back through admin_list_audit() so the read is gated by the
--    same function as the write.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at   timestamptz NOT NULL DEFAULT now(),
  actor_id     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_email  text,
  action       text NOT NULL,
  target_type  text NOT NULL,
  target_id    text,
  before_value jsonb,
  after_value  jsonb,
  note         text
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_created  ON public.admin_audit_log (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_target   ON public.admin_audit_log (target_type, target_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_actor    ON public.admin_audit_log (actor_id, created_at DESC);

ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.admin_audit_log FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.admin_audit_log TO service_role;

COMMENT ON TABLE public.admin_audit_log IS
  'H1: every admin mutation, with the actor taken from the JWT rather than a parameter. Deny-all by design (RLS on, zero policies) — read it through admin_list_audit().';

-- ----------------------------------------------------------------------------
-- 3. The writer. Internal only.
--
-- Known and accepted: a RAISE inside an admin RPC rolls back its own audit row,
-- exactly as G10 proved for device_money_events. Refused admin actions
-- therefore leave no trace. Left as-is rather than reaching for G10's
-- fresh-transaction workaround: an admin refusal is a UI-level mistake by a
-- trusted operator, not an attack signal worth a second round trip.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_log(
  p_action      text,
  p_target_type text,
  p_target_id   text,
  p_before      jsonb DEFAULT NULL,
  p_after       jsonb DEFAULT NULL,
  p_note        text  DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_email text;
  v_id    uuid;
BEGIN
  IF v_uid IS NOT NULL THEN
    SELECT email INTO v_email FROM public.profiles WHERE id = v_uid;
  END IF;

  INSERT INTO public.admin_audit_log (
    actor_id, actor_email, action, target_type, target_id,
    before_value, after_value, note
  ) VALUES (
    v_uid, COALESCE(v_email, 'service_role'), p_action, p_target_type, p_target_id,
    p_before, p_after, p_note
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_log(text,text,text,jsonb,jsonb,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_log(text,text,text,jsonb,jsonb,text) TO service_role;

COMMENT ON FUNCTION public.admin_log(text,text,text,jsonb,jsonb,text) IS
  'H1: internal audit writer. service_role only — the admin_* RPCs reach it as their own definer, never the client.';

-- ----------------------------------------------------------------------------
-- 4. Reading the audit log back.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_audit(
  p_limit       integer DEFAULT 100,
  p_target_type text    DEFAULT NULL,
  p_action      text    DEFAULT NULL
)
RETURNS TABLE (
  id           uuid,
  created_at   timestamptz,
  actor_email  text,
  action       text,
  target_type  text,
  target_id    text,
  before_value jsonb,
  after_value  jsonb,
  note         text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT a.id, a.created_at, a.actor_email, a.action, a.target_type,
         a.target_id, a.before_value, a.after_value, a.note
  FROM public.admin_audit_log a
  WHERE (p_target_type IS NULL OR a.target_type = p_target_type)
    AND (p_action      IS NULL OR a.action      = p_action)
  ORDER BY a.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_audit(integer,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_audit(integer,text,text) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4b. The two existing admin RPCs are DROPped, not replaced.
--
--     Two reasons, both learned the hard way:
--       * CREATE OR REPLACE cannot change a return type, and these returned
--         SETOF topup_executions — a shape that leaks every column of another
--         user's row to satisfy a button that needs a boolean.
--       * Keeping the 1-arg form alongside a 2-arg form with a defaulted
--         parameter is the F2b failure exactly: PostgREST resolves overloads
--         from the body keys on signature alone, so `{p_execution_id: …}`
--         matches both and every call returns HTTP 300 PGRST203. One signature
--         per function, always.
--
--     f0_grant_matrix_tests.sql's allow-list is updated in the same commit.
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_complete_manual_refill(uuid);
DROP FUNCTION IF EXISTS public.admin_switch_gateway_to_manual(uuid);

-- ----------------------------------------------------------------------------
-- 5. admin_complete_manual_refill — rewritten.
--
--    Preconditions are the feature here, not defensive programming:
--      * MANUAL only. An API row belongs to worker_instant_refill.js; hand-
--        completing one while the worker is mid-flight is how you fulfil twice.
--        The admin has "Switch to Manual" for that case, which is a deliberate
--        two-step.
--      * non-terminal only. Re-completing a `success` row would re-fire
--        trg_fn_notify_topup_result and re-notify the user.
--      * debit before status. If the wallet cannot pay, nothing is marked done.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_complete_manual_refill(
  p_execution_id uuid,
  p_note         text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_exec    RECORD;
  v_txn_id  uuid;
  v_debited boolean := false;
BEGIN
  PERFORM public.assert_admin();

  SELECT * INTO v_exec
  FROM public.topup_executions
  WHERE id = p_execution_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Execution % not found', p_execution_id USING ERRCODE = 'KS461';
  END IF;

  IF v_exec.status IN ('success', 'failed', 'refunded', 'cancelled') THEN
    RAISE EXCEPTION 'Execution % is already %', p_execution_id, v_exec.status
      USING ERRCODE = 'KS462',
            HINT = 'Terminal executions cannot be completed again.';
  END IF;

  IF COALESCE(v_exec.fulfillment_gateway, 'MANUAL') <> 'MANUAL' THEN
    RAISE EXCEPTION 'Execution % is routed to %, not MANUAL',
      p_execution_id, v_exec.fulfillment_gateway
      USING ERRCODE = 'KS463',
            HINT = 'Switch it to MANUAL first — completing an API row by hand races the worker.';
  END IF;

  -- The worker debits `amount`, not `base_cost_usd` (G6): a $2.50 offer costs
  -- $2.58 once tr_calculate_topup_fees has run. Matching it here is what keeps
  -- MANUAL and API fulfilment the same price to the user.
  BEGIN
    v_txn_id := public.debit_wallet_for_topup(
      v_exec.user_id,
      v_exec.sim_line_id,
      v_exec.amount,
      'Manual top-up completed by support',
      'exec_' || p_execution_id::text,
      'topup_debit'
    );
    v_debited := true;
  EXCEPTION
    WHEN unique_violation THEN
      -- The partial unique index on reference_id already holds a topup_debit
      -- for this execution. Somebody (or some retry) paid for it; completing is
      -- still the right outcome, charging twice is not.
      v_debited := false;
  END;

  UPDATE public.topup_executions
  SET status = 'success',
      completed_at = now()
  WHERE id = p_execution_id;

  PERFORM public.admin_log(
    'refill.complete_manual', 'topup_execution', p_execution_id::text,
    jsonb_build_object('status', v_exec.status, 'gateway', v_exec.fulfillment_gateway),
    jsonb_build_object('status', 'success', 'debited', v_debited,
                       'amount_usd', v_exec.amount, 'txn_id', v_txn_id),
    p_note
  );

  RETURN jsonb_build_object(
    'success',        true,
    'execution_id',   p_execution_id,
    'debited',        v_debited,
    'amount_usd',     v_exec.amount,
    'transaction_id', v_txn_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_complete_manual_refill(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_complete_manual_refill(uuid,text) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 6. admin_switch_gateway_to_manual — same guard, same preconditions.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_switch_gateway_to_manual(
  p_execution_id uuid,
  p_note         text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_exec RECORD;
BEGIN
  PERFORM public.assert_admin();

  SELECT * INTO v_exec
  FROM public.topup_executions
  WHERE id = p_execution_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Execution % not found', p_execution_id USING ERRCODE = 'KS461';
  END IF;

  IF v_exec.status IN ('success', 'failed', 'refunded', 'cancelled') THEN
    RAISE EXCEPTION 'Execution % is already %', p_execution_id, v_exec.status
      USING ERRCODE = 'KS462';
  END IF;

  UPDATE public.topup_executions
  SET fulfillment_gateway = 'MANUAL',
      api_provider = NULL
  WHERE id = p_execution_id;

  PERFORM public.admin_log(
    'refill.switch_to_manual', 'topup_execution', p_execution_id::text,
    jsonb_build_object('gateway', v_exec.fulfillment_gateway, 'api_provider', v_exec.api_provider),
    jsonb_build_object('gateway', 'MANUAL', 'api_provider', NULL),
    p_note
  );

  RETURN jsonb_build_object('success', true, 'execution_id', p_execution_id);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_switch_gateway_to_manual(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_switch_gateway_to_manual(uuid,text) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 7. admin_fail_refill — the other half of the queue. Marks an execution failed
--    and refunds it if (and only if) it was actually debited.
--
--    The credit is INLINE rather than a call to credit_wallet_for_refund: F1's
--    guard on that function is absolute — ANY non-service_role JWT at ANY depth
--    raises KS403 — so it is unreachable from an authenticated-invoked RPC.
--    Same constraint G3 hit. The property worth preserving is that this only
--    ever credits money it can first prove left the same wallet under the same
--    execution id.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_fail_refill(
  p_execution_id uuid,
  p_reason       text,
  p_refund       boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_exec     RECORD;
  v_debit    RECORD;
  v_wallet   RECORD;
  v_after    numeric;
  v_txn_id   uuid;
  v_refunded boolean := false;
BEGIN
  PERFORM public.assert_admin();

  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'A reason is required' USING ERRCODE = 'KS464';
  END IF;

  SELECT * INTO v_exec FROM public.topup_executions WHERE id = p_execution_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Execution % not found', p_execution_id USING ERRCODE = 'KS461';
  END IF;

  IF v_exec.status IN ('failed', 'refunded', 'cancelled') THEN
    RAISE EXCEPTION 'Execution % is already %', p_execution_id, v_exec.status
      USING ERRCODE = 'KS462';
  END IF;

  IF p_refund THEN
    SELECT * INTO v_debit
    FROM public.wallet_transactions
    WHERE reference_id = 'exec_' || p_execution_id::text
      AND type = 'topup_debit'
      AND status = 'completed';

    IF FOUND
       AND NOT EXISTS (
         SELECT 1 FROM public.wallet_transactions
         WHERE reference_id = 'refund_exec_' || p_execution_id::text
           AND type = 'refund'
       ) THEN
      SELECT * INTO v_wallet FROM public.wallets WHERE user_id = v_debit.user_id FOR UPDATE;

      IF FOUND THEN
        v_after := v_wallet.balance + v_debit.amount;

        UPDATE public.wallets
        SET balance = v_after,
            -- Mirrors credit_wallet_for_refund: a refund un-spends, it does not
            -- deposit. Leaving total_spent alone would inflate every lifetime
            -- spend figure the admin dashboards show.
            total_spent = GREATEST(0, total_spent - v_debit.amount)
        WHERE id = v_wallet.id;

        INSERT INTO public.wallet_transactions (
          wallet_id, user_id, type, amount, balance_before, balance_after,
          description, reference_id, sim_line_id, status, metadata
        ) VALUES (
          v_wallet.id, v_debit.user_id, 'refund', v_debit.amount,
          v_wallet.balance, v_after,
          'Refund: ' || left(p_reason, 180),
          'refund_exec_' || p_execution_id::text,
          v_exec.sim_line_id, 'completed',
          jsonb_build_object('refunded_by_admin', true, 'execution_id', p_execution_id::text)
        ) RETURNING id INTO v_txn_id;

        v_refunded := true;
      END IF;
    END IF;
  END IF;

  UPDATE public.topup_executions
  SET status = CASE WHEN v_refunded THEN 'refunded' ELSE 'failed' END,
      completed_at = now(),
      failure_reason = left(p_reason, 500)
  WHERE id = p_execution_id;

  PERFORM public.admin_log(
    'refill.fail', 'topup_execution', p_execution_id::text,
    jsonb_build_object('status', v_exec.status),
    jsonb_build_object('status', CASE WHEN v_refunded THEN 'refunded' ELSE 'failed' END,
                       'refunded', v_refunded, 'txn_id', v_txn_id),
    p_reason
  );

  RETURN jsonb_build_object('success', true, 'refunded', v_refunded, 'transaction_id', v_txn_id);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_fail_refill(uuid,text,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_fail_refill(uuid,text,boolean) TO authenticated, service_role;

COMMENT ON FUNCTION public.admin_fail_refill(uuid,text,boolean) IS
  'H1: marks a queued refill failed, refunding only a debit it can prove exists under the same exec_<id> reference. Credit is inline because F1 makes credit_wallet_for_refund unreachable from an authenticated caller at any nesting depth.';
