-- ============================================================================
-- H2 — system_configs gets a type system.
--
-- `system_configs` is (config_key varchar, config_value varchar) and nothing
-- else: no type, no range, no label, no description. G11 already flagged what
-- that costs — a fat-fingered 50.5 -> 505 in an FX rate multiplies every
-- displayed price by ten with nothing to catch it — and that was the argument
-- for keeping rates in their own table. The same hazard applies to the 70 rows
-- that legitimately live here: APP_FEE_PERCENT is a percentage, RESCUE_ENABLED
-- is a global brake on the one feature that spends users' money unattended, and
-- RATE_LIMIT_* are "N/M" strings whose parse failure does not throw — it makes
-- consume_rate_limit fall back, i.e. it turns a limit off silently, on a money
-- path.
--
-- This adds the missing half: one metadata row per key, and an admin_set_config
-- that refuses anything the metadata says is impossible. Verified at apply
-- time: 70 of 70 live keys have metadata, no metadata row is an orphan, and
-- every current value passes its own validator — so the metadata describes what
-- is actually deployed rather than what someone hoped was.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.system_config_meta (
  config_key   text PRIMARY KEY,
  label        text NOT NULL,
  group_name   text NOT NULL,
  value_type   text NOT NULL CHECK (value_type IN
                 ('int','decimal','bool','text','url','phone','enum','rate_limit','timestamp')),
  min_value    numeric,
  max_value    numeric,
  enum_options text[],
  unit         text,
  description  text NOT NULL,
  is_sensitive boolean NOT NULL DEFAULT false,
  is_readonly  boolean NOT NULL DEFAULT false,
  sort_order   integer NOT NULL DEFAULT 100
);

ALTER TABLE public.system_config_meta ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.system_config_meta FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.system_config_meta TO service_role;

COMMENT ON TABLE public.system_config_meta IS
  'H2: the type, range and meaning of every system_configs key. Deny-all; read it through admin_list_configs(). is_readonly marks rows the system writes (heartbeats, FX_LAST_REFRESH_AT) — an admin editing those would be lying to the code that reads them.';

