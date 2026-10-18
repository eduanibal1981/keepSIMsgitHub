-- C1: Notification dispatcher — delivery logging, per-device tokens,
-- Vault-based trigger secret, and DB event wiring into public.notifications.
-- Applied to live 2026-07-17.

-- ---------------------------------------------------------------------------
-- 1) notification_deliveries: one row per channel delivery attempt, written by
--    the dispatch-alert Edge Function (service role). Users may read their own.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notification_deliveries (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid REFERENCES public.notifications(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel         text NOT NULL,   -- push_onesignal | push_fcm | email | telegram | whatsapp | webhook
  status          text NOT NULL CHECK (status IN ('delivered','failed','skipped')),
  detail          text,
  provider_status integer,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notif_deliveries_notification
  ON public.notification_deliveries(notification_id);
CREATE INDEX IF NOT EXISTS idx_notif_deliveries_user
  ON public.notification_deliveries(user_id, created_at DESC);

ALTER TABLE public.notification_deliveries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "deliveries_select_own" ON public.notification_deliveries;
CREATE POLICY "deliveries_select_own" ON public.notification_deliveries
  FOR SELECT USING (auth.uid() = user_id);
-- No INSERT/UPDATE/DELETE policies: writes happen only through the service role
-- (Edge Function), which bypasses RLS. The client never writes deliveries.

-- ---------------------------------------------------------------------------
-- 2) device_push_tokens: OneSignal player id + raw FCM token, one row per
--    (user, device). The FCM fallback targets fcm_token; OneSignal targets the
--    external_id alias (= user id) but we also store the player id for debugging
--    and future direct-device targeting.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.device_push_tokens (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id            text NOT NULL,          -- stable per-install id from the client
  platform             text,                   -- android | ios | web
  onesignal_player_id  text,
  fcm_token            text,
  updated_at           timestamptz NOT NULL DEFAULT now(),
  created_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_device_push_tokens_user
  ON public.device_push_tokens(user_id);

ALTER TABLE public.device_push_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dpt_select_own" ON public.device_push_tokens;
CREATE POLICY "dpt_select_own" ON public.device_push_tokens
  FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "dpt_insert_own" ON public.device_push_tokens;
CREATE POLICY "dpt_insert_own" ON public.device_push_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "dpt_update_own" ON public.device_push_tokens;
CREATE POLICY "dpt_update_own" ON public.device_push_tokens
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "dpt_delete_own" ON public.device_push_tokens;
CREATE POLICY "dpt_delete_own" ON public.device_push_tokens
  FOR DELETE USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 3) Shared secret out of source and into Vault. The notifications trigger
--    sends it to the internet-facing dispatch-alert function; the function
--    reads the expected value back via get_internal_secret (service role only).
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'dispatch_shared_secret') THEN
    PERFORM vault.create_secret(
      gen_random_uuid()::text,
      'dispatch_shared_secret',
      'Shared secret the notifications trigger sends to the dispatch-alert Edge Function'
    );
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.get_internal_secret(p_name text)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = p_name;
$function$;

REVOKE ALL ON FUNCTION public.get_internal_secret(text) FROM public;
REVOKE ALL ON FUNCTION public.get_internal_secret(text) FROM anon;
REVOKE ALL ON FUNCTION public.get_internal_secret(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.get_internal_secret(text) TO service_role;

-- ---------------------------------------------------------------------------
-- 4) Rebuild the notification dispatch trigger: SECURITY DEFINER so it can read
--    the Vault secret, and no hardcoded secret literal. Behaviour is otherwise
--    identical to the previous version (tier gate, alert_settings gate,
--    notification_channels selection, delivered_via write, pg_net POST).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_fn_dispatch_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_channels   text[];
  v_is_enabled boolean;
  v_url        text;
  v_payload    jsonb;
  v_tier       text;
  v_secret     text;
