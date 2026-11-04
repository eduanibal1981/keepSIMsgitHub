-- Free Call aliases are public routing hints, never authentication credentials.
-- No SIM, wallet, supplier, referral or paid-calling data is migrated.
CREATE SCHEMA IF NOT EXISTS free_call_private;
REVOKE ALL ON SCHEMA free_call_private FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE free_call_private.identities (
  public_id text PRIMARY KEY CHECK (public_id ~ '^K[A-Z]{2}-[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{8}$'),
  user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  registration_country text NOT NULL CHECK (registration_country ~ '^[A-Z]{2}$' AND substr(public_id,2,2)=registration_country),
  issued_at timestamptz NOT NULL DEFAULT now(),
  discover_by_id boolean NOT NULL DEFAULT true,
  email_consent text
);
CREATE TABLE free_call_private.phone_consents (
  phone text PRIMARY KEY CHECK (phone ~ '^\+[1-9][0-9]{6,14}$'),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_id text NOT NULL,
  verified_at timestamptz NOT NULL,
  consented_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX phone_consents_user ON free_call_private.phone_consents(user_id);
CREATE TABLE free_call_private.blocks (
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(owner_id, blocked_id), CHECK (owner_id <> blocked_id)
);
CREATE INDEX blocks_target ON free_call_private.blocks(blocked_id);
CREATE TABLE free_call_private.resolutions (
  caller_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL,
  PRIMARY KEY(caller_id, target_id)
);
CREATE INDEX resolutions_target ON free_call_private.resolutions(target_id);
ALTER TABLE free_call_private.identities ENABLE ROW LEVEL SECURITY;
ALTER TABLE free_call_private.phone_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE free_call_private.blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE free_call_private.resolutions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA free_call_private FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION free_call_private.protect_identity() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'DELETE' OR TG_OP = 'TRUNCATE' THEN
    RAISE EXCEPTION 'Issued calling aliases are never recycled';
  END IF;
  IF NEW.public_id IS DISTINCT FROM OLD.public_id
     OR NEW.registration_country IS DISTINCT FROM OLD.registration_country
     OR NEW.issued_at IS DISTINCT FROM OLD.issued_at
     OR (NEW.user_id IS DISTINCT FROM OLD.user_id AND
         NOT (NEW.user_id IS NULL AND NOT EXISTS (SELECT 1 FROM auth.users WHERE id=OLD.user_id))) THEN
    RAISE EXCEPTION 'Calling identity is immutable';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER protect_identity BEFORE UPDATE OR DELETE ON free_call_private.identities
FOR EACH ROW EXECUTE FUNCTION free_call_private.protect_identity();
CREATE TRIGGER protect_identity_truncate BEFORE TRUNCATE ON free_call_private.identities
FOR EACH STATEMENT EXECUTE FUNCTION free_call_private.protect_identity();

CREATE FUNCTION free_call_private.issue_identity(p_user uuid) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_id text; v_country text; v_bytes bytea; v_suffix text; v_byte integer;
  v_alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
BEGIN
  -- Serializes interrupted/concurrent provisioning for the same immutable UID.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user::text, 71429));
  SELECT public_id INTO v_id FROM free_call_private.identities WHERE user_id=p_user;
  IF FOUND THEN RETURN v_id; END IF;
  -- There is no immutable registration-country field on legacy profiles.
  -- home_country_code/last_country and SIM countries are mutable and not used.
  SELECT upper(u.raw_app_meta_data->>'registration_country') INTO v_country FROM auth.users u WHERE id=p_user;
  IF NOT FOUND THEN RAISE EXCEPTION 'Account missing'; END IF;
  IF v_country IS NULL OR NOT (v_country = ANY(string_to_array(
    'AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW', ' '))) THEN
    v_country := 'XX';
  END IF;
  FOR attempt IN 1..12 LOOP
    v_suffix := '';
    -- Rejection sampling avoids modulo bias with this 31-character alphabet.
    WHILE length(v_suffix) < 8 LOOP
      v_bytes := extensions.gen_random_bytes(16);
      FOR i IN 0..15 LOOP
        v_byte := get_byte(v_bytes,i);
        IF v_byte < 248 THEN
          v_suffix := v_suffix || substr(v_alphabet, (v_byte % 31)+1, 1);
          EXIT WHEN length(v_suffix)=8;
        END IF;
      END LOOP;
    END LOOP;
    v_id := 'K' || v_country || '-' || v_suffix;
    BEGIN
      INSERT INTO free_call_private.identities(public_id,user_id,registration_country) VALUES(v_id,p_user,v_country);
      RETURN v_id;
    EXCEPTION WHEN unique_violation THEN
      SELECT public_id INTO v_id FROM free_call_private.identities WHERE user_id=p_user;
      IF FOUND THEN RETURN v_id; END IF;
    END;
  END LOOP;
  RAISE EXCEPTION 'Unable to allocate calling alias; retry provisioning';
