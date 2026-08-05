-- ============================================================================
-- I8b — the notification that tells a subscriber to go and do it themselves.
--
-- Two lines in this product cannot be kept alive by anything we sell:
--
--   * a `usage_required` carrier (MTN Syria, Syriatel, Vodafone Germany CallYa)
--     restarts its countdown on a call, an SMS or a data session. Credit is not
--     consumption. i7 already refuses to sell Premium on these — but refusing a
--     sale is not the same as telling the subscriber what WILL work.
--   * any line with no automation paid for. A free or Standard line is watched,
--     not refilled; the countdown still runs.
--
-- In both cases the useful advice is the same shape: buy the plan in the
-- operator's own app, in the number's home country. This emits that advice
-- through the ordinary notification pipeline, so it obeys the user's channel
-- switches, the per-category opt-in and the operator's channel catalogue like
-- everything else.
--
-- A new category rather than 'system': a subscriber who does not want to be
-- told to shop elsewhere must be able to mute exactly that without also muting
-- maintenance notices. It is NOT 'promo' — promo is marketing consent, off for
-- 8 of 8 users, and this is advice that frequently costs us the sale.
--
-- SHIPS DISABLED. `CARRIER_ADVICE_ENABLED` is false, per the owner's standing
-- pre-production instruction. p_dry_run deliberately ignores the flag, because
-- a dry run only reads: the owner can see exactly who would be told what, then
-- flip one row.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. The category. Both CHECKs, the seed function, and a backfill — a category
--    missing from any one of the three is a category the user cannot mute.
-- ---------------------------------------------------------------------------
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_category_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_category_check CHECK (
  category IN (
    'top_up_success', 'top_up_failed', 'wallet_low', 'wallet_depleted',
    'line_critical', 'line_entering_grace', 'geo_fence_triggered',
    'welcome_home_ready', 'referral_reward', 'system', 'wallet_credit',
    'promo', 'support', 'esim_low_data', 'carrier_action'
  )
);

ALTER TABLE public.alert_settings DROP CONSTRAINT IF EXISTS alert_settings_category_check;
ALTER TABLE public.alert_settings ADD CONSTRAINT alert_settings_category_check CHECK (
  category IN (
    'top_up_success', 'top_up_failed', 'wallet_low', 'wallet_depleted',
    'line_critical', 'line_entering_grace', 'geo_fence_triggered',
    'welcome_home_ready', 'referral_reward', 'system', 'wallet_credit',
    'promo', 'support', 'esim_low_data', 'carrier_action'
  )
);

CREATE OR REPLACE FUNCTION public.seed_default_alert_settings()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.alert_settings (user_id, category, is_enabled, channels)
  SELECT NEW.id,
         c.category,
         c.category <> 'promo',
         ARRAY['push','email','telegram','whatsapp']::text[]
  FROM unnest(ARRAY[
    'top_up_success','top_up_failed','wallet_low','wallet_depleted','line_critical',
    'line_entering_grace','geo_fence_triggered','welcome_home_ready','referral_reward',
    'system','wallet_credit','promo','support','esim_low_data','carrier_action'
  ]) AS c(category)
  ON CONFLICT (user_id, category) DO NOTHING;
  RETURN NEW;
END;
$function$;

-- Existing accounts. Without this the row only appears for users who sign up
-- after this migration, and Alert Preferences renders from alert_settings rows
-- — so the switch would be invisible to every current user.
INSERT INTO public.alert_settings (user_id, category, is_enabled, channels)
SELECT p.id, 'carrier_action', true, ARRAY['push','email','telegram','whatsapp']::text[]
FROM public.profiles p
ON CONFLICT (user_id, category) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Config, typed so the admin app can edit it.
-- ---------------------------------------------------------------------------
INSERT INTO public.system_configs (config_key, config_value)
VALUES
  ('CARRIER_ADVICE_ENABLED',       'false'),
  ('CARRIER_ADVICE_LEAD_DAYS',     '21'),
  ('CARRIER_ADVICE_COOLDOWN_DAYS', '45'),
  ('CARRIER_ADVICE_MAX_PER_RUN',   '200')
ON CONFLICT (config_key) DO NOTHING;

INSERT INTO public.system_config_meta
  (config_key, label, group_name, value_type, min_value, max_value, enum_options,
   unit, description, is_sensitive, is_readonly, sort_order)
