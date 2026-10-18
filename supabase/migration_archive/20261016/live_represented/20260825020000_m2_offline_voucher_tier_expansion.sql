-- Migration: 20260825020000_m2_offline_voucher_tier_expansion.sql
-- Expands offline emergency recharge voucher privileges to both Premium and Standard plans.

BEGIN;

-- 1. Enable OFFLINE_VOUCHER_ENABLED in system_configs if not already set
INSERT INTO public.system_configs (config_key, config_value)
VALUES ('OFFLINE_VOUCHER_ENABLED', 'true')
ON CONFLICT (config_key) DO UPDATE SET config_value = 'true';

-- 2. Update provision_offline_voucher to permit Standard and Premium tiers
CREATE OR REPLACE FUNCTION public.provision_offline_voucher(
  p_sim_line_id uuid,
  p_device_id   text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_uid       uuid := auth.uid();
  v_enabled   boolean;
  v_line      RECORD;
  v_grant     RECORD;
  v_stock     RECORD;
  v_validity  integer;
  v_due       timestamptz;
  v_source    text;
  v_redeem    RECORD;
  v_reuse     boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED');
  END IF;

  SELECT COALESCE(NULLIF(config_value, ''), 'false')::boolean INTO v_enabled
    FROM public.system_configs WHERE config_key = 'OFFLINE_VOUCHER_ENABLED';
  IF NOT COALESCE(v_enabled, false) THEN
    RETURN jsonb_build_object('success', false, 'code', 'FEATURE_OFF');
  END IF;

  PERFORM public.enforce_rate_limit('voucher_provision', v_uid::text);

  SELECT sl.id, sl.user_id, sl.carrier_id, sl.phone_number, sl.plan_type
    INTO v_line
    FROM public.sim_lines sl
   WHERE sl.id = p_sim_line_id AND sl.user_id = v_uid;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'code', 'LINE_NOT_FOUND');
  END IF;

  IF v_line.carrier_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'NO_CARRIER');
  END IF;

  -- ── An existing grant decides the answer before any stock is touched ──────
  SELECT g.*, s.expires_at AS stock_expires_at
    INTO v_grant
    FROM public.offline_voucher_grants g
    JOIN public.offline_voucher_stock s ON s.id = g.stock_id
   WHERE g.sim_line_id = p_sim_line_id
     AND g.status IN ('provisioned', 'revealed')
   FOR UPDATE OF g;

  IF FOUND THEN
    IF v_grant.status = 'revealed' THEN
      RETURN jsonb_build_object(
        'success', false,
        'code', 'SETTLEMENT_DUE',
        'grant_id', v_grant.id,
        'amount_due_usd', v_grant.amount_due_usd,
        'revealed_at', v_grant.revealed_at
      );
    END IF;

    IF v_grant.stock_expires_at IS NOT NULL AND v_grant.stock_expires_at <= now() THEN
      UPDATE public.offline_voucher_grants
         SET status = 'expired', updated_at = now()
       WHERE id = v_grant.id;
      UPDATE public.offline_voucher_stock
         SET status = 'expired', updated_at = now()
       WHERE id = v_grant.stock_id;
    ELSE
      v_reuse := true;
    END IF;
  END IF;

  IF v_reuse THEN
    UPDATE public.offline_voucher_grants
       SET device_id = COALESCE(p_device_id, device_id), updated_at = now()
     WHERE id = v_grant.id;

    SELECT * INTO v_stock FROM public.offline_voucher_stock WHERE id = v_grant.stock_id;

    SELECT * INTO v_redeem FROM public.carrier_voucher_redemption
     WHERE carrier_id = v_line.carrier_id;

    RETURN jsonb_build_object(
      'success', true,
      'reissued', true,
      'grant_id', v_grant.id,
      'sim_line_id', p_sim_line_id,
      'pin', public.voucher_decrypt_pin(v_stock.pin_encrypted),
      'serial', v_stock.serial,
      'face_value_usd', v_stock.face_value_usd,
      'face_value_native', v_stock.face_value_native,
      'face_value_currency', v_stock.face_value_currency,
      'amount_due_usd', public.offline_voucher_amount_due(v_stock.face_value_usd),
      'expires_at', v_stock.expires_at,
      'instructions', COALESCE(
        v_stock.redeem_instructions,
        v_redeem.instructions,
        'Dial your carrier''s recharge code and enter this PIN when prompted.'),
      'redeem_ussd_template',
        CASE WHEN v_redeem.verified_at IS NOT NULL THEN v_redeem.redeem_ussd_template END
    );
  END IF;

  -- ── Entitlement check: Premium or Standard lines are entitled ──────────────
  IF v_line.plan_type NOT IN ('premium', 'standard') AND NOT public.has_paid_premium_entitlement(p_sim_line_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'NOT_ENTITLED',
      'message', 'Free plan lines must upgrade to Standard or Premium to secure emergency offline vouchers.'
    );
  END IF;

  SELECT COALESCE(NULLIF(config_value, '')::integer, 365) INTO v_validity
    FROM public.system_configs WHERE config_key = 'OFFLINE_VOUCHER_VALIDITY_DAYS';

  SELECT * INTO v_stock
    FROM public.offline_voucher_stock
   WHERE carrier_id = v_line.carrier_id
     AND status = 'available'
     AND (expires_at IS NULL OR expires_at > now() + interval '7 days')
   ORDER BY face_value_usd ASC, expires_at ASC NULLS LAST, created_at ASC
   FOR UPDATE SKIP LOCKED
   LIMIT 1;

  IF NOT FOUND THEN
    v_source := public.offline_voucher_source_for_carrier(v_line.carrier_id);
    v_due := public.open_offline_voucher_request(
      v_uid, p_sim_line_id, v_line.carrier_id,
      CASE WHEN v_source = 'ding' THEN 'no_stock' ELSE 'no_automatic_source' END
    );
    RETURN jsonb_build_object(
      'success', false,
      'code', 'NO_STOCK',
      'source', v_source,
      'expected_by', v_due
    );
  END IF;

  UPDATE public.offline_voucher_stock
     SET status = 'issued',
         expires_at = COALESCE(expires_at, now() + make_interval(days => COALESCE(v_validity, 365))),
         updated_at = now()
   WHERE id = v_stock.id
  RETURNING * INTO v_stock;

  INSERT INTO public.offline_voucher_grants (
    user_id, sim_line_id, stock_id, status, device_id, expires_at
  ) VALUES (
    v_uid, p_sim_line_id, v_stock.id, 'provisioned', p_device_id, v_stock.expires_at
  )
  RETURNING * INTO v_grant;

  SELECT * INTO v_redeem FROM public.carrier_voucher_redemption
   WHERE carrier_id = v_line.carrier_id;

  RETURN jsonb_build_object(
    'success', true,
    'reissued', false,
    'grant_id', v_grant.id,
    'sim_line_id', p_sim_line_id,
    'pin', public.voucher_decrypt_pin(v_stock.pin_encrypted),
    'serial', v_stock.serial,
    'face_value_usd', v_stock.face_value_usd,
    'face_value_native', v_stock.face_value_native,
    'face_value_currency', v_stock.face_value_currency,
    'amount_due_usd', public.offline_voucher_amount_due(v_stock.face_value_usd),
    'expires_at', v_stock.expires_at,
    'instructions', COALESCE(
      v_stock.redeem_instructions,
      v_redeem.instructions,
      'Dial your carrier''s recharge code and enter this PIN when prompted.'),
    'redeem_ussd_template',
      CASE WHEN v_redeem.verified_at IS NOT NULL THEN v_redeem.redeem_ussd_template END
  );
END;
$fn$;

-- 3. Update offline_voucher_state to return entitlement for Standard & Premium lines
CREATE OR REPLACE FUNCTION public.offline_voucher_state()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
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
              AND g.status IN ('provisioned', 'revealed')
        LEFT JOIN public.offline_voucher_stock s ON s.id = g.stock_id
        LEFT JOIN public.offline_voucher_requests r
               ON r.sim_line_id = sl.id
              AND r.status IN ('pending', 'processing')
        LEFT JOIN public.carrier_voucher_redemption cr ON cr.carrier_id = sl.carrier_id
       WHERE sl.user_id = v_uid
    ) rows;

  RETURN jsonb_build_object(
    'success', true,
    'enabled', COALESCE(v_enabled, false),
    'lines', v_lines
  );
END;
$fn$;

COMMIT;
