-- ============================================================================
-- Phase H — the admin control plane.
--
-- HOW TO RUN — as ONE execute_sql call. MCP makes each call its own
-- transaction, so a split file never pairs BEGIN with ROLLBACK.
--
-- Last run 2026-07-31: 20/20 PASSED.
--
-- WHAT THIS FILE IS FOR
-- ---------------------
-- Every `admin_*` function is SECURITY DEFINER and authenticated-callable, i.e.
-- it is on f0_grant_matrix_tests.sql's allow-list. That file asserts the ACL;
-- this one asserts the internal check behind each entry. An allow-list entry
-- without a tested internal check is exactly what F-4's apply_referral was.
--
-- The gate is `assert_admin()`. It replaces a guard shaped
--
--     IF auth.uid() IS NOT NULL AND NOT (is_power_user AND NOT suspended)
--
-- which is FALSE when auth.uid() is NULL, i.e. it fell open for an
-- unauthenticated caller. That is the fifth occurrence of this shape in the
-- project (D5c, F-4's apply_referral, protect_is_power_user, F-1's suggested
-- fix, and these two). T1 is the assertion that stops the sixth.
--
-- ONE KNOWN GAP, deliberately not worked around: a RAISEd refusal rolls back its
-- own audit row, exactly as G10 proved for device_money_events. So
-- admin_audit_log records what happened, never what was denied.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE h_results(n int, t text, outcome text) ON COMMIT DROP;
CREATE TEMP TABLE h_fixture(ticket_id uuid, exec_id uuid, carrier_id uuid) ON COMMIT DROP;
GRANT ALL ON h_results, h_fixture TO authenticated, anon;

-- Fixtures created as the owner: a user-opened ticket awaiting a reply, and a
-- queued execution flipped to MANUAL so the money path can be exercised.
WITH new_ticket AS (
  INSERT INTO public.support_tickets (user_id, subject, description, category, priority)
  SELECT id, 'H regression ticket', 'probe', 'refill_issue', 'high'
  FROM public.profiles WHERE NOT is_power_user ORDER BY created_at LIMIT 1
  RETURNING id
)
INSERT INTO h_fixture (ticket_id, exec_id, carrier_id)
SELECT
  new_ticket.id,
  (SELECT te.id FROM public.topup_executions te
    JOIN public.wallets w ON w.user_id = te.user_id
   WHERE te.status = 'pending' AND w.balance >= te.amount LIMIT 1),
  (SELECT id FROM public.carriers ORDER BY name LIMIT 1)
FROM new_ticket;

INSERT INTO public.ticket_messages (ticket_id, user_id, sender, message)
SELECT f.ticket_id, t.user_id, 'user', 'Any update?'
FROM h_fixture f JOIN public.support_tickets t ON t.id = f.ticket_id;

UPDATE public.topup_executions
SET fulfillment_gateway = 'MANUAL', api_provider = NULL
WHERE id = (SELECT exec_id FROM h_fixture);

-- ---------------------------------------------------------------------------
-- T1-T3: the gate
-- ---------------------------------------------------------------------------
DO $$ BEGIN
  SET LOCAL ROLE anon;
  BEGIN
    PERFORM public.assert_admin();
    INSERT INTO h_results VALUES (1,'assert_admin() refuses anon','FAIL - returned without raising');
  EXCEPTION WHEN OTHERS THEN
    -- 42501 is the STRONGER outcome: anon holds no EXECUTE at all, so the body
    -- is never reached. KS460 means it was reached and refused. Both are a pass;
    -- returning normally is not.
    INSERT INTO h_results VALUES (1,'assert_admin() refuses anon',
      CASE WHEN SQLSTATE IN ('KS460','42501') THEN 'PASS ('||SQLSTATE||')' ELSE 'FAIL '||SQLSTATE END);
  END;
  RESET ROLE;
END $$;

