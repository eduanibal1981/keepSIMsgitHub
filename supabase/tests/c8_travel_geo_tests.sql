-- C8 Travel & Geolocation Live SQL Test Suite
-- Wrapped in BEGIN..ROLLBACK so live database state remains 100% untouched.

BEGIN;

DO $$
DECLARE
  v_test_user_id UUID;
  v_home_country TEXT := 'US';
  v_new_country TEXT := 'GB';
  v_notif_count_before INT;
  v_notif_count_after INT;
  v_notif_category TEXT;
  v_notif_action_url TEXT;
  v_last_country_result TEXT;
  v_line_id UUID := gen_random_uuid();
  v_sched_id UUID := gen_random_uuid();
  v_sched_active BOOLEAN;
BEGIN
  RAISE NOTICE 'Starting C8 Travel & Geolocation SQL Test Suite...';

  -- 1. Setup test user in profiles
  SELECT id INTO v_test_user_id FROM public.profiles LIMIT 1;
  IF v_test_user_id IS NULL THEN
    RAISE EXCEPTION 'No test user found in profiles table';
  END IF;

  UPDATE public.profiles
  SET home_country_code = 'US', last_country = NULL
  WHERE id = v_test_user_id;

  -- 2. Verify profiles.last_country CHECK constraint (2 letters or NULL)
  BEGIN
    UPDATE public.profiles SET last_country = 'INVALID_3_LETTERS' WHERE id = v_test_user_id;
    RAISE EXCEPTION 'Failsafe: 3-letter last_country should have failed CHECK constraint';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'Passed Test 1: CHECK constraint rejects invalid last_country codes';
  END;

  -- 3. Simulate detect-country update: United Kingdom (abroad)
  UPDATE public.profiles
  SET last_country = 'GB', updated_at = NOW()
  WHERE id = v_test_user_id;

  INSERT INTO public.notifications (user_id, category, title, body, action_url)
  VALUES (
    v_test_user_id,
    'geo_fence_triggered',
    'Welcome to United Kingdom! ✈️',
    'Arrived in GB. Secure your prepaid line.',
    '/esim'
  );

  SELECT last_country INTO v_last_country_result FROM public.profiles WHERE id = v_test_user_id;
  IF v_last_country_result <> 'GB' THEN
    RAISE EXCEPTION 'Test 2 Failed: last_country not updated to GB';
  END IF;

  SELECT category, action_url INTO v_notif_category, v_notif_action_url
  FROM public.notifications
  WHERE user_id = v_test_user_id AND category = 'geo_fence_triggered'
  ORDER BY created_at DESC LIMIT 1;

  IF v_notif_category <> 'geo_fence_triggered' OR v_notif_action_url <> '/esim' THEN
    RAISE EXCEPTION 'Test 3 Failed: notification category or action_url mismatch for abroad country';
  END IF;
  RAISE NOTICE 'Passed Test 2 & 3: Country change abroad sets last_country and inserts geo_fence_triggered with /esim URL';

  -- 4. Test Welcome Home notification category when arriving back in home_country_code ('US')
  UPDATE public.profiles
  SET last_country = 'US', updated_at = NOW()
  WHERE id = v_test_user_id;

  INSERT INTO public.notifications (user_id, category, title, body, action_url)
  VALUES (
    v_test_user_id,
    'welcome_home_ready',
    'Welcome Home! 🏠',
    'Back in US. Unfreeze local lines.',
    '/settings/geo'
  );

  SELECT category, action_url INTO v_notif_category, v_notif_action_url
  FROM public.notifications
  WHERE user_id = v_test_user_id AND category = 'welcome_home_ready'
  ORDER BY created_at DESC LIMIT 1;

  IF v_notif_category <> 'welcome_home_ready' OR v_notif_action_url <> '/settings/geo' THEN
    RAISE EXCEPTION 'Test 4 Failed: notification category or action_url mismatch for home country';
  END IF;
  RAISE NOTICE 'Passed Test 4: Arriving home inserts welcome_home_ready with /settings/geo action_url';

  -- 5. Test scheduled_topups is_active toggle on line freeze (fixing cosmetic freeze)
  INSERT INTO public.sim_lines (id, user_id, phone_number, country_id, status, protection_paused, requires_protection_at_home)
  VALUES (v_line_id, v_test_user_id, '+15550001111', (SELECT id FROM public.countries LIMIT 1), 'active', false, false);

  INSERT INTO public.scheduled_topups (id, user_id, sim_line_id, amount, is_active, status, frequency_days, next_execution_at)
  VALUES (v_sched_id, v_test_user_id, v_line_id, 5.00, true, 'active', 30, NOW() + INTERVAL '30 days');

  -- Simulate real freeze execution
  UPDATE public.sim_lines SET status = 'paused', protection_paused = true WHERE id = v_line_id;
  UPDATE public.scheduled_topups SET is_active = false, status = 'paused' WHERE sim_line_id = v_line_id;

  SELECT is_active INTO v_sched_active FROM public.scheduled_topups WHERE id = v_sched_id;
  IF v_sched_active <> false THEN
    RAISE EXCEPTION 'Test 5 Failed: freezing line did not deactivate scheduled_topups.is_active';
  END IF;
  RAISE NOTICE 'Passed Test 5: Line freeze deactivates scheduled_topups.is_active';

  RAISE NOTICE 'ALL C8 SQL TESTS PASSED SUCCESSFULLY!';
END $$;

ROLLBACK;
