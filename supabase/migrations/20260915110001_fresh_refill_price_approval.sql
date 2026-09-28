-- Approval quotes are read-only supplier checks. They never reserve funds or submit a refill.
CREATE TABLE public.refill_approval_quotes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  execution_id uuid NOT NULL REFERENCES public.topup_executions(id) ON DELETE CASCADE,
  requested_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  execution_snapshot jsonb NOT NULL,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','processing','ready','failed','approved')),
  route jsonb,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '2 minutes'
);
CREATE INDEX refill_approval_quotes_pending ON public.refill_approval_quotes(created_at) WHERE status = 'queued';
CREATE INDEX refill_approval_quotes_execution ON public.refill_approval_quotes(execution_id, created_at DESC);
CREATE INDEX refill_approval_quotes_requester ON public.refill_approval_quotes(requested_by);
ALTER TABLE public.refill_approval_quotes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.refill_approval_quotes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.refill_approval_quotes TO authenticated;
GRANT ALL ON public.refill_approval_quotes TO service_role;
CREATE POLICY read_own_refill_quotes ON public.refill_approval_quotes FOR SELECT TO authenticated
  USING (requested_by = (SELECT auth.uid()));

CREATE OR REPLACE FUNCTION public.request_refill_approval_quote(p_execution_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_exec public.topup_executions;
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT * INTO v_exec FROM public.topup_executions WHERE id = p_execution_id FOR UPDATE;
  IF NOT FOUND OR NOT (
    coalesce(v_exec.user_id = auth.uid(),false) OR EXISTS (
      SELECT 1 FROM public.sim_lines sl WHERE sl.id = v_exec.sim_line_id
      AND (sl.user_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.household_members hm WHERE hm.owner_id = sl.user_id
        AND hm.member_id = auth.uid() AND hm.invite_status = 'accepted' AND hm.role = 'manager'))
    )) THEN RAISE EXCEPTION 'Not authorized to review this refill'; END IF;
  IF v_exec.status <> 'awaiting_approval' OR v_exec.execution_type NOT IN ('refill_mini','refill_custom')
     OR v_exec.carrier_in_flight OR v_exec.reloadly_transaction_id IS NOT NULL THEN
    RAISE EXCEPTION 'This refill is no longer waiting for price approval. Refresh its status.';
  END IF;
  IF v_exec.scheduled_topup_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.scheduled_topups WHERE id = v_exec.scheduled_topup_id AND is_active
  ) THEN RAISE EXCEPTION 'This refill schedule is paused'; END IF;
  -- Repeated taps share the same recent request; retries after a crashed worker can start anew.
  SELECT id INTO v_id FROM public.refill_approval_quotes
  WHERE execution_id = p_execution_id AND requested_by = auth.uid()
    AND execution_snapshot = to_jsonb(v_exec)
    AND status IN ('queued','processing','ready') AND created_at > now() - interval '45 seconds'
    AND expires_at > now() + interval '15 seconds'
  ORDER BY created_at DESC LIMIT 1;
  IF v_id IS NULL THEN
    INSERT INTO public.refill_approval_quotes(execution_id,requested_by,execution_snapshot)
    VALUES (p_execution_id,auth.uid(),to_jsonb(v_exec)) RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.request_refill_approval_quote(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_refill_approval_quote(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.claim_refill_approval_quotes(p_execution_type text)
RETURNS SETOF public.refill_approval_quotes LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$
  WITH jobs AS (
    SELECT q.id FROM public.refill_approval_quotes q
    WHERE q.status = 'queued' AND q.expires_at > now()
      AND q.execution_snapshot->>'execution_type' = p_execution_type
    ORDER BY q.created_at LIMIT 5 FOR UPDATE SKIP LOCKED
  )
  UPDATE public.refill_approval_quotes q SET status = 'processing'
  FROM jobs WHERE q.id = jobs.id RETURNING q.*;
$$;
REVOKE ALL ON FUNCTION public.claim_refill_approval_quotes(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_refill_approval_quotes(text) TO service_role;

CREATE OR REPLACE FUNCTION public.approve_refill_execution_quote(p_quote_id uuid, p_expected_amount numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_quote public.refill_approval_quotes;
  v_exec public.topup_executions;
  v_total numeric;
  v_cost numeric;
  v_fee numeric;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT * INTO v_quote FROM public.refill_approval_quotes WHERE id = p_quote_id FOR UPDATE;
  IF NOT FOUND OR v_quote.requested_by <> auth.uid() THEN RAISE EXCEPTION 'Not authorized to approve this quote'; END IF;
  SELECT * INTO v_exec FROM public.topup_executions WHERE id = v_quote.execution_id FOR UPDATE;
  IF NOT FOUND OR NOT (
    coalesce(v_exec.user_id = auth.uid(),false) OR EXISTS (
      SELECT 1 FROM public.sim_lines sl WHERE sl.id = v_exec.sim_line_id
      AND (sl.user_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.household_members hm WHERE hm.owner_id = sl.user_id
        AND hm.member_id = auth.uid() AND hm.invite_status = 'accepted' AND hm.role = 'manager'))
    )) THEN RAISE EXCEPTION 'Not authorized to approve this refill'; END IF;
  v_total := (v_quote.route->>'totalChargeUsd')::numeric;
  v_cost := (v_quote.route->>'costUsd')::numeric;
  v_fee := (v_quote.route->>'feeUsd')::numeric;
  IF p_expected_amount IS NULL OR v_total IS NULL OR p_expected_amount IS DISTINCT FROM v_total
    OR NOT (v_total BETWEEN 0.01 AND 1000) OR v_cost IS NULL OR NOT (v_cost > 0 AND v_cost <= v_total)
    OR v_fee IS NULL OR NOT (v_fee >= 0 AND v_fee <= v_total) OR round(v_cost + v_fee,2) <> v_total
    OR nullif(v_quote.route->>'provider','') IS NULL OR nullif(v_quote.route->>'offerId','') IS NULL THEN
    RAISE EXCEPTION 'The price is invalid or changed. Review a fresh quote.';
  END IF;
  -- Idempotent repeat after a lost response: never enqueue a second purchase.
  IF v_quote.status = 'approved' THEN
    RETURN jsonb_build_object('success',true,'status',v_exec.status,'execution_id',v_exec.id);
  END IF;
  IF v_quote.status <> 'ready' OR v_quote.expires_at <= now() THEN
    RAISE EXCEPTION 'This price quote expired or is not ready. Review a fresh quote.';
  END IF;
  IF v_exec.status <> 'awaiting_approval' OR to_jsonb(v_exec) IS DISTINCT FROM v_quote.execution_snapshot
    OR v_exec.carrier_in_flight OR v_exec.reloadly_transaction_id IS NOT NULL THEN
    RAISE EXCEPTION 'This refill changed while you reviewed it. Refresh and review its current price.';
  END IF;
  IF v_exec.scheduled_topup_id IS NOT NULL THEN
    PERFORM 1 FROM public.scheduled_topups WHERE id = v_exec.scheduled_topup_id AND is_active FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'This refill schedule is paused'; END IF;
  END IF;
  UPDATE public.topup_executions SET
    amount = v_total, base_cost_usd = v_cost, app_fee_usd = v_fee, max_authorized_usd = v_total,
    api_provider = v_quote.route->>'provider', offer_id = v_quote.route->>'offerId',
    offer_value = (v_quote.route->>'offerValue')::numeric,
    target_local_value = (v_quote.route->>'targetLocalValue')::numeric,
    target_local_currency = v_quote.route->>'targetLocalCurrency',
    quoted_cost_usd = v_cost, quoted_fee_usd = v_fee, quote_id = p_quote_id,
    status = 'pending', failure_reason = NULL, processing_since = NULL, pre_processing_status = NULL,
    execution_time = now(), updated_at = now()
  WHERE id = v_exec.id;
  -- Approval is for this refill only. Future automatic spending remains separately authorized.
  UPDATE public.refill_approval_quotes SET status = 'approved' WHERE id = p_quote_id;
  RETURN jsonb_build_object('success',true,'status','pending','execution_id',v_exec.id,'amount',v_total);
END;
$$;
REVOKE ALL ON FUNCTION public.approve_refill_execution_quote(uuid,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_refill_execution_quote(uuid,numeric) TO authenticated;

-- Older app versions must not approve a stale display value without a supplier quote.
CREATE OR REPLACE FUNCTION public.approve_refill_execution(p_execution_id uuid,p_new_max_authorized_usd numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  RAISE EXCEPTION 'Please update or reload KeepSIMs, then review the current refill price before approving.';
END;
$$;

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

      -- Fee calculation must preserve an explicit customer spending limit.
      IF NEW.max_authorized_usd IS NULL THEN
        NEW.max_authorized_usd := NEW.amount;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