VALUES
  ('CARRIER_ADVICE_ENABLED','Carrier self-service advice','Notifications','bool',NULL,NULL,NULL,NULL,
   'Master switch for the notification that tells a subscriber to top up in the operator''s own app. Ships off. Run emit_carrier_self_service_advice(true) first — a dry run ignores this switch and returns exactly who would be told what.',false,false,60),
  ('CARRIER_ADVICE_LEAD_DAYS','Carrier advice lead','Notifications','int',1,120,NULL,'days',
   'How far ahead of a line''s estimated deactivation date the advice is sent.',false,false,70),
  ('CARRIER_ADVICE_COOLDOWN_DAYS','Carrier advice cooldown','Notifications','int',1,365,NULL,'days',
   'Minimum gap between two pieces of advice about the same line. Longer than the forecast''s own lead, or a line that cannot be automated is nagged every cycle.',false,false,80),
  ('CARRIER_ADVICE_MAX_PER_RUN','Carrier advice batch cap','Notifications','int',1,5000,NULL,'lines',
   'Ceiling on notifications one run may send — the blast radius if a rule table is edited wrongly.',false,false,90)
ON CONFLICT (config_key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. The emitter.
--
-- No `WHEN OTHERS` handler, for the reason G1 spells out: a nightly job that
-- fails must appear in cron.job_run_details, not return a cheerful zero.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.emit_carrier_self_service_advice(
  p_dry_run boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  r             RECORD;
  v_enabled     boolean;
  v_lead        integer;
  v_cooldown    integer;
  v_max         integer;
  v_sent        integer := 0;
  v_no_date     integer := 0;
  v_considered  integer := 0;
  v_preview     jsonb   := '[]'::jsonb;
  v_label       text;
  v_reason      text;
  v_app         text;
  v_title       text;
  v_body        text;
  v_when        text;
  v_days        integer;
BEGIN
  v_enabled  := lower(COALESCE((SELECT config_value FROM public.system_configs
                                 WHERE config_key = 'CARRIER_ADVICE_ENABLED'), 'false')) = 'true';
  v_lead     := public.config_numeric('CARRIER_ADVICE_LEAD_DAYS',     21, 1, 120)::integer;
  v_cooldown := public.config_numeric('CARRIER_ADVICE_COOLDOWN_DAYS', 45, 1, 365)::integer;
  v_max      := public.config_numeric('CARRIER_ADVICE_MAX_PER_RUN',  200, 1, 5000)::integer;

  IF NOT v_enabled AND NOT p_dry_run THEN
    RETURN jsonb_build_object('enabled', false, 'sent', 0,
                              'note', 'CARRIER_ADVICE_ENABLED is false');
  END IF;

  FOR r IN
    SELECT sl.id                       AS sim_line_id,
           sl.user_id,
           sl.nickname,
           sl.phone_number,
           c.name                      AS carrier_name,
           co.name                     AS country_name,
           cr.activity_requirement,
           cr.inactivity_limit_days,
           cr.validity_qualifying_topup_amount,
           cr.inapp_pricing_currency,
           s.app_name,
           s.ussd_code,
           COALESCE(f.predicted_depletion_at,
                    sl.next_topup_due,
                    sl.validity_expires_at)          AS due_at,
           public.has_paid_premium_entitlement(sl.id) AS is_premium
    FROM public.sim_lines sl
    JOIN public.carriers      c  ON c.id  = sl.carrier_id
    JOIN public.countries     co ON co.id = c.country_id
    JOIN public.carrier_rules cr ON cr.carrier_id = c.id
    LEFT JOIN public.carrier_self_service s ON s.carrier_id = c.id
    LEFT JOIN public.sim_line_usage_forecast f ON f.sim_line_id = sl.id
    WHERE sl.status = 'active'
      AND COALESCE(sl.protection_paused, false) = false
      -- Cooldown read straight off `notifications`, not a new bookkeeping
      -- column: the notification IS the record, and a second copy of "when did
      -- we last say this" is a second thing to keep in step.
      AND NOT EXISTS (
        SELECT 1 FROM public.notifications n
        WHERE n.sim_line_id = sl.id
          AND n.category = 'carrier_action'
          AND n.created_at > now() - make_interval(days => v_cooldown)
      )
    ORDER BY COALESCE(f.predicted_depletion_at, sl.next_topup_due, sl.validity_expires_at)
             NULLS LAST
  LOOP
    -- Who is this actually for? A premium line on an ordinary carrier is
    -- already being refilled by us — telling its owner to go and buy elsewhere
    -- would be noise, and untrue.
    v_reason := CASE
                  WHEN r.activity_requirement = 'usage_required' THEN 'usage_required'
                  WHEN NOT r.is_premium                          THEN 'no_automation'
                  ELSE NULL
                END;
    CONTINUE WHEN v_reason IS NULL;

    -- No date means no honest way to time the advice. Counted rather than
    -- swallowed, so a carrier whose lines never get a forecast shows up as a
    -- number instead of as silence.
    IF r.due_at IS NULL THEN
      v_no_date := v_no_date + 1;
      CONTINUE;
    END IF;
    CONTINUE WHEN r.due_at > now() + make_interval(days => v_lead);

    EXIT WHEN v_sent >= v_max;
    v_considered := v_considered + 1;

    v_label := COALESCE(NULLIF(r.nickname, ''), r.phone_number, 'Your SIM line');
    v_days  := GREATEST(0, (r.due_at::date - now()::date));
    v_when  := CASE
                 WHEN v_days <= 0 THEN 'It is due now'
                 WHEN v_days  = 1 THEN 'It is due tomorrow'
                 ELSE 'It is due in ' || v_days || ' days'
               END;

    -- The app name is a hint, never a claim: carrier_self_service ships with
    -- verified_at NULL everywhere, so an unverified name is phrased as what to
    -- search for, and a missing one falls back to the carrier's own name.
    v_app := CASE
               WHEN r.app_name IS NOT NULL
                 THEN r.carrier_name || '''s official app (look for "' || r.app_name || '")'
               ELSE r.carrier_name || '''s official app'
             END;

    IF v_reason = 'usage_required' THEN
      v_title := 'Only you can keep ' || v_label || ' active';
      v_body  := r.carrier_name || ' restarts its ' || r.inactivity_limit_days
              || '-day countdown when the line makes a call, sends an SMS or uses data — '
              || 'adding credit does not count, so no automatic top-up can save this number. '
              || 'Buy a plan in ' || v_app || ' in ' || r.country_name
              || ' and use the line, or ask someone there to. ' || v_when || '.';
    ELSE
      v_title := 'Nothing is scheduled for ' || v_label;
      v_body  := r.carrier_name || ' deactivates a prepaid line after '
              || r.inactivity_limit_days || ' days without a qualifying top-up, and this '
              || 'line has no automatic refill paid for. Buy a plan in ' || v_app
              || ' in ' || r.country_name || ', or upgrade to Premium and we will do it for you.'
              || CASE
                   WHEN r.activity_requirement = 'min_denomination'
                        AND r.validity_qualifying_topup_amount IS NOT NULL
                     THEN ' Only a top-up of '
                          || to_char(r.validity_qualifying_topup_amount, 'FM99999990.00')
                          || ' ' || upper(COALESCE(r.inapp_pricing_currency, 'usd'))
                          || ' or more counts.'
                   ELSE ''
                 END
              || ' ' || v_when || '.';
    END IF;

    IF r.ussd_code IS NOT NULL THEN
      v_body := v_body || ' On the handset itself: dial ' || r.ussd_code || '.';
    END IF;

    IF p_dry_run THEN
      v_preview := v_preview || jsonb_build_object(
        'sim_line_id', r.sim_line_id,
        'carrier',     r.carrier_name,
        'reason',      v_reason,
        'due_at',      r.due_at,
        'title',       v_title,
        'body',        v_body
      );
      v_sent := v_sent + 1;
      CONTINUE;
    END IF;

    INSERT INTO public.notifications (
      user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read, created_at
    ) VALUES (
      r.user_id, 'carrier_action', v_title, v_body,
      '/sim_lines/' || r.sim_line_id, r.sim_line_id,
      ARRAY['push'::text], false, now()
    );

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, metadata, created_at
    ) VALUES (
      r.sim_line_id, r.user_id, 'reminder_sent', NULL,
      jsonb_build_object(
        'source',               'carrier_advice',
        'reason',               v_reason,
        'activity_requirement', r.activity_requirement,
        'due_at',               r.due_at
      ),
      clock_timestamp()
    );

    v_sent := v_sent + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'enabled',        v_enabled,
    'dry_run',        p_dry_run,
    'sent',           v_sent,
    'considered',     v_considered,
    'skipped_no_due_date', v_no_date,
    'lead_days',      v_lead,
    'cooldown_days',  v_cooldown,
    'preview',        CASE WHEN p_dry_run THEN v_preview ELSE NULL END
  );
END;
$$;

-- service_role only. This function reads every user's lines and writes to every
-- user's notifications; it must never appear on the F0 authenticated
-- allow-list.
REVOKE ALL ON FUNCTION public.emit_carrier_self_service_advice(boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.emit_carrier_self_service_advice(boolean) TO service_role;

COMMENT ON FUNCTION public.emit_carrier_self_service_advice(boolean) IS
  'I8b: advises a subscriber to buy their plan in the operator''s own home-country app, for lines nothing we sell can protect (usage_required) or that nobody has paid to automate. Gated on CARRIER_ADVICE_ENABLED, which ships false. p_dry_run ignores the flag and returns the exact copy each line would receive.';

-- 02:55 UTC: after refresh-usage-forecasts at 02:20 and refresh-offer-price-watch
-- at 02:40, because the due date this reads comes from that forecast. Running
-- before it would advise off yesterday's numbers — the same ordering mistake
-- that made G7 re-warn a line it had already rescued.
SELECT cron.unschedule('emit-carrier-self-service-advice')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'emit-carrier-self-service-advice');

SELECT cron.schedule(
  'emit-carrier-self-service-advice',
  '55 2 * * *',
  'SELECT public.emit_carrier_self_service_advice();'
);
