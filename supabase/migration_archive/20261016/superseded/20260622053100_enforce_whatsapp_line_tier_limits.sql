-- Migration to enforce plan restrictions on notification channels based on SIM line tier.
-- If the alert is for a specific SIM line, we check its protection tier.
-- If it is basic (Free Plan), we restrict notifications to mobile push only.

CREATE OR REPLACE FUNCTION public.trg_fn_dispatch_notification()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_channels TEXT[];
  v_is_enabled BOOLEAN;
  v_url TEXT;
  v_payload JSONB;
  v_tier TEXT;
BEGIN
  -- 0. Fetch tier: check SIM line tier first, then fall back to profile tier
  IF NEW.sim_line_id IS NOT NULL THEN
    SELECT protection_tier INTO v_tier
    FROM public.sim_lines
    WHERE id = NEW.sim_line_id;
  END IF;

  IF v_tier IS NULL THEN
    SELECT subscription_tier INTO v_tier
    FROM public.profiles
    WHERE id = NEW.user_id;
  END IF;

  IF v_tier IS NULL THEN
    v_tier := 'standard';
  END IF;

  -- 1. Check user's alert settings for this category
  SELECT is_enabled INTO v_is_enabled
  FROM public.alert_settings
  WHERE user_id = NEW.user_id AND category = NEW.category;

  -- Default to enabled if category settings don't exist yet
  IF v_is_enabled IS NULL THEN
    v_is_enabled := TRUE;
  END IF;

  -- 2. Fetch the globally enabled channels from notification_channels
  SELECT ARRAY(
    SELECT channel_type 
    FROM public.notification_channels 
    WHERE user_id = NEW.user_id AND is_enabled = true
  ) INTO v_channels;

  -- Enforce plan tier limits: if tier is 'basic' (Free Plan), only allow 'push' notification
  IF v_tier = 'basic' THEN
    SELECT ARRAY(
      SELECT val FROM unnest(v_channels) AS val WHERE val = 'push'
    ) INTO v_channels;
  END IF;

  -- 3. Default to push if no channels are configured/enabled in notification_channels
  IF array_length(v_channels, 1) IS NULL OR array_length(v_channels, 1) = 0 THEN
    v_channels := ARRAY['push'::text];
  END IF;

  -- Update the notification record itself to store actual delivery channels
  UPDATE public.notifications SET delivered_via = v_channels WHERE id = NEW.id;

  -- 4. If alert category is enabled, dispatch via Edge Function
  IF v_is_enabled = TRUE AND array_length(v_channels, 1) > 0 THEN
    v_url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/dispatch-alert';
    
    -- Construct full payload
    v_payload := jsonb_build_object(
      'notification_id', NEW.id,
      'user_id', NEW.user_id,
      'category', NEW.category,
      'title', NEW.title,
      'body', NEW.body,
      'action_url', NEW.action_url,
      'sim_line_id', NEW.sim_line_id,
      'channels', to_jsonb(v_channels)
    );

    -- Perform asynchronous HTTP POST call via pg_net
    PERFORM net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-keep-sims-secret', 'super_secret_alerts_key'
      ),
      body := v_payload,
      timeout_milliseconds := 5000
    );
  END IF;

  RETURN NEW;
END;
$function$;
