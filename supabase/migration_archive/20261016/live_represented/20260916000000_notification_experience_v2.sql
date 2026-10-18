-- ---------------------------------------------------------------------------
-- Migration: 20260916000000_notification_experience_v2.sql
-- Purpose: Additive schema for KeepSIMs Notification Experience v2
--          (event_type, source_event_key, template_data, target, language)
--          and preference-honoring dispatch trigger fix.
-- ---------------------------------------------------------------------------

-- 1. Additive columns on public.notifications
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS schema_version integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS event_type text,
  ADD COLUMN IF NOT EXISTS source_event_key text,
  ADD COLUMN IF NOT EXISTS occurred_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS scheduled_at timestamptz,
  ADD COLUMN IF NOT EXISTS expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS template_version integer DEFAULT 1,
  ADD COLUMN IF NOT EXISTS template_data jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS target jsonb;

CREATE INDEX IF NOT EXISTS idx_notifications_event_key
  ON public.notifications(source_event_key)
  WHERE source_event_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_event_type
  ON public.notifications(event_type)
  WHERE event_type IS NOT NULL;

-- 2. Update dispatch trigger function
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
  v_url                text;
  v_payload            jsonb;
  v_tier               text;
  v_secret             text;
  v_push_global_on     boolean;
  v_push_user_enabled  boolean;
  v_language           text;
BEGIN
  SELECT ARRAY(SELECT channel_key FROM public.notification_channel_catalog ORDER BY sort_order),
         ARRAY(SELECT channel_key FROM public.notification_channel_catalog
                WHERE is_globally_enabled ORDER BY sort_order)
    INTO v_all_channels, v_global_on;

  -- Fail soft, not silent: if the catalogue is empty for any reason, default to standard channels
  IF COALESCE(array_length(v_all_channels, 1), 0) = 0 THEN
    v_all_channels := ARRAY['push','email','telegram','whatsapp'];
    v_global_on    := v_all_channels;
  END IF;

  v_push_global_on := 'push' = ANY (v_global_on);

  -- Fetch line protection tier or profile subscription tier
  IF NEW.sim_line_id IS NOT NULL THEN
    SELECT protection_tier INTO v_tier FROM public.sim_lines WHERE id = NEW.sim_line_id;
  END IF;
  IF v_tier IS NULL THEN
    SELECT subscription_tier INTO v_tier FROM public.profiles WHERE id = NEW.user_id;
  END IF;
  v_tier := COALESCE(v_tier, 'standard');

  -- Fetch user preferred language from user_preferences
  SELECT language INTO v_language FROM public.user_preferences WHERE user_id = NEW.user_id;
  v_language := COALESCE(v_language, 'en');

  -- Alert settings per category
  SELECT is_enabled, channels INTO v_is_enabled, v_category_chans
  FROM public.alert_settings
  WHERE user_id = NEW.user_id AND category = NEW.category;

  v_is_enabled     := COALESCE(v_is_enabled, NEW.category <> 'promo');
  v_category_chans := COALESCE(v_category_chans, v_all_channels);

  -- Inspect explicit push switch from notification_channels
  SELECT is_enabled INTO v_push_user_enabled
  FROM public.notification_channels
  WHERE user_id = NEW.user_id AND channel_type = 'push';

  -- User's active channels intersected with category opt-in and global operator catalog
  SELECT ARRAY(
    SELECT nc.channel_type
    FROM public.notification_channels nc
    WHERE nc.user_id = NEW.user_id
      AND nc.is_enabled = true
      AND nc.channel_type = ANY (v_category_chans)
      AND nc.channel_type = ANY (v_global_on)
  ) INTO v_channels;

  IF v_tier = 'basic' THEN
    SELECT ARRAY(SELECT val FROM unnest(v_channels) AS val WHERE val = 'push') INTO v_channels;
  END IF;

  -- Fallback to push ONLY if push was NOT explicitly disabled by the user (honoring opt-out)
  IF COALESCE(array_length(v_channels, 1), 0) = 0
     AND (v_push_user_enabled IS NULL OR v_push_user_enabled = true)
     AND 'push' = ANY (v_category_chans)
     AND v_push_global_on THEN
    v_channels := ARRAY['push'::text];
  END IF;

  UPDATE public.notifications SET delivered_via = v_channels WHERE id = NEW.id;

  IF v_is_enabled AND COALESCE(array_length(v_channels, 1), 0) > 0 THEN
    SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'dispatch_shared_secret';

    v_url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/dispatch-alert';

    v_payload := jsonb_build_object(
      'notification_id', NEW.id,
      'user_id',         NEW.user_id,
      'category',        NEW.category,
      'title',           NEW.title,
      'body',            NEW.body,
      'action_url',      NEW.action_url,
      'sim_line_id',     NEW.sim_line_id,
      'channels',        to_jsonb(v_channels),
      'schema_version',  COALESCE(NEW.schema_version, 1),
      'event_type',      NEW.event_type,
      'template_data',   COALESCE(NEW.template_data, '{}'::jsonb),
      'target',          NEW.target,
      'language',        v_language
    );

    PERFORM net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-keep-sims-secret', COALESCE(v_secret, '')
      ),
      body := v_payload,
      timeout_milliseconds := 5000
    );
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.trg_fn_dispatch_notification() FROM public, anon, authenticated;
