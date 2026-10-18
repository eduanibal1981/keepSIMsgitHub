BEGIN;

CREATE OR REPLACE FUNCTION public.emit_upcoming_refill_low_balance_reminders()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  r record;
  v_count integer := 0;
  v_available numeric;
  v_id uuid;
  v_key text;
BEGIN
  IF NOT coalesce((current_setting('role',true) = 'service_role' AND auth.role() = 'service_role')
     OR (current_setting('role',true) IN ('none','postgres') AND session_user = 'postgres'),false) THEN
    RAISE EXCEPTION 'Trusted notification scheduler required' USING ERRCODE = '42501';
  END IF;
  -- Direct sweeps and the hourly scheduler share the rolling 24-hour limit.
  -- The existing source-event index is deliberately non-unique.
  PERFORM pg_advisory_xact_lock(hashtextextended('keepsims:upcoming-refill-low-balance',0));
  FOR r IN
    SELECT te.id,te.sim_line_id,te.user_id,te.amount,te.execution_time,coalesce(te.currency,'USD') AS currency,
      sl.phone_number
    FROM public.topup_executions te
    JOIN public.sim_lines sl ON sl.id = te.sim_line_id AND sl.user_id = te.user_id
    WHERE te.status = 'pending' AND te.execution_type IN ('refill_mini','refill_custom')
      AND te.execution_time > now() AND te.execution_time <= now() + interval '7 days'
      AND sl.status = 'active' AND NOT coalesce(sl.protection_paused,false)
    ORDER BY te.execution_time,te.id
  LOOP
    SELECT w.balance - coalesce((SELECT sum(h.amount) FROM public.wallet_holds h
      WHERE h.user_id = r.user_id AND h.status = 'active'),0)
    INTO v_available FROM public.wallets w WHERE w.user_id = r.user_id;

    IF v_available IS NOT NULL AND v_available < r.amount AND NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.user_id = r.user_id AND n.sim_line_id = r.sim_line_id
        AND n.category = 'wallet_low' AND n.created_at >= now() - interval '24 hours'
        AND (n.source_event_key LIKE 'upcoming-refill-low-balance:%'
          OR n.title = 'Low Wallet Balance for Upcoming Auto-Refill')
    ) THEN
      v_key := 'upcoming-refill-low-balance:' || r.sim_line_id || ':' || floor(extract(epoch FROM now()) / 86400);
      INSERT INTO public.notifications(user_id,sim_line_id,category,title,body,action_url,
        delivered_via,event_type,schema_version,source_event_key,occurred_at,expires_at,
        template_version,template_data,target)
      VALUES(r.user_id,r.sim_line_id,'wallet_low','Low Wallet Balance for Upcoming Auto-Refill',
        'Your scheduled recharge of ' || to_char(r.amount,'FM999990.00') || ' ' || r.currency ||
        ' for SIM line ending ' || right(regexp_replace(r.phone_number,'[^0-9]','','g'),4) ||
        ' is due on ' || to_char(r.execution_time AT TIME ZONE 'UTC','Mon DD') ||
        '. Please top up your wallet to ensure continuous protection.',
        '/wallet',ARRAY[]::text[],'wallet_low',2,v_key,now(),
        least(r.execution_time,now() + interval '24 hours'),1,
        jsonb_build_object('execution_id',r.id,'execution_time',r.execution_time,
          'refill_amount',r.amount,'available_balance',greatest(v_available,0),'currency',r.currency),
        jsonb_build_object('route','/wallet'))
      RETURNING id INTO v_id;
      -- Insertion queues the event; only the dispatcher can report delivery.
      INSERT INTO public.line_activity_log(sim_line_id,user_id,event_type,description,metadata)
      VALUES(r.sim_line_id,r.user_id,'reminder_sent','Low wallet balance reminder queued for upcoming auto-refill',
        jsonb_build_object('notification_id',v_id,'source_event_key',v_key,'state','queued',
          'execution_id',r.id,'execution_time',r.execution_time));
      v_count := v_count + 1;
    END IF;
  END LOOP;
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.process_due_notifications()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r record; v_period interval; v_next timestamptz; v_key text; v_stage text; v_state text;
BEGIN
  IF NOT coalesce((current_setting('role',true) = 'service_role' AND auth.role() = 'service_role')
     OR (current_setting('role',true) IN ('none','postgres') AND session_user = 'postgres'),false) THEN
    RAISE EXCEPTION 'Trusted notification scheduler required' USING ERRCODE = '42501';
  END IF;
  FOREACH v_stage IN ARRAY ARRAY['due_schedules','upcoming_refill','missing_recharge_date','urgent_deactivation'] LOOP
    BEGIN
      IF v_stage = 'due_schedules' THEN
        FOR r IN SELECT s.*,l.phone_number FROM public.scheduled_topups s
          JOIN public.sim_lines l ON l.id=s.sim_line_id AND l.user_id=s.user_id
          WHERE s.is_active AND s.status='active' AND s.schedule_type='notify' AND s.next_execution_at<=now()
          ORDER BY s.next_execution_at LIMIT 1000 FOR UPDATE OF s SKIP LOCKED
        LOOP
          v_key := 'notify_due:' || r.id || ':' || r.next_execution_at;
          v_period := CASE WHEN coalesce(r.frequency_days,0)<=0 THEN interval '1 hour' ELSE r.frequency_days*interval '1 day' END;
          v_next := r.next_execution_at+v_period*(floor(extract(epoch FROM (now()-r.next_execution_at))/extract(epoch FROM v_period))+1);
          INSERT INTO public.notifications(user_id,sim_line_id,category,title,body,event_type,schema_version,source_event_key,
            action_url,occurred_at,expires_at,template_data)
          VALUES(r.user_id,r.sim_line_id,'line_critical','Recharge reminder',
            'SIM line ending '||right(regexp_replace(r.phone_number,'[^0-9]','','g'),4)||' is due for recharge. Open KeepSIMs to review your line.',
            'recharge_due_today',2,v_key,'/sim-lines/detail/'||r.sim_line_id,r.next_execution_at,now()+interval '24 hours',
            jsonb_build_object('scheduled_topup_id',r.id,'amount',r.amount,'currency',r.currency)) ON CONFLICT DO NOTHING;
          INSERT INTO public.line_activity_log(sim_line_id,user_id,event_type,metadata)
            VALUES(r.sim_line_id,r.user_id,'reminder_sent',jsonb_build_object('source_event_key',v_key,'schedule_type','notify','state','queued'));
          UPDATE public.scheduled_topups SET last_execution_at=now(),next_execution_at=v_next,retry_count=0,
            whatsapp_sent_this_cycle=false,updated_at=now() WHERE id=r.id;
        END LOOP;
      ELSIF v_stage = 'upcoming_refill' THEN
        PERFORM public.emit_upcoming_refill_low_balance_reminders();
      ELSIF v_stage = 'missing_recharge_date' THEN
        PERFORM public.emit_missing_recharge_date_reminders();
      ELSE
        PERFORM public.emit_urgent_deactivation_alerts(false);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_state := SQLSTATE;
      -- Each stage is a subtransaction: its partial output rolls back while
      -- successful stages commit. Never log SQLERRM or customer payloads.
      RAISE WARNING 'Notification scheduler stage % failed (SQLSTATE %)',v_stage,v_state;
      BEGIN
        INSERT INTO public.system_alerts(kind,message,details)
        VALUES('notification_scheduler_failed','A notification scheduler stage failed; retry on next sweep',
          jsonb_build_object('job_name','process-hourly-notifications','stage',v_stage,'sqlstate',v_state));
      EXCEPTION WHEN OTHERS THEN
        -- An outbox failure can also break the system-alert trigger. The
        -- sanitized warning remains observable in PostgreSQL logs.
        RAISE WARNING 'Notification scheduler diagnostic for stage % could not be persisted (SQLSTATE %)',v_stage,SQLSTATE;
      END;
    END;
  END LOOP;
END;
$$;

-- Scheduler diagnostics use this existing trigger too. They must not claim a
-- push delivery from insertion, and require event metadata for channel routing.
CREATE OR REPLACE FUNCTION public.trg_fn_notify_system_alert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.notifications(user_id,category,title,body,action_url,delivered_via,
    schema_version,event_type,source_event_key,template_version,template_data,target)
  SELECT p.id,'system','System alert: ' || NEW.kind,NEW.message,'/notifications',ARRAY[]::text[],
    2,'system_alert','system-alert:' || NEW.id,1,jsonb_build_object('kind',NEW.kind),
    jsonb_build_object('route','/notifications')
  FROM public.profiles p WHERE p.is_power_user = true;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.emit_upcoming_refill_low_balance_reminders() FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.process_due_notifications() FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.trg_fn_notify_system_alert() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.emit_upcoming_refill_low_balance_reminders() TO postgres,service_role;
GRANT EXECUTE ON FUNCTION public.process_due_notifications() TO postgres,service_role;

COMMIT;
