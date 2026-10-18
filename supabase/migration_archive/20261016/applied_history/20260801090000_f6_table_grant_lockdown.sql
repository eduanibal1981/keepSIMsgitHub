-- ============================================================================
-- F6: strip the default GRANT ALL — stop RLS being a single point of failure
--
-- Finding F-6 (doc/PRODUCTION_PLAN_REVIEW.md § 1). Verified live 2026-07-29:
-- anon and authenticated held INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES and
-- TRIGGER at table level on profiles, sim_lines, scheduled_topups, esim_orders
-- and user_esims. (Exception, already correct: sim_lines has no table-level
-- UPDATE — D5d column-scoped it to 13 columns. That is the pattern followed here.)
--
-- Writes were blocked only by RLS. That is one DROP POLICY from a breach, and
-- TRUNCATE is not RLS-filtered at all. Grants are re-derived from what the live
-- policies actually permit:
--
--   profiles          INSERT(self) + UPDATE(self) policies, NO DELETE policy
--                       -> keep INSERT + column-scoped UPDATE, drop DELETE
--   sim_lines         INSERT/UPDATE/DELETE/SELECT policies all present
--                       -> keep, UPDATE stays on D5d's 13 columns
--   scheduled_topups  ALL policy (self + household manager)
--                       -> keep INSERT/UPDATE/DELETE
--   esim_orders       ONLY a SELECT policy  -> revoke every write
--   user_esims        ONLY a SELECT policy  -> revoke every write
--
-- anon loses every write everywhere. SELECT is left in place: every policy on
-- these tables requires auth.uid(), so anon already reads nothing, and revoking
-- it would be churn without a security gain.
--
-- REFERENCES and TRIGGER are revoked throughout. Neither has any caller, and
-- TRIGGER on a table a client can reach is a privilege-escalation primitive.
--
-- ---------------------------------------------------------------------------
-- 🔴 The live hole this actually closes: self-service power-user escalation
-- ---------------------------------------------------------------------------
-- protect_is_power_user() is the trigger that is supposed to stop a client
-- setting profiles.is_power_user. It opened with:
--
--     IF current_user IN ('postgres', 'supabase_admin') OR ... THEN RETURN NEW;
--
-- but it is SECURITY DEFINER, so current_user is the function OWNER — always
-- 'postgres'. The guard returned NEW for every caller and had never fired. This
-- is the identical defect D5c shipped and D5d fixed for the plan-tier trigger.
--
-- Proven live before this migration, as SET LOCAL ROLE authenticated with a real
-- JWT (rolled back):
--
--     a1 profiles.is_power_user           false -> true
--     a1 auth.users raw_app_meta_data     false -> true   (sync_power_user_claim)
--     privilege_escalation_attempt rows   0                (trigger never ran)
--
-- That is not cosmetic: sync_power_user_claim() copies the column into
-- auth.users.raw_app_meta_data, so after the next token refresh the user's JWT
-- satisfies is_power_user(auth.uid()) — which the "Allow power users full access
-- on sim_lines" policy honours (read/write on EVERY user's SIM lines) and
-- "Users can view own or household profiles" honours (read EVERY profile).
--
-- Fixed in two layers, as F-1/F-2 established:
--   Layer 1  authenticated's column-level UPDATE on profiles excludes
--            is_power_user, is_suspended and subscription_tier -> 42501.
--   Layer 2  the trigger keys on the JWT role instead of current_user, so a
--            future re-grant is not instantly fatal -> silent revert + log.
--
-- The trigger stays SECURITY DEFINER on purpose. D5d's fix for the sibling bug
-- was "make it SECURITY INVOKER", which works there but would break here:
-- security_logs has RLS enabled with zero policies, so an INVOKER trigger could
-- not write its own audit row and would abort the statement with 42501 instead
-- of silently reverting. Keying on request.jwt.claims (the F-1 shape) gets a
-- live guard AND keeps the logging.
--
-- ---------------------------------------------------------------------------
-- ⚠️ Caller change shipped alongside this migration
-- ---------------------------------------------------------------------------
-- ProfileRepository.updateProfile sent profile.toJson() — the FULL model,
-- including every column revoked above. Shipping this lockdown alone would have
-- broken profile editing with 42501, exactly as D5c broke SIM line editing.
-- lib/features/auth/model/auth_model.dart now carries
-- UserProfileWritablePayload.toClientWritableJson() and the repository sends
-- that instead. Both paths are exercised by supabase/tests/f6_table_grant_tests.sql.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- anon: no writes anywhere on these five tables
-- ---------------------------------------------------------------------------
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.profiles         FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.sim_lines        FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.scheduled_topups FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.esim_orders      FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.user_esims       FROM anon;


