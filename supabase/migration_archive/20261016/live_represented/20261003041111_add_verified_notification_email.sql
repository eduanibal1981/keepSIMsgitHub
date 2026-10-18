-- Keep alternate alert addresses separate from client-editable preferences.
-- A destination is written only after the authenticated verification flow
-- consumes a valid, unexpired code.
CREATE TABLE IF NOT EXISTS public.notification_email_destinations (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  verified_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notification_email_destinations_email_nonempty CHECK (btrim(email) <> '')
);

ALTER TABLE public.notification_email_destinations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.notification_email_destinations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.notification_email_destinations TO service_role;
GRANT INSERT, UPDATE, DELETE ON public.notification_email_destinations TO service_role;

CREATE TABLE IF NOT EXISTS public.notification_email_verification_challenges (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  code_digest text NOT NULL,
  expires_at timestamptz NOT NULL,
  last_sent_at timestamptz NOT NULL,
  window_started_at timestamptz NOT NULL,
  request_count integer NOT NULL DEFAULT 1 CHECK (request_count BETWEEN 1 AND 5),
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count BETWEEN 0 AND 5)
);

ALTER TABLE public.notification_email_verification_challenges ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.notification_email_verification_challenges FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_email_verification_challenges TO service_role;

CREATE OR REPLACE FUNCTION public.begin_notification_email_verification(
  p_user_id uuid,
  p_email text,
  p_code_digest text,
  p_expires_at timestamptz
) RETURNS boolean
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_allowed boolean := false;
BEGIN
  INSERT INTO public.notification_email_verification_challenges AS challenge (
    user_id, email, code_digest, expires_at, last_sent_at,
    window_started_at, request_count, attempt_count
  ) VALUES (
    p_user_id, p_email, p_code_digest, p_expires_at, now(), now(), 1, 0
  )
  ON CONFLICT (user_id) DO UPDATE SET
    email = EXCLUDED.email,
    code_digest = EXCLUDED.code_digest,
    expires_at = EXCLUDED.expires_at,
    last_sent_at = now(),
    window_started_at = CASE
      WHEN challenge.window_started_at <= now() - interval '1 hour'
        THEN now()
      ELSE challenge.window_started_at
    END,
    request_count = CASE
      WHEN challenge.window_started_at <= now() - interval '1 hour'
        THEN 1
      ELSE challenge.request_count + 1
    END,
    attempt_count = 0
  WHERE challenge.last_sent_at <= now() - interval '1 minute'
    AND (
      challenge.window_started_at <= now() - interval '1 hour'
      OR challenge.request_count < 5
    )
  RETURNING true INTO v_allowed;

  RETURN coalesce(v_allowed, false);
END;
$$;

REVOKE ALL ON FUNCTION public.begin_notification_email_verification(uuid, text, text, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.begin_notification_email_verification(uuid, text, text, timestamptz)
  TO service_role;

CREATE OR REPLACE FUNCTION public.consume_notification_email_verification(
  p_user_id uuid,
  p_code_digest text
) RETURNS jsonb
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_challenge public.notification_email_verification_challenges;
BEGIN
  SELECT * INTO v_challenge
  FROM public.notification_email_verification_challenges
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND OR v_challenge.expires_at <= now() OR v_challenge.attempt_count >= 5 THEN
    RETURN jsonb_build_object('valid', false);
  END IF;

  IF v_challenge.code_digest IS DISTINCT FROM p_code_digest THEN
    UPDATE public.notification_email_verification_challenges
      SET attempt_count = attempt_count + 1
      WHERE user_id = p_user_id;
    RETURN jsonb_build_object('valid', false);
  END IF;

  INSERT INTO public.notification_email_destinations (user_id, email, verified_at)
    VALUES (p_user_id, v_challenge.email, now())
    ON CONFLICT (user_id) DO UPDATE
      SET email = EXCLUDED.email, verified_at = EXCLUDED.verified_at;

  DELETE FROM public.notification_email_verification_challenges WHERE user_id = p_user_id;
  RETURN jsonb_build_object('valid', true, 'email', v_challenge.email);
END;
$$;

REVOKE ALL ON FUNCTION public.consume_notification_email_verification(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_notification_email_verification(uuid, text)
  TO service_role;