BEGIN
  -- 0. Tier: SIM line tier first, then profile tier, then default.
  IF NEW.sim_line_id IS NOT NULL THEN
    SELECT protection_tier INTO v_tier FROM public.sim_lines WHERE id = NEW.sim_line_id;
  END IF;
  IF v_tier IS NULL THEN
    SELECT subscription_tier INTO v_tier FROM public.profiles WHERE id = NEW.user_id;
  END IF;
  IF v_tier IS NULL THEN
    v_tier := 'standard';
  END IF;

  -- 1. Alert-category gate (default enabled if no row yet; C2 formalises this).
  SELECT is_enabled INTO v_is_enabled
  FROM public.alert_settings
  WHERE user_id = NEW.user_id AND category = NEW.category;
  IF v_is_enabled IS NULL THEN
    v_is_enabled := TRUE;
  END IF;

  -- 2. Globally enabled channels for this user.
  SELECT ARRAY(
    SELECT channel_type FROM public.notification_channels
    WHERE user_id = NEW.user_id AND is_enabled = true
  ) INTO v_channels;

  -- Free tier (basic) is push-only.
  IF v_tier = 'basic' THEN
    SELECT ARRAY(SELECT val FROM unnest(v_channels) AS val WHERE val = 'push') INTO v_channels;
  END IF;

  -- 3. Default to push when nothing configured.
  IF array_length(v_channels, 1) IS NULL OR array_length(v_channels, 1) = 0 THEN
    v_channels := ARRAY['push'::text];
  END IF;

  UPDATE public.notifications SET delivered_via = v_channels WHERE id = NEW.id;

  -- 4. Dispatch via Edge Function when the category is enabled.
  IF v_is_enabled = TRUE AND array_length(v_channels, 1) > 0 THEN
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
      'channels',        to_jsonb(v_channels)
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

-- ---------------------------------------------------------------------------
-- 5) Wire real domain events into public.notifications. Each INSERT here fires
--    trg_on_notification_created -> dispatch-alert, so these are the only new
--    hookups needed for push/email delivery.
-- ---------------------------------------------------------------------------

-- 5a. Refill success / failure (worker flips topup_executions.status).
CREATE OR REPLACE FUNCTION public.trg_fn_notify_topup_result()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_phone  text;
  v_amount text;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;
  IF NEW.status NOT IN ('success', 'failed') THEN
    RETURN NEW;
  END IF;

  SELECT phone_number INTO v_phone FROM public.sim_lines WHERE id = NEW.sim_line_id;
  v_amount := to_char(COALESCE(NEW.amount, 0), 'FM99999990.00');

  IF NEW.status = 'success' THEN
    INSERT INTO public.notifications
      (user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read)
    VALUES
      (NEW.user_id, 'top_up_success', 'Recharge successful',
       'Your recharge of $' || v_amount || ' for ' || COALESCE(v_phone, 'your line') || ' completed.',
       '/sim_lines/' || NEW.sim_line_id, NEW.sim_line_id, ARRAY['push']::text[], false);
  ELSE
    INSERT INTO public.notifications
      (user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read)
    VALUES
      (NEW.user_id, 'top_up_failed', 'Recharge failed',
       'We could not complete your $' || v_amount || ' recharge for ' || COALESCE(v_phone, 'your line') || '. Please review your wallet and line.',
       '/sim_lines/' || NEW.sim_line_id, NEW.sim_line_id, ARRAY['push']::text[], false);
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_notify_topup_result ON public.topup_executions;
CREATE TRIGGER trg_notify_topup_result
  AFTER INSERT OR UPDATE OF status ON public.topup_executions
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_notify_topup_result();

-- 5b. Wallet credit (deposits only; debits/refunds/referral handled elsewhere).
--     NB: the 'wallet_credit' category is added to the notifications_category_check
--     constraint in the follow-up migration 20260717000100 — that must be applied
--     for this trigger's inserts to succeed.
CREATE OR REPLACE FUNCTION public.trg_fn_notify_wallet_credit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_amount text;
BEGIN
  v_amount := to_char(COALESCE(NEW.amount, 0), 'FM99999990.00');
  INSERT INTO public.notifications
    (user_id, category, title, body, action_url, delivered_via, is_read)
  VALUES
    (NEW.user_id, 'wallet_credit', 'Wallet topped up',
     '$' || v_amount || ' has been added to your wallet.',
     '/wallet', ARRAY['push']::text[], false);
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_notify_wallet_credit ON public.wallet_transactions;
CREATE TRIGGER trg_notify_wallet_credit
  AFTER INSERT ON public.wallet_transactions
  FOR EACH ROW WHEN (NEW.type = 'deposit')
  EXECUTE FUNCTION public.trg_fn_notify_wallet_credit();

-- 5c. system_alerts -> notify every power user.
CREATE OR REPLACE FUNCTION public.trg_fn_notify_system_alert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.notifications
    (user_id, category, title, body, action_url, delivered_via, is_read)
  SELECT p.id, 'system',
         'System alert: ' || NEW.kind,
         NEW.message,
         '/notifications', ARRAY['push']::text[], false
  FROM public.profiles p
  WHERE p.is_power_user = true;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_notify_system_alert ON public.system_alerts;
CREATE TRIGGER trg_notify_system_alert
  AFTER INSERT ON public.system_alerts
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_notify_system_alert();
