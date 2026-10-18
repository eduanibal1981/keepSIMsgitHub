-- ============================================================================
-- Migration: 20260921040000_fix_voip_contact_lookup_sim_lines.sql
-- Feature: Search KeepSIMs VoIP Contact by SIM lines, caller IDs & profiles
-- ============================================================================

DROP FUNCTION IF EXISTS public.lookup_voip_contact_by_phone(TEXT);

CREATE OR REPLACE FUNCTION public.lookup_voip_contact_by_phone(p_phone TEXT)
RETURNS TABLE (
  user_id UUID,
  full_name TEXT,
  avatar_url TEXT,
  phone TEXT,
  is_online BOOLEAN,
  is_self BOOLEAN
) 
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_clean_phone TEXT;
BEGIN
  v_clean_phone := REGEXP_REPLACE(p_phone, '[^0-9]', '', 'g');
  
  IF LENGTH(v_clean_phone) < 6 THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH matched_candidates AS (
    -- 1. Match from sim_lines
    SELECT 
      s.user_id,
      s.phone_number AS matched_phone,
      COALESCE(s.nickname, '') AS custom_name,
      1 AS priority
    FROM public.sim_lines s
    WHERE (
      REGEXP_REPLACE(s.phone_number, '[^0-9]', '', 'g') = v_clean_phone
      OR (LENGTH(v_clean_phone) >= 8 AND REGEXP_REPLACE(s.phone_number, '[^0-9]', '', 'g') LIKE '%' || v_clean_phone)
      OR (LENGTH(v_clean_phone) >= 8 AND v_clean_phone LIKE '%' || REGEXP_REPLACE(s.phone_number, '[^0-9]', '', 'g'))
    )

    UNION ALL

    -- 2. Match from user_caller_ids
    SELECT 
      c.user_id,
      c.phone_number AS matched_phone,
      '' AS custom_name,
      2 AS priority
    FROM public.user_caller_ids c
    WHERE c.is_verified = TRUE
      AND (
        REGEXP_REPLACE(c.phone_number, '[^0-9]', '', 'g') = v_clean_phone
        OR (LENGTH(v_clean_phone) >= 8 AND REGEXP_REPLACE(c.phone_number, '[^0-9]', '', 'g') LIKE '%' || v_clean_phone)
      )

    UNION ALL

    -- 3. Match from virtual_did_numbers
    SELECT 
      d.user_id,
      d.phone_number AS matched_phone,
      '' AS custom_name,
      3 AS priority
    FROM public.virtual_did_numbers d
    WHERE d.status = 'active'
      AND (
        REGEXP_REPLACE(d.phone_number, '[^0-9]', '', 'g') = v_clean_phone
        OR (LENGTH(v_clean_phone) >= 8 AND REGEXP_REPLACE(d.phone_number, '[^0-9]', '', 'g') LIKE '%' || v_clean_phone)
      )

    UNION ALL

    -- 4. Match from profiles.phone
    SELECT 
      p.id AS user_id,
      p.phone AS matched_phone,
      '' AS custom_name,
      4 AS priority
    FROM public.profiles p
    WHERE p.phone IS NOT NULL
      AND (
        REGEXP_REPLACE(p.phone, '[^0-9]', '', 'g') = v_clean_phone
        OR (LENGTH(v_clean_phone) >= 8 AND REGEXP_REPLACE(p.phone, '[^0-9]', '', 'g') LIKE '%' || v_clean_phone)
      )
  )
  SELECT 
    m.user_id,
    COALESCE(NULLIF(p.full_name, ''), NULLIF(m.custom_name, ''), 'KeepSIMs User') AS full_name,
    p.avatar_url,
    m.matched_phone AS phone,
    EXISTS (
      SELECT 1 FROM public.voip_push_tokens t 
      WHERE t.user_id = m.user_id AND t.is_active = TRUE
    ) AS is_online,
    (auth.uid() IS NOT NULL AND m.user_id = auth.uid()) AS is_self
  FROM matched_candidates m
  JOIN public.profiles p ON p.id = m.user_id
  ORDER BY 
    -- Prioritize other users over self if there's any ambiguity, then by priority
    CASE WHEN auth.uid() IS NOT NULL AND m.user_id = auth.uid() THEN 1 ELSE 0 END ASC,
    m.priority ASC
  LIMIT 1;
END;
$$;

REVOKE ALL ON FUNCTION public.lookup_voip_contact_by_phone(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lookup_voip_contact_by_phone(TEXT) TO authenticated, service_role;
