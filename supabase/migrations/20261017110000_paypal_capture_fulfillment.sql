-- Task 5: one verified provider capture, one atomic local fulfillment.
-- Compatible with both the live credit RPC and the pending M2 funding trigger.
BEGIN;
ALTER TABLE public.paypal_orders ADD COLUMN merchant_id text;
CREATE TABLE public.paypal_capture_receipts (
  capture_id text PRIMARY KEY,
  order_id text NOT NULL UNIQUE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  kind text NOT NULL CHECK (kind IN ('deposit','plan')),
  amount_usd numeric NOT NULL CHECK (amount_usd>0),
  currency text NOT NULL CHECK (currency='USD'),
  merchant_id text NOT NULL CHECK (merchant_id<>''),
  transaction_id uuid REFERENCES public.wallet_transactions(id) ON DELETE SET NULL,
  funding_lot_id uuid REFERENCES public.wallet_funding_lots(id) ON DELETE SET NULL,
  plan_payment_id uuid REFERENCES public.plan_payments(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.paypal_capture_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.paypal_capture_receipts FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.fulfill_paypal_capture(p_order_id text,p_evidence jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_order public.paypal_orders;
  v_receipt public.paypal_capture_receipts;
  v_capture text:=p_evidence->>'capture_id';
  v_amount numeric;
  v_owner uuid;
  v_tx public.wallet_transactions;
  v_lot public.wallet_funding_lots;
  v_wallet public.wallets;
  v_plan public.plan_payments;
  v_tx_id uuid;
  v_count integer;
  v_duplicate boolean:=false;
  v_metadata jsonb;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE insufficient_privilege; END IF;
  IF p_order_id IS NULL OR p_order_id='' OR v_capture IS NULL OR v_capture='' OR v_capture=p_order_id OR
     p_evidence->>'status' IS DISTINCT FROM 'COMPLETED' OR p_evidence->>'order_id' IS DISTINCT FROM p_order_id OR
     p_evidence->>'currency' IS DISTINCT FROM 'USD' OR coalesce(p_evidence->>'merchant_id','')='' OR
     p_evidence->>'merchant_id' IS DISTINCT FROM p_evidence->>'expected_merchant_id' OR
     p_evidence->>'source' NOT IN ('capture_endpoint','webhook') OR p_evidence->>'source' IS NULL OR
     coalesce(p_evidence->>'amount','') !~ '^[0-9]+(\.[0-9]{1,2})?$' THEN
    RAISE EXCEPTION 'Invalid verified capture evidence' USING ERRCODE='22023';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_each(jsonb_build_object('fee',p_evidence->'paypal_fee','net',p_evidence->'net')) f
    WHERE f.value<>'null'::jsonb AND (f.value->>'currency_code' IS DISTINCT FROM 'USD' OR
      coalesce(f.value->>'value','') !~ '^[0-9]+(\.[0-9]{1,2})?$')) THEN
    RAISE EXCEPTION 'Invalid capture fee evidence' USING ERRCODE='22023';
  END IF;
  v_amount:=(p_evidence->>'amount')::numeric;
  v_owner:=(p_evidence->>'user_id')::uuid;
  IF v_amount<=0 OR v_owner IS NULL THEN RAISE EXCEPTION 'Invalid payment identity or amount' USING ERRCODE='22023'; END IF;
  -- Capture identity is global, including attempts to redirect it to another order/user.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('paypal-capture:'||v_capture,0));
  SELECT * INTO v_order FROM public.paypal_orders WHERE order_id=p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.user_id IS DISTINCT FROM v_owner OR v_order.kind IS DISTINCT FROM p_evidence->>'kind' OR
     v_order.amount_usd IS DISTINCT FROM v_amount OR
     (v_order.merchant_id IS NOT NULL AND v_order.merchant_id<>p_evidence->>'merchant_id') OR
     (v_order.kind='plan' AND (v_order.plan IS DISTINCT FROM p_evidence->>'plan' OR
       v_order.sim_line_id IS DISTINCT FROM nullif(p_evidence->>'sim_line_id','')::uuid)) THEN
    RAISE EXCEPTION 'Stored order evidence mismatch' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_receipt FROM public.paypal_capture_receipts WHERE capture_id=v_capture OR order_id=p_order_id;
  IF FOUND THEN
    IF v_receipt.capture_id<>v_capture OR v_receipt.order_id<>p_order_id OR v_receipt.user_id IS DISTINCT FROM v_owner OR
       v_receipt.amount_usd<>v_amount OR v_receipt.kind<>v_order.kind OR v_receipt.merchant_id<>p_evidence->>'merchant_id' THEN
      RAISE EXCEPTION 'Capture identity conflict' USING ERRCODE='22023';
    END IF;
    UPDATE public.paypal_orders SET status='captured',captured_at=coalesce(captured_at,now())
      WHERE order_id=p_order_id AND status<>'captured';
    RETURN jsonb_build_object('success',true,'duplicate',true,'capture_id',v_capture,'transaction_id',v_receipt.transaction_id);
  END IF;
  v_metadata:=jsonb_build_object('method','paypal','order_id',p_order_id,'paypal_order_id',p_order_id,
    'paypal_capture_id',v_capture,'currency','USD','source',p_evidence->>'source','event_id',p_evidence->>'event_id',
    'gross',v_amount,'paypal_fee',nullif(p_evidence->'paypal_fee'->>'value','')::numeric,
    'net',nullif(p_evidence->'net'->>'value','')::numeric);
  IF (v_order.kind='deposit' AND EXISTS(SELECT 1 FROM public.plan_payments WHERE capture_id=v_capture)) OR
     (v_order.kind='plan' AND (EXISTS(SELECT 1 FROM public.wallet_transactions WHERE type='deposit' AND reference_id='paypal_'||v_capture) OR
       EXISTS(SELECT 1 FROM public.wallet_funding_lots WHERE original_reference_id=v_capture))) THEN
    RAISE EXCEPTION 'Capture purpose conflict' USING ERRCODE='22023';
  END IF;
  IF v_order.kind='deposit' THEN
    -- Use the same wallet lock order as pending M2, before calling its credit RPC.
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('wallet:'||v_owner::text,0));
    SELECT * INTO v_wallet FROM public.wallets WHERE user_id=v_owner FOR UPDATE;
    IF FOUND AND (v_wallet.currency IS DISTINCT FROM 'USD' OR v_wallet.balance IS NULL OR v_wallet.total_deposited IS NULL) THEN
      RAISE EXCEPTION 'Wallet requires reconciliation';
    END IF;
    -- Never turn the historical order-ID fallback or a second capture into a
    -- second deposit. Ambiguous preexisting money needs operator reconciliation.
    IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE type='deposit' AND (
      reference_id='paypal_'||p_order_id OR ((metadata->>'order_id'=p_order_id OR metadata->>'paypal_order_id'=p_order_id)
        AND reference_id IS DISTINCT FROM 'paypal_'||v_capture))) OR
       EXISTS (SELECT 1 FROM public.wallet_funding_lots WHERE original_reference_id=p_order_id OR
         (original_order_id=p_order_id AND original_reference_id IS DISTINCT FROM v_capture)) THEN
      RAISE EXCEPTION 'Legacy PayPal identity requires reconciliation';
    END IF;
    SELECT * INTO v_tx FROM public.wallet_transactions WHERE type='deposit' AND reference_id='paypal_'||v_capture;
    IF FOUND THEN
      IF v_wallet.id IS NULL OR v_wallet.id IS DISTINCT FROM v_tx.wallet_id OR v_tx.user_id IS DISTINCT FROM v_owner OR v_tx.amount<>v_amount OR v_tx.status IS DISTINCT FROM 'completed' OR
         v_tx.balance_after-v_tx.balance_before<>v_amount OR
         (v_tx.metadata->>'paypal_capture_id' IS NOT NULL AND v_tx.metadata->>'paypal_capture_id'<>v_capture) OR
         (coalesce(v_tx.metadata->>'order_id',v_tx.metadata->>'paypal_order_id') IS NOT NULL AND
          coalesce(v_tx.metadata->>'order_id',v_tx.metadata->>'paypal_order_id')<>p_order_id) THEN
        RAISE EXCEPTION 'Existing deposit requires reconciliation';
      END IF;
      v_tx_id:=v_tx.id; v_duplicate:=true;
    ELSE
      IF EXISTS(SELECT 1 FROM public.wallet_funding_lots WHERE original_reference_id=v_capture) THEN
        RAISE EXCEPTION 'Orphan funding source requires reconciliation';
      END IF;
      v_tx_id:=public.credit_wallet_for_deposit(v_owner,v_amount,'PayPal wallet deposit','paypal_'||v_capture,v_metadata);
    END IF;
    SELECT count(*) INTO v_count FROM public.wallet_funding_lots WHERE original_reference_id=v_capture;
    SELECT * INTO v_lot FROM public.wallet_funding_lots WHERE original_reference_id=v_capture LIMIT 1;
    IF v_count<>1 OR v_lot.user_id IS DISTINCT FROM v_owner OR v_lot.wallet_id IS DISTINCT FROM
       (SELECT wallet_id FROM public.wallet_transactions WHERE id=v_tx_id) OR v_lot.funded_amount<>v_amount OR
       v_lot.currency<>'USD' OR v_lot.origin_type<>'paypal_deposit' OR NOT v_lot.is_refundable OR
       (v_lot.original_order_id IS NOT NULL AND v_lot.original_order_id<>p_order_id) THEN
      RAISE EXCEPTION 'Capture funding source requires reconciliation';
    END IF;
  ELSE
    -- Preserve fulfillment of previously created direct-plan orders. New order
    -- creation remains deposit-only; no plan is ever treated as a wallet deposit.
    IF v_order.sim_line_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sim_lines WHERE id=v_order.sim_line_id AND user_id=v_owner) THEN
      RAISE EXCEPTION 'Plan line ownership mismatch' USING ERRCODE='22023';
    END IF;
    SELECT * INTO v_plan FROM public.plan_payments WHERE capture_id=v_capture;
    IF FOUND THEN
      IF v_plan.user_id IS DISTINCT FROM v_owner OR v_plan.order_id IS DISTINCT FROM p_order_id OR
         v_plan.gross_usd<>v_amount OR v_plan.kind<>'plan' OR v_plan.sim_line_id IS DISTINCT FROM v_order.sim_line_id THEN
        RAISE EXCEPTION 'Existing plan payment identity conflict';
      END IF;
      v_duplicate:=true;
    ELSE
      INSERT INTO public.plan_payments(user_id,sim_line_id,capture_id,order_id,kind,gross_usd,paypal_fee_usd,net_usd,metadata)
      VALUES(v_owner,v_order.sim_line_id,v_capture,p_order_id,'plan',v_amount,
        nullif(p_evidence->'paypal_fee'->>'value','')::numeric,nullif(p_evidence->'net'->>'value','')::numeric,
        v_metadata||jsonb_build_object('plan',v_order.plan)) RETURNING * INTO v_plan;
    END IF;
  END IF;
  INSERT INTO public.paypal_capture_receipts(capture_id,order_id,user_id,kind,amount_usd,currency,merchant_id,transaction_id,funding_lot_id,plan_payment_id)
  VALUES(v_capture,p_order_id,v_owner,v_order.kind,v_amount,'USD',p_evidence->>'merchant_id',v_tx_id,v_lot.id,v_plan.id);
  -- Success visible to checkout only after the receipt, ledger and funding lot commit.
  UPDATE public.paypal_orders SET status='captured',captured_at=coalesce(captured_at,now()),
    merchant_id=coalesce(merchant_id,p_evidence->>'merchant_id') WHERE order_id=p_order_id;
  RETURN jsonb_build_object('success',true,'duplicate',v_duplicate,'capture_id',v_capture,'transaction_id',v_tx_id);
END $$;
REVOKE ALL ON FUNCTION public.fulfill_paypal_capture(text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fulfill_paypal_capture(text,jsonb) TO service_role;
COMMIT;
