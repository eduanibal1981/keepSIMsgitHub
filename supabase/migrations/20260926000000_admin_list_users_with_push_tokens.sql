-- Migration: 20260926000000_admin_list_users_with_push_tokens.sql
-- Description: Expose latest OneSignal player id per user to admin panel and provide admin select policy on device_push_tokens.

-- 1. Add admin select policy on device_push_tokens
DROP POLICY IF EXISTS "dpt_admin_select" ON public.device_push_tokens;
CREATE POLICY "dpt_admin_select" ON public.device_push_tokens
  FOR SELECT TO authenticated
  USING (public.is_power_user(auth.uid()));

-- 2. Extended admin user listing function that includes the latest OneSignal player id
CREATE OR REPLACE FUNCTION public.admin_list_users_extended()
RETURNS TABLE (
  id uuid,
  email text,
  full_name text,
  phone text,
  is_power_user boolean,
  is_suspended boolean,
  onesignal_player_id text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT DISTINCT ON (p.id)
    p.id,
    p.email,
    p.full_name,
    p.phone,
    p.is_power_user,
    p.is_suspended,
    dpt.onesignal_player_id
  FROM public.profiles p
  LEFT JOIN public.device_push_tokens dpt
    ON dpt.user_id = p.id AND dpt.onesignal_player_id IS NOT NULL
  ORDER BY p.id, dpt.updated_at DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_users_extended() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_users_extended() TO authenticated, service_role;
