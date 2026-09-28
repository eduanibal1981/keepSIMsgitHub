-- Missing recharge date reminder cadence and stop-condition tests.
-- Run as one transaction; queued pg_net work is discarded by ROLLBACK.

BEGIN;

DO $$
DECLARE
  v_user       uuid;
  v_free       uuid := gen_random_uuid();
  v_standard   uuid := gen_random_uuid();
  v_premium    uuid := gen_random_uuid();
  v_paused     uuid := gen_random_uuid();
  v_legacy     uuid := gen_random_uuid();
  v_now        timestamptz := date_trunc('hour', now());
  v_sent       integer;
  v_count      integer;
BEGIN
  SELECT id INTO v_user FROM public.profiles ORDER BY created_at LIMIT 1;
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Test requires at least one profile';
  END IF;

  INSERT INTO public.sim_lines (
    id, user_id, phone_number, nickname, status, plan_type, protection_tier,
    plan_expires_at, last_topup_at, protection_paused, created_at
  ) VALUES
    (v_free, v_user, '+96890000001', 'Free test', 'active', 'free', 'basic',
     NULL, NULL, false, v_now - interval '30 days'),
    (v_standard, v_user, '+96890000002', 'Standard test', 'active', 'standard', 'standard',
     v_now + interval '300 days', NULL, false, v_now - interval '30 days'),
    (v_premium, v_user, '+96890000003', 'Premium test', 'active', 'premium', 'premium',
     v_now + interval '300 days', NULL, false, v_now - interval '30 days'),
    (v_paused, v_user, '+96890000004', 'Paused test', 'active', 'standard', 'standard',
     v_now + interval '300 days', NULL, true, v_now - interval '30 days'),
    (v_legacy, v_user, '+96890000005', 'Legacy test', 'active', 'standard', 'standard',
     v_now + interval '300 days', NULL, false, NULL);

  v_sent := public.emit_missing_recharge_date_reminders(v_now);
  ASSERT v_sent >= 4, 'First run must create reminders for eligible missing dates';
  ASSERT (SELECT count(*) = 3 FROM public.notifications
          WHERE sim_line_id IN (v_free, v_standard, v_premium)
            AND event_type = 'recharge_date_missing'),
    'Free, Standard, and Premium lines must each receive the first reminder';
  ASSERT NOT EXISTS (SELECT 1 FROM public.notifications
                     WHERE sim_line_id = v_paused
                       AND event_type = 'recharge_date_missing'),
    'Paused protection must not generate reminders';
  ASSERT EXISTS (SELECT 1 FROM public.notifications
                 WHERE sim_line_id = v_legacy
                   AND event_type = 'recharge_date_missing'),
    'A legacy line with no created_at timestamp must still be reminded';
  ASSERT (SELECT (template_data->>'cadence_days')::integer = 7
          FROM public.notifications
          WHERE sim_line_id = v_free AND event_type = 'recharge_date_missing'),
    'Free cadence must be seven days';
  ASSERT (SELECT bool_and((template_data->>'cadence_days')::integer = 1)
          FROM public.notifications
          WHERE sim_line_id IN (v_standard, v_premium)
            AND event_type = 'recharge_date_missing'),
    'Standard and Premium cadence must be one day';

  PERFORM public.emit_missing_recharge_date_reminders(v_now + interval '23 hours');
  ASSERT (SELECT count(*) = 3 FROM public.notifications
          WHERE sim_line_id IN (v_free, v_standard, v_premium)
            AND event_type = 'recharge_date_missing'),
    'No tier may be reminded before its cooldown expires';

  PERFORM public.emit_missing_recharge_date_reminders(v_now + interval '25 hours');
  ASSERT (SELECT count(*) = 2 FROM public.notifications
          WHERE sim_line_id IN (v_standard, v_premium)
            AND event_type = 'recharge_date_missing'
            AND created_at > v_now),
    'Standard and Premium must be reminded again after one day';
  ASSERT (SELECT count(*) = 1 FROM public.notifications
          WHERE sim_line_id = v_free AND event_type = 'recharge_date_missing'),
    'Free must not be reminded again after one day';

  PERFORM public.emit_missing_recharge_date_reminders(v_now + interval '7 days 1 hour');
  ASSERT (SELECT count(*) = 2 FROM public.notifications
          WHERE sim_line_id = v_free AND event_type = 'recharge_date_missing'),
    'Free must be reminded again after seven days';

  UPDATE public.sim_lines SET last_topup_at = v_now WHERE id = v_standard;
  SELECT count(*) INTO v_count FROM public.notifications
   WHERE sim_line_id = v_standard AND event_type = 'recharge_date_missing';
  PERFORM public.emit_missing_recharge_date_reminders(v_now + interval '9 days');
  ASSERT (SELECT count(*) = v_count FROM public.notifications
          WHERE sim_line_id = v_standard AND event_type = 'recharge_date_missing'),
    'Recording a recharge date must stop future reminders';

  ASSERT NOT has_function_privilege(
      'anon', 'public.emit_missing_recharge_date_reminders(timestamptz)', 'EXECUTE'),
    'Anonymous clients must not invoke the cross-user emitter';
  ASSERT NOT has_function_privilege(
      'authenticated', 'public.emit_missing_recharge_date_reminders(timestamptz)', 'EXECUTE'),
    'Authenticated clients must not invoke the cross-user emitter';
  ASSERT has_function_privilege(
      'service_role', 'public.emit_missing_recharge_date_reminders(timestamptz)', 'EXECUTE'),
    'The scheduled service role must invoke the emitter';
  ASSERT position(
      'emit_missing_recharge_date_reminders' IN
      pg_get_functiondef('public.process_due_notifications()'::regprocedure)
    ) > 0,
    'The hourly notification processor must call the missing-date emitter';

  RAISE NOTICE 'Missing recharge date reminder tests passed.';
END;
$$;

ROLLBACK;
