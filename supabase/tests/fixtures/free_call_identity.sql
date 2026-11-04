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
