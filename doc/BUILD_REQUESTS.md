# KeepSIMs — Production Readiness Build Requests

> **Superseded for planning by `doc/PRODUCTION_PLAN.md` (2026-07-16).** That
> file merges these requests with the pre-production master plan and current
> statuses. Keep this file as the original audit record.

Derived from a live audit of the Flutter repo, the Supabase project
(`zwxswagokhgbuzrrbnhr`), and the `keepsims-staging` GCE VM running the PM2
workers.

Each request is self-contained: hand one at a time to an AI agent.

**Status legend:** ✅ done · 🔴 blocking · 🟠 important · ⚪ later

---

## Findings summary

| # | Finding | Severity |
|---|---|---|
| 1 | `credit_wallet` / `debit_wallet_for_topup`: `SECURITY DEFINER`, `anon`-executable, no auth check | ✅ fixed (REQUEST A) |
| 2 | `wallets` UPDATE policy restricts row, not column — user can PATCH own `balance` | 🔴 |
| 3 | `update_execution_status` / `_failed`: `SECURITY DEFINER` + `anon` | ✅ fixed (REQUEST A) |
| 4 | `bind_telegram_bot`: `SECURITY DEFINER` + `anon` — bind Telegram to any account | ✅ fixed (REQUEST A) |
| 5 | `service_role` JWT hardcoded at `worker_instant_refill.js:30` | 🔴 |
| 6 | Zendit secret hardcoded in `zendit_repository.dart:8` AND `worker_*.js:31` | 🔴 |
| 7 | `worker_auto_mini_refill.js:159` missing `_offset` → 400 on the fallback path; 48/49 carrier_rules have null `offer_id` and depend on it | ✅ applied, unproven |
| 8 | Worker refund path is read-modify-write on `balance` | 🟠 |
| 9 | Deduct + ledger insert are non-atomic | 🟠 |
| 10 | `calculate_health_score` overloaded x2, UI computes a 3rd | 🟠 |
| 11 | `claim_*` sets `processing` with no reaper | 🟠 |
| 12 | Only one pg_cron job; no DB-side refill safety net | 🟠 |
| 13 | Backend `NOT A GIT REPO` — 2,070 lines, single VM | 🟠 |
| 14 | `search_path` missing on several `SECURITY DEFINER` functions | 🟠 |
| 15 | Zendit key is `sand_` — sandbox, no real top-ups | ⚪ |

Not launched: 7 profiles, 9 sim_lines, 129 test transactions. Nothing above is
an active breach. All of it must close before the first real user.

---

# Phase 0 — Security

## ✅ REQUEST A — Revoke public EXECUTE on privileged RPCs (DONE)

Applied as migration `revoke_public_execute_on_privileged_rpcs`.
Revoked `EXECUTE` from `PUBLIC`/`anon`/`authenticated` on: `credit_wallet`,
`debit_wallet_for_topup`, `deduct_wallet_atomic`, `refund_wallet_atomic`,
`update_execution_status`, `update_execution_failed`, `apply_referral`,
`bind_telegram_bot`. `service_role` retains explicit grants; workers verified
unaffected (same PIDs, no restarts).

`is_power_user` deliberately **excluded** — nine RLS policies invoke it
(`sim_lines`, `topup_executions`, `refill_requests`, `countries`,
`system_configs`); revoking it would break RLS evaluation app-wide.

Follow-up: `claim_due_executions` / `claim_instant_executions` remain
`anon`-executable. They are not `SECURITY DEFINER`, so RLS contains them, but
revoking is cheap hygiene.

## 🔴 REQUEST B — Stop users writing their own wallet balance

The `wallets` policy `"Users can update own wallet"` uses
`USING (auth.uid() = user_id)` with a matching `WITH CHECK`, constraining which
*row* a user may touch but not which *columns*. Any authenticated user can
`PATCH /rest/v1/wallets?user_id=eq.<self>` with `{"balance": 999999}`.
`wallet_transactions` INSERT has the same shape, permitting forged ledger rows.

Balance must only ever change via `SECURITY DEFINER` functions called by
`service_role`. Drop the UPDATE policy on `wallets`; `REVOKE UPDATE, INSERT ON
wallets, wallet_transactions FROM anon, authenticated`. Leave SELECT policies
intact so users still read their own balance. Apply the same reasoning to
`topup_executions` — users must not set `status='completed'` on their own rows.

