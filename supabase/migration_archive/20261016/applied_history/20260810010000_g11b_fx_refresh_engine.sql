-- ============================================================================
-- G11b — FX refresh engine
--
-- G11 shipped rates marked `rate_source = 'seed'`. Those are placeholders, and
-- by G11 decision 4 the whole feature switches itself off 72 hours after the
-- newest quote — so without this file G11 is a three-day feature. This is the
-- part that keeps it alive.
--
-- ── Five decisions worth not re-deriving ───────────────────────────────────
--
-- 1. THE APPLYING IS SQL, THE FETCHING IS THE EDGE FUNCTION. `refresh_fx_rates`
--    takes a jsonb of quotes and does all the deciding; `refresh-fx-rates`
--    (the Deno function) only knows how to talk HTTP to a rate provider. The
--    circuit breaker in `tr_fx_rate_sanity` is a database trigger, so putting
--    the writes anywhere else would route around it. Swapping providers later
--    touches only the Edge Function.
--
-- 2. THE FEED MAY UPDATE CURRENCIES, NEVER ADD THEM. The loop iterates over
--    `fx_rates`, not over the payload. `display_name`, `symbol` and
--    `decimal_digits` are curated by us and a provider has no business setting
--    them; open.er-api.com alone would otherwise inject ~160 rows into the
--    picker overnight. An unknown code in the payload is silently ignored.
--
-- 3. ONE BAD QUOTE MUST NOT LOSE THE OTHER THIRTEEN. Each currency is applied
--    in its own `BEGIN … EXCEPTION` subtransaction and its failure is *returned
--    in the report*, not swallowed — the same shape as G7's per-line isolation,
--    and deliberately not the fail-open `WHEN OTHERS THEN RAISE NOTICE` that F0
--    flagged. A rate the breaker refuses (KS460) appears under `refused` with
--    its reason, and the old value stays put and starts ageing toward the USD
--    fallback.
--
-- 4. `rate_as_of` COMES FROM THE PROVIDER, NOT FROM `now()`. Staleness is
--    measured from when the quote was *taken*. A provider that stops updating
--    but keeps serving its last payload would otherwise look permanently fresh
--    — which is precisely the lie G11 decision 4 exists to prevent. A payload
--    whose timestamp is older than the rate we already hold is ignored.
--
-- 5. NO SECURITY DEFINER ANYWHERE IN G11. This project has shipped a
--    `current_user`-inside-DEFINER guard that was dead code four separate times
--    (F4b). `refresh_fx_rates` is INVOKER and simply granted to `service_role`,
--    which already holds the table privileges and BYPASSRLS. The privilege
--    boundary is the grant, which cannot rot into a no-op.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 0. Correction to G11's circuit breaker: a placeholder is not a known-good
--    rate, and must never be defended as though it were.
--
-- The breaker exists to stop a broken feed from repainting a rate we trust. A
-- `seed` row is the opposite — a hand-typed guess we specifically want replaced
-- by the first real quote. Left as G11 wrote it the two rules deadlock: say the
-- EGP seed reads 50.5 and the true rate is 65, that is a 28.7% move, so the
-- breaker refuses it; a refused UPDATE changes nothing, so the row stays
-- `rate_source = 'seed'`, so tomorrow's run is refused identically, forever.
-- The placeholder would outlive every attempt to correct it and the currency
-- would sit on a wrong number until it aged into the USD fallback.
--
-- So the band applies only when there is something real to protect. The
-- numeric CHECK on `usd_to_local` still bounds the first quote.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.tr_fx_rate_sanity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_band     numeric;
  v_move_pct numeric;
BEGIN
  NEW.updated_at := now();

  -- A deliberate human correction is the escape hatch the band needs.
  IF NEW.rate_source = 'manual' THEN
    RETURN NEW;
  END IF;

  -- First real quote over a placeholder: always allowed (see above).
  IF OLD.rate_source = 'seed' THEN
    RETURN NEW;
  END IF;

  IF NEW.usd_to_local = OLD.usd_to_local THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(
           (SELECT NULLIF(config_value,'')::numeric
              FROM public.system_configs
             WHERE config_key = 'FX_MAX_MOVE_PERCENT'),
           25)
    INTO v_band;

  v_move_pct := abs(NEW.usd_to_local - OLD.usd_to_local) / OLD.usd_to_local * 100;

  IF v_move_pct > v_band THEN
    RAISE EXCEPTION
      'KS460: FX rate for % moved % pct (% -> %), outside the % pct band. '
      'Refusing — the stale rate will fall back to USD display. '
      'Set rate_source = ''manual'' to override deliberately.',
      NEW.currency_code, round(v_move_pct, 2), OLD.usd_to_local,
      NEW.usd_to_local, v_band
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;


