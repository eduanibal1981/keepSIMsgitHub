-- Migration: 20260926010000_default_email_notification_channel.sql
-- Description: Automatically default notification_channels (email) to the user's login email in profiles table.

-- 1. Backfill any existing email channels with missing config.email
UPDATE public.notification_channels nc
SET config = jsonb_set(COALESCE(nc.config, '{}'::jsonb), '{email}', to_jsonb(p.email))
FROM public.profiles p
WHERE nc.user_id = p.id
  AND nc.channel_type = 'email'
  AND (nc.config->>'email' IS NULL OR trim(nc.config->>'email') = '')
  AND p.email IS NOT NULL AND trim(p.email) <> '';

-- 2. Trigger function to ensure email channel always defaults to the user's account email
CREATE OR REPLACE FUNCTION public.trg_fn_default_notification_channel_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_email text;
BEGIN
  IF NEW.channel_type = 'email' AND (NEW.config->>'email' IS NULL OR trim(NEW.config->>'email') = '') THEN
    SELECT email INTO v_email FROM public.profiles WHERE id = NEW.user_id;
    IF v_email IS NOT NULL AND trim(v_email) <> '' THEN
      NEW.config := jsonb_set(COALESCE(NEW.config, '{}'::jsonb), '{email}', to_jsonb(v_email));
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_default_notification_channel_email ON public.notification_channels;
CREATE TRIGGER trg_default_notification_channel_email
  BEFORE INSERT OR UPDATE OF config, is_enabled ON public.notification_channels
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_default_notification_channel_email();
