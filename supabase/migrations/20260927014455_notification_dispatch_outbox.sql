-- Durable logical-event handoff. A leased job with an ambiguous outcome is
-- quarantined as unknown and cannot be replayed automatically.
CREATE TABLE IF NOT EXISTS public.notification_dispatch_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL UNIQUE REFERENCES public.notifications(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  payload jsonb NOT NULL,
  state text NOT NULL DEFAULT 'pending'
    CHECK (state IN ('pending','leased','complete','unknown','failed','canceled')),
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  lease_until timestamptz,
  last_error text,
  response_summary jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_notification_dispatch_jobs_due
  ON public.notification_dispatch_jobs(next_attempt_at, created_at)
  WHERE state = 'pending';
CREATE INDEX IF NOT EXISTS idx_notification_dispatch_jobs_state
  ON public.notification_dispatch_jobs(state, created_at);
ALTER TABLE public.notification_dispatch_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.notification_dispatch_jobs FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.notification_dispatch_jobs TO service_role;

CREATE OR REPLACE FUNCTION public.claim_notification_dispatch_jobs(p_limit integer DEFAULT 20)
RETURNS TABLE (id uuid, notification_id uuid, payload jsonb, attempt_count integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
BEGIN
  -- A dead process may have sent the message; do not retry its expired lease.
  UPDATE public.notification_dispatch_jobs
  SET state = 'unknown', lease_until = NULL,
      last_error = 'Dispatch lease expired; provider outcome requires reconciliation',
      updated_at = now()
  WHERE state = 'leased' AND lease_until < now();

  RETURN QUERY
  WITH due AS (
    SELECT j.id FROM public.notification_dispatch_jobs j
    WHERE j.state = 'pending' AND j.next_attempt_at <= now()
    ORDER BY j.next_attempt_at, j.created_at
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50)
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.notification_dispatch_jobs j
  SET state = 'leased', attempt_count = j.attempt_count + 1,
      lease_until = now() + interval '3 minutes', updated_at = now()
  FROM due WHERE j.id = due.id
  RETURNING j.id, j.notification_id, j.payload, j.attempt_count;
END;
$$;
REVOKE ALL ON FUNCTION public.claim_notification_dispatch_jobs(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_notification_dispatch_jobs(integer) TO service_role;

CREATE OR REPLACE FUNCTION public.finish_notification_dispatch_job(
  p_id uuid, p_state text, p_error text DEFAULT NULL,
  p_response jsonb DEFAULT NULL, p_retryable boolean DEFAULT false
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
BEGIN
  IF p_state NOT IN ('complete','unknown','failed','canceled') THEN
    RAISE EXCEPTION 'Invalid dispatch outcome' USING ERRCODE = 'KS400';
  END IF;
  UPDATE public.notification_dispatch_jobs
  SET state = CASE
        WHEN p_retryable AND attempt_count < 3 AND p_state = 'failed'
          THEN 'pending' ELSE p_state END,
      next_attempt_at = CASE
        WHEN p_retryable AND attempt_count < 3 AND p_state = 'failed'
          THEN now() + make_interval(mins => (2 ^ attempt_count)::integer)
        ELSE next_attempt_at END,
      lease_until = NULL, last_error = left(p_error, 1000),
      response_summary = p_response, updated_at = now(),
      completed_at = CASE WHEN p_state = 'complete' THEN now() ELSE NULL END
  WHERE id = p_id AND state = 'leased';
  RETURN FOUND;
END;
$$;
REVOKE ALL ON FUNCTION public.finish_notification_dispatch_job(uuid,text,text,jsonb,boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finish_notification_dispatch_job(uuid,text,text,jsonb,boolean)
  TO service_role;

CREATE OR REPLACE FUNCTION public.admin_notification_dispatch_health()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN (
    SELECT jsonb_build_object(
      'pending', count(*) FILTER (WHERE state='pending'),
      'leased', count(*) FILTER (WHERE state='leased'),
      'complete', count(*) FILTER (WHERE state='complete'),
      'unknown', count(*) FILTER (WHERE state='unknown'),
      'failed', count(*) FILTER (WHERE state='failed'),
      'canceled', count(*) FILTER (WHERE state='canceled'),
      'oldest_pending_at', min(created_at) FILTER (WHERE state='pending'),
      'last_completed_at', max(completed_at)
    ) FROM public.notification_dispatch_jobs
  );
END;
$$;
REVOKE ALL ON FUNCTION public.admin_notification_dispatch_health()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_notification_dispatch_health()
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_retry_notification_dispatch_job(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE v_notification_id uuid;
BEGIN
  PERFORM public.assert_admin();
  SELECT notification_id INTO v_notification_id
  FROM public.notification_dispatch_jobs
  WHERE id=p_id AND state='failed'
  FOR UPDATE;
  IF v_notification_id IS NULL THEN
    RAISE EXCEPTION 'Only definitively failed jobs can be replayed'
      USING ERRCODE='KS409';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.notification_deliveries
    WHERE notification_id=v_notification_id
      AND status IN ('accepted_by_provider','delivered','unknown','attempting','retrying')
  ) THEN
    RAISE EXCEPTION 'This job may already have reached a provider'
      USING ERRCODE='KS409';
  END IF;
  UPDATE public.notification_dispatch_jobs
  SET state='pending', attempt_count=0, next_attempt_at=now(),
      last_error=NULL, updated_at=now()
  WHERE id=p_id;
  RETURN jsonb_build_object('success',true,'job_id',p_id);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_retry_notification_dispatch_job(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_retry_notification_dispatch_job(uuid)
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.trg_fn_dispatch_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_all_channels       text[];
  v_global_on          text[];
  v_channels           text[];
  v_category_chans     text[];
  v_is_enabled         boolean;
  v_payload            jsonb;
  v_push_global_on     boolean;
  v_push_user_enabled  boolean;
  v_language           text;
  v_tier               text;
  v_plan_type          text;
  v_line_validity      timestamptz;
  v_effective_tier     text := 'basic';
  v_is_line_expired    boolean := false;
BEGIN
  SELECT ARRAY(SELECT channel_key FROM public.notification_channel_catalog ORDER BY sort_order),
         ARRAY(SELECT channel_key FROM public.notification_channel_catalog
                WHERE is_globally_enabled ORDER BY sort_order)
    INTO v_all_channels, v_global_on;

  IF COALESCE(array_length(v_all_channels, 1), 0) = 0 THEN
    v_all_channels := ARRAY['push','email','telegram','whatsapp'];
    v_global_on    := v_all_channels;
  END IF;

  v_push_global_on := 'push' = ANY (v_global_on);

  -- Strict line-level entitlement and expiry check
  IF NEW.sim_line_id IS NOT NULL THEN
    SELECT protection_tier, plan_type, validity_expires_at
    INTO v_tier, v_plan_type, v_line_validity
    FROM public.sim_lines WHERE id = NEW.sim_line_id;

    v_effective_tier := lower(COALESCE(v_tier, v_plan_type, 'basic'));
    v_is_line_expired := (v_line_validity IS NOT NULL AND v_line_validity < now());
  ELSE
    -- If no sim_line_id is associated (account-level), check user profile tier
    SELECT lower(subscription_tier) INTO v_tier FROM public.profiles WHERE id = NEW.user_id;
    v_effective_tier := COALESCE(v_tier, 'basic');
    v_is_line_expired := false;
  END IF;

  -- Fetch user preferred language
  SELECT language INTO v_language FROM public.user_preferences WHERE user_id = NEW.user_id;
  v_language := COALESCE(v_language, 'en');

  -- Category alert settings
  SELECT is_enabled, channels INTO v_is_enabled, v_category_chans
  FROM public.alert_settings
  WHERE user_id = NEW.user_id AND category = NEW.category;

  v_is_enabled     := COALESCE(v_is_enabled, NEW.category <> 'promo');
  v_category_chans := COALESCE(v_category_chans, v_all_channels);

  -- Inspect explicit push switch from notification_channels
  SELECT is_enabled INTO v_push_user_enabled
  FROM public.notification_channels
  WHERE user_id = NEW.user_id AND channel_type = 'push';

  -- Intersect user opt-in, category opt-in, and global catalog
  SELECT ARRAY(
    SELECT nc.channel_type
    FROM public.notification_channels nc
    WHERE nc.user_id = NEW.user_id
      AND nc.is_enabled = true
      AND nc.channel_type = ANY (v_category_chans)
      AND nc.channel_type = ANY (v_global_on)
  ) INTO v_channels;

  -- GATING: Paid channels (whatsapp and email) require an active Standard or Premium line.
  -- Expired lines, missing tiers, or Basic lines can ONLY receive push and telegram!
  IF v_effective_tier NOT IN ('standard', 'premium') OR v_is_line_expired THEN
    SELECT ARRAY(
      SELECT val FROM unnest(v_channels) AS val 
      WHERE val IN ('push', 'telegram')
    ) INTO v_channels;
  END IF;

  -- Fallback to push ONLY if push was NOT explicitly disabled by the user
  IF COALESCE(array_length(v_channels, 1), 0) = 0
     AND (v_push_user_enabled IS NULL OR v_push_user_enabled = true)
     AND 'push' = ANY (v_category_chans)
     AND v_push_global_on THEN
    v_channels := ARRAY['push'::text];
  END IF;

  IF v_is_enabled AND COALESCE(array_length(v_channels, 1), 0) > 0 THEN
    v_payload := jsonb_build_object(
      'notification_id', NEW.id,
      'user_id', NEW.user_id,
      'category', NEW.category,
      'title', NEW.title,
      'body', NEW.body,
      'action_url', NEW.action_url,
      'sim_line_id', NEW.sim_line_id,
      'channels', to_jsonb(v_channels),
      'schema_version', COALESCE(NEW.schema_version, 1),
      'event_type', NEW.event_type,
      'source_event_key', NEW.source_event_key,
      'template_data', COALESCE(NEW.template_data, '{}'::jsonb),
      'target', NEW.target,
      'language', v_language
    );
    INSERT INTO public.notification_dispatch_jobs(notification_id, user_id, payload)
    VALUES (NEW.id, NEW.user_id, v_payload)
    ON CONFLICT (notification_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$function$;

-- Include provider acceptance in the existing channel summary. Historical
-- delivered rows remain legacy/uncertain and must be labeled accordingly.
CREATE OR REPLACE FUNCTION public.admin_list_channels()
RETURNS TABLE (
  channel_key text, label text, is_globally_enabled boolean, provider text,
  credential_secret text, credential_status text, min_tier text,
  user_configurable boolean, monthly_quota integer, notes text,
  sort_order integer, users_enabled bigint, sent_30d bigint,
  failed_30d bigint, skipped_30d bigint, last_delivery_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
  SELECT c.channel_key,c.label,c.is_globally_enabled,c.provider,
         c.credential_secret,c.credential_status,c.min_tier,
         c.user_configurable,c.monthly_quota,c.notes,c.sort_order,
         (SELECT count(*) FROM public.notification_channels nc
          WHERE nc.channel_type=c.channel_key AND nc.is_enabled),
         COALESCE(d.sent,0),COALESCE(d.failed,0),COALESCE(d.skipped,0),d.last_at
  FROM public.notification_channel_catalog c
  LEFT JOIN LATERAL (
    SELECT count(*) FILTER (WHERE nd.status IN
      ('accepted_by_provider','delivered','sent','success')) AS sent,
      count(*) FILTER (WHERE nd.status='failed') AS failed,
      count(*) FILTER (WHERE nd.status='skipped') AS skipped,
      max(nd.created_at) AS last_at
    FROM public.notification_deliveries nd
    WHERE nd.created_at > now()-interval '30 days'
      AND (nd.channel=c.channel_key OR nd.channel LIKE c.channel_key || E'\\_%')
  ) d ON true
  ORDER BY c.sort_order;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_list_channels() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_channels()
  TO authenticated, service_role;

-- Drain persisted jobs every minute. The shared secret stays in Vault and is
-- read at execution time, so rotation does not require changing this job.
SELECT cron.schedule(
  'process-alert-outbox-every-minute',
  '* * * * *',
  $cron$
    SELECT net.http_post(
      url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/process-alert-outbox',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-keep-sims-secret', public.get_internal_secret('dispatch_shared_secret')
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 60000
    );
  $cron$
);
