-- ============================================================================
-- G6 — Family / fleet shared wallet with per-member spend limits
--
-- Feature suggestion #6 in doc/PRODUCTION_PLAN_REVIEW.md § 6.
--
-- ⚠️ THE REVIEW'S PREMISE WAS WRONG, AND THAT CHANGES THE SHAPE OF THIS.
-- "`household_members` with roles already exists. Add per-member monthly caps"
-- assumes the shared wallet exists and only needs limiting. It does not. A
-- `manager` can already *trigger* a refill on the owner's line — but
-- `request_instant_refill` books `topup_executions.user_id = auth.uid()`, and
-- `worker_instant_refill.js` debits exactly that user. So today the member pays
-- from their own wallet. Capping "how much of the owner's money a member may
-- spend" caps nothing until the owner's money is reachable at all.
--
-- So G6 is two things: it makes the wallet genuinely shared, and it makes that
-- sharing safe. The cap is not a feature bolted onto sharing — it is the thing
-- that makes sharing shippable.
--
-- ── Six decisions worth not re-deriving ────────────────────────────────────
--
-- 1. THE CAP *IS* THE PERMISSION. There is no `can_spend` boolean next to a
--    `monthly_cap_usd`; two knobs that mean one thing drift apart. One column,
--    `monthly_cap_usd`, `NOT NULL DEFAULT 0.00`, and **0 means cannot spend**.
--    Fail-closed by construction: every existing `manager` keeps paying from
--    their own wallet until an owner types a number. There is deliberately no
--    way to express "unlimited" — this is a spend-limit feature.
--
-- 2. THE PAYER IS BOOKED ON THE EXECUTION; THE ACTOR IS BOOKED BESIDE IT.
--    `topup_executions.user_id` becomes the payer and the new `acting_user_id`
--    records who pressed the button. That is what lets the owner's wallet fund
--    the refill **without touching `worker_instant_refill.js`**, which lives on
--    the owner-gated VM and cannot ship from here (same wall G1 and G2 hit).
--    The worker keeps passing `execution.user_id` to the debit and is simply
--    right. `acting_user_id IS NULL` on every pre-existing row and on every
--    ordinary self-funded refill, so the old path is bit-for-bit unchanged.
--    The existing "Users can view household shared topup executions" policy
--    already keys on `user_id` being the owner, so the member does not lose
--    sight of the execution they created.
--
-- 3. SPEND IS DERIVED, NEVER COUNTED. No `spent_this_month` column. G3 found
--    `wallets.total_deposited` reads 0.00 for six of eight users who have real
--    deposit rows, because a counter is only as good as every path that
--    remembers to bump it. Month-to-date spend is computed from
--    `wallet_transactions` stamped `metadata->>'spent_by'`, net of refunds
--    matched on `reference_id`.
--
-- 4. IN-FLIGHT EXECUTIONS COUNT AGAINST THE CAP. Checking only committed
--    ledger rows would let a member queue twenty refills that each pass the
--    check and then all debit — the cap would hold at request time and be
--    meaningless by morning. `household_spend_mtd()` adds pending executions
--    that have no matching `wallet_transaction` yet, which is reservation
--    accounting and cannot double-count: the moment the debit lands, the
--    execution stops being in-flight and the ledger row takes over.
--
-- 5. ENFORCED TWICE, AND THE SECOND ONE IS THE REAL ONE. At request time in
--    `request_instant_refill` (fast, so the member gets a sentence instead of a
--    silent failure hours later) and again inside `debit_wallet_for_topup`,
--    which is the only place money actually moves. The debit-time check is
--    written so it is inert unless the execution names an `acting_user_id`
--    different from the payer — every existing caller takes the identical code
--    path it takes today.
--
-- 6. THE CAP EXCEPTION MUST NOT BE RAISED INSIDE `enforce_rate_limit`.
--    That function ends in `WHEN OTHERS THEN RAISE NOTICE`, re-raising only
--    KS429 and KS403. A cap violation raised under it would be swallowed
--    silently and fail **open** on a money path. G6 raises `KS402` from the
--    calling RPCs, never from inside the limiter. (This is the F0 lesson,
--    written down in § 8 of the review, biting for the second time.)
--
-- eSIM purchases are deliberately NOT chargeable to a household wallet: an
-- eSIM is delivered to and installed by the buyer, `user_esims` binds it to
-- them, and there is no SIM line on the order to resolve an owner from.
-- `request_esim_purchase` is left exactly as it was; § 6 of the review says so.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. The cap, on the membership row.
-- ---------------------------------------------------------------------------
ALTER TABLE public.household_members
  ADD COLUMN IF NOT EXISTS monthly_cap_usd numeric(10,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS per_txn_cap_usd numeric(10,2),
  ADD COLUMN IF NOT EXISTS cap_updated_at  timestamptz,
  ADD COLUMN IF NOT EXISTS cap_updated_by  uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.household_members
  DROP CONSTRAINT IF EXISTS household_members_monthly_cap_nonneg;
ALTER TABLE public.household_members
  ADD CONSTRAINT household_members_monthly_cap_nonneg
  CHECK (monthly_cap_usd >= 0 AND monthly_cap_usd <= 100000);

ALTER TABLE public.household_members
  DROP CONSTRAINT IF EXISTS household_members_per_txn_cap_positive;
ALTER TABLE public.household_members
  ADD CONSTRAINT household_members_per_txn_cap_positive
  CHECK (per_txn_cap_usd IS NULL OR (per_txn_cap_usd > 0 AND per_txn_cap_usd <= monthly_cap_usd));

COMMENT ON COLUMN public.household_members.monthly_cap_usd IS
  'G6: how much of the OWNER''s wallet this member may spend per calendar month (UTC). 0.00 = may not spend it at all, which is the default and the fail-closed state. There is deliberately no "unlimited" value.';
COMMENT ON COLUMN public.household_members.per_txn_cap_usd IS
  'G6: optional ceiling on a single refill. NULL = only the monthly cap applies.';

-- Only a `manager` can act on the owner's lines at all (that predicate is
-- already in request_instant_refill), so a funded `viewer` would be a cap
-- nobody can spend. Keep the data honest rather than silently inert.
CREATE OR REPLACE FUNCTION public.trg_fn_household_cap_requires_manager()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.monthly_cap_usd > 0 AND NEW.role IS DISTINCT FROM 'manager' THEN
    RAISE EXCEPTION 'A spend cap requires the manager role, not %', COALESCE(NEW.role, '<null>')
      USING ERRCODE = 'KS402';
  END IF;
  RETURN NEW;
