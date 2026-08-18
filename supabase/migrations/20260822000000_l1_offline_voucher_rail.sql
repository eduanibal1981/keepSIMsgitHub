-- L1 — the offline recharge VOUCHER rail: schema, crypto and switches.
--
-- WHY THIS EXISTS, given C4 already shipped an "offline recharge" screen.
--
-- C4's three channels (WhatsApp / SMS / missed call) all require the handset to
-- reach us out-of-band. WhatsApp needs data. SMS and a missed call need the SIM
-- to be able to originate traffic — and a prepaid line that has run to zero, or
-- fallen out of its activity window, is very often barred from doing exactly
-- that. The one customer who most needs an offline top-up is the one whose SIM
-- cannot send the message that asks for it.
--
-- A recharge PIN inverts the dependency. The voucher is fetched while the
-- device still has connectivity, stored encrypted on the handset, and redeemed
-- later by dialling the carrier's own redemption code — which works on a barred
-- line, with no data, no credit and no reachable server.
--
-- The commercial shape (owner's design):
--   * Premium subscribers only. It is an entitlement of the paid plan.
--   * The PIN is REVEALED as a gift — nothing is charged at reveal time,
--     because at reveal time we are unreachable and cannot charge anything.
--   * When the device is next online the app asks to be paid. Settling is what
--     restores eligibility for the next voucher. One unsettled voucher per
--     premium SIM line is the whole exposure, and it is capped by a partial
--     unique index below, not by a check somewhere in application code.
--
-- Two supply sources, and they are NOT interchangeable:
--   * `ding`   — DingConnect sells PIN products (`RedemptionMechanism` =
--                'ReadReceipt'); the PIN arrives in the SendTransfer receipt.
--                That is a REAL, PAID purchase — there is no "give me a PIN"
--                endpoint — so stock costs money the moment it is created.
--   * `manual` — an operator pastes PINs bought from the carrier or a local
--                distributor. This is the only source that works on day one:
--                Ding has never been called from this project (0 enabled
--                mappings, 0 cached Ding offers) and the adapter has never seen
--                a live response.
--
-- Nothing here is switched on. `OFFLINE_VOUCHER_ENABLED` ships false, and every
-- config key added below gets its `system_config_meta` row in the same
-- migration — a key without one is refused by `admin_set_config` with KS466,
-- which is how 11 switches shipped dead before J6.

BEGIN;

-- ───────────────────────────────────────────────────────────────────────────
-- 0. The encryption key
-- ───────────────────────────────────────────────────────────────────────────
-- A recharge PIN is a bearer instrument: whoever reads it can spend it. It is
-- therefore never stored in plaintext, not even in a deny-all table, because
-- deny-all protects against the API and not against a database dump, a
-- restored backup, or a support query run by a human.
--
-- The key lives in Vault. `get_internal_secret()` is the existing accessor
-- (J1/J3 use it for the eSIM Go token) and is SECURITY DEFINER, so the key
-- material is never selectable by a client.
DO $do$
DECLARE
  v_exists boolean;
BEGIN
  SELECT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'offline_voucher_pin_key')
    INTO v_exists;

  IF NOT v_exists THEN
    PERFORM vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'base64'),
      'offline_voucher_pin_key',
      'Symmetric key for offline_voucher_stock.pin_encrypted (L1). '
      || 'Rotating it makes every stored PIN unreadable — void the stock first.'
    );
  END IF;
END $do$;

