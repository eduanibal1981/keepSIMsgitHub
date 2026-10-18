-- ============================================================================
-- Migration: 20260907100000_wallet_holds_lots_and_refunds.sql
-- Description: KeepSIMs Wallet Payments & Truth Source Architecture
--             - wallet_funding_lots: Tracks deposit origin and refundability
--             - wallet_holds: Asynchronous holds/reservations
--             - wallet_hold_allocations: Lot allocation mapping per hold
--             - wallet_refund_requests & wallet_refund_items: Unused funds refund
--             - Updated credit_wallet_for_deposit: Auto-generates funding lots
--             - Atomic RPCs: ensure_wallet_v2, reserve_wallet_funds, capture_wallet_hold,
--                            release_wallet_hold, quote_wallet_refund, request_wallet_refund
--             - Reconciled wallet_reconciliation view for all transaction types
--             - Safe idempotent backfill for existing wallet balances
-- ============================================================================

-- 1. WALLET FUNDING LOTS
CREATE TABLE IF NOT EXISTS public.wallet_funding_lots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  origin_type TEXT NOT NULL CHECK (origin_type IN ('paypal_deposit', 'card_deposit', 'promotional', 'gift_received', 'admin_adjustment', 'unverified_legacy')),
  original_reference_id TEXT,
  original_order_id TEXT,
  currency TEXT NOT NULL DEFAULT 'USD',
  funded_amount NUMERIC NOT NULL CHECK (funded_amount >= 0),
  remaining_amount NUMERIC NOT NULL CHECK (remaining_amount >= 0 AND remaining_amount <= funded_amount),
  is_refundable BOOLEAN NOT NULL DEFAULT false,
  refund_deadline TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'fully_consumed', 'partially_refunded', 'fully_refunded', 'disputed', 'restricted')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_funding_lots_user_ref
  ON public.wallet_funding_lots (user_id, original_reference_id)
  WHERE original_reference_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_wallet_funding_lots_user_active
  ON public.wallet_funding_lots (user_id, status, created_at ASC);

-- 2. WALLET HOLDS (RESERVATIONS)
CREATE TABLE IF NOT EXISTS public.wallet_holds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  order_type TEXT NOT NULL CHECK (order_type IN ('refill_instant', 'refill_scheduled', 'plan_fee', 'esim_purchase', 'call_budget', 'offline_voucher', 'refund_request')),
  order_reference_id TEXT NOT NULL,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  currency TEXT NOT NULL DEFAULT 'USD',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'captured', 'released', 'expired')),
  reason TEXT,
  captured_at TIMESTAMPTZ,
  released_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '2 hours'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_wallet_holds_ref UNIQUE(order_type, order_reference_id)
);

CREATE INDEX IF NOT EXISTS idx_wallet_holds_user_active
  ON public.wallet_holds (user_id, status)
  WHERE status = 'active';

-- 3. WALLET HOLD ALLOCATIONS
CREATE TABLE IF NOT EXISTS public.wallet_hold_allocations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hold_id UUID NOT NULL REFERENCES public.wallet_holds(id) ON DELETE CASCADE,
  lot_id UUID NOT NULL REFERENCES public.wallet_funding_lots(id) ON DELETE RESTRICT,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wallet_hold_allocations_hold
  ON public.wallet_hold_allocations (hold_id);

-- 4. WALLET REFUND REQUESTS
CREATE TABLE IF NOT EXISTS public.wallet_refund_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  requested_amount NUMERIC NOT NULL CHECK (requested_amount > 0),
  currency TEXT NOT NULL DEFAULT 'USD',
  hold_id UUID REFERENCES public.wallet_holds(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'processing', 'completed', 'partially_completed', 'failed', 'cancelled', 'under_review')),
  rejection_reason TEXT,
  audit_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wallet_refund_requests_user
  ON public.wallet_refund_requests (user_id, created_at DESC);