END $$;

REVOKE EXECUTE ON FUNCTION public.trg_fn_household_cap_requires_manager() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_household_cap_requires_manager ON public.household_members;
CREATE TRIGGER trg_household_cap_requires_manager
  BEFORE INSERT OR UPDATE OF monthly_cap_usd, role ON public.household_members
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_household_cap_requires_manager();


-- ---------------------------------------------------------------------------
-- 2. Who actually pressed the button.
--
-- NULL means "the payer acted for themselves" — true of every row that exists
-- today and of every ordinary self-funded refill after this. Nothing reads it
-- unless it is non-null, which is what keeps the old path unchanged.
-- ---------------------------------------------------------------------------
ALTER TABLE public.topup_executions
  ADD COLUMN IF NOT EXISTS acting_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.topup_executions.acting_user_id IS
  'G6: the household member who requested this, when they are not the payer. NULL = user_id acted for themselves. When set, user_id is the OWNER whose wallet funds it.';

CREATE INDEX IF NOT EXISTS topup_executions_acting_user_month_idx
  ON public.topup_executions (acting_user_id, user_id, created_at)
  WHERE acting_user_id IS NOT NULL;

-- Column-level grant, in the F6 style: the client may not set this itself.
REVOKE UPDATE ON public.topup_executions FROM anon, authenticated;