> ⚠️ **This request is load-bearing — unlike REQUEST A.**
> `lib/features/wallet/repository/wallet_repository.dart` writes
> `.from('wallets')` and `.from('wallet_transactions')` **directly** from the
> client (lines 221–225, 291–295). That is the vulnerability, and it is also how
> deposits currently work. Revoking these grants **will break every deposit**
> until the write path moves server-side.
>
> Correct order: (1) build a server-side deposit path (Edge Function or worker
> calling `credit_wallet` as `service_role`); (2) migrate
> `wallet_repository.deposit()` to call it; (3) verify a real deposit
> end-to-end; **then** (4) revoke.
>
> REQUEST A was safe precisely because nothing called those functions. Verify
> callers across **all** surfaces before revoking anything — the Flutter app,
> the PM2 workers, Edge Functions, and any web frontend (`keepsims.com`).

## 🔴 REQUEST C — Get every credential out of source

Three hardcoded secrets:

1. A `service_role` JWT at `worker_instant_refill.js:30`, reached because the
   worker reads `SUPABASE_SERVICE_ROLE_KEY` while `.env` only defines
   `SUPABASE_KEY` — the `||` fallback silently hides this. Same pattern in
   `worker_auto_mini_refill.js:30` and `worker_auto_custom_refill.js:30`.
2. The Zendit secret at `worker_*.js:31`.
3. The same Zendit secret at `lib/features/topup/data/repositories/zendit_repository.dart:8`.

Rotate all three. Move them to `.env` with correct variable names and **delete
every `||` literal fallback** so a missing variable crashes loudly at boot
instead of running on a stale key. The Flutter client must never hold a top-up
credential — route through an Edge Function (`supabase/functions/fetch_zendit_offers`
is the existing pattern). Note `ESIM_GO_API_KEY` via `flutter_dotenv` is also
unsafe: `.env` bundles as an app asset and is extractable.

## 🟠 REQUEST C2 — Harden `search_path` on SECURITY DEFINER functions

Split out of REQUEST A because `SET search_path = ''` breaks any function with
unqualified table references. Functions missing `search_path`: `apply_referral`,
`is_power_user`, `update_execution_status`, `update_execution_failed`,
`calculate_health_score(uuid,text,timestamptz)`. **Read each body first**; fully
qualify every table reference (`public.foo`), then add `SET search_path = ''`.
Test each function after.

---

# Phase 1 — Correctness

## ✅ REQUEST D0 — Fix the auto mini refill fallback path (APPLIED, UNPROVEN)

`worker_auto_mini_refill.js:159` built the Zendit offers URL with `&_limit=50`
but no `&_offset`. Zendit requires `_offset` whenever `_limit` is present, so
the call returned `400 INVALID_VALUE: _offset: required` every time (12/12).

**Applied 2026-07-15**: line 159 now `&_limit=50&_offset=0`. Backup at
`worker_auto_mini_refill.js.bak.20260715190706`; `diff` confirms line 159 is the
only change; worker restarted.

**Scope — read this before trusting the old severity.** The Offers API lookup is
a *fallback*, reached only when `execution.offer_id` is null (worker line 154).
When `offer_id` is set the worker skips the lookup entirely and succeeds. So the
bug never broke the whole product — but it is still serious:

* **48 of 49 `carrier_rules` have a NULL `offer_id`.** Only one carrier
  (Vodafone Egypt / `VODAFONE_EG_OPEN`) is configured.
* Every execution to date carries an `offer_id` and therefore takes the fast
  path. That is why successes exist (2 on 07-13, 1 on 07-15).
* Any line on the other 48 carriers hits the fallback — which was 100% broken.

**Still to do:**

1. **Prove the fix.** No execution has exercised the fallback since the restart.
   Create a test line on a carrier with a null `offer_id` (i.e. anything but
   Vodafone Egypt) and confirm the refill completes.
2. **Populate `offer_id` on the other 48 `carrier_rules`**, so the fast path is
   the norm and the fallback is genuinely exceptional.
3. **Alerting on sustained worker failure** — 12 consecutive 400s went unnoticed
   for days (see REQUEST H).
4. Add a test asserting a non-empty offers list per supported carrier.

## 🟠 REQUEST D — Make deduct/refund atomic and always ledgered

`deduct_wallet_atomic` and `refund_wallet_atomic` mutate `wallets.balance`
without writing `wallet_transactions`; the worker inserts the ledger row
separately (`worker_instant_refill.js:143`), so a failure between the two leaves
money debited with no record. The refund path (~325–330) does `select('*')` then
`update({balance: refundedBalance})` — a read-modify-write race that loses
concurrent updates — and ignores `refund_wallet_atomic` entirely.

Consolidate onto `debit_wallet_for_topup` and a new `credit_wallet_for_refund`,
both `SECURITY DEFINER` with `SET search_path=''`, each performing balance update
*and* ledger insert in one transaction, returning the txn id. Delete
`deduct_wallet_atomic` / `refund_wallet_atomic` once callers migrate. Add a
reconciliation query proving `wallets.balance` equals the sum of that user's
`wallet_transactions` for all accounts.

## 🟠 REQUEST E — One health score

