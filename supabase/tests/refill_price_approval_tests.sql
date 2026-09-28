-- Run against an existing awaiting_approval sandbox refill. Everything rolls back;
-- pending status is never visible to workers and no supplier or wallet API is called.
BEGIN;
DO $$
DECLARE
  e public.topup_executions;
  q uuid;
  response jsonb;
  schedule_cap numeric;
  denied boolean;
  snapshot jsonb;
  probe public.topup_executions;
BEGIN
  SELECT * INTO e FROM public.topup_executions
    WHERE status = 'awaiting_approval' AND execution_type IN ('refill_mini','refill_custom')
      AND user_id IS NOT NULL AND NOT carrier_in_flight AND reloadly_transaction_id IS NULL
    ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Test needs an unsubmitted sandbox refill awaiting approval'; END IF;
  SELECT max_authorized_usd INTO schedule_cap FROM public.scheduled_topups WHERE id=e.scheduled_topup_id;
  snapshot := to_jsonb(e);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',e.user_id,'role','authenticated')::text,true);
  q := public.request_refill_approval_quote(e.id);
  ASSERT q = public.request_refill_approval_quote(e.id), 'Repeated reviews must share their recent request';
  ASSERT (SELECT to_jsonb(t) = snapshot FROM public.topup_executions t WHERE id=e.id), 'Price check must not mutate execution or cap';
  UPDATE public.refill_approval_quotes SET status='ready', route=jsonb_build_object(
    'provider','zendit','offerId','approval-test-only','offerValue',NULL,
    'costUsd',7.10,'feeUsd',.21,'totalChargeUsd',7.31,'targetLocalValue',20,'targetLocalCurrency','SAR'
  ) WHERE id=q;

  denied := false;
  BEGIN PERFORM public.approve_refill_execution_quote(q,3.50);
  EXCEPTION WHEN raise_exception THEN denied:=true; END;
  ASSERT denied, 'Stale display amount 3.50 must not authorize 7.31';

  UPDATE public.refill_approval_quotes SET expires_at=now()-interval '1 second' WHERE id=q;
  denied := false;
  BEGIN PERFORM public.approve_refill_execution_quote(q,7.31);
  EXCEPTION WHEN raise_exception THEN denied:=true; END;
  ASSERT denied, 'Expired quotes must not queue refills';
  UPDATE public.refill_approval_quotes SET expires_at=now()+interval '1 minute' WHERE id=q;

  UPDATE public.topup_executions SET amount=amount+.01 WHERE id=e.id;
  denied := false;
  BEGIN PERFORM public.approve_refill_execution_quote(q,7.31);
  EXCEPTION WHEN raise_exception THEN denied:=true; END;
  ASSERT denied, 'Changes during the dialog must invalidate its quote';
  UPDATE public.topup_executions SET amount=e.amount WHERE id=e.id;

  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated')::text,true);
  denied := false;
  BEGIN PERFORM public.request_refill_approval_quote(e.id);
  EXCEPTION WHEN raise_exception THEN denied:=true; END;
  ASSERT denied, 'Another customer cannot request this refill quote';
  denied := false;
  BEGIN PERFORM public.approve_refill_execution_quote(q,7.31);
  EXCEPTION WHEN raise_exception THEN denied:=true; END;
  ASSERT denied, 'Another customer cannot approve this quote';

  PERFORM set_config('request.jwt.claims','{}',true);
  denied := false;
  BEGIN PERFORM public.request_refill_approval_quote(e.id);
  EXCEPTION WHEN raise_exception THEN denied:=true; END;
  ASSERT denied, 'Unauthenticated requests must fail';
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',e.user_id,'role','authenticated')::text,true);

  response := public.approve_refill_execution_quote(q,7.31);
  ASSERT response->>'status'='pending', 'Reviewed price must queue successfully';
  ASSERT (SELECT status='pending' AND amount=7.31 AND max_authorized_usd=7.31
      AND api_provider='zendit' AND offer_id='approval-test-only' AND quote_id=q
      AND processing_since IS NULL FROM public.topup_executions WHERE id=e.id), 'Approval must atomically store the reviewed route and exact cap';
  ASSERT (SELECT max_authorized_usd IS NOT DISTINCT FROM schedule_cap
    FROM public.scheduled_topups WHERE id=e.scheduled_topup_id), 'One-time approval must not change future spending authorization';
  response := public.approve_refill_execution_quote(q,7.31);
  ASSERT response->>'success'='true', 'Duplicate approval must return success without requeueing';

  ASSERT NOT has_table_privilege('authenticated','public.refill_approval_quotes','INSERT'), 'Customer cannot forge quotes';
  ASSERT NOT has_table_privilege('authenticated','public.refill_approval_quotes','UPDATE'), 'Customer cannot change a quote';
  ASSERT NOT has_function_privilege('anon','public.request_refill_approval_quote(uuid)','EXECUTE'), 'Anonymous quote RPC must be revoked';
  ASSERT NOT has_function_privilege('authenticated','public.claim_refill_approval_quotes(text)','EXECUTE'), 'Only workers can claim price jobs';

  INSERT INTO public.topup_executions(sim_line_id,user_id,amount,base_cost_usd,max_authorized_usd,
    currency,status,execution_type,payment_gateway_code,api_provider,offer_id,engine_version)
  VALUES(e.sim_line_id,e.user_id,7.10,7.10,1.00,'USD','awaiting_approval','refill_mini','wallet','zendit',e.offer_id,2)
  RETURNING * INTO probe;
  ASSERT probe.amount > 1 AND probe.max_authorized_usd=1,
    'Fee calculation must not increase an explicit authorization limit';
END;
$$;
SELECT 'All approval database assertions passed; changes rolled back.' AS result;
ROLLBACK;
