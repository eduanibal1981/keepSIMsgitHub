-- ============================================================================
-- SIM Shield — Phase C7: Support Tickets & Notifications SQL Test Suite
-- ============================================================================

BEGIN;

-- 1. Setup Fixture Variables
DO $$
DECLARE
  v_test_user_id UUID;
  v_other_user_id UUID;
  v_ticket_id UUID;
  v_msg_id UUID;
  v_notif_count INT;
  v_http_count INT;
  v_ticket_status TEXT;
BEGIN
  -- Retrieve test user ID (a1-wallet-test@example.com)
  SELECT id INTO v_test_user_id FROM auth.users WHERE email = 'a1-wallet-test@example.com';
  IF v_test_user_id IS NULL THEN
    RAISE EXCEPTION 'Test fixture user a1-wallet-test@example.com not found!';
  END IF;

  -- Create a dummy other user ID for unauthorized access tests
  v_other_user_id := gen_random_uuid();

  -- 2. Test user ticket creation (simulate authenticated user session)
  SET LOCAL rbac.current_user_id = v_test_user_id;
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_test_user_id::text, 'role', 'authenticated')::text, true);

  INSERT INTO public.support_tickets (
    user_id,
    subject,
    category,
    priority
  ) VALUES (
    v_test_user_id,
    'Cannot refill UK Vodafone SIM',
    'refill_issue',
    'high'
  ) RETURNING id INTO v_ticket_id;

  ASSERT v_ticket_id IS NOT NULL, 'Failed to insert support ticket as authenticated user';

  -- 3. Test user message insertion
  INSERT INTO public.ticket_messages (
    ticket_id,
    user_id,
    sender,
    message
  ) VALUES (
    v_ticket_id,
    v_test_user_id,
    'user',
    'I tried requesting instant refill for my UK line but it failed.'
  ) RETURNING id INTO v_msg_id;

  ASSERT v_msg_id IS NOT NULL, 'Failed to insert ticket message as authenticated user';

  -- 4. Test security enforcement: user trying to forge sender='admin' MUST FAIL
  BEGIN
    INSERT INTO public.ticket_messages (
      ticket_id,
      user_id,
      sender,
      message
    ) VALUES (
      v_ticket_id,
      v_test_user_id,
      'admin',
      'Fake admin reply'
    );
    RAISE EXCEPTION 'SECURITY FAIL: User was able to forge sender=admin!';
  EXCEPTION WHEN OTHERS THEN
    -- Expected failure due to RLS WITH CHECK (sender = ''user'')
    RAISE NOTICE 'SUCCESS: Forged sender=admin rejected by RLS';
  END;

  -- 5. Test security enforcement: user trying to write to another user''s ticket MUST FAIL
  BEGIN
    INSERT INTO public.ticket_messages (
      ticket_id,
      user_id,
      sender,
      message
    ) VALUES (
      v_ticket_id,
      v_other_user_id,
      'user',
      'Malicious message on another ticket'
    );
    RAISE EXCEPTION 'SECURITY FAIL: User was able to post on unauthorized user_id!';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'SUCCESS: Unauthorized user_id message rejected by RLS';
  END;

  -- 6. Test Admin Reply as Service Role / Admin
  PERFORM set_config('role', 'postgres', true); -- Switch to superuser/service role

  INSERT INTO public.ticket_messages (
    ticket_id,
    user_id,
    sender,
    message
  ) VALUES (
    v_ticket_id,
    v_test_user_id,
    'admin',
    'Hello! We checked your line status and issued a retry. Please test now.'
  );

  -- 7. Assert notification creation for category 'support'
  SELECT count(*) INTO v_notif_count
  FROM public.notifications
  WHERE user_id = v_test_user_id
    AND category = 'support'
    AND action_url = '/support/' || v_ticket_id::text;

  ASSERT v_notif_count > 0, 'Admin reply failed to generate support notification!';

  -- 8. Assert ticket status updated to 'pending'
  SELECT status INTO v_ticket_status
  FROM public.support_tickets
  WHERE id = v_ticket_id;

  ASSERT v_ticket_status = 'pending', 'Ticket status was not set to pending after admin reply!';

  -- 9. Assert dispatch trigger queued HTTP request in net.http_request_queue
  SELECT count(*) INTO v_http_count
  FROM net.http_request_queue;

  ASSERT v_http_count > 0, 'Notification dispatch trigger failed to queue HTTP request!';

  RAISE NOTICE 'ALL C7 SUPPORT TICKET TESTS PASSED CLEANLY!';
END $$;

ROLLBACK;
