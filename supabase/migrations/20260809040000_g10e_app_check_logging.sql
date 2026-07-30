-- ============================================================================
-- G10e — Where App Check results land.
--
-- The verification itself is TypeScript inside the Edge Functions (RS256 against
-- Google's JWKS; a Postgres extension that can verify RSA signatures is not
-- installed and pgcrypto cannot). This migration is the database half: one
-- config flag, one recorder, and the place `user_devices.attested_at` gets
-- stamped.
--
-- ── Decisions worth not re-deriving ────────────────────────────────────────
--
-- 1. IT SHIPS NON-ENFORCING. `APP_CHECK_ENFORCE` defaults to `'false'`, so the
--    functions verify, record, and then continue regardless. Nobody knows the
--    real-world failure rate of Play Integrity on this user base — devices
--    without Play Services, rooted phones, sideloaded builds, the emulator the
--    G4 widget was proven on — and switching attestation on blind is how you
--    lock a paying customer out of their own wallet. The owner turns it on
--    after reading `app_check_summary()`.
--
-- 2. A MISSING TOKEN AND A BAD TOKEN ARE DIFFERENT FACTS. `missing` means the
--    client sent no header at all, which every build before this one does and
--    every non-Android build still will. `invalid` means a header arrived and
--    failed cryptographic verification, which no honest client produces. They
--    are separate outcomes so the owner can tell "our old APKs" from "someone
--    is forging headers" before enforcing.
--
-- 3. ANDROID ONLY, AND SAID SO. iOS has no `GoogleService-Info.plist` in this
--    repo (§ 7 owner item 2, the Apple Developer account), so DeviceCheck /
--    App Attest cannot be configured and an iOS build will always report
--    `missing`. Enforcing before iOS is registered would block every iPhone.
--    That gate is written into `app_check_should_enforce()` rather than left as
--    a comment.
--
-- 4. A PASS STAMPS THE DEVICE. `user_devices.attested_at` is the only place the
--    two halves of G10 meet: a device id is a client claim, and this column is
--    the nearest thing to evidence that the claim came from a genuine install
--    of this app. The risk model does not read it yet — deliberately, because
--    with enforcement off the column is sparse and scoring on a sparse column
--    would punish the devices that behaved.
-- ============================================================================

INSERT INTO public.system_configs (config_key, config_value) VALUES
  ('APP_CHECK_ENFORCE',          'false'),
  ('APP_CHECK_ENFORCE_PLATFORMS', 'android')
ON CONFLICT (config_key) DO NOTHING;


-- ---------------------------------------------------------------------------
-- 1. Should the Edge Function refuse on a failed check?
--
-- One place, so the two functions cannot disagree, and so the answer is
-- inspectable from SQL rather than only from a deployed bundle.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_check_should_enforce(p_platform text DEFAULT NULL)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT COALESCE(
           (SELECT config_value FROM public.system_configs WHERE config_key = 'APP_CHECK_ENFORCE'),
           'false') = 'true'
     AND COALESCE(lower(btrim(p_platform)), '') = ANY (
           string_to_array(
             COALESCE((SELECT lower(config_value) FROM public.system_configs
                        WHERE config_key = 'APP_CHECK_ENFORCE_PLATFORMS'), 'android'),
             ','));
$$;

REVOKE ALL     ON FUNCTION public.app_check_should_enforce(text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.app_check_should_enforce(text) TO service_role;

COMMENT ON FUNCTION public.app_check_should_enforce(text) IS
  'G10e: true only when APP_CHECK_ENFORCE is on AND the caller platform is listed '
  'in APP_CHECK_ENFORCE_PLATFORMS. A NULL/unknown platform is never enforced, so '
  'iOS (no GoogleService-Info.plist) and web cannot be locked out by flipping one flag.';


-- ---------------------------------------------------------------------------
-- 2. Recording an outcome.
--
-- `pass` is not logged to `security_logs`: a passing attestation on every money
-- call would be tens of rows per user per day of "nothing happened", and it
-- would bury the rows that matter. A pass stamps `attested_at` instead, which
-- is both the durable record and the useful one.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_app_check_result(
  p_user_id  uuid,
  p_outcome  text,
  p_device_id text DEFAULT NULL,
  p_platform text DEFAULT NULL,
  p_detail   jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_device text := public.normalize_device_id(p_device_id);
BEGIN
  IF p_outcome IS NULL OR p_outcome NOT IN ('pass', 'missing', 'invalid', 'error') THEN
    RETURN;
  END IF;

  IF p_outcome = 'pass' THEN
    IF p_user_id IS NOT NULL AND v_device IS NOT NULL THEN
      UPDATE public.user_devices
         SET attested_at = now()
       WHERE user_id = p_user_id AND device_id = v_device;
    END IF;
    RETURN;
  END IF;

  INSERT INTO public.security_logs (user_id, event_type, description, metadata)
  VALUES (p_user_id,
          'app_check_' || p_outcome,
          CASE p_outcome
            WHEN 'missing' THEN 'Money call arrived with no Firebase App Check token'
            WHEN 'invalid' THEN 'Money call arrived with an App Check token that failed verification'
            ELSE                'App Check verification could not be completed'
          END,
          COALESCE(p_detail, '{}'::jsonb)
            || jsonb_strip_nulls(jsonb_build_object('device_id', v_device, 'platform', p_platform)));
END;
$function$;

REVOKE ALL     ON FUNCTION public.log_app_check_result(uuid, text, text, text, jsonb) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.log_app_check_result(uuid, text, text, text, jsonb) TO service_role;


-- ---------------------------------------------------------------------------
-- 3. What the owner reads before flipping the flag.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_check_summary(p_days integer DEFAULT 7)
RETURNS TABLE (
  outcome       text,
  events        bigint,
  users         bigint,
  last_seen     timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT replace(sl.event_type, 'app_check_', '') AS outcome,
         count(*)                                AS events,
         count(DISTINCT sl.user_id)               AS users,
         max(sl.created_at)                       AS last_seen
    FROM public.security_logs sl
   WHERE sl.event_type LIKE 'app\_check\_%'
     AND sl.created_at >= now() - make_interval(days => GREATEST(COALESCE(p_days, 7), 1))
   GROUP BY 1
  UNION ALL
  SELECT 'pass (devices attested)',
         count(*),
         count(DISTINCT ud.user_id),
         max(ud.attested_at)
    FROM public.user_devices ud
   WHERE ud.attested_at >= now() - make_interval(days => GREATEST(COALESCE(p_days, 7), 1));
$$;

REVOKE ALL     ON FUNCTION public.app_check_summary(integer) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.app_check_summary(integer) TO service_role;

COMMENT ON FUNCTION public.app_check_summary(integer) IS
  'G10e: pass/missing/invalid/error counts. Turning APP_CHECK_ENFORCE on while '
  '"missing" is still the majority outcome locks out every user on an older build.';
