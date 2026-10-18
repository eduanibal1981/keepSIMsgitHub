-- Remind users to record the most recent recharge date while it is missing.
-- Paid lines are reminded every 24 hours; Free lines every 7 days. The
-- existing hourly notification processor invokes this emitter, while the
-- rolling cooldown and deterministic event key make repeated runs idempotent.

CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_missing_recharge_event_key
  ON public.notifications (source_event_key)
  WHERE event_type = 'recharge_date_missing'
    AND source_event_key IS NOT NULL;

CREATE OR REPLACE FUNCTION public.emit_missing_recharge_date_reminders(
  p_now timestamptz DEFAULT now()
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_sent integer := 0;
BEGIN
  WITH candidates AS MATERIALIZED (
    SELECT
      sl.id AS sim_line_id,
      sl.user_id,
      sl.phone_number,
      sl.nickname,
      sl.created_at,
      COALESCE(ent.details->>'effective_tier', 'free') AS effective_tier,
      CASE
        WHEN COALESCE(ent.details->>'effective_tier', 'free') IN ('standard', 'premium') THEN 1
        ELSE 7
      END AS cadence_days,
      CASE
        WHEN NULLIF(left(regexp_replace(btrim(COALESCE(sl.nickname, '')), '[[:cntrl:]]', '', 'g'), 24), '') IS NOT NULL
          THEN left(regexp_replace(btrim(sl.nickname), '[[:cntrl:]]', '', 'g'), 24)
               || ' · '
               || COALESCE(NULLIF(right(regexp_replace(sl.phone_number, '\D', '', 'g'), 4), ''), 'SIM')
        ELSE 'Line ending '
             || COALESCE(NULLIF(right(regexp_replace(sl.phone_number, '\D', '', 'g'), 4), ''), 'SIM')
      END AS line_label,
      COALESCE(NULLIF(up.language, ''), 'en') AS language
    FROM public.sim_lines sl
    CROSS JOIN LATERAL (
      SELECT public.resolve_line_entitlement(sl.id) AS details
    ) ent
    LEFT JOIN public.user_preferences up ON up.user_id = sl.user_id
    WHERE sl.status = 'active'
      AND sl.last_topup_at IS NULL
      AND COALESCE(sl.protection_paused, false) = false
  ), eligible AS (
    SELECT c.*
    FROM candidates c
    WHERE (c.created_at IS NULL
           OR c.created_at <= p_now - make_interval(days => c.cadence_days))
      AND NOT EXISTS (
        SELECT 1
        FROM public.notifications n
        WHERE n.sim_line_id = c.sim_line_id
          AND n.event_type = 'recharge_date_missing'
          AND n.created_at > p_now - make_interval(days => c.cadence_days)
      )
  ), inserted AS (
    INSERT INTO public.notifications (
      user_id,
      category,
      title,
      body,
      action_url,
      sim_line_id,
      delivered_via,
      is_read,
      schema_version,
      event_type,
      source_event_key,
      occurred_at,
      template_version,
      template_data,
      target,
      created_at
    )
    SELECT
      e.user_id,
      'system',
      CASE
        WHEN e.language LIKE 'ar%' THEN '⚠️ أضف تاريخ آخر شحن'
        ELSE '⚠️ Add your last recharge date'
      END,
      CASE
        WHEN e.language LIKE 'ar%' THEN
          'أضف تاريخ آخر شحن للرقم ' || e.line_label
          || ' ليتمكن KeepSIMs من حساب موعد التذكير التالي.'
        ELSE
          'Add the most recent recharge date for ' || e.line_label
          || ' so KeepSIMs can calculate when to remind you next.'
      END,
      '/sim-lines/detail/' || e.sim_line_id,
      e.sim_line_id,
      ARRAY['push'::text],
      false,
      2,
      'recharge_date_missing',
      'missing-recharge:' || e.sim_line_id || ':' ||
        CASE
          WHEN e.cadence_days = 1
            THEN to_char(p_now AT TIME ZONE 'UTC', 'YYYY-MM-DD')
          ELSE floor(extract(epoch FROM p_now) / 604800)::bigint::text
        END,
      p_now,
      1,
      jsonb_build_object(
        'line', e.line_label,
        'phone_number', e.phone_number,
        'effective_tier', e.effective_tier,
        'cadence_days', e.cadence_days
      ),
      jsonb_build_object('route', '/sim-lines/detail/:id', 'id', e.sim_line_id),
      p_now
    FROM eligible e
    ON CONFLICT DO NOTHING
    RETURNING sim_line_id, user_id, template_data
  )
  INSERT INTO public.line_activity_log (
    sim_line_id,
    user_id,
    event_type,
    description,
    metadata,
    created_at
  )
  SELECT
    i.sim_line_id,
    i.user_id,
    'reminder_sent',
    NULL,
    jsonb_build_object(
      'source', 'missing_recharge_date',
      'effective_tier', i.template_data->>'effective_tier',
      'cadence_days', (i.template_data->>'cadence_days')::integer
    ),
    p_now
  FROM inserted i;

  GET DIAGNOSTICS v_sent = ROW_COUNT;
  RETURN v_sent;
END;
$function$;

REVOKE ALL ON FUNCTION public.emit_missing_recharge_date_reminders(timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.emit_missing_recharge_date_reminders(timestamptz)
  TO service_role;

-- Keep the established hourly job and its existing schedule. This definition
-- preserves notify-schedule and low-wallet reminders, then adds the new
-- missing-recharge-date reminder pass.
CREATE OR REPLACE FUNCTION public.process_due_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
    SELECT phone_number INTO v_phone_number
    FROM public.sim_lines
    WHERE id = r.sim_line_id;

    INSERT INTO public.notifications (
      user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read, created_at
    ) VALUES (
      r.user_id, 'line_critical', 'Notify Renewal',
      'Your Phone Number (' || COALESCE(v_phone_number, '') || ') is due for recharge. Please top up at least $' || to_char(r.amount, 'FM99999990.00') || ' to keep it active.',
      '/sim_lines/' || r.sim_line_id, r.sim_line_id, ARRAY['push'::text], false, NOW()
    );

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, metadata, created_at
    ) VALUES (
      r.sim_line_id, r.user_id, 'reminder_sent',
      NULL,
      jsonb_build_object('amount', r.amount, 'schedule_type', 'notify'),
      clock_timestamp()
    );

    v_next_due := NOW() + (
      CASE
        WHEN r.frequency_days = 0 THEN INTERVAL '1 hour'
        ELSE r.frequency_days * INTERVAL '1 day'
      END
    );

    UPDATE public.scheduled_topups
    SET last_execution_at = NOW(),
        next_execution_at = v_next_due,
        retry_count = 0,
        whatsapp_sent_this_cycle = false,
        status = 'active',
        updated_at = NOW()
    WHERE id = r.id;
  END LOOP;

  PERFORM public.emit_upcoming_refill_low_balance_reminders();
  PERFORM public.emit_missing_recharge_date_reminders();
END;
$function$;

REVOKE ALL ON FUNCTION public.process_due_notifications()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_due_notifications() TO service_role;
