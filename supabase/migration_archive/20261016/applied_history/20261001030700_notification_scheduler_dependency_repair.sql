-- The hourly scheduler requires this emitter; the older local migration had
-- never been applied to the hosted project. Missing-date reminders use the
-- originating line's current entitlement, rolling cadence and stable keys.
CREATE OR REPLACE FUNCTION public.emit_missing_recharge_date_reminders(p_now timestamptz DEFAULT now())
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_count integer;
BEGIN
  WITH candidates AS (
    SELECT l.id,l.user_id,l.phone_number,l.created_at,
      CASE WHEN public.notification_channel_eligible(l.user_id,l.id,'email',NULL) THEN 1 ELSE 7 END days,
      coalesce(up.language,'en') language
    FROM public.sim_lines l LEFT JOIN public.user_preferences up ON up.user_id=l.user_id
    WHERE l.status='active' AND l.last_topup_at IS NULL AND NOT l.protection_paused
  ), inserted AS (
    INSERT INTO public.notifications(user_id,sim_line_id,category,title,body,event_type,schema_version,
      source_event_key,action_url,occurred_at,created_at,expires_at,template_data)
    SELECT user_id,id,'system',CASE WHEN language LIKE 'ar%' THEN 'أضف تاريخ آخر شحن' ELSE 'Add your last recharge date' END,
      CASE WHEN language LIKE 'ar%' THEN 'أضف تاريخ آخر شحن للخط المنتهي بـ ' ELSE 'Add the last recharge date for SIM line ending ' END
        ||right(regexp_replace(phone_number,'[^0-9]','','g'),4),
      'recharge_date_missing',2,'missing-recharge:'||id||':'||floor(extract(epoch FROM p_now)/(days*86400)),
      '/sim-lines/detail/'||id,p_now,p_now,p_now+interval '24 hours',jsonb_build_object('cadence_days',days)
    FROM candidates c WHERE created_at<=p_now-make_interval(days=>c.days)
      AND NOT EXISTS(SELECT 1 FROM public.notifications n WHERE n.sim_line_id=c.id AND n.event_type='recharge_date_missing'
        AND n.created_at>p_now-make_interval(days=>c.days))
    ON CONFLICT DO NOTHING RETURNING id
  ) SELECT count(*) INTO v_count FROM inserted;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.emit_missing_recharge_date_reminders(timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.emit_missing_recharge_date_reminders(timestamptz) TO service_role;
