-- J5 — affiliate conversion reader: schedule and admin trigger.
--
-- Pairs with the `sync-affiliate-network` Edge Function. Without it the rail
-- records clicks and never learns what they earned.

BEGIN;

CREATE OR REPLACE FUNCTION public.kick_affiliate_sync(p_since_days integer DEFAULT 45)
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
    FROM vault.decrypted_secrets WHERE name = 'affiliate_sync_secret';
  IF COALESCE(v_secret, '') = '' THEN
    RAISE EXCEPTION 'affiliate_sync_secret missing from Vault' USING ERRCODE = 'KS500';
  END IF;

  SELECT net.http_post(
    url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/sync-affiliate-network',
    headers := jsonb_build_object('Content-Type','application/json','x-sync-secret', v_secret),
    body := jsonb_build_object('since_days', LEAST(GREATEST(COALESCE(p_since_days,45),1),365)),
    timeout_milliseconds := 120000
  ) INTO v_req_id;

  RETURN v_req_id;
END;
$fn$;

REVOKE ALL ON FUNCTION public.kick_affiliate_sync(integer) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kick_affiliate_sync(integer) TO service_role;

CREATE OR REPLACE FUNCTION public.admin_sync_affiliate_network(
  p_since_days integer DEFAULT 45,
  p_note       text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_req_id bigint;
BEGIN
  PERFORM public.assert_admin();
  v_req_id := public.kick_affiliate_sync(p_since_days);

  INSERT INTO public.admin_audit_log (actor_id, action, target_type, target_id, after_value, note)
  VALUES (auth.uid(), 'affiliate_network_sync', 'affiliate_network', 'all',
          jsonb_build_object('request_id', v_req_id, 'since_days', p_since_days), p_note);

  -- pg_net is asynchronous: queued, not finished. The caller reads
  -- admin_affiliate_overview() afterwards for the outcome.
  RETURN jsonb_build_object('success', true, 'queued', true, 'request_id', v_req_id);
END;
$fn$;

REVOKE ALL ON FUNCTION public.admin_sync_affiliate_network(integer,text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_sync_affiliate_network(integer,text) TO authenticated;

-- 04:10 UTC, after the 03:40 catalogue sync. A 45-day look-back every night is
-- deliberate over-fetch: Impact restates an action's status for weeks after the
-- sale (PENDING -> APPROVED -> REVERSED), and the upsert is idempotent on
-- (network_code, external_action_id), so re-reading is how a reversal is ever
-- noticed. Fetching only new actions would leave the ledger permanently
-- optimistic. 45 is also Impact's own hard maximum for a single date span.
SELECT cron.schedule('sync-affiliate-network', '10 4 * * *',
                     'SELECT public.kick_affiliate_sync(45);');

COMMIT;