`calculate_health_score` is overloaded twice: `(uuid, text, timestamptz)` scores
auto-refill 50 + `status='active'` 25 + refill-within-80-days 25 (its comment
says "Verified" but it reads `status`, not `verification_status` — the comment
lies); `(timestamptz, timestamptz)` is an unused `IMMUTABLE` time-decay variant.
The Flutter UI computes a third version in `dashboard_sim_line_card.dart:49` and
`sim_line_card.dart:84`, keyed on `isVerified` and forcing 100 when `isHomeMode`.

Three sources of truth that disagree. Pick one definition, keep it in the DB,
drop the unused overload, make both UI sites read `line.healthScore`, and fix the
misleading comment. Pairs with REQUEST F.

## 🟠 REQUEST F — Decouple home-mode from protection (unlocks residents/citizens)

`is_home_mode` conflates "user is in this SIM's country" with "pause protection."
When true, `sim_lines_controller.dart:374` pauses all schedules and the UI forces
health to 100. A resident's dormant second SIM is permanently home → permanently
unprotected → displayed as perfectly healthy while it dies at 90 days.

Add `protection_paused` (intent) and `requires_protection_at_home`; backfill
`protection_paused = is_home_mode`; key all pausing on `protection_paused`.
Exclude `requires_protection_at_home` lines from `freezeAllInternationalLines()`
in `geo_controller.dart`. Fold in REQUEST E so a protected line at home reports
true risk. Tests: resident's dormant line stays protected at home; expat's line
still auto-freezes.

---

# Phase 2 — Operations

## 🟠 REQUEST G — Put the backend in version control

`/home/abdal/keepsims_backend` on `keepsims-staging` is `NOT A GIT REPO`: 2,070
lines running all money movement, on one VM, no history, review, or rollback.
Stale duplicates exist — `server_baileys.js`, `server_tg.js`, `server_ww.js` at
both root and `servers/`, while `ecosystem.config.js` runs only the `servers/`
copies — plus `test_zendit.js` in production and two PM2 entries for
`server_baileys` (id 3 stopped, id 12 online).

Initialize a repo; commit `servers/` and `ecosystem.config.js` with a strict
`.gitignore` for `.env`. **Rotate keys (REQUEST C) first so no secret enters
history.** Delete the stale root duplicates and `test_zendit.js`; deregister the
dead PM2 entry. Then bring it into the Flutter repo under `backend/` or give it
its own remote.

## 🟠 REQUEST H — Stuck-execution reaper and DB-side safety net

`claim_due_executions` / `claim_instant_executions` flip rows to `processing` and
return; nothing resets them, so a worker crash mid-flight strands a row forever.
Separately, `cron.job` has exactly one entry (`process_due_notifications`,
hourly) — there is **no database-side cron for refills**. If PM2 stops, refills
stop silently and no alert fires; on a 90-day deadline a multi-day outage kills
customer SIMs (see REQUEST D0 — a 0% success rate went unnoticed for days).

Add a pg_cron job resetting `processing` rows older than N minutes to `pending`
with an attempt counter and dead-letter status after M retries; a second job
alerting if no execution succeeds within an expected window. Add `pm2 startup` +
`pm2 save` and external uptime monitoring.

## 🟠 REQUEST I — Delete the mocked Dart backend

Resolved: the Node workers in `/home/abdal/keepsims_backend/servers/` are
authoritative and running. `lib/backend/fulfillment/` is dead Dart whose
`api_strategy.dart` marks refills `completed` after a 2-second delay without
contacting any provider, and whose `tasker_strategy.dart` only prints. Delete
`lib/backend/` and `bin/fulfillment_server.zip`. Code that fakes financial
success is a hazard the moment someone imports it believing it works.

## 🟠 REQUEST J — Go live on Zendit, and replace Baileys

Workers run against Zendit **sandbox** (`sand_` key) — confirm that's intentional
for staging. Plan the production cutover: production credentials via `.env` only,
a real-money smoke test per gateway, and confirmation that `TASKER_SCRIPT` and
`MANUAL` routes work end-to-end (only `API` appears in `topup_executions` — the
other two gateways are **unexercised**).

Separately, `server_baileys` is an unofficial WhatsApp library and the pricing
page sells WhatsApp notifications on paid tiers. Meta bans accounts for this,
which would take a paid feature down with it. Migrate to the WhatsApp Business API.

---

# Phase 3 — Product completion

Strictly after Phases 0–2.

## ⚪ REQUEST 9 — Wire up Instant Recharge (server-side)

Sold on the pricing page but unreachable in-app: `ITopUpRepository.executeRecharge`
is only called by `settings/presentation/screens/zendit_simulator_screen.dart:184`
— a dev simulator. `worker_instant_refill.js` works (log shows successful Zendit
transactions). Only the Flutter entry point is missing.

