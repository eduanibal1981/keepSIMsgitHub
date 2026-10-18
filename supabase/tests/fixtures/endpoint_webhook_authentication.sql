-- Isolated Task 4 fixture. No financial data or provider integration.
CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
    CREATE SCHEMA auth;
    CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
      SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'role',''); $$;
    GRANT USAGE ON SCHEMA auth,public TO anon,authenticated,service_role;
    CREATE TABLE public.processed_webhook_events(event_id text PRIMARY KEY,event_type text NOT NULL,call_record_id uuid,processed_at timestamptz DEFAULT now());
    INSERT INTO public.processed_webhook_events(event_id,event_type) VALUES ('legacy-event','call.hangup');
    CREATE TABLE public.voicemail_messages(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid NOT NULL);
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon,authenticated;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon,authenticated;