-- ---------------------------------------------------------------------------
-- 3. Month-to-date spend, derived.
--
-- Committed ledger spend stamped with this member, net of refunds matched on
-- `reference_id`, plus executions that are queued but not yet debited.
-- `p_exclude_execution_id` exists because the debit-time check must not count
-- the very execution it is about to pay for.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.household_spend_mtd(
  p_owner_id             uuid,
  p_member_id            uuid,
  p_exclude_execution_id uuid DEFAULT NULL
)
RETURNS TABLE (committed_usd numeric, in_flight_usd numeric, total_usd numeric)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
WITH bounds AS (
  SELECT date_trunc('month', (now() AT TIME ZONE 'UTC')) AT TIME ZONE 'UTC' AS month_start
),
-- Debits taken out of the owner's wallet by this member this month.
debits AS (
  SELECT wt.reference_id, wt.amount
  FROM public.wallet_transactions wt
  JOIN public.wallets w ON w.id = wt.wallet_id
  CROSS JOIN bounds b
  WHERE w.user_id = p_owner_id
    AND wt.status = 'completed'
    AND wt.created_at >= b.month_start
    AND wt.metadata ->> 'spent_by' = p_member_id::text
    AND wt.type IN ('topup_debit', 'welcome_home_debit', 'plan_fee_debit')
),
-- Anything given back against those same references stops counting.
refunds AS (
  SELECT COALESCE(SUM(wt.amount), 0) AS amt
  FROM public.wallet_transactions wt
  JOIN public.wallets w ON w.id = wt.wallet_id
  WHERE w.user_id = p_owner_id
    AND wt.status = 'completed'
    AND wt.type IN ('refund', 'esim_purchase_refund')
    AND wt.reference_id IN (SELECT reference_id FROM debits WHERE reference_id IS NOT NULL)
),
-- Queued against the owner but not yet paid for.
--
-- ⚠️ The status list is the whole ballgame and 'pending' is NOT enough.
-- `route_topup_execution()` is a BEFORE INSERT trigger that rewrites a
-- `refill_instant` from 'pending' to **'routing'** before the row ever lands,
-- so a first draft that watched only ('pending','processing') counted exactly
-- nothing and let queue-stacking straight through. Proven by inserting one and
-- reading the row back: `status = 'routing'`. The four non-terminal statuses
-- out of the eight the CHECK constraint allows are listed explicitly.
--
-- `payment_gateway_code = 'wallet'` matters too: the worker only debits when
-- the gateway is the wallet, so a card-funded refill never touches the owner's
-- balance and must not eat their cap.
--
-- Double-counting is prevented by the ABSENCE of a ledger row rather than by
-- status, because the debit lands while the execution is still in flight.
in_flight AS (
  SELECT COALESCE(SUM(te.amount), 0) AS amt
  FROM public.topup_executions te
  CROSS JOIN bounds b
  WHERE te.acting_user_id = p_member_id
    AND te.user_id        = p_owner_id
    AND te.created_at    >= b.month_start
    AND te.status IN ('pending', 'pending_payment', 'routing', 'processing')
    AND te.payment_gateway_code = 'wallet'
    AND (p_exclude_execution_id IS NULL OR te.id <> p_exclude_execution_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.wallet_transactions wt
      WHERE wt.reference_id = 'exec_' || te.id::text
        AND wt.status = 'completed'
    )
)
SELECT
  GREATEST(COALESCE((SELECT SUM(amount) FROM debits), 0) - (SELECT amt FROM refunds), 0)::numeric(12,2),
  (SELECT amt FROM in_flight)::numeric(12,2),
  (GREATEST(COALESCE((SELECT SUM(amount) FROM debits), 0) - (SELECT amt FROM refunds), 0)
   + (SELECT amt FROM in_flight))::numeric(12,2);
$$;

COMMENT ON FUNCTION public.household_spend_mtd(uuid, uuid, uuid) IS
  'G6: what a household member has spent of the owner''s wallet this calendar month (UTC), derived from the ledger plus not-yet-debited executions. Never a stored counter — see G3''s wallets.total_deposited.';