-- ---------------------------------------------------------------------------
-- authenticated: only what the live policies need
-- ---------------------------------------------------------------------------

-- profiles — no DELETE policy exists, so DELETE is dead surface.
REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.profiles FROM authenticated;
GRANT UPDATE (
  full_name,
  avatar_url,
  phone,
  home_country_code,
  last_country,
  preferred_currency,
  onboarding_completed,
  updated_at
) ON public.profiles TO authenticated;
-- NOT granted, deliberately: id, email, created_at (immutable);
-- is_power_user, is_suspended (privilege/moderation, server-owned);
-- subscription_tier (entitlement, set by trg_fn_apply_plan_tier_from_payment);
-- referral_code, referred_by (set only by apply_referral(), SECURITY DEFINER).

-- sim_lines — D5d's column-scoped UPDATE is already correct and is left alone.
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.sim_lines FROM authenticated;

-- scheduled_topups — the ALL policy needs INSERT/UPDATE/DELETE.
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.scheduled_topups FROM authenticated;

-- esim_orders / user_esims — SELECT policy only. Rows here are written by
-- request_esim_purchase() and worker_esim_fulfillment.js, both service_role.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.esim_orders FROM authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.user_esims  FROM authenticated;


-- ---------------------------------------------------------------------------
-- Layer 2 — make protect_is_power_user actually fire
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_is_power_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_raw_claims text;
  v_jwt_role text;
  strike_count INT;
BEGIN
  -- WAS: IF current_user IN ('postgres','supabase_admin') OR <jwt role check>
  -- Under SECURITY DEFINER current_user is the owner ('postgres') for EVERY
  -- caller, so that first disjunct was always true and the whole guard was dead
  -- code. Key on the request JWT instead — the F-1 shape.
  --
  -- Trusted: no JWT at all (cron, a direct psql/dashboard session, a worker on a
  -- pooled connection) or an explicit service_role JWT. Everything else arrived
  -- through PostgREST as a client. A malformed claims blob fails closed at the
  -- cast rather than falling through.
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NULL OR v_raw_claims = '' THEN
    RETURN NEW;
  END IF;
  v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
  IF v_jwt_role = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.is_power_user = true THEN
      -- Silently fix it so it doesn't crash the transaction
      NEW.is_power_user = false;

      INSERT INTO security_logs (user_id, event_type, description, metadata)
      VALUES (
        auth.uid(),
        'privilege_escalation_attempt',
        'User attempted to create a profile with is_power_user = true',
        jsonb_build_object('action', 'INSERT', 'target_profile_id', NEW.id, 'jwt_role', v_jwt_role)
      );

      -- Auto-Suspend Logic (Strike 3 within 1 hour)
      SELECT count(*) INTO strike_count
      FROM security_logs
      WHERE user_id = auth.uid()
        AND created_at > (NOW() - INTERVAL '1 hour');

      IF strike_count >= 3 THEN
        NEW.is_suspended = true;
      END IF;
    END IF;

  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.is_power_user IS DISTINCT FROM OLD.is_power_user THEN
      -- Silently revert the change
      NEW.is_power_user = OLD.is_power_user;

      INSERT INTO security_logs (user_id, event_type, description, metadata)
      VALUES (
        auth.uid(),
        'privilege_escalation_attempt',
        'User attempted to modify the is_power_user flag on a profile',
        jsonb_build_object(
          'action', 'UPDATE',
          'target_profile_id', NEW.id,
          'attempted_value', NEW.is_power_user,
          'actual_value', OLD.is_power_user,
          'jwt_role', v_jwt_role
        )
      );

      SELECT count(*) INTO strike_count
      FROM security_logs
      WHERE user_id = auth.uid()
        AND created_at > (NOW() - INTERVAL '1 hour');

      IF strike_count >= 3 THEN
        NEW.is_suspended = true;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.protect_is_power_user() IS
  'Reverts and logs client attempts to set profiles.is_power_user. Keys on the request JWT role: '
  'current_user is useless here because the function is SECURITY DEFINER, and that is exactly why '
  'this guard was dead code until 2026-07-29 (F-6). Layer 1 is the column-level UPDATE revoke in '
  'migration 20260801090000; regression test supabase/tests/f6_table_grant_tests.sql.';
