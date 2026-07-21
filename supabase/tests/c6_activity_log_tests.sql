-- Test Suite: C6 Activity Log Server-Authored Triggers & Retention Cap
BEGIN;

DO $$
DECLARE
  v_user_id UUID := 'e5a56433-6f75-41a3-96b9-19c62b9d1280';
  v_sim_id UUID := '00000000-0000-0000-0000-0000000000c6';
  v_exec_id UUID;
  v_log_count INT;
  v_event_type TEXT;
BEGIN
  -- Cleanup test data if present
  DELETE FROM public.line_activity_log WHERE sim_line_id = v_sim_id;
  DELETE FROM public.topup_executions WHERE sim_line_id = v_sim_id;
  DELETE FROM public.sim_lines WHERE id = v_sim_id;

  -- Insert mock SIM line on standard plan
  INSERT INTO public.sim_lines (id, user_id, phone_number, status, plan_type)
  VALUES (v_sim_id, v_user_id, '+155500000c6', 'active', 'standard');

  -- Test 1: Insert topup_executions row -> should trigger 'topup_requested'
  INSERT INTO public.topup_executions (
    sim_line_id, user_id, amount, status, execution_type, api_provider
  ) VALUES (
    v_sim_id, v_user_id, 5.00, 'pending', 'refill_instant', 'dtone'
  ) RETURNING id INTO v_exec_id;

  SELECT event_type INTO v_event_type
  FROM public.line_activity_log
  WHERE sim_line_id = v_sim_id
  ORDER BY created_at DESC, id DESC LIMIT 1;

  ASSERT v_event_type = 'topup_requested', 'Expected event_type topup_requested on insert, got: ' || COALESCE(v_event_type, 'null');

  -- Test 2: Update status to 'success' -> should trigger 'topup_success'
  UPDATE public.topup_executions
  SET status = 'success', reloadly_transaction_id = 'dt_tx_test_c6'
  WHERE id = v_exec_id;

  SELECT event_type INTO v_event_type
  FROM public.line_activity_log
  WHERE sim_line_id = v_sim_id
  ORDER BY created_at DESC, id DESC LIMIT 1;

  ASSERT v_event_type = 'topup_success', 'Expected event_type topup_success on update, got: ' || COALESCE(v_event_type, 'null');

  -- Test 3: Update status to 'failed' -> should trigger 'topup_failed'
  UPDATE public.topup_executions
  SET status = 'failed', failure_reason = 'Offer price mismatch'
  WHERE id = v_exec_id;

  SELECT event_type INTO v_event_type
  FROM public.line_activity_log
  WHERE sim_line_id = v_sim_id
  ORDER BY created_at DESC, id DESC LIMIT 1;

  ASSERT v_event_type = 'topup_failed', 'Expected event_type topup_failed on update, got: ' || COALESCE(v_event_type, 'null');

  -- Test 4: Retry execution -> should trigger 'topup_retry_queued'
  INSERT INTO public.topup_executions (
    sim_line_id, user_id, amount, status, execution_type, retry_of
  ) VALUES (
    v_sim_id, v_user_id, 5.00, 'pending', 'refill_scheduled', v_exec_id
  );

  SELECT event_type INTO v_event_type
  FROM public.line_activity_log
  WHERE sim_line_id = v_sim_id
  ORDER BY created_at DESC, id DESC LIMIT 1;

  ASSERT v_event_type = 'topup_retry_queued', 'Expected event_type topup_retry_queued, got: ' || COALESCE(v_event_type, 'null');

  -- Test 5: Verify retention cap (max 50 rows)
  FOR i IN 1..60 LOOP
    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, metadata
    ) VALUES (
      v_sim_id, v_user_id, 'health_update', jsonb_build_object('idx', i)
    );
  END LOOP;

  SELECT COUNT(*) INTO v_log_count
  FROM public.line_activity_log
  WHERE sim_line_id = v_sim_id;

  ASSERT v_log_count = 50, 'Expected retention cap to prune rows to 50, got: ' || v_log_count;

  RAISE NOTICE 'ALL C6 ACTIVITY LOG TESTS PASSED SUCCESSFULLY';
END $$;

ROLLBACK;
