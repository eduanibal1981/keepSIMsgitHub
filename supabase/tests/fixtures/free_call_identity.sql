-- Bounded native PostgreSQL fixture; never run against a hosted project.
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role BYPASSRLS;
CREATE SCHEMA auth;
CREATE SCHEMA extensions;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
CREATE TABLE auth.users(id uuid PRIMARY KEY,phone text,email text,phone_confirmed_at timestamptz,
  email_confirmed_at timestamptz,banned_until timestamptz,deleted_at timestamptz,
  is_anonymous boolean DEFAULT false,raw_app_meta_data jsonb DEFAULT '{}',created_at timestamptz DEFAULT now());
CREATE TABLE auth.sessions(id uuid PRIMARY KEY,user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT (auth.jwt()->>'sub')::uuid $$;
GRANT USAGE ON SCHEMA auth TO authenticated,anon,service_role;
CREATE TABLE public.profiles(id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,full_name text,avatar_url text,phone text,is_suspended boolean DEFAULT false);
CREATE TABLE public.account_deletions(user_id uuid,status text);
CREATE TABLE public.user_caller_ids(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,phone_number text,is_verified boolean,verified_at timestamptz);
CREATE TABLE public.sim_lines(user_id uuid,phone_number text,verification_status text);
CREATE TABLE public.household_members(owner_id uuid,member_id uuid,invite_status text);
CREATE TABLE public.voip_call_sessions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),caller_id uuid,callee_id uuid,status text DEFAULT 'initiating',started_at timestamptz DEFAULT now(),connected_at timestamptz,ended_at timestamptz,duration_seconds integer DEFAULT 0);
CREATE TABLE public.rate_limit_buckets(bucket text,key text,tokens numeric,updated_at timestamptz,PRIMARY KEY(bucket,key));
CREATE TABLE public.security_logs(user_id uuid,event_type text,description text,metadata jsonb);
INSERT INTO auth.users(id,email) VALUES ('00000000-0000-4000-8000-000000000001','legacy@example.test');
INSERT INTO profiles(id,full_name) SELECT id,'Legacy' FROM auth.users;

-- Captured existing rate-limit function, reused unchanged by the new API.
CREATE OR REPLACE FUNCTION "public"."consume_rate_limit"("p_bucket" "text", "p_key" "text", "p_capacity" integer, "p_refill_per_minute" numeric, "p_now" timestamp with time zone DEFAULT "clock_timestamp"()) RETURNS TABLE("allowed" boolean, "retry_after_seconds" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_raw_claims text;
  v_jwt_role text;
  v_ctx text;
  v_tokens numeric;
  v_updated_at timestamptz;
  v_elapsed numeric;
  v_refill numeric;
  v_new_tokens numeric;
  v_needed numeric;
  v_retry_sec int;
BEGIN
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NOT NULL AND v_raw_claims <> '' THEN
    v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
    IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
      GET DIAGNOSTICS v_ctx = PG_CONTEXT;
      IF coalesce(array_length(string_to_array(v_ctx, E'\n'), 1), 1) < 2 THEN
        RAISE EXCEPTION 'consume_rate_limit is not directly callable by role %', COALESCE(v_jwt_role, '<none>')
          USING ERRCODE = 'KS403';
      END IF;
    END IF;
  END IF;

  IF p_key IS NULL OR p_key = '' THEN
    RETURN QUERY SELECT true, 0;
    RETURN;
  END IF;

  p_bucket := LOWER(p_bucket);

  SELECT tokens, updated_at INTO v_tokens, v_updated_at
  FROM public.rate_limit_buckets
  WHERE bucket = p_bucket AND key = p_key
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.rate_limit_buckets (bucket, key, tokens, updated_at)
    VALUES (p_bucket, p_key, GREATEST(0, p_capacity - 1), p_now)
    ON CONFLICT (bucket, key) DO UPDATE
      SET tokens = EXCLUDED.tokens, updated_at = EXCLUDED.updated_at;

    RETURN QUERY SELECT true, 0;
    RETURN;
  END IF;

  v_elapsed := GREATEST(0, EXTRACT(EPOCH FROM (p_now - v_updated_at)));
  v_refill := v_elapsed * (p_refill_per_minute / 60.0);
  v_new_tokens := LEAST(p_capacity::numeric, v_tokens + v_refill);

  IF v_new_tokens >= 1.0 THEN
    UPDATE public.rate_limit_buckets
    SET tokens = v_new_tokens - 1.0, updated_at = p_now
    WHERE bucket = p_bucket AND key = p_key;

    RETURN QUERY SELECT true, 0;
  ELSE
    v_needed := 1.0 - v_new_tokens;
    IF p_refill_per_minute > 0 THEN
      v_retry_sec := GREATEST(1, CEIL(v_needed / (p_refill_per_minute / 60.0))::int);
    ELSE
      v_retry_sec := 60;
    END IF;

    UPDATE public.rate_limit_buckets
    SET tokens = v_new_tokens, updated_at = p_now
    WHERE bucket = p_bucket AND key = p_key;

    INSERT INTO public.security_logs (user_id, event_type, description, metadata)
    VALUES (
      CASE WHEN auth.uid() IS NOT NULL THEN auth.uid() ELSE NULL END,
      'rate_limited',
      'Rate limit exceeded for ' || p_bucket,
      jsonb_build_object('bucket', p_bucket, 'key', p_key, 'retry_after', v_retry_sec)
    );

    RETURN QUERY SELECT false, v_retry_sec;
  END IF;
END;
$$;
