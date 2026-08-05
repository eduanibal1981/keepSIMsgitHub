-- ============================================================================
-- I8 — where a subscriber goes when KeepSIMs is not the right answer.
--
-- i7 established that a third of the carriers we list cannot be protected the
-- way the product assumes: `usage_required` carriers reset their clock only on
-- a call, an SMS or a data session, and `min_denomination` carriers only count
-- a top-up at or above a voucher threshold. In both cases the honest advice is
-- sometimes "do it yourself, in the operator's own app" — and until now the
-- product had nowhere to say that and no data to say it with.
--
-- This registry is that data. One row per carrier, holding the operator's own
-- self-service channel: the name its app is published under, store links, a
-- web top-up page, a USSD string.
--
-- What it deliberately does NOT do is invent store URLs. Every url column ships
-- NULL. The seed carries app *names* only, and only for the operators whose app
-- is published under a name that differs from the carrier's own — "Ana
-- Vodafone", "mySTC", "Jazz World" — because that is the only case where
-- knowing the name saves the user anything. Everywhere else the client already
-- has the carrier name and says "<Carrier>'s official app". `verified_at` is
-- NULL on every seeded row: the UI must present an unverified name as a search
-- hint, never as a link, and must tell the user to check the publisher. A
-- prepaid telecom app is one of the most cloned things in either store, and a
-- fabricated link is how you send someone to the clone.
--
-- Filling in the URLs is an owner/admin task, done through
-- admin_upsert_carrier_self_service() — same shape as every other H1 admin
-- write: a jsonb patch, an absent key means unchanged, an unknown key is
-- refused, and every write lands in admin_audit_log.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.carrier_self_service (
  carrier_id     uuid PRIMARY KEY REFERENCES public.carriers(id) ON DELETE CASCADE,

  -- What the operator publishes its app as. NULL means "we do not know", which
  -- the client renders as the carrier's own name — never as a guess.
  app_name       text,
  android_url    text,
  ios_url        text,
  web_topup_url  text,

  -- Dialled on the handset itself, so it works with no data at all. The one
  -- channel a traveller's relative at home can always use.
  ussd_code      text,

  -- Operator-sourced English detail. Same contract as
  -- carrier_rules.activity_requirement_note: not translatable content we own,
  -- and paraphrasing it is how a wrong claim survives.
  note           text,

  -- NULL means nobody has checked this against the operator. The client must
  -- degrade to a search when it is NULL rather than presenting a link.
  verified_at    timestamptz,
  source_url     text,

  updated_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.carrier_self_service ENABLE ROW LEVEL SECURITY;

-- Catalogue data, exactly like `carriers`: readable by anyone signed in, and
-- writable by nothing that is not service_role. Note the explicit REVOKE — a
-- new public table arrives carrying the default GRANT ALL to anon and
-- authenticated (32 tables in this database still do; see G5b), and TRUNCATE is
-- not RLS-filtered.
REVOKE ALL ON TABLE public.carrier_self_service FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.carrier_self_service TO authenticated;
GRANT ALL ON TABLE public.carrier_self_service TO service_role;

DROP POLICY IF EXISTS "Anyone signed in can read carrier self-service"
  ON public.carrier_self_service;
CREATE POLICY "Anyone signed in can read carrier self-service"
  ON public.carrier_self_service FOR SELECT TO authenticated USING (true);

COMMENT ON TABLE public.carrier_self_service IS
  'I8: the operator''s own top-up channel, for the cases where KeepSIMs'' automation is not the right answer (usage_required carriers, and any line with no automation paid for). URLs ship NULL on purpose — an unverified store link for a prepaid telecom app points at a clone as often as not. verified_at NULL means the client must render a search, not a link.';

-- ---------------------------------------------------------------------------
-- Seed: app names only, and only where the app's name is not simply the
-- carrier's name. Matched on (carrier name, country) because carrier names
-- repeat across countries — there are four Zains and three Vodafones.
-- ---------------------------------------------------------------------------
INSERT INTO public.carrier_self_service (carrier_id, app_name, verified_at)
SELECT c.id, s.app_name, NULL
FROM (VALUES
  ('EG','Vodafone Egypt',        'Ana Vodafone'),
  ('EG','Etisalat Egypt',        'My Etisalat'),
  ('EG','WE (Telecom Egypt)',    'My WE'),
  ('AE','Etisalat (e&)',         'e& UAE'),
  ('SA','STC',                   'mySTC'),
  ('PK','Jazz',                  'Jazz World'),
  ('PK','Zong',                  'My Zong'),
  ('PK','Ufone',                 'My Ufone'),
  ('PK','Telenor Pakistan',      'My Telenor'),
  ('IN','Jio',                   'MyJio'),
  ('IN','Airtel',                'Airtel Thanks'),
  ('IN','BSNL',                  'BSNL Selfcare'),
  ('BD','Grameenphone',          'MyGP'),
  ('BD','Robi',                  'My Robi'),
  ('BD','Banglalink',            'MyBL'),
  ('BD','Teletalk',              'MyTeletalk'),
  ('BD','Airtel Bangladesh',     'My Airtel'),
  ('LK','Dialog',                'MyDialog'),
  ('PH','Globe',                 'GlobeOne'),
  ('PH','Smart',                 'GigaLife'),
  ('TR','Vodafone Turkey',       'Vodafone Yanımda'),
  ('DE','Telekom (T-Mobile DE)', 'MeinMagenta'),
  ('DE','Vodafone Germany',      'MeinVodafone'),
  ('DE','O2 Germany',            'Mein o2'),
  ('GB','EE',                    'My EE'),
  ('GB','O2 UK',                 'My O2'),
  ('GB','Vodafone UK',           'My Vodafone'),
  ('US','AT&T',                  'myAT&T'),
  ('US','Verizon',               'My Verizon')
) AS s(iso, carrier_name, app_name)
JOIN public.countries co ON co.iso_code = s.iso
JOIN public.carriers  c  ON c.country_id = co.id AND c.name = s.carrier_name
ON CONFLICT (carrier_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- The admin write path. Deliberately the only write path: `authenticated` gets
-- SELECT and nothing else, so there is no policy for a client to slip through.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_upsert_carrier_self_service(
  p_carrier_id uuid,
  p_patch      jsonb,
  p_note       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_allowed text[] := ARRAY['app_name','android_url','ios_url','web_topup_url',
                            'ussd_code','note','verified','source_url'];
  v_bad     text;
  v_before  jsonb;
  v_after   jsonb;
  v_name    text;
BEGIN
  PERFORM public.assert_admin();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Nothing to change' USING ERRCODE = 'KS467';
  END IF;

  SELECT string_agg(k, ', ') INTO v_bad
  FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'Unknown field(s): %', v_bad USING ERRCODE = 'KS467';
  END IF;

  SELECT c.name INTO v_name FROM public.carriers c WHERE c.id = p_carrier_id;
  IF v_name IS NULL THEN
    RAISE EXCEPTION 'Unknown carrier %', p_carrier_id USING ERRCODE = 'KS461';
  END IF;

  SELECT to_jsonb(s) INTO v_before
  FROM public.carrier_self_service s WHERE s.carrier_id = p_carrier_id;

  -- No ON CONFLICT here: the table has CHECK-free columns, but the H3c lesson
  -- is that Postgres evaluates constraints before it detects a conflict, so an
  -- explicit "does the row exist" is the shape that survives a later CHECK.
  IF v_before IS NULL THEN
    INSERT INTO public.carrier_self_service (carrier_id) VALUES (p_carrier_id);
    SELECT to_jsonb(s) INTO v_before
    FROM public.carrier_self_service s WHERE s.carrier_id = p_carrier_id;
  END IF;

  UPDATE public.carrier_self_service SET
    app_name      = CASE WHEN p_patch ? 'app_name'
                         THEN NULLIF(btrim(p_patch ->> 'app_name'), '') ELSE app_name END,
    android_url   = CASE WHEN p_patch ? 'android_url'
                         THEN NULLIF(btrim(p_patch ->> 'android_url'), '') ELSE android_url END,
    ios_url       = CASE WHEN p_patch ? 'ios_url'
                         THEN NULLIF(btrim(p_patch ->> 'ios_url'), '') ELSE ios_url END,
    web_topup_url = CASE WHEN p_patch ? 'web_topup_url'
                         THEN NULLIF(btrim(p_patch ->> 'web_topup_url'), '') ELSE web_topup_url END,
    ussd_code     = CASE WHEN p_patch ? 'ussd_code'
                         THEN NULLIF(btrim(p_patch ->> 'ussd_code'), '') ELSE ussd_code END,
    note          = CASE WHEN p_patch ? 'note'
                         THEN NULLIF(btrim(p_patch ->> 'note'), '') ELSE note END,
    source_url    = CASE WHEN p_patch ? 'source_url'
                         THEN NULLIF(btrim(p_patch ->> 'source_url'), '') ELSE source_url END,
    -- `verified` is a verb, not a timestamp the caller supplies: the admin is
    -- asserting they checked it *now*. Letting a caller post a date would let a
    -- row claim it was verified on a day nobody looked at it.
    verified_at   = CASE WHEN p_patch ? 'verified'
                         THEN (CASE WHEN (p_patch ->> 'verified')::boolean
                                    THEN now() ELSE NULL END)
                         ELSE verified_at END,
    updated_at    = now()
  WHERE carrier_id = p_carrier_id;

  SELECT to_jsonb(s) INTO v_after
  FROM public.carrier_self_service s WHERE s.carrier_id = p_carrier_id;

  PERFORM public.admin_log('carrier_self_service.upsert', 'carrier',
                           p_carrier_id::text, v_before, v_after, p_note);

  RETURN jsonb_build_object('success', true, 'carrier', v_name);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_carrier_self_service(uuid,jsonb,text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_carrier_self_service(uuid,jsonb,text)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.admin_upsert_carrier_self_service(uuid,jsonb,text) IS
  'I8: the only write path into carrier_self_service. assert_admin() gate, jsonb patch (absent key = unchanged, unknown key refused), admin_audit_log row. Pass {"verified": true} to stamp verified_at with now(); a caller may not supply the date itself.';

-- ---------------------------------------------------------------------------
-- Read side for the admin app, so the gaps are visible rather than implied.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_carrier_self_service()
RETURNS TABLE (
  carrier_id    uuid,
  carrier_name  text,
  country       text,
  iso_code      text,
  app_name      text,
  android_url   text,
  ios_url       text,
  web_topup_url text,
  ussd_code     text,
  note          text,
  verified_at   timestamptz,
  source_url    text,
  activity_requirement text,
  live_lines    bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT c.id,
         c.name,
         co.name,
         co.iso_code,
         s.app_name,
         s.android_url,
         s.ios_url,
         s.web_topup_url,
         s.ussd_code,
         s.note,
         s.verified_at,
         s.source_url,
         COALESCE(cr.activity_requirement, 'recharge_ok'),
         (SELECT count(*) FROM public.sim_lines sl WHERE sl.carrier_id = c.id)
  FROM public.carriers c
  JOIN public.countries co ON co.id = c.country_id
  LEFT JOIN public.carrier_self_service s ON s.carrier_id = c.id
  LEFT JOIN public.carrier_rules cr ON cr.carrier_id = c.id
  ORDER BY co.iso_code, c.name;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_carrier_self_service() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_carrier_self_service()
  TO authenticated, service_role;