-- ---------------------------------------------------------------------------
-- 1. Apply a batch of quotes.
--
-- `p_rates` is {"EGP": 50.4, "INR": 83.2, ...} — units of that currency per
-- USD, matching `fx_rates.usd_to_local`. Returns a report of every currency it
-- considered and what it did, because an automation that changes displayed
-- prices silently is not debuggable.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refresh_fx_rates(
  p_rates  jsonb,
  p_as_of  timestamptz,
  p_source text DEFAULT 'open.er-api.com'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  rec        record;
  v_new      numeric;
  v_applied  jsonb := '[]'::jsonb;
  v_refused  jsonb := '[]'::jsonb;
  v_skipped  jsonb := '[]'::jsonb;
BEGIN
  IF p_rates IS NULL OR jsonb_typeof(p_rates) <> 'object' THEN
    RAISE EXCEPTION 'KS462: refresh_fx_rates() needs a jsonb object of quotes.'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  IF p_as_of IS NULL OR p_as_of > now() + interval '1 hour' THEN
    RAISE EXCEPTION 'KS463: refresh_fx_rates() got an absent or future as_of (%).', p_as_of
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- Decision 2: drive off our catalogue, never off the payload.
  FOR rec IN
    SELECT currency_code, usd_to_local, rate_as_of, rate_source
      FROM public.fx_rates
     WHERE currency_code <> 'USD'
     ORDER BY currency_code
  LOOP
    v_new := NULL;
    BEGIN
      v_new := (p_rates ->> rec.currency_code)::numeric;
    EXCEPTION WHEN OTHERS THEN
      v_new := NULL;
    END;

    IF v_new IS NULL THEN
      v_skipped := v_skipped || jsonb_build_object(
        'code', rec.currency_code, 'reason', 'not in payload');
      CONTINUE;
    END IF;

    -- Decision 4: never move the clock backwards over a REAL quote.
    --
    -- The `rate_source = 'seed'` exemption is load-bearing, not a nicety. The
    -- G11 seed rows were written with `rate_as_of = now()` at migration time,
    -- while a daily provider stamps its payload at ~00:00 UTC — so a plain
    -- `p_as_of <= rate_as_of` test skips every currency on the first run and
    -- leaves the placeholders on screen until the provider's clock overtakes
    -- the migration's. A genuine quote always beats a placeholder.
    IF p_as_of <= rec.rate_as_of AND rec.rate_source <> 'seed' THEN
      v_skipped := v_skipped || jsonb_build_object(
        'code', rec.currency_code, 'reason', 'payload older than stored quote');
      CONTINUE;
    END IF;

    -- Decision 3: isolate. The breaker raises KS460 for an implausible move;
    -- the CHECK raises 23514 for an impossible one. Either way the currency is
    -- reported and the loop continues.
    BEGIN
      UPDATE public.fx_rates
         SET usd_to_local = v_new,
             rate_as_of   = p_as_of,
             rate_source  = p_source
       WHERE currency_code = rec.currency_code;

      v_applied := v_applied || jsonb_build_object(
        'code', rec.currency_code,
        'from', rec.usd_to_local,
        'to',   v_new);
    EXCEPTION WHEN OTHERS THEN
      v_refused := v_refused || jsonb_build_object(
        'code',    rec.currency_code,
        'kept',    rec.usd_to_local,
        'rejected', v_new,
        'sqlstate', SQLSTATE,
        'error',   left(SQLERRM, 200));
    END;
  END LOOP;

  -- An ops heartbeat in the same idiom as WORKER_ESIM_FULFILLMENT_HEARTBEAT, so
  -- "has the FX job been running?" is one SELECT and not a log dig.
  INSERT INTO public.system_configs (config_key, config_value, updated_at)
  VALUES ('FX_LAST_REFRESH_AT', to_jsonb(now())::text, now())
  ON CONFLICT (config_key)
  DO UPDATE SET config_value = EXCLUDED.config_value, updated_at = now();

  RETURN jsonb_build_object(
    'as_of',         p_as_of,
    'source',        p_source,
    'applied_count', jsonb_array_length(v_applied),
    'refused_count', jsonb_array_length(v_refused),
    'skipped_count', jsonb_array_length(v_skipped),
    'applied',       v_applied,
    'refused',       v_refused,
    'skipped',       v_skipped
  );
END;
$$;

-- Decision 5: the grant *is* the boundary. Clients cannot reach this at all.
REVOKE ALL ON FUNCTION public.refresh_fx_rates(jsonb, timestamptz, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_fx_rates(jsonb, timestamptz, text)
  TO service_role;

COMMENT ON FUNCTION public.refresh_fx_rates(jsonb, timestamptz, text) IS
  'G11b. Applies a batch of USD-based quotes to the curated fx_rates catalogue, '
  'one subtransaction per currency, and returns a full report of applied / '
  'refused / skipped. service_role only — called by the refresh-fx-rates Edge Function.';


-- ---------------------------------------------------------------------------
-- 2. The scheduled kick.
--
-- Same shape as every other outbound call in this schema (C1 / D3b / F3):
-- `net.http_post` with the Vault shared secret in `x-keep-sims-secret`, which
-- is what lets the Edge Function ship with verify_jwt disabled. Fire and
-- forget — the function does the work and writes its own heartbeat, so there
-- is no response for pg_net to hand back to anyone.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.kick_fx_refresh()
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_secret text;
BEGIN
  SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'dispatch_shared_secret' LIMIT 1;

  PERFORM net.http_post(
    url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/refresh-fx-rates',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-keep-sims-secret', COALESCE(v_secret, '')
    ),
    body := '{}'::jsonb
  );
END;
$$;

REVOKE ALL ON FUNCTION public.kick_fx_refresh() FROM PUBLIC, anon, authenticated;

-- 03:10 UTC daily: clear of the 02:20 forecast and 02:40 price-watch jobs, and
-- comfortably inside the 72h staleness window even if two runs in a row fail.
SELECT cron.unschedule('refresh-fx-rates')
 WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh-fx-rates');

SELECT cron.schedule('refresh-fx-rates', '10 3 * * *', 'SELECT public.kick_fx_refresh();');
