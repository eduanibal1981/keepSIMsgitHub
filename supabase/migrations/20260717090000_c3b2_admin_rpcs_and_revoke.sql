-- C3b-2 (4/4): the lockdown itself. Every write path the client (user app OR
-- admin app) had on topup_executions now goes through a SECURITY DEFINER RPC,
-- so the table grants and the user-scoped write policies go away. Workers use
-- service_role and are unaffected.

-- The admin app's two operational tools, previously raw UPDATEs riding the
-- power-user RLS policy through the shared 'authenticated' role.
CREATE OR REPLACE FUNCTION public.admin_complete_manual_refill(p_execution_id uuid)
RETURNS SETOF topup_executions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF auth.uid() IS NOT NULL
     AND NOT (public.is_power_user(auth.uid()) AND NOT public.is_user_suspended()) THEN
    RAISE EXCEPTION 'Power user access required';
  END IF;

  RETURN QUERY
  UPDATE public.topup_executions
  SET status = 'success',
      completed_at = now()
  WHERE id = p_execution_id
  RETURNING *;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_complete_manual_refill(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_complete_manual_refill(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_switch_gateway_to_manual(p_execution_id uuid)
RETURNS SETOF topup_executions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF auth.uid() IS NOT NULL
     AND NOT (public.is_power_user(auth.uid()) AND NOT public.is_user_suspended()) THEN
    RAISE EXCEPTION 'Power user access required';
  END IF;

  RETURN QUERY
  UPDATE public.topup_executions
  SET fulfillment_gateway = 'MANUAL',
      api_provider = NULL
  WHERE id = p_execution_id
  RETURNING *;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_switch_gateway_to_manual(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_switch_gateway_to_manual(uuid) TO authenticated;

-- The revoke. anon also loses the stray REFERENCES/TRIGGER it could never use
-- through PostgREST anyway; both roles keep SELECT (RLS scopes reads).
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.topup_executions FROM anon, authenticated;

-- Write policies are dead letters without grants; drop them so the posture is
-- readable from the policy list alone. SELECT policies stay.
DROP POLICY "Users can insert own topup executions" ON public.topup_executions;
DROP POLICY "Users can update own topup executions" ON public.topup_executions;
DROP POLICY "Allow power users full update on topup_executions" ON public.topup_executions;