DO $$ BEGIN
  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated","app_metadata":{"is_power_user":false}}';
  BEGIN
    PERFORM public.assert_admin();
    INSERT INTO h_results VALUES (2,'assert_admin() refuses an ordinary user','FAIL - allowed');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO h_results VALUES (2,'assert_admin() refuses an ordinary user',
      CASE WHEN SQLSTATE='KS460' THEN 'PASS (KS460)' ELSE 'FAIL '||SQLSTATE END);
  END;
  RESET ROLE; SET LOCAL request.jwt.claims = '';
END $$;

-- Everything below runs as a real power user.
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"8a07a25b-a49b-4ec3-a56c-cfe7f7ea0c0e","role":"authenticated","app_metadata":{"is_power_user":true}}';

DO $$
DECLARE
  v jsonb; f RECORD; n int; q0 int; q1 int;
  v_before numeric; v_after numeric; v_uid uuid; v_amt numeric;
  v_target uuid;
BEGIN
  SELECT * INTO f FROM h_fixture;
  SELECT id INTO v_target FROM public.profiles WHERE NOT is_power_user ORDER BY created_at LIMIT 1;

  INSERT INTO h_results VALUES (3,'assert_admin() admits a power user',
    CASE WHEN public.assert_admin() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END);

  -- -------------------------------------------------------------------------
  -- T4-T5: carriers. The direct write is the regression being guarded against.
  -- -------------------------------------------------------------------------
  UPDATE public.carriers SET fulfillment_gateway='MANUAL' WHERE id=f.carrier_id;
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO h_results VALUES (4,'direct UPDATE on carriers is still a silent no-op',
    CASE WHEN n=0 THEN 'PASS rows=0 (this is why the RPC exists)' ELSE 'FAIL rows='||n END);

  BEGIN
    v := public.admin_update_carrier(f.carrier_id,'{"fulfillment_gateway":"API","api_provider":null}'::jsonb);
    INSERT INTO h_results VALUES (5,'API route with no provider refused','FAIL allowed');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO h_results VALUES (5,'API route with no provider refused',
      CASE WHEN SQLSTATE='KS466' THEN 'PASS (KS466)' ELSE 'FAIL '||SQLSTATE END);
  END;

  BEGIN
    v := public.admin_update_carrier(f.carrier_id,'{"fullfilment_gateway":"API"}'::jsonb);
    INSERT INTO h_results VALUES (6,'a misspelt field is refused, not ignored','FAIL saved nothing silently');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO h_results VALUES (6,'a misspelt field is refused, not ignored',
      CASE WHEN SQLSTATE='KS467' THEN 'PASS (KS467)' ELSE 'FAIL '||SQLSTATE END);
  END;

  BEGIN
    v := public.admin_update_carrier(f.carrier_id,'{"fulfillment_gateway":"MANUAL","gateway_phone_number":"+201001234567"}'::jsonb,'probe');
    INSERT INTO h_results VALUES (7,'admin_update_carrier writes and clears the stale provider',
      (SELECT CASE WHEN fulfillment_gateway='MANUAL' AND api_provider IS NULL
              THEN 'PASS' ELSE 'FAIL' END FROM public.carriers WHERE id=f.carrier_id));
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO h_results VALUES (7,'admin_update_carrier writes','FAIL '||SQLSTATE||' '||SQLERRM);
  END;

  BEGIN
    v := public.admin_update_carrier_rule(f.carrier_id,'{"minimum_topup_amount":2.00,"recommended_topup_amount":1.00}'::jsonb);
    INSERT INTO h_results VALUES (8,'recommended below minimum refused','FAIL allowed');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO h_results VALUES (8,'recommended below minimum refused',
      CASE WHEN SQLSTATE='KS466' THEN 'PASS (KS466)' ELSE 'FAIL '||SQLSTATE END);
  END;

  -- -------------------------------------------------------------------------
  -- T9-T12: config
  -- -------------------------------------------------------------------------
  BEGIN
    v := public.admin_set_config('APP_FEE_PERCENT','120');
    INSERT INTO h_results VALUES (9,'a fee of 120% is refused','FAIL allowed');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO h_results VALUES (9,'a fee of 120% is refused',
      CASE WHEN SQLSTATE='KS466' THEN 'PASS (KS466)' ELSE 'FAIL '||SQLSTATE END);
  END;

  BEGIN
    v := public.admin_set_config('RATE_LIMIT_INSTANT_REFILL','10 per hour');
    INSERT INTO h_results VALUES (10,'a malformed rate limit is refused','FAIL allowed');
  EXCEPTION WHEN OTHERS THEN
    -- A rate limit that fails to parse does not throw at read time; it makes
    -- consume_rate_limit fall back, i.e. it turns a limit off silently on a
    -- money path. Refusing it here is the only place it can be caught.
    INSERT INTO h_results VALUES (10,'a malformed rate limit is refused',
      CASE WHEN SQLSTATE='KS466' THEN 'PASS (KS466)' ELSE 'FAIL '||SQLSTATE END);
  END;

  BEGIN
    v := public.admin_set_config('FX_LAST_REFRESH_AT','"2020-01-01T00:00:00Z"');
    INSERT INTO h_results VALUES (11,'a system-written key is read-only','FAIL allowed');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO h_results VALUES (11,'a system-written key is read-only',
      CASE WHEN SQLSTATE='KS466' THEN 'PASS (KS466)' ELSE 'FAIL '||SQLSTATE END);
  END;

  -- Deliberately NOT compared against `SELECT count(*) FROM system_configs`.
  -- That query runs as `authenticated` and is filtered by the RESTRICTIVE
  -- "Hide device risk thresholds from clients" policy, so it returns 56, not
  -- 71 — the first version of this assertion compared the admin view against
  -- the client view and reported a pass as a failure. The property worth
  -- asserting is that the RPC returns MORE than the caller could read directly,
  -- and that the hidden rows are the DEVICE_RISK_* ones.
  SELECT count(*) INTO n FROM public.admin_list_configs();
  SELECT count(*) INTO q0 FROM public.system_configs;
  INSERT INTO h_results VALUES (12,'admin sees the DEVICE_RISK_* rows the client policy hides',
    CASE WHEN n > q0
          AND (SELECT count(*) FROM public.admin_list_configs() WHERE config_key LIKE 'DEVICE\_RISK\_%') > 0
          AND (SELECT count(*) FROM public.system_configs WHERE config_key LIKE 'DEVICE\_RISK\_%') = 0
         THEN 'PASS admin '||n||' vs client '||q0||' (the difference is the fraud thresholds)'
         ELSE 'FAIL admin '||n||' client '||q0 END);

  -- -------------------------------------------------------------------------
  -- T13-T15: the queue, and the money it moves
  -- -------------------------------------------------------------------------
  SELECT te.user_id, te.amount INTO v_uid, v_amt
  FROM public.topup_executions te WHERE te.id=f.exec_id;
  SELECT balance INTO v_before FROM public.wallets WHERE user_id=v_uid;

  v := public.admin_complete_manual_refill(f.exec_id,'probe');
  SELECT balance INTO v_after FROM public.wallets WHERE user_id=v_uid;

  -- The defect this asserts against: nothing on topup_executions moves money —
  -- the debit lives in worker_instant_refill.js, which only claims API rows —
  -- so a MANUAL completion used to deliver airtime and charge nobody.
  INSERT INTO h_results VALUES (13,'completing a MANUAL refill debits the wallet',
    CASE WHEN (v->>'debited')::boolean AND v_before - v_after = v_amt
         THEN 'PASS '||v_before||' -> '||v_after||' (amount '||v_amt||', fee-inclusive per G6)'
         ELSE 'FAIL debited='||(v->>'debited')||' '||v_before||'->'||v_after END);

  BEGIN
    v := public.admin_complete_manual_refill(f.exec_id,'again');
    INSERT INTO h_results VALUES (14,'a terminal execution cannot be completed twice','FAIL allowed');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO h_results VALUES (14,'a terminal execution cannot be completed twice',
      CASE WHEN SQLSTATE='KS462' THEN 'PASS (KS462)' ELSE 'FAIL '||SQLSTATE END);
  END;

  BEGIN
    SELECT id INTO v_target FROM public.topup_executions
    WHERE status='pending' AND fulfillment_gateway='API' LIMIT 1;
    IF v_target IS NULL THEN
      INSERT INTO h_results VALUES (15,'an API-routed row cannot be hand-completed','SKIP no API row pending');
    ELSE
      v := public.admin_complete_manual_refill(v_target,'probe');
      INSERT INTO h_results VALUES (15,'an API-routed row cannot be hand-completed','FAIL allowed');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO h_results VALUES (15,'an API-routed row cannot be hand-completed',
      CASE WHEN SQLSTATE='KS463' THEN 'PASS (KS463 - completing one races the worker)' ELSE 'FAIL '||SQLSTATE END);
  END;

  -- -------------------------------------------------------------------------
  -- T16-T17: notification channels
  -- -------------------------------------------------------------------------
  BEGIN
    v := public.admin_update_channel('whatsapp','{"is_globally_enabled":true}'::jsonb);
    INSERT INTO h_results VALUES (16,'a channel with a missing credential cannot be enabled','FAIL allowed');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO h_results VALUES (16,'a channel with a missing credential cannot be enabled',
      CASE WHEN SQLSTATE='KS466' THEN 'PASS (KS466 - sends would be accepted and dropped)' ELSE 'FAIL '||SQLSTATE END);
  END;

  -- -------------------------------------------------------------------------
  -- T18-T19: support
  -- -------------------------------------------------------------------------
  SELECT count(*) INTO q0 FROM net.http_request_queue;
  v := public.admin_reply_ticket(f.ticket_id,'Sorry about that - refunded.','resolved');
  SELECT count(*) INTO q1 FROM net.http_request_queue;

  -- C7's trigger on ticket_messages already raises the notification. The first
  -- cut of admin_reply_ticket raised a second one, so a single reply pushed
  -- twice — C1's dedupe loop repeating.
  INSERT INTO h_results VALUES (17,'one reply queues exactly ONE dispatch',
    CASE WHEN q1 = q0+1 THEN 'PASS '||q0||' -> '||q1 ELSE 'FAIL '||q0||' -> '||q1 END);

  INSERT INTO h_results VALUES (18,'the reply is stored owner-scoped so the customer can read it',
    CASE WHEN jsonb_array_length(public.admin_get_ticket(f.ticket_id)->'messages') = 2
         THEN 'PASS 2 messages, status='||(v->>'status') ELSE 'FAIL' END);

  -- -------------------------------------------------------------------------
  -- T19-T20: user ops
  -- -------------------------------------------------------------------------
  SELECT id INTO v_target FROM public.profiles WHERE NOT is_power_user ORDER BY created_at LIMIT 1;

  BEGIN
    v := public.admin_set_user_flags(v_target,'{"is_power_user":true}'::jsonb);
    INSERT INTO h_results VALUES (19,'promotion is refused here, not silently reverted','FAIL allowed');
  EXCEPTION WHEN OTHERS THEN
    -- protect_is_power_user() would revert the write AND log the ADMIN as a
    -- privilege-escalation attempt; three inside an hour suspends them.
    INSERT INTO h_results VALUES (19,'promotion is refused here, not silently reverted',
      CASE WHEN SQLSTATE='KS467' THEN 'PASS (KS467)' ELSE 'FAIL '||SQLSTATE END);
  END;

  BEGIN
    v := public.admin_adjust_wallet(v_target, 5000, 'far too much');
    INSERT INTO h_results VALUES (20,'a wallet adjustment over the cap is refused','FAIL allowed');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO h_results VALUES (20,'a wallet adjustment over the cap is refused',
      CASE WHEN SQLSTATE='KS466' THEN 'PASS (KS466)' ELSE 'FAIL '||SQLSTATE END);
  END;
END $$;

RESET ROLE;
SET LOCAL request.jwt.claims = '';

SELECT * FROM h_results ORDER BY n;

SELECT
  count(*) FILTER (WHERE outcome LIKE 'PASS%') || ' / ' || count(*) || ' PASSED'
  || CASE WHEN count(*) FILTER (WHERE outcome LIKE 'FAIL%') > 0
          THEN '  <<< ' || count(*) FILTER (WHERE outcome LIKE 'FAIL%') || ' FAILURES'
          ELSE '' END AS total
FROM h_results;

ROLLBACK;
