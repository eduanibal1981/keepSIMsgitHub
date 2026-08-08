-- J7 — outbound admin email through Resend.
--
-- A power user composes in `keep_sims_admin`, `admin_send_email()` validates
-- and queues, and the `send-admin-email` Edge Function delivers. The split is
-- not ceremony: the RPC runs inside the caller's transaction and must not
-- depend on a third-party HTTP call, and the Resend key must never be reachable
-- from anything a client can call.
--
-- ⚠️ THIS IS AN OUTWARD-FACING CAPABILITY. A signed-in power user can send mail
-- from a domain that passes SPF/DKIM as KeepSIMs. Four things contain that:
--
--   1. The sender is validated against ADMIN_EMAIL_FROM_OPTIONS. A caller
--      cannot pick an arbitrary address on the domain.
--   2. The body is PLAIN TEXT. The Edge Function escapes it and wraps it in a
--      fixed template; no caller-supplied HTML is ever rendered. An admin form
--      that emits arbitrary HTML from a verified domain is a phishing kit.
--   3. Recipients are capped (ADMIN_EMAIL_MAX_RECIPIENTS) and rate limited.
--      This is correspondence, not campaigns — those go through the Campaigns
--      feature, where marketing consent is actually checked.
--   4. Every send writes an `admin_emails` row AND an `admin_audit_log` row.
--
-- ADMIN_EMAIL_ENABLED ships **true**, which departs from the usual
-- ship-it-switched-off stance, deliberately: this is an internal tool the owner
-- asked for in order to use it immediately, not customer-facing capability, and
-- a switch they have to hunt for would defeat the request. The switch exists so
-- it can be killed instantly if an admin session is ever compromised.

BEGIN;

CREATE TABLE IF NOT EXISTS public.admin_emails (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at          timestamptz NOT NULL DEFAULT now(),
  created_by          uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  from_address        text NOT NULL,
  to_addresses        text[] NOT NULL,
  cc_addresses        text[] NOT NULL DEFAULT '{}',
  reply_to            text,
  subject             text NOT NULL,
  body_text           text NOT NULL,
  status              text NOT NULL DEFAULT 'queued'
                        CHECK (status IN ('queued','sending','sent','failed')),
  provider_message_id text,
  error               text,
  sent_at             timestamptz,
  note                text
);