END $$;

CREATE FUNCTION free_call_private.provision_identity() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM free_call_private.issue_identity(NEW.id);
  RETURN NEW;
END $$;
CREATE TRIGGER provision_free_call_identity AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION free_call_private.provision_identity();
-- Only the alias ledger is written; existing profile/signup triggers never run.
SELECT free_call_private.issue_identity(id) FROM auth.users ORDER BY id;

CREATE FUNCTION free_call_private.active_account(p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM auth.users u JOIN public.profiles p ON p.id=u.id
    WHERE u.id=p_user AND u.deleted_at IS NULL AND NOT coalesce(u.is_anonymous,false)
      AND (u.banned_until IS NULL OR u.banned_until<=now()) AND NOT coalesce(p.is_suspended,false)
      AND NOT EXISTS (SELECT 1 FROM public.account_deletions d WHERE d.user_id=u.id
        AND d.status NOT IN ('cancelled','canceled')));
$$;
CREATE FUNCTION free_call_private.require_caller() RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user uuid := auth.uid(); v_session text := auth.jwt()->>'session_id';
BEGIN
  IF v_user IS NULL OR NOT free_call_private.active_account(v_user) THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  IF v_session IS NOT NULL AND NOT EXISTS(SELECT 1 FROM auth.sessions s WHERE s.id::text=v_session AND s.user_id=v_user) THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  RETURN v_user;
END $$;

