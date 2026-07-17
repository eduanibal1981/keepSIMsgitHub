-- C2 — Alert preferences: predefined categories, per-category channel opt-in.
--
-- Category naming: doc/PRODUCTION_PLAN.md C2 item 1 sketched a different enum
-- (low_balance, upcoming_expiry, refill_success, refill_failure,
-- wallet_activity, travel_roaming, promo). That sketch predates the live schema
-- and is strictly lossier — it has no equivalent for system, referral_reward or
-- wallet_depleted, all of which users can toggle today. The live names stay
-- canonical (signed off 2026-07-17); this migration only adds the two that were
-- genuinely missing:
--   * wallet_credit — dispatchable since C1 but absent from
--     alert_settings_category_check, so deposit alerts could not be muted.
--   * promo         — the plan's one new category. Opt-in, see item 4.
--
-- Channel model: alert_settings.channels has existed since the table was
-- created, is seeded '{push}', and is read by nothing. C2 makes it live as the
-- per-category opt-in. Effective channels for a dispatch are
--   alert_settings.channels ∩ enabled(notification_channels) ∩ tier clamp
-- so the global per-channel switches remain the master control and the
-- per-category list can only narrow. Existing rows are widened to the full set,
-- which reproduces current behaviour exactly — intersecting the full set with
-- the globally-enabled set is a no-op. Narrowing them to the stored '{push}'
-- would silently mute email/telegram/whatsapp for everyone.

BEGIN;

-- 1. Category lists. Both tables carry the same set — keep them in sync.
ALTER TABLE public.alert_settings DROP CONSTRAINT IF EXISTS alert_settings_category_check;
ALTER TABLE public.alert_settings ADD CONSTRAINT alert_settings_category_check
  CHECK (category = ANY (ARRAY[
    'top_up_success','top_up_failed','wallet_low','wallet_depleted','line_critical',
    'line_entering_grace','geo_fence_triggered','welcome_home_ready','referral_reward',
    'system','wallet_credit','promo'
  ]));

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_category_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_category_check
  CHECK (category = ANY (ARRAY[
    'top_up_success','top_up_failed','wallet_low','wallet_depleted','line_critical',
    'line_entering_grace','geo_fence_triggered','welcome_home_ready','referral_reward',
    'system','wallet_credit','promo'
  ]));

-- 2. updated_at: the plan's table spec, and the consent timestamp for promo.
ALTER TABLE public.alert_settings
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DROP TRIGGER IF EXISTS trg_alert_settings_updated_at ON public.alert_settings;
CREATE TRIGGER trg_alert_settings_updated_at
  BEFORE UPDATE ON public.alert_settings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- 3. channels becomes the per-category opt-in.
ALTER TABLE public.alert_settings
  ALTER COLUMN channels SET DEFAULT ARRAY['push','email','telegram','whatsapp']::text[];

ALTER TABLE public.alert_settings DROP CONSTRAINT IF EXISTS alert_settings_channels_check;
ALTER TABLE public.alert_settings ADD CONSTRAINT alert_settings_channels_check
  CHECK (channels <@ ARRAY['push','email','telegram','whatsapp','webhook']::text[]);

-- Widen the inert '{push}' seed. The guard means a row that genuinely opted
-- into a narrower set (impossible before now, possible on re-run) is left alone.
UPDATE public.alert_settings
SET channels = ARRAY['push','email','telegram','whatsapp']::text[]
WHERE channels IS NULL OR channels <@ ARRAY['push']::text[];

-- 4. Seed defaults on signup — all on except promo, which stays off until the
--    user explicitly opts in (app-store marketing-consent requirement).
CREATE OR REPLACE FUNCTION public.seed_default_alert_settings()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  INSERT INTO public.alert_settings (user_id, category, is_enabled, channels)
  SELECT NEW.id,
         c.category,
         c.category <> 'promo',
         ARRAY['push','email','telegram','whatsapp']::text[]
  FROM unnest(ARRAY[
    'top_up_success','top_up_failed','wallet_low','wallet_depleted','line_critical',
    'line_entering_grace','geo_fence_triggered','welcome_home_ready','referral_reward',
    'system','wallet_credit','promo'
  ]) AS c(category)
  ON CONFLICT (user_id, category) DO NOTHING;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.seed_default_alert_settings() FROM public, anon, authenticated;

DROP TRIGGER IF EXISTS trg_profiles_seed_alert_settings ON public.profiles;
CREATE TRIGGER trg_profiles_seed_alert_settings
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.seed_default_alert_settings();

-- Backfill existing users so the DB is the only thing that ever seeds these
-- rows (the client's read-time seeding is removed in this session's Dart half).
-- ON CONFLICT DO NOTHING preserves every choice a user has already made.
INSERT INTO public.alert_settings (user_id, category, is_enabled, channels)
SELECT p.id,
       c.category,
       c.category <> 'promo',
       ARRAY['push','email','telegram','whatsapp']::text[]
FROM public.profiles p
CROSS JOIN unnest(ARRAY[
  'top_up_success','top_up_failed','wallet_low','wallet_depleted','line_critical',
  'line_entering_grace','geo_fence_triggered','welcome_home_ready','referral_reward',
  'system','wallet_credit','promo'
]) AS c(category)
ON CONFLICT (user_id, category) DO NOTHING;

-- 5. Dispatch gate: category on/off (C1) plus the per-category channel opt-in.
CREATE OR REPLACE FUNCTION public.trg_fn_dispatch_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_all_channels   CONSTANT text[] := ARRAY['push','email','telegram','whatsapp'];
  v_channels       text[];
  v_category_chans text[];
  v_is_enabled     boolean;
  v_url            text;
  v_payload        jsonb;
  v_tier           text;
  v_secret         text;
BEGIN
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

  -- The user's global channel switches, narrowed by the per-category opt-in.
  SELECT ARRAY(
    SELECT nc.channel_type
    FROM public.notification_channels nc
    WHERE nc.user_id = NEW.user_id
      AND nc.is_enabled = true
      AND nc.channel_type = ANY (v_category_chans)
  ) INTO v_channels;

  IF v_tier = 'basic' THEN
    SELECT ARRAY(SELECT val FROM unnest(v_channels) AS val WHERE val = 'push') INTO v_channels;
  END IF;

  -- Existing safety net: never leave a user with no route at all. Now gated on
  -- the category still permitting push — if they switched push off for this
  -- category, forcing it back would defeat the preference they just set.
  IF COALESCE(array_length(v_channels, 1), 0) = 0 AND 'push' = ANY (v_category_chans) THEN
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
$$;

REVOKE EXECUTE ON FUNCTION public.trg_fn_dispatch_notification() FROM public, anon, authenticated;

COMMIT;
