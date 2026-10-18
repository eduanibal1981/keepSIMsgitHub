-- Task 4. Independent of the pending financial migrations. Deploy before handlers.
BEGIN;
CREATE TABLE public.verified_webhook_events (
  scope text NOT NULL CHECK (scope IN ('telnyx','twilio-liveness','twilio-voice','voicemail')),
  event_id text NOT NULL CHECK (length(event_id) BETWEEN 1 AND 300),
  resource_id text NOT NULL CHECK (length(resource_id) BETWEEN 1 AND 500),
  payload_hash text,
  state text NOT NULL CHECK (state IN ('processing','failed','completed')),
  claim_token uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (scope,event_id)
);
CREATE UNIQUE INDEX verified_webhook_resource_processing
  ON public.verified_webhook_events(scope,resource_id) WHERE state='processing';
ALTER TABLE public.verified_webhook_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.verified_webhook_events FROM PUBLIC,anon,authenticated,service_role;
-- Preserve prior Telnyx deduplication history. No raw payloads/customer data copied.
INSERT INTO public.verified_webhook_events(scope,event_id,resource_id,state)
SELECT 'telnyx',event_id,coalesce(call_record_id::text,event_id),'completed'
FROM public.processed_webhook_events;

CREATE FUNCTION public.claim_verified_webhook(p_scope text,p_event_id text,p_resource_id text,p_payload_hash text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_event public.verified_webhook_events; v_token uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE insufficient_privilege; END IF;
  IF p_scope IS NULL OR p_scope NOT IN ('telnyx','twilio-liveness','twilio-voice','voicemail') OR
     p_event_id IS NULL OR length(p_event_id) NOT BETWEEN 1 AND 300 OR
     p_resource_id IS NULL OR length(p_resource_id) NOT BETWEEN 1 AND 500 OR
     p_payload_hash IS NULL OR p_payload_hash !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'Invalid webhook identity' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_scope||':'||p_resource_id,0));
  SELECT * INTO v_event FROM public.verified_webhook_events WHERE scope=p_scope AND event_id=p_event_id FOR UPDATE;
  IF FOUND THEN
    IF v_event.payload_hash IS NOT NULL AND
       (v_event.payload_hash<>p_payload_hash OR v_event.resource_id<>p_resource_id) THEN
      RETURN jsonb_build_object('state','conflict');
    END IF;
    IF v_event.state='completed' THEN RETURN jsonb_build_object('state','completed'); END IF;
    IF v_event.state='processing' THEN RETURN jsonb_build_object('state','busy'); END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM public.verified_webhook_events WHERE scope=p_scope AND resource_id=p_resource_id AND state='processing') THEN
    RETURN jsonb_build_object('state','busy');
  END IF;
  v_token := gen_random_uuid();
  INSERT INTO public.verified_webhook_events(scope,event_id,resource_id,payload_hash,state,claim_token)
  VALUES (p_scope,p_event_id,p_resource_id,p_payload_hash,'processing',v_token)
  ON CONFLICT (scope,event_id) DO UPDATE SET state='processing',claim_token=v_token,updated_at=now();
  RETURN jsonb_build_object('state','claimed','token',v_token);
END $$;

CREATE FUNCTION public.finish_verified_webhook(p_scope text,p_event_id text,p_token uuid,p_success boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE insufficient_privilege; END IF;
  IF p_success IS NULL OR NOT EXISTS (SELECT 1 FROM public.verified_webhook_events
     WHERE scope=p_scope AND event_id=p_event_id AND claim_token=p_token) THEN
    RAISE EXCEPTION 'Invalid webhook claim' USING ERRCODE='42501';
  END IF;
  UPDATE public.verified_webhook_events SET state=CASE WHEN p_success THEN 'completed' ELSE 'failed' END,updated_at=now()
    WHERE scope=p_scope AND event_id=p_event_id AND claim_token=p_token AND state='processing';
END $$;
REVOKE ALL ON FUNCTION public.claim_verified_webhook(text,text,text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.finish_verified_webhook(text,text,uuid,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_verified_webhook(text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_verified_webhook(text,text,uuid,boolean) TO service_role;

-- Legacy rows remain NULL. New ingestion uses a stable provider recording ID.
ALTER TABLE public.voicemail_messages ADD COLUMN source_recording_id text;
CREATE UNIQUE INDEX voicemail_source_recording_id ON public.voicemail_messages(source_recording_id) WHERE source_recording_id IS NOT NULL;
COMMIT;