CREATE INDEX IF NOT EXISTS idx_admin_emails_status  ON public.admin_emails (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_emails_created ON public.admin_emails (created_at DESC);

-- Deny-all. The outbox holds correspondence with partners and customers and is
-- reachable only through admin_list_emails().
ALTER TABLE public.admin_emails ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_emails FROM anon, authenticated, public;
GRANT ALL ON public.admin_emails TO service_role;

INSERT INTO public.system_configs (config_key, config_value) VALUES
  ('ADMIN_EMAIL_ENABLED',       'true'),
  ('ADMIN_EMAIL_FROM',          'admin@keepsims.com'),
  ('ADMIN_EMAIL_FROM_OPTIONS',  'admin@keepsims.com,support@keepsims.com,alerts@keepsims.com'),
  ('ADMIN_EMAIL_FROM_NAME',     'KeepSIMs'),
  ('ADMIN_EMAIL_MAX_RECIPIENTS','10'),
  ('RATE_LIMIT_ADMIN_EMAIL',    '20/60')
ON CONFLICT (config_key) DO NOTHING;

-- Meta rows are NOT optional: J6 established that a config key without one is
-- unsettable from the admin app entirely (validate_config_value returns "not a
-- known configuration key" and admin_set_config raises KS466). Shipping the
-- kill switch without one would make it unusable in exactly the emergency it
-- exists for.
INSERT INTO public.system_config_meta
  (config_key, label, group_name, value_type, min_value, max_value, unit, description, is_sensitive, is_readonly, sort_order)
VALUES
  ('ADMIN_EMAIL_ENABLED', 'Outbound admin email', 'Admin email', 'bool', NULL, NULL, NULL,
   'Lets a power user send an email from a KeepSIMs address through the Compose screen. Turning this off is the kill switch if an admin session is ever compromised — a signed-in admin who can send arbitrary mail from a verified domain is a phishing tool.',
   false, false, 10),
  ('ADMIN_EMAIL_FROM', 'Default sender', 'Admin email', 'text', NULL, NULL, NULL,
   'The address new messages default to. Must also appear in the sender allow-list below, and must be on a domain verified in Resend or Resend rejects the send.',
   false, false, 20),
  ('ADMIN_EMAIL_FROM_OPTIONS', 'Allowed senders', 'Admin email', 'text', NULL, NULL, NULL,
   'Comma-separated allow-list. The RPC refuses any From outside this list, so a compromised admin session cannot send as an arbitrary address on the domain.',
   false, false, 30),
  ('ADMIN_EMAIL_FROM_NAME', 'Sender display name', 'Admin email', 'text', NULL, NULL, NULL,
   'Shown as the friendly name, e.g. KeepSIMs <admin@keepsims.com>.',
   false, false, 40),
  ('ADMIN_EMAIL_MAX_RECIPIENTS', 'Max recipients per message', 'Admin email', 'int', 1, 50, 'people',
   'Caps To + Cc on a single message. This is a one-to-one correspondence tool, not a bulk sender — campaigns belong in the Campaigns feature where consent is checked.',
   false, false, 50),
  ('RATE_LIMIT_ADMIN_EMAIL', 'Admin email send limit', 'Rate limits', 'rate_limit', NULL, NULL, NULL,
   'Calls/minutes for admin_send_email.',
   false, false, 160)
ON CONFLICT (config_key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.kick_admin_email(p_email_id uuid)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_secret text; v_req_id bigint;
BEGIN
  SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'admin_email_secret';
  IF COALESCE(v_secret,'') = '' THEN
    RAISE EXCEPTION 'admin_email_secret missing from Vault' USING ERRCODE = 'KS500';
  END IF;

  SELECT net.http_post(
    url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/send-admin-email',
    headers := jsonb_build_object('Content-Type','application/json','x-sync-secret', v_secret),
    body := jsonb_build_object('email_id', p_email_id),
    timeout_milliseconds := 30000
  ) INTO v_req_id;
  RETURN v_req_id;
END;
$fn$;

REVOKE ALL ON FUNCTION public.kick_admin_email(uuid) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kick_admin_email(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.admin_send_email(
  p_to       text[],
  p_subject  text,
  p_body     text,
  p_cc       text[] DEFAULT '{}',
  p_reply_to text DEFAULT NULL,
  p_from     text DEFAULT NULL,
  p_note     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_admin uuid; v_enabled boolean; v_from text; v_allowed text[];
  v_max integer; v_id uuid; v_addr text; v_all text[]; v_req bigint;
  v_rx text := '^[^@[:space:],]+@[^@[:space:],]+\.[^@[:space:],]+$';
BEGIN
  v_admin := public.assert_admin();
  v_admin := COALESCE(v_admin, auth.uid());

  SELECT COALESCE(NULLIF(config_value,'')::boolean, false) INTO v_enabled
    FROM system_configs WHERE config_key = 'ADMIN_EMAIL_ENABLED';
  IF NOT COALESCE(v_enabled,false) THEN
    RAISE EXCEPTION 'Outbound admin email is switched off' USING ERRCODE = 'KS466';
  END IF;

  PERFORM public.enforce_rate_limit('admin_email', COALESCE(v_admin::text,'admin'));

  SELECT COALESCE(NULLIF(config_value,''), 'admin@keepsims.com') INTO v_from
    FROM system_configs WHERE config_key = 'ADMIN_EMAIL_FROM';
  v_from := lower(trim(COALESCE(NULLIF(trim(p_from),''), v_from)));

  SELECT ARRAY(SELECT lower(trim(x))
               FROM unnest(string_to_array(COALESCE(NULLIF(config_value,''),''), ',')) x
               WHERE trim(x) <> '')
    INTO v_allowed
    FROM system_configs WHERE config_key = 'ADMIN_EMAIL_FROM_OPTIONS';

  IF v_allowed IS NULL OR array_length(v_allowed,1) IS NULL OR NOT (v_from = ANY(v_allowed)) THEN
    RAISE EXCEPTION 'Sender % is not in the allowed sender list', v_from USING ERRCODE = 'KS466';
  END IF;

  SELECT COALESCE(NULLIF(config_value,'')::integer, 10) INTO v_max
    FROM system_configs WHERE config_key = 'ADMIN_EMAIL_MAX_RECIPIENTS';

  IF p_to IS NULL OR array_length(p_to,1) IS NULL THEN
    RAISE EXCEPTION 'At least one recipient is required' USING ERRCODE = 'KS466';
  END IF;

  v_all := ARRAY(SELECT DISTINCT lower(trim(x))
                 FROM unnest(p_to || COALESCE(p_cc,'{}')) x WHERE trim(x) <> '');

  IF array_length(v_all,1) > COALESCE(v_max,10) THEN
    RAISE EXCEPTION 'Too many recipients (% of max %). This is a correspondence tool, not a bulk sender.',
      array_length(v_all,1), v_max USING ERRCODE = 'KS466';
  END IF;

  FOREACH v_addr IN ARRAY v_all LOOP
    IF v_addr !~ v_rx THEN
      RAISE EXCEPTION 'Not a valid email address: %', v_addr USING ERRCODE = 'KS466';
    END IF;
  END LOOP;

  IF p_reply_to IS NOT NULL AND trim(p_reply_to) <> '' AND lower(trim(p_reply_to)) !~ v_rx THEN
    RAISE EXCEPTION 'Reply-to is not a valid email address' USING ERRCODE = 'KS466';
  END IF;

  IF COALESCE(trim(p_subject),'') = '' OR length(p_subject) > 200 THEN
    RAISE EXCEPTION 'Subject is required and must be under 200 characters' USING ERRCODE = 'KS466';
  END IF;
  IF COALESCE(trim(p_body),'') = '' OR length(p_body) > 20000 THEN
    RAISE EXCEPTION 'Body is required and must be under 20000 characters' USING ERRCODE = 'KS466';
  END IF;

  INSERT INTO admin_emails (created_by, from_address, to_addresses, cc_addresses,
                            reply_to, subject, body_text, note)
  VALUES (v_admin, v_from,
          ARRAY(SELECT DISTINCT lower(trim(x)) FROM unnest(p_to) x WHERE trim(x) <> ''),
          ARRAY(SELECT DISTINCT lower(trim(x)) FROM unnest(COALESCE(p_cc,'{}')) x WHERE trim(x) <> ''),
          NULLIF(lower(trim(COALESCE(p_reply_to,''))),''),
          trim(p_subject), p_body, p_note)
  RETURNING id INTO v_id;

  INSERT INTO admin_audit_log (actor_id, action, target_type, target_id, after_value, note)
  VALUES (v_admin, 'admin_email_send', 'admin_email', v_id::text,
          jsonb_build_object('from', v_from, 'to', p_to, 'cc', p_cc, 'subject', trim(p_subject)),
          p_note);

  v_req := public.kick_admin_email(v_id);

  RETURN jsonb_build_object('success', true, 'email_id', v_id, 'status', 'queued', 'request_id', v_req);
END;
$fn$;

REVOKE ALL ON FUNCTION public.admin_send_email(text[],text,text,text[],text,text,text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_send_email(text[],text,text,text[],text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_list_emails(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid, created_at timestamptz, sender_email text, from_address text,
  to_addresses text[], cc_addresses text[], reply_to text, subject text,
  body_text text, status text, provider_message_id text, error text,
  sent_at timestamptz, note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
  SELECT e.id, e.created_at, u.email::text, e.from_address,
         e.to_addresses, e.cc_addresses, e.reply_to, e.subject,
         e.body_text, e.status, e.provider_message_id, e.error, e.sent_at, e.note
    FROM admin_emails e
    LEFT JOIN auth.users u ON u.id = e.created_by
   ORDER BY e.created_at DESC
   LIMIT LEAST(GREATEST(COALESCE(p_limit,50),1), 500);
END;
$fn$;

REVOKE ALL ON FUNCTION public.admin_list_emails(integer) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_emails(integer) TO authenticated;

COMMIT;
