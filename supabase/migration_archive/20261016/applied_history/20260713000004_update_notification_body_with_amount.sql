-- Migration: Update process_due_notifications to include top-up amount in notification body

CREATE OR REPLACE FUNCTION public.process_due_notifications()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  r RECORD;
  v_phone_number TEXT;
  v_next_due TIMESTAMPTZ;
BEGIN
  FOR r IN 
    SELECT s.id, s.sim_line_id, s.user_id, s.amount, s.currency, s.frequency_days
    FROM public.scheduled_topups s
    WHERE s.is_active = true 
      AND s.status = 'active'
      AND s.schedule_type = 'notify'
      AND s.next_execution_at <= NOW()
  LOOP
    -- Fetch phone number for notification text
    SELECT phone_number INTO v_phone_number
    FROM public.sim_lines
    WHERE id = r.sim_line_id;

    -- Insert notification record
    INSERT INTO public.notifications (
      user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read, created_at
    ) VALUES (
      r.user_id, 'line_critical', 'Notify Renewal', 
      'Your Phone Number (' || COALESCE(v_phone_number, '') || ') is due for recharge. Please top up at least $' || to_char(r.amount, 'FM99999990.00') || ' to keep it active.',
      '/sim_lines/' || r.sim_line_id, r.sim_line_id, ARRAY['push'::text], false, NOW()
    );

    -- Log activity
    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, metadata, created_at
    ) VALUES (
      r.sim_line_id, r.user_id, 'topup_success', 
      CASE WHEN r.frequency_days = 0 THEN 'Auto-Notify reminder. Next notification due in 1 hour.' 
      ELSE 'Auto-Notify reminder. Next notification due in ' || r.frequency_days || ' days.' END,
      jsonb_build_object('amount', r.amount, 'schedule_type', 'notify'),
      NOW()
    );

    -- Calculate next execution date
    v_next_due := NOW() + (CASE WHEN r.frequency_days = 0 THEN INTERVAL '1 hour' ELSE r.frequency_days * INTERVAL '1 day' END);

    -- Update schedule dates
    UPDATE public.scheduled_topups
    SET last_execution_at = NOW(),
        next_execution_at = v_next_due,
        retry_count = 0,
        whatsapp_sent_this_cycle = false,
        status = 'active',
        updated_at = NOW()
    WHERE id = r.id;
  END LOOP;
END;
$$;
