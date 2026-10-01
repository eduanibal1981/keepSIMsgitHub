-- Migration: 20261001031000_repair_notification_trigger_outbox_contract.sql
-- Description:
-- 1. P0 Repair: Restores exact durable outbox contract (notification_id, user_id, payload) on notification_dispatch_jobs.
-- 2. Removes incompatible inline HTTP dispatch block.
-- 3. Restores full payload fields including 'target' and COALESCE(template_data, '{}'::jsonb).
-- 4. Enforces strict line ownership: checks sim_lines.user_id == NEW.user_id.
-- 5. Canonical tier resolution: uses COALESCE(NULLIF(plan_type, ''), NULLIF(protection_tier, ''), 'basic').
-- 6. Verifies subscription expiry via plan_expires_at (not telecom carrier validity).

-- Never replace the newer atomic delivery contract on a fresh migration run.
DO $guard$ BEGIN
  IF to_regprocedure('public.claim_notification_channel_target(uuid,text,text,jsonb)') IS NULL THEN
    EXECUTE $definition$
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
  v_tier               text;
  v_plan_type          text;
  v_plan_expires_at    timestamptz;
  v_effective_tier     text := 'basic';
  v_is_subscription_expired boolean := false;
  v_push_global_on     boolean;
  v_push_user_enabled  boolean;
  v_language           text;
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

  -- Strict line-level entitlement, subscription expiry, and owner verification
  IF NEW.sim_line_id IS NOT NULL THEN
    SELECT protection_tier, plan_type, plan_expires_at
    INTO v_tier, v_plan_type, v_plan_expires_at
    FROM public.sim_lines
    WHERE id = NEW.sim_line_id AND user_id = NEW.user_id;

    IF FOUND THEN
      v_effective_tier := lower(COALESCE(NULLIF(v_plan_type, ''), NULLIF(v_tier, ''), 'basic'));
      v_is_subscription_expired := (v_plan_expires_at IS NOT NULL AND v_plan_expires_at < now());
    ELSE
      -- Line doesn't belong to notification user or was deleted; deny paid channel privileges
      v_effective_tier := 'basic';
      v_is_subscription_expired := false;
    END IF;
  ELSE
    -- If no sim_line_id is associated (account-level), default to basic for external channel gating
    v_effective_tier := 'basic';
    v_is_subscription_expired := false;
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
  -- Expired subscriptions, basic lines, or foreign lines can ONLY receive push and telegram!
  IF v_effective_tier NOT IN ('standard', 'premium') OR v_is_subscription_expired THEN
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

  -- Durable outbox insert matching live table schema
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
      'occurred_at', NEW.occurred_at,
      'template_version', NEW.template_version,
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

$definition$;
  END IF;
END $guard$;
