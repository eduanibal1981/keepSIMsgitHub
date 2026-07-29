-- G3 regression suite — gift / send wallet credit
-- (doc/PRODUCTION_PLAN_REVIEW.md § 6, feature #3).
--
-- This is the first RPC in the project that is BOTH callable by `authenticated`
-- AND moves money between two users, so the suite is weighted towards the two
-- questions that actually matter:
--
--   1. Did adding it widen the F0/F1/F2 perimeter? The four wallet money
--      helpers must still be service_role-only, and `transfer_wallet_credit`
--      itself must not be reachable by anon.
--   2. Can a signed-in user move money that is not theirs to move? Sender is
--      auth.uid() and nothing else; only ledger-derived deposits and received
--      gifts are transferable; the ledger conserves value exactly.
--
-- Probed as a REAL `authenticated` role with a JWT, never as postgres — a
-- SECURITY DEFINER function sees current_user = its owner, which is how four
-- separate guards in this project shipped as dead code.
--
-- Uses the existing fixtures only — creates no auth.users rows. Every write is
-- undone by the single ROLLBACK at the end.
--
-- ============================================================================
-- HOW TO RUN — as ONE execute_sql call. MCP makes each call its own
-- transaction, so a split file never pairs BEGIN with ROLLBACK and the INSERTs
-- COMMIT. That is how test residue leaked into production three times here.
-- ============================================================================
-- Last run 2026-07-29: 18/18 PASSED.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE g3(t text, outcome text) ON COMMIT DROP;
GRANT INSERT, SELECT ON g3 TO authenticated;

-- --------------------------------------------------------------------------
-- Part 1 — the grant matrix, read from the catalog.
-- --------------------------------------------------------------------------
DO $$
DECLARE
  v_n int; v_bad text; v_passed int := 0;
  money_fns text[] := ARRAY[
    'credit_wallet_for_refund(uuid,numeric,text,text,uuid,text)',
    'debit_wallet_for_topup(uuid,uuid,numeric,text,text,text)',
    'credit_wallet_for_deposit(uuid,numeric,text,text,jsonb)',
    'credit_wallet(uuid,numeric,text,text,text)'
  ];
BEGIN
  -- T1: the new RPC is callable by signed-in users. That is the feature.
  IF NOT has_function_privilege('authenticated',
        'public.transfer_wallet_credit(text,numeric,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'T1 FAIL: authenticated cannot execute transfer_wallet_credit';
  END IF;
  INSERT INTO g3 VALUES ('T1 transfer_wallet_credit is authenticated-callable','PASS');
  v_passed := v_passed + 1;

  -- T2: ...and by nobody holding only the publishable key. An anon-callable
  --     money mover is finding F-2 all over again.
  IF has_function_privilege('anon',
        'public.transfer_wallet_credit(text,numeric,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'T2 FAIL: anon can execute transfer_wallet_credit';
  END IF;
  INSERT INTO g3 VALUES ('T2 transfer_wallet_credit is not anon-callable','PASS');
  v_passed := v_passed + 1;

  -- T3: THE REGRESSION THAT MATTERS. G3 reuses debit_wallet_for_topup by
  --     nesting inside it, which is the sort of change that tempts a future
  --     session into "just grant it to authenticated". All four wallet money
  --     helpers stay service_role-only — F1 and F2 exist because they did not.
  SELECT string_agg(f, ', '), count(*) INTO v_bad, v_n
  FROM unnest(money_fns) f
  WHERE has_function_privilege('anon', 'public.' || f, 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.' || f, 'EXECUTE');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T3 FAIL: % wallet money helper(s) reachable by a client role: %', v_n, v_bad;
  END IF;
  INSERT INTO g3 VALUES ('T3 all 4 wallet money helpers stay service_role-only','PASS');
  v_passed := v_passed + 1;

  -- T4: SECURITY DEFINER with a pinned search_path. Without the pin, a caller
  --     who can create a schema redirects every unqualified name in the body.
  SELECT count(*) INTO v_n
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'transfer_wallet_credit'
    AND p.prosecdef = true
    AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%');
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'T4 FAIL: transfer_wallet_credit is not SECURITY DEFINER with a pinned search_path';
  END IF;
  INSERT INTO g3 VALUES ('T4 SECURITY DEFINER with a pinned search_path','PASS');
  v_passed := v_passed + 1;

  -- T5: no parameter can carry a sender. The sender cannot be spoofed because
  --     there is nowhere to put a spoofed value, which is a stronger guarantee
  --     than any in-body check — and the moment someone adds `p_sender_id` for
  --     "an admin gifting on a user's behalf", it is gone. Asserted on the
  --     parameter NAMES, not on a signature string, so adding a harmless
  --     parameter does not fail the suite but adding a dangerous one does.
  SELECT string_agg(a, ', '), count(*) INTO v_bad, v_n
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  CROSS JOIN LATERAL unnest(p.proargnames) AS a
  WHERE n.nspname = 'public' AND p.proname = 'transfer_wallet_credit'
    AND (a ILIKE '%sender%' OR a ILIKE '%user_id%' OR a ILIKE '%from_%' OR a ILIKE '%actor%');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T5 FAIL: transfer_wallet_credit has spoofable sender parameter(s): %', v_bad;
  END IF;
  INSERT INTO g3 VALUES ('T5 no sender parameter — sender is always auth.uid()','PASS');
  v_passed := v_passed + 1;

  -- T6: both idempotency indexes exist. The pre-check is a convenience; these
  --     are what make a double-submit impossible under a race.
  SELECT count(*) INTO v_n FROM pg_indexes
  WHERE schemaname='public'
    AND indexname IN ('uq_wallet_txns_gift_sent_ref','uq_wallet_txns_gift_received_ref');
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'T6 FAIL: expected 2 gift idempotency indexes, found %', v_n;
  END IF;
  INSERT INTO g3 VALUES ('T6 both gift reference_id unique indexes exist','PASS');
  v_passed := v_passed + 1;

  -- T7: the ledger accepts the two new types.
  SELECT count(*) INTO v_n FROM pg_constraint
  WHERE conrelid='public.wallet_transactions'::regclass
    AND conname='wallet_transactions_type_check'
    AND pg_get_constraintdef(oid) LIKE '%gift_sent%'
    AND pg_get_constraintdef(oid) LIKE '%gift_received%';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'T7 FAIL: wallet_transactions type CHECK does not allow the gift types';
  END IF;
  INSERT INTO g3 VALUES ('T7 gift_sent/gift_received allowed by the type CHECK','PASS');
  v_passed := v_passed + 1;

  RAISE NOTICE 'Part 1: % passed', v_passed;
END $$;


-- --------------------------------------------------------------------------
-- Part 2 — behaviour, as a real signed-in user.
--
-- Everything below runs with request.jwt.claims set exactly as PostgREST sets
-- it, so auth.uid() resolves and the nested call-depth guard on
-- debit_wallet_for_topup is exercised for real.
-- --------------------------------------------------------------------------
DO $$
DECLARE
  v_sender    uuid; v_semail text;
  v_recipient uuid; v_remail text;
  v_sb0 numeric; v_rb0 numeric; v_total0 numeric;
  v_rdep0 numeric; v_sspent0 numeric;
  v_res jsonb; v_debit public.wallet_transactions%ROWTYPE;
  v_credit public.wallet_transactions%ROWTYPE;
  v_n int; v_passed int := 0;
BEGIN
  SELECT w.user_id, u.email INTO v_sender, v_semail
  FROM public.wallets w JOIN auth.users u ON u.id = w.user_id
  ORDER BY w.balance DESC LIMIT 1;

  SELECT w.user_id, u.email INTO v_recipient, v_remail
  FROM public.wallets w JOIN auth.users u ON u.id = w.user_id
  WHERE w.user_id <> v_sender ORDER BY w.balance ASC LIMIT 1;

  SELECT balance INTO v_sb0 FROM public.wallets WHERE user_id = v_sender;
  SELECT balance INTO v_rb0 FROM public.wallets WHERE user_id = v_recipient;
  SELECT sum(balance) INTO v_total0 FROM public.wallets;
  SELECT total_deposited INTO v_rdep0   FROM public.wallets WHERE user_id = v_recipient;
  SELECT total_spent     INTO v_sspent0 FROM public.wallets WHERE user_id = v_sender;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_sender::text, 'role', 'authenticated')::text, true);
  DELETE FROM public.rate_limit_buckets WHERE bucket = 'gift_credit';

  -- T8: the transfer itself.
  v_res := public.transfer_wallet_credit(v_remail, 7.50, 'g3test_a', 'for the trip');
  IF (v_res->>'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'T8 FAIL: transfer refused: %', v_res;
  END IF;
  INSERT INTO g3 VALUES ('T8 a signed-in user can send $7.50','PASS');
  v_passed := v_passed + 1;

  SELECT * INTO v_debit  FROM public.wallet_transactions WHERE reference_id='g3test_a' AND type='gift_sent';
  SELECT * INTO v_credit FROM public.wallet_transactions WHERE reference_id='g3test_a' AND type='gift_received';

  -- T9: one reference_id, two halves — the joinability the feature promises.
  IF v_debit.id IS NULL OR v_credit.id IS NULL
     OR v_debit.reference_id IS DISTINCT FROM v_credit.reference_id THEN
    RAISE EXCEPTION 'T9 FAIL: the two halves do not share a reference_id (% / %)',
      v_debit.reference_id, v_credit.reference_id;
  END IF;
  INSERT INTO g3 VALUES ('T9 gift_sent and gift_received share one reference_id','PASS');
  v_passed := v_passed + 1;

  -- T10: VALUE IS CONSERVED. The whole feature is worthless if this ever drifts.
  IF (SELECT sum(balance) FROM public.wallets) <> v_total0
     OR (SELECT balance FROM public.wallets WHERE user_id=v_sender)    <> v_sb0 - 7.50
     OR (SELECT balance FROM public.wallets WHERE user_id=v_recipient) <> v_rb0 + 7.50 THEN
    RAISE EXCEPTION 'T10 FAIL: value not conserved (total was %, now %)',
      v_total0, (SELECT sum(balance) FROM public.wallets);
  END IF;
  INSERT INTO g3 VALUES ('T10 exactly $7.50 moved; the sum of all balances is unchanged','PASS');
  v_passed := v_passed + 1;

  -- T11: the ledger rows agree with the balances they claim to describe.
  IF v_debit.balance_before - v_debit.amount <> v_debit.balance_after
     OR v_credit.balance_before + v_credit.amount <> v_credit.balance_after
     OR v_debit.amount <> 7.50 OR v_credit.amount <> 7.50 THEN
    RAISE EXCEPTION 'T11 FAIL: ledger arithmetic is inconsistent';
  END IF;
  INSERT INTO g3 VALUES ('T11 both ledger rows are internally consistent','PASS');
  v_passed := v_passed + 1;

  -- T12: a gift is booked as an INFLOW for the recipient, never as a refund.
  --      Routing the credit through credit_wallet_for_refund would instead have
  --      run total_spent = GREATEST(0, total_spent - 7.50) on the recipient,
  --      erasing lifetime spend they really did incur.
  IF (SELECT total_deposited FROM public.wallets WHERE user_id=v_recipient) <> v_rdep0 + 7.50 THEN
    RAISE EXCEPTION 'T12 FAIL: recipient total_deposited went % -> %, expected +7.50',
      v_rdep0, (SELECT total_deposited FROM public.wallets WHERE user_id=v_recipient);
  END IF;
  IF (SELECT total_spent FROM public.wallets WHERE user_id=v_sender) <> v_sspent0 + 7.50 THEN
    RAISE EXCEPTION 'T12 FAIL: sender total_spent went % -> %, expected +7.50',
      v_sspent0, (SELECT total_spent FROM public.wallets WHERE user_id=v_sender);
  END IF;
  IF v_credit.type <> 'gift_received' OR v_debit.type <> 'gift_sent' THEN
    RAISE EXCEPTION 'T12 FAIL: wrong ledger types (% / %)', v_debit.type, v_credit.type;
  END IF;
  INSERT INTO g3 VALUES ('T12 booked as an inflow/outflow pair, not as a refund','PASS');
  v_passed := v_passed + 1;

  -- T13: the recipient is told, on a default-ON category.
  SELECT count(*) INTO v_n FROM public.notifications
  WHERE user_id = v_recipient AND category = 'wallet_credit'
    AND title = 'You received $7.50';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'T13 FAIL: expected 1 wallet_credit notification, found %', v_n;
  END IF;
  INSERT INTO g3 VALUES ('T13 recipient gets one wallet_credit notification','PASS');
  v_passed := v_passed + 1;

  -- T14: replaying the same reference_id pays once.
  v_res := public.transfer_wallet_credit(v_remail, 7.50, 'g3test_a', 'for the trip');
  SELECT count(*) INTO v_n FROM public.wallet_transactions WHERE reference_id='g3test_a';
  IF (v_res->>'already_sent')::boolean IS NOT TRUE OR v_n <> 2 THEN
    RAISE EXCEPTION 'T14 FAIL: replay was not idempotent (already_sent=%, rows=%)',
      v_res->>'already_sent', v_n;
  END IF;
  INSERT INTO g3 VALUES ('T14 replaying the reference_id pays once, not twice','PASS');
  v_passed := v_passed + 1;

  -- T15: you cannot gift yourself into a bigger balance.
  IF (public.transfer_wallet_credit(v_semail, 5.00, 'g3test_self'))->>'code'
     IS DISTINCT FROM 'CANNOT_GIFT_SELF' THEN
    RAISE EXCEPTION 'T15 FAIL: a self-gift was not refused';
  END IF;
  INSERT INTO g3 VALUES ('T15 self-transfer refused','PASS');
  v_passed := v_passed + 1;

  -- T16: promotional credit is not transferable. Turn every deposit this user
  --      has into referral credit and the giftable amount must fall to zero —
  --      this is what stops n throwaway accounts funnelling n signup bonuses
  --      into one wallet.
  UPDATE public.wallet_transactions SET type = 'referral_credit'
  WHERE user_id = v_sender AND type IN ('deposit', 'gift_received');
  DELETE FROM public.rate_limit_buckets WHERE bucket = 'gift_credit';
  v_res := public.transfer_wallet_credit(v_remail, 5.00, 'g3test_promo');
  IF v_res->>'code' IS DISTINCT FROM 'NOT_GIFTABLE' THEN
    RAISE EXCEPTION 'T16 FAIL: promo-only balance was transferable: %', v_res;
  END IF;
  INSERT INTO g3 VALUES ('T16 a balance made only of promo credit cannot be sent','PASS');
  v_passed := v_passed + 1;

  -- T17: the limiter bounds the recipient lookup, which is the enumeration
  --      surface. Five lookups, then KS429.
  DELETE FROM public.rate_limit_buckets WHERE bucket = 'gift_credit';
  FOR v_n IN 1..5 LOOP
    PERFORM public.transfer_wallet_credit('nobody-' || v_n || '-9f3a@example.org', 5.00,
                                          'g3test_enum_' || v_n);
  END LOOP;
  IF (public.transfer_wallet_credit('nobody-6-9f3a@example.org', 5.00, 'g3test_enum_6'))->>'code'
     IS DISTINCT FROM 'KS429' THEN
    RAISE EXCEPTION 'T17 FAIL: the 6th recipient lookup in an hour was not rate limited';
  END IF;
  INSERT INTO g3 VALUES ('T17 6th recipient lookup in an hour is rate limited','PASS');
  v_passed := v_passed + 1;

  -- T18: ...and each failed lookup left a trail.
  SELECT count(*) INTO v_n FROM public.security_logs
  WHERE event_type = 'gift_recipient_not_found' AND user_id = v_sender;
  IF v_n < 5 THEN
    RAISE EXCEPTION 'T18 FAIL: expected >= 5 enumeration log rows, found %', v_n;
  END IF;
  INSERT INTO g3 VALUES ('T18 every failed recipient lookup is logged to security_logs','PASS');
  v_passed := v_passed + 1;

  RAISE NOTICE 'Part 2: % passed', v_passed;
END $$;

SELECT t AS test, outcome FROM g3;

-- Nothing above is meant to survive.
ROLLBACK;
