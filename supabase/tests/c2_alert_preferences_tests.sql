-- C2: alert-preference gating tests.
--
-- Run live inside BEGIN..ROLLBACK (workers can't see uncommitted rows); the
-- dispatch pg_net POSTs enqueued by trg_fn_dispatch_notification are discarded
-- on rollback, so nothing is actually delivered. Fixtures reference the
-- a1-wallet-test user (see doc/B1_B2_REFILL_MONEY_AUDIT.md).
--
-- These assert on net.http_request_queue directly: a dispatch decision is only
-- observable as an enqueued POST. delivered_via alone can't prove it, because
-- the trigger writes delivered_via before it consults is_enabled.
--
-- Covers: category on/off gating, per-category channel narrowing, the push
-- safety net not overriding a deliberate opt-out, promo's inverted default,
-- wallet_credit now being mutable, and the signup seed.

BEGIN;

DO $$
DECLARE
  v_user    uuid := 'e5a56433-6f75-41a3-96b9-19c62b9d1280';
  v_all     text[] := ARRAY['push','email','telegram','whatsapp'];
  v_q       bigint;
  v_before  bigint;
  v_note    uuid;
  v_via     text[];
  v_count   int;
  v_new     uuid;
BEGIN
  -- Deterministic fixture: standard tier (no basic clamp), push+email globally
  -- on, telegram/whatsapp globally off.
  UPDATE public.profiles SET subscription_tier = 'standard' WHERE id = v_user;
  DELETE FROM public.notification_channels WHERE user_id = v_user;
  INSERT INTO public.notification_channels (user_id, channel_type, is_enabled, config)
  VALUES (v_user,'push',true,'{}'::jsonb), (v_user,'email',true,'{}'::jsonb),
         (v_user,'telegram',false,'{}'::jsonb), (v_user,'whatsapp',false,'{}'::jsonb);

  -- 1) Enabled category dispatches, and delivered_via is the intersection of
  --    the per-category opt-in with the globally-enabled channels.
  UPDATE public.alert_settings SET is_enabled = true, channels = v_all
   WHERE user_id = v_user AND category = 'system';
  SELECT count(*) INTO v_before FROM net.http_request_queue;
  INSERT INTO public.notifications (user_id, category, title, body, is_read)
  VALUES (v_user, 'system', 'C2 test enabled', 'body', false)
  RETURNING id INTO v_note;
  SELECT count(*) INTO v_q FROM net.http_request_queue;
  IF v_q <> v_before + 1 THEN
    RAISE EXCEPTION 'enabled category did not dispatch (queue % -> %)', v_before, v_q;
  END IF;
  SELECT delivered_via INTO v_via FROM public.notifications WHERE id = v_note;
  IF NOT (v_via @> ARRAY['push','email']::text[] AND v_via <@ ARRAY['push','email']::text[]) THEN
    RAISE EXCEPTION 'expected delivered_via {push,email}, got %', v_via;
  END IF;

  -- 2) THE C2 GATE: a disabled category must not dispatch at all.
  UPDATE public.alert_settings SET is_enabled = false
   WHERE user_id = v_user AND category = 'system';
  SELECT count(*) INTO v_before FROM net.http_request_queue;
  INSERT INTO public.notifications (user_id, category, title, body, is_read)
  VALUES (v_user, 'system', 'C2 test disabled', 'body', false);
  SELECT count(*) INTO v_q FROM net.http_request_queue;
  IF v_q <> v_before THEN
    RAISE EXCEPTION 'disabled category still dispatched (queue % -> %)', v_before, v_q;
  END IF;

  -- 3) Per-category narrowing: category allows push only, so email is dropped
  --    even though it is globally enabled.
  UPDATE public.alert_settings SET is_enabled = true, channels = ARRAY['push']::text[]
   WHERE user_id = v_user AND category = 'system';
  INSERT INTO public.notifications (user_id, category, title, body, is_read)
  VALUES (v_user, 'system', 'C2 test narrowed', 'body', false)
  RETURNING id INTO v_note;
  SELECT delivered_via INTO v_via FROM public.notifications WHERE id = v_note;
  IF v_via <> ARRAY['push']::text[] THEN
    RAISE EXCEPTION 'per-category narrowing failed, expected {push}, got %', v_via;
  END IF;

  -- 4) Opting a category out of every channel silences it — the push safety net
  --    must not resurrect a route the user deliberately switched off.
  UPDATE public.alert_settings SET is_enabled = true, channels = ARRAY['telegram']::text[]
   WHERE user_id = v_user AND category = 'system';
  SELECT count(*) INTO v_before FROM net.http_request_queue;
  INSERT INTO public.notifications (user_id, category, title, body, is_read)
  VALUES (v_user, 'system', 'C2 test all-off', 'body', false)
  RETURNING id INTO v_note;
  SELECT count(*) INTO v_q FROM net.http_request_queue;
  SELECT delivered_via INTO v_via FROM public.notifications WHERE id = v_note;
  IF v_q <> v_before THEN
    RAISE EXCEPTION 'category with no reachable channel still dispatched';
  END IF;
  IF COALESCE(array_length(v_via, 1), 0) <> 0 THEN
    RAISE EXCEPTION 'expected empty delivered_via, got %', v_via;
  END IF;

  -- 5) promo is opt-in: the seeded row is off, so it must not dispatch.
  SELECT count(*) INTO v_before FROM net.http_request_queue;
  INSERT INTO public.notifications (user_id, category, title, body, is_read)
  VALUES (v_user, 'promo', 'C2 test promo', 'body', false);
  SELECT count(*) INTO v_q FROM net.http_request_queue;
  IF v_q <> v_before THEN
    RAISE EXCEPTION 'promo dispatched without opt-in (queue % -> %)', v_before, v_q;
  END IF;

  -- 6) promo with no row at all is still treated as no-consent (inverted
  --    default), unlike every other category.
  DELETE FROM public.alert_settings WHERE user_id = v_user AND category = 'promo';
  SELECT count(*) INTO v_before FROM net.http_request_queue;
  INSERT INTO public.notifications (user_id, category, title, body, is_read)
  VALUES (v_user, 'promo', 'C2 test promo no row', 'body', false);
  SELECT count(*) INTO v_q FROM net.http_request_queue;
  IF v_q <> v_before THEN
    RAISE EXCEPTION 'promo with no settings row dispatched (queue % -> %)', v_before, v_q;
  END IF;

  -- 7) A non-promo category with no row keeps C1's default-on behaviour.
  DELETE FROM public.alert_settings WHERE user_id = v_user AND category = 'wallet_low';
  SELECT count(*) INTO v_before FROM net.http_request_queue;
  INSERT INTO public.notifications (user_id, category, title, body, is_read)
  VALUES (v_user, 'wallet_low', 'C2 test default on', 'body', false);
  SELECT count(*) INTO v_q FROM net.http_request_queue;
  IF v_q <> v_before + 1 THEN
    RAISE EXCEPTION 'missing settings row should default to enabled (queue % -> %)', v_before, v_q;
  END IF;

  -- 8) wallet_credit is now mutable — before C2 it was dispatchable but absent
  --    from alert_settings_category_check, so it could not be turned off.
  INSERT INTO public.alert_settings (user_id, category, is_enabled, channels)
  VALUES (v_user, 'wallet_credit', false, v_all)
  ON CONFLICT (user_id, category) DO UPDATE SET is_enabled = false;
  SELECT count(*) INTO v_before FROM net.http_request_queue;
  INSERT INTO public.notifications (user_id, category, title, body, is_read)
  VALUES (v_user, 'wallet_credit', 'C2 test wallet_credit off', 'body', false);
  SELECT count(*) INTO v_q FROM net.http_request_queue;
  IF v_q <> v_before THEN
    RAISE EXCEPTION 'wallet_credit could not be muted (queue % -> %)', v_before, v_q;
  END IF;

  -- 9) Signup seeds all 12 categories, promo off, everything else on.
  v_new := gen_random_uuid();
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password,
                          created_at, updated_at)
  VALUES (v_new, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'c2-seed-' || v_new || '@example.com', 'x', now(), now());
  SELECT count(*) INTO v_count FROM public.alert_settings WHERE user_id = v_new;
  IF v_count <> 12 THEN
    RAISE EXCEPTION 'signup seeded % alert_settings rows, expected 12', v_count;
  END IF;
  SELECT count(*) INTO v_count FROM public.alert_settings
   WHERE user_id = v_new AND is_enabled;
  IF v_count <> 11 THEN
    RAISE EXCEPTION 'signup seeded % enabled rows, expected 11 (promo off)', v_count;
  END IF;
  IF EXISTS (SELECT 1 FROM public.alert_settings
              WHERE user_id = v_new AND category = 'promo' AND is_enabled) THEN
    RAISE EXCEPTION 'promo must be off by default';
  END IF;

  -- 10) updated_at tracks changes — it is the consent timestamp for promo.
  UPDATE public.alert_settings SET updated_at = now() - interval '1 day'
   WHERE user_id = v_new AND category = 'promo';
  UPDATE public.alert_settings SET is_enabled = true
   WHERE user_id = v_new AND category = 'promo';
  IF (SELECT updated_at FROM public.alert_settings
       WHERE user_id = v_new AND category = 'promo') < now() - interval '1 minute' THEN
    RAISE EXCEPTION 'updated_at not bumped on change';
  END IF;

  RAISE NOTICE 'C2 alert-preference tests: all 10 assertions passed.';
END $$;

ROLLBACK;
