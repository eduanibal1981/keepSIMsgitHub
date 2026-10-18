-- The Free Call resolver relies on server-verified phone ownership. Owner RLS
-- alone previously let authenticated clients manufacture that verification.
CREATE OR REPLACE FUNCTION public.protect_caller_id_verification_fields()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  -- Service verification and trusted, ownership-checked SQL routines retain
  -- their existing write path. A client cannot choose its Postgres role.
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.is_verified OR NEW.verified_at IS NOT NULL THEN
      RAISE EXCEPTION 'Phone verification must be performed by the server' USING ERRCODE = '42501';
    END IF;
  ELSE
    IF (NEW.is_verified AND (NOT OLD.is_verified OR NEW.verified_at IS DISTINCT FROM OLD.verified_at))
       OR (NEW.verified_at IS NOT NULL AND NEW.verified_at IS DISTINCT FROM OLD.verified_at) THEN
      RAISE EXCEPTION 'Phone verification must be performed by the server' USING ERRCODE = '42501';
    END IF;
    IF NEW.phone_number IS DISTINCT FROM OLD.phone_number OR NEW.user_id IS DISTINCT FROM OLD.user_id THEN
      NEW.is_verified := false;
      NEW.verified_at := NULL;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.protect_caller_id_verification_fields() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER protect_caller_id_verification_fields
BEFORE INSERT OR UPDATE ON public.user_caller_ids
FOR EACH ROW EXECUTE FUNCTION public.protect_caller_id_verification_fields();
