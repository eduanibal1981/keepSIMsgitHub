-- Align the digest with the customer setting: Sunday 09:00 local time,
-- including active line status even when there were no routine updates.
CREATE OR REPLACE FUNCTION public.emit_weekly_notification_digests(
  p_now timestamptz DEFAULT now()
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_pref record;
  v_count integer;
  v_lines integer;
  v_created integer := 0;
  v_key text;
  v_id uuid;
BEGIN
  FOR v_pref IN
    SELECT up.user_id, up.notification_timezone,
           p_now AT TIME ZONE up.notification_timezone AS local_now
    FROM public.user_preferences up
    JOIN pg_timezone_names tz ON tz.name=up.notification_timezone
    WHERE up.weekly_digest_enabled=true
      AND up.weekly_digest_consent_at IS NOT NULL
    ORDER BY up.user_id
    LIMIT 1000
  LOOP
    -- Monday morning locally, with a bounded three-hour catch-up window.
    IF extract(isodow FROM v_pref.local_now) <> 7 OR
       extract(hour FROM v_pref.local_now) NOT BETWEEN 9 AND 11 THEN
      CONTINUE;
    END IF;
    SELECT count(*) INTO v_count
    FROM public.notifications n
    WHERE n.user_id=v_pref.user_id
      AND n.created_at >= p_now-interval '7 days'
      AND n.created_at < p_now
      AND n.event_type IS DISTINCT FROM 'weekly_digest'
      AND n.category NOT IN ('promo','line_critical');
    SELECT count(*) INTO v_lines FROM public.sim_lines sl
    WHERE sl.user_id=v_pref.user_id AND sl.status='active';
    IF v_count=0 AND v_lines=0 THEN CONTINUE; END IF;
    v_key := 'weekly_digest:' || v_pref.user_id || ':' ||
      to_char(v_pref.local_now::date, 'YYYY-MM-DD');
    INSERT INTO public.notifications(
      user_id, category, title, body, action_url, delivered_via,
      is_read, schema_version, event_type, source_event_key,
      occurred_at, template_version, template_data, created_at
    ) VALUES (
      v_pref.user_id, 'digest', 'Your KeepSIMs weekly summary',
      'You have ' || v_lines || ' active SIM line(s) and ' || v_count || ' routine update(s) this week. Open KeepSIMs to review them.',
      '/notifications', ARRAY[]::text[], false, 2, 'weekly_digest',
      v_key, p_now, 1, jsonb_build_object('routine_count',v_count,'active_line_count',v_lines), p_now
    ) ON CONFLICT DO NOTHING RETURNING id INTO v_id;
    IF v_id IS NOT NULL THEN v_created := v_created + 1; END IF;
    v_id := NULL;
  END LOOP;
  RETURN jsonb_build_object('created',v_created);
END;
$$;

