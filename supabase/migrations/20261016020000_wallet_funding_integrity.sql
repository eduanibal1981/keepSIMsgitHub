-- All new ledger mutations book funding in the same transaction. No historical
-- balance/lot adjustment is performed: unmatched legacy reversals fail closed.
BEGIN;

-- Stop for reconciliation instead of silently repairing legacy money records.
DO $$
BEGIN
  IF EXISTS(SELECT 1 FROM public.wallets w WHERE w.balance IS DISTINCT FROM
    (SELECT coalesce(sum(l.remaining_amount),0) FROM public.wallet_funding_lots l WHERE l.wallet_id=w.id))
    OR EXISTS(SELECT 1 FROM public.wallets w WHERE w.balance<
      (SELECT coalesce(sum(h.amount),0) FROM public.wallet_holds h WHERE h.wallet_id=w.id AND h.status='active'))
    OR EXISTS(SELECT 1 FROM public.wallet_funding_lots l WHERE l.remaining_amount<
      (SELECT coalesce(sum(a.amount),0) FROM public.wallet_hold_allocations a
        JOIN public.wallet_holds h ON h.id=a.hold_id WHERE a.lot_id=l.id AND h.status='active')) THEN
    RAISE EXCEPTION 'Wallet funding reconciliation required before migration';
  END IF;
END;
$$;

-- Keep every captured discriminator and add the two real settlement producers.
-- The production fixture remains unchanged; this is the proposed schema repair.
ALTER TABLE public.wallet_transactions DROP CONSTRAINT wallet_transactions_type_check;
ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_type_check CHECK(type IN (
  'deposit','topup_debit','refund','referral_credit','referral_withdrawal','plan_fee_debit',
  'home_mode_debit','auto_fund','esim_purchase_debit','esim_purchase_refund','wallet_settlement',
  'wallet_forfeit','gift_sent','gift_received','admin_adjustment','offline_voucher_debit',
  'call_debit','call_refund','did_purchase_debit','refund_payout','verification_debit'));

CREATE TABLE public.wallet_transaction_funding (
  transaction_id uuid NOT NULL REFERENCES public.wallet_transactions(id) ON DELETE CASCADE,
  lot_id uuid NOT NULL REFERENCES public.wallet_funding_lots(id) ON DELETE CASCADE,
  amount numeric NOT NULL CHECK (amount>0),
  reversed_amount numeric NOT NULL DEFAULT 0 CHECK (reversed_amount>=0 AND reversed_amount<=amount),
  PRIMARY KEY(transaction_id,lot_id)
);
ALTER TABLE public.wallet_transaction_funding ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.wallet_transaction_funding FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.wallet_transaction_funding TO service_role;
CREATE INDEX wallet_transaction_funding_lot ON public.wallet_transaction_funding(lot_id);

CREATE FUNCTION public.wallet_lot_availability(p_user_id uuid)
RETURNS TABLE(lot_id uuid,available_amount numeric) LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT l.id,greatest(0,l.remaining_amount-coalesce((
    SELECT sum(a.amount) FROM public.wallet_hold_allocations a
    JOIN public.wallet_holds h ON h.id=a.hold_id
    WHERE a.lot_id=l.id AND h.status='active'
  ),0)) FROM public.wallet_funding_lots l
  JOIN public.wallets w ON w.id=l.wallet_id AND w.user_id=l.user_id AND w.currency=l.currency
  WHERE l.user_id=p_user_id AND l.status IN ('active','partially_refunded') AND l.remaining_amount>0;