-- 5. WALLET REFUND ITEMS (PER CAPTURE)
CREATE TABLE IF NOT EXISTS public.wallet_refund_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  refund_request_id UUID NOT NULL REFERENCES public.wallet_refund_requests(id) ON DELETE CASCADE,
  lot_id UUID NOT NULL REFERENCES public.wallet_funding_lots(id) ON DELETE RESTRICT,
  provider TEXT NOT NULL DEFAULT 'paypal',
  capture_id TEXT NOT NULL,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  currency TEXT NOT NULL DEFAULT 'USD',
  provider_refund_id TEXT,
  idempotency_key TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'reconciliation_required')),
  failure_reason TEXT,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wallet_refund_items_request
  ON public.wallet_refund_items (refund_request_id);

-- ============================================================================
-- RLS POLICIES & SECURITY
-- ============================================================================
ALTER TABLE public.wallet_funding_lots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_holds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_hold_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_refund_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_refund_items ENABLE ROW LEVEL SECURITY;

-- Select own rows policies
DROP POLICY IF EXISTS p_wallet_funding_lots_select ON public.wallet_funding_lots;
CREATE POLICY p_wallet_funding_lots_select ON public.wallet_funding_lots
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS p_wallet_holds_select ON public.wallet_holds;
CREATE POLICY p_wallet_holds_select ON public.wallet_holds
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS p_wallet_hold_allocations_select ON public.wallet_hold_allocations;
CREATE POLICY p_wallet_hold_allocations_select ON public.wallet_hold_allocations
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.wallet_holds h
    WHERE h.id = wallet_hold_allocations.hold_id AND h.user_id = (SELECT auth.uid())
  ));

DROP POLICY IF EXISTS p_wallet_refund_requests_select ON public.wallet_refund_requests;
CREATE POLICY p_wallet_refund_requests_select ON public.wallet_refund_requests
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS p_wallet_refund_items_select ON public.wallet_refund_items;
CREATE POLICY p_wallet_refund_items_select ON public.wallet_refund_items
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.wallet_refund_requests r
    WHERE r.id = wallet_refund_items.refund_request_id AND r.user_id = (SELECT auth.uid())
  ));

