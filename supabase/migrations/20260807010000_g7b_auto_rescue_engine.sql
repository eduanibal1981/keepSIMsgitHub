-- ============================================================================
-- G7b — The auto-rescue engine, and the cron that runs it.
--
-- Split from G7 for the same reason G5b and G6b were split: everything here
-- spends money, and it should be reviewable — and revertible — on its own.
--
-- `run_auto_rescue()` is the first thing in this product that moves a user's
-- money with no human in the loop. Its guard list is the feature, not
-- decoration. In order, a line is rescued only when ALL of these hold:
--
--    1. `RESCUE_ENABLED` is true                       (global brake)
--    2. the line has a policy with `max_usd > 0`       (the owner opted in)
--    3. the line is `active` and not `protection_paused`
--    4. the owner is not suspended
--    5. G1's forecast says `days_remaining <= lead_days`
--    6. a warning was written at least `RESCUE_GRACE_HOURS` ago …
--    7. … and the user has not topped the line up since it
--    8. no refill is already queued or in flight for the line
--    9. the forecast names an offer, and that offer is live and < 24h stale
--   10. no rescue on this line inside `RESCUE_COOLDOWN_DAYS`
--   11. the POST-FEE charged amount is within `max_usd`
--   12. the wallet covers it
--
-- Anything short of all twelve produces a `skipped` row naming the reason. The
-- function returns its whole reasoning every run — an automation that spends
-- silently is not debuggable, and `p_dry_run => true` performs the entire
-- decision and spends nothing.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.run_auto_rescue(p_dry_run boolean DEFAULT false)
RETURNS TABLE (
  sim_line_id  uuid,
  line_label   text,
  action       text,      -- 'rescued' | 'warned' | 'skipped' | 'reset'
  reason       text,
  amount_usd   numeric,
  execution_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_claims        text;
  v_role          text;
  v_enabled       boolean;
  v_grace_hours   numeric;
  v_cooldown_days numeric;
  v_max_per_run   integer;
  v_spent         integer := 0;
  r               RECORD;
  v_offer         RECORD;
  v_base          numeric;
  v_value         bigint;
  v_exec_id       uuid;
  v_charged       numeric;
  v_label         text;
BEGIN
  -- The EXECUTE grant is service_role-only; this is the second layer, so a
  -- future re-grant cannot quietly open an unattended spender to a signed-in
  -- user. Guarded on the request JWT, never on `current_user` — inside
  -- SECURITY DEFINER that is the owner, which is how four dead guards shipped.
  v_claims := current_setting('request.jwt.claims', true);
  IF v_claims IS NOT NULL AND v_claims <> '' THEN
    v_role := (v_claims::jsonb) ->> 'role';
    IF v_role IS DISTINCT FROM 'service_role' THEN
      RAISE EXCEPTION 'run_auto_rescue is not callable by role %', COALESCE(v_role, '<none>')
        USING ERRCODE = 'KS403';
    END IF;
  END IF;

  SELECT COALESCE(NULLIF(config_value, ''), 'true')::boolean INTO v_enabled
    FROM public.system_configs WHERE config_key = 'RESCUE_ENABLED';
  v_enabled := COALESCE(v_enabled, true);

  IF NOT v_enabled THEN
    RETURN QUERY SELECT NULL::uuid, NULL::text, 'skipped'::text,
                        'RESCUE_ENABLED is false'::text, NULL::numeric, NULL::uuid;
    RETURN;
  END IF;

  SELECT COALESCE((SELECT NULLIF(config_value,'')::numeric FROM public.system_configs WHERE config_key='RESCUE_GRACE_HOURS'), 24)
    INTO v_grace_hours;
  SELECT COALESCE((SELECT NULLIF(config_value,'')::numeric FROM public.system_configs WHERE config_key='RESCUE_COOLDOWN_DAYS'), 20)
    INTO v_cooldown_days;
  SELECT COALESCE((SELECT NULLIF(config_value,'')::int FROM public.system_configs WHERE config_key='RESCUE_MAX_PER_RUN'), 25)
    INTO v_max_per_run;

  FOR r IN
    SELECT p.sim_line_id, p.user_id, p.max_usd, p.lead_days, p.warn_lead_days,
           p.last_warned_at, p.last_rescue_at,
           sl.nickname, sl.phone_number,
           f.days_remaining, f.predicted_depletion_at,
           f.suggested_offer_id, f.suggested_amount_usd,
           co.iso_code AS country_code, ca.zen_carrier,
           COALESCE(w.balance, 0) AS balance
    FROM public.sim_line_rescue_policy p
    JOIN public.sim_lines sl ON sl.id = p.sim_line_id
    JOIN public.profiles pr  ON pr.id = p.user_id
    LEFT JOIN public.sim_line_usage_forecast f
           ON f.sim_line_id = p.sim_line_id AND f.subject_kind = 'sim_line'
    LEFT JOIN public.countries co ON co.id = sl.country_id
    LEFT JOIN public.carriers  ca ON ca.id = sl.carrier_id
    LEFT JOIN public.wallets   w  ON w.user_id = p.user_id
    WHERE p.max_usd > 0
      AND sl.status = 'active'
      AND sl.protection_paused = false
      AND COALESCE(pr.is_suspended, false) = false
    ORDER BY f.days_remaining NULLS LAST
  LOOP
    v_label := COALESCE(NULLIF(r.nickname, ''), r.phone_number, r.sim_line_id::text);

    -- No forecast, no rescue. G1 is the only source of "how long has this line
    -- got" — `sim_lines.validity_expires_at` is NULL on every live row.
    IF r.days_remaining IS NULL THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          'no forecast for this line'::text, NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    -- ── Healthy again: clear the clock so the next cycle warns afresh. ──────
    IF r.days_remaining > r.lead_days + r.warn_lead_days THEN
      IF r.last_warned_at IS NOT NULL THEN
        IF NOT p_dry_run THEN
          UPDATE public.sim_line_rescue_policy SET last_warned_at = NULL
           WHERE sim_line_rescue_policy.sim_line_id = r.sim_line_id;
        END IF;
        RETURN QUERY SELECT r.sim_line_id, v_label, 'reset'::text,
                            format('%s days left; warning cleared', r.days_remaining),
                            NULL::numeric, NULL::uuid;
      END IF;
      CONTINUE;
    END IF;

    -- ── The user acted after we warned them. Stand down. ───────────────────
    IF r.last_warned_at IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.topup_executions te
      WHERE te.sim_line_id = r.sim_line_id
        AND te.status = 'success'
        AND te.created_at > r.last_warned_at
    ) THEN
      IF NOT p_dry_run THEN
        UPDATE public.sim_line_rescue_policy SET last_warned_at = NULL
         WHERE sim_line_rescue_policy.sim_line_id = r.sim_line_id;
      END IF;
      RETURN QUERY SELECT r.sim_line_id, v_label, 'reset'::text,
                          'user topped up after the warning'::text, NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    -- ── Cooldown. This has to sit ABOVE the warn phase, not below it.
    --
    -- A rescue clears `last_warned_at`, and the forecast does not refresh until
    -- 02:20, so on the very next hourly run the line still reads 1 day left
    -- with no warning on record — and the warn phase fired again, promising a
    -- top-up "in 24 hours" that the cooldown would then refuse. No double
    -- spend (proven: one execution), but a misleading notification an hour
    -- after we already fixed the problem. Caught by running the lifecycle
    -- twice instead of once. While a line is in cooldown, do nothing at all.
    IF r.last_rescue_at IS NOT NULL
       AND r.last_rescue_at > now() - make_interval(days => v_cooldown_days::int) THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('rescued already within %s days', v_cooldown_days::int),
                          NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    -- ── Warn phase, and the floor under the rescue phase. A line is never
    --    rescued without a warning on the record first. ────────────────────
    IF r.last_warned_at IS NULL THEN
      IF NOT p_dry_run THEN
        INSERT INTO public.notifications (user_id, category, title, body, action_url, sim_line_id)
        VALUES (
          r.user_id, 'line_critical',
          format('%s needs a top-up', v_label),
          format('About %s day(s) of validity left. SIM Shield will top it up automatically in %s hour(s) if you do not — up to $%s.',
                 GREATEST(r.days_remaining, 0), v_grace_hours::int, to_char(r.max_usd, 'FM999990.00')),
          '/sim-lines/' || r.sim_line_id::text,
          r.sim_line_id
        );
        UPDATE public.sim_line_rescue_policy SET last_warned_at = now()
         WHERE sim_line_rescue_policy.sim_line_id = r.sim_line_id;
      END IF;
      RETURN QUERY SELECT r.sim_line_id, v_label, 'warned'::text,
                          format('%s days left; grace starts now', r.days_remaining),
                          NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF r.days_remaining > r.lead_days THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('warned; %s days left, rescue at %s', r.days_remaining, r.lead_days),
                          NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF now() - r.last_warned_at < make_interval(hours => v_grace_hours::int) THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('inside the %s-hour grace window', v_grace_hours::int),
                          NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.topup_executions te
      WHERE te.sim_line_id = r.sim_line_id
        AND te.status IN ('pending', 'pending_payment', 'routing', 'processing')
    ) THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          'a refill is already in flight'::text, NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF v_spent >= v_max_per_run THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('run capped at %s rescues', v_max_per_run), NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF r.suggested_offer_id IS NULL OR r.zen_carrier IS NULL THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          'no top-up offer known for this line'::text, NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    SELECT * INTO v_offer
    FROM public.zendit_offers_cache z
    WHERE z.offer_id = r.suggested_offer_id
      AND z.country_code = r.country_code
      AND z.zen_carrier = r.zen_carrier;

    IF NOT FOUND OR v_offer.refreshed_at < now() - interval '24 hours' THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('offer %s unavailable or stale', r.suggested_offer_id),
                          NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    -- Same pricing arithmetic as request_instant_refill. Duplicated rather
    -- than shared because that function is SECURITY DEFINER on auth.uid() and
    -- there is no caller here.
    IF v_offer.price_type = 'FIXED' THEN
      v_base  := v_offer.price_fixed_usd;
      v_value := NULL;
    ELSE
      v_base := round(COALESCE(r.suggested_amount_usd, v_offer.price_min_usd), 2);
      v_base := LEAST(GREATEST(v_base, v_offer.price_min_usd), v_offer.price_max_usd);
      v_value := least(v_offer.send_max, greatest(v_offer.send_min, round(
        v_offer.send_min
        + CASE WHEN v_offer.price_max_usd - v_offer.price_min_usd > 0
               THEN (v_base - v_offer.price_min_usd)
                    * (v_offer.send_max - v_offer.send_min)
                    / (v_offer.price_max_usd - v_offer.price_min_usd)
               ELSE 0 END)));
    END IF;

    IF v_base IS NULL OR v_base <= 0 THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          'offer has no usable price'::text, NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF v_base > r.max_usd THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('cheapest top-up $%s is over the $%s limit',
                                 to_char(v_base, 'FM999990.00'), to_char(r.max_usd, 'FM999990.00')),
                          v_base, NULL::uuid;
      CONTINUE;
    END IF;

    IF r.balance < v_base THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('wallet has $%s, needs $%s',
                                 to_char(r.balance, 'FM999990.00'), to_char(v_base, 'FM999990.00')),
                          v_base, NULL::uuid;
      CONTINUE;
    END IF;

    IF p_dry_run THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'rescued'::text,
                          format('DRY RUN: would buy %s for $%s',
                                 r.suggested_offer_id, to_char(v_base, 'FM999990.00')),
                          v_base, NULL::uuid;
      v_spent := v_spent + 1;
      CONTINUE;
    END IF;

    -- ── Spend. Per-line subtransaction: a failure here unwinds this line's
    --    INSERT and the activity row its AFTER INSERT trigger already wrote,
    --    and leaves every other line in the run untouched. ─────────────────
    BEGIN
      INSERT INTO public.topup_executions (
        sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code,
        currency, status, execution_type, execution_time, offer_id, offer_value
      ) VALUES (
        r.sim_line_id, r.user_id, v_base, v_base, 'wallet',
        'USD', 'pending', 'refill_instant', now(), r.suggested_offer_id, v_value
      )
      RETURNING id, amount INTO v_exec_id, v_charged;

      -- tr_calculate_topup_fees has now added the app fee, and `amount` — not
      -- `base_cost_usd` — is what worker_instant_refill.js debits. Checking the
      -- offer price alone would let every rescue overrun its limit by the fee.
      IF v_charged > r.max_usd THEN
        RAISE EXCEPTION 'RESCUE_OVER_CAP:%:%', v_charged, r.max_usd USING ERRCODE = 'KS402';
      END IF;

      IF v_charged > r.balance THEN
        RAISE EXCEPTION 'RESCUE_NO_FUNDS:%:%', v_charged, r.balance USING ERRCODE = 'KS402';
      END IF;

      -- The event the C6 canon has had a slot for since 2026-07-22.
      INSERT INTO public.line_activity_log (sim_line_id, user_id, event_type, description, metadata)
      VALUES (
        r.sim_line_id, r.user_id, 'rescue_topup_triggered',
        format('SIM Shield auto-topped up $%s to keep this line alive', to_char(v_charged, 'FM999990.00')),
        jsonb_build_object(
          'execution_id', v_exec_id,
          'offer_id', r.suggested_offer_id,
          'base_cost_usd', v_base,
          'charged_usd', v_charged,
          'max_usd', r.max_usd,
          'days_remaining', r.days_remaining,
          'warned_at', r.last_warned_at,
          'grace_hours', v_grace_hours
        )
      );

      INSERT INTO public.notifications (user_id, category, title, body, action_url, sim_line_id)
      VALUES (
        r.user_id, 'system',
        format('SIM Shield rescued %s', v_label),
        format('You had about %s day(s) left and had not topped up, so we spent $%s from your wallet to keep the line alive. Switch this off any time in the line''s settings.',
               GREATEST(r.days_remaining, 0), to_char(v_charged, 'FM999990.00')),
        '/sim-lines/' || r.sim_line_id::text,
        r.sim_line_id
      );

      UPDATE public.sim_line_rescue_policy
         SET last_rescue_at = now(),
             last_rescue_execution_id = v_exec_id,
             rescue_count = rescue_count + 1,
             last_warned_at = NULL
       WHERE sim_line_rescue_policy.sim_line_id = r.sim_line_id;

      v_spent := v_spent + 1;

      RETURN QUERY SELECT r.sim_line_id, v_label, 'rescued'::text,
                          format('bought %s, charged $%s of a $%s limit',
                                 r.suggested_offer_id, to_char(v_charged, 'FM999990.00'),
                                 to_char(r.max_usd, 'FM999990.00')),
                          v_charged, v_exec_id;

    EXCEPTION
      -- Deliberate per-line isolation, NOT a fail-open catch-all: the SQLSTATE
      -- and message are returned in this line's row, so nothing is hidden the
      -- way enforce_rate_limit's `WHEN OTHERS THEN RAISE NOTICE` hides things.
      WHEN OTHERS THEN
        RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                            format('%s %s', SQLSTATE, left(SQLERRM, 120)),
                            v_base, NULL::uuid;
    END;
  END LOOP;

  RETURN;
END $fn$;

COMMENT ON FUNCTION public.run_auto_rescue(boolean) IS
  'G7: SIM insurance. Warns, waits RESCUE_GRACE_HOURS, then spends the minimum viable top-up from the owner''s wallet for lines they insured. service_role only. Returns one row per line considered, including every refusal; p_dry_run => true decides everything and spends nothing.';

REVOKE ALL     ON FUNCTION public.run_auto_rescue(boolean) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.run_auto_rescue(boolean) TO service_role;


-- ---------------------------------------------------------------------------
-- The clock. Hourly at :50, clear of the 02:20 forecast refresh (G1) and the
-- 02:40 price watch (G2) so a rescue always reads a settled forecast.
-- ---------------------------------------------------------------------------
SELECT cron.unschedule('run-auto-rescue')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'run-auto-rescue');

SELECT cron.schedule('run-auto-rescue', '50 * * * *', 'SELECT public.run_auto_rescue();');