-- Proof sources are kept live: changing/unlinking a source invalidates consent.
-- SIM verification/test passes, profile phones and managed DIDs are not proofs.
CREATE INDEX free_call_verified_caller_phone ON public.user_caller_ids(phone_number,user_id) WHERE is_verified AND verified_at IS NOT NULL;
CREATE FUNCTION free_call_private.phone_proofs(p_phone text DEFAULT NULL,p_user uuid DEFAULT NULL) RETURNS TABLE(user_id uuid,phone text,source_id text,verified_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT u.id,'+' || ltrim(u.phone,'+'),'auth:' || u.id::text,u.phone_confirmed_at
    FROM auth.users u WHERE u.phone_confirmed_at IS NOT NULL AND '+' || ltrim(u.phone,'+') ~ '^\+[1-9][0-9]{6,14}$'
      AND (p_phone IS NULL OR u.phone=ltrim(p_phone,'+') OR u.phone=p_phone) AND (p_user IS NULL OR u.id=p_user)
  UNION ALL
  SELECT c.user_id,c.phone_number,'caller:' || c.id::text,c.verified_at FROM public.user_caller_ids c
    WHERE c.is_verified AND c.verified_at IS NOT NULL AND c.phone_number ~ '^\+[1-9][0-9]{6,14}$'
      AND (p_phone IS NULL OR c.phone_number=p_phone) AND (p_user IS NULL OR c.user_id=p_user);
$$;
CREATE FUNCTION free_call_private.eligible_pair(a uuid,b uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT a<>b AND free_call_private.active_account(a) AND free_call_private.active_account(b)
    AND NOT EXISTS(SELECT 1 FROM free_call_private.blocks WHERE (owner_id=a AND blocked_id=b) OR (owner_id=b AND blocked_id=a));
$$;
CREATE FUNCTION free_call_private.known_pair(a uuid,b uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS(SELECT 1 FROM public.household_members h WHERE h.invite_status='accepted'
    AND ((h.owner_id=a AND h.member_id=b) OR (h.owner_id=b AND h.member_id=a)))
  OR EXISTS(SELECT 1 FROM public.voip_call_sessions s WHERE (s.caller_id=a AND s.callee_id=b) OR (s.caller_id=b AND s.callee_id=a))
  OR EXISTS(SELECT 1 FROM free_call_private.resolutions r WHERE r.caller_id=a AND r.target_id=b AND r.expires_at>now());
$$;
CREATE FUNCTION free_call_private.quota(p_user uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_allowed boolean;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user::text,71430));
  SELECT allowed INTO v_allowed FROM public.consume_rate_limit('free_call_identity',p_user::text,20,5);
  IF NOT coalesce(v_allowed,false) THEN RETURN false; END IF;
  -- A signed Auth session ID provides a device/session quota without trusting
  -- arbitrary client headers as an IP address.
  IF auth.jwt()->>'session_id' IS NOT NULL THEN
    SELECT allowed INTO v_allowed FROM public.consume_rate_limit('free_call_session',auth.jwt()->>'session_id',15,4);
  END IF;
  RETURN coalesce(v_allowed,false);
END $$;

CREATE FUNCTION public.get_free_call_identity() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user uuid := free_call_private.require_caller(); v_id text;
BEGIN
  v_id := free_call_private.issue_identity(v_user);
  RETURN (SELECT jsonb_build_object('public_id',v_id,'issued_at',i.issued_at,
    'discover_by_id',i.discover_by_id,'email_verified',u.email_confirmed_at IS NOT NULL,
    'discover_by_email',coalesce(u.email_confirmed_at IS NOT NULL AND i.email_consent=lower(u.email),false),
    'phones',coalesce((SELECT jsonb_agg(t) FROM (
      SELECT p.phone,bool_or(EXISTS(SELECT 1 FROM free_call_private.phone_consents c
        WHERE c.user_id=v_user AND c.phone=p.phone AND c.source_id=p.source_id AND c.verified_at=p.verified_at)) AS enabled
      FROM free_call_private.phone_proofs(NULL,v_user) p
      GROUP BY p.phone
    ) t),'[]'::jsonb),
    'blocked',coalesce((SELECT jsonb_agg(jsonb_build_object('user_id',b.blocked_id,'full_name',coalesce(nullif(p.full_name,''),'KeepSIMs User')))
      FROM free_call_private.blocks b LEFT JOIN public.profiles p ON p.id=b.blocked_id WHERE b.owner_id=v_user),'[]'::jsonb))
    FROM free_call_private.identities i JOIN auth.users u ON u.id=i.user_id WHERE i.user_id=v_user);
END $$;
CREATE FUNCTION public.set_free_call_discovery(p_by_id boolean,p_by_email boolean) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user uuid := free_call_private.require_caller();
BEGIN
  IF p_by_id IS NULL OR p_by_email IS NULL THEN RAISE EXCEPTION 'Choose discovery settings'; END IF;
  PERFORM free_call_private.issue_identity(v_user);
  UPDATE free_call_private.identities SET discover_by_id=p_by_id,
    email_consent=CASE WHEN p_by_email THEN (SELECT lower(email) FROM auth.users WHERE id=v_user AND email_confirmed_at IS NOT NULL) ELSE NULL END
    WHERE user_id=v_user;
  RETURN public.get_free_call_identity();
END $$;
CREATE FUNCTION public.set_free_call_phone_discovery(p_phone text,p_enabled boolean) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user uuid := free_call_private.require_caller(); v_proof record;
BEGIN
  IF p_enabled IS NULL OR p_phone IS NULL OR p_phone !~ '^\+[1-9][0-9]{6,14}$' THEN RAISE EXCEPTION 'Choose a verified international number'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_phone,71431));
  IF NOT p_enabled THEN
    DELETE FROM free_call_private.phone_consents WHERE user_id=v_user AND phone=p_phone;
  ELSE
    SELECT * INTO v_proof FROM free_call_private.phone_proofs(p_phone,v_user) ORDER BY source_id LIMIT 1;
    IF NOT FOUND OR (SELECT count(DISTINCT user_id) FROM free_call_private.phone_proofs(p_phone))<>1 THEN
      RAISE EXCEPTION 'Number is not available for calling discovery' USING ERRCODE='42501';
    END IF;
    DELETE FROM free_call_private.phone_consents c WHERE c.phone=p_phone AND NOT EXISTS(
      SELECT 1 FROM free_call_private.phone_proofs(p_phone) p WHERE p.user_id=c.user_id AND p.phone=c.phone AND p.source_id=c.source_id AND p.verified_at=c.verified_at);
    INSERT INTO free_call_private.phone_consents(phone,user_id,source_id,verified_at) VALUES(p_phone,v_user,v_proof.source_id,v_proof.verified_at)
      ON CONFLICT(phone) DO UPDATE SET source_id=excluded.source_id,verified_at=excluded.verified_at,consented_at=now()
      WHERE free_call_private.phone_consents.user_id=v_user;
    IF NOT FOUND THEN RAISE EXCEPTION 'Number is not available for calling discovery' USING ERRCODE='42501'; END IF;
  END IF;
  RETURN public.get_free_call_identity();
