-- ============================================================================
-- H5 — two supply registries the product has been running without:
--   * where eSIM offers come from, and
--   * which numbers users contact for an offline refill.
--
-- Both existed only as literals. `esim_offers_cache.provider` defaults to the
-- string 'esim_go' and nothing anywhere says what that is, whether it is live,
-- or where a second supplier would be configured — which is why the catalogue
-- has been stuck at 50 bundles covering 4 of 21 supported countries with no
-- operator-visible signal. The offline numbers are three system_configs rows
-- still holding the original Oman placeholders (+968 24 555 011x), which no
-- carrier answers.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.esim_suppliers (
  code             text PRIMARY KEY,
  name             text NOT NULL,
  website_url      text,
  api_base_url     text,
  docs_url         text,
  credential_secret text,
  is_active        boolean NOT NULL DEFAULT false,
  priority         integer NOT NULL DEFAULT 100,
  markup_percent_override numeric,
  countries_supported text[] NOT NULL DEFAULT '{}',
  last_sync_at     timestamptz,
  last_sync_status text CHECK (last_sync_status IN ('ok','partial','failed')),
  last_sync_count  integer,
  last_sync_error  text,
  notes            text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.esim_suppliers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.esim_suppliers FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.esim_suppliers TO service_role;

COMMENT ON TABLE public.esim_suppliers IS
  'H5: where eSIM inventory comes from. Deny-all — it holds wholesale economics (markup override) and the names of our API secrets, the same reason esim_offers_cache is not client-readable. markup_percent_override NULL means "use system_configs.ESIM_MARKUP_PERCENT".';

INSERT INTO public.esim_suppliers
  (code, name, website_url, api_base_url, docs_url, credential_secret, is_active, priority, notes)
VALUES
  ('esim_go','eSIM Go','https://www.esim-go.com','https://api.esim-go.com/v2.4','https://docs.esim-go.com',
   'ESIM_GO_API_KEY', true, 10,
   'The only live supplier. Holds all 50 bundles in esim_offers_cache, every one of them 1 GB / 7 days and covering only AE, BD, BH and DE — the fetch is alphabetically truncated at A-D, so 17 of 21 supported countries have no eSIM at all. Fixing that fetch is worth more than adding tariffs or suppliers.'),
  ('zendit','Zendit','https://www.zendit.io','https://api.zendit.io/v1','https://docs.zendit.io',
   'ZENDIT_API_KEY', false, 20,
   'Live for airtime top-ups (780 of 783 provider_offers_cache rows) but not wired for eSIM. Listed here so the eSIM side is a switch rather than a code change.'),
  ('dtone','DTOne','https://www.dtone.com','https://dvs-api.dtone.com/v1','https://dvs-api-doc.dtone.com',
   'DTONE_API_KEY', false, 30,
   'Airtime only today, 3 offers cached. 13 carriers have no Zendit sandbox coverage — this is the intended second source for them.')
ON CONFLICT (code) DO NOTHING;

-- Sync columns derived from what is actually cached, not typed in by hand.
-- `countries` is text[] per row, so it is flattened with a lateral unnest:
-- array_agg over an array column accumulates dimensions and raises 2202E.
UPDATE public.esim_suppliers s SET
  last_sync_at     = c.newest,
  last_sync_count  = c.n,
  last_sync_status = CASE WHEN c.n > 0 THEN 'ok' ELSE 'failed' END,
  countries_supported = COALESCE(
    (SELECT array_agg(DISTINCT cc ORDER BY cc)
     FROM public.esim_offers_cache e, unnest(e.countries) cc
     WHERE e.provider = s.code), '{}')
FROM (
  SELECT provider, count(*) n, max(updated_at) newest
  FROM public.esim_offers_cache GROUP BY provider
) c
WHERE s.code = c.provider;

CREATE TABLE IF NOT EXISTS public.offline_refill_endpoints (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel       text NOT NULL CHECK (channel IN ('sms','whatsapp','ivr')),
  phone_number  text NOT NULL,
  label         text NOT NULL,
  country_code  text,
  provider      text CHECK (provider IN ('twilio','waba','baileys','manual')),
  is_active     boolean NOT NULL DEFAULT true,
  is_primary    boolean NOT NULL DEFAULT false,
  sort_order    integer NOT NULL DEFAULT 100,
  notes         text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT offline_endpoint_e164 CHECK (phone_number ~ '^\+[0-9][0-9 ]{6,20}$')
);

-- One primary per channel. This is what keeps the system_configs mirror
-- unambiguous — without it, "the SMS number" would be whichever row sorted
-- first today.
CREATE UNIQUE INDEX IF NOT EXISTS offline_endpoints_one_primary_per_channel
  ON public.offline_refill_endpoints (channel) WHERE is_primary;

ALTER TABLE public.offline_refill_endpoints ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.offline_refill_endpoints FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.offline_refill_endpoints TO authenticated;
GRANT ALL ON TABLE public.offline_refill_endpoints TO service_role;

DROP POLICY IF EXISTS "Signed-in users can read active endpoints" ON public.offline_refill_endpoints;
CREATE POLICY "Signed-in users can read active endpoints"
  ON public.offline_refill_endpoints FOR SELECT TO authenticated
  USING (is_active);

COMMENT ON TABLE public.offline_refill_endpoints IS
  'H5: the numbers a user contacts to refill with no data. Client-readable (active rows only) so the app can offer a local number per country instead of one global one. The primary row per channel is mirrored into the matching system_configs key by sync_offline_endpoint_configs(), because the offline screen reads that key through a local cache — which is the whole point of that screen and must not be broken by moving the data.';

INSERT INTO public.offline_refill_endpoints (channel, phone_number, label, provider, is_active, is_primary, sort_order, notes)
SELECT 'sms', config_value, 'SMS refill line', 'twilio', true, true, 10,
       'Seeded from system_configs.OFFLINE_SMS_NUMBER. Still the original Oman placeholder — no Twilio number is provisioned yet, so nothing answers it.'
FROM public.system_configs WHERE config_key = 'OFFLINE_SMS_NUMBER'
  AND NOT EXISTS (SELECT 1 FROM public.offline_refill_endpoints WHERE channel='sms');

INSERT INTO public.offline_refill_endpoints (channel, phone_number, label, provider, is_active, is_primary, sort_order, notes)
SELECT 'whatsapp', config_value, 'WhatsApp refill line', 'waba', true, true, 10,
       'Seeded from system_configs.OFFLINE_WHATSAPP_NUMBER. Placeholder — the Meta WABA number is not provisioned.'
FROM public.system_configs WHERE config_key = 'OFFLINE_WHATSAPP_NUMBER'
  AND NOT EXISTS (SELECT 1 FROM public.offline_refill_endpoints WHERE channel='whatsapp');

INSERT INTO public.offline_refill_endpoints (channel, phone_number, label, provider, is_active, is_primary, sort_order, notes)
SELECT 'ivr', config_value, 'Voice / missed-call line', 'twilio', true, true, 10,
       'Seeded from system_configs.OFFLINE_IVR_NUMBER. Placeholder. Serves both the "call us" and "ring once" cards in the app.'
FROM public.system_configs WHERE config_key = 'OFFLINE_IVR_NUMBER'
  AND NOT EXISTS (SELECT 1 FROM public.offline_refill_endpoints WHERE channel='ivr');

-- The mirror. system_configs stays the client's source of truth for the primary
-- number because the offline screen caches that read on-device; this keeps the
-- two from drifting without asking the client to change how it reads.
CREATE OR REPLACE FUNCTION public.sync_offline_endpoint_configs()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT channel, phone_number FROM public.offline_refill_endpoints
    WHERE is_primary AND is_active
  LOOP
    UPDATE public.system_configs
    SET config_value = r.phone_number, updated_at = now()
    WHERE config_key = CASE r.channel
                         WHEN 'sms'      THEN 'OFFLINE_SMS_NUMBER'
                         WHEN 'whatsapp' THEN 'OFFLINE_WHATSAPP_NUMBER'
                         WHEN 'ivr'      THEN 'OFFLINE_IVR_NUMBER'
                       END
      AND config_value IS DISTINCT FROM r.phone_number;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_offline_endpoint_configs() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sync_offline_endpoint_configs() TO service_role;

CREATE OR REPLACE FUNCTION public.trg_fn_sync_offline_endpoints()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.sync_offline_endpoint_configs();
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_offline_endpoints_sync ON public.offline_refill_endpoints;
CREATE TRIGGER trg_offline_endpoints_sync
AFTER INSERT OR UPDATE OR DELETE ON public.offline_refill_endpoints
FOR EACH STATEMENT EXECUTE FUNCTION public.trg_fn_sync_offline_endpoints();