Build "Recharge Now": entry points on `sim_line_detail_screen.dart` and the
dashboard card; amount seeded from `carrier.defaultRefillAmount`; wallet balance
check with top-up prompt; **insert a `topup_executions` row** (the trigger
`route_topup_execution` assigns the gateway and bumps `refill_instant` from
`pending` to `routing`, which `claim_instant_executions` then picks up) rather
than calling Zendit from the client. Subscribe to realtime for status. Follow
`ARCHITECTURE_RULES.md`; add ARB strings for all nine locales; test the
insufficient-balance and provider-failure paths.

## ⚪ REQUEST 10 — Harden Offline Recharge

`lib/features/offline_recharge/` is 1,684 lines, 1,367 in one UI file, against a
52-line controller. Business rules (dialer/SMS/WhatsApp launch at 145–176,
realtime listener at 198, timeline at 222) live in the widget. Extract to the
controller/repository per `ARCHITECTURE_RULES.md`. Add explicit failure states
for unreachable gateway number and listener timeout; retry with backoff; a
fallback when `carrier.gatewayPhoneNumber` is null; latency messaging. Test the
state machine.

## ⚪ REQUEST 11 — Complete eSIM management

`lib/features/esim/` is a facade: both CTAs in `esim_screen.dart` (lines 81, 96)
call `_showComingSoonSheet`. Build: browse bundles by destination, purchase
against the existing wallet, QR/activation delivery, "My eSIMs" with data
remaining and expiry, low-data alerts via `lib/features/notifications/`. Route
eSIM Go calls through an Edge Function (REQUEST C). Surface eSIMs alongside
physical lines so the app reads as one number hub. ARB strings for nine locales.

## ⚪ REQUEST 4 — Local payment rails (mada, STC Pay, Apple Pay)

`lib/features/payments/` supports only Stripe and PayPal, which most of the
target audience (South Asian migrant workers and GCC residents) don't hold.
Extend `payment_method_model.dart` and `payment_gateways` for mada, STC Pay,
Apple Pay. Evaluate Moyasar / Tap / MyFatoorah and report trade-offs before
implementing. Keep `PaymentMethod.provider` polymorphic. Tokenization only —
never store raw PANs.

## ⚪ REQUEST 3 — Critical / OTP line tier

Add `lineCriticality` (`normal` | `critical`) on `SimLine`. A `critical` line
never auto-freezes, escalates alerts across every enabled channel at
30/14/7/3/1 days before `validity_expires_at`, and pins to the top of the
dashboard. Present as "Bank / OTP line — never let this number die," citing
`pricing & Features/KSA_Telecom_SIM_Rules.md`: terminated numbers return to the
operator's public pool and are resold to new customers — an account-takeover
vector for any number registered with a bank. ARB strings for nine locales.

## ⚪ REQUEST 7 — Business / fleet accounts

Extend `lib/features/household/` into an organization tier: CSV bulk import,
org roles (owner/admin/viewer), consolidated billing against one wallet, fleet
dashboard grouped by health. Target: businesses with dormant IoT/POS/fleet SIMs —
dormant by design, and far higher ARPU than $0.50/month consumers. Reuse the
`households` model; follow `ARCHITECTURE_RULES.md`.

## ⚪ REQUEST 8 — Test suite for money paths

Zero tests exist. Establish `test/` with `flutter_test` + `mocktail`. Priority:
(1) `scheduled_topups` execution and rescheduling, (2) `wallet` arithmetic and
`calculate_topup_fees`, (3) `carrier_rule` expiry math including
`grace_period_days`, (4) the `route_topup_execution` gateway chain. Mock Supabase
at the repository boundary. Target meaningful coverage of financial logic, not a
percentage.

## ⚪ REQUEST 5 — Strip dev simulators from release builds

`paypal_simulator_screen.dart` (2,156), `paypal_refill_simulator_screen.dart`
(2,078), `alert_simulator_screen.dart` (834), `zendit_simulator_screen.dart`
(481) total 5,549 lines and are routed live at `/settings/simulators` and
`/settings/tests` in `lib/core/router/app_router.dart`. Gate behind `kDebugMode`
or a `--dart-define` flag so they compile out of release. Verify the release
bundle excludes them.

## ⚪ REQUEST 6 — Fulfillment redundancy

`api_offers_providers.dart` has unimplemented TODOs for Ding (62), DTConnect (72),
Reloadly (82); `carriers.api_provider` already anticipates multiple providers.
Implement Reloadly (`carrier_model.dart` already has `reloadly_operator_id`)
behind the same interface as `zendit_repository.dart`. Add failover in
`route_topup_execution` so a provider outage falls through before `MANUAL`.
Test the failover chain.
