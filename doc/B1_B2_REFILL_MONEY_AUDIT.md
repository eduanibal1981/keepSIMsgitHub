# B1 + B2 — Refill engine audit & atomic wallet migration (2026-07-16)

Sessions B1 and B2 of `PRODUCTION_PLAN.md`, done together because both edit the
same three VM workers. Everything below is applied to the live Supabase project
(`zwxswagokhgbuzrrbnhr`) and the `keepsims-staging` VM, and committed to
`github.com/eduanibal1981/keepsims-backend` (`e0bcf06`).

## What the audit found

### 1. The Offers-API fallback had never worked (old D0 was misdiagnosed)

The `_offset` pagination fix from D0 was irrelevant: the fallback query
returned HTTP 200 with **zero offers for every carrier**, including known-good
Vodafone Egypt. Four independent bugs:

| Bug | Old worker code | Reality (verified against sandbox) |
|---|---|---|
| Country filter | `country=Egypt` (full name from `carriers.zen_country`) | API takes ISO-2 (`country=EG`) |
| Sub-type filter | `subType=AIRTIME` | Values are `subTypes: ["Mobile Top Up"]`; param dropped, filtered client-side |
| Price type | `offer.price.type` (always `undefined` → no offer ever matched) | `offer.priceType` (`FIXED` / `RANGE`) |
| Price units | compared floats (`price.value`, `rangeMin/Max`) against USD | integer minor units: `price.fixed|min|max` scaled by `price.currencyDivisor` |

Fix (all three workers): query by the ISO code the worker already has from its
`countries.iso_code` join, paginate (`_limit=100`, up to 500), filter
`enabled && productType==='TOPUP' && subTypes includes 'Mobile Top Up'`, match
FIXED at exact USD price first, else a RANGE offer covering the amount with the
purchase value **interpolated into send-currency minor units** — the unit the
purchase API's `value: {type:'ZEND'}` takes (confirmed from historically
successful `VODAFONE_EG_OPEN` purchases where `offer_value` 800 = `send.min`).

**Proven live** (executions in `topup_executions`, worker logs on VM):
- FIXED: `c2879086…` — Etisalat EG, `offer_id` NULL, $0.25 → resolved
  `ETISALAT_EG_001` → Zendit `DONE`.
- RANGE: `96f71cec…` — Zong, `offer_id` NULL, $0.50 → resolved `ZONG_PK_OPEN`,
  value 12305 PKR-minor → success.

### 2. Five carriers had wrong Zendit brand names

`zen_carrier` didn't match Zendit's brand codes, so even a fixed fallback found
nothing: `AT&T`→`Att`, `T-Mobile`→`Tmobile`, `Turk Telekom`→`TurkTelekom`,
`Vi`→`VodafoneIdea`, `WE`→`WETelecom`. Fixed in migration
`20260716020000_b1_carrier_zen_brands_and_offer_backfill.sql`. (WE Egypt's
pinned `WETELECOM_EG_01` was always valid — only its brand filter was broken.)

### 3. offer_id backfill: 7 pinned, 13 impossible

Plan expected 48 null rules; only 20 were left. Same migration pinned 7 from
the sandbox catalog (AT&T, T-Mobile, Verizon, Etisalat EG, Turk Telekom, Vi,
Zong) and realigned their `minimum/recommended_topup_amount` to the offer's
real USD price. **13 carriers have no Zendit sandbox coverage at all** (offers
enumerated per country, zero for these brands):

> Mint Mobile, Mobily, Zain KSA, O2 UK, Three UK, Vodafone UK, Omantel,
> Ooredoo Oman, Ooredoo Kuwait, STC Kuwait, Zain Kuwait, Umniah,
> Virgin Mobile UAE

Their `offer_id` stays NULL and API fulfilment will fail with a clear "no
matching offer" message. They need `MANUAL`/`TASKER_SCRIPT` routing or a second
provider (E2 Reloadly) — revisit at E1 with the production catalog.

### 4. Double-debit was real, not theoretical