END $$;
CREATE FUNCTION public.set_free_call_block(p_user_id uuid,p_blocked boolean) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user uuid := free_call_private.require_caller();
BEGIN
  IF p_user_id IS NULL OR p_user_id=v_user OR p_blocked IS NULL THEN RAISE EXCEPTION 'Choose another account'; END IF;
  IF p_blocked THEN
    INSERT INTO free_call_private.blocks(owner_id,blocked_id) SELECT v_user,p_user_id
      WHERE EXISTS(SELECT 1 FROM auth.users WHERE id=p_user_id) ON CONFLICT DO NOTHING;
    DELETE FROM free_call_private.resolutions WHERE (caller_id=v_user AND target_id=p_user_id) OR (caller_id=p_user_id AND target_id=v_user);
  ELSE
    DELETE FROM free_call_private.blocks WHERE owner_id=v_user AND blocked_id=p_user_id;
  END IF;
  RETURN jsonb_build_object('ok',true);
END $$;

CREATE FUNCTION public.resolve_free_call_identity(p_type text,p_value text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_caller uuid := free_call_private.require_caller(); v_value text; v_target uuid; v_result jsonb;
BEGIN
  IF NOT free_call_private.quota(v_caller) THEN RETURN jsonb_build_object('status','rate_limited'); END IF;
  IF p_value IS NULL OR length(p_value)>254 THEN RETURN jsonb_build_object('status','invalid'); END IF;
  v_value := btrim(p_value);
  IF p_type='id' THEN
    v_value := upper(regexp_replace(v_value,'[[:space:]-]','','g'));
    IF v_value !~ '^K[A-Z]{2}[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{8}$' THEN RETURN jsonb_build_object('status','invalid'); END IF;
    v_value := substr(v_value,1,3)||'-'||substr(v_value,4);
    SELECT user_id INTO v_target FROM free_call_private.identities WHERE public_id=v_value AND discover_by_id;
  ELSIF p_type='phone' THEN
    IF v_value !~ '^\+[1-9][0-9]{6,14}$' THEN RETURN jsonb_build_object('status','invalid'); END IF;
    SELECT c.user_id INTO v_target FROM free_call_private.phone_consents c
      WHERE c.phone=v_value AND EXISTS(SELECT 1 FROM free_call_private.phone_proofs(v_value) p
        WHERE p.phone=c.phone AND p.user_id=c.user_id AND p.source_id=c.source_id AND p.verified_at=c.verified_at)
      AND (SELECT count(DISTINCT user_id) FROM free_call_private.phone_proofs(v_value))=1;
  ELSIF p_type='email' THEN
    v_value := lower(v_value);
    IF v_value !~ '^[^[:space:]@]+@[^[:space:]@.]+(\.[^[:space:]@.]+)+$' THEN RETURN jsonb_build_object('status','invalid'); END IF;
    SELECT u.id INTO v_target FROM auth.users u JOIN free_call_private.identities i ON i.user_id=u.id
      WHERE lower(u.email)=v_value AND u.email_confirmed_at IS NOT NULL AND i.email_consent=v_value;
  ELSE RETURN jsonb_build_object('status','invalid'); END IF;
  IF v_target=v_caller THEN RETURN jsonb_build_object('status','self'); END IF;
  IF v_target IS NULL OR NOT free_call_private.eligible_pair(v_caller,v_target) THEN RETURN jsonb_build_object('status','not_found'); END IF;
  -- A search grants temporary routing eligibility, but never creates a call.
  DELETE FROM free_call_private.resolutions WHERE caller_id=v_caller AND expires_at<=now();
  INSERT INTO free_call_private.resolutions VALUES(v_caller,v_target,now()+interval '15 minutes')
    ON CONFLICT(caller_id,target_id) DO UPDATE SET expires_at=excluded.expires_at;
  SELECT jsonb_build_object('status','found','recipient',jsonb_build_object('user_id',p.id,
    'full_name',coalesce(nullif(p.full_name,''),'KeepSIMs User'),'avatar_url',p.avatar_url,
    'public_id',i.public_id,'is_online',false)) INTO v_result
    FROM public.profiles p JOIN free_call_private.identities i ON i.user_id=p.id WHERE p.id=v_target;
  RETURN coalesce(v_result,jsonb_build_object('status','not_found'));
END $$;

-- Keep the exact legacy signature/phone echo for installed clients. Raw managed
-- SIM claims no longer suppress or impersonate a verified, opted-in owner.
CREATE OR REPLACE FUNCTION public.resolve_free_call_recipient(p_phone text DEFAULT NULL,p_user_id uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user uuid := free_call_private.require_caller(); v_result jsonb;
BEGIN
  IF (p_phone IS NULL)=(p_user_id IS NULL) THEN RETURN jsonb_build_object('status','invalid'); END IF;
  IF p_phone IS NOT NULL THEN
    v_result := public.resolve_free_call_identity('phone',p_phone) || jsonb_build_object('phone',p_phone);
    IF v_result->>'status'='found' THEN v_result := jsonb_set(v_result,'{recipient,phone}',to_jsonb(p_phone)); END IF;
    RETURN v_result;
  END IF;
  IF NOT free_call_private.quota(v_user) THEN RETURN jsonb_build_object('status','rate_limited'); END IF;
  IF p_user_id=v_user THEN RETURN jsonb_build_object('status','self'); END IF;
  IF NOT free_call_private.eligible_pair(v_user,p_user_id) OR NOT free_call_private.known_pair(v_user,p_user_id) THEN RETURN jsonb_build_object('status','unavailable'); END IF;
  RETURN (SELECT jsonb_build_object('status','found','recipient',jsonb_build_object('user_id',p.id,
    'full_name',coalesce(nullif(p.full_name,''),'KeepSIMs User'),'avatar_url',p.avatar_url,
    'public_id',i.public_id,'phone','','is_online',false)) FROM public.profiles p
    JOIN free_call_private.identities i ON i.user_id=p.id WHERE p.id=p_user_id);
END $$;

-- This guard covers service-role Edge inserts too. Guessing a canonical UUID
-- cannot bypass discovery, lifecycle, block or call-attempt rate controls.
CREATE FUNCTION free_call_private.guard_call() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_allowed boolean;
BEGIN
  IF NOT free_call_private.eligible_pair(NEW.caller_id,NEW.callee_id)
     OR NOT free_call_private.known_pair(NEW.caller_id,NEW.callee_id) THEN
    RAISE EXCEPTION 'KeepSIMs contact unavailable' USING ERRCODE='42501';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(NEW.caller_id::text,71432));
  SELECT allowed INTO v_allowed FROM public.consume_rate_limit('free_call_attempt',NEW.caller_id::text,8,2);
  IF NOT coalesce(v_allowed,false) THEN RAISE EXCEPTION 'Try calling again later' USING ERRCODE='42501'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER guard_free_call BEFORE INSERT ON public.voip_call_sessions FOR EACH ROW EXECUTE FUNCTION free_call_private.guard_call();
-- RLS does not apply to TRUNCATE. Ordinary clients only read participant rows;
-- all existing offer/answer/termination writes run through guarded server APIs.
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.voip_call_sessions FROM anon,authenticated;

-- Preserve the installed history signature while removing editable/private
-- profile phone leakage. No call rows or timestamps are modified.
CREATE OR REPLACE FUNCTION public.get_voip_call_history(p_limit integer DEFAULT 50)
RETURNS TABLE(id uuid,caller_id uuid,callee_id uuid,peer_user_id uuid,peer_name text,peer_avatar_url text,peer_phone text,is_outgoing boolean,status text,started_at timestamptz,connected_at timestamptz,ended_at timestamptz,duration_seconds integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user uuid := free_call_private.require_caller();
BEGIN
  RETURN QUERY SELECT s.id,s.caller_id,s.callee_id,CASE WHEN s.caller_id=v_user THEN s.callee_id ELSE s.caller_id END,
    p.full_name,p.avatar_url,''::text,s.caller_id=v_user,s.status,s.started_at,s.connected_at,s.ended_at,s.duration_seconds
    FROM public.voip_call_sessions s LEFT JOIN public.profiles p ON p.id=CASE WHEN s.caller_id=v_user THEN s.callee_id ELSE s.caller_id END
    WHERE s.caller_id=v_user OR s.callee_id=v_user ORDER BY s.started_at DESC LIMIT greatest(1,least(coalesce(p_limit,50),100));
END $$;
CREATE FUNCTION public.get_free_call_history(p_limit integer DEFAULT 50) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM free_call_private.require_caller();
  RETURN coalesce((SELECT jsonb_agg(to_jsonb(h)||jsonb_build_object('peer_public_id',i.public_id) ORDER BY h.started_at DESC)
    FROM public.get_voip_call_history(p_limit) h LEFT JOIN free_call_private.identities i ON i.user_id=h.peer_user_id),'[]'::jsonb);
END $$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA free_call_private FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.get_free_call_identity(),public.set_free_call_discovery(boolean,boolean),public.set_free_call_phone_discovery(text,boolean),public.set_free_call_block(uuid,boolean),public.resolve_free_call_identity(text,text),public.resolve_free_call_recipient(text,uuid),public.get_free_call_history(integer),public.get_voip_call_history(integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_free_call_identity(),public.set_free_call_discovery(boolean,boolean),public.set_free_call_phone_discovery(text,boolean),public.set_free_call_block(uuid,boolean),public.resolve_free_call_identity(text,text),public.resolve_free_call_recipient(text,uuid),public.get_free_call_history(integer),public.get_voip_call_history(integer) TO authenticated;
