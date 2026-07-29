-- ============================================================================
-- F5: pin process_due_notifications' search_path
--
-- Finding F-5 (doc/PRODUCTION_PLAN_REVIEW.md § 1). Live get_advisors(security)
-- reports `function_search_path_mutable` for public.process_due_notifications:
-- it is the last SECURITY DEFINER function in this schema with no `SET
-- search_path`, so the schema resolution order is whatever the *caller's*
-- search_path happens to be. It runs from cron.job 7 as the table owner, so a
-- shadowing object in an earlier schema would be resolved with owner rights.
--
-- Every table reference in the body is already `public.`-qualified, and every
-- function it calls (NOW, clock_timestamp, to_char, COALESCE, jsonb_build_object)
-- lives in pg_catalog, which stays implicitly searchable even with an empty
-- search_path. So pinning to '' is a no-op for behaviour and closes the lint.
--
-- The body below is byte-identical to the deployed one apart from the SET.
--
-- NOT fixed here, deliberately — see doc/RLS_MATRIX.md § Accepted exceptions:
--   * security_definer_view on public.esim_offers and public.zendit_offers_cache
--     (2 advisor ERRORs) — these are the markup-isolation views. Their whole
--     purpose is to run with the definer's rights so a client can read retail
--     prices without reading the wholesale cost columns behind them. Making them
--     SECURITY INVOKER would expose supplier margin.
--   * rls_enabled_no_policy on esim_offers_cache, offline_refill_events,
--     rate_limit_buckets, retired_referral_codes, security_logs (5 advisor INFOs)
--     — deliberate deny-all tables. RLS on with zero policies is the intended
--     "service_role only" posture, not an oversight.
--   * extension_in_public on pg_net — Supabase-managed, and purge_deleted_accounts
--     calls net.http_post. Relocating it is a separate change, not a security fix.
--   * auth_leaked_password_protection — Dashboard-only setting, owner task.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.process_due_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  r RECORD;
  v_phone_number TEXT;
  v_next_due TIMESTAMPTZ;
BEGIN
  FOR r IN
    SELECT s.id, s.sim_line_id, s.user_id, s.amount, s.currency, s.frequency_days
    FROM public.scheduled_topups s
    WHERE s.is_active = true
      AND s.status = 'active'
      AND s.schedule_type = 'notify'
      AND s.next_execution_at <= NOW()
  LOOP
    SELECT phone_number INTO v_phone_number
    FROM public.sim_lines
    WHERE id = r.sim_line_id;

    INSERT INTO public.notifications (
      user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read, created_at
    ) VALUES (
      r.user_id, 'line_critical', 'Notify Renewal',
      'Your Phone Number (' || COALESCE(v_phone_number, '') || ') is due for recharge. Please top up at least $' || to_char(r.amount, 'FM99999990.00') || ' to keep it active.',
      '/sim_lines/' || r.sim_line_id, r.sim_line_id, ARRAY['push'::text], false, NOW()
    );

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, metadata, created_at
    ) VALUES (
      r.sim_line_id, r.user_id, 'reminder_sent',
      NULL,
      jsonb_build_object('amount', r.amount, 'schedule_type', 'notify'),
      clock_timestamp()
    );

    v_next_due := NOW() + (CASE WHEN r.frequency_days = 0 THEN INTERVAL '1 hour' ELSE r.frequency_days * INTERVAL '1 day' END);

    UPDATE public.scheduled_topups
    SET last_execution_at = NOW(),
        next_execution_at = v_next_due,
        retry_count = 0,
        whatsapp_sent_this_cycle = false,
        status = 'active',
        updated_at = NOW()
    WHERE id = r.id;
  END LOOP;
END;
$function$;

REVOKE ALL ON FUNCTION public.process_due_notifications() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_due_notifications() TO service_role;