Executions `fcab87db…` and `40eec7ae…` each had **3 debits + 3 refunds** for
the same execution (reaper requeued a stuck row; each retry debited again —
matches `reap_stuck_executions`' 3-retry limit). The old code also had a
**free-refund bug**: any error inside the debit RPC threw into the catch block,
which refunded a debit that had never happened.

## Why double-charging is now impossible

1. **One claim at a time.** `claim_due_executions` / `claim_instant_executions`
   flip `status` → `processing` under `FOR UPDATE SKIP LOCKED`; a row can only
   be claimed in status `pending`/`routing`, so two workers can't hold it
   concurrently. The only re-entry path is the reaper requeueing a row stuck
   `processing` > 15 min (cron every 5 min, max 3 retries → dead-letter +
   `system_alerts`).
2. **At most one debit per execution — enforced by the database.**
   `wallet_transactions` has partial unique indexes on `reference_id` for
   `type='topup_debit'` and `type='refund'`
   (`20260716021000_b1_wallet_txn_idempotency.sql`). Workers debit via
   `debit_wallet_for_topup(..., p_reference_id => 'exec_<execution_id>')`
   (`20260716022000`): balance change and ledger row commit in one transaction,
   so a duplicate reference rolls back the entire debit (`unique_violation`).
   Verified live: replaying the debit for execution `9170c4db…` was rejected
   and the balance was unchanged. A retried worker treats the violation as
   "already debited" and continues.
3. **At most one provider purchase per execution.** Zendit `transactionId` is
   now the stable `z_<execution_id>` (was `z_sand_<Date.now()>`, which created
   a *new* purchase on every retry). If the POST is rejected because the id
   exists, the worker adopts the existing purchase's status instead of failing.
4. **Refunds are idempotent and only follow real debits.** The
   read-modify-write refund (lost-update prone) is gone; workers call
   `credit_wallet_for_refund` with `refund_exec_<execution_id>` (same unique
   protection), only when the debit actually happened (`walletDebited` flag),
   and a *failed* refund now raises a `system_alerts` row instead of a silent
   log line.
5. **No ledger-free balance movement remains.** `deduct_wallet_atomic` /
   `refund_wallet_atomic` are dropped (`20260716023000`); balance writes exist
   only inside `debit_wallet_for_topup`, `credit_wallet_for_refund`,
   `credit_wallet` and `wallet_transact` — all `SECURITY DEFINER`, all
   service-role-only, all writing balance + ledger atomically.

Residual (accepted) race: if a worker hangs > 15 min *after* purchasing and a
retry runs while the first eventually fails, the user can end up refunded for a
delivered top-up (our loss, never the user's). The stable transactionId +
adoption makes this window nearly unreachable.

**Live proof of the money path** (test user `a1-wallet-test@example.com`):
- Success: `9170c4db…` instant refill $0.39 → single atomic debit
  57.70 → 57.31, `exec_…` reference, Zendit success.
- Failure: `b989e106…` $0.05 (matches no offer) → debit 57.31 → 57.26, refund
  57.26 → 57.31, `refund_exec_…` reference, status `failed`.
- Fast path after backfill: `4de7f7a7…` with pinned `ETISALAT_EG_001` → success.

## Reconciliation

View `public.wallet_reconciliation` (service-role only):
`balance − Σ(signed ledger)` per wallet. Result: **every wallet reconciles to 0
except one** — the developer account `thehonestgoma@gmail.com` (drift −875.04),
legacy damage from the pre-server-side-writes era (client wrote `balance`
directly; old debits had no ledger rows). Annotated here per plan; no synthetic
correction entries were inserted. Sandbox-only account.

## refill_custom schedule math vs. claim window (B1 item 4)

`RefillScheduleMath` uses absolute UTC instants (`nowUtc.add(Duration(days:))`)
and the repository converts to UTC before insert; the worker claims
`execution_time <= NOW()` on `timestamptz`. No cron-style recurrence exists, so
timezone/DST/end-of-month arithmetic cannot skew — worst case a refill fires at
a different local wall-clock hour, days early by design (85/28/13-day safety
margins). One real defect fixed:
`ScheduledTopupRepository.updateSchedule` requeued the execution **without**
`offer_id`/`offer_value` (createSchedule includes them), silently downgrading
edited schedules to the fallback path.

## Also fixed / reconciled

- `ecosystem.config.js` now matches the live PM2 processes (underscore names,
  1 instance each) and the running workers were relaunched *from* the config +
  `pm2 save`, so `pm2 startup` (D5) will resurrect the real set. `server_baileys`
  deliberately unmanaged (live WhatsApp session; retired at E1).
- Backend repo pushed to GitHub from the workstation via git bundle (VM still
  has no push credentials — leftover A3 item).

## Flagged for later sessions

| Finding | Where it goes |
|---|---|
| `check_topup_rate_limit` trigger tests `execution_type = 'instant'` but real rows use `refill_instant` — the rate limit never fires | D2 (rate limiting) |
| `execute_zendit_recharge` Edge Function purchases without any wallet debit and picks the *closest* offer to the amount (dev simulator path) | C3 replaces it with the `topup_executions` insert flow |
| Client still INSERTs/UPDATEs/DELETEs `topup_executions` rows (schedule requeue, simulateExecution, retryExecution mock success) | C3 + A4 leftover: move behind RPC, then revoke |
| `deposit` reference duplicates exist (11 distinct / 18 rows); idempotency by PayPal `capture_id` | B3 |
| Pricing drift on pre-B1 pinned rules (e.g. STC rule min 6.25 vs current offer $7.10) | E1 production catalog re-verify |
| 13 carriers unfulfillable via Zendit sandbox (list above) | E1 / E2 |

## Test fixtures kept

SIM lines on test user `e5a56433-6f75-41a3-96b9-19c62b9d1280`
(`a1-wallet-test@example.com`): `B1 test Etisalat EG` (+201012345678),
`B1 test Zong PK` (+923151234567), `B1 test Vodafone EG` (+201001234567) —
premium plan, safe to reuse for future money-path tests.