$$;
REVOKE ALL ON FUNCTION public.wallet_lot_availability(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.wallet_lot_availability(uuid) TO service_role;

-- No repair is inferred here. Corrupt legacy funding blocks new money actions.
CREATE FUNCTION public.assert_wallet_funding_integrity(p_wallet_id uuid,p_expected_balance numeric DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE w public.wallets; expected numeric;
BEGIN
 SELECT * INTO w FROM public.wallets WHERE id=p_wallet_id FOR UPDATE;
 expected:=coalesce(p_expected_balance,w.balance);
 IF w.id IS NULL OR w.user_id IS NULL OR w.currency IS DISTINCT FROM 'USD' OR expected IS NULL
   OR expected::text IN ('NaN','Infinity','-Infinity') OR expected<>round(expected,2)
   OR expected IS DISTINCT FROM (SELECT coalesce(sum(remaining_amount),0) FROM public.wallet_funding_lots WHERE wallet_id=w.id)
   OR EXISTS(SELECT 1 FROM public.wallet_funding_lots WHERE wallet_id=w.id AND
     (user_id IS DISTINCT FROM w.user_id OR currency IS DISTINCT FROM w.currency OR remaining_amount<>round(remaining_amount,2)
      OR funded_amount::text IN ('NaN','Infinity','-Infinity') OR remaining_amount::text IN ('NaN','Infinity','-Infinity')))
   OR expected<(SELECT coalesce(sum(amount),0) FROM public.wallet_holds WHERE wallet_id=w.id AND status='active')
   OR EXISTS(SELECT 1 FROM public.wallet_holds h WHERE h.wallet_id=w.id AND h.status='active' AND
     (h.user_id IS DISTINCT FROM w.user_id OR h.currency IS DISTINCT FROM w.currency OR h.amount<>round(h.amount,2)
      OR h.amount::text IN ('NaN','Infinity','-Infinity')
      OR h.amount<>(SELECT coalesce(sum(amount),0) FROM public.wallet_hold_allocations WHERE hold_id=h.id)))
   OR EXISTS(SELECT 1 FROM public.wallet_hold_allocations a JOIN public.wallet_holds h ON h.id=a.hold_id
     JOIN public.wallet_funding_lots l ON l.id=a.lot_id WHERE h.status IN ('active','captured')
       AND (h.wallet_id=w.id OR l.wallet_id=w.id) AND
       (h.wallet_id IS DISTINCT FROM l.wallet_id OR h.user_id IS DISTINCT FROM l.user_id OR h.currency IS DISTINCT FROM l.currency))
   OR EXISTS(SELECT 1 FROM public.wallet_funding_lots l WHERE l.wallet_id=w.id AND l.remaining_amount<
     (SELECT coalesce(sum(a.amount),0) FROM public.wallet_hold_allocations a JOIN public.wallet_holds h ON h.id=a.hold_id
       WHERE a.lot_id=l.id AND h.status='active')) THEN
   RAISE EXCEPTION 'Funding reconciliation required: balance, reservation or funding binding';
 END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.assert_wallet_funding_integrity(uuid,numeric) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.assert_wallet_funding_integrity(uuid,numeric) TO service_role;

CREATE FUNCTION public.book_wallet_transaction_funding()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_wallet public.wallets;
  v_hold public.wallet_holds;
  v_lot record;
  v_delta numeric:=NEW.balance_after-NEW.balance_before;
  v_needed numeric:=abs(v_delta);
  v_take numeric;
  v_held numeric;
  v_origin text;
  v_capture text;
  v_original uuid;
  v_original_type text;
  v_original_amount numeric;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed' THEN RETURN NEW; END IF;
  SELECT * INTO v_wallet FROM public.wallets WHERE id=NEW.wallet_id AND user_id=NEW.user_id FOR UPDATE;
  -- The existing trusted account-purge function writes its settlement ledger
  -- before zeroing/anonymizing the wallet. Complete that specific legacy delta
  -- here; reservation and lot checks below still apply and roll back together.
  IF NEW.type IN ('wallet_forfeit','wallet_settlement') AND v_wallet.balance=NEW.balance_before
    AND NEW.balance_after=0 AND NEW.amount=NEW.balance_before THEN
    UPDATE public.wallets SET balance=0,updated_at=now() WHERE id=v_wallet.id;
    v_wallet.balance:=0;
  END IF;
  IF v_wallet.id IS NULL OR v_wallet.currency IS DISTINCT FROM 'USD'
    OR v_wallet.balance IS DISTINCT FROM NEW.balance_after
    OR abs(v_delta) IS DISTINCT FROM NEW.amount OR NEW.amount<=0
    OR NEW.amount::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'Wallet ledger delta mismatch' USING ERRCODE='23514';
  END IF;
  IF (NEW.type IN ('deposit','auto_fund','referral_credit','gift_received','refund','esim_purchase_refund','call_refund') AND v_delta<=0)
    OR (NEW.type NOT IN ('deposit','auto_fund','referral_credit','gift_received','refund','esim_purchase_refund','call_refund','admin_adjustment') AND v_delta>=0) THEN
    RAISE EXCEPTION 'Wallet transaction direction mismatch' USING ERRCODE='23514';
  END IF;
  IF NEW.balance_before IS DISTINCT FROM (SELECT coalesce(sum(remaining_amount),0)
      FROM public.wallet_funding_lots WHERE wallet_id=NEW.wallet_id)
    OR EXISTS(SELECT 1 FROM public.wallet_funding_lots WHERE wallet_id=NEW.wallet_id
      AND (user_id IS DISTINCT FROM NEW.user_id OR currency IS DISTINCT FROM v_wallet.currency))
    OR EXISTS(SELECT 1 FROM public.wallet_holds WHERE wallet_id=NEW.wallet_id AND status='active'
      AND (user_id IS DISTINCT FROM NEW.user_id OR currency IS DISTINCT FROM v_wallet.currency)) THEN
    RAISE EXCEPTION 'Funding reconciliation required: wallet, owner or currency binding';
  END IF;
  IF EXISTS(SELECT 1 FROM public.wallet_hold_allocations a JOIN public.wallet_holds h ON h.id=a.hold_id
    JOIN public.wallet_funding_lots l ON l.id=a.lot_id WHERE h.status IN ('active','captured')
      AND (h.wallet_id=NEW.wallet_id OR l.wallet_id=NEW.wallet_id)
      AND (h.wallet_id IS DISTINCT FROM l.wallet_id OR h.user_id IS DISTINCT FROM l.user_id
        OR h.currency IS DISTINCT FROM l.currency)) THEN
    RAISE EXCEPTION 'Funding reconciliation required: foreign hold allocation';
  END IF;
  PERFORM public.assert_wallet_funding_integrity(NEW.wallet_id,NEW.balance_before);
  IF NEW.reference_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.wallet_transactions WHERE user_id=NEW.user_id AND type=NEW.type
      AND reference_id=NEW.reference_id AND id<>NEW.id AND status='completed'
  ) THEN RAISE EXCEPTION 'Duplicate wallet reference' USING ERRCODE='23505'; END IF;

  IF v_delta<0 THEN
    -- Capture has already transitioned its hold while holding the wallet lock.
    SELECT * INTO v_hold FROM public.wallet_holds
      WHERE id=nullif(NEW.metadata->>'hold_id','')::uuid AND wallet_id=NEW.wallet_id
        AND user_id=NEW.user_id AND currency=v_wallet.currency
        AND status='captured' AND amount>=NEW.amount
        AND NEW.reference_id='hold_'||id::text;
    IF nullif(NEW.metadata->>'hold_id','') IS NOT NULL AND v_hold.id IS NULL THEN
      RAISE EXCEPTION 'Invalid captured hold binding';
    END IF;
    IF NEW.type='refund_payout' AND NOT EXISTS(
      SELECT 1 FROM public.wallet_refund_items i JOIN public.wallet_refund_requests r ON r.id=i.refund_request_id
      WHERE i.id=nullif(NEW.metadata->>'refund_item_id','')::uuid AND r.wallet_id=NEW.wallet_id
        AND r.user_id=NEW.user_id AND i.status='completed' AND i.provider_outcome='completed'
        AND i.amount=NEW.amount AND i.currency=v_wallet.currency
        AND i.provider_refund_id=NEW.metadata->>'provider_refund_id' AND NEW.reference_id='refund_'||i.id::text
    ) THEN RAISE EXCEPTION 'Verified refund payout item required'; END IF;
    SELECT coalesce(sum(amount),0) INTO v_held FROM public.wallet_holds
      WHERE wallet_id=NEW.wallet_id AND status='active';
    IF NEW.balance_before-v_held<NEW.amount THEN
      RAISE EXCEPTION 'Insufficient available balance: funds are reserved' USING ERRCODE='23514';
    END IF;
    IF v_hold.id IS NOT NULL THEN
      FOR v_lot IN
        SELECT l.*,a.amount AS allocated FROM public.wallet_hold_allocations a
          JOIN public.wallet_funding_lots l ON l.id=a.lot_id
        WHERE a.hold_id=v_hold.id ORDER BY l.id FOR UPDATE OF l
      LOOP
        EXIT WHEN v_needed<=0;
        v_take:=least(v_needed,v_lot.allocated);
        IF v_lot.wallet_id<>NEW.wallet_id OR v_lot.user_id<>NEW.user_id
          OR v_lot.currency<>v_wallet.currency OR v_lot.remaining_amount<v_take
          OR v_lot.status NOT IN ('active','partially_refunded') THEN
          RAISE EXCEPTION 'Invalid hold allocation';
        END IF;
        UPDATE public.wallet_funding_lots SET remaining_amount=remaining_amount-v_take,
          status=CASE WHEN NEW.type='refund_payout' THEN
            CASE WHEN remaining_amount=v_take THEN 'fully_refunded' ELSE 'partially_refunded' END
            WHEN remaining_amount=v_take THEN 'fully_consumed' ELSE status END,
          updated_at=now() WHERE id=v_lot.id;
        INSERT INTO public.wallet_transaction_funding(transaction_id,lot_id,amount)
          VALUES(NEW.id,v_lot.id,v_take);
        v_needed:=v_needed-v_take;
      END LOOP;
    ELSE
      FOR v_lot IN
        SELECT l.*,a.available_amount FROM public.wallet_funding_lots l
          JOIN public.wallet_lot_availability(NEW.user_id) a ON a.lot_id=l.id
        -- Gifting retains its existing eligibility checks AND spends only
        -- transferable funding; promotional rewards cannot be laundered.
        WHERE (NEW.type<>'gift_sent' OR l.origin_type IN ('paypal_deposit','card_deposit','gift_received'))
          AND (NEW.type<>'refund_payout' OR l.id=(SELECT i.lot_id FROM public.wallet_refund_items i
            WHERE i.id=nullif(NEW.metadata->>'refund_item_id','')::uuid AND i.status='completed'))
        ORDER BY CASE WHEN l.is_refundable THEN 1 ELSE 0 END,l.created_at,l.id FOR UPDATE OF l
      LOOP
        EXIT WHEN v_needed<=0;
        v_take:=least(v_needed,v_lot.available_amount);
        IF v_take<=0 THEN CONTINUE; END IF;
        UPDATE public.wallet_funding_lots SET remaining_amount=remaining_amount-v_take,
          status=CASE WHEN NEW.type='refund_payout' THEN
            CASE WHEN remaining_amount=v_take THEN 'fully_refunded' ELSE 'partially_refunded' END
            WHEN remaining_amount=v_take THEN 'fully_consumed' ELSE status END,
          updated_at=now() WHERE id=v_lot.id;
        INSERT INTO public.wallet_transaction_funding(transaction_id,lot_id,amount) VALUES(NEW.id,v_lot.id,v_take);
        v_needed:=v_needed-v_take;
      END LOOP;
    END IF;
    IF v_needed<>0 THEN RAISE EXCEPTION 'Funding reconciliation required: debit not fully allocated'; END IF;
  ELSIF NEW.type IN ('refund','esim_purchase_refund','call_refund') THEN
    v_original:=nullif(NEW.metadata->>'reversal_of','')::uuid;
    IF v_original IS NULL THEN
      SELECT id INTO v_original FROM public.wallet_transactions
      WHERE user_id=NEW.user_id AND status='completed' AND balance_after<balance_before
        AND reference_id=CASE WHEN NEW.reference_id LIKE 'esim_refund_%'
          THEN 'esim_'||substr(NEW.reference_id,13)
          WHEN NEW.reference_id LIKE 'call_refund_%' THEN 'call_'||substr(NEW.reference_id,13)
          WHEN NEW.reference_id LIKE 'refund_%' THEN substr(NEW.reference_id,8) END;
    END IF;
    SELECT type,amount INTO v_original_type,v_original_amount FROM public.wallet_transactions WHERE id=v_original
      AND wallet_id=NEW.wallet_id AND user_id=NEW.user_id AND status='completed' AND balance_after<balance_before
      AND type IN ('topup_debit','plan_fee_debit','home_mode_debit','esim_purchase_debit',
        'offline_voucher_debit','call_debit','did_purchase_debit','verification_debit');
    IF NOT FOUND THEN RAISE EXCEPTION 'Funding reconciliation required: original debit unavailable'; END IF;
    IF v_original_amount IS DISTINCT FROM (SELECT sum(amount) FROM public.wallet_transaction_funding WHERE transaction_id=v_original) THEN
      RAISE EXCEPTION 'Funding reconciliation required: original allocation total mismatch';
    END IF;
    IF (NEW.type='esim_purchase_refund' AND v_original_type<>'esim_purchase_debit')
      OR (NEW.type='call_refund' AND v_original_type<>'call_debit') THEN
      RAISE EXCEPTION 'Funding reconciliation required: reversal type mismatch';
    END IF;
    FOR v_lot IN SELECT f.*,l.remaining_amount,l.funded_amount FROM public.wallet_transaction_funding f
      JOIN public.wallet_funding_lots l ON l.id=f.lot_id WHERE f.transaction_id=v_original
      ORDER BY l.id FOR UPDATE OF f,l
    LOOP
      EXIT WHEN v_needed<=0;
      IF NOT EXISTS(SELECT 1 FROM public.wallet_funding_lots WHERE id=v_lot.lot_id
        AND wallet_id=NEW.wallet_id AND user_id=NEW.user_id AND currency=v_wallet.currency
        AND status IN ('active','partially_refunded','fully_consumed','fully_refunded')) THEN
        RAISE EXCEPTION 'Funding reconciliation required: reversal lot unavailable';
      END IF;
      v_take:=least(v_needed,v_lot.amount-v_lot.reversed_amount);
      IF v_take<=0 THEN CONTINUE; END IF;
      UPDATE public.wallet_funding_lots SET remaining_amount=remaining_amount+v_take,
        status=CASE WHEN EXISTS(SELECT 1 FROM public.wallet_refund_items WHERE lot_id=v_lot.lot_id AND status='completed')
          THEN 'partially_refunded' ELSE 'active' END,updated_at=now()
        WHERE id=v_lot.lot_id;
      UPDATE public.wallet_transaction_funding SET reversed_amount=reversed_amount+v_take
        WHERE transaction_id=v_original AND lot_id=v_lot.lot_id;
      v_needed:=v_needed-v_take;
    END LOOP;
    IF v_needed<>0 THEN RAISE EXCEPTION 'Funding reconciliation required: reversal exceeds recorded consumption'; END IF;
  ELSE
    v_capture:=nullif(NEW.metadata->>'paypal_capture_id','');
    v_origin:=CASE WHEN NEW.type='gift_received' THEN 'gift_received'
      WHEN NEW.type='referral_credit' THEN 'promotional'
      WHEN NEW.type='admin_adjustment' THEN 'admin_adjustment'
      WHEN NEW.type IN ('deposit','auto_fund') AND v_capture IS NOT NULL THEN 'paypal_deposit'
      ELSE 'unverified_legacy' END;
    INSERT INTO public.wallet_funding_lots(wallet_id,user_id,origin_type,original_reference_id,original_order_id,
      currency,funded_amount,remaining_amount,is_refundable,refund_deadline)
    VALUES(NEW.wallet_id,NEW.user_id,v_origin,coalesce(v_capture,'credit_'||NEW.id::text),
      coalesce(NEW.metadata->>'order_id',NEW.metadata->>'paypal_order_id'),v_wallet.currency,
      NEW.amount,NEW.amount,v_origin='paypal_deposit',
      CASE WHEN v_origin='paypal_deposit' THEN now()+interval '180 days' END);
  END IF;
  IF v_wallet.balance IS DISTINCT FROM (SELECT coalesce(sum(remaining_amount),0)
    FROM public.wallet_funding_lots WHERE wallet_id=NEW.wallet_id) THEN
    RAISE EXCEPTION 'Funding reconciliation required: posted balance differs from funding';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.book_wallet_transaction_funding() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.book_wallet_transaction_funding() TO service_role;
CREATE TRIGGER book_wallet_transaction_funding AFTER INSERT ON public.wallet_transactions
  FOR EACH ROW EXECUTE FUNCTION public.book_wallet_transaction_funding();

CREATE FUNCTION public.guard_wallet_ledger_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Wallet ledger deletion requires a reviewed retention migration'; END IF;
  IF ROW(NEW.wallet_id,NEW.type,NEW.amount,NEW.balance_before,NEW.balance_after,NEW.reference_id,NEW.status,NEW.created_at)
    IS DISTINCT FROM ROW(OLD.wallet_id,OLD.type,OLD.amount,OLD.balance_before,OLD.balance_after,OLD.reference_id,OLD.status,OLD.created_at) THEN
    RAISE EXCEPTION 'Wallet financial ledger fields are immutable';
  END IF;
  IF NEW.user_id IS DISTINCT FROM OLD.user_id AND NOT (NEW.user_id IS NULL AND EXISTS(
    SELECT 1 FROM public.wallets w JOIN public.account_deletions d ON d.user_id=OLD.user_id
    WHERE w.id=OLD.wallet_id AND w.user_id IS NULL AND d.status='draining')) THEN
    RAISE EXCEPTION 'Wallet ledger ownership is immutable';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.guard_wallet_ledger_mutation() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.guard_wallet_ledger_mutation() TO service_role;
CREATE TRIGGER guard_wallet_ledger_mutation BEFORE UPDATE OR DELETE ON public.wallet_transactions
  FOR EACH ROW EXECUTE FUNCTION public.guard_wallet_ledger_mutation();

CREATE OR REPLACE FUNCTION public.trg_fn_resume_awaiting_funds()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF NEW.status='completed' AND NEW.balance_after>NEW.balance_before THEN
    UPDATE public.topup_executions SET status='pending',execution_time=now(),failure_reason=NULL,updated_at=now()
      WHERE user_id=NEW.user_id AND status='awaiting_funds';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.trg_fn_resume_awaiting_funds() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.trg_fn_resume_awaiting_funds() TO service_role;

-- Refund holds have no time-based release: only authoritative settlement can
-- release them. Other operation TTLs remain unchanged.
ALTER TABLE public.wallet_holds ALTER COLUMN expires_at DROP NOT NULL;
-- Legacy workers did not consistently persist the submission boundary. Old
-- reservations are never automatically classified safe merely from false flags.
ALTER TABLE public.wallet_holds ADD COLUMN recovery_contract_version integer NOT NULL DEFAULT 0;
ALTER TABLE public.wallet_holds ALTER COLUMN recovery_contract_version SET DEFAULT 1;

CREATE OR REPLACE FUNCTION public.capture_wallet_hold(
  p_hold_id UUID,
  p_txn_type TEXT DEFAULT 'topup_debit',
  p_description TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_hold RECORD;
  v_wallet RECORD;
  v_balance_after NUMERIC;
  v_txn_id UUID;
  v_alloc RECORD;
BEGIN
  PERFORM 1 FROM public.wallets WHERE id=(SELECT wallet_id FROM public.wallet_holds WHERE id=p_hold_id) FOR UPDATE;

  -- Lock hold
  SELECT * INTO v_hold
  FROM public.wallet_holds
  WHERE id = p_hold_id
  FOR UPDATE;

  IF v_hold.id IS NULL THEN
    RAISE EXCEPTION 'Hold not found: %', p_hold_id;
  END IF;

  IF v_hold.order_type='refund_request' THEN RAISE EXCEPTION 'Use atomic refund item settlement'; END IF;
  IF p_txn_type NOT IN ('topup_debit','plan_fee_debit','home_mode_debit','esim_purchase_debit',
    'offline_voucher_debit','call_debit','did_purchase_debit','verification_debit') OR p_txn_type IS NULL THEN
    RAISE EXCEPTION 'Purchase debit type required';
  END IF;

  IF NOT EXISTS(SELECT 1 FROM public.wallets WHERE id=v_hold.wallet_id AND user_id=v_hold.user_id AND currency=v_hold.currency AND currency='USD') THEN
    RAISE EXCEPTION 'Hold owner or currency binding mismatch';
  END IF;
  IF NOT ((v_hold.order_type IN ('refill_instant','refill_scheduled','setup_refill') AND p_txn_type IN ('topup_debit','home_mode_debit'))
    OR (v_hold.order_type='plan_fee' AND p_txn_type='plan_fee_debit')
    OR (v_hold.order_type='esim_purchase' AND p_txn_type='esim_purchase_debit')
    OR (v_hold.order_type='offline_voucher' AND p_txn_type='offline_voucher_debit')
    OR (v_hold.order_type='call_budget' AND p_txn_type='call_debit')
    OR (v_hold.order_type='line_verification' AND p_txn_type='verification_debit')) THEN
    RAISE EXCEPTION 'Hold operation and debit type mismatch';
  END IF;
  IF v_hold.status = 'captured' THEN
    -- Idempotent retry: return existing transaction if recorded in metadata
    SELECT id INTO v_txn_id
    FROM public.wallet_transactions
    WHERE reference_id = 'hold_' || p_hold_id::text AND wallet_id=v_hold.wallet_id AND user_id=v_hold.user_id
      AND type=p_txn_type AND amount=v_hold.amount AND status='completed';
    IF v_txn_id IS NOT NULL THEN
      RETURN v_txn_id;
    END IF;
  END IF;

  IF v_hold.status != 'active' THEN
    RAISE EXCEPTION 'Cannot capture hold in status: %', v_hold.status;
  END IF;

  -- Lock wallet
  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE id = v_hold.wallet_id
  FOR UPDATE;

  IF v_wallet.balance < v_hold.amount THEN
    RAISE EXCEPTION 'Invariant violation: wallet balance % is less than hold amount %', v_wallet.balance, v_hold.amount;
  END IF;

  v_balance_after := v_wallet.balance - v_hold.amount;

  -- Update wallet balance
  UPDATE public.wallets
  SET balance = v_balance_after,
      total_spent = total_spent + v_hold.amount,
      updated_at = now()
  WHERE id = v_wallet.id;

  -- Mark hold captured
  UPDATE public.wallet_holds
  SET status = 'captured',
      captured_at = now(),
      updated_at = now()
  WHERE id = p_hold_id;

  -- Record ledger transaction
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, status, metadata, created_at
  ) VALUES (
    v_wallet.id, v_hold.user_id, p_txn_type, v_hold.amount, v_wallet.balance, v_balance_after,
    COALESCE(p_description, 'Purchase completed'),
    'hold_' || p_hold_id::text,
    'completed',
    COALESCE(p_metadata, '{}'::jsonb) || jsonb_build_object('hold_id', p_hold_id, 'order_type', v_hold.order_type, 'order_reference_id', v_hold.order_reference_id),
    now()
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.capture_wallet_hold(uuid,text,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.capture_wallet_hold(uuid,text,text,jsonb) TO service_role;
CREATE OR REPLACE FUNCTION public.release_wallet_hold(
  p_hold_id UUID,
  p_reason TEXT DEFAULT 'Operation cancelled or failed'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_hold RECORD;
BEGIN
  PERFORM 1 FROM public.wallets WHERE id=(SELECT wallet_id FROM public.wallet_holds WHERE id=p_hold_id) FOR UPDATE;
  SELECT * INTO v_hold
  FROM public.wallet_holds
  WHERE id = p_hold_id
  FOR UPDATE;

  IF v_hold.id IS NULL THEN
    RAISE EXCEPTION 'Hold not found: %', p_hold_id;
  END IF;

  IF v_hold.order_type='refund_request' THEN RAISE EXCEPTION 'Use atomic refund item settlement'; END IF;

  IF v_hold.status = 'released' THEN
    RETURN true; -- Idempotent
  END IF;

  IF v_hold.status != 'active' THEN
    RAISE EXCEPTION 'Cannot release hold in status: %', v_hold.status;
  END IF;

  UPDATE public.wallet_holds
  SET status = 'released',
      released_at = now(),
      reason = COALESCE(p_reason, reason),
      updated_at = now()
  WHERE id = p_hold_id;

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.release_wallet_hold(uuid,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.release_wallet_hold(uuid,text) TO service_role;
CREATE OR REPLACE FUNCTION public.credit_wallet_for_deposit(
  p_user_id uuid,
  p_amount numeric,
  p_description text DEFAULT 'Wallet deposit'::text,
  p_reference_id text DEFAULT NULL::text,
  p_metadata jsonb DEFAULT NULL::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_wallet_id UUID;
  v_balance_before NUMERIC;
  v_balance_after NUMERIC;
  v_txn_id UUID;
  v_order_id TEXT;
  v_capture_id TEXT;
  v_origin TEXT := 'paypal_deposit';
  v_is_refundable BOOLEAN := true;
BEGIN
  IF nullif(btrim(p_reference_id),'') IS NULL THEN RAISE EXCEPTION 'Stable deposit reference required'; END IF;
  IF (p_metadata->>'currency' IS NOT NULL AND p_metadata->>'currency'<>'USD') OR
    (nullif(p_metadata->>'paypal_capture_id','') IS NOT NULL AND p_reference_id<>'paypal_'||(p_metadata->>'paypal_capture_id')) THEN
    RAISE EXCEPTION 'Deposit currency or capture reference mismatch';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('wallet:'||p_user_id::text,0));
  IF p_reference_id IS NOT NULL THEN
    SELECT id INTO v_txn_id FROM public.wallet_transactions WHERE user_id=p_user_id
      AND reference_id=p_reference_id AND type IN ('deposit','referral_credit') AND status='completed';
    IF FOUND THEN
      IF NOT EXISTS(SELECT 1 FROM public.wallet_transactions WHERE id=v_txn_id AND amount=p_amount) THEN
        RAISE EXCEPTION 'Deposit reference amount mismatch';
      END IF;
      RETURN v_txn_id;
    END IF;
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount<>round(p_amount,2) OR p_amount::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'Deposit amount must be positive, got %', p_amount;
  END IF;

  SELECT id, balance INTO v_wallet_id, v_balance_before
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    INSERT INTO public.wallets (
      user_id, balance, currency, auto_fund_enabled, total_deposited, total_spent
    ) VALUES (
      p_user_id, p_amount, 'USD', false, p_amount, 0.00
    ) RETURNING id, balance - p_amount INTO v_wallet_id, v_balance_before;
    v_balance_after := p_amount;
  ELSE
    v_balance_after := v_balance_before + p_amount;
    UPDATE public.wallets
    SET balance = v_balance_after,
        total_deposited = total_deposited + p_amount,
        updated_at = now()
    WHERE id = v_wallet_id;
  END IF;

  -- Record transaction
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, status, metadata, created_at
  ) VALUES (
    v_wallet_id, p_user_id, CASE WHEN p_reference_id LIKE 'refredeem_%' THEN 'referral_credit' ELSE 'deposit' END, p_amount, v_balance_before, v_balance_after,
    p_description, p_reference_id, 'completed', coalesce(p_metadata,'{}'::jsonb), now()
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.credit_wallet_for_deposit(uuid,numeric,text,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.credit_wallet_for_deposit(uuid,numeric,text,text,jsonb) TO service_role;
CREATE OR REPLACE FUNCTION public.credit_wallet_for_refund(
  p_user_id uuid,p_amount numeric,p_reference_id text DEFAULT NULL,p_description text DEFAULT NULL,
  p_sim_line_id uuid DEFAULT NULL,p_type text DEFAULT 'refund'
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE w public.wallets; original public.wallet_transactions; existing public.wallet_transactions;
  original_ref text; tx uuid; matches integer;
BEGIN
  IF coalesce(auth.role(),'') NOT IN ('','service_role') THEN
    PERFORM public.assert_admin();
  END IF;
  IF p_amount IS NULL OR p_amount<=0 OR p_amount<>round(p_amount,2) OR p_amount::text IN ('NaN','Infinity','-Infinity')
    OR nullif(btrim(p_reference_id),'') IS NULL OR p_type IS NULL OR p_type NOT IN ('refund','esim_purchase_refund','call_refund') THEN
    RAISE EXCEPTION 'Invalid original-funding reversal' USING ERRCODE='22023';
  END IF;
  SELECT * INTO w FROM public.wallets WHERE user_id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Wallet not found'; END IF;
  -- Both deployed eSIM interfaces share one operation reference even when
  -- one uses generic refund and the other esim_purchase_refund.
  SELECT * INTO existing FROM public.wallet_transactions WHERE wallet_id=w.id
    AND reference_id=p_reference_id AND type IN ('refund','esim_purchase_refund','call_refund') AND status='completed';
  IF FOUND THEN
    IF existing.amount<>p_amount OR existing.sim_line_id IS DISTINCT FROM p_sim_line_id OR
      (p_type<>'refund' AND existing.type NOT IN ('refund',p_type)) THEN RAISE EXCEPTION 'Refund reference mismatch'; END IF;
    IF (p_type='esim_purchase_refund' AND NOT EXISTS(SELECT 1 FROM public.wallet_transactions WHERE id=nullif(existing.metadata->>'reversal_of','')::uuid AND type='esim_purchase_debit'))
      OR (p_type='call_refund' AND NOT EXISTS(SELECT 1 FROM public.wallet_transactions WHERE id=nullif(existing.metadata->>'reversal_of','')::uuid AND type='call_debit')) THEN
      RAISE EXCEPTION 'Refund reference type mismatch';
    END IF;
    RETURN existing.id;
  END IF;
  original_ref:=CASE WHEN p_reference_id LIKE 'esim_refund_%' THEN 'esim_'||substr(p_reference_id,13)
    WHEN p_reference_id LIKE 'call_refund_%' THEN 'call_'||substr(p_reference_id,13)
    WHEN p_reference_id LIKE 'refund_%' THEN substr(p_reference_id,8) END;
  SELECT count(*) INTO matches FROM public.wallet_transactions WHERE wallet_id=w.id AND user_id=p_user_id
    AND reference_id=original_ref AND status='completed' AND balance_after<balance_before;
  IF matches<>1 THEN RAISE EXCEPTION 'Funding reconciliation required: original debit unavailable or ambiguous'; END IF;
  SELECT * INTO original FROM public.wallet_transactions WHERE wallet_id=w.id AND user_id=p_user_id
    AND reference_id=original_ref AND status='completed' AND balance_after<balance_before;
  IF p_sim_line_id IS NOT NULL AND original.sim_line_id IS DISTINCT FROM p_sim_line_id THEN
    RAISE EXCEPTION 'Reversal SIM binding mismatch';
  END IF;
  UPDATE public.wallets SET balance=balance+p_amount,total_spent=greatest(0,total_spent-p_amount),updated_at=now() WHERE id=w.id;
  INSERT INTO public.wallet_transactions(wallet_id,user_id,type,amount,balance_before,balance_after,
    description,reference_id,sim_line_id,status,metadata)
  VALUES(w.id,p_user_id,p_type,p_amount,w.balance,w.balance+p_amount,p_description,p_reference_id,p_sim_line_id,
    'completed',jsonb_build_object('reversal_of',original.id)) RETURNING id INTO tx;
  RETURN tx;
END;
$$;
REVOKE ALL ON FUNCTION public.credit_wallet_for_refund(uuid,numeric,text,text,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.credit_wallet_for_refund(uuid,numeric,text,text,uuid,text) TO service_role;
CREATE OR REPLACE FUNCTION public.debit_wallet_for_topup(
  p_user_id      uuid,
  p_sim_line_id  uuid,
  p_amount       numeric,
  p_description  text DEFAULT 'SIM top-up'::text,
  p_reference_id text DEFAULT NULL::text,
  p_txn_type     text DEFAULT 'topup_debit'::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_raw_claims     TEXT;
  v_jwt_role       TEXT;
  v_ctx            TEXT;
  v_wallet_id      UUID;
  v_balance_before NUMERIC;
  v_balance_after  NUMERIC;
  v_txn_id         UUID;
  v_exec_id        UUID;                   -- G6
  v_acting         UUID;                   -- G6
  v_chk            RECORD;                 -- G6
  v_metadata       JSONB := '{}'::jsonb;   -- G6
BEGIN
  p_txn_type:=coalesce(p_txn_type,'topup_debit');
  IF nullif(btrim(p_reference_id),'') IS NULL OR p_txn_type NOT IN ('topup_debit','plan_fee_debit','home_mode_debit',
    'esim_purchase_debit','offline_voucher_debit','call_debit','did_purchase_debit','verification_debit','gift_sent') THEN
    RAISE EXCEPTION 'Stable purchase debit identity required';
  END IF;
  -- ── F-2 guard, unchanged ────────────────────────────────────────────────
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NOT NULL AND v_raw_claims <> '' THEN
    v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
    IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
      GET DIAGNOSTICS v_ctx = PG_CONTEXT;
      IF coalesce(array_length(string_to_array(v_ctx, E'\n'), 1), 1) < 2 THEN
        RAISE EXCEPTION 'debit_wallet_for_topup is not directly callable by role %', COALESCE(v_jwt_role, '<none>')
          USING ERRCODE = 'KS403';
      END IF;
    END IF;
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 OR p_amount<>round(p_amount,2) OR p_amount::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'Debit amount must be positive, got %', p_amount;
  END IF;

  -- ── G6: is a household member spending the payer's wallet here? ─────────
  -- `exec_<uuid>` is the reference format worker_instant_refill.js builds and
  -- the D5b reaper already relies on. The regex means a malformed or unrelated
  -- reference simply skips this block instead of erroring.
  IF p_reference_id ~ '^exec_[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_exec_id := substring(p_reference_id FROM 6)::uuid;

    SELECT te.acting_user_id INTO v_acting
    FROM public.topup_executions te
    WHERE te.id = v_exec_id;
  END IF;

  SELECT id, balance INTO v_wallet_id, v_balance_before
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  IF p_sim_line_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sim_lines l WHERE l.id=p_sim_line_id AND
    (l.user_id=p_user_id OR EXISTS(SELECT 1 FROM public.household_members hm WHERE hm.owner_id=l.user_id
      AND hm.member_id=p_user_id AND hm.invite_status='accepted' AND hm.role='manager'))) THEN
    RAISE EXCEPTION 'SIM spending ownership required' USING ERRCODE='42501';
  END IF;
  SELECT id INTO v_txn_id FROM public.wallet_transactions WHERE user_id=p_user_id
    AND reference_id=p_reference_id AND type=p_txn_type AND status='completed';
  IF FOUND THEN
    IF NOT EXISTS(SELECT 1 FROM public.wallet_transactions WHERE id=v_txn_id
      AND amount=p_amount AND sim_line_id IS NOT DISTINCT FROM p_sim_line_id) THEN
      RAISE EXCEPTION 'Debit reference mismatch';
    END IF;
    RETURN v_txn_id;
  END IF;
  IF v_acting IS NOT NULL AND v_acting <> p_user_id THEN
    -- Exclude this execution from its own in-flight total, or it would count
    -- twice and the last refill under a cap would always be refused.
    SELECT * INTO v_chk
    FROM public.household_spend_check(p_user_id, v_acting, p_amount, v_exec_id);

    IF NOT v_chk.allowed THEN
      RAISE EXCEPTION 'HOUSEHOLD_CAP:%:%:%:%',
        v_chk.reason, v_chk.monthly_cap, v_chk.spent_mtd, v_chk.remaining_usd
        USING ERRCODE = 'KS402';
    END IF;

    -- The stamp household_spend_mtd() reads. Without it the spend is invisible
    -- to the cap and every later refill this month would be free.
    v_metadata := jsonb_build_object(
      'spent_by',        v_acting::text,
      'spent_for_owner', p_user_id::text,
      'household',       true
    );
  END IF;

  IF v_balance_before < p_amount THEN
    RAISE EXCEPTION 'Insufficient wallet balance. Have: %, Need: %', v_balance_before, p_amount;
  END IF;

  v_balance_after := v_balance_before - p_amount;

  UPDATE public.wallets
  SET balance = v_balance_after,
      total_spent = total_spent + p_amount
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, sim_line_id, status, metadata
  ) VALUES (
    v_wallet_id, p_user_id, COALESCE(p_txn_type, 'topup_debit'), p_amount, v_balance_before, v_balance_after,
    p_description, p_reference_id, p_sim_line_id, 'completed', v_metadata
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$fn$;

REVOKE ALL ON FUNCTION public.debit_wallet_for_topup(uuid,uuid,numeric,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.debit_wallet_for_topup(uuid,uuid,numeric,text,text,text) TO service_role;
CREATE OR REPLACE FUNCTION public.reserve_wallet_funds(
  p_user_id uuid,
  p_amount numeric,
  p_order_type text,
  p_order_reference_id text,
  p_reason text DEFAULT NULL::text,
  p_ttl_minutes integer DEFAULT 120
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_wallet_id UUID;
  v_balance NUMERIC;
  v_held_amount NUMERIC := 0.00;
  v_available NUMERIC := 0.00;
  v_hold_id UUID;
  v_existing_hold RECORD;
  v_needed NUMERIC;
  v_lot RECORD;
  v_alloc_amount NUMERIC;
  v_active_lot_alloc NUMERIC;
  v_available_in_lot NUMERIC;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount<>round(p_amount,2) OR p_amount::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'Hold amount must be positive, got %', p_amount;
  END IF;

  IF p_order_type='refund_request' THEN RAISE EXCEPTION 'Use request_wallet_refund'; END IF;
  IF p_order_type IS NULL OR nullif(btrim(p_order_reference_id),'') IS NULL THEN
    RAISE EXCEPTION 'order_type and order_reference_id are required';
  END IF;

  IF p_ttl_minutes IS NULL OR p_ttl_minutes NOT BETWEEN 1 AND 10080 THEN
    RAISE EXCEPTION 'Invalid hold TTL';
  END IF;
  -- Lock wallet
  SELECT id, balance INTO v_wallet_id, v_balance
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  PERFORM public.assert_wallet_funding_integrity(v_wallet_id);
  -- Idempotency check: if active hold exists for this reference, adopt it
  SELECT * INTO v_existing_hold
  FROM public.wallet_holds
  WHERE order_type = p_order_type AND order_reference_id = p_order_reference_id;

  IF v_existing_hold.id IS NOT NULL THEN
    IF v_existing_hold.status = 'active' THEN
      -- F09: Verify user_id and amount match
      IF v_existing_hold.user_id != p_user_id OR v_existing_hold.wallet_id<>v_wallet_id OR v_existing_hold.currency<>'USD' THEN
        RAISE EXCEPTION 'Existing hold % belongs to user %, but requested for user %', v_existing_hold.id, v_existing_hold.user_id, p_user_id;
      END IF;
      IF v_existing_hold.amount != p_amount THEN
        RAISE EXCEPTION 'Existing hold % has amount %, but requested amount is %', v_existing_hold.id, v_existing_hold.amount, p_amount;
      END IF;
      RETURN v_existing_hold.id;
    ELSE
      RAISE EXCEPTION 'Hold for % % is already in status %', p_order_type, p_order_reference_id, v_existing_hold.status;
    END IF;
  END IF;


  -- Calculate current active holds
  SELECT COALESCE(SUM(amount), 0.00) INTO v_held_amount
  FROM public.wallet_holds
  WHERE user_id = p_user_id AND status = 'active';

  v_available := v_balance - v_held_amount;

  IF v_available < p_amount THEN
    RAISE EXCEPTION 'Insufficient available balance. Available: %, Needed: %', v_available, p_amount;
  END IF;

  -- Create hold
  INSERT INTO public.wallet_holds (
    wallet_id, user_id, order_type, order_reference_id, amount, currency,
    status, reason, expires_at, created_at
  ) VALUES (
    v_wallet_id, p_user_id, p_order_type, p_order_reference_id, p_amount, 'USD',
    'active', p_reason, now() + (p_ttl_minutes || ' minutes')::interval, now()
  ) RETURNING id INTO v_hold_id;

  -- Allocate lots: Spend non-refundable/promotional first, then gifts, then paid deposits oldest first
  v_needed := p_amount;

  FOR v_lot IN
    SELECT l.*,a.available_amount FROM public.wallet_funding_lots l
    JOIN public.wallet_lot_availability(p_user_id) a ON a.lot_id=l.id
    ORDER BY
      CASE
        WHEN origin_type IN ('promotional', 'unverified_legacy') THEN 1
        WHEN origin_type = 'gift_received' THEN 2
        ELSE 3
      END ASC,
      created_at ASC
    FOR UPDATE OF l
  LOOP
    EXIT WHEN v_needed <= 0;

    -- Subtract any already-allocated amounts from active holds on this lot
    SELECT COALESCE(SUM(a.amount), 0.00) INTO v_active_lot_alloc
    FROM public.wallet_hold_allocations a
    JOIN public.wallet_holds h ON h.id = a.hold_id
    WHERE a.lot_id = v_lot.id AND h.status = 'active' AND h.id != v_hold_id;

    v_available_in_lot := v_lot.remaining_amount - v_active_lot_alloc;

    IF v_available_in_lot > 0 THEN
      v_alloc_amount := LEAST(v_available_in_lot, v_needed);

      INSERT INTO public.wallet_hold_allocations (hold_id, lot_id, amount, created_at)
      VALUES (v_hold_id, v_lot.id, v_alloc_amount, now());

      v_needed := v_needed - v_alloc_amount;
    END IF;
  END LOOP;

  -- Invariant check: Assert that the entire requested amount was successfully allocated
  IF v_needed > 0 THEN
    RAISE EXCEPTION 'Invariant violation: unable to allocate full amount from active lots. Short by %', v_needed;
  END IF;

  RETURN v_hold_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.reserve_wallet_funds(uuid,numeric,text,text,text,integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.reserve_wallet_funds(uuid,numeric,text,text,text,integer) TO service_role;
CREATE OR REPLACE FUNCTION public.settle_call_wallet_hold(
  p_hold_id UUID,
  p_actual_cost NUMERIC,
  p_description TEXT DEFAULT 'International Call',
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_hold RECORD;
  v_wallet RECORD;
  v_balance_after NUMERIC;
  v_txn_id UUID;
  v_alloc RECORD;
  v_to_consume NUMERIC;
  v_lot_consume NUMERIC;
BEGIN
  PERFORM 1 FROM public.wallets WHERE id=(SELECT wallet_id FROM public.wallet_holds WHERE id=p_hold_id) FOR UPDATE;
  -- Lock hold
  SELECT * INTO v_hold
  FROM public.wallet_holds
  WHERE id = p_hold_id
  FOR UPDATE;

  IF v_hold.id IS NULL THEN
    RAISE EXCEPTION 'Hold not found: %', p_hold_id;
  END IF;

  -- Idempotency check: if already captured, return existing transaction
  IF NOT EXISTS(SELECT 1 FROM public.wallets WHERE id=v_hold.wallet_id AND user_id=v_hold.user_id AND currency=v_hold.currency AND currency='USD') THEN
    RAISE EXCEPTION 'Hold owner or currency binding mismatch';
  END IF;
  IF v_hold.order_type<>'call_budget' OR p_actual_cost IS NULL OR p_actual_cost<0 OR p_actual_cost<>round(p_actual_cost,2)
    OR p_actual_cost::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Invalid call settlement'; END IF;
  IF v_hold.status = 'captured' THEN
    SELECT id INTO v_txn_id
    FROM public.wallet_transactions
    WHERE reference_id = 'hold_' || p_hold_id::text AND wallet_id=v_hold.wallet_id AND user_id=v_hold.user_id
      AND type='call_debit' AND amount=least(p_actual_cost,v_hold.amount) AND status='completed';
    IF v_txn_id IS NOT NULL THEN
      RETURN v_txn_id;
    END IF;
  END IF;

  IF v_hold.order_type<>'call_budget' THEN RAISE EXCEPTION 'Call budget hold required'; END IF;
  IF v_hold.status = 'released' THEN
    RETURN NULL;
  END IF;

  IF v_hold.status != 'active' THEN
    RAISE EXCEPTION 'Cannot settle hold in status: %', v_hold.status;
  END IF;

  -- If actual cost is zero or negative (e.g. unanswered call), release the hold completely
  IF p_actual_cost IS NULL OR p_actual_cost <= 0 THEN
    UPDATE public.wallet_holds
    SET status = 'released',
        released_at = now(),
        updated_at = now()
    WHERE id = p_hold_id;
    RETURN NULL;
  END IF;

  -- Cap actual cost to held amount if rounding exceeds
  IF p_actual_cost > v_hold.amount THEN
    p_actual_cost := v_hold.amount;
  END IF;

  -- Lock wallet
  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE id = v_hold.wallet_id
  FOR UPDATE;

  IF v_wallet.balance < p_actual_cost THEN
    RAISE EXCEPTION 'Invariant violation: wallet balance % is less than actual cost %', v_wallet.balance, p_actual_cost;
  END IF;

  v_balance_after := v_wallet.balance - p_actual_cost;

  -- Update wallet balance
  UPDATE public.wallets
  SET balance = v_balance_after,
      total_spent = total_spent + p_actual_cost,
      updated_at = now()
  WHERE id = v_wallet.id;

  -- Mark hold captured
  UPDATE public.wallet_holds
  SET status = 'captured',
      captured_at = now(),
      updated_at = now()
  WHERE id = p_hold_id;

  -- Record ledger transaction
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, status, metadata, created_at
  ) VALUES (
    v_wallet.id, v_hold.user_id, 'call_debit', p_actual_cost, v_wallet.balance, v_balance_after,
    COALESCE(p_description, 'International Call'),
    'hold_' || p_hold_id::text,
    'completed',
    COALESCE(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'hold_id', p_hold_id,
      'order_type', v_hold.order_type,
      'order_reference_id', v_hold.order_reference_id,
      'held_amount', v_hold.amount,
      'settled_amount', p_actual_cost
    ),
    now()
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.settle_call_wallet_hold(uuid,numeric,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.settle_call_wallet_hold(uuid,numeric,text,jsonb) TO service_role;
CREATE OR REPLACE FUNCTION public.transfer_wallet_credit(
  p_recipient_email text,
  p_amount numeric,
  p_reference_id text DEFAULT NULL::text,
  p_note text DEFAULT NULL::text,
  p_device_id text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_sender_id       UUID := auth.uid();
  v_sender_email    TEXT;
  v_sender_name     TEXT;
  v_recipient_id    UUID;
  v_recipient_email TEXT;
  v_recipient_name  TEXT;
  v_email           TEXT;
  v_amount          NUMERIC(10,2);
  v_ref             TEXT;
  v_note            TEXT;
  v_min             NUMERIC := 1.00;
  v_max             NUMERIC := 100.00;
  v_daily_max       NUMERIC := 250.00;
  v_sent_today      NUMERIC;
  v_balance         NUMERIC;
  v_giftable        NUMERIC;
  v_existing        public.wallet_transactions%ROWTYPE;
  v_wallet_id       UUID;
  v_before          NUMERIC;
  v_after           NUMERIC;
  v_debit_id        UUID;
  v_credit_id       UUID;
  v_lock            RECORD;
  v_amount_text     TEXT;
  v_guard           JSONB;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED',
                              'error', 'You must be signed in to send credit.');
  END IF;

  v_note := NULLIF(LEFT(TRIM(COALESCE(p_note, '')), 140), '');
  v_ref  := NULLIF(TRIM(COALESCE(p_reference_id, '')), '');
  IF v_ref IS NULL THEN
    v_ref := 'gift_' || LEFT(v_sender_id::text, 8) || '_'
             || (EXTRACT(EPOCH FROM clock_timestamp()) * 1000000)::bigint::text;
  END IF;

  SELECT * INTO v_existing
  FROM public.wallet_transactions
  WHERE reference_id = v_ref AND type = 'gift_sent' AND user_id = v_sender_id;

  IF v_existing.id IS NOT NULL THEN
    IF v_existing.amount IS DISTINCT FROM round(p_amount,2) OR
      v_existing.metadata #>> '{gift,counterparty_email}' IS DISTINCT FROM lower(btrim(p_recipient_email)) THEN
      RAISE EXCEPTION 'Gift reference mismatch';
    END IF;
    RETURN jsonb_build_object(
      'success', true,
      'already_sent', true,
      'transaction_id', v_existing.id,
      'reference_id', v_ref,
      'amount', v_existing.amount,
      'recipient_email', v_existing.metadata #>> '{gift,counterparty_email}',
      'recipient_name', v_existing.metadata #>> '{gift,counterparty_name}'
    );
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 OR p_amount<>round(p_amount,2) OR p_amount::text IN ('NaN','Infinity','-Infinity') THEN
    RETURN jsonb_build_object('success', false, 'code', 'INVALID_AMOUNT',
                              'error', 'Enter an amount greater than zero.');
  END IF;
  v_amount := ROUND(p_amount, 2);

  SELECT COALESCE(MAX(CASE WHEN config_key = 'GIFT_MIN_USD'       THEN config_value::numeric END), 1.00),
         COALESCE(MAX(CASE WHEN config_key = 'GIFT_MAX_USD'       THEN config_value::numeric END), 100.00),
         COALESCE(MAX(CASE WHEN config_key = 'GIFT_DAILY_MAX_USD' THEN config_value::numeric END), 250.00)
    INTO v_min, v_max, v_daily_max
  FROM public.system_configs
  WHERE config_key IN ('GIFT_MIN_USD', 'GIFT_MAX_USD', 'GIFT_DAILY_MAX_USD');

  IF v_amount < v_min THEN
    RETURN jsonb_build_object('success', false, 'code', 'BELOW_MINIMUM',
      'error', 'The smallest gift is $' || to_char(v_min, 'FM99999990.00') || '.',
      'minimum', v_min);
  END IF;

  IF v_amount > v_max THEN
    RETURN jsonb_build_object('success', false, 'code', 'ABOVE_MAXIMUM',
      'error', 'The largest single gift is $' || to_char(v_max, 'FM99999990.00') || '.',
      'maximum', v_max);
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles
             WHERE id = v_sender_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'code', 'SENDER_SUSPENDED',
                              'error', 'Your account is suspended.');
  END IF;

  IF EXISTS (SELECT 1 FROM public.account_deletions
             WHERE user_id = v_sender_id
               AND status IN ('requested', 'frozen', 'draining')) THEN
    RETURN jsonb_build_object('success', false, 'code', 'SENDER_CLOSING',
      'error', 'Your account is scheduled for deletion, so transfers are closed.');
  END IF;

  v_email := LOWER(TRIM(COALESCE(p_recipient_email, '')));
  IF v_email = '' OR v_email NOT LIKE '%_@_%.__%' THEN
    RETURN jsonb_build_object('success', false, 'code', 'INVALID_EMAIL',
                              'error', 'Enter a valid email address.');
  END IF;

  BEGIN
    PERFORM public.enforce_rate_limit('gift_credit', v_sender_id::text);
  EXCEPTION WHEN SQLSTATE 'KS429' THEN
    RETURN jsonb_build_object(
      'success', false, 'code', 'KS429',
      'error', 'Too many transfers just now. Try again in a little while.');
  END;

  SELECT u.id, u.email INTO v_recipient_id, v_recipient_email
  FROM auth.users u
  WHERE LOWER(u.email) = v_email
    AND u.deleted_at IS NULL
    AND COALESCE(u.is_anonymous, false) = false;

  IF v_recipient_id IS NULL THEN
    INSERT INTO public.security_logs (user_id, event_type, description, metadata)
    VALUES (v_sender_id, 'gift_recipient_not_found',
            'Wallet gift attempted to an address with no KeepSIMs account',
            jsonb_build_object('email_hash',
                               encode(sha256(v_email::bytea), 'hex')));

    RETURN jsonb_build_object('success', false, 'code', 'RECIPIENT_NOT_FOUND',
      'error', 'No KeepSIMs account uses that email address yet.');
  END IF;

  IF v_recipient_id = v_sender_id THEN
    RETURN jsonb_build_object('success', false, 'code', 'CANNOT_GIFT_SELF',
                              'error', 'You cannot send credit to yourself.');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles
             WHERE id = v_recipient_id AND is_suspended = true)
     OR EXISTS (SELECT 1 FROM public.account_deletions
                WHERE user_id = v_recipient_id
                  AND status IN ('requested', 'frozen', 'draining', 'drained')) THEN
    RETURN jsonb_build_object('success', false, 'code', 'RECIPIENT_UNAVAILABLE',
      'error', 'That account cannot receive credit right now.');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE user_id = v_recipient_id) THEN
    RETURN jsonb_build_object('success', false, 'code', 'RECIPIENT_UNAVAILABLE',
      'error', 'That account cannot receive credit right now.');
  END IF;

  FOR v_lock IN
    SELECT id FROM public.wallets
    WHERE user_id IN (v_sender_id, v_recipient_id)
    ORDER BY user_id
  LOOP
    PERFORM 1 FROM public.wallets WHERE id = v_lock.id FOR UPDATE;
  END LOOP;

  SELECT * INTO v_existing FROM public.wallet_transactions WHERE user_id=v_sender_id
    AND reference_id=v_ref AND type='gift_sent' AND status='completed';
  IF FOUND THEN
    IF v_existing.amount IS DISTINCT FROM v_amount OR
      v_existing.metadata #>> '{gift,counterparty_email}' IS DISTINCT FROM v_email THEN RAISE EXCEPTION 'Gift reference mismatch'; END IF;
    RETURN jsonb_build_object('success',true,'already_sent',true,'transaction_id',v_existing.id,'amount',v_existing.amount,'reference_id',v_ref);
  END IF;
  SELECT COALESCE(SUM(amount), 0) INTO v_sent_today
  FROM public.wallet_transactions
  WHERE user_id = v_sender_id
    AND type = 'gift_sent'
    AND status = 'completed'
    AND created_at > (clock_timestamp() - INTERVAL '24 hours');

  IF v_sent_today + v_amount > v_daily_max THEN
    RETURN jsonb_build_object('success', false, 'code', 'DAILY_LIMIT',
      'error', 'That would pass your $' || to_char(v_daily_max, 'FM99999990.00')
               || ' daily transfer limit. Sent in the last 24 hours: $'
               || to_char(v_sent_today, 'FM99999990.00') || '.',
      'daily_max', v_daily_max, 'sent_today', v_sent_today);
  END IF;

  SELECT COALESCE(balance, 0) INTO v_balance
  FROM public.wallets WHERE user_id = v_sender_id;

  IF v_balance < v_amount THEN
    RETURN jsonb_build_object('success', false, 'code', 'INSUFFICIENT_FUNDS',
      'error', 'Your balance is $' || to_char(v_balance, 'FM99999990.00') || '.',
      'balance', v_balance);
  END IF;

  SELECT coalesce(sum(a.available_amount),0) INTO v_giftable
  FROM public.wallet_lot_availability(v_sender_id) a JOIN public.wallet_funding_lots l ON l.id=a.lot_id
  WHERE l.origin_type IN ('paypal_deposit','card_deposit','gift_received');

  IF v_amount > COALESCE(v_giftable, 0) THEN
    RETURN jsonb_build_object('success', false, 'code', 'NOT_GIFTABLE',
      'error', 'Only credit you added yourself can be sent on. Available to '
               || 'send: $' || to_char(COALESCE(v_giftable, 0), 'FM99999990.00') || '.',
      'giftable', COALESCE(v_giftable, 0),
      'balance', v_balance);
  END IF;

  -- G10: the last checkpoint before two wallets move.
  v_guard := public.guard_money_action('gift_send', v_amount, p_device_id, v_ref, v_sender_id);
  IF (v_guard ->> 'blocked')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'DEVICE_BLOCKED',
      'reason', v_guard ->> 'reason',
      'error', 'This transfer was stopped by a security check on this device. Contact support if this is a mistake.');
  END IF;

  SELECT u.email, p.full_name INTO v_sender_email, v_sender_name
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
  WHERE u.id = v_sender_id;

  SELECT full_name INTO v_recipient_name
  FROM public.profiles WHERE id = v_recipient_id;

  v_debit_id := public.debit_wallet_for_topup(
    v_sender_id, NULL, v_amount,
    'Gift to ' || COALESCE(NULLIF(v_recipient_name, ''), v_recipient_email),
    v_ref, 'gift_sent'
  );

  SELECT id, balance INTO v_wallet_id, v_before
  FROM public.wallets WHERE user_id = v_recipient_id FOR UPDATE;

  v_after := v_before + v_amount;

  UPDATE public.wallets
  SET balance = v_after,
      total_deposited = COALESCE(total_deposited, 0) + v_amount
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, status, metadata
  ) VALUES (
    v_wallet_id, v_recipient_id, 'gift_received', v_amount, v_before, v_after,
    'Gift from ' || COALESCE(NULLIF(v_sender_name, ''), v_sender_email),
    v_ref, 'completed',
    jsonb_build_object('gift', jsonb_strip_nulls(jsonb_build_object(
      'direction', 'received',
      'counterparty_user_id', v_sender_id,
      'counterparty_email', v_sender_email,
      'counterparty_name', NULLIF(v_sender_name, ''),
      'note', v_note)))
  ) RETURNING id INTO v_credit_id;

  UPDATE public.wallet_transactions
  SET metadata = jsonb_build_object('gift', jsonb_strip_nulls(jsonb_build_object(
        'direction', 'sent',
        'counterparty_user_id', v_recipient_id,
        'counterparty_email', v_recipient_email,
        'counterparty_name', NULLIF(v_recipient_name, ''),
        'note', v_note)))
  WHERE id = v_debit_id;

  v_amount_text := to_char(v_amount, 'FM99999990.00');

  INSERT INTO public.notifications (user_id, category, title, body, action_url)
  VALUES (
    v_recipient_id,
    'wallet_credit',
    'You received $' || v_amount_text,
    COALESCE(NULLIF(v_sender_name, ''), v_sender_email)
      || ' sent you $' || v_amount_text || ' of KeepSIMs credit.'
      || CASE WHEN v_note IS NULL THEN '' ELSE ' "' || v_note || '"' END,
    '/wallet'
  );

  RETURN jsonb_build_object(
    'success', true,
    'already_sent', false,
    'reference_id', v_ref,
    'amount', v_amount,
    'transaction_id', v_debit_id,
    'credit_transaction_id', v_credit_id,
    'recipient_email', v_recipient_email,
    'recipient_name', NULLIF(v_recipient_name, ''),
    'balance_after', v_balance - v_amount
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.transfer_wallet_credit(text,numeric,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.transfer_wallet_credit(text,numeric,text,text,text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.admin_adjust_wallet_once(p_user_id uuid, p_amount numeric, p_reason text, p_reference_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor  uuid;
  v_cap    numeric;
  v_wallet RECORD;
  v_before numeric;
  v_after  numeric;
  v_txn    uuid;
  v_email  text;
  v_existing public.wallet_transactions;
BEGIN
  v_actor := public.assert_admin();

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'A reason of at least 5 characters is required' USING ERRCODE = 'KS464';
  END IF;

  IF p_amount IS NULL OR p_amount = 0 OR p_amount<>round(p_amount,2) OR p_amount::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'Amount must be non-zero' USING ERRCODE = 'KS466';
  END IF;

  SELECT COALESCE(NULLIF(config_value,'')::numeric, 50) INTO v_cap
  FROM public.system_configs WHERE config_key = 'ADMIN_WALLET_ADJUST_MAX_USD';
  v_cap := COALESCE(v_cap, 50);

  IF abs(p_amount) > v_cap THEN
    RAISE EXCEPTION 'Adjustment of % exceeds the % USD support limit', p_amount, v_cap
      USING ERRCODE = 'KS466';
  END IF;

  IF p_user_id = v_actor THEN
    RAISE EXCEPTION 'You cannot adjust your own wallet' USING ERRCODE = 'KS466';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id USING ERRCODE = 'KS461';
  END IF;

  IF p_reference_id IS NULL OR p_reference_id !~ '^[A-Za-z0-9:_-]{8,96}$' THEN RAISE invalid_parameter_value; END IF;
  SELECT * INTO v_existing FROM public.wallet_transactions WHERE wallet_id=v_wallet.id AND type='admin_adjustment'
    AND reference_id='adminadj_'||p_reference_id AND status='completed';
  IF FOUND THEN
    IF v_existing.balance_after-v_existing.balance_before<>p_amount OR v_existing.metadata->>'adjusted_by' IS DISTINCT FROM v_actor::text
      OR v_existing.metadata->>'reason' IS DISTINCT FROM btrim(p_reason) THEN RAISE EXCEPTION 'Adjustment reference mismatch'; END IF;
    RETURN jsonb_build_object('success',true,'balance_before',v_existing.balance_before,'balance_after',v_existing.balance_after,
      'transaction_id',v_existing.id,'already_adjusted',true);
  END IF;
  v_before := v_wallet.balance;
  v_after  := v_before + round(p_amount, 2);

  IF v_after < 0 THEN
    RAISE EXCEPTION 'That would take the balance to %, below zero', v_after USING ERRCODE = 'KS466';
  END IF;

  UPDATE public.wallets SET balance = v_after WHERE id = v_wallet.id;

  SELECT email INTO v_email FROM public.profiles WHERE id = v_actor;

  -- Positive and negative both store a positive amount (the CHECK requires it);
  -- direction is carried by balance_before/balance_after, as every other debit
  -- in this ledger already does.
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, status, metadata
  ) VALUES (
    v_wallet.id, p_user_id, 'admin_adjustment', abs(round(p_amount, 2)), v_before, v_after,
    CASE WHEN p_amount > 0 THEN 'Support credit: ' ELSE 'Support correction: ' END || left(btrim(p_reason), 160),
    'adminadj_' || p_reference_id,
    'completed',
    jsonb_build_object('adjusted_by', v_actor::text, 'adjusted_by_email', v_email,
                       'direction', CASE WHEN p_amount > 0 THEN 'credit' ELSE 'debit' END,
                       'reason', btrim(p_reason))
  ) RETURNING id INTO v_txn;

  PERFORM public.admin_log('wallet.adjust', 'user', p_user_id::text,
    jsonb_build_object('balance', v_before),
    jsonb_build_object('balance', v_after, 'amount', p_amount, 'txn_id', v_txn),
    btrim(p_reason));

  INSERT INTO public.notifications (user_id, category, title, body)
  VALUES (p_user_id, 'wallet_credit',
          CASE WHEN p_amount > 0 THEN 'Credit added to your wallet' ELSE 'Your wallet balance was corrected' END,
          'Support adjusted your balance by ' ||
          CASE WHEN p_amount > 0 THEN '+' ELSE '-' END || '$' || to_char(abs(round(p_amount,2)),'FM999999990.00') ||
          '. New balance $' || to_char(v_after,'FM999999990.00') || '.');

  RETURN jsonb_build_object('success', true, 'balance_before', v_before,
                            'balance_after', v_after, 'transaction_id', v_txn);
END;
$function$
;
REVOKE ALL ON FUNCTION public.admin_adjust_wallet_once(uuid,numeric,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_adjust_wallet_once(uuid,numeric,text,text) TO authenticated,service_role;

-- Safe compatibility for old support callers without an explicit operation key.
-- A deliberate identical later correction requires the new explicit-key RPC.
CREATE OR REPLACE FUNCTION public.admin_adjust_wallet(p_user_id uuid,p_amount numeric,p_reason text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT public.admin_adjust_wallet_once(p_user_id,p_amount,p_reason,
   'legacy_'||md5(coalesce(auth.uid()::text,'')||':'||p_user_id::text||':'||round(p_amount,2)::text||':'||btrim(p_reason)));
$$;
REVOKE ALL ON FUNCTION public.admin_adjust_wallet(uuid,numeric,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_adjust_wallet(uuid,numeric,text) TO authenticated,service_role;

CREATE FUNCTION public.assert_wallet_access(p_user_id uuid)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF p_user_id IS NULL OR (
    coalesce(auth.role(),'')='service_role' OR auth.uid()=p_user_id
    OR (session_user='postgres' AND coalesce(current_setting('request.jwt.claims',true),'') IN ('','{}'))
  ) IS NOT TRUE THEN RAISE EXCEPTION 'Wallet ownership required' USING ERRCODE='42501'; END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.assert_wallet_access(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.assert_wallet_access(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.quote_wallet_refund(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_wallet public.wallets; v_available numeric; v_eligible numeric; v_lots jsonb;
BEGIN
  PERFORM public.assert_wallet_access(p_user_id);
  SELECT * INTO v_wallet FROM public.wallets WHERE user_id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('eligible_amount',0,'lots','[]'::jsonb); END IF;
  PERFORM public.assert_wallet_funding_integrity(v_wallet.id);
  SELECT greatest(0,v_wallet.balance-coalesce(sum(amount),0)) INTO v_available
    FROM public.wallet_holds WHERE wallet_id=v_wallet.id AND status='active';
  SELECT coalesce(sum(a.available_amount),0),coalesce(jsonb_agg(jsonb_build_object(
    'lot_id',l.id,'capture_id',l.original_reference_id,'funded_amount',l.funded_amount,
    'remaining_amount',a.available_amount,'refund_deadline',l.refund_deadline) ORDER BY l.created_at,l.id),'[]'::jsonb)
    INTO v_eligible,v_lots FROM public.wallet_lot_availability(p_user_id) a
    JOIN public.wallet_funding_lots l ON l.id=a.lot_id
    WHERE l.is_refundable AND l.origin_type='paypal_deposit' AND a.available_amount>0
      AND l.currency='USD' AND nullif(btrim(l.original_reference_id),'') IS NOT NULL
      AND (l.refund_deadline IS NOT NULL AND l.refund_deadline>now());
  RETURN jsonb_build_object('eligible_amount',least(v_available,v_eligible),'available_balance',v_available,
    'currency',v_wallet.currency,'lots',v_lots);
END;
$$;
REVOKE ALL ON FUNCTION public.quote_wallet_refund(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.quote_wallet_refund(uuid) TO authenticated,service_role;

CREATE FUNCTION public.create_wallet_refund_request(p_user_id uuid,p_amount numeric,
  p_reason text DEFAULT 'Customer requested refund of unused balance')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_wallet public.wallets; v_request uuid:=gen_random_uuid(); v_hold uuid; v_quote jsonb;
  v_lot record; v_take numeric; v_needed numeric:=p_amount; v_count integer:=0; v_item uuid;
BEGIN
  PERFORM public.assert_wallet_access(p_user_id);
  IF p_amount IS NULL OR p_amount<=0 OR p_amount<>round(p_amount,2) OR p_amount::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Invalid refund amount'; END IF;
  SELECT * INTO v_wallet FROM public.wallets WHERE user_id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Wallet not found'; END IF;
  SELECT id,hold_id INTO v_request,v_hold FROM public.wallet_refund_requests
    WHERE user_id=p_user_id AND requested_amount=p_amount AND status IN ('requested','processing','under_review')
    ORDER BY created_at DESC LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('success',true,'refund_request_id',v_request,'hold_id',v_hold,'amount',p_amount,
      'item_count',(SELECT count(*) FROM public.wallet_refund_items WHERE refund_request_id=v_request),'already_requested',true);
  END IF;
  v_request:=gen_random_uuid();
  v_quote:=public.quote_wallet_refund(p_user_id);
  IF (v_quote->>'eligible_amount')::numeric<p_amount THEN RAISE EXCEPTION 'Refund exceeds eligible unreserved deposits'; END IF;
  INSERT INTO public.wallet_refund_requests(id,user_id,wallet_id,requested_amount,currency,audit_notes)
    VALUES(v_request,p_user_id,v_wallet.id,p_amount,v_wallet.currency,p_reason);
  INSERT INTO public.wallet_holds(wallet_id,user_id,order_type,order_reference_id,amount,currency,expires_at)
    VALUES(v_wallet.id,p_user_id,'refund_request','refund_'||v_request::text,p_amount,v_wallet.currency,NULL) RETURNING id INTO v_hold;
  UPDATE public.wallet_refund_requests SET hold_id=v_hold WHERE id=v_request;
  FOR v_lot IN SELECT l.*,a.available_amount FROM public.wallet_lot_availability(p_user_id) a
    JOIN public.wallet_funding_lots l ON l.id=a.lot_id
    WHERE l.is_refundable AND l.origin_type='paypal_deposit' AND a.available_amount>0
      AND l.currency='USD' AND nullif(btrim(l.original_reference_id),'') IS NOT NULL
      AND (l.refund_deadline IS NOT NULL AND l.refund_deadline>now()) ORDER BY l.created_at,l.id FOR UPDATE OF l
  LOOP
    EXIT WHEN v_needed<=0;
    v_take:=least(v_needed,v_lot.available_amount);
    INSERT INTO public.wallet_hold_allocations(hold_id,lot_id,amount) VALUES(v_hold,v_lot.id,v_take);
    v_item:=gen_random_uuid();
    INSERT INTO public.wallet_refund_items(id,refund_request_id,lot_id,capture_id,amount,currency,idempotency_key)
      VALUES(v_item,v_request,v_lot.id,v_lot.original_reference_id,v_take,v_wallet.currency,'ksr-'||replace(v_item::text,'-',''));
    v_needed:=v_needed-v_take; v_count:=v_count+1;
  END LOOP;
  IF v_needed<>0 THEN RAISE EXCEPTION 'Refund allocation incomplete'; END IF;
  RETURN jsonb_build_object('success',true,'refund_request_id',v_request,'hold_id',v_hold,'amount',p_amount,'item_count',v_count);
END;
$$;
REVOKE ALL ON FUNCTION public.create_wallet_refund_request(uuid,numeric,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.create_wallet_refund_request(uuid,numeric,text) TO service_role;

CREATE TABLE public.wallet_refund_request_keys (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 request_key text NOT NULL CHECK(request_key ~ '^[A-Za-z0-9:_-]{8,96}$'),
 refund_request_id uuid NOT NULL REFERENCES public.wallet_refund_requests(id) ON DELETE RESTRICT,
 amount numeric NOT NULL CHECK(amount>0), PRIMARY KEY(user_id,request_key)
);
ALTER TABLE public.wallet_refund_request_keys ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.wallet_refund_request_keys FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.wallet_refund_request_keys TO service_role;

CREATE FUNCTION public.request_wallet_refund_once(p_user_id uuid,p_amount numeric,p_request_key text,
 p_reason text DEFAULT 'Customer requested refund of unused balance')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE w public.wallets; r public.wallet_refund_requests; key_amount numeric; request_id uuid; result jsonb;
BEGIN
 PERFORM public.assert_wallet_access(p_user_id);
 IF p_request_key IS NULL OR p_request_key !~ '^[A-Za-z0-9:_-]{8,96}$' OR p_amount IS NULL OR p_amount<=0
   OR p_amount<>round(p_amount,2) OR p_amount::text IN ('NaN','Infinity','-Infinity') THEN RAISE invalid_parameter_value; END IF;
 SELECT * INTO w FROM public.wallets WHERE user_id=p_user_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Wallet not found'; END IF;
 SELECT k.refund_request_id,k.amount INTO request_id,key_amount FROM public.wallet_refund_request_keys k
   WHERE k.user_id=p_user_id AND k.request_key=p_request_key;
 IF FOUND THEN
   SELECT * INTO r FROM public.wallet_refund_requests WHERE id=request_id;
   IF key_amount<>p_amount OR r.wallet_id<>w.id OR r.currency<>w.currency THEN RAISE EXCEPTION 'Refund request key mismatch'; END IF;
   RETURN jsonb_build_object('success',true,'refund_request_id',r.id,'hold_id',r.hold_id,'amount',r.requested_amount,
     'item_count',(SELECT count(*) FROM public.wallet_refund_items WHERE refund_request_id=r.id),'already_requested',true,'status',r.status);
 END IF;
 result:=public.create_wallet_refund_request(p_user_id,p_amount,p_reason);
 INSERT INTO public.wallet_refund_request_keys(user_id,request_key,refund_request_id,amount)
   VALUES(p_user_id,p_request_key,(result->>'refund_request_id')::uuid,p_amount);
 RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.request_wallet_refund_once(uuid,numeric,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_wallet_refund_once(uuid,numeric,text,text) TO authenticated,service_role;

-- Existing three-argument callers retain a deterministic per-amount identity.
-- Distinct requests after completion must use a new explicit request key.
CREATE OR REPLACE FUNCTION public.request_wallet_refund(p_user_id uuid,p_amount numeric,
 p_reason text DEFAULT 'Customer requested refund of unused balance')
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT public.request_wallet_refund_once(p_user_id,p_amount,'legacy:'||trunc(p_amount*100)::text,p_reason);
$$;
REVOKE ALL ON FUNCTION public.request_wallet_refund(uuid,numeric,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_wallet_refund(uuid,numeric,text) TO authenticated,service_role;

ALTER TABLE public.wallet_refund_items ADD COLUMN claim_token uuid, ADD COLUMN claimed_at timestamptz,
  ADD COLUMN submission_started_at timestamptz, ADD COLUMN provider_observed_at timestamptz,
  ADD COLUMN provider_outcome text CHECK(provider_outcome IN ('completed','failed','pending','unknown'));
CREATE UNIQUE INDEX wallet_refund_items_provider_identity ON public.wallet_refund_items(provider,provider_refund_id)
  WHERE provider_refund_id IS NOT NULL;

-- Every transition uses the same wallet -> request -> item -> hold -> lot order.
CREATE FUNCTION public.lock_wallet_refund_item(p_item_id uuid)
RETURNS public.wallet_refund_items LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i public.wallet_refund_items; r public.wallet_refund_requests; w public.wallets;
  h public.wallet_holds; l public.wallet_funding_lots;
BEGIN
  SELECT w0.* INTO w FROM public.wallets w0 JOIN public.wallet_refund_requests r0 ON r0.wallet_id=w0.id
    JOIN public.wallet_refund_items i0 ON i0.refund_request_id=r0.id WHERE i0.id=p_item_id FOR UPDATE OF w0;
  SELECT r0.* INTO r FROM public.wallet_refund_requests r0 JOIN public.wallet_refund_items i0
    ON i0.refund_request_id=r0.id WHERE i0.id=p_item_id FOR UPDATE OF r0;
  SELECT * INTO i FROM public.wallet_refund_items WHERE id=p_item_id FOR UPDATE;
  IF i.id IS NULL THEN RAISE EXCEPTION 'Refund item unavailable'; END IF;
  SELECT * INTO h FROM public.wallet_holds WHERE id=r.hold_id FOR UPDATE;
  SELECT * INTO l FROM public.wallet_funding_lots WHERE id=i.lot_id FOR UPDATE;
  IF w.id IS NULL OR h.id IS NULL OR l.id IS NULL OR w.user_id IS DISTINCT FROM r.user_id
    OR h.wallet_id IS DISTINCT FROM w.id OR h.user_id IS DISTINCT FROM w.user_id
    OR l.wallet_id IS DISTINCT FROM w.id OR l.user_id IS DISTINCT FROM w.user_id
    OR w.currency IS DISTINCT FROM 'USD' OR r.currency IS DISTINCT FROM w.currency
    OR i.currency IS DISTINCT FROM w.currency OR h.currency IS DISTINCT FROM w.currency
    OR l.currency IS DISTINCT FROM w.currency OR i.provider<>'paypal' OR l.origin_type<>'paypal_deposit'
    OR NOT l.is_refundable OR i.capture_id IS DISTINCT FROM l.original_reference_id OR nullif(btrim(i.capture_id),'') IS NULL
    OR h.order_type<>'refund_request' OR h.order_reference_id IS DISTINCT FROM 'refund_'||r.id::text
    OR i.amount<>round(i.amount,2) OR i.amount::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'Refund owner, currency or funding binding mismatch';
  END IF;
  IF i.status NOT IN ('completed','failed') AND (h.status<>'active'
    OR r.status NOT IN ('requested','processing','under_review')
    OR (SELECT coalesce(sum(amount),0) FROM public.wallet_hold_allocations WHERE hold_id=h.id AND lot_id=l.id)<>i.amount
    OR h.amount<>(SELECT coalesce(sum(amount),0) FROM public.wallet_hold_allocations WHERE hold_id=h.id)) THEN
    RAISE EXCEPTION 'Active bound refund reservation required';
  END IF;
  PERFORM public.assert_wallet_funding_integrity(w.id);
  RETURN i;
END;
$$;
REVOKE ALL ON FUNCTION public.lock_wallet_refund_item(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lock_wallet_refund_item(uuid) TO service_role;

CREATE FUNCTION public.claim_wallet_refund_item(p_item_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i public.wallet_refund_items; token uuid:=gen_random_uuid(); action text;
BEGIN
  i:=public.lock_wallet_refund_item(p_item_id);
  IF i.status IN ('completed','failed') THEN RETURN jsonb_build_object('claimed',false); END IF;
  IF i.status='processing' AND i.claimed_at>clock_timestamp()-interval '5 minutes' THEN
    RETURN jsonb_build_object('claimed',false);
  END IF;
  action:=CASE WHEN i.provider_outcome IN ('completed','failed') AND i.provider_refund_id IS NOT NULL THEN 'settle'
    WHEN i.provider_refund_id IS NOT NULL THEN 'poll'
    WHEN i.submission_started_at IS NULL AND i.idempotency_key ~ '^ksr-[a-f0-9]{32}$' THEN 'submit' END;
  IF action IS NULL THEN
    -- A lost POST response is never a licence to issue another payout, even
    -- after the provider's idempotency retention or our claim lease has elapsed.
    UPDATE public.wallet_refund_items SET status='reconciliation_required',updated_at=now() WHERE id=i.id;
    UPDATE public.wallet_refund_requests SET status='under_review',updated_at=now() WHERE id=i.refund_request_id;
    RETURN jsonb_build_object('claimed',false,'reconciliation_required',true);
  END IF;
  UPDATE public.wallet_refund_items SET status='processing',claim_token=token,claimed_at=clock_timestamp(),updated_at=now()
    WHERE id=i.id RETURNING * INTO i;
  UPDATE public.wallet_refund_requests SET status='processing',updated_at=now() WHERE id=i.refund_request_id;
  RETURN jsonb_build_object('claimed',true,'claim_token',token,'action',action,'item',to_jsonb(i));
END;
$$;
REVOKE ALL ON FUNCTION public.claim_wallet_refund_item(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_wallet_refund_item(uuid) TO service_role;

CREATE FUNCTION public.list_wallet_refund_work(p_request_id uuid,p_limit integer DEFAULT 5)
RETURNS TABLE(id uuid) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 20 THEN RAISE invalid_parameter_value; END IF;
  RETURN QUERY SELECT i.id FROM public.wallet_refund_items i WHERE i.refund_request_id=p_request_id
    AND i.status IN ('pending','processing','reconciliation_required')
    AND (i.status<>'processing' OR i.claimed_at<=now()-interval '5 minutes')
    AND (i.provider_refund_id IS NOT NULL OR (i.submission_started_at IS NULL AND i.idempotency_key ~ '^ksr-[a-f0-9]{32}$'))
    ORDER BY i.created_at,i.id LIMIT p_limit;
END;
$$;
REVOKE ALL ON FUNCTION public.list_wallet_refund_work(uuid,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.list_wallet_refund_work(uuid,integer) TO service_role;

CREATE FUNCTION public.begin_wallet_refund_submission(p_item_id uuid,p_claim_token uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i public.wallet_refund_items;
BEGIN
  i:=public.lock_wallet_refund_item(p_item_id);
  IF p_claim_token IS NULL OR i.claim_token IS DISTINCT FROM p_claim_token OR i.status<>'processing'
    OR i.claimed_at<=clock_timestamp()-interval '5 minutes' THEN RAISE insufficient_privilege; END IF;
  IF i.submission_started_at IS NOT NULL OR i.provider_refund_id IS NOT NULL THEN RETURN false; END IF;
  IF i.idempotency_key !~ '^ksr-[a-f0-9]{32}$' THEN RAISE EXCEPTION 'Legacy refund identity requires reconciliation'; END IF;
  UPDATE public.wallet_refund_items SET submission_started_at=clock_timestamp(),updated_at=now() WHERE id=i.id;
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.begin_wallet_refund_submission(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.begin_wallet_refund_submission(uuid,uuid) TO service_role;

-- Separate durable provider observation from the financial transaction. A local
-- settlement rollback cannot erase the provider identity or its terminal result.
CREATE FUNCTION public.record_wallet_refund_evidence(p_item_id uuid,p_claim_token uuid,p_outcome text,p_provider_refund_id text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i public.wallet_refund_items;
BEGIN
  i:=public.lock_wallet_refund_item(p_item_id);
  p_provider_refund_id:=nullif(btrim(p_provider_refund_id),'');
  IF p_claim_token IS NULL OR i.claim_token IS DISTINCT FROM p_claim_token THEN RAISE insufficient_privilege; END IF;
  IF p_outcome IS NULL OR p_outcome NOT IN ('completed','failed','pending','unknown')
    OR (p_outcome<>'unknown' AND p_provider_refund_id IS NULL) OR i.submission_started_at IS NULL THEN
    RAISE EXCEPTION 'Invalid refund provider evidence';
  END IF;
  IF i.provider_refund_id IS NOT NULL AND p_provider_refund_id IS NOT NULL AND i.provider_refund_id<>p_provider_refund_id THEN
    RAISE EXCEPTION 'Provider refund identity changed';
  END IF;
  IF i.provider_outcome IN ('completed','failed') AND p_outcome IN ('completed','failed') AND i.provider_outcome<>p_outcome THEN
    RAISE EXCEPTION 'Conflicting terminal refund evidence';
  END IF;
  UPDATE public.wallet_refund_items SET provider_refund_id=coalesce(provider_refund_id,p_provider_refund_id),
    provider_outcome=CASE WHEN provider_outcome IN ('completed','failed') THEN provider_outcome ELSE p_outcome END,
    provider_observed_at=clock_timestamp(),updated_at=now() WHERE id=i.id;
  RETURN jsonb_build_object('persisted',true);
END;
$$;
REVOKE ALL ON FUNCTION public.record_wallet_refund_evidence(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.record_wallet_refund_evidence(uuid,uuid,text,text) TO service_role;

-- Only the trusted adapter may attach a manually recovered provider ID, after
-- GET verification of parent capture, amount and currency. No funds move here.
CREATE FUNCTION public.adopt_wallet_refund_identity(p_item_id uuid,p_provider_refund_id text,p_actor_user_id uuid DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i public.wallet_refund_items;
BEGIN
  i:=public.lock_wallet_refund_item(p_item_id);
  p_provider_refund_id:=nullif(btrim(p_provider_refund_id),'');
  IF p_provider_refund_id IS NULL OR i.submission_started_at IS NULL OR i.status IN ('completed','failed')
    OR (i.provider_refund_id IS NOT NULL AND i.provider_refund_id<>p_provider_refund_id)
    OR (i.status='processing' AND i.claimed_at>clock_timestamp()-interval '5 minutes') THEN
    RAISE EXCEPTION 'Refund identity cannot be adopted';
  END IF;
  UPDATE public.wallet_refund_items SET provider_refund_id=p_provider_refund_id,status='reconciliation_required',updated_at=now() WHERE id=i.id;
  INSERT INTO public.security_logs(user_id,event_type,description,metadata)
    SELECT r.user_id,'wallet_refund_identity_adopted','Verified provider refund identity recovered',
      jsonb_build_object('refund_item_id',i.id,'provider_refund_id',p_provider_refund_id,'actor_user_id',p_actor_user_id)
    FROM public.wallet_refund_requests r WHERE r.id=i.refund_request_id;
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.adopt_wallet_refund_identity(uuid,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.adopt_wallet_refund_identity(uuid,text,uuid) TO service_role;

CREATE FUNCTION public.finish_wallet_refund_item(p_item_id uuid,p_claim_token uuid,p_outcome text,p_provider_refund_id text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i public.wallet_refund_items; r public.wallet_refund_requests; w public.wallets;
  remaining numeric; pending integer; completed integer; failed integer; state text;
BEGIN
  i:=public.lock_wallet_refund_item(p_item_id);
  SELECT * INTO r FROM public.wallet_refund_requests WHERE id=i.refund_request_id;
  SELECT * INTO w FROM public.wallets WHERE id=r.wallet_id;
  p_provider_refund_id:=nullif(btrim(p_provider_refund_id),'');
  IF p_claim_token IS NULL OR i.claim_token IS DISTINCT FROM p_claim_token THEN RAISE insufficient_privilege; END IF;
  IF p_outcome IS NULL OR p_outcome NOT IN ('completed','failed','pending','unknown') THEN RAISE EXCEPTION 'Invalid provider outcome'; END IF;
  IF i.status IN ('completed','failed') THEN
    IF p_outcome<>i.status OR p_provider_refund_id IS DISTINCT FROM i.provider_refund_id THEN RAISE EXCEPTION 'Terminal refund result mismatch'; END IF;
    RETURN jsonb_build_object('status',r.status,'item_status',i.status,'idempotent',true);
  END IF;
  IF i.submission_started_at IS NULL OR (p_provider_refund_id IS NOT NULL AND i.provider_refund_id IS DISTINCT FROM p_provider_refund_id)
    OR (p_outcome IN ('completed','failed') AND (i.provider_outcome IS DISTINCT FROM p_outcome OR i.provider_refund_id IS NULL)) THEN
    RAISE EXCEPTION 'Persist verified provider evidence before settlement';
  END IF;
  IF p_outcome IN ('pending','unknown') THEN
    UPDATE public.wallet_refund_items SET status='reconciliation_required',updated_at=now() WHERE id=i.id;
  ELSE
    DELETE FROM public.wallet_hold_allocations WHERE hold_id=r.hold_id AND lot_id=i.lot_id AND amount=i.amount;
    IF NOT FOUND THEN RAISE EXCEPTION 'Refund allocation mismatch'; END IF;
    SELECT coalesce(sum(amount),0) INTO remaining FROM public.wallet_hold_allocations WHERE hold_id=r.hold_id;
    UPDATE public.wallet_holds SET amount=CASE WHEN remaining>0 THEN remaining ELSE amount END,
      status=CASE WHEN remaining>0 THEN 'active' ELSE 'released' END,
      released_at=CASE WHEN remaining=0 THEN now() ELSE released_at END,updated_at=now() WHERE id=r.hold_id;
    UPDATE public.wallet_refund_items SET status=p_outcome,completed_at=CASE WHEN p_outcome='completed' THEN now() END,updated_at=now() WHERE id=i.id;
    IF p_outcome='completed' THEN
      UPDATE public.wallets SET balance=balance-i.amount,updated_at=now() WHERE id=w.id;
      INSERT INTO public.wallet_transactions(wallet_id,user_id,type,amount,balance_before,balance_after,description,reference_id,status,metadata)
      VALUES(w.id,r.user_id,'refund_payout',i.amount,w.balance,w.balance-i.amount,'Unused wallet funds refund',
        'refund_'||i.id,'completed',jsonb_build_object('refund_item_id',i.id,'provider_refund_id',i.provider_refund_id));
    END IF;
  END IF;
  SELECT count(*) FILTER(WHERE status IN ('pending','processing','reconciliation_required')),
    count(*) FILTER(WHERE status='completed'),count(*) FILTER(WHERE status='failed') INTO pending,completed,failed
    FROM public.wallet_refund_items WHERE refund_request_id=r.id;
  state:=CASE WHEN pending>0 THEN 'under_review' WHEN failed=0 THEN 'completed' WHEN completed>0 THEN 'partially_completed' ELSE 'failed' END;
  UPDATE public.wallet_refund_requests SET status=state,updated_at=now() WHERE id=r.id;
  RETURN jsonb_build_object('status',state,'item_status',p_outcome);
END;
$$;
REVOKE ALL ON FUNCTION public.finish_wallet_refund_item(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.finish_wallet_refund_item(uuid,uuid,text,text) TO service_role;
CREATE OR REPLACE FUNCTION public.get_wallet_summary(p_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_wallet RECORD;
  v_held_amount NUMERIC := 0.00;
  v_available_amount NUMERIC := 0.00;
  v_refundable_amount NUMERIC := 0.00;
  v_promotional_amount NUMERIC := 0.00;
BEGIN
  PERFORM public.assert_wallet_access(p_user_id);
  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;

  IF v_wallet.id IS NULL THEN
    -- Return default zero summary
    RETURN jsonb_build_object(
      'wallet_id', null,
      'posted_balance', 0.00,
      'held_amount', 0.00,
      'available_balance', 0.00,
      'refundable_balance', 0.00,
      'promotional_balance', 0.00,
      'currency', 'USD'
    );
  END IF;

  -- Calculate active holds
  SELECT COALESCE(SUM(amount), 0.00) INTO v_held_amount
  FROM public.wallet_holds
  WHERE user_id = p_user_id AND status = 'active';

  v_available_amount := GREATEST(0.00, v_wallet.balance - v_held_amount);

  v_refundable_amount:=(public.quote_wallet_refund(p_user_id)->>'eligible_amount')::numeric;

  -- Calculate promotional / gift balance
  SELECT COALESCE(SUM(remaining_amount), 0.00) INTO v_promotional_amount
  FROM public.wallet_funding_lots
  WHERE user_id = p_user_id
    AND status = 'active'
    AND origin_type IN ('promotional', 'unverified_legacy', 'gift_received');

  RETURN jsonb_build_object(
    'wallet_id', v_wallet.id,
    'posted_balance', v_wallet.balance,
    'held_amount', v_held_amount,
    'available_balance', v_available_amount,
    'refundable_balance', v_refundable_amount,
    'promotional_balance', v_promotional_amount,
    'currency', v_wallet.currency
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_wallet_summary(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_wallet_summary(uuid) TO authenticated,service_role;
CREATE OR REPLACE FUNCTION public.debit_wallet_for_call(
  p_user_id UUID,
  p_call_id UUID,
  p_amount NUMERIC,
  p_description TEXT DEFAULT 'International Call'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_wallet_id UUID;
  v_balance_before NUMERIC;
  v_balance_after NUMERIC;
  v_txn_id UUID;
  v_ref_id TEXT;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount<>round(p_amount,2) OR p_amount::text IN ('NaN','Infinity','-Infinity') THEN
    RETURN NULL;
  END IF;

  IF NOT EXISTS(SELECT 1 FROM public.call_records WHERE id=p_call_id AND user_id=p_user_id) THEN
    RAISE EXCEPTION 'Call ownership required' USING ERRCODE='42501';
  END IF;
  v_ref_id := 'call_' || p_call_id::text;

  -- Check if already debited for this call (idempotency)
  SELECT id INTO v_txn_id
  FROM public.wallet_transactions
  WHERE reference_id = v_ref_id AND user_id=p_user_id AND type='call_debit' AND status='completed'
  LIMIT 1;

  IF v_txn_id IS NOT NULL THEN
    IF NOT EXISTS(SELECT 1 FROM public.wallet_transactions WHERE id=v_txn_id AND amount=p_amount) THEN RAISE EXCEPTION 'Call reference amount mismatch'; END IF;
    RETURN v_txn_id;
  END IF;

  -- Lock wallet
  SELECT id, balance INTO v_wallet_id, v_balance_before
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  SELECT id INTO v_txn_id FROM public.wallet_transactions
    WHERE user_id=p_user_id AND reference_id=v_ref_id AND type='call_debit';
  IF FOUND THEN
    IF NOT EXISTS(SELECT 1 FROM public.wallet_transactions WHERE id=v_txn_id AND amount=p_amount) THEN RAISE EXCEPTION 'Call reference amount mismatch'; END IF;
    RETURN v_txn_id;
  END IF;
  IF v_balance_before-p_amount < coalesce((SELECT sum(amount) FROM public.wallet_holds
      WHERE user_id=p_user_id AND status='active'),0) THEN
    RAISE EXCEPTION 'Insufficient available balance for legacy call; reconciliation required';
  END IF;
  v_balance_after := v_balance_before - p_amount;

  UPDATE public.wallets
  SET balance = v_balance_after,
      total_spent = total_spent + p_amount
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, status
  ) VALUES (
    v_wallet_id, p_user_id, 'call_debit', p_amount, v_balance_before, v_balance_after,
    p_description, v_ref_id, 'completed'
  ) RETURNING id INTO v_txn_id;

  -- Link transaction to call record
  UPDATE public.call_records
  SET wallet_txn_id = v_txn_id,
      total_cost_usd = p_amount,
      updated_at = NOW()
  WHERE id = p_call_id;

  RETURN v_txn_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.debit_wallet_for_call(uuid,uuid,numeric,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.debit_wallet_for_call(uuid,uuid,numeric,text) TO service_role;
CREATE OR REPLACE FUNCTION public.reap_stuck_executions(
  p_stuck_after_minutes integer DEFAULT 10,
  p_max_retries integer DEFAULT 3
)
RETURNS TABLE(requeued integer, dead_lettered integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_requeued integer := 0;
  v_dead integer := 0;
  v_in_flight_count integer := 0;
  v_dead_hold_ids uuid[];
  v_dead_hold uuid;
BEGIN
  IF p_stuck_after_minutes IS NULL OR p_stuck_after_minutes NOT BETWEEN 5 AND 1440
    OR p_max_retries IS NULL OR p_max_retries NOT BETWEEN 1 AND 10 THEN
    RAISE EXCEPTION 'Invalid reaper bounds' USING ERRCODE='22023';
  END IF;
  -- 1. Identify stuck processing executions
  -- Distinguish between safe-to-requeue (pre-submission) and in-flight/ambiguous (post-submission)
  WITH stuck_all AS (
    SELECT t.id, t.reaper_retries, COALESCE(t.pre_processing_status, 'pending') AS back_to,
           t.reloadly_transaction_id,
           (COALESCE(h.carrier_in_flight, false) OR COALESCE(t.carrier_in_flight, false)) AS carrier_in_flight
    FROM public.topup_executions t
    LEFT JOIN public.wallet_holds h ON h.id = t.wallet_hold_id
    WHERE t.status = 'processing'
      AND COALESCE(t.processing_since, t.created_at) < now() - make_interval(mins => p_stuck_after_minutes)
    FOR UPDATE OF t SKIP LOCKED
  ),
  -- In-flight / ambiguous submissions: MUST NOT be requeued to pending (F06 double-purchase prevention)
  in_flight_flagged AS (
    UPDATE public.topup_executions t
    SET status = 'failed',
        carrier_in_flight = true,
        failure_reason = 'Stuck in processing with in-flight carrier submission. Dead-lettered for manual reconciliation to prevent duplicate purchase.',
        completed_at = now()
    FROM stuck_all s
    WHERE t.id = s.id
      AND (s.reloadly_transaction_id IS NOT NULL OR s.carrier_in_flight)
    RETURNING t.id
  ),
  -- Dead-letter pre-submission executions that have exhausted retries
  dead AS (
    UPDATE public.topup_executions t
    SET status = 'failed',
        failure_reason = 'Dead-lettered by reaper: repeatedly stuck in processing before provider submission (worker crash?)',
        completed_at = now()
    FROM stuck_all s
    WHERE t.id = s.id
      AND s.reloadly_transaction_id IS NULL
      AND NOT s.carrier_in_flight
      AND s.reaper_retries >= p_max_retries
    RETURNING t.id,t.wallet_hold_id
  ),
  -- Safe to requeue: pre-submission executions with retries remaining
  requeue AS (
    UPDATE public.topup_executions t
    SET status = s.back_to,
        reaper_retries = t.reaper_retries + 1,
        processing_since = NULL
    FROM stuck_all s
    WHERE t.id = s.id
      AND s.reloadly_transaction_id IS NULL
      AND NOT s.carrier_in_flight
      AND s.reaper_retries < p_max_retries
    RETURNING t.id
  )
  SELECT 
    (SELECT count(*) FROM requeue),
    (SELECT count(*) FROM dead) + (SELECT count(*) FROM in_flight_flagged),
    (SELECT count(*) FROM in_flight_flagged),
    (SELECT array_agg(wallet_hold_id) FROM dead WHERE wallet_hold_id IS NOT NULL)
  INTO v_requeued, v_dead, v_in_flight_count,v_dead_hold_ids;

  FOREACH v_dead_hold IN ARRAY coalesce(v_dead_hold_ids,'{}'::uuid[]) LOOP
    PERFORM public.release_wallet_hold(v_dead_hold,'Reaper: terminal pre-submission failure')
      FROM public.wallet_holds WHERE id=v_dead_hold AND status='active' AND NOT carrier_in_flight
        AND recovery_contract_version>=1;
  END LOOP;

  IF v_in_flight_count > 0 THEN
    INSERT INTO public.system_alerts (kind, message, details)
    VALUES (
      'in_flight_execution_stuck',
      v_in_flight_count || ' execution(s) were stuck in processing with in-flight submissions and dead-lettered to prevent duplicate purchases.',
      jsonb_build_object('in_flight_count', v_in_flight_count, 'stuck_after_minutes', p_stuck_after_minutes)
    );
  END IF;

  IF (v_dead - v_in_flight_count) > 0 THEN
    INSERT INTO public.system_alerts (kind, message, details)
    VALUES (
      'execution_dead_lettered',
      (v_dead - v_in_flight_count) || ' execution(s) dead-lettered after repeatedly getting stuck in processing.',
      jsonb_build_object('dead_lettered', v_dead - v_in_flight_count, 'requeued', v_requeued)
    );
  END IF;

  RETURN QUERY SELECT v_requeued, v_dead;
END;
$$;

REVOKE ALL ON FUNCTION public.reap_stuck_executions(integer,integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.reap_stuck_executions(integer,integer) TO service_role;

ALTER TABLE public.wallet_holds ADD COLUMN recovery_required_at timestamptz;
CREATE FUNCTION public.recover_expired_wallet_holds(p_limit integer DEFAULT 100)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE h public.wallet_holds; e public.topup_executions; o public.sim_setup_orders;
  v_safe boolean; v_released integer:=0; v_review integer:=0;
BEGIN
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Invalid recovery limit'; END IF;
  FOR h IN SELECT * FROM public.wallet_holds WHERE status='active' AND expires_at<now()
    ORDER BY expires_at,id LIMIT p_limit
  LOOP
    v_safe:=false;
    IF h.order_type IN ('refill_instant','refill_scheduled','setup_refill') THEN
      SELECT * INTO e FROM public.topup_executions WHERE wallet_hold_id=h.id
        ORDER BY created_at DESC LIMIT 1 FOR UPDATE SKIP LOCKED;
      v_safe:=e.id IS NOT NULL AND e.status IN ('failed','cancelled')
        AND e.reloadly_transaction_id IS NULL AND NOT coalesce(e.carrier_in_flight,false);
    ELSIF h.order_type='plan_fee' THEN
      SELECT * INTO o FROM public.sim_setup_orders WHERE annual_fee_hold_id=h.id FOR UPDATE SKIP LOCKED;
      v_safe:=o.id IS NOT NULL AND o.status IN ('failed','cancelled') AND o.provider_tx_id IS NULL
        AND NOT EXISTS(SELECT 1 FROM public.topup_executions t WHERE t.wallet_hold_id=o.first_refill_hold_id
          AND (t.status IN ('processing','success') OR t.reloadly_transaction_id IS NOT NULL OR t.carrier_in_flight))
        AND NOT EXISTS(SELECT 1 FROM public.wallet_holds r WHERE r.id=o.first_refill_hold_id AND (r.carrier_in_flight OR r.recovery_contract_version<1));
    END IF;
    -- Skip busy wallets instead of acquiring locks in opposition to an owner
    -- operation. Recheck the hold under lock; expiry by itself is never proof.
    PERFORM 1 FROM public.wallets WHERE id=h.wallet_id FOR UPDATE SKIP LOCKED;
    IF NOT FOUND THEN CONTINUE; END IF;
    SELECT * INTO h FROM public.wallet_holds WHERE id=h.id AND status='active' FOR UPDATE SKIP LOCKED;
    IF NOT FOUND THEN CONTINUE; END IF;
    IF v_safe AND NOT h.carrier_in_flight AND h.recovery_contract_version>=1 THEN
      PERFORM public.release_wallet_hold(h.id,'Recovery: confirmed terminal pre-submission failure');
      v_released:=v_released+1;
    ELSIF h.recovery_required_at IS NULL THEN
      UPDATE public.wallet_holds SET recovery_required_at=now(),updated_at=now() WHERE id=h.id;
      INSERT INTO public.system_alerts(kind,message,details)
        VALUES('wallet_hold_reconciliation_required','Expired reservation requires operation reconciliation',
          jsonb_build_object('hold_id',h.id,'order_type',h.order_type));
      v_review:=v_review+1;
    END IF;
  END LOOP;
  -- A crashed payout processor must be reconciled, never automatically paid
  -- again. Known provider IDs can be polled by the refund processor.
  UPDATE public.wallet_refund_items SET status='reconciliation_required',claim_token=NULL,updated_at=now()
    WHERE status='processing' AND claimed_at<now()-interval '30 minutes';
  RETURN jsonb_build_object('released',v_released,'review_required',v_review);
END;
$$;
REVOKE ALL ON FUNCTION public.recover_expired_wallet_holds(integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.recover_expired_wallet_holds(integer) TO service_role,postgres;

-- Use actual ledger deltas, including signed admin adjustments. Failed entries
-- never contribute. This does not rewrite or infer historical transactions.
CREATE OR REPLACE VIEW public.wallet_reconciliation WITH(security_invoker=true) AS
SELECT w.id AS wallet_id,w.user_id,w.balance,
  coalesce(sum(t.balance_after-t.balance_before) FILTER(WHERE t.status='completed'),0) AS ledger_sum,
  w.balance-coalesce(sum(t.balance_after-t.balance_before) FILTER(WHERE t.status='completed'),0) AS drift
FROM public.wallets w LEFT JOIN public.wallet_transactions t ON t.wallet_id=w.id GROUP BY w.id,w.user_id,w.balance;
REVOKE ALL ON public.wallet_reconciliation FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.wallet_reconciliation TO service_role;
COMMIT;
