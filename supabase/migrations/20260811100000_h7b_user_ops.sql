-- ============================================================================
-- H7b — user operations.
--
-- The admin app's Users screen reads `profiles` and `wallets` directly. profiles
-- works (there is a read-all policy); wallets does not — probed live with a real
-- power-user JWT it returns exactly ONE row, the admin's own. So no support
-- person has ever been able to see a customer's balance, which is the first
-- question every support ticket asks.
--
-- Balances here are DERIVED from wallet_transactions, not read from
-- wallets.total_deposited / total_spent. G3 established why: those counters read
-- 0.00 for six of eight users who have real deposits in the ledger, because only
-- credit_wallet_for_deposit increments them and most credits never went through
-- it. A support screen quoting them would be quoting a number that is wrong more
-- often than right.
-- ============================================================================

-- A goodwill adjustment is neither a deposit nor a refund. It must not be either:
--   * 'deposit' would make it giftable (G3 derives giftable balance from
--     deposits + gifts_received - gifts_sent), turning support credit into a
--     laundering route;
--   * 'refund' would decrement total_spent against a purchase that never happened.
ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;
ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_type_check
  CHECK (type = ANY (ARRAY['deposit','topup_debit','refund','referral_credit','welcome_home_debit',
                           'auto_fund','plan_fee_debit','esim_purchase_debit','esim_purchase_refund',
                           'wallet_settlement','wallet_forfeit','gift_sent','gift_received',
                           'admin_adjustment']));

INSERT INTO public.system_configs (config_key, config_value)
VALUES ('ADMIN_WALLET_ADJUST_MAX_USD', '50.00')
ON CONFLICT (config_key) DO NOTHING;

INSERT INTO public.system_config_meta
  (config_key, label, group_name, value_type, min_value, max_value, unit, description, sort_order)
VALUES
  ('ADMIN_WALLET_ADJUST_MAX_USD','Support adjustment cap','Wallet & payments','decimal',0,1000,'USD',
   'Largest single goodwill credit or correction a support agent may apply to a wallet. Every adjustment is audited with the agent''s email and a mandatory reason.',70)
ON CONFLICT (config_key) DO UPDATE SET
  label=EXCLUDED.label, group_name=EXCLUDED.group_name, value_type=EXCLUDED.value_type,
  min_value=EXCLUDED.min_value, max_value=EXCLUDED.max_value, unit=EXCLUDED.unit,
  description=EXCLUDED.description, sort_order=EXCLUDED.sort_order;