-- ============================================================================
-- 6. RPC: ensure_wallet_v2 (Atomic Zero Wallet Creation)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.ensure_wallet_v2(p_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_wallet RECORD;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User ID cannot be null';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;

  IF v_wallet.id IS NULL THEN
    INSERT INTO public.wallets (
      user_id, balance, currency, auto_fund_enabled, total_deposited, total_spent
    ) VALUES (
      p_user_id, 0.00, 'USD', false, 0.00, 0.00
    ) RETURNING * INTO v_wallet;
  END IF;

  RETURN jsonb_build_object(
    'id', v_wallet.id,
    'user_id', v_wallet.user_id,
    'balance', v_wallet.balance,
    'currency', v_wallet.currency
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.ensure_wallet_v2(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_wallet_v2(UUID) TO service_role;

-- ============================================================================
-- 7. RPC: get_wallet_summary
-- ============================================================================
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
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User ID cannot be null';
  END IF;

  -- Caller must be self or service role / admin
  IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Access denied: cannot view another user wallet summary' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id;

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

  -- Calculate refundable balance (active paid deposits within deadline)
  SELECT COALESCE(SUM(remaining_amount), 0.00) INTO v_refundable_amount
  FROM public.wallet_funding_lots
  WHERE user_id = p_user_id 
    AND status = 'active'
    AND is_refundable = true
    AND (refund_deadline IS NULL OR refund_deadline > now());

  -- Ensure refundable does not exceed available balance
  v_refundable_amount := LEAST(v_refundable_amount, v_available_amount);

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

REVOKE ALL ON FUNCTION public.get_wallet_summary(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_wallet_summary(UUID) TO authenticated, service_role;

-- ============================================================================
-- 8. RPC: credit_wallet_for_deposit (Updated with Funding Lots)
-- ============================================================================
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
  IF p_amount IS NULL OR p_amount <= 0 THEN
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
    v_wallet_id, p_user_id, 'deposit', p_amount, v_balance_before, v_balance_after,
    p_description, p_reference_id, 'completed', p_metadata, now()
  ) RETURNING id INTO v_txn_id;

  -- Extract order/capture ID from metadata if present
  IF p_metadata IS NOT NULL THEN
    v_order_id := p_metadata->>'order_id';
    v_capture_id := p_metadata->>'paypal_capture_id';
  END IF;
  IF v_capture_id IS NULL AND p_reference_id LIKE 'paypal_%' THEN
    v_capture_id := replace(p_reference_id, 'paypal_', '');
  END IF;

  -- Record funding source lot
  INSERT INTO public.wallet_funding_lots (
    wallet_id, user_id, origin_type, original_reference_id, original_order_id,
    currency, funded_amount, remaining_amount, is_refundable, refund_deadline, status, created_at
  ) VALUES (
    v_wallet_id, p_user_id, v_origin, COALESCE(v_capture_id, p_reference_id), v_order_id,
    'USD', p_amount, p_amount, v_is_refundable, now() + interval '180 days', 'active', now()
  ) ON CONFLICT (user_id, original_reference_id) WHERE original_reference_id IS NOT NULL
  DO NOTHING;

  RETURN v_txn_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.credit_wallet_for_deposit(uuid, numeric, text, text, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.credit_wallet_for_deposit(uuid, numeric, text, text, jsonb) TO service_role;

-- ============================================================================
-- 9. RPC: reserve_wallet_funds (Hold Creation with Lot Allocation)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.reserve_wallet_funds(
  p_user_id UUID,
  p_amount NUMERIC,
  p_order_type TEXT,
  p_order_reference_id TEXT,
  p_reason TEXT DEFAULT NULL,
  p_ttl_minutes INTEGER DEFAULT 120
)
RETURNS UUID
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
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Hold amount must be positive, got %', p_amount;
  END IF;

  IF p_order_type IS NULL OR p_order_reference_id IS NULL THEN
    RAISE EXCEPTION 'order_type and order_reference_id are required';
  END IF;

  -- Idempotency check: if active hold exists for this reference, adopt it
  SELECT * INTO v_existing_hold
  FROM public.wallet_holds
  WHERE order_type = p_order_type AND order_reference_id = p_order_reference_id;

  IF v_existing_hold.id IS NOT NULL THEN
    IF v_existing_hold.status = 'active' THEN
      RETURN v_existing_hold.id;
    ELSE
      RAISE EXCEPTION 'Hold for % % is already in status %', p_order_type, p_order_reference_id, v_existing_hold.status;
    END IF;
  END IF;

  -- Lock wallet
  SELECT id, balance INTO v_wallet_id, v_balance
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
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
    SELECT * FROM public.wallet_funding_lots
    WHERE user_id = p_user_id AND status = 'active' AND remaining_amount > 0
    ORDER BY
      CASE
        WHEN origin_type IN ('promotional', 'unverified_legacy') THEN 1
        WHEN origin_type = 'gift_received' THEN 2
        ELSE 3
      END ASC,
      created_at ASC
    FOR UPDATE
  LOOP
    EXIT WHEN v_needed <= 0;

    v_alloc_amount := LEAST(v_lot.remaining_amount, v_needed);

    INSERT INTO public.wallet_hold_allocations (hold_id, lot_id, amount, created_at)
    VALUES (v_hold_id, v_lot.id, v_alloc_amount, now());

    v_needed := v_needed - v_alloc_amount;
  END LOOP;

  RETURN v_hold_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.reserve_wallet_funds(UUID, NUMERIC, TEXT, TEXT, TEXT, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_wallet_funds(UUID, NUMERIC, TEXT, TEXT, TEXT, INTEGER) TO service_role;

-- ============================================================================
-- 10. RPC: capture_wallet_hold (Atomic Hold Consumption & Ledger Debit)
-- ============================================================================
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
  -- Lock hold
  SELECT * INTO v_hold
  FROM public.wallet_holds
  WHERE id = p_hold_id
  FOR UPDATE;

  IF v_hold.id IS NULL THEN
    RAISE EXCEPTION 'Hold not found: %', p_hold_id;
  END IF;

  IF v_hold.status = 'captured' THEN
    -- Idempotent retry: return existing transaction if recorded in metadata
    SELECT id INTO v_txn_id
    FROM public.wallet_transactions
    WHERE reference_id = 'hold_' || p_hold_id::text;
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

  -- Update allocated lots (consume remaining_amount)
  FOR v_alloc IN
    SELECT * FROM public.wallet_hold_allocations
    WHERE hold_id = p_hold_id
  LOOP
    UPDATE public.wallet_funding_lots
    SET remaining_amount = remaining_amount - v_alloc.amount,
        status = CASE WHEN remaining_amount - v_alloc.amount = 0 THEN 'fully_consumed' ELSE status END,
        updated_at = now()
    WHERE id = v_alloc.lot_id;
  END LOOP;

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
    jsonb_build_object('hold_id', p_hold_id, 'order_type', v_hold.order_type, 'order_reference_id', v_hold.order_reference_id) || COALESCE(p_metadata, '{}'::jsonb),
    now()
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.capture_wallet_hold(UUID, TEXT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.capture_wallet_hold(UUID, TEXT, TEXT, JSONB) TO service_role;

-- ============================================================================
-- 11. RPC: release_wallet_hold (Atomic Hold Cancellation / Release)
-- ============================================================================
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
  SELECT * INTO v_hold
  FROM public.wallet_holds
  WHERE id = p_hold_id
  FOR UPDATE;

  IF v_hold.id IS NULL THEN
    RAISE EXCEPTION 'Hold not found: %', p_hold_id;
  END IF;

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

REVOKE ALL ON FUNCTION public.release_wallet_hold(UUID, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.release_wallet_hold(UUID, TEXT) TO service_role;

-- ============================================================================
-- 12. RPC: quote_wallet_refund (FIFO Unused Paid Lots Quote)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.quote_wallet_refund(p_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_wallet RECORD;
  v_held NUMERIC := 0.00;
  v_available NUMERIC := 0.00;
  v_refundable NUMERIC := 0.00;
  v_lots JSONB := '[]'::jsonb;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User ID cannot be null';
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Access denied: cannot quote refund for another user' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id;

  IF v_wallet.id IS NULL THEN
    RETURN jsonb_build_object('eligible_amount', 0.00, 'items', '[]'::jsonb);
  END IF;

  SELECT COALESCE(SUM(amount), 0.00) INTO v_held
  FROM public.wallet_holds
  WHERE user_id = p_user_id AND status = 'active';

  v_available := GREATEST(0.00, v_wallet.balance - v_held);

  -- Sum eligible refundable lots
  SELECT COALESCE(SUM(remaining_amount), 0.00) INTO v_refundable
  FROM public.wallet_funding_lots
  WHERE user_id = p_user_id
    AND is_refundable = true
    AND status = 'active'
    AND (refund_deadline IS NULL OR refund_deadline > now());

  v_refundable := LEAST(v_refundable, v_available);

  SELECT jsonb_agg(jsonb_build_object(
    'lot_id', id,
    'capture_id', original_reference_id,
    'funded_amount', funded_amount,
    'remaining_amount', remaining_amount,
    'refund_deadline', refund_deadline
  )) INTO v_lots
  FROM (
    SELECT * FROM public.wallet_funding_lots
    WHERE user_id = p_user_id
      AND is_refundable = true
      AND status = 'active'
      AND (refund_deadline IS NULL OR refund_deadline > now())
    ORDER BY created_at ASC
  ) sub;

  RETURN jsonb_build_object(
    'eligible_amount', v_refundable,
    'available_balance', v_available,
    'currency', 'USD',
    'lots', COALESCE(v_lots, '[]'::jsonb)
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.quote_wallet_refund(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quote_wallet_refund(UUID) TO authenticated, service_role;

-- ============================================================================
-- 13. RPC: request_wallet_refund
-- ============================================================================
CREATE OR REPLACE FUNCTION public.request_wallet_refund(
  p_user_id UUID,
  p_amount NUMERIC,
  p_reason TEXT DEFAULT 'Customer requested refund of unused balance'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_wallet RECORD;
  v_held NUMERIC := 0.00;
  v_available NUMERIC := 0.00;
  v_refundable NUMERIC := 0.00;
  v_request_id UUID;
  v_hold_id UUID;
  v_needed NUMERIC;
  v_lot RECORD;
  v_item_amount NUMERIC;
  v_item_id UUID;
  v_item_count INTEGER := 0;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Refund amount must be positive, got %', p_amount;
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Access denied: cannot request refund for another user' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet.id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  SELECT COALESCE(SUM(amount), 0.00) INTO v_held
  FROM public.wallet_holds
  WHERE user_id = p_user_id AND status = 'active';

  v_available := v_wallet.balance - v_held;

  IF v_available < p_amount THEN
    RAISE EXCEPTION 'Requested refund amount % exceeds available balance %', p_amount, v_available;
  END IF;

  -- Check eligible refundable lots
  SELECT COALESCE(SUM(remaining_amount), 0.00) INTO v_refundable
  FROM public.wallet_funding_lots
  WHERE user_id = p_user_id
    AND is_refundable = true
    AND status = 'active'
    AND (refund_deadline IS NULL OR refund_deadline > now());

  IF v_refundable < p_amount THEN
    RAISE EXCEPTION 'Requested refund amount % exceeds eligible refundable paid deposits %', p_amount, v_refundable;
  END IF;

  -- Create refund request
  INSERT INTO public.wallet_refund_requests (
    user_id, wallet_id, requested_amount, currency, status, audit_notes, created_at
  ) VALUES (
    p_user_id, v_wallet.id, p_amount, 'USD', 'requested', p_reason, now()
  ) RETURNING id INTO v_request_id;

  -- Create hold for the refund
  INSERT INTO public.wallet_holds (
    wallet_id, user_id, order_type, order_reference_id, amount, currency,
    status, reason, created_at
  ) VALUES (
    v_wallet.id, p_user_id, 'refund_request', 'refund_' || v_request_id::text, p_amount, 'USD',
    'active', 'Reserved for refund request ' || v_request_id::text, now()
  ) RETURNING id INTO v_hold_id;

  UPDATE public.wallet_refund_requests SET hold_id = v_hold_id WHERE id = v_request_id;

  -- Allocate to specific lots and create refund items
  v_needed := p_amount;

  FOR v_lot IN
    SELECT * FROM public.wallet_funding_lots
    WHERE user_id = p_user_id
      AND is_refundable = true
      AND status = 'active'
      AND (refund_deadline IS NULL OR refund_deadline > now())
      AND remaining_amount > 0
    ORDER BY created_at ASC
    FOR UPDATE
  LOOP
    EXIT WHEN v_needed <= 0;

    v_item_amount := LEAST(v_lot.remaining_amount, v_needed);

    -- Record hold allocation
    INSERT INTO public.wallet_hold_allocations (hold_id, lot_id, amount, created_at)
    VALUES (v_hold_id, v_lot.id, v_item_amount, now());

    -- Create refund item
    INSERT INTO public.wallet_refund_items (
      refund_request_id, lot_id, provider, capture_id, amount, currency,
      idempotency_key, status, created_at
    ) VALUES (
      v_request_id, v_lot.id, 'paypal', v_lot.original_reference_id, v_item_amount, 'USD',
      'refitem_' || v_request_id::text || '_' || v_lot.id::text,
      'pending', now()
    ) RETURNING id INTO v_item_id;

    v_item_count := v_item_count + 1;
    v_needed := v_needed - v_item_amount;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'refund_request_id', v_request_id,
    'hold_id', v_hold_id,
    'amount', p_amount,
    'item_count', v_item_count
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.request_wallet_refund(UUID, NUMERIC, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_wallet_refund(UUID, NUMERIC, TEXT) TO authenticated, service_role;

-- ============================================================================
-- 14. UPDATED RECONCILIATION VIEW (All Transaction Types Included)
-- ============================================================================
CREATE OR REPLACE VIEW public.wallet_reconciliation
WITH (security_invoker = true) AS
SELECT
  w.id AS wallet_id,
  w.user_id,
  w.balance,
  COALESCE(SUM(
    CASE
      WHEN t.type IN ('deposit', 'refund', 'referral_credit', 'auto_fund', 'gift_received', 'admin_credit') THEN t.amount
      WHEN t.type IN ('topup_debit', 'welcome_home_debit', 'plan_fee_debit', 'esim_purchase_debit', 'call_debit', 'voucher_purchase_debit', 'gift_sent', 'refund_payout', 'admin_debit') THEN -t.amount
      ELSE 0.00
    END
  ), 0.00) AS ledger_sum,
  w.balance - COALESCE(SUM(
    CASE
      WHEN t.type IN ('deposit', 'refund', 'referral_credit', 'auto_fund', 'gift_received', 'admin_credit') THEN t.amount
      WHEN t.type IN ('topup_debit', 'welcome_home_debit', 'plan_fee_debit', 'esim_purchase_debit', 'call_debit', 'voucher_purchase_debit', 'gift_sent', 'refund_payout', 'admin_debit') THEN -t.amount
      ELSE 0.00
    END
  ), 0.00) AS drift
FROM public.wallets w
LEFT JOIN public.wallet_transactions t ON t.wallet_id = w.id
GROUP BY w.id, w.user_id, w.balance;

REVOKE ALL ON public.wallet_reconciliation FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.wallet_reconciliation TO service_role;

-- ============================================================================
-- 15. SAFE IDEMPOTENT BACKFILL OF HISTORICAL WALLETS
-- ============================================================================
DO $$
DECLARE
  v_w RECORD;
  v_txn RECORD;
  v_credited_from_txns NUMERIC;
  v_unclassified NUMERIC;
BEGIN
  FOR v_w IN SELECT * FROM public.wallets WHERE balance > 0 LOOP
    v_credited_from_txns := 0.00;

    -- Map verified paypal deposits
    FOR v_txn IN
      SELECT * FROM public.wallet_transactions
      WHERE wallet_id = v_w.id AND type = 'deposit' AND reference_id LIKE 'paypal_%'
    LOOP
      INSERT INTO public.wallet_funding_lots (
        wallet_id, user_id, origin_type, original_reference_id,
        currency, funded_amount, remaining_amount, is_refundable, refund_deadline, status, created_at
      ) VALUES (
        v_w.id, v_w.user_id, 'paypal_deposit', replace(v_txn.reference_id, 'paypal_', ''),
        'USD', v_txn.amount, v_txn.amount, true, COALESCE(v_txn.created_at, now()) + interval '180 days', 'active', COALESCE(v_txn.created_at, now())
      ) ON CONFLICT (user_id, original_reference_id) WHERE original_reference_id IS NOT NULL
      DO NOTHING;

      v_credited_from_txns := v_credited_from_txns + v_txn.amount;
    END LOOP;

    -- Any balance exceeding verified deposits is classified as unverified_legacy (spendable in app, non-refundable to cash)
    v_unclassified := v_w.balance - v_credited_from_txns;
    IF v_unclassified > 0 THEN
      INSERT INTO public.wallet_funding_lots (
        wallet_id, user_id, origin_type, original_reference_id,
        currency, funded_amount, remaining_amount, is_refundable, status, created_at
      ) VALUES (
        v_w.id, v_w.user_id, 'unverified_legacy', 'legacy_init_' || v_w.id::text,
        'USD', v_unclassified, v_unclassified, false, 'active', now()
      ) ON CONFLICT (user_id, original_reference_id) WHERE original_reference_id IS NOT NULL
      DO NOTHING;
    END IF;
  END LOOP;
END;
$$;

-- ============================================================================
-- 15. RPC: admin_list_refund_requests
-- ============================================================================
CREATE OR REPLACE FUNCTION public.admin_list_refund_requests(
  p_status text DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  user_email text,
  amount numeric,
  currency text,
  reason text,
  status text,
  hold_id uuid,
  items jsonb,
  created_at timestamptz,
  processed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT 
    r.id,
    r.user_id,
    p.email::text AS user_email,
    r.amount,
    r.currency,
    r.reason,
    r.status,
    r.hold_id,
    COALESCE(
      (
        SELECT jsonb_agg(jsonb_build_object(
          'id', i.id,
          'lot_id', i.lot_id,
          'capture_id', i.original_capture_id,
          'amount', i.amount,
          'paypal_refund_id', i.paypal_refund_id,
          'status', i.status
        ))
        FROM public.wallet_refund_items i
        WHERE i.refund_request_id = r.id
      ),
      '[]'::jsonb
    ) AS items,
    r.created_at,
    r.processed_at
  FROM public.wallet_refund_requests r
  LEFT JOIN public.profiles p ON p.id = r.user_id
  WHERE (p_status IS NULL OR r.status = p_status)
  ORDER BY r.created_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_refund_requests(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_refund_requests(text, integer) TO authenticated, service_role;
