-- Task 21: preserve the existing active-request-only response contract.
-- fulfilled/cancelled/history and no request all project request:null.
-- No feature flags, request/grant mutations, stock or recovery endpoint changes.
BEGIN;

CREATE OR REPLACE FUNCTION "public"."offline_voucher_state"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_enabled boolean;
  v_lines   jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED');
  END IF;

  SELECT COALESCE(NULLIF(config_value, ''), 'false')::boolean INTO v_enabled
    FROM public.system_configs WHERE config_key = 'OFFLINE_VOUCHER_ENABLED';

  SELECT COALESCE(jsonb_agg(x ORDER BY x ->> 'phone_number'), '[]'::jsonb)
    INTO v_lines
    FROM (
      SELECT jsonb_build_object(
               'sim_line_id',  sl.id,
               'phone_number', sl.phone_number,
               'nickname',     sl.nickname,
               'carrier_id',   sl.carrier_id,
               'carrier_name', c.name,
               'plan_type',    sl.plan_type,
               'entitled',     (sl.plan_type IN ('premium', 'standard') OR public.has_paid_premium_entitlement(sl.id)),
               'is_premium',   (sl.plan_type = 'premium' OR public.has_paid_premium_entitlement(sl.id)),
               'grant', CASE WHEN g.id IS NULL THEN NULL ELSE jsonb_build_object(
                          'id',              g.id,
                          'status',          g.status,
                          'amount_due_usd',  g.amount_due_usd,
                          'face_value_usd',  s.face_value_usd,
                          'revealed_at',     g.revealed_at,
                          'provisioned_at',  g.provisioned_at,
                          'expires_at',      g.expires_at
                        ) END,
               'request', CASE WHEN r.id IS NULL THEN NULL ELSE jsonb_build_object(
                            'due_at', r.due_at,
                            'reason', r.reason
                          ) END,
               'stock_available', (
                 SELECT count(*) > 0
                   FROM public.offline_voucher_stock st
                  WHERE st.carrier_id = sl.carrier_id
                    AND st.status = 'available'
                    AND (st.expires_at IS NULL OR st.expires_at > now() + interval '7 days')
               ),
               'carrier_redemption', CASE WHEN cr.carrier_id IS NULL THEN NULL ELSE jsonb_build_object(
                 'instructions', cr.instructions,
                 'redeem_ussd_template', CASE WHEN cr.verified_at IS NOT NULL THEN cr.redeem_ussd_template END
               ) END
             ) AS x
        FROM public.sim_lines sl
        LEFT JOIN public.carriers c ON c.id = sl.carrier_id
        LEFT JOIN public.offline_voucher_grants g
               ON g.sim_line_id = sl.id
              AND g.user_id = v_uid
              AND g.status IN ('provisioned', 'revealed')
        LEFT JOIN public.offline_voucher_stock s ON s.id = g.stock_id
        LEFT JOIN public.offline_voucher_requests r
               ON r.sim_line_id = sl.id
              AND r.user_id = v_uid
              AND r.status = 'open'
        LEFT JOIN public.carrier_voucher_redemption cr ON cr.carrier_id = sl.carrier_id
       WHERE sl.user_id = v_uid
    ) rows;

  RETURN jsonb_build_object(
    'success', true,
    'enabled', COALESCE(v_enabled, false),
    'lines', v_lines
  );
END;
$$;

-- Explicit customer read API; existing service callers still need an owner uid.
REVOKE ALL ON FUNCTION public.offline_voucher_state() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.offline_voucher_state() TO authenticated, service_role;
COMMIT;
