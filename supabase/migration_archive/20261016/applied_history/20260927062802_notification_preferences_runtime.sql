-- Use an IANA zone for local quiet hours and a fresh explicit consent for
-- weekly digests. Preserve all previously saved preferences unchanged.
ALTER TABLE public.user_preferences
  ADD COLUMN IF NOT EXISTS notification_timezone text,
  ADD COLUMN IF NOT EXISTS weekly_digest_consent_at timestamptz;

CREATE OR REPLACE FUNCTION public.defer_notification_dispatch_job(
  p_id uuid, p_until timestamptz
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
BEGIN
  IF p_until <= now() OR p_until > now() + interval '49 hours' THEN
    RAISE EXCEPTION 'Invalid quiet-hours release time' USING ERRCODE='KS400';
  END IF;
  UPDATE public.notification_dispatch_jobs
  SET state='pending', next_attempt_at=p_until,
      attempt_count=greatest(0,attempt_count-1), lease_until=NULL,
      updated_at=now(), last_error='Deferred by user quiet hours'
  WHERE id=p_id AND state='leased';
  RETURN FOUND;
END;
$$;
REVOKE ALL ON FUNCTION public.defer_notification_dispatch_job(uuid,timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.defer_notification_dispatch_job(uuid,timestamptz)
  TO service_role;

CREATE UNIQUE INDEX IF NOT EXISTS uq_weekly_digest_event_key
  ON public.notifications(source_event_key)
  WHERE event_type='weekly_digest' AND source_event_key IS NOT NULL;

CREATE OR REPLACE FUNCTION public.emit_weekly_notification_digests(
  p_now timestamptz DEFAULT now()
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_pref record;
  v_count integer;
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
    IF extract(isodow FROM v_pref.local_now) <> 1 OR
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
    IF v_count=0 THEN CONTINUE; END IF;
    v_key := 'weekly_digest:' || v_pref.user_id || ':' ||
      to_char(v_pref.local_now::date, 'YYYY-MM-DD');
    INSERT INTO public.notifications(
      user_id, category, title, body, action_url, delivered_via,
      is_read, schema_version, event_type, source_event_key,
      occurred_at, template_version, template_data, created_at
    ) VALUES (
      v_pref.user_id, 'digest', 'Your KeepSIMs weekly summary',
      'You had ' || v_count || ' routine line update(s) this week. Open KeepSIMs to review them.',
      '/notifications', ARRAY[]::text[], false, 2, 'weekly_digest',
      v_key, p_now, 1, jsonb_build_object('routine_count',v_count), p_now
    ) ON CONFLICT DO NOTHING RETURNING id INTO v_id;
    IF v_id IS NOT NULL THEN v_created := v_created + 1; END IF;
    v_id := NULL;
  END LOOP;
  RETURN jsonb_build_object('created',v_created);
END;
$$;
REVOKE ALL ON FUNCTION public.emit_weekly_notification_digests(timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.emit_weekly_notification_digests(timestamptz)
  TO service_role;

SELECT cron.schedule(
  'emit-weekly-notification-digests-hourly',
  '0 * * * *',
  $cron$SELECT public.emit_weekly_notification_digests();$cron$
);