CREATE OR REPLACE FUNCTION public.admin_list_users(
  p_search text    DEFAULT NULL,
  p_limit  integer DEFAULT 100
)
RETURNS TABLE (
  id                uuid,
  email             text,
  full_name         text,
  subscription_tier text,
  is_power_user     boolean,
  is_suspended      boolean,
  created_at        timestamptz,
  wallet_balance    numeric,
  deposited_usd     numeric,
  spent_usd         numeric,
  line_count        bigint,
  esim_count        bigint,
  open_tickets      bigint,
  last_activity_at  timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT p.id, p.email, p.full_name, p.subscription_tier, p.is_power_user, p.is_suspended,
         p.created_at,
         COALESCE(w.balance, 0),
         COALESCE(t.deposited, 0),
         COALESCE(t.spent, 0),
         (SELECT count(*) FROM public.sim_lines sl WHERE sl.user_id = p.id),
         (SELECT count(*) FROM public.user_esims ue WHERE ue.user_id = p.id),
         (SELECT count(*) FROM public.support_tickets st
           WHERE st.user_id = p.id AND st.status NOT IN ('resolved','closed')),
         t.last_txn_at
  FROM public.profiles p
  LEFT JOIN public.wallets w ON w.user_id = p.id
  LEFT JOIN LATERAL (
    SELECT sum(wt.amount) FILTER (WHERE wt.type IN ('deposit','gift_received','referral_credit')) AS deposited,
           sum(wt.amount) FILTER (WHERE wt.type IN ('topup_debit','plan_fee_debit','esim_purchase_debit',
                                                    'welcome_home_debit','gift_sent'))            AS spent,
           max(wt.created_at)                                                                     AS last_txn_at
    FROM public.wallet_transactions wt
    WHERE wt.user_id = p.id AND wt.status = 'completed'
  ) t ON true
  WHERE p_search IS NULL
     OR p.email ILIKE '%' || p_search || '%'
     OR p.full_name ILIKE '%' || p_search || '%'
     OR p.id::text = p_search
  ORDER BY p.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_users(text,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_users(text,integer) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_get_user(p_user_id uuid)
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
    'profile', jsonb_build_object('id', p.id, 'email', p.email, 'full_name', p.full_name,
                 'tier', p.subscription_tier, 'is_power_user', p.is_power_user,
                 'is_suspended', p.is_suspended, 'created_at', p.created_at,
                 'preferred_currency', p.preferred_currency),
    'wallet', jsonb_build_object('balance', COALESCE(w.balance, 0), 'currency', 'USD'),
    'lines', COALESCE((SELECT jsonb_agg(jsonb_build_object(
                 'id', sl.id, 'phone', sl.phone_number, 'carrier', ca.name,
                 'country', co.name, 'tier', sl.protection_tier,
                 'status', sl.status, 'last_topup_at', sl.last_topup_at) ORDER BY sl.created_at)
               FROM public.sim_lines sl
               LEFT JOIN public.carriers ca ON ca.id = sl.carrier_id
               LEFT JOIN public.countries co ON co.id = sl.country_id
               WHERE sl.user_id = p.id), '[]'::jsonb),
    'recent_transactions', COALESCE((SELECT jsonb_agg(jsonb_build_object(
                 'created_at', wt.created_at, 'type', wt.type, 'amount', wt.amount,
                 'balance_after', wt.balance_after, 'description', wt.description,
                 'reference_id', wt.reference_id) ORDER BY wt.created_at DESC)
               FROM (SELECT * FROM public.wallet_transactions
                     WHERE user_id = p.id ORDER BY created_at DESC LIMIT 25) wt), '[]'::jsonb),
    'devices', COALESCE((SELECT jsonb_agg(jsonb_build_object(
                 'device_id', ud.device_id, 'trust_state', ud.trust_state,
                 'first_seen_at', ud.first_seen_at, 'last_seen_at', ud.last_seen_at))
               FROM public.user_devices ud WHERE ud.user_id = p.id), '[]'::jsonb)
  ) INTO v
  FROM public.profiles p
  LEFT JOIN public.wallets w ON w.user_id = p.id
  WHERE p.id = p_user_id;

  IF v IS NULL THEN
    RAISE EXCEPTION 'User % not found', p_user_id USING ERRCODE = 'KS461';
  END IF;
  RETURN v;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_user(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_user(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_set_user_flags(
  p_user_id uuid,
  p_patch   jsonb,
  p_note    text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_allowed text[] := ARRAY['is_suspended','subscription_tier'];
  v_bad     text;
  v_actor   uuid;
  v_before  RECORD;
  v_tier    text;
BEGIN
  v_actor := public.assert_admin();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Nothing to change' USING ERRCODE = 'KS467';
  END IF;

  -- is_power_user is deliberately NOT here. protect_is_power_user() silently
  -- reverts any change to that column whose JWT role is not service_role, and
  -- then logs a privilege_escalation_attempt against the caller — three of those
  -- in an hour and it suspends the caller's own account. An admin promoting a
  -- colleague from this app would appear to succeed, do nothing, and on the
  -- third try lock themselves out. Promotion stays a service_role action.
  SELECT string_agg(k, ', ') INTO v_bad
  FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'Field(s) % cannot be changed here%', v_bad,
      CASE WHEN p_patch ? 'is_power_user'
           THEN '. Power-user status is granted with the service role, not from this app — protect_is_power_user() would revert it and log you as an attacker.'
           ELSE '' END
      USING ERRCODE = 'KS467';
  END IF;

  SELECT * INTO v_before FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User % not found', p_user_id USING ERRCODE = 'KS461';
  END IF;

  IF p_user_id = v_actor AND COALESCE((p_patch ->> 'is_suspended')::boolean, false) THEN
    RAISE EXCEPTION 'You cannot suspend your own account' USING ERRCODE = 'KS466';
  END IF;

  v_tier := COALESCE(p_patch ->> 'subscription_tier', v_before.subscription_tier);
  IF v_tier NOT IN ('basic','standard','premium') THEN
    RAISE EXCEPTION 'Tier must be basic, standard or premium' USING ERRCODE = 'KS466';
  END IF;

  UPDATE public.profiles SET
    is_suspended      = COALESCE((p_patch ->> 'is_suspended')::boolean, is_suspended),
    subscription_tier = v_tier
  WHERE id = p_user_id;

  PERFORM public.admin_log('user.flags', 'user', p_user_id::text,
    jsonb_build_object('is_suspended', v_before.is_suspended, 'tier', v_before.subscription_tier),
    jsonb_build_object('is_suspended', COALESCE((p_patch ->> 'is_suspended')::boolean, v_before.is_suspended),
                       'tier', v_tier),
    COALESCE(p_note, '') || ' [' || COALESCE(v_before.email,'?') || ']');

  RETURN jsonb_build_object('success', true, 'user_id', p_user_id);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_user_flags(uuid,jsonb,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_user_flags(uuid,jsonb,text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_adjust_wallet(
  p_user_id uuid,
  p_amount  numeric,
  p_reason  text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_actor  uuid;
  v_cap    numeric;
  v_wallet RECORD;
  v_before numeric;
  v_after  numeric;
  v_txn    uuid;
  v_email  text;
BEGIN
  v_actor := public.assert_admin();

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'A reason of at least 5 characters is required' USING ERRCODE = 'KS464';
  END IF;

  IF p_amount IS NULL OR p_amount = 0 THEN
    RAISE EXCEPTION 'Amount must be non-zero' USING ERRCODE = 'KS466';
  END IF;

  SELECT COALESCE(NULLIF(config_value,'')::numeric, 50) INTO v_cap
  FROM public.system_configs WHERE config_key = 'ADMIN_WALLET_ADJUST_MAX_USD';
  v_cap := COALESCE(v_cap, 50);

  IF abs(p_amount) > v_cap THEN
    RAISE EXCEPTION 'Adjustment of % exceeds the % USD support limit', p_amount, v_cap
      USING ERRCODE = 'KS466';
  END IF;

  IF p_user_id = v_actor THEN
    RAISE EXCEPTION 'You cannot adjust your own wallet' USING ERRCODE = 'KS466';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id USING ERRCODE = 'KS461';
  END IF;

  v_before := v_wallet.balance;
  v_after  := v_before + round(p_amount, 2);

  IF v_after < 0 THEN
    RAISE EXCEPTION 'That would take the balance to %, below zero', v_after USING ERRCODE = 'KS466';
  END IF;

  UPDATE public.wallets SET balance = v_after WHERE id = v_wallet.id;

  SELECT email INTO v_email FROM public.profiles WHERE id = v_actor;

  -- Positive and negative both store a positive amount (the CHECK requires it);
  -- direction is carried by balance_before/balance_after, as every other debit
  -- in this ledger already does.
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, status, metadata
  ) VALUES (
    v_wallet.id, p_user_id, 'admin_adjustment', abs(round(p_amount, 2)), v_before, v_after,
    CASE WHEN p_amount > 0 THEN 'Support credit: ' ELSE 'Support correction: ' END || left(btrim(p_reason), 160),
    'adminadj_' || replace(gen_random_uuid()::text, '-', ''),
    'completed',
    jsonb_build_object('adjusted_by', v_actor::text, 'adjusted_by_email', v_email,
                       'direction', CASE WHEN p_amount > 0 THEN 'credit' ELSE 'debit' END,
                       'reason', btrim(p_reason))
  ) RETURNING id INTO v_txn;

  PERFORM public.admin_log('wallet.adjust', 'user', p_user_id::text,
    jsonb_build_object('balance', v_before),
    jsonb_build_object('balance', v_after, 'amount', p_amount, 'txn_id', v_txn),
    btrim(p_reason));

  INSERT INTO public.notifications (user_id, category, title, body)
  VALUES (p_user_id, 'wallet_credit',
          CASE WHEN p_amount > 0 THEN 'Credit added to your wallet' ELSE 'Your wallet balance was corrected' END,
          'Support adjusted your balance by ' ||
          CASE WHEN p_amount > 0 THEN '+' ELSE '-' END || '$' || to_char(abs(round(p_amount,2)),'FM999999990.00') ||
          '. New balance $' || to_char(v_after,'FM999999990.00') || '.');

  RETURN jsonb_build_object('success', true, 'balance_before', v_before,
                            'balance_after', v_after, 'transaction_id', v_txn);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_adjust_wallet(uuid,numeric,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_adjust_wallet(uuid,numeric,text) TO authenticated, service_role;

COMMENT ON FUNCTION public.admin_adjust_wallet(uuid,numeric,text) IS
  'H7b: support goodwill credit / correction. Capped by ADMIN_WALLET_ADJUST_MAX_USD, reason mandatory, self-adjustment refused, and booked as admin_adjustment so it is neither giftable (G3) nor mistaken for a refund.';