-- SECURITY DEFINER because it reads another user's wallet ledger by design.
-- It is never callable directly: every caller is a function in this file.
REVOKE ALL ON FUNCTION public.household_spend_mtd(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.household_spend_mtd(uuid, uuid, uuid) TO service_role;


-- ---------------------------------------------------------------------------
-- 4. The check itself. One place, so the two enforcement points cannot drift.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.household_spend_check(
  p_owner_id             uuid,
  p_member_id            uuid,
  p_amount               numeric,
  p_exclude_execution_id uuid DEFAULT NULL
)
RETURNS TABLE (
  allowed       boolean,
  reason        text,
  monthly_cap   numeric,
  per_txn_cap   numeric,
  spent_mtd     numeric,
  remaining_usd numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_m       RECORD;
  v_spend   RECORD;
  v_remain  numeric;
BEGIN
  SELECT hm.monthly_cap_usd, hm.per_txn_cap_usd, hm.role, hm.invite_status
    INTO v_m
  FROM public.household_members hm
  WHERE hm.owner_id = p_owner_id AND hm.member_id = p_member_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'NOT_A_MEMBER', 0::numeric, NULL::numeric, 0::numeric, 0::numeric;
    RETURN;
  END IF;

  IF v_m.invite_status <> 'accepted' THEN
    RETURN QUERY SELECT false, 'INVITE_NOT_ACCEPTED', v_m.monthly_cap_usd, v_m.per_txn_cap_usd, 0::numeric, 0::numeric;
    RETURN;
  END IF;

  IF v_m.role <> 'manager' THEN
    RETURN QUERY SELECT false, 'NOT_A_MANAGER', v_m.monthly_cap_usd, v_m.per_txn_cap_usd, 0::numeric, 0::numeric;
    RETURN;
  END IF;

  -- The fail-closed default. An owner who has never set a cap has not opted in.
  IF v_m.monthly_cap_usd <= 0 THEN
    RETURN QUERY SELECT false, 'NO_CAP_SET', v_m.monthly_cap_usd, v_m.per_txn_cap_usd, 0::numeric, 0::numeric;
    RETURN;
  END IF;

  SELECT * INTO v_spend
  FROM public.household_spend_mtd(p_owner_id, p_member_id, p_exclude_execution_id);

  v_remain := v_m.monthly_cap_usd - v_spend.total_usd;

  IF p_amount IS NOT NULL AND v_m.per_txn_cap_usd IS NOT NULL AND p_amount > v_m.per_txn_cap_usd THEN
    RETURN QUERY SELECT false, 'OVER_PER_TXN_CAP', v_m.monthly_cap_usd, v_m.per_txn_cap_usd,
                        v_spend.total_usd, GREATEST(v_remain, 0);
    RETURN;
  END IF;

  IF p_amount IS NOT NULL AND p_amount > v_remain THEN
    RETURN QUERY SELECT false, 'OVER_MONTHLY_CAP', v_m.monthly_cap_usd, v_m.per_txn_cap_usd,
                        v_spend.total_usd, GREATEST(v_remain, 0);
    RETURN;
  END IF;

  RETURN QUERY SELECT true, 'OK', v_m.monthly_cap_usd, v_m.per_txn_cap_usd,
                      v_spend.total_usd, GREATEST(v_remain, 0);
END $$;

COMMENT ON FUNCTION public.household_spend_check(uuid, uuid, numeric, uuid) IS
  'G6: may this member spend p_amount of this owner''s wallet right now? Single source of truth for both the request-time and the debit-time check. Reason codes: NOT_A_MEMBER, INVITE_NOT_ACCEPTED, NOT_A_MANAGER, NO_CAP_SET, OVER_PER_TXN_CAP, OVER_MONTHLY_CAP, OK.';

REVOKE ALL ON FUNCTION public.household_spend_check(uuid, uuid, numeric, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.household_spend_check(uuid, uuid, numeric, uuid) TO service_role;


-- ---------------------------------------------------------------------------
-- 5. Payer resolution. Returns the owner when the actor is a funded member of
--    that owner's household, and the actor themselves in every other case —
--    including when the cap is exhausted, so the caller decides whether that
--    is a refusal or a fall-back to self-funding. G6 makes it a refusal.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_household_payer(
  p_actor_id      uuid,
  p_line_owner_id uuid
)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_actor_id = p_line_owner_id THEN p_actor_id
    WHEN EXISTS (
      SELECT 1 FROM public.household_members hm
      WHERE hm.owner_id        = p_line_owner_id
        AND hm.member_id       = p_actor_id
        AND hm.invite_status   = 'accepted'
        AND hm.role            = 'manager'
        AND hm.monthly_cap_usd > 0
    ) THEN p_line_owner_id
    ELSE p_actor_id
  END;
$$;

COMMENT ON FUNCTION public.resolve_household_payer(uuid, uuid) IS
  'G6: whose wallet funds an action the actor is taking on a line owned by p_line_owner_id. The owner only when the actor is an accepted manager with a non-zero cap; otherwise the actor pays for themselves, exactly as before G6.';

REVOKE ALL ON FUNCTION public.resolve_household_payer(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_household_payer(uuid, uuid) TO service_role;


-- ---------------------------------------------------------------------------
-- 6. Owner-facing: set a member's cap.
--
-- SECURITY INVOKER on purpose. The existing "Owners can manage household
-- members" policy (`auth.uid() = owner_id AND NOT is_user_suspended()`) is what
-- authorises this, so there is no new privileged surface and no
-- `current_user`-inside-DEFINER trap to get wrong for the fifth time. The RPC
-- exists for the bounds checks and the audit stamp, not for the permission.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_household_member_cap(
  p_member_row_id   uuid,
  p_monthly_cap_usd numeric,
  p_per_txn_cap_usd numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $fn$
DECLARE
  v_actor uuid := auth.uid();
  v_row   RECORD;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED');
  END IF;

  IF p_monthly_cap_usd IS NULL OR p_monthly_cap_usd < 0 OR p_monthly_cap_usd > 100000 THEN
    RETURN jsonb_build_object('success', false, 'code', 'INVALID_CAP',
      'error', 'Monthly cap must be between $0.00 and $100,000.00. Use 0 to switch spending off.');
  END IF;

  IF p_per_txn_cap_usd IS NOT NULL
     AND (p_per_txn_cap_usd <= 0 OR p_per_txn_cap_usd > p_monthly_cap_usd) THEN
    RETURN jsonb_build_object('success', false, 'code', 'INVALID_PER_TXN_CAP',
      'error', 'A per-refill cap must be above $0.00 and no more than the monthly cap.');
  END IF;

  -- RLS is the authorisation: a row belonging to someone else simply is not
  -- visible to this UPDATE, so it affects nothing and we report NOT_FOUND.
  UPDATE public.household_members hm
     SET monthly_cap_usd = round(p_monthly_cap_usd, 2),
         per_txn_cap_usd = CASE WHEN p_per_txn_cap_usd IS NULL
                                THEN NULL ELSE round(p_per_txn_cap_usd, 2) END,
         cap_updated_at  = now(),
         cap_updated_by  = v_actor
   WHERE hm.id = p_member_row_id
   RETURNING hm.id, hm.member_email, hm.role, hm.monthly_cap_usd, hm.per_txn_cap_usd
   INTO v_row;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'code', 'NOT_FOUND',
      'error', 'That household member does not exist, or is not yours to manage.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'member_email', v_row.member_email,
    'role', v_row.role,
    'monthly_cap_usd', v_row.monthly_cap_usd,
    'per_txn_cap_usd', v_row.per_txn_cap_usd
  );
EXCEPTION
  -- The manager-role trigger raises KS402; turn it into the same envelope the
  -- rest of this function returns rather than a raw Postgres error string.
  WHEN SQLSTATE 'KS402' THEN
    RETURN jsonb_build_object('success', false, 'code', 'ROLE_REQUIRED',
      'error', 'Give this person the manager role before funding them — a viewer cannot act on your lines.');
END $fn$;

COMMENT ON FUNCTION public.set_household_member_cap(uuid, numeric, numeric) IS
  'G6: owner sets a household member''s monthly (and optional per-refill) spend cap. SECURITY INVOKER — the existing owner RLS policy is the authorisation. 0 switches spending off.';

REVOKE ALL     ON FUNCTION public.set_household_member_cap(uuid, numeric, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.set_household_member_cap(uuid, numeric, numeric) TO authenticated, service_role;


-- ---------------------------------------------------------------------------
-- 7. The consolidated view the review asks for.
--
-- One row per member of the caller's household: their cap, what they have
-- spent this month, what is still in flight, and what is left. SECURITY
-- DEFINER because it has to read the owner's ledger and the members' profiles,
-- but it is scoped to `auth.uid()` as owner and takes no user id argument —
-- there is nothing to forge.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.household_spend_summary()
RETURNS TABLE (
  member_row_id   uuid,
  member_id       uuid,
  member_email    text,
  member_name     text,
  role            text,
  invite_status   text,
  monthly_cap_usd numeric,
  per_txn_cap_usd numeric,
  committed_usd   numeric,
  in_flight_usd   numeric,
  spent_mtd_usd   numeric,
  remaining_usd   numeric,
  last_spend_at   timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT
    hm.id,
    hm.member_id,
    hm.member_email,
    pr.full_name,
    hm.role,
    hm.invite_status,
    hm.monthly_cap_usd,
    hm.per_txn_cap_usd,
    COALESCE(s.committed_usd, 0.00),
    COALESCE(s.in_flight_usd, 0.00),
    COALESCE(s.total_usd, 0.00),
    GREATEST(hm.monthly_cap_usd - COALESCE(s.total_usd, 0.00), 0.00),
    (SELECT MAX(wt.created_at)
       FROM public.wallet_transactions wt
       JOIN public.wallets w ON w.id = wt.wallet_id
      WHERE w.user_id = auth.uid()
        AND wt.metadata ->> 'spent_by' = hm.member_id::text)
  FROM public.household_members hm
  LEFT JOIN public.profiles pr ON pr.id = hm.member_id
  LEFT JOIN LATERAL public.household_spend_mtd(auth.uid(), hm.member_id) s ON hm.member_id IS NOT NULL
  WHERE hm.owner_id = auth.uid()
  ORDER BY hm.monthly_cap_usd DESC, hm.member_email;
$fn$;

COMMENT ON FUNCTION public.household_spend_summary() IS
  'G6: the consolidated household view — one row per member with cap, month-to-date spend, in-flight spend and headroom. Scoped to auth.uid() as owner; takes no argument, so there is nothing to forge.';

REVOKE ALL     ON FUNCTION public.household_spend_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.household_spend_summary() TO authenticated, service_role;


-- ---------------------------------------------------------------------------
-- 8. My own headroom, for the member's side of the screen.
--
-- A member cannot read the owner's wallet or ledger (RLS says so, correctly),
-- so without this they would discover their cap by hitting it.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_household_allowances()
RETURNS TABLE (
  owner_id        uuid,
  owner_name      text,
  owner_email     text,
  role            text,
  monthly_cap_usd numeric,
  per_txn_cap_usd numeric,
  spent_mtd_usd   numeric,
  remaining_usd   numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT
    hm.owner_id,
    pr.full_name,
    pr.email,
    hm.role,
    hm.monthly_cap_usd,
    hm.per_txn_cap_usd,
    COALESCE(s.total_usd, 0.00),
    GREATEST(hm.monthly_cap_usd - COALESCE(s.total_usd, 0.00), 0.00)
  FROM public.household_members hm
  LEFT JOIN public.profiles pr ON pr.id = hm.owner_id
  LEFT JOIN LATERAL public.household_spend_mtd(hm.owner_id, auth.uid()) s ON true
  WHERE hm.member_id     = auth.uid()
    AND hm.invite_status = 'accepted'
  ORDER BY hm.monthly_cap_usd DESC;
$fn$;

COMMENT ON FUNCTION public.my_household_allowances() IS
  'G6: the caller''s side of the arrangement — which households have funded them, how much is left this month. Scoped to auth.uid() as member.';

REVOKE ALL     ON FUNCTION public.my_household_allowances() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_household_allowances() TO authenticated, service_role;

