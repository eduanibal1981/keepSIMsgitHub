-- Separate contract for the new review; retain the legacy RPC for older clients.
-- SIM setup/carrier status and editable profile phones do not prove ownership.
CREATE OR REPLACE FUNCTION public.resolve_free_call_recipient(
  p_phone text DEFAULT NULL,
  p_user_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_number text;
  v_ids uuid[];
  v_claims uuid[];
  v_target uuid;
  v_allowed boolean;
BEGIN
  IF v_caller IS NULL OR NOT EXISTS (
    SELECT 1 FROM auth.users u WHERE u.id = v_caller
      AND (u.banned_until IS NULL OR u.banned_until <= now())
  ) THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  SELECT r.allowed INTO v_allowed FROM public.consume_rate_limit(
    'free_call_recipient', v_caller::text, 30, 10
  ) r;
  IF NOT coalesce(v_allowed, false) THEN
    RETURN jsonb_build_object('status', 'rate_limited');
  END IF;

  IF p_user_id IS NOT NULL THEN
    IF p_phone IS NOT NULL THEN
      RETURN jsonb_build_object('status', 'invalid');
    END IF;
    IF p_user_id = v_caller THEN
      RETURN jsonb_build_object('status', 'self');
    END IF;
    -- A route-supplied ID is insufficient. Only an existing relationship or
    -- call history can resolve by ID; everyone else must resolve by phone.
    IF NOT EXISTS (
      SELECT 1 FROM public.household_members h
      WHERE h.invite_status = 'accepted' AND
        ((h.owner_id = v_caller AND h.member_id = p_user_id)
         OR (h.member_id = v_caller AND h.owner_id = p_user_id))
    ) AND NOT EXISTS (
      SELECT 1 FROM public.voip_call_sessions s
      WHERE (s.caller_id = v_caller AND s.callee_id = p_user_id)
         OR (s.callee_id = v_caller AND s.caller_id = p_user_id)
    ) THEN
      RETURN jsonb_build_object('status', 'unavailable');
    END IF;
    v_target := p_user_id;
  ELSE
    IF p_phone IS NULL OR p_phone !~ '^\+[1-9][0-9]{6,14}$' THEN
      RETURN jsonb_build_object('status', 'invalid');
    END IF;
    v_number := p_phone;
    WITH verified AS (
      SELECT c.user_id FROM public.user_caller_ids c
      WHERE c.is_verified AND
        '+' || regexp_replace(c.phone_number, '[^0-9]', '', 'g') = v_number
      UNION
      SELECT d.user_id FROM public.virtual_did_numbers d
      WHERE d.status = 'active' AND
        '+' || regexp_replace(d.phone_number, '[^0-9]', '', 'g') = v_number
      UNION
      SELECT u.id FROM auth.users u
      WHERE u.phone_confirmed_at IS NOT NULL AND
        '+' || regexp_replace(u.phone, '[^0-9]', '', 'g') = v_number
    ) SELECT array_agg(DISTINCT user_id) INTO v_ids FROM verified;

    -- Preserve a safe unavailable outcome for legacy claims rather than
    -- guessing an owner or asserting that an existing account lacks the app.
    WITH claims AS (
      SELECT s.user_id FROM public.sim_lines s
      WHERE '+' || regexp_replace(s.phone_number, '[^0-9]', '', 'g') = v_number
      UNION
      SELECT p.id FROM public.profiles p
      WHERE '+' || regexp_replace(p.phone, '[^0-9]', '', 'g') = v_number
    ) SELECT array_agg(DISTINCT user_id) INTO v_claims FROM claims;
    IF coalesce(cardinality(v_ids), 0) > 1 THEN
      RETURN jsonb_build_object('status', 'ambiguous', 'phone', v_number);
    ELSIF coalesce(cardinality(v_ids), 0) = 0 THEN
      RETURN jsonb_build_object('status', CASE
        WHEN cardinality(v_claims) = 1 AND v_claims[1] = v_caller THEN 'self'
        WHEN coalesce(cardinality(v_claims), 0) > 0 THEN 'unverified'
        ELSE 'not_found' END, 'phone', v_number);
    END IF;
    v_target := v_ids[1];
    IF EXISTS (SELECT 1 FROM unnest(v_claims) AS claim(id) WHERE id <> v_target) THEN
      RETURN jsonb_build_object('status', 'ambiguous', 'phone', v_number);
    END IF;
    IF v_target = v_caller THEN
      RETURN jsonb_build_object('status', 'self', 'phone', v_number);
    END IF;
  END IF;

  RETURN coalesce((
    SELECT jsonb_build_object('status', 'found', 'phone', v_number,
      'recipient', jsonb_build_object('user_id', p.id,
        'full_name', coalesce(nullif(p.full_name, ''), 'KeepSIMs User'),
        'avatar_url', p.avatar_url, 'phone', coalesce(v_number, ''),
        'is_self', false, 'is_online', false))
    FROM public.profiles p JOIN auth.users u ON u.id = p.id
    WHERE p.id = v_target AND (u.banned_until IS NULL OR u.banned_until <= now())
  ), jsonb_build_object('status', 'unavailable', 'phone', v_number));
END;
$$;
REVOKE ALL ON FUNCTION public.resolve_free_call_recipient(text, uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.resolve_free_call_recipient(text, uuid) TO authenticated;
COMMENT ON FUNCTION public.resolve_free_call_recipient(text, uuid) IS
  'Authenticated bounded Free Call lookup: exact verified phone owner or authorized known peer; no suffix match or presence claim.';
