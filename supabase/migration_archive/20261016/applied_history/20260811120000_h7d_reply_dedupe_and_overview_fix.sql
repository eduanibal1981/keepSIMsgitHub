-- ============================================================================
-- H7d — two defects found by RUNNING H7a/H7c rather than reading them.
--
-- 1. DOUBLE NOTIFICATION. C7 already ships trg_fn_support_ticket_messages_process
--    on ticket_messages: on a sender='admin' row it sets the ticket to 'pending'
--    AND inserts a 'support' notification. admin_reply_ticket inserted a second
--    one, so a single support reply queued TWO dispatches — proven, the
--    net.http_request_queue went 0 -> 2 on one reply. This is C1's dedupe loop
--    repeating: one user action, two pushes. The trigger owns the notification;
--    the RPC must not.
--
--    The status UPDATE stays. It runs after the trigger has already moved the
--    ticket to 'pending', so COALESCE(p_new_status, status) either honours the
--    agent's explicit choice or leaves the trigger's 'pending' in place.
--
-- 2. A MISLEADING METRIC — see the header of h7c for the full account.
--    esim_covered_countries now counts supported countries that have at least
--    one bundle (4 of 21), not distinct country codes across all bundles (50).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_reply_ticket(
  p_ticket_id  uuid,
  p_message    text,
  p_new_status text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_ticket RECORD;
  v_msg_id uuid;
BEGIN
  PERFORM public.assert_admin();

  IF p_message IS NULL OR length(btrim(p_message)) < 2 THEN
    RAISE EXCEPTION 'A reply needs a message' USING ERRCODE = 'KS464';
  END IF;

  IF p_new_status IS NOT NULL AND p_new_status NOT IN ('open','pending','resolved','closed') THEN
    RAISE EXCEPTION 'Status must be open, pending, resolved or closed' USING ERRCODE = 'KS466';
  END IF;

  SELECT * INTO v_ticket FROM public.support_tickets WHERE id = p_ticket_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ticket % not found', p_ticket_id USING ERRCODE = 'KS461';
  END IF;

  -- user_id here is the ticket OWNER, not the author; `sender` is what
  -- distinguishes them, and the user's SELECT policy joins through
  -- support_tickets on the owner. Writing the agent's id would hide the reply
  -- from the person it is addressed to.
  --
  -- Inserting this row is also what notifies the user: C7's
  -- trg_fn_support_ticket_messages_process fires on it. Do not add a second
  -- notifications INSERT here.
  INSERT INTO public.ticket_messages (ticket_id, user_id, sender, message)
  VALUES (p_ticket_id, v_ticket.user_id, 'admin', btrim(p_message))
  RETURNING id INTO v_msg_id;

  UPDATE public.support_tickets
  SET status = COALESCE(p_new_status, status), updated_at = now()
  WHERE id = p_ticket_id;

  PERFORM public.admin_log('ticket.reply', 'support_ticket', p_ticket_id::text,
    jsonb_build_object('status', v_ticket.status),
    jsonb_build_object('status', COALESCE(p_new_status, 'pending'), 'message_id', v_msg_id),
    left(btrim(p_message), 200));

  RETURN jsonb_build_object('success', true, 'message_id', v_msg_id,
    'status', (SELECT status FROM public.support_tickets WHERE id = p_ticket_id));
END;
$$;

REVOKE ALL ON FUNCTION public.admin_reply_ticket(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_reply_ticket(uuid,text,text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_overview()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE v jsonb;
BEGIN
  PERFORM public.assert_admin();

  SELECT jsonb_build_object(
    'generated_at', now(),
    'users', jsonb_build_object(
      'total',     (SELECT count(*) FROM public.profiles),
      'suspended', (SELECT count(*) FROM public.profiles WHERE is_suspended),
      'power',     (SELECT count(*) FROM public.profiles WHERE is_power_user),
      'new_7d',    (SELECT count(*) FROM public.profiles WHERE created_at > now() - interval '7 days')),
    'money', jsonb_build_object(
      'wallet_balance_total', (SELECT COALESCE(sum(balance),0) FROM public.wallets),
      'deposited_30d',        (SELECT COALESCE(sum(amount),0) FROM public.wallet_transactions
                                WHERE type='deposit' AND status='completed'
                                  AND created_at > now() - interval '30 days'),
      'spent_30d',            (SELECT COALESCE(sum(amount),0) FROM public.wallet_transactions
                                WHERE type IN ('topup_debit','plan_fee_debit','esim_purchase_debit')
                                  AND status='completed' AND created_at > now() - interval '30 days'),
      'app_fee_30d',          (SELECT COALESCE(sum(app_fee_usd),0) FROM public.topup_executions
                                WHERE status='success' AND created_at > now() - interval '30 days')),
    'queue', jsonb_build_object(
      -- The four non-terminal statuses, spelled out. G6 lost time to a filter of
      -- ('pending','processing') that counted nothing, because
      -- route_topup_execution() rewrites a new instant refill to 'routing' in a
      -- BEFORE INSERT trigger.
      'in_flight',  (SELECT count(*) FROM public.topup_executions
                      WHERE status IN ('pending','pending_payment','routing','processing')),
      'stuck_24h',  (SELECT count(*) FROM public.topup_executions
                      WHERE status IN ('pending','pending_payment','routing','processing')
                        AND created_at < now() - interval '24 hours'),
      'failed_7d',  (SELECT count(*) FROM public.topup_executions
                      WHERE status IN ('failed','refunded') AND created_at > now() - interval '7 days'),
      'success_7d', (SELECT count(*) FROM public.topup_executions
                      WHERE status='success' AND created_at > now() - interval '7 days'),
      'manual_waiting', (SELECT count(*) FROM public.topup_executions
                          WHERE fulfillment_gateway='MANUAL'
                            AND status IN ('pending','pending_payment','routing','processing'))),
    'routing', jsonb_build_object(
      'carriers_total',   (SELECT count(*) FROM public.carriers),
      'carriers_api',     (SELECT count(*) FROM public.carriers WHERE fulfillment_gateway='API'),
      'carriers_manual',  (SELECT count(*) FROM public.carriers WHERE fulfillment_gateway<>'API'),
      'api_without_provider', (SELECT count(*) FROM public.carriers
                                WHERE fulfillment_gateway='API' AND api_provider IS NULL),
      'carriers_without_offers', (SELECT count(*) FROM public.carriers ca
                                   JOIN public.countries co ON co.id = ca.country_id
                                   WHERE ca.fulfillment_gateway = 'API'
                                     AND NOT EXISTS (
                                       SELECT 1 FROM public.provider_offers_cache p
                                       WHERE p.country_code = co.iso_code
                                         AND p.api_provider = COALESCE(ca.api_provider::text,'zendit')
                                         AND p.carrier_code = CASE COALESCE(ca.api_provider::text,'zendit')
                                                                WHEN 'ding'  THEN ca.ding_carrier::text
                                                                WHEN 'dtone' THEN ca.dt_carrier::text
                                                                ELSE ca.zen_carrier::text END)),
      'default_gateway',  (SELECT config_value FROM public.system_configs
                            WHERE config_key='ACTIVE_FULFILLMENT_METHOD')),
    'catalogue', jsonb_build_object(
      'topup_offers',        (SELECT count(*) FROM public.provider_offers_cache),
      'topup_offers_stale',  (SELECT count(*) FROM public.provider_offers_cache
                               WHERE refreshed_at < now() - interval '24 hours'),
      'esim_bundles',        (SELECT count(*) FROM public.esim_offers_cache WHERE is_active),
      -- Supported countries a user can actually buy an eSIM for, not every
      -- country a regional bundle happens to roam in.
      'esim_covered_countries', (SELECT count(*) FROM public.countries c
                                  WHERE EXISTS (SELECT 1 FROM public.esim_offers_cache e
                                                WHERE e.is_active AND c.iso_code = ANY (e.countries))),
      'supported_countries', (SELECT count(*) FROM public.countries)),
    'notifications', jsonb_build_object(
      'channels_enabled', (SELECT count(*) FROM public.notification_channel_catalog WHERE is_globally_enabled),
      'channels_total',   (SELECT count(*) FROM public.notification_channel_catalog),
      'credential_gaps',  (SELECT COALESCE(array_agg(channel_key ORDER BY channel_key), '{}')
                            FROM public.notification_channel_catalog WHERE credential_status <> 'configured'),
      'delivered_7d',     (SELECT count(*) FROM public.notification_deliveries
                            WHERE status IN ('sent','success','delivered') AND created_at > now() - interval '7 days'),
      'failed_7d',        (SELECT count(*) FROM public.notification_deliveries
                            WHERE status='failed' AND created_at > now() - interval '7 days'),
      'push_tokens',      (SELECT count(*) FROM public.device_push_tokens)),
    'support', jsonb_build_object(
      'open',           (SELECT count(*) FROM public.support_tickets WHERE status NOT IN ('resolved','closed')),
      'awaiting_reply', (SELECT count(*) FROM public.support_tickets t
                          WHERE t.status NOT IN ('resolved','closed')
                            AND COALESCE((SELECT (array_agg(tm.sender ORDER BY tm.created_at DESC))[1]
                                          FROM public.ticket_messages tm WHERE tm.ticket_id=t.id), 'user') = 'user')),
    'alerts', COALESCE((SELECT jsonb_agg(jsonb_build_object(
                 'id', sa.id, 'kind', sa.kind, 'message', sa.message, 'created_at', sa.created_at)
                 ORDER BY sa.created_at DESC)
               FROM (SELECT * FROM public.system_alerts ORDER BY created_at DESC LIMIT 10) sa), '[]'::jsonb),
    'workers', jsonb_build_object(
      'esim_heartbeat', (SELECT config_value FROM public.system_configs
                          WHERE config_key='WORKER_ESIM_FULFILLMENT_HEARTBEAT'),
      'fx_last_refresh',(SELECT config_value FROM public.system_configs
                          WHERE config_key='FX_LAST_REFRESH_AT'),
      'cron_jobs',      (SELECT count(*) FROM cron.job WHERE active))
  ) INTO v;

  RETURN v;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_overview() TO authenticated, service_role;