-- ───────────────────────────────────────────────────────────────────────────
-- 1. How a voucher is redeemed on a given carrier
-- ───────────────────────────────────────────────────────────────────────────
-- Same stance as I8's `carrier_self_service`: a code nobody has verified is
-- WORSE than no code, because a wrong USSD string dialled by someone with no
-- connectivity and no balance cannot be corrected. An unverified row therefore
-- renders as instructions only; the app offers a dial button solely when
-- `redeem_ussd_template` is present AND `verified_at` is set.
CREATE TABLE IF NOT EXISTS public.carrier_voucher_redemption (
  carrier_id            uuid PRIMARY KEY REFERENCES public.carriers(id) ON DELETE CASCADE,
  -- `{PIN}` is substituted client-side, e.g. '*102*{PIN}#'.
  redeem_ussd_template  text,
  -- Plain-language fallback, always shown. English-only like every other
  -- server-authored string in this product (§ 6 #12 covers the gap).
  instructions          text NOT NULL,
  verified_at           timestamptz,
  verified_by           uuid REFERENCES public.profiles(id),
  notes                 text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT carrier_voucher_redemption_template_has_pin
    CHECK (redeem_ussd_template IS NULL OR redeem_ussd_template LIKE '%{PIN}%')
);

COMMENT ON COLUMN public.carrier_voucher_redemption.redeem_ussd_template IS
  'USSD string with a {PIN} placeholder. NULL until an operator has confirmed it '
  'against the carrier. The app never fabricates one.';

-- ───────────────────────────────────────────────────────────────────────────
-- 2. Stock — one row is one redeemable PIN
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.offline_voucher_stock (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  carrier_id           uuid NOT NULL REFERENCES public.carriers(id),
  source               text NOT NULL CHECK (source IN ('ding','manual')),

  -- pgp_sym_encrypt output. Never selected outside a SECURITY DEFINER function.
  pin_encrypted        bytea NOT NULL,
  -- sha256 of the PIN, so a duplicate paste is caught without ever comparing
  -- plaintext and without a second decryption.
  pin_fingerprint      text NOT NULL,
  serial               text,

  -- What the SUBSCRIBER receives. This is what they are asked to pay back.
  face_value_usd       numeric(10,2) NOT NULL CHECK (face_value_usd > 0),
  face_value_native    numeric(12,2),
  face_value_currency  text,
  -- What WE paid. Only ever an ops number; never shown to a subscriber, the
  -- same isolation that keeps wholesale eSIM cost out of `compare_esim_offers`.
  cost_usd             numeric(10,2) CHECK (cost_usd IS NULL OR cost_usd >= 0),

  expires_at           timestamptz,
  status               text NOT NULL DEFAULT 'available'
                       CHECK (status IN ('available','issued','redeemed','settled','expired','void')),

  -- Ding provenance. `provider_receipt` keeps the whole payload: J5's lesson is
  -- that a normalisation nobody has diffed against a real response should never
  -- be the only copy of the data.
  provider_ref         text,
  provider_receipt     jsonb NOT NULL DEFAULT '{}'::jsonb,

  -- Overrides the carrier default when the supplier ships its own wording
  -- (Ding's ReceiptText is exactly that).
  redeem_instructions  text,

  loaded_by            uuid REFERENCES public.profiles(id),
  load_note            text,
  void_reason          text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

-- The same PIN loaded twice for the same carrier is an operator slip, not a
-- second voucher. Two subscribers holding one PIN means the second one dials a
-- spent code while offline, which is the worst failure this feature has.
CREATE UNIQUE INDEX IF NOT EXISTS offline_voucher_stock_pin_uniq
  ON public.offline_voucher_stock (carrier_id, pin_fingerprint);

CREATE INDEX IF NOT EXISTS offline_voucher_stock_available_idx
  ON public.offline_voucher_stock (carrier_id, face_value_usd, expires_at)
  WHERE status = 'available';

-- ───────────────────────────────────────────────────────────────────────────
-- 3. Grants — who is holding which voucher, and what they owe for it
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.offline_voucher_grants (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sim_line_id        uuid NOT NULL REFERENCES public.sim_lines(id) ON DELETE CASCADE,
  -- One stock row can only ever back one grant.
  stock_id           uuid NOT NULL UNIQUE REFERENCES public.offline_voucher_stock(id),

  status             text NOT NULL DEFAULT 'provisioned'
                     CHECK (status IN ('provisioned','revealed','settled','written_off','expired')),

  -- NULL until revealed: nothing is owed for a voucher still sealed on the
  -- device. Priced at reveal time so a later fee change cannot retro-bill.
  amount_due_usd     numeric(10,2) CHECK (amount_due_usd IS NULL OR amount_due_usd >= 0),

  provisioned_at     timestamptz NOT NULL DEFAULT now(),
  -- When the handset says it revealed the PIN (clamped server-side).
  revealed_at        timestamptz,
  -- When we actually heard about it, which may be days later.
  reported_at        timestamptz,
  settled_at         timestamptz,
  expires_at         timestamptz,

  device_id          text,
  settlement_txn_id  uuid REFERENCES public.wallet_transactions(id),
  write_off_reason   text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT offline_voucher_grants_revealed_has_amount
    CHECK (status <> 'revealed' OR amount_due_usd IS NOT NULL),
  CONSTRAINT offline_voucher_grants_settled_has_txn
    CHECK (status <> 'settled' OR settlement_txn_id IS NOT NULL)
);

-- 🔒 THE CAP, IN THE SCHEMA. One live voucher per premium SIM line. Expressed
-- as an index rather than a check inside `provision_offline_voucher`, because
-- five separate guards in this project have shipped as code that never ran.
-- A second concurrent provision raises 23505 and the RPC reports it honestly.
CREATE UNIQUE INDEX IF NOT EXISTS offline_voucher_grants_one_live_per_line
  ON public.offline_voucher_grants (sim_line_id)
  WHERE status IN ('provisioned','revealed');

CREATE INDEX IF NOT EXISTS offline_voucher_grants_user_idx
  ON public.offline_voucher_grants (user_id, status);
CREATE INDEX IF NOT EXISTS offline_voucher_grants_outstanding_idx
  ON public.offline_voucher_grants (revealed_at)
  WHERE status = 'revealed';

-- ───────────────────────────────────────────────────────────────────────────
-- 4. Requests — the manual fulfilment SLA queue
-- ───────────────────────────────────────────────────────────────────────────
-- A subscriber pays for Premium on a carrier we cannot source automatically.
-- They are entitled to a voucher and there is none. That is an OPERATIONS task
-- with a deadline, not an error to swallow: this table is the queue the admin
-- app works from, and `due_at` is the promise.
CREATE TABLE IF NOT EXISTS public.offline_voucher_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sim_line_id   uuid NOT NULL REFERENCES public.sim_lines(id) ON DELETE CASCADE,
  carrier_id    uuid NOT NULL REFERENCES public.carriers(id),
  reason        text NOT NULL DEFAULT 'no_stock'
                CHECK (reason IN ('no_stock','no_automatic_source')),
  status        text NOT NULL DEFAULT 'open'
                CHECK (status IN ('open','fulfilled','cancelled')),
  opened_at     timestamptz NOT NULL DEFAULT now(),
  due_at        timestamptz NOT NULL,
  fulfilled_at  timestamptz,
  fulfilled_by  uuid REFERENCES public.profiles(id),
  stock_id      uuid REFERENCES public.offline_voucher_stock(id),
  note          text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS offline_voucher_requests_one_open_per_line
  ON public.offline_voucher_requests (sim_line_id)
  WHERE status = 'open';

CREATE INDEX IF NOT EXISTS offline_voucher_requests_due_idx
  ON public.offline_voucher_requests (due_at)
  WHERE status = 'open';

-- ───────────────────────────────────────────────────────────────────────────
-- 5. Purchase jobs — the only way Ding is ever asked for a PIN
-- ───────────────────────────────────────────────────────────────────────────
-- Deliberately a queue and not a direct call. A DB function cannot reach Ding
-- (the credential is `DING_API_KEY` in `servers/.env` on the VM and nowhere
-- else), and more importantly: this is the one code path in the feature that
-- SPENDS MONEY WITHOUT A SUBSCRIBER IN THE LOOP. Making it a row that an
-- operator creates and a worker claims means every purchase has an author, a
-- cap, and an audit trail before anything is bought.
CREATE TABLE IF NOT EXISTS public.offline_voucher_purchase_jobs (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  carrier_id          uuid NOT NULL REFERENCES public.carriers(id),
  provider_code       text NOT NULL DEFAULT 'ding'
                      REFERENCES public.service_providers(code),
  quantity            integer NOT NULL CHECK (quantity BETWEEN 1 AND 50),
  -- The worker must refuse any SKU dearer than this. A cap the operator sets
  -- per job, defaulted from OFFLINE_VOUCHER_DING_MAX_UNIT_COST_USD.
  max_unit_cost_usd   numeric(10,2) NOT NULL CHECK (max_unit_cost_usd > 0),
  -- The line the PINs are bought against. Ding's SendTransfer requires an
  -- AccountNumber even for a PIN product.
  account_number      text,

  status              text NOT NULL DEFAULT 'queued'
                      CHECK (status IN ('queued','claimed','done','failed','cancelled')),
  produced_count      integer NOT NULL DEFAULT 0,
  spent_usd           numeric(10,2) NOT NULL DEFAULT 0,
  last_error          text,

  requested_by        uuid REFERENCES public.profiles(id),
  requested_at        timestamptz NOT NULL DEFAULT now(),
  claimed_at          timestamptz,
  completed_at        timestamptz,
  note                text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS offline_voucher_purchase_jobs_queued_idx
  ON public.offline_voucher_purchase_jobs (requested_at)
  WHERE status = 'queued';

-- ───────────────────────────────────────────────────────────────────────────
-- 6. Lockdown
-- ───────────────────────────────────────────────────────────────────────────
-- Every one of these is deny-all to anon AND authenticated. The stock table
-- holds bearer instruments; the grants table is reachable only through the RPCs
-- in L2, which is what lets those RPCs be the single place entitlement is
-- decided. No RLS policy is added to any user-facing table (F-1..F-4).
DO $do$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'carrier_voucher_redemption',
    'offline_voucher_stock',
    'offline_voucher_grants',
    'offline_voucher_requests',
    'offline_voucher_purchase_jobs'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated, public', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
  END LOOP;
END $do$;

-- No moddatetime triggers: this database has none anywhere (checked — zero
-- triggers on that function), and adding the pattern for five tables only here
-- would make `updated_at` mean something different on these five than on the
-- other eighty. The RPCs stamp it.

-- ───────────────────────────────────────────────────────────────────────────
-- 7. Crypto helpers
-- ───────────────────────────────────────────────────────────────────────────
-- Callable by nobody. They exist so the RPCs in L2/L3 do not each carry their
-- own key lookup, and so the key name appears exactly twice in the codebase.
-- A SECURITY DEFINER caller runs as the owner, which is these functions' owner
-- too, so revoking every grant does not break the internal calls.
CREATE OR REPLACE FUNCTION public.voucher_encrypt_pin(p_pin text)
RETURNS bytea
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_key text;
BEGIN
  IF p_pin IS NULL OR btrim(p_pin) = '' THEN
    RAISE EXCEPTION 'A voucher PIN may not be empty' USING ERRCODE = 'KS470';
  END IF;

  v_key := public.get_internal_secret('offline_voucher_pin_key');
  IF v_key IS NULL OR v_key = '' THEN
    RAISE EXCEPTION 'offline_voucher_pin_key is not in Vault' USING ERRCODE = 'KS471';
  END IF;

  RETURN extensions.pgp_sym_encrypt(btrim(p_pin), v_key);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.voucher_decrypt_pin(p_cipher bytea)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_key text;
BEGIN
  IF p_cipher IS NULL THEN RETURN NULL; END IF;

  v_key := public.get_internal_secret('offline_voucher_pin_key');
  IF v_key IS NULL OR v_key = '' THEN
    RAISE EXCEPTION 'offline_voucher_pin_key is not in Vault' USING ERRCODE = 'KS471';
  END IF;

  RETURN extensions.pgp_sym_decrypt(p_cipher, v_key);
END;
$fn$;

-- Fingerprint is salted with the carrier so the same physical PIN issued by two
-- carriers does not collide, and so a stolen fingerprint list is not a rainbow
-- table against short numeric PINs.
CREATE OR REPLACE FUNCTION public.voucher_pin_fingerprint(p_carrier_id uuid, p_pin text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $fn$
  SELECT encode(
           extensions.digest(p_carrier_id::text || ':' || btrim(coalesce(p_pin, '')), 'sha256'),
           'hex');
$fn$;

REVOKE ALL ON FUNCTION public.voucher_encrypt_pin(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.voucher_decrypt_pin(bytea) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.voucher_pin_fingerprint(uuid, text) FROM PUBLIC, anon, authenticated;

-- ───────────────────────────────────────────────────────────────────────────
-- 8. Can this carrier be sourced automatically?
-- ───────────────────────────────────────────────────────────────────────────
-- The answer decides whether a premium purchase silently works or opens an
-- operations ticket, so it is one function and not a condition copied into
-- three callers.
--
-- "Ding can source it" requires ALL of: the global switch, Ding active as a
-- service provider, an ENABLED mapping carrying Ding's own provider code, and
-- the feature's own Ding switch. Any one missing and the honest answer is
-- 'manual' — a supplier we refuse to call cannot supply anything, which is the
-- same trap as an enabled supplier with an empty offer cache ranking as
-- infinitely cheap by absence.
CREATE OR REPLACE FUNCTION public.offline_voucher_source_for_carrier(p_carrier_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_ding_on boolean;
BEGIN
  SELECT COALESCE(NULLIF(config_value, ''), 'false')::boolean
    INTO v_ding_on
    FROM public.system_configs
   WHERE config_key = 'OFFLINE_VOUCHER_DING_ENABLED';

  IF COALESCE(v_ding_on, false)
     AND EXISTS (
       SELECT 1
         FROM public.carrier_provider_map m
         JOIN public.service_providers sp ON sp.code = m.provider
        WHERE m.carrier_id = p_carrier_id
          AND m.provider = 'ding'
          AND m.is_enabled
          AND sp.is_active
          AND COALESCE(m.provider_carrier_code, '') <> ''
     )
  THEN
    RETURN 'ding';
  END IF;

  RETURN 'manual';
END;
$fn$;

REVOKE ALL ON FUNCTION public.offline_voucher_source_for_carrier(uuid) FROM PUBLIC, anon, authenticated;

-- ───────────────────────────────────────────────────────────────────────────
-- 9. Settlement is a wallet debit of its own kind
-- ───────────────────────────────────────────────────────────────────────────
-- Not `topup_debit`: that type is reconciled against `topup_executions`, and a
-- voucher has none — the airtime was delivered by the carrier's own redemption
-- system, not by us. Not `plan_fee_debit` either; the plan was already paid,
-- and reusing it would make `has_paid_premium_entitlement()` treat a voucher
-- settlement as proof of a plan purchase, granting a free year of premium.
ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;
ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_type_check
  CHECK (type = ANY (ARRAY[
    'deposit','topup_debit','refund','referral_credit','welcome_home_debit',
    'auto_fund','plan_fee_debit','esim_purchase_debit','esim_purchase_refund',
    'wallet_settlement','wallet_forfeit','gift_sent','gift_received',
    'admin_adjustment','offline_voucher_debit'
  ]));

-- ───────────────────────────────────────────────────────────────────────────
-- 10. Switches — every one with its meta row, or it cannot be flipped (J6)
-- ───────────────────────────────────────────────────────────────────────────
INSERT INTO public.system_configs (config_key, config_value) VALUES
  ('OFFLINE_VOUCHER_ENABLED',                 'false'),
  ('OFFLINE_VOUCHER_DING_ENABLED',            'false'),
  ('OFFLINE_VOUCHER_MANUAL_SLA_DAYS',         '7'),
  ('OFFLINE_VOUCHER_SERVICE_FEE_PERCENT',     '0'),
  ('OFFLINE_VOUCHER_SETTLEMENT_GRACE_DAYS',   '14'),
  ('OFFLINE_VOUCHER_STOCK_LOW_THRESHOLD',     '3'),
  ('OFFLINE_VOUCHER_VALIDITY_DAYS',           '365'),
  ('OFFLINE_VOUCHER_DING_MAX_UNIT_COST_USD',  '5.00')
ON CONFLICT (config_key) DO NOTHING;

INSERT INTO public.system_config_meta
  (config_key, label, group_name, value_type, min_value, max_value, unit, description, sort_order)
VALUES
  ('OFFLINE_VOUCHER_ENABLED', 'Offline voucher rail', 'Offline refill', 'bool',
   NULL, NULL, NULL,
   'Master switch. Off means premium subscribers are never provisioned a recharge PIN and the '
   || 'emergency card never appears. Turning it on with no stock loaded shows subscribers a '
   || '"being prepared" state, not an error.', 610),

  ('OFFLINE_VOUCHER_DING_ENABLED', 'Buy PINs from DingConnect', 'Offline refill', 'bool',
   NULL, NULL, NULL,
   'Allows purchase jobs to be queued against DingConnect. Every Ding PIN is a real paid '
   || 'SendTransfer. Ding has never been called from this project, so leave this off until one '
   || 'purchase has been made by hand and its receipt inspected.', 611),

  ('OFFLINE_VOUCHER_MANUAL_SLA_DAYS', 'Manual load deadline', 'Offline refill', 'int',
   1, 60, 'days',
   'How long an operator has to hand-load a PIN after a premium plan is paid on a carrier with '
   || 'no automatic source. Drives due_at on the fulfilment queue.', 612),

  ('OFFLINE_VOUCHER_SERVICE_FEE_PERCENT', 'Voucher service fee', 'Offline refill', 'decimal',
   0, 25, '%',
   'Added to the voucher face value when the subscriber is asked to settle. 0 means they repay '
   || 'exactly what they received.', 613),

  ('OFFLINE_VOUCHER_SETTLEMENT_GRACE_DAYS', 'Settlement grace', 'Offline refill', 'int',
   1, 180, 'days',
   'How long an unsettled voucher stays a polite request before it is flagged for the operator. '
   || 'Nothing is auto-debited and nothing is auto-forfeited at this boundary.', 614),

  ('OFFLINE_VOUCHER_STOCK_LOW_THRESHOLD', 'Low stock warning', 'Offline refill', 'int',
   0, 500, 'PINs',
   'Available PINs per carrier below which the admin dashboard flags the carrier.', 615),

  ('OFFLINE_VOUCHER_VALIDITY_DAYS', 'Default PIN validity', 'Offline refill', 'int',
   1, 3650, 'days',
   'Used when a loaded PIN carries no expiry of its own. A voucher held past this is retired '
   || 'rather than handed to a subscriber who would dial a dead code while offline.', 616),

  ('OFFLINE_VOUCHER_DING_MAX_UNIT_COST_USD', 'Max Ding PIN cost', 'Offline refill', 'decimal',
   0.5, 100, 'USD',
   'Hard ceiling on what a single DingConnect PIN may cost. The worker refuses any SKU above it, '
   || 'so a mis-parsed price cannot drain the Ding balance.', 617)
ON CONFLICT (config_key) DO NOTHING;

COMMIT;
