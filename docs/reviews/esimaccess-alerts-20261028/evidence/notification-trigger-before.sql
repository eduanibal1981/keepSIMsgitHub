CREATE OR REPLACE FUNCTION public.trg_fn_dispatch_notification()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_channels text[]; v_enabled boolean; v_category_channels text[]; v_language text;
BEGIN
  SELECT is_enabled,channels INTO v_enabled,v_category_channels FROM public.alert_settings
    WHERE user_id=NEW.user_id AND category=NEW.category;
  IF NOT coalesce(v_enabled,NEW.category<>'promo') THEN RETURN NEW; END IF;
  IF NEW.sim_line_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sim_lines WHERE id=NEW.sim_line_id AND user_id=NEW.user_id) THEN RETURN NEW; END IF;
  SELECT language INTO v_language FROM public.user_preferences WHERE user_id=NEW.user_id;
  SELECT array_agg(c.channel_key ORDER BY c.sort_order) INTO v_channels
  FROM public.notification_channel_catalog c LEFT JOIN public.notification_channels nc
    ON nc.user_id=NEW.user_id AND nc.channel_type=c.channel_key
  WHERE public.notification_channel_eligible(NEW.user_id,NEW.sim_line_id,c.channel_key,NEW.event_type)
    AND coalesce(nc.is_enabled,c.channel_key='push')
    AND (v_category_channels IS NULL OR c.channel_key=ANY(v_category_channels))
    AND (NEW.event_type IS DISTINCT FROM 'weekly_digest' OR c.channel_key<>'email' OR NEW.template_data->>'digest_paid_eligible'='true')
    AND (NEW.event_type<>'notification_test' OR NEW.template_data->>'test_channel' IS NULL OR c.channel_key=NEW.template_data->>'test_channel');
  IF coalesce(cardinality(v_channels),0)=0 THEN RETURN NEW; END IF;
  INSERT INTO public.notification_dispatch_jobs(notification_id,user_id,payload,next_attempt_at)
    VALUES(NEW.id,NEW.user_id,jsonb_build_object('notification_id',NEW.id,'user_id',NEW.user_id,
      'category',NEW.category,'title',NEW.title,'body',NEW.body,'action_url',NEW.action_url,'sim_line_id',NEW.sim_line_id,
      'channels',v_channels,'event_type',NEW.event_type,'source_event_key',NEW.source_event_key,
      'target',NEW.target,'template_data',coalesce(NEW.template_data,'{}'),'language',coalesce(v_language,'en'),
      'schema_version',NEW.schema_version,'occurred_at',NEW.occurred_at,'template_version',NEW.template_version),
      greatest(now(),coalesce(NEW.scheduled_at,now()))) ON CONFLICT(notification_id) DO NOTHING;
  RETURN NEW;
END;
$function$
