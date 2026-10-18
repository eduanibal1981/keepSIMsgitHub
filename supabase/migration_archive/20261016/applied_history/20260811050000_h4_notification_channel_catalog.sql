-- ============================================================================
-- H4 — a global registry for notification channels, and a real kill switch.
--
-- Until now "which channels exist" was a plpgsql CONSTANT inside
-- trg_fn_dispatch_notification (push/email/telegram/whatsapp) and "is this
-- channel usable" was decided by whether an Edge Function secret happened to be
-- set — WHATSAPP_VPS_API_KEY is unset, so that channel has been silently
-- skipping every send (16 of 16 in the last 30 days) with nothing in the product
-- saying so. There was no way to turn a channel off without a migration, and no
-- way to see its state at all.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.notification_channel_catalog (
  channel_key         text PRIMARY KEY,
  label               text NOT NULL,
  is_globally_enabled boolean NOT NULL DEFAULT true,
  provider            text,
  credential_secret   text,
  credential_status   text NOT NULL DEFAULT 'unknown'
                        CHECK (credential_status IN ('configured','missing','unknown')),
  min_tier            text NOT NULL DEFAULT 'basic'
                        CHECK (min_tier IN ('basic','standard','premium')),
  user_configurable   boolean NOT NULL DEFAULT true,
  monthly_quota       integer,
  notes               text,
  sort_order          integer NOT NULL DEFAULT 100,
  updated_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_channel_catalog ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.notification_channel_catalog FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.notification_channel_catalog TO authenticated;
GRANT ALL ON TABLE public.notification_channel_catalog TO service_role;

DROP POLICY IF EXISTS "Anyone signed in can read the channel catalog"
  ON public.notification_channel_catalog;
CREATE POLICY "Anyone signed in can read the channel catalog"
  ON public.notification_channel_catalog FOR SELECT TO authenticated USING (true);

-- The client needs the catalogue to stop offering a channel it cannot deliver
-- on; it must not read the credential columns, which name our secrets.
REVOKE SELECT (credential_secret, credential_status, notes)
  ON public.notification_channel_catalog FROM authenticated;

COMMENT ON TABLE public.notification_channel_catalog IS
  'H4: one row per delivery channel. is_globally_enabled is the operator kill switch consulted by trg_fn_dispatch_notification — including by the push safety net, which would otherwise re-add push after an admin turned it off. credential_status is maintained by hand: the database cannot read Edge Function secrets, so claiming to know would be a lie.';

INSERT INTO public.notification_channel_catalog
  (channel_key, label, is_globally_enabled, provider, credential_secret, credential_status, min_tier, user_configurable, monthly_quota, notes, sort_order)
VALUES
  ('push','Push notification', true,  'OneSignal, falling back to FCM', 'ONESIGNAL_REST_API_KEY', 'configured', 'basic', true, NULL,
   'Free and unmetered on both providers: OneSignal Free is unlimited mobile push sends and subscribers, FCM is unlimited on Spark. The 10k OneSignal cap is web push only. FCM is redundancy, not cost relief.', 10),
  ('email','Email', true, 'Resend', 'RESEND_API_KEY', 'configured', 'standard', true, 3000,
   'The only genuinely scarce channel (~3k/month free). dispatch-alert already restricts it to top_up_failed, line_critical and wallet_depleted. Measure real usage from notification_deliveries before raising it.', 20),
  ('telegram','Telegram', true, 'Telegram Bot API', 'TELEGRAM_BOT_TOKEN', 'configured', 'standard', true, NULL,
   'Needs a chat id in the user''s notification_channels.config. Enabled by 0 of 8 users today.', 30),
  ('whatsapp','WhatsApp', false, 'Self-hosted Baileys VPS', 'WHATSAPP_VPS_API_KEY', 'missing', 'premium', true, NULL,
   'Ships OFF because the secret has never been set: dispatch-alert has been logging "skipped" for every WhatsApp send. Turning this on without the secret changes nothing except that the failure becomes invisible again. Set WHATSAPP_VPS_API_KEY, mark the credential configured, then enable.', 40),
  ('webhook','Webhook', true, 'Customer HTTP endpoint', NULL, 'configured', 'premium', true, NULL,
   'Per-user outbound POST. Fleet/business use.', 50)
ON CONFLICT (channel_key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- The dispatcher, rewired.
--
-- Two changes, and the second is the one a single pass misses:
--   1. the channel universe comes from the catalogue instead of a CONSTANT, and
--      a globally disabled channel is removed from the user's effective set;
--   2. the "never leave a user with no route" push safety net is gated on push
--      being globally enabled. Without that, disabling push in the admin app
--      would appear to work and then be silently undone for every user whose
--      other channels are off — which is most of them.
--
-- Proven with the c2 technique (assert on net.http_request_queue): push on, a
-- new notification takes the queue 0 -> 1 with delivered_via {push}; push off,
-- the queue does not move and delivered_via comes back empty.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_fn_dispatch_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_all_channels   text[];
  v_global_on      text[];
  v_channels       text[];
  v_category_chans text[];
  v_is_enabled     boolean;
  v_url            text;
  v_payload        jsonb;
  v_tier           text;
  v_secret         text;
  v_push_global_on boolean;
BEGIN
  SELECT ARRAY(SELECT channel_key FROM public.notification_channel_catalog ORDER BY sort_order),
         ARRAY(SELECT channel_key FROM public.notification_channel_catalog
                WHERE is_globally_enabled ORDER BY sort_order)
    INTO v_all_channels, v_global_on;

  -- Fail soft, not silent: if the catalogue is empty for any reason, behave
  -- exactly as this function did before H4 rather than muting the product.
  IF COALESCE(array_length(v_all_channels, 1), 0) = 0 THEN
    v_all_channels := ARRAY['push','email','telegram','whatsapp'];
    v_global_on    := v_all_channels;
  END IF;

  v_push_global_on := 'push' = ANY (v_global_on);

  IF NEW.sim_line_id IS NOT NULL THEN
    SELECT protection_tier INTO v_tier FROM public.sim_lines WHERE id = NEW.sim_line_id;
  END IF;
  IF v_tier IS NULL THEN
    SELECT subscription_tier INTO v_tier FROM public.profiles WHERE id = NEW.user_id;
  END IF;
  v_tier := COALESCE(v_tier, 'standard');

  SELECT is_enabled, channels INTO v_is_enabled, v_category_chans
  FROM public.alert_settings
  WHERE user_id = NEW.user_id AND category = NEW.category;

  -- No row means the user has never touched their preferences: default on, as
  -- C1 established. promo inverts that — marketing needs explicit opt-in, so an
  -- absent row means "not consented", never "send it".
  v_is_enabled     := COALESCE(v_is_enabled, NEW.category <> 'promo');
  v_category_chans := COALESCE(v_category_chans, v_all_channels);

  -- The user's global channel switches, narrowed by the per-category opt-in,
  -- narrowed again by the operator's catalogue.
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

  IF COALESCE(array_length(v_channels, 1), 0) = 0
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

CREATE OR REPLACE FUNCTION public.admin_update_channel(
  p_channel_key text,
  p_patch       jsonb,
  p_note        text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_allowed text[] := ARRAY['is_globally_enabled','label','provider','credential_secret',
                            'credential_status','min_tier','user_configurable','monthly_quota',
                            'notes','sort_order'];
  v_bad    text;
  v_before jsonb;
  v_after  jsonb;
BEGIN
  PERFORM public.assert_admin();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Nothing to change' USING ERRCODE = 'KS467';
  END IF;

  SELECT string_agg(k, ', ') INTO v_bad
  FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'Unknown field(s): %', v_bad USING ERRCODE = 'KS467';
  END IF;

  SELECT to_jsonb(c) INTO v_before
  FROM public.notification_channel_catalog c WHERE c.channel_key = p_channel_key;
  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Unknown channel %', p_channel_key USING ERRCODE = 'KS461';
  END IF;

  -- Turning a channel on while its credential is missing produces a channel
  -- that accepts sends and drops them. That is the state WhatsApp has been in;
  -- refusing it here is the whole point of recording credential_status.
  IF COALESCE((p_patch ->> 'is_globally_enabled')::boolean, false)
     AND COALESCE(p_patch ->> 'credential_status',
                  v_before ->> 'credential_status') = 'missing' THEN
    RAISE EXCEPTION
      'Cannot enable % while its credential (%) is recorded as missing — sends would be accepted and silently dropped',
      p_channel_key, COALESCE(v_before ->> 'credential_secret', 'n/a')
      USING ERRCODE = 'KS466';
  END IF;

  UPDATE public.notification_channel_catalog SET
    is_globally_enabled = COALESCE((p_patch ->> 'is_globally_enabled')::boolean, is_globally_enabled),
    label               = COALESCE(NULLIF(btrim(p_patch ->> 'label'), ''), label),
    provider            = CASE WHEN p_patch ? 'provider'
                               THEN NULLIF(btrim(p_patch ->> 'provider'), '') ELSE provider END,
    credential_secret   = CASE WHEN p_patch ? 'credential_secret'
                               THEN NULLIF(btrim(p_patch ->> 'credential_secret'), '') ELSE credential_secret END,
    credential_status   = COALESCE(p_patch ->> 'credential_status', credential_status),
    min_tier            = COALESCE(p_patch ->> 'min_tier', min_tier),
    user_configurable   = COALESCE((p_patch ->> 'user_configurable')::boolean, user_configurable),
    monthly_quota       = CASE WHEN p_patch ? 'monthly_quota'
                               THEN NULLIF(p_patch ->> 'monthly_quota', '')::integer ELSE monthly_quota END,
    notes               = CASE WHEN p_patch ? 'notes'
                               THEN NULLIF(btrim(p_patch ->> 'notes'), '') ELSE notes END,
    sort_order          = COALESCE((p_patch ->> 'sort_order')::integer, sort_order),
    updated_at          = now()
  WHERE channel_key = p_channel_key;

  SELECT to_jsonb(c) INTO v_after
  FROM public.notification_channel_catalog c WHERE c.channel_key = p_channel_key;

  PERFORM public.admin_log('channel.update', 'notification_channel', p_channel_key, v_before, v_after, p_note);

  RETURN jsonb_build_object('success', true, 'channel', p_channel_key);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_channel(text,jsonb,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_channel(text,jsonb,text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_notification_health(p_days integer DEFAULT 30)
RETURNS TABLE (
  channel        text,
  status         text,
  n              bigint,
  last_at        timestamptz,
  sample_detail  text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT nd.channel, nd.status, count(*), max(nd.created_at),
         (array_agg(nd.detail ORDER BY nd.created_at DESC)
            FILTER (WHERE nd.detail IS NOT NULL))[1]
  FROM public.notification_deliveries nd
  WHERE nd.created_at > now() - make_interval(days => LEAST(GREATEST(COALESCE(p_days,30),1),365))
  GROUP BY nd.channel, nd.status
  ORDER BY nd.channel, count(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_notification_health(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_notification_health(integer) TO authenticated, service_role;