-- Returns NULL when the value is acceptable, else the reason it is not.
CREATE OR REPLACE FUNCTION public.validate_config_value(p_key text, p_value text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  m   RECORD;
  n   numeric;
  cap integer;
  per integer;
BEGIN
  SELECT * INTO m FROM public.system_config_meta WHERE config_key = p_key;
  IF NOT FOUND THEN
    RETURN format('%s is not a known configuration key', p_key);
  END IF;

  IF m.is_readonly THEN
    RETURN format('%s is written by the system and cannot be edited here', p_key);
  END IF;

  IF p_value IS NULL OR btrim(p_value) = '' THEN
    RETURN 'Value cannot be empty';
  END IF;

  CASE m.value_type
    WHEN 'bool' THEN
      IF lower(p_value) NOT IN ('true','false') THEN
        RETURN 'Must be true or false';
      END IF;

    WHEN 'int' THEN
      BEGIN n := p_value::numeric; EXCEPTION WHEN OTHERS THEN RETURN 'Must be a whole number'; END;
      IF n <> trunc(n) THEN RETURN 'Must be a whole number'; END IF;
      IF m.min_value IS NOT NULL AND n < m.min_value THEN
        RETURN format('Must be at least %s', trim(to_char(m.min_value,'FM999999990.99')));
      END IF;
      IF m.max_value IS NOT NULL AND n > m.max_value THEN
        RETURN format('Must be at most %s', trim(to_char(m.max_value,'FM999999990.99')));
      END IF;

    WHEN 'decimal' THEN
      BEGIN n := p_value::numeric; EXCEPTION WHEN OTHERS THEN RETURN 'Must be a number'; END;
      IF m.min_value IS NOT NULL AND n < m.min_value THEN
        RETURN format('Must be at least %s', trim(to_char(m.min_value,'FM999999990.99')));
      END IF;
      IF m.max_value IS NOT NULL AND n > m.max_value THEN
        RETURN format('Must be at most %s', trim(to_char(m.max_value,'FM999999990.99')));
      END IF;

    WHEN 'enum' THEN
      IF m.enum_options IS NULL OR NOT (p_value = ANY (m.enum_options)) THEN
        RETURN format('Must be one of: %s', array_to_string(m.enum_options, ', '));
      END IF;

    WHEN 'phone' THEN
      -- E.164 with optional spaces, which is how the existing rows are written.
      IF p_value !~ '^\+[0-9][0-9 ]{6,20}$' THEN
        RETURN 'Must be an international number starting with + (e.g. +968 24 555 0112)';
      END IF;

    WHEN 'url' THEN
      IF p_value !~ '^https?://[^\s]+$' THEN
        RETURN 'Must be an http(s) URL';
      END IF;

    WHEN 'rate_limit' THEN
      IF p_value !~ '^[0-9]+/[0-9]+$' THEN
        RETURN 'Must be calls/minutes, e.g. 10/60';
      END IF;
      cap := split_part(p_value, '/', 1)::integer;
      per := split_part(p_value, '/', 2)::integer;
      IF cap < 1 OR cap > 100000 THEN RETURN 'Call count must be 1..100000'; END IF;
      IF per < 1 OR per > 44640  THEN RETURN 'Window must be 1..44640 minutes'; END IF;

    ELSE
      IF length(p_value) > 500 THEN RETURN 'Too long (max 500 characters)'; END IF;
  END CASE;

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.validate_config_value(text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.validate_config_value(text,text) TO service_role;

-- Read side. Includes the DEVICE_RISK_% rows the RESTRICTIVE client policy
-- hides: an admin who cannot see the fraud thresholds cannot tune them.
CREATE OR REPLACE FUNCTION public.admin_list_configs()
RETURNS TABLE (
  config_key   text,
  config_value text,
  label        text,
  group_name   text,
  value_type   text,
  min_value    numeric,
  max_value    numeric,
  enum_options text[],
  unit         text,
  description  text,
  is_sensitive boolean,
  is_readonly  boolean,
  sort_order   integer,
  updated_at   timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT
    c.config_key::text,
    c.config_value::text,
    COALESCE(m.label, c.config_key::text),
    COALESCE(m.group_name, 'Unclassified'),
    COALESCE(m.value_type, 'text'),
    m.min_value, m.max_value, m.enum_options, m.unit,
    COALESCE(m.description, 'No description recorded for this key.'),
    COALESCE(m.is_sensitive, false),
    COALESCE(m.is_readonly, false),
    COALESCE(m.sort_order, 999),
    c.updated_at
  FROM public.system_configs c
  LEFT JOIN public.system_config_meta m ON m.config_key = c.config_key::text
  ORDER BY COALESCE(m.group_name, 'Unclassified'), COALESCE(m.sort_order, 999), c.config_key;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_configs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_configs() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_set_config(
  p_key   text,
  p_value text,
  p_note  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_before text;
  v_error  text;
BEGIN
  PERFORM public.assert_admin();

  SELECT config_value INTO v_before FROM public.system_configs WHERE config_key = p_key;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown configuration key %', p_key USING ERRCODE = 'KS465';
  END IF;

  v_error := public.validate_config_value(p_key, p_value);
  IF v_error IS NOT NULL THEN
    RAISE EXCEPTION '%', v_error USING ERRCODE = 'KS466';
  END IF;

  IF v_before = p_value THEN
    RETURN jsonb_build_object('success', true, 'changed', false, 'value', p_value);
  END IF;

  UPDATE public.system_configs
  SET config_value = p_value, updated_at = now()
  WHERE config_key = p_key;

  PERFORM public.admin_log(
    'config.set', 'system_config', p_key,
    jsonb_build_object('value', v_before),
    jsonb_build_object('value', p_value),
    p_note
  );

  RETURN jsonb_build_object('success', true, 'changed', true,
                            'key', p_key, 'before', v_before, 'value', p_value);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_config(text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_config(text,text,text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Seed: every key that exists today (70 of 70).
-- ---------------------------------------------------------------------------
INSERT INTO public.system_config_meta
  (config_key, label, group_name, value_type, min_value, max_value, enum_options, unit, description, is_sensitive, is_readonly, sort_order)
VALUES
  ('APP_FEE_PERCENT','Service fee','Fees & pricing','decimal',0,100,NULL,'%','KeepSIMs'' cut of every refill, applied to the base cost. calculate_topup_fees and the client quote both read this row — changing it here changes both with no app release.',false,false,10),
  ('BASE_SERVICE_FEE_USD','Yearly line fee','Fees & pricing','decimal',0,1000,NULL,'USD','Charged once a year per line on both paid tiers. pay_plan_fee_from_wallet prices from this row.',false,false,20),
  ('PREMIUM_MARGIN_PERCENT','Premium margin (percent)','Fees & pricing','decimal',0,100,NULL,'%','Percentage part of the premium-tier margin. Needs both parts: the flat component is ~2.6% of a $277 plan but ~41% of a $13 one.',false,false,30),
  ('PREMIUM_MARGIN_PER_REFILL_USD','Premium margin (flat)','Fees & pricing','decimal',0,1000,NULL,'USD','Flat part of the premium-tier margin, per refill.',false,false,40),
  ('ESIM_MARKUP_PERCENT','eSIM markup','Fees & pricing','decimal',0,500,NULL,'%','Retail markup over the supplier''s wholesale eSIM price. The esim_offers view applies it; wholesale is never exposed to clients.',false,false,50),

  ('ACTIVE_FULFILLMENT_METHOD','Default gateway','Refill engine','enum',NULL,NULL,ARRAY['MANUAL','TASKER_SCRIPT','API'],NULL,'Fallback route for a refill whose carrier has no gateway of its own. route_topup_execution() reads it on INSERT.',false,false,10),
  ('FORECAST_ALERT_LEAD_DAYS','Forecast warning lead','Refill engine','int',1,60,NULL,'days','How far ahead of predicted depletion a line is warned.',false,false,20),
  ('FORECAST_DEFAULT_VALIDITY_DAYS','Assumed top-up validity','Refill engine','int',1,365,NULL,'days','Validity assumed for a carrier with no rule of its own.',false,false,30),
  ('FORECAST_MIN_CYCLE_DAYS','Minimum refill cycle','Refill engine','int',1,90,NULL,'days','Floor on the suggested gap between refills, so a noisy forecast cannot propose a daily charge.',false,false,40),
  ('RESCUE_ENABLED','Auto-rescue master switch','Refill engine','bool',NULL,NULL,NULL,NULL,'Global brake on SIM insurance. This is the only feature that spends a user''s money with no human in the loop; per-line opt-in defaults off, so this defaults on.',false,false,50),
  ('RESCUE_GRACE_HOURS','Auto-rescue grace','Refill engine','int',1,720,NULL,'hours','Wait between warning a line and rescuing it.',false,false,60),
  ('RESCUE_COOLDOWN_DAYS','Auto-rescue cooldown','Refill engine','int',1,365,NULL,'days','Minimum gap between two rescues of the same line.',false,false,70),
  ('RESCUE_MAX_PER_RUN','Auto-rescue batch cap','Refill engine','int',1,1000,NULL,'lines','Ceiling on lines rescued in one hourly run — the blast radius if the forecast goes wrong.',false,false,80),
  ('GEO_FLAP_GUARD_HOURS','Geo-fence flap guard','Refill engine','int',0,72,NULL,'hours','Suppresses repeat travel triggers when a device bounces across a border.',false,false,90),

  ('OFFLINE_SMS_NUMBER','SMS number','Offline refill','phone',NULL,NULL,NULL,NULL,'The number users text to refill without data. Shown in the app and cached on-device, because that screen exists for when the device is offline.',false,false,10),
  ('OFFLINE_WHATSAPP_NUMBER','WhatsApp number','Offline refill','phone',NULL,NULL,NULL,NULL,'The WhatsApp number users message to refill without data.',false,false,20),
  ('OFFLINE_IVR_NUMBER','Voice / missed-call number','Offline refill','phone',NULL,NULL,NULL,NULL,'The number users call or ring once to trigger a refill.',false,false,30),
  ('OFFLINE_SMS_MESSAGE_FEE_USD','SMS message fee','Offline refill','decimal',0,100,NULL,'USD','Per-inbound-message cost passed to the wallet by calculate_topup_fees when refill_channel = sms.',false,false,40),
  ('OFFLINE_WHATSAPP_MESSAGE_FEE_USD','WhatsApp message fee','Offline refill','decimal',0,100,NULL,'USD','Per-inbound-message cost for the WhatsApp channel.',false,false,50),
  ('OFFLINE_MISSED_CALL_FEE_USD','Missed-call fee','Offline refill','decimal',0,100,NULL,'USD','Per-inbound-call cost for the voice channel.',false,false,60),

  ('DEFAULT_WHATSAPP_SERVER_URL','WhatsApp VPS URL','Notifications','url',NULL,NULL,NULL,NULL,'Base URL of the self-hosted WhatsApp sender. The channel also needs WHATSAPP_VPS_API_KEY set as an Edge Function secret, or dispatch-alert skips it.',false,false,10),

  ('ESIM_LOW_DATA_THRESHOLD_PERCENT','eSIM low-data alert','eSIM','int',1,99,NULL,'%','Remaining-data percentage that triggers the esim_low_data notification.',false,false,10),
  ('ESIM_STALE_ORDER_HOURS','Stale eSIM order','eSIM','int',1,168,NULL,'hours','An unfulfilled eSIM order older than this is treated as stuck.',false,false,20),

  ('PRICE_DROP_THRESHOLD_PERCENT','Price-drop threshold','Offers & prices','int',1,90,NULL,'%','How far a price must fall against its baseline before a watcher is alerted.',false,false,10),
  ('PRICE_WATCH_BASELINE_DAYS','Price baseline window','Offers & prices','int',1,365,NULL,'days','Look-back used to compute "the usual price".',false,false,20),
  ('PRICE_WATCH_COOLDOWN_DAYS','Price alert cooldown','Offers & prices','int',0,90,NULL,'days','Minimum gap between two alerts for the same watch.',false,false,30),
  ('PRICE_HISTORY_RETENTION_DAYS','Price history retention','Offers & prices','int',7,3650,NULL,'days','How long offer_price_history rows are kept.',false,false,40),

  ('FX_DISPLAY_ENABLED','Show local currency','Currency (display only)','bool',NULL,NULL,NULL,NULL,'Master switch for the multi-currency display layer. Every charge stays in USD regardless — this only affects the secondary ≈ figure.',false,false,10),
  ('FX_MAX_AGE_HOURS','FX staleness limit','Currency (display only)','int',1,720,NULL,'hours','Past this age the server stops returning a local currency at all and answers USD. Decided server-side on purpose: a client deciding it disagrees whenever its clock is wrong.',false,false,20),
  ('FX_MAX_MOVE_PERCENT','FX circuit breaker','Currency (display only)','decimal',1,100,NULL,'%','A refresh that would move a rate by more than this is refused. 25 is deliberately tight — it caught a real 39.5% TRY move that was a bad seed, not a bad quote.',false,false,30),
  ('FX_LAST_REFRESH_AT','Last FX refresh','Currency (display only)','timestamp',NULL,NULL,NULL,NULL,'Written by refresh-fx-rates. Read-only here.',false,true,40),

  ('GIFT_MIN_USD','Minimum gift','Wallet & payments','decimal',0,10000,NULL,'USD','Smallest wallet credit one user may send another.',false,false,10),
  ('GIFT_MAX_USD','Maximum gift','Wallet & payments','decimal',0,10000,NULL,'USD','Largest single gift.',false,false,20),
  ('GIFT_DAILY_MAX_USD','Daily gift cap','Wallet & payments','decimal',0,100000,NULL,'USD','Total a sender may gift in 24 hours.',false,false,30),
  ('PAYPAL_MIN_DEPOSIT_USD','Minimum deposit','Wallet & payments','decimal',0.5,1000,NULL,'USD','Floor on a PayPal top-up.',false,false,40),
  ('PAYPAL_MAX_DEPOSIT_USD','Maximum deposit','Wallet & payments','decimal',1,100000,NULL,'USD','Ceiling on a single PayPal top-up.',false,false,50),
  ('WALLET_DUST_FORFEIT_USD','Dust forfeit threshold','Wallet & payments','decimal',0,100,NULL,'USD','Balance below which a closing wallet is forfeited rather than settled.',false,false,60),

  ('REFERRAL_DAILY_POINT_CAP','Referral daily cap','Referrals','int',1,1000,NULL,'points','Ceiling on points one account can earn per day.',false,false,10),

  ('ACCOUNT_DELETION_GRACE_DAYS','Deletion grace period','System','int',1,90,NULL,'days','How long a requested account deletion sits recoverable before purge-accounts removes it.',false,false,10),
  ('WORKER_ESIM_FULFILLMENT_HEARTBEAT','eSIM worker heartbeat','System','timestamp',NULL,NULL,NULL,NULL,'Written by the eSIM fulfilment worker on the VM. Read-only here — it is how you tell the worker is alive.',false,true,20),

  ('RATE_LIMIT_INSTANT_REFILL','Instant refill','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per user. Money path.',false,false,10),
  ('RATE_LIMIT_ESIM_PURCHASE','eSIM purchase','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per user. Money path.',false,false,20),
  ('RATE_LIMIT_GIFT_CREDIT','Gift credit','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per user. Sits immediately before the recipient email lookup — the app''s only enumeration surface.',false,false,30),
  ('RATE_LIMIT_PLAN_FEE','Plan fee','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per user. Money path.',false,false,40),
  ('RATE_LIMIT_WALLET_DEDUCT','Wallet deduct','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per user. Money path.',false,false,50),
  ('RATE_LIMIT_OFFLINE_COMMAND','Offline command','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per inbound sender on the SMS/WhatsApp channel.',false,false,60),
  ('RATE_LIMIT_ACCOUNT_DELETE','Account deletion','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per user.',false,false,70),
  ('RATE_LIMIT_DATA_EXPORT','Data export','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per user. Expensive query.',false,false,80),
  ('RATE_LIMIT_APPLY_REFERRAL','Apply referral','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per user.',false,false,90),
  ('RATE_LIMIT_REFERRAL_REDEEM','Redeem referral','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per user. Money path.',false,false,100),
  ('RATE_LIMIT_DETECT_COUNTRY','Detect country','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per user. Billed third-party lookup.',false,false,110),
  ('RATE_LIMIT_DEVICE_TOUCH','Device touch','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per device.',false,false,120),
  ('RATE_LIMIT_DEVICE_BLOCK_REPORT','Device block report','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per device.',false,false,130),
  ('RATE_LIMIT_WEBHOOK_IP','Webhook per IP','Rate limits','rate_limit',NULL,NULL,NULL,'calls/min','Per source IP across the public webhooks.',false,false,140),

  ('DEVICE_RISK_ENABLED','Risk scoring on','Fraud & device risk','bool',NULL,NULL,NULL,NULL,'Whether device risk is assessed at all. Assessment is cheap and observable; leave on.',true,false,10),
  ('DEVICE_RISK_ENFORCE','Risk enforcement on','Fraud & device risk','bool',NULL,NULL,NULL,NULL,'Whether a deny decision actually blocks. Ships false: the model observes for a while before it is allowed to refuse a real payment.',true,false,20),
  ('DEVICE_RISK_CHALLENGE_SCORE','Challenge at score','Fraud & device risk','int',0,100,NULL,'points','Score at which a payment is challenged rather than accepted.',true,false,30),
  ('DEVICE_RISK_DENY_SCORE','Deny at score','Fraud & device risk','int',0,100,NULL,'points','Score at which a payment is refused outright.',true,false,40),
  ('DEVICE_RISK_WINDOW_HOURS','Velocity window','Fraud & device risk','int',1,720,NULL,'hours','Look-back over which the velocity counters are computed.',true,false,50),
  ('DEVICE_RISK_MAX_ACCOUNTS','Accounts per device','Fraud & device risk','int',1,50,NULL,'accounts','Distinct accounts one install may sign into before it scores.',true,false,60),
  ('DEVICE_RISK_MAX_DEVICES_PER_USER','Devices per account','Fraud & device risk','int',1,100,NULL,'devices','Distinct installs one account may use before it scores.',true,false,70),
  ('DEVICE_RISK_MAX_CARDS','Cards per device','Fraud & device risk','int',1,20,NULL,'cards','Distinct cards seen on one device. Unexercised today: PayPal stores no cards here.',true,false,80),
  ('DEVICE_RISK_MAX_DEPOSITS','Deposits per window','Fraud & device risk','int',1,100,NULL,'deposits','Deposit attempts per device per window.',true,false,90),
  ('DEVICE_RISK_MAX_DEPOSIT_USD','Deposit value per window','Fraud & device risk','decimal',0,100000,NULL,'USD','Total deposited per device per window.',true,false,100),
  ('DEVICE_RISK_MAX_FAILED_CAPTURES','Failed captures','Fraud & device risk','int',1,50,NULL,'attempts','Failed payment captures per device per window — the card-testing signal.',true,false,110),
  ('DEVICE_RISK_NEW_DEVICE_HOURS','New-device age','Fraud & device risk','int',1,720,NULL,'hours','How long an install counts as new.',true,false,120),
  ('DEVICE_RISK_NEW_DEVICE_MAX_USD','New-device value cap','Fraud & device risk','decimal',0,100000,NULL,'USD','Spend above this on a new device scores. It can never deny on its own.',true,false,130),
  ('DEVICE_RISK_MISSING_DEVICE_SCORE','No device id penalty','Fraud & device risk','int',0,100,NULL,'points','Cost of arriving with no device id. Deliberately non-zero but non-fatal: old builds must not break, scripts must not be free.',true,false,140),
  ('APP_CHECK_ENFORCE','App Check enforcement','Fraud & device risk','bool',NULL,NULL,NULL,NULL,'Whether a missing or invalid attestation blocks. Ships false; yields nothing until Android is registered in the Firebase console.',true,false,150),
  ('APP_CHECK_ENFORCE_PLATFORMS','App Check platforms','Fraud & device risk','text',NULL,NULL,NULL,NULL,'Comma-separated platforms enforcement applies to. iOS attestation is impossible until an Apple account exists.',true,false,160)
ON CONFLICT (config_key) DO UPDATE SET
  label = EXCLUDED.label, group_name = EXCLUDED.group_name, value_type = EXCLUDED.value_type,
  min_value = EXCLUDED.min_value, max_value = EXCLUDED.max_value, enum_options = EXCLUDED.enum_options,
  unit = EXCLUDED.unit, description = EXCLUDED.description, is_sensitive = EXCLUDED.is_sensitive,
  is_readonly = EXCLUDED.is_readonly, sort_order = EXCLUDED.sort_order;
