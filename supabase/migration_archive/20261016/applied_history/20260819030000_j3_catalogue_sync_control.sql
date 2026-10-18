-- J3 — catalogue sync control: a cron schedule and an admin trigger.
--
-- The `sync-esim-catalogue` Edge Function is the only implementation; these are
-- two ways to call it. Both read the shared secret from Vault so it never
-- appears in a cron command, a migration, or the admin app.
--
-- Why an Edge Function rather than the pm2 worker that already does this:
-- `servers/worker_esim_catalog.js` lives on the owner-gated VM, so a catalogue
-- fix could not reach production without a manual deploy. Both write the same
-- rows on the same conflict key.

BEGIN;

CREATE OR REPLACE FUNCTION public.kick_esim_catalogue_sync()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_secret text;
  v_req_id bigint;
BEGIN
  SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'esim_catalogue_sync_secret';

  IF COALESCE(v_secret, '') = '' THEN
    -- Fail loudly. A silent no-op here means the catalogue quietly stops
    -- refreshing and nobody notices until prices are months old.
    RAISE EXCEPTION 'esim_catalogue_sync_secret missing from Vault' USING ERRCODE = 'KS500';
  END IF;

  SELECT net.http_post(
    url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/sync-esim-catalogue',
    headers := jsonb_build_object('Content-Type','application/json','x-sync-secret', v_secret),
    body := '{}'::jsonb,
    -- 28 pages of upstream fetch plus 5,412 upserts. The observed run is well
    -- under this; a short timeout would abandon a sync that then completes
    -- anyway and looks like a failure.
    timeout_milliseconds := 180000
  ) INTO v_req_id;

  RETURN v_req_id;
END;
$fn$;

REVOKE ALL ON FUNCTION public.kick_esim_catalogue_sync() FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kick_esim_catalogue_sync() TO service_role;

-- Admin-triggered sync, for a "Refresh catalogue now" button in keep_sims_admin.
-- assert_admin() raises on a *missing* identity, which is the shape F4b's four
-- dead guards got wrong by falling open when auth.uid() was NULL.
CREATE OR REPLACE FUNCTION public.admin_sync_esim_catalogue(p_note text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_req_id bigint;
BEGIN
  PERFORM public.assert_admin();

  v_req_id := public.kick_esim_catalogue_sync();

  INSERT INTO public.admin_audit_log (actor_id, action, target_type, target_id, after_value, note)
  VALUES (auth.uid(), 'esim_catalogue_sync', 'esim_supplier', 'esim_go',
          jsonb_build_object('request_id', v_req_id), p_note);

  -- pg_net is asynchronous: this returns once the request is QUEUED, not once
  -- the catalogue is loaded. The caller polls esim_suppliers.last_sync_* for
  -- the outcome, so the UI must not claim success on this return alone.
  RETURN jsonb_build_object('success', true, 'queued', true, 'request_id', v_req_id);
END;
$fn$;

REVOKE ALL ON FUNCTION public.admin_sync_esim_catalogue(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_sync_esim_catalogue(text) TO authenticated;

-- 03:40 UTC: after the 03:10 FX refresh, and clear of the 02:20/02:40/02:55
-- overnight chain so a 28-page upstream fetch is not competing with them.
SELECT cron.schedule('sync-esim-catalogue', '40 3 * * *',
                     'SELECT public.kick_esim_catalogue_sync();');

COMMIT;
