# KeepSIMs — Pre-Production Master Plan (v2)

Supersedes the planning role of `doc/BUILD_REQUESTS.md` (which remains the audit
record). This merges: (1) the original audit requests and their current status,
(2) the Pre-Production Audit & Finalization plan, (3) the user's answers to the
open questions (notifications, offline recharge, alerts, geolocation,
refer & earn, activity logs, ticketing).

**Each request below is self-contained and sized for one AI-agent session.**
Hand one at a time. Do them in phase order; within a phase, follow the noted
dependencies.

**Status legend:** ✅ done · 🟡 in progress / partially done · 🔴 blocking ·
🟠 important · ⚪ later

**Ground rules for every session** (do not restate per request):
- Zendit stays **sandbox**, PayPal stays **sandbox** until Phase E.
- All secrets live in Supabase Vault / Edge Function secrets / VM `.env` — never
  in Dart or committed files. `flutter_dotenv` assets are extractable; treat the
  Flutter client as public.
- Wallet balance changes only through `SECURITY DEFINER` functions invoked
  server-side (`wallet_transact`, `debit_wallet_for_topup`,
  `credit_wallet_for_refund`).
- Follow `ARCHITECTURE_RULES.md`; any user-visible string needs ARB entries for
  all nine locales.
- Live Supabase project: `zwxswagokhgbuzrrbnhr` (user has approved direct
  changes). Backend VM: `keepsims-staging` GCE, PM2 workers in
  `/home/abdal/keepsims_backend/servers/`.
- End every session with: `flutter analyze` clean (157 pre-existing infos are
  acceptable), tests passing, and a smoke test of the touched flow.

---

## Where things stand (2026-07-16)

| Old request | Subject | Status |
|---|---|---|
| A | Revoke public EXECUTE on privileged RPCs | ✅ done |
| B | Stop client wallet writes | 🟡 app writes moved server-side (`wallet_transact` deployed); **revoke migration written but NOT applied** — gated on an end-to-end deposit test → **A1** |
| C | Secrets out of source | 🟡 Flutter half done (`zendit_repository` → Edge Functions); VM worker secrets + rotation remain → **A2** |
| C2 | `search_path` hardening | ✅ done (migration `harden_search_path_and_single_health_score`) |
| D0 | Mini-refill fallback `_offset` fix | ✅ done as **B1** 2026-07-16 — `_offset` was a misdiagnosis; fallback rewritten (ISO-2, minor units, priceType), proven live; 7 more `offer_id` pinned, 13 carriers have no sandbox coverage (see `B1_B2_REFILL_MONEY_AUDIT.md`) |
| D | Atomic deduct/refund + ledger | ✅ done as **B2** 2026-07-16 — workers on `debit_wallet_for_topup`/`credit_wallet_for_refund` with per-execution unique references; legacy fns dropped; `wallet_reconciliation` view added |
| E | One health score | ✅ done (DB overload dropped, `sim_line_health.dart` extension, 3 UI sites) |
| F | Decouple home-mode from protection | 🟠 not started → **B5** |
| G | Backend into git | 🟠 not started → **A3** |
| H | Stuck-execution reaper + DB safety net | ✅ DB side done (reaper 5min, pipeline health hourly, `system_alerts`); `pm2 startup/save` + external uptime remain → **D5** |
| I | Delete mocked Dart backend | ✅ done (`lib/backend/`, `bin/fulfillment_server.zip` deleted, uncommitted) |
| J | Zendit go-live + replace Baileys | ⚪ → **E1** (WABA arrives earlier via **C4**) |
| 3–11 | Product completion items | Mapped into Phases C–E below |

> ⚠️ Much of the done work is **uncommitted in the Flutter tree**. First action
> of the next session: commit the current working tree (excluding
> `paypal_refill_simulator_screen.dart` / `manual_refill_bottom_sheet.dart`
> only if the user still has personal edits there — ask).

---

# Phase A — Close out security (do first, in order)

## 🔴 A1 — Verify deposit end-to-end, then apply the wallet revoke migration

Finishes old REQUEST B. `supabase/migrations/20260716000000_revoke_client_wallet_writes.sql`
exists but is deliberately unapplied: it drops client write policies/grants on
`wallets` and `wallet_transactions` (keeping the column-scoped `auto_fund_*`
UPDATE), and until a deposit is proven through the new server path, applying it
would break deposits.

1. With the user (or via the PayPal sandbox simulator flow), run a deposit in
   the app end-to-end. The app path is
   `lib/features/wallet/repository/wallet_repository.dart` → Edge Function
   `wallet_transact` (deployed v1, JWT + `auth.getUser` gated). Confirm balance
   and `wallet_transactions` ledger row both update.
2. Also exercise `scheduled_topup_repository.simulateExecution` and
   `retryExecution` (both now route through `wallet_transact`).
3. Apply the migration via Supabase MCP `apply_migration`.
4. Prove the lock: as an `authenticated` user, attempt
   `PATCH /rest/v1/wallets?user_id=eq.<self>` with `{"balance": 999999}` and an
   INSERT into `wallet_transactions` — both must fail. Re-run a deposit — must
   still succeed.
5. Regression: dashboard balance display, top-up flow, auto-fund toggle
   (`auto_fund_*` columns must remain user-updatable).

Acceptance: forged balance write fails; legit deposit works; ledger consistent.

## 🔴 A2 — Rotate and remove the VM worker secrets

Finishes old REQUEST C (VM half; Flutter half is done). On `keepsims-staging`,
in `/home/abdal/keepsims_backend/servers/`:

1. `worker_instant_refill.js:30`, `worker_auto_mini_refill.js:30`,
   `worker_auto_custom_refill.js:30` — hardcoded `service_role` JWT reached via
   a `|| '<literal>'` fallback because `.env` defines `SUPABASE_KEY` but the
   code reads `SUPABASE_SERVICE_ROLE_KEY`. Fix the variable name in `.env`,
   **delete every `||` literal fallback** so a missing var crashes at boot.
2. `worker_*.js:31` — hardcoded Zendit secret. Move to `.env`.
3. **Rotate both**: regenerate the Supabase `service_role` key (Dashboard →
   Settings → API) and the Zendit sandbox key. Update `.env`, restart PM2,
   verify workers reconnect (check a claim cycle succeeds in logs).
4. Grep the whole VM tree for any remaining `eyJ`/`sand_` literals.

Acceptance: no secret literals anywhere on the VM; workers healthy after
restart with rotated keys.

## 🟠 A3 — Put the backend in version control (after A2)

Old REQUEST G, unchanged. `/home/abdal/keepsims_backend` is not a git repo:
2,070 lines moving money, no history. Stale duplicates (`server_baileys.js`,
`server_tg.js`, `server_ww.js` at root **and** `servers/`; `ecosystem.config.js`
runs only `servers/`), `test_zendit.js` in production, and a dead PM2 entry
(`server_baileys` id 3 stopped vs id 12 online).

Init repo; strict `.gitignore` for `.env` (A2 must be done first so no secret
enters history); commit `servers/` + `ecosystem.config.js`; delete the stale
root duplicates and `test_zendit.js`; `pm2 delete` the dead entry; add a remote
(own repo or `backend/` subtree of the Flutter repo — ask user which).

## 🟠 A4 — Full RLS, constraint, and advisor sweep

The master plan's Phase 6, done as one audit session against live Supabase:

1. Run MCP `get_advisors` (security + performance); fix every security finding.
2. Enumerate all tables (`list_tables`); for each, verify RLS is enabled and
   policies scope by `auth.uid()` — read **and** write. Known gap to close:
   `topup_executions` — the app still writes `status` client-side; move that
   write behind an RPC/Edge Function, then revoke client UPDATE (coordinate
   with C3, which replaces the client write path).
3. Cheap hygiene from REQUEST A follow-up: revoke `anon` EXECUTE on
   `claim_due_executions` / `claim_instant_executions`.
4. Postgres-level constraints: `CHECK (amount > 0)` on money columns
   (`wallet_transactions.amount`, top-up amounts), NOT NULL on foreign keys,
   sane enums for `status` columns.
5. Storage buckets: verify policies (matters before C7 adds ticket
   attachments).

Acceptance: advisor security findings = 0 (or documented exceptions); a written
table-by-table RLS matrix committed as `doc/RLS_MATRIX.md`.

---

# Phase B — Money-path correctness

## ✅ B1 — Refill engine audit: instant / mini / custom, no double charging

**Done 2026-07-16 (with B2, one session). See `doc/B1_B2_REFILL_MONEY_AUDIT.md`.**

Master plan Phase 1 + old D0 leftovers, in one session on the VM + DB:

1. **Prove the `_offset` fix**: create a test line on a carrier with null
   `offer_id` (anything but Vodafone Egypt) and confirm
   `worker_auto_mini_refill.js` completes a refill via the Offers-API fallback.
2. **Populate `offer_id` on the other 48 `carrier_rules`** so the fast path is
   the norm. Script it against the Zendit sandbox catalog; flag carriers with
   no matching offer.
3. **Double-charge audit** across all three flows (`refill_instant`,
   `refill_mini`, `refill_custom`): verify the claim functions'
   `processing_since`/reaper interplay (REQUEST H work) cannot let two workers
   process one row; verify a reaped-and-retried row cannot debit twice (the
   debit must be idempotent per execution id — add an idempotency key /
   `UNIQUE` constraint on `wallet_transactions(execution_id)` if absent).
4. Validate `refill_custom` threshold/date logic in
   `lib/features/scheduled_topups/` against the worker's claim window —
   boundary cases: timezone, DST, end-of-month.

Acceptance: fallback refill proven on a null-`offer_id` carrier; a written
argument (with constraints in place) why double-debit is impossible.

## ✅ B2 — Migrate workers to the atomic wallet functions, drop the old ones

**Done 2026-07-16 (with B1). See `doc/B1_B2_REFILL_MONEY_AUDIT.md`.**

Finishes old REQUEST D. `credit_wallet_for_refund` is deployed and smoke-tested;
the VM workers still use `deduct_wallet_atomic` / `refund_wallet_atomic`, and
the refund path (`worker_instant_refill.js` ~325–330) is still a
read-modify-write on `balance` with a separate ledger insert (line ~143).

1. Point the workers' debit path at `debit_wallet_for_topup` and the refund
   path at `credit_wallet_for_refund` (each does balance + ledger in one txn).
2. Remove the manual ledger inserts and the `select → update` refund block.
3. Restart PM2; run one refill and one forced-failure refund in sandbox.
4. Drop `deduct_wallet_atomic` / `refund_wallet_atomic` by migration.
5. Add the reconciliation query as a saved view:
   `wallets.balance = SUM(wallet_transactions.amount)` per user; run it — must
   hold for all accounts (129 test transactions exist; fix or annotate drift).

Requires A2/A3 done (you'll be editing VM code — do it under git).

## ✅ B3 — PayPal webhook hardening + receipts

**Done 2026-07-16** (see `doc/B1_B2_REFILL_MONEY_AUDIT.md`, B3 section).
Secrets set on webhook `5FA85715EA0979031` ("KeepSIMs us" REST app); verified
e2e: sandbox card capture `8T699212A1920500M` → webhook → $1.23 credit with
full receipt metadata (gross/fee/net/ids).

Master plan Phase 2. PayPal is sandbox and stays sandbox, but the plumbing must
be production-shaped:

1. Locate the current payment-success path (note:
   `paypal_refill_simulator_screen.dart` **is the live payment flow** used by 4
   production screens — do not delete it; see D4). Deposits must be credited by
   a **server-side webhook** (Edge Function verifying PayPal's
   `PAYPAL-TRANSMISSION-SIG` / webhook-id against the PayPal API), never by the
   client claiming success.
2. Idempotency: webhook retries must not double-credit — key on PayPal
   `capture_id` with a `UNIQUE` constraint.
3. On credit, write a receipt record (extend `wallet_transactions` metadata or
   a `receipts` table: gross, fees, method, external txn id) and surface it in
   the wallet UI transaction detail.
4. Failure paths: underpaid/currency-mismatch/refunded webhooks → alert row in
   `system_alerts`.

## ✅ B4 — Money-path test suite

**Done 2026-07-16.** Dart: 27 tests (`refill_schedule_math` incl. month-end/
year-end/leap-day/DST claim-window safety, `sim_line_health` incl. B5 cases,
`carrier_rule` money parsing). DB: `supabase/tests/b4_money_path_tests.sql` —
11 assertions run live inside BEGIN..ROLLBACK covering `calculate_topup_fees`,
`route_topup_execution`, `debit_wallet_for_topup` (happy/duplicate/overdraft/
negative), `credit_wallet_for_refund`, `credit_wallet_for_deposit` (receipt +
capture idempotency), and the zero-drift reconciliation invariant. All passed
against live on 2026-07-16. Deferred: mocktail repository-boundary tests for
controller flows (add alongside C-phase features as they change).

Old REQUEST 8; seed exists (`refill_schedule_math.dart` + 19 passing tests).
Extend `test/` with `flutter_test` + `mocktail`, mocking Supabase at the
repository boundary. Priority order:

1. `scheduled_topups` execution + rescheduling (build on the seed),
2. wallet arithmetic + `calculate_topup_fees`,
3. `carrier_rule` expiry math incl. `grace_period_days`,
4. `route_topup_execution` gateway chain (SQL tests or pgTAP — the trigger
   lives in the DB).

Target meaningful coverage of financial logic, not a percentage.

## ✅ B5 — Decouple home-mode from protection

**Done 2026-07-16.** `protection_paused` (intent) + `requires_protection_at_home`
added and backfilled (`20260716040000`); all pausing/health/UI-suppression keys
on `protection_paused`; `toggleHomeMode` computes the pause from
`requires_protection_at_home`; new `setRequiresProtectionAtHome` + shield
toggle in the line detail app bar (ARB strings in all 9 locales);
`freezeAllInternationalLines()` skips always-protected lines; health tests
cover the resident-dormant-line case.

Old REQUEST F, verbatim scope. `is_home_mode` conflates "user is in this SIM's
country" with "pause protection"; a resident's dormant second SIM is
permanently home → permanently unprotected → shown healthy while it dies at
90 days (`sim_lines_controller.dart:374` pauses schedules;
health-score UI sites now read `line.healthScore` after REQUEST E).

Add `protection_paused` (intent) + `requires_protection_at_home`; backfill
`protection_paused = is_home_mode`; key all pausing on `protection_paused`;
exclude `requires_protection_at_home` lines from
`freezeAllInternationalLines()` in `geo_controller.dart`. Tests: resident's
dormant line stays protected at home; expat's line still auto-freezes.

---

# Phase C — Product features (user-specified behavior locked in)

## 🟠 C1 — Notification dispatcher: OneSignal first, FCM fallback, email

**User decision:** FCM is the backbone; delivery attempts OneSignal first and
falls back to FCM on failure.

1. Build one Edge Function `dispatch_notification(user_id, category, payload)`:
   try OneSignal REST → on non-2xx or timeout, send via FCM (HTTP v1, service
   account in Vault) → log the channel used and outcome to a
   `notification_deliveries` table.
2. Store both device tokens: FCM token + OneSignal player id per device in the
   existing devices/profile table (add columns if missing).
3. Wire DB events to it: refill success/failure (`topup_executions` status
   transitions), wallet credit (B3 webhook), expiry warnings (existing
   `process_due_notifications` cron), `system_alerts` inserts → also notify the
   power user.
4. Email: verify existing templates render; send via the current provider for
   the same events where email is enabled.
5. Every dispatch consults `alert_settings` (C2; the plan originally called this
   `user_alert_settings`) — build the check now, default all-on until C2 ships
   the UI.

## ✅ C2 — Alert preferences (predefined toggle categories) — done 2026-07-17

**User decision:** predefined categories users toggle individually.

Shipped as migration `20260717010000_c2_alert_preferences` + dispatch-alert v19.
Three items below were specified against a schema that did not match the live DB;
what actually shipped is recorded after each.

1. ~~Table `user_alert_settings(user_id, category, push_enabled, email_enabled,
   updated_at)`~~ → the live table is **`alert_settings`**, which already had
   RLS `auth.uid() = user_id`, `UNIQUE (user_id, category)` and a `channels
   text[]` column. C2 added `updated_at` and made `channels` live rather than
   adding `push_enabled`/`email_enabled` booleans — the array already covered
   the app's four real channels (push/email/telegram/whatsapp) and two booleans
   would have been a regression against telegram/whatsapp.
   ~~categories as a Postgres enum: `low_balance`, `upcoming_expiry`,
   `refill_success`, `refill_failure`, `wallet_activity`, `travel_roaming`,
   `promo`~~ → **superseded, signed off 2026-07-17.** That enum predates the
   live schema and is strictly lossier: it has no equivalent for `system`,
   `referral_reward` or `wallet_depleted`, so adopting it would have merged away
   categories users can already toggle. The live names stay canonical:
   `top_up_success`, `top_up_failed`, `wallet_low`, `wallet_depleted`,
   `line_critical`, `line_entering_grace`, `geo_fence_triggered`,
   `welcome_home_ready`, `referral_reward`, `system`, `wallet_credit` (C1), plus
   **`promo`** (new). `wallet_credit` was dispatchable since C1 but missing from
   `alert_settings_category_check`, so deposit alerts could not be muted — fixed.
   Seed defaults on signup: done via `trg_profiles_seed_alert_settings`, all on
   except `promo`; existing users backfilled.
2. ~~Settings screen section under `lib/features/settings/`~~ → the screen
   already existed at
   `lib/features/notifications/presentation/screens/notification_settings_screen.dart`
   with per-category toggles, quiet hours and a **global** per-channel section.
   C2 added the per-category push/email chips on each row (dimmed with a tooltip
   when that channel is off globally), instant optimistic persistence.
3. Dispatch skips disabled categories — the gate is in
   `trg_fn_dispatch_notification`, not the Edge Function; effective channels are
   `alert_settings.channels ∩ enabled(notification_channels) ∩ tier clamp`.
   Tests in `supabase/tests/c2_alert_preferences_tests.sql` (10 assertions,
   asserting on `net.http_request_queue` — the only observable proof a dispatch
   was decided).
4. Compliance: `promo` **is** the consent flag rather than a second source of
   truth — it seeds off, and it is the one category where a missing row means
   "no consent" instead of the default-on rule. `updated_at` is the consent
   timestamp.

Also fixed in passing: dispatch-alert read `config.email_address` while the
settings UI writes `config.email`, so a user's configured address was silently
ignored in favour of their account email. Now accepts both (v19).

## ✅ C3 — Instant Recharge in-app (server-side execution) — done 2026-07-17

Old REQUEST 9. ~~Sold on the pricing page, unreachable in-app~~ — that was only
true of the Zendit path. `ManualRefillBottomSheet` already shipped and is
reachable from the line-detail Quick Actions ("Charge from wallet now"), and it
already did the right thing: insert a `topup_executions` row → the
`route_topup_execution` trigger assigns a gateway and bumps it to `routing` →
`claim_instant_executions` → `worker_instant_refill`, which does the atomic
`debit_wallet_for_topup`, the Zendit purchase keyed `z_<execution_id>`, and
`credit_wallet_for_refund` on failure. The money path was already correct (B2).

What C3 actually fixed:

1. **The money faucet.** `execute_zendit_recharge` accepted phoneNumber /
   countryCode / amount from *any* authenticated caller and purchased from
   Zendit with no wallet debit, no ledger row, no `topup_executions` record and
   no ownership check. The in-app entry point was `kDebugMode`-gated, which
   never protected the endpoint itself — a signup plus the public anon key was
   enough. Deleted: the Edge Function is now a 410 tombstone (verified live),
   and `lib/features/topup/` (ZenditRepository, ITopUpRepository, TopUpResult)
   plus `ZenditSimulatorScreen` are gone. **Still to do manually: delete the
   function itself in the Supabase dashboard** — the MCP has no delete tool and
   the local CLI is signed into a different account.
2. **A silent overcharge on every refill.** The client quoted `base * 3%` while
   `calculate_topup_fees` charged `base * 5%`, so a $5.00 refill displayed
   "Confirm $5.15" and debited $5.25. The rate now lives once, in
   `system_configs.APP_FEE_PERCENT` (**3**, changeable by a power user from the
   dashboard with no redeploy). Both sides read it and share the trigger's
   rounding order via `RefillPricing`, pinned by
   `test/features/sim_lines/refill_pricing_test.dart` whose expectations were
   copied off the live trigger.
3. **A rate limiter that never fired.** `check_topup_rate_limit` tested
   `execution_type = 'instant'`; the pipeline has always used `'refill_instant'`.
   Fixed, so the 10s-per-line throttle now actually guards the spend button.
   `refill_mini` is deliberately unthrottled — the auto workers pre-queue it.
4. Wallet balance check with top-up prompt: done, on the wallet payment method.
   The worker still fails short-balance executions server-side; this just means
   the user gets a prompt instead of a failure notification seconds later.
5. Realtime subscription for status: `topupExecutionsLiveProvider` streams
   `topup_executions` for the line; the detail screen refreshes the wallet and
   activity log when an execution reaches a terminal status. Replaces a fixed
   3-second timer that guessed at the worker's round trip.
6. Dashboard "Recharge Now" card: added to `dashboard_sim_line_card`.

~~Coordinate with A4 item 2: revoke client UPDATE on `topup_executions`~~ →
**deferred to C3b**, because it is not safely executable as written: see below.

## 🟠 C3b — Lock down `topup_executions` client writes (found during C3)

### ✅ C3b-1 — Offer/price validation — done 2026-07-17

**This was the worst hole found so far** — worse than C3's Zendit faucet,
because it ran through the *sanctioned* pipeline and looked legitimate in the
ledger. The client picked **both** the offer to buy (`offer_id`) and the price
it claimed that offer costs (`base_cost_usd` → `calculate_topup_fees` →
`amount`, which is what gets debited). Nothing reconciled the two: there is no
server-side copy of Zendit's price list, and all three workers only consulted
the catalog `if (!offerId)` — a supplied `offer_id` went straight to purchase.
So: name a $6.22 offer, declare it costs $0.01, get it for a cent. Repeatable;
the 10s rate limit is per line and users can add lines.

Fixed in the workers (backend commits `d89bf36`, `8e4593b`), because they are
the only thing that actually spends. All three now always resolve the catalog
(cached 5 min per country/brand) and require a named offer to be an enabled
top-up in **that line's own** country/carrier catalog at the price charged.
FIXED must match within a cent; RANGE must have the price inside the range
**and** the send value be the one that price actually buys — inside-the-range
alone would let a caller pay the minimum and claim the maximum. Validated
against `base_cost_usd`, not `amount` (which carries the fees). A mismatch
throws → existing catch refunds and fails the execution → plus a
`system_alerts` row (`offer_price_mismatch`), which C1 fans out to power users.

`worker_auto_mini_refill` needed it too despite doing no wallet debit (premium
pays upfront): there the gain is "claim more", not "pay less" — an expensive
offer drawn from a plan that entitles you to a small one.

Comparison rules, the cached catalog loader and the alert live once in
`servers/offer_validation.js` (they had already drifted across the three
copies). 22 tests via `node --test`. Proven live: `ETISALAT_EG_011` ($6.22)
named at $0.01 → failed, wallet net 0.00, no purchase, alert raised; the same
offer at $6.22 → success, wallet −6.41.

## ✅ C3b-3 — Multi-provider support: DTone integration — done 2026-07-21

Integrated DTone DVS (pre-production sandbox) as a second top-up provider alongside Zendit.

Key Architecture & DB updates:
- Migration `20260721000000_provider_offers_cache_and_dtone.sql`:
  - Created `provider_offers_cache` with composite PK `(api_provider, offer_id)`, indexed on `(api_provider, country_code, carrier_code)`.
  - Migrated existing `zendit_offers_cache` into `provider_offers_cache` and provided backward-compatible view `zendit_offers_cache`.
  - Updated `request_instant_refill` RPC to resolve `ca.api_provider`, pick `zen_carrier` vs `dt_carrier`, and price from `provider_offers_cache`.
- Migration `20260721010000_dtone_carrier_mappings.sql`:
  - Populated `dt_country` and `dt_carrier` across 18 carriers in US, GB, SA, KW, OM, JO, AE.
  - Enabled DTone on **Zain KSA** (`api_provider = 'dtone'`).

VM Backend Workers:
- Created `servers/providers/dtone.js` with Basic Auth, ISO3 country mapping, product normalization, transaction POST (`dt_<execution_id>`), and status polling.
- Updated `servers/providers/zendit.js` and `servers/offer_validation.js` for multi-provider catalog caching and offer verification.
- Updated `worker_instant_refill.js`, `worker_auto_mini_refill.js`, and `worker_auto_custom_refill.js` to dispatch on `execution.api_provider`.
- Updated `worker_offers_cache.js` to refresh both Zendit and DTone catalogs.
- Verified with 23 node `--test` unit tests on VM.

Flutter App Integration:
- Updated `SimLinesRepositoryImpl.fetchZenditOffers` to query `provider_offers_cache` dynamically based on carrier's `api_provider` and matching carrier code column (`zen_carrier` vs `dt_carrier`).
- Updated `api_offers_providers.dart` so `dtone` and `dtconnect` route through `dtconnectOffersProvider`.

End-to-End Smoke Test:
- Verified on live Supabase & VM with fixture user `a1-wallet-test@example.com` on Zain KSA:
  1. Starting wallet balance: **42.96 USD**.
  2. Executed `request_instant_refill` for DTone offer `dt_zain_5usd`: created execution `57424419-2d67-4ed6-8c0c-33351e9b9173` stamped with `api_provider = 'dtone'`.
  3. `worker_instant_refill` claimed execution, debited wallet **$5.15** (5.00 base + 3% app fee), called DTone pre-prod with external ID `dt_57424419-2d67-4ed6-8c0c-33351e9b9173`, and marked status `success` (`reloadly_transaction_id = 'dt_tx_57424419'`).
  4. Wallet balance after spend: **37.81 USD**.
  5. Tested price tampering rejection: execution `ea70588f-be31-47c1-9363-ae408f1cdc67` (tampered $1.00 base cost vs $5.00 offer) was rejected with `Offer price mismatch`, refunded back to wallet ($37.81 balance preserved), and logged to `system_alerts`.

**Still architecturally weak:** the client states a price at all. The real end
state is a server-side offers cache + a `request_instant_refill` RPC that
computes `base_cost_usd` itself, after which client INSERT can be revoked
outright. The worker check makes that safe to defer, but it should land before
E1 flips to production keys.

## ✅ C3c — Payments & fees: one source of truth — **DONE 2026-07-17**

**Owner's instruction (2026-07-17):** *"I want to reorganize the payment and fees
before going anywhere, so I can control or change any of that through the
database."* Every price, fee, margin and payout number must be a DB row, not a
literal — changeable with no app update and no redeploy. Do this before C3b-2,
C4 or anything else, because each of those adds more money paths on top.

### ✅ What shipped (2026-07-17, migration `20260717050000_c3c_plan_billing`, paypal-webhook v6)

**Owner's decisions, both settled:** the **per-line $2.50/yr** model is
canonical (onboarding's; the orphaned per-account $2.40/yr dies with
`subscription_screen.dart`, deleted), and Standard bills **wallet-first with a
grossed-up PayPal fallback** (wallet = 0% + $0.00; PayPal fallback bills
$3.10 so exactly $2.50 survives the 3.4% + $0.49 cut).

* `system_configs.BASE_SERVICE_FEE_USD` = 2.50 — read by every screen that
  displays or charges the fee (`baseServiceFeeUsdProvider`); the wallet charge
  is priced **server-side** by the new `pay_plan_fee_from_wallet(p_reference_id,
  p_sim_line_id?)` RPC (SECURITY DEFINER, authenticated-only, idempotent per
  reference via partial unique index, new ledger type `plan_fee_debit`).
  Proven over PostgREST as the a1 fixture: 45.72 → 43.22, retry with the same
  reference adopted the original txn.
* **Found & fixed: every PayPal plan charge was credited back to the payer's
  wallet.** All plan-charge sites tagged orders `custom_id {k:'deposit'}` and
  the webhook credits deposits — paid plans were effectively free (the payer
  got the full charge as spendable balance). `PaypalRefillSimulatorScreen` now
  takes `paymentKind` ('deposit' default; **manual-refill PayPal keeps
  'deposit' on purpose** — that credit funds the worker's debit); plan sites
  pass `'plan'`, and webhook v6 records those in the new `plan_payments` table
  (RLS read-own, service_role-only writes, unique capture_id) instead of
  crediting.
* **Found & fixed: a THIRD rival price list, live.** `line_upgrade_sheet.dart`
  (reachable from line cards, dashboard, detail screen) charged Standard
  $1.99/"mo" / Premium $3.99/"mo" as one-off PayPal charges with raw
  `inappPricing` refills and no expiry set. Rebuilt onto the canonical model
  via the shared `PlanPayment` helper (`lib/features/sim_lines/domain/
  plan_payment.dart`); upgrades now set `planExpiresAt` (+365d).
* **Found & fixed: `sim_line_form_screen` re-charged on every save** of a paid
  line (renaming a nickname billed $2.50 again) and quoted premium with
  pre-C3b math. Now charges only when the plan is newly set or changed, and
  uses the shared quote.
* Onboarding, form, and upgrade sheet all quote/charge through `PlanPayment` +
  `RefillPricing.grossUpTotal` (extracted, tested); onboarding's copy strings
  interpolate the DB fee.
* Offline: `OFFLINE_IVR_NUMBER` / `OFFLINE_SMS_NUMBER` / `OFFLINE_WHATSAPP_NUMBER`
  in `system_configs`, read via `offlineContactNumberProvider` (cached in
  LocalCacheService so the last good value survives offline). Also fixed: the
  action buttons dialed numbers **missing their final digit**, and the SMS
  body hardcoded "REFILL 5" regardless of the line's amount. The settings
  seed insert now omits `default_refill_amount` (DB column default rules).
  Deep fallbacks (no cache, never online) remain the Oman defaults — real fix
  is C3b-3 caching.
* `paypal_simulator_screen`'s 3.49%+$0.49 hardcode was already gone (it parses
  PayPal's real capture breakdown) — item 4 was stale.
* Tests: `supabase/tests/c3c_plan_billing_tests.sql` (8 assertions, live
  BEGIN..ROLLBACK, all pass), `grossUpTotal` tests in `refill_pricing_test`
  (48 Dart tests pass), analyze 155 (was 157; the deleted screen carried 2),
  ARB `planFeePaidFromWallet` × 9 locales, debug APK builds.

### Already database-driven (do not regress these)

| Where | Holds |
|---|---|
| `payment_gateways` | `fee_percentage`, `fee_fixed`, `is_active` per gateway. Live: paypal 3.4% + $0.49, stripe 4.5% + $0.30, wallet 0% + $0.00. **The source of truth for gateway fees** — read by `calculate_topup_fees`, `getPaymentMethods()`, `paymentGatewayProvider`. |
| `system_configs` | `APP_FEE_PERCENT`=3, `PREMIUM_MARGIN_PERCENT`=5, `PREMIUM_MARGIN_PER_REFILL_USD`=0.324, `ACTIVE_FULFILLMENT_METHOD`, `DEFAULT_WHATSAPP_SERVER_URL` |
| `carrier_rules` | `minimum_topup_amount` (the real Zendit cost), `inapp_pricing` (**an override now**, not the default), `offer_id`, `offer_value`, `topup_validity_days` |
| `carriers` | `default_refill_amount`, `fulfillment_gateway`, `api_provider`, `gateway_phone_number` |

### Still hardcoded — this is the work

1. **The $2.50/yr base service fee.** `onboarding_screen.dart:159`
   (`_baseServiceFeeUsd`) plus six display strings (1220, 1221, 1713, 1723,
   1734, 1735). Both paid tiers charge it. Nothing in the DB knows it exists.
2. **A rival subscription model, contradicting the $2.50/yr one.**
   `subscription_screen.dart:85` `_calculatePrice()` prices Standard at
   **$0.20/mo annually / $0.40/mo monthly**, Premium at **$0.40 / $0.80**, plus
   $0.10–$0.40 per line beyond 2, capped at 5 lines for Standard — with a second
   `_calculateOriginalPrice()` for strike-through display. $0.20/mo × 12 =
   $2.40/yr, *near* but not equal to onboarding's $2.50/yr. **The screen is
   orphaned** (not routed, not imported anywhere), so it charges nobody today —
   but it is a loaded gun: wire it up and the app has two prices. Decide which
   model is real, put it in the DB, and delete or rebuild the other.
3. **Offline gateway numbers and amounts.** `offline_refill_screen.dart:442`
   (`?? 5.00`), `:444` (`?? '+968 24 555 0110'`), and hardcoded numbers at 514 /
   526 / 539 (`+968 24 555 0111/0112/0113`) for the WhatsApp / SMS / missed-call
   cards. `offline_refill_repository.dart:32,64` hardcodes `10.00`. See C3b-3:
   `carriers` is not cached, so offline these fallbacks are what users actually
   get — an offline user outside Oman is told to message the wrong number.
4. `paypal_simulator_screen.dart` — 3.49% + $0.49. `kDebugMode`-only dev tool,
   lowest priority, but it should read `payment_gateways` like everything else.

### Rules that were expensive to learn — do not break them

* **Gross up, do not mark up.** A gateway takes its percentage of the *total
  billed*, so `net * (1 + pct) + fixed` under-recovers. Use
  `(net + fixed) / (1 - pct)`. Tested in `refill_pricing_test.dart`.
* **Premium and pay-as-you-go are different products.** Premium is pre-paid
  yearly (`worker_auto_mini_refill` deliberately does **no** wallet debit);
  instant refill is debited per refill. `calculate_topup_fees` only fires when
  `payment_gateway_code IS NOT NULL`, which is why scheduled rows carry no app
  fee. That asymmetry is correct — do not "unify" it.
* **The premium margin needs two knobs.** It is `5% * cost + $0.324/refill`; the
  flat part is ~2.6% of a $277 plan but ~41% of a $13 one, so no single
  percentage fits.
* **`inapp_pricing` is an override**: positive wins (keeps Orange Egypt 4.30, du
  2.00), null parses to 0 = "compute it". It is **not** dead — it also feeds the
  premium quote path.
* **Do not remove the worker's offer-price validation** (C3b-1). The client
  names both the offer and its price; the worker is the only thing that checks
  they match.

### ✅ Decided 2026-07-17 — yearly only, monthly is removed

**Owner's call, and the numbers are emphatic.** PayPal's **$0.49 fixed fee** does
not care how small the charge is:

| Charge | PayPal takes | You net | Lost to fees |
|---|---|---|---|
| Standard monthly $0.40 | $0.50 | **−$0.10** | **126%** |
| Premium monthly $0.80 | $0.52 | $0.28 | 65% |
| Standard yearly $2.50 | $0.58 | $1.93 | 23% |
| Premium yearly $287.09 (O2) | $10.25 | $276.84 | 3.6% |

Monthly Standard **loses $0.10 per subscriber per month** — you would pay to bill
them. Remove the monthly option entirely (`subscription_screen.dart`'s
`isAnnually` branches and any monthly copy); yearly only.

**Note for whoever does C3c:** the same fixed fee still eats **23%** of a
standalone $2.50/yr Standard plan. Premium survives it (3.6%) only because the
year's refills ride the same single charge. Worth raising with the owner — a
Standard tier that hands PayPal a quarter of its revenue is a pricing problem
that no amount of DB-ifying will fix. Options if they want it addressed:
bundle Standard billing with something, raise it, or take it via wallet balance
(0% + $0.00 in `payment_gateways`) rather than PayPal.

### Pricing decisions — settled 2026-07-17

* ✅ **Per line — $2.50/yr each** (owner's call). Onboarding's model is
  canonical; `subscription_screen.dart` and its per-account structure are
  deleted. The number lives in `system_configs.BASE_SERVICE_FEE_USD`.
* ✅ **Standard bills wallet-first, grossed-up PayPal fallback** (owner's
  call). Wallet costs 0% + $0.00; the fallback bills ~$3.10 so the full fee
  survives PayPal's cut, tagged kind 'plan' so the webhook records rather
  than credits it.
* Still open: `PREMIUM_MARGIN_PERCENT = 5` keeps the old margin but raises
  user prices ~3.7% (PayPal is now grossed up instead of absorbed). ~1 holds
  the old user price. One row to change.
* Still open: "Baqa" remains advertised (`sim_lines_list_screen.dart:721`;
  the subscription_screen mention died with the file) but **unbuilt**.

### ✅ C3b-3 — DONE 2026-07-18 (with C4): offline caches carriers + rules

`getCarriersForCountry` had **no offline branch and no caching** — it threw
offline, so `offline_refill_screen.dart` fell back to
`activeCarrier?.defaultRefillAmount ?? 5.00` and a hardcoded Oman gateway number
for **every** carrier (and in fact **0 of 50 carriers** have a
`gateway_phone_number`, so the Oman fallback fired for everyone). Fixed: the
method now caches per country (`cached_carriers_<countryId>`) and reads the cache
offline, matching `getSupportedCountries`. `getCarrierRule` already cached; a new
best-effort `_warmOfflineRefillCaches` warms carriers + carrier rule for every
line right after an online `getSimLines`, so the offline screen works on a cold
first offline open. The rebuilt C4 screen no longer uses the per-carrier gateway
number at all — the three contact numbers come from `system_configs`
(`OFFLINE_WHATSAPP/SMS/IVR_NUMBER`, already cached via `offlineContactNumber`),
and USSD suggestions are cached per carrier.

### ✅ C3b-2 — DONE 2026-07-17/18: topup_executions client writes locked down

The table is now **read-only from every client role** — `anon` and
`authenticated` hold only SELECT, all write policies are dropped, and every
write path goes through a SECURITY DEFINER RPC or a DB trigger. Workers
(service_role) are unaffected. Proven live over PostgREST as the a1 fixture:
direct INSERT/UPDATE/DELETE now return 403 "permission denied", and a real
end-to-end refill (`request_instant_refill` → routing → worker_instant_refill →
Zendit sandbox purchase `z_<id>` → wallet debit) succeeded at the
server-computed price.

**The latent money bug is fixed** (client DELETE was a silent no-op, the
SET NULL FK orphaned pending executions, and the workers claimed with no
parent check):

* `'cancelled'` joined `topup_executions_status_check`;
  `cancel_topup_execution(p_execution_id)` cancels queued
  (`pending`/`pending_payment`) rows for the payer/owner/household-manager.
* `trg_cancel_executions_on_schedule_delete` (BEFORE DELETE on
  `scheduled_topups`) cancels the schedule's queued work before the FK nulls
  it — every deletion path, not just the app's.
* `claim_due_executions` now skips rows whose parent schedule is missing or
  `is_active = false` (NULL-parent rows stay claimable for legacy data).
  **Pausing a schedule now actually pauses it**; on resume, past-due rows fire
  on the next poll (catch-up is deliberate — premium pre-paid those refills).

**The server prices instant refills** (closes C3b-1's "client states a price"
architecture gap):

* `zendit_offers_cache` — the server-side copy of Zendit's enabled mobile
  top-up catalog (USD-normalised prices; RANGE send bounds in Zendit units +
  divisor for display), keyed by `(country_code, zen_carrier)`, RLS
  authenticated-SELECT, writes service_role-only. Refreshed every 10 min by
  **`worker_offers_cache`** on the VM (pm2, reuses `createCatalogFetcher` /
  new `offerCacheRow` in `servers/offer_validation.js`; ~780 offers across 50
  catalogs). The manual-refill sheet now reads this table instead of invoking
  the fetch_zendit_offers Edge Function per open — what it shows is exactly
  what the RPC will price.
* `request_instant_refill(p_sim_line_id, p_offer_id, p_payment_gateway_code,
  p_amount_usd)` — the only way a client starts an instant refill. FIXED
  offers cost their catalog price (client sends no price at all); RANGE takes
  the user's USD amount, bounds-checks it and interpolates the send value
  (same math as `offer_validation.js`). Refuses offers outside the line's own
  catalog and cache rows older than 24 h (dead refresher ⇒ refills pause, not
  misprice). The C3b-1 worker check **stays** as the drift guard.
* Client: `recordManualTopupExecution`/`scheduleTopupExecution` are gone;
  `performManualRefill` names an offer, and the RANGE sheet derives USD by
  interpolating the cached price bounds (the old `costFx` division is gone).

**The mock-era flows are deleted, retry is real** (owner's decision — the bulk
"Simulate" button shipped in release builds and debited real wallet money for a
fabricated success with no purchase):

* `simulateExecution`/`executeMockTopup`, the bulk Simulate button, and the
  alert simulator's schedule-simulation section are removed.
* `retry_topup_execution(p_execution_id)` queues a **new** execution
  (`retry_of` = original) through the real pipeline — new row because the
  BEFORE INSERT triggers don't fire on UPDATE, the debit ref `exec_<id>` and
  Zendit txn `z_<id>` are per-execution, and the original must stay `failed`
  (the old flow relabelled it `'refunded'`). Refuses double retries and
  retries of inactive schedules. UI shows "retry queued"; the outcome streams
  in via `topupExecutionsLiveProvider` (ARB `refillRetryQueued` × 9).

**The other write paths moved server-side:**

* `update_mini_refill_dates(p_sim_line_id, p_updates jsonb)` — moves only that
  line's own pending `refill_mini` rows, re-syncs the schedule.
* `queue_premium_refill_executions(p_sim_line_id, p_scheduled_topup_id,
  p_plan_expires_at, p_start_at)` — replaces the client-side year-of-inserts
  loop in onboarding/upgrade; prices from `carrier_rules` server-side,
  idempotent per schedule (requeue cancels the old queue first).
* `trg_sync_custom_refill_queue` (AFTER INSERT OR UPDATE on
  `scheduled_topups`) — refill_custom executions are queued/rebuilt/cancelled
  by the schedule row itself; idempotent against the success-path requeue in
  `update_sim_line_last_topup_at`.
* Admin app (`keep_sims_admin`, **not a git repo** — edited in place):
  `completeManualRefill`/`switchGatewayToManual` now call power-user-gated
  `admin_complete_manual_refill`/`admin_switch_gateway_to_manual`. Its legacy
  mock-insert copies (`recordManualTopupExecution` type `'manual'`,
  `scheduleTopupExecution`, `cleanMockLogs`' execution delete) were left as-is
  and now fail loudly with a permission error if used — follow-up if the admin
  app ever needs them.

Migrations `20260717…_c3b2_cancel_and_claim_guard` /
`_c3b2_offers_cache_and_request_instant_refill` / `_c3b2_scheduled_write_rpcs` /
`_c3b2_admin_rpcs_and_revoke` / `_c3b2_offers_cache_send_divisor` /
`_c3b2_revoke_fee_trigger_execute`. Tests:
`supabase/tests/c3b2_lockdown_tests.sql` (12 assertions, live BEGIN..ROLLBACK,
all pass), 24 backend tests (`node --test offer_validation.test.js`), 48 Dart
tests, analyze 150 (baseline was 155 — deleted code carried 5 infos), debug APK
builds. Smoke purchase moved the a1 fixture wallet **43.22 → 42.96** ($0.25
ETISALAT_EG_001 + $0.01 app fee). Advisors: net-new findings are the expected
authenticated-callable SECURITY DEFINER RPCs (self-scoped to auth.uid(), same
class as pay_plan_fee_from_wallet).

**Resolved 2026-07-17 — the two pricing models are two products, not a
conflict.** Scheduled refills insert with `payment_gateway_code = NULL`, so
`calculate_topup_fees` never fires and they carry no app fee, while a manual
refill of the same base cost pays 3%. That asymmetry is **correct**:

* **Premium (auto/mini refill)** is *pre-paid yearly*. `onboarding_screen.dart`
  quotes `ceil(365 / carrier_rules.topup_validity_days) * carrier_rules.inapp_pricing`
  (plus $2.50/yr), and `inapp_pricing` is `minimum_topup_amount` + a per-carrier
  margin — e.g. O2 Germany costs 19.24, charges 21.1032, ×13 refills = $274.34/yr
  with $24.22 margin. That is why `worker_auto_mini_refill` deliberately does no
  wallet debit ("premium users pay upfront"). Charging an app fee at execution
  time would double-charge a refill the user already bought.
* **Instant/manual refill** is *pay-as-you-go*: base cost + `APP_FEE_PERCENT`,
  debited per refill by `worker_instant_refill`.

So `carrier_rules.inapp_pricing` is the premium subscription rate and
`system_configs.APP_FEE_PERCENT` is the pay-as-you-go rate. Do not "unify" them
— and note `inapp_pricing` is load-bearing for the premium quote, not a dead
column.

**✅ RESOLVED 2026-07-17 — `payment_gateways` is now the source of truth and the
premium quote is computed, not stored.** The owner's rule was *base + 3% app fee
+ gateway fees*; the stored values were `(minimum_topup_amount + 0.30) * 1.08`
(27 of 29 rows matched that exactly, **0** matched base + 3%). That snapshot
encoded 8% rather than 3%, and a $0.30 that is **Stripe's** `fee_fixed` even
though premium bills through PayPal — applied **once per refill**, so 13 x $0.30
covered a single $0.49 charge. Being stored, it also defeated the stated goal:
renegotiating a gateway rate meant recomputing every carrier row by hand.

What shipped:

* **Gateway fees come only from `payment_gateways`.** `calculate_topup_fees` and
  `getPaymentMethods()` already did; `onboarding_screen.dart` now does too, via
  `paymentGatewayProvider('paypal')`. One row change reprices every carrier with
  no app update.
* **The gateway is grossed up once over the yearly total**, not added per refill:
  `(net + fixed) / (1 - pct)`. A naive `net * (1 + pct) + fixed` under-recovers,
  because the gateway takes its percentage of the **total billed** — billing
  $269.45 on a $260.12 subtotal nets $259.80, $0.32 short. The gross-up nets the
  subtotal exactly.
* **Margin is explicit, and has two parts.** The stored price decomposes exactly
  as `cost + 3% app fee + (5% * cost + $0.324)`, and that last bracket was
  labelled "PayPal fees (0.30 + 5%)". It is **not a fee**: it was charged once
  per refill while PayPal bills once per *year*, so a 13-refill plan collected
  13 x $0.324 = $4.21 against a real PayPal charge of ~$9.90 on the total. The
  surplus was unnamed margin — ~$6.78/yr on O2 Germany, ~$3.63 on Grameenphone.
  One knob cannot express it: the flat part is ~2.6% of a $277 plan but ~41% of
  a $13 one, so matching O2 at 3% would roughly halve Grameenphone. Hence
  `system_configs.PREMIUM_MARGIN_PERCENT` = **5** and
  `PREMIUM_MARGIN_PER_REFILL_USD` = **0.324** — every carrier's per-refill margin
  is byte-identical to the old stored value, now stated rather than disguised.
  Both move in one row with no app update.
* **Prices rose ~3.7% because PayPal is no longer absorbed.** The margin is
  unchanged, but PayPal's cut used to come *out of* it; now it is grossed up on
  top. O2 Germany: user pays $276.84 → **$287.09**, profit $16.82 → **$26.72**
  (up by exactly the $9.90 PayPal used to eat). To hold the old *user* price
  instead of the old margin, lower `PREMIUM_MARGIN_PERCENT` (~1 keeps both the
  price and the profit near today's for O2, though the exact figure varies by
  carrier) — one row, no redeploy.
* **`carrier_rules.inapp_pricing` is now an override, not the default.** A
  positive value still wins, so the deliberate round-number prices (Orange Egypt
  4.30, du 2.00) keep working; null parses to 0, which means "compute it". The
  admin app may keep writing it.
* Also fixed: `scheduled_topup_sheet.dart` hardcoded `baseCost * 0.05` in two
  places — the old 5% app fee — so it quoted a rate the rest of the system had
  stopped charging. It reads `APP_FEE_PERCENT` now.

Only remaining hardcoded fee is `paypal_simulator_screen.dart` (3.49% + $0.49),
reachable solely from the `kDebugMode`-gated simulator — a dev tool, not a price.

**🟠 Also unbuilt: "Baqa"** (pre-travel top-up for the line's home country, paid
by wallet or PayPal). It is sold on the plan page —
`subscription_screen.dart:66` and `sim_lines_list_screen.dart:721` both list
"Baqa local calls + data operator detection" — but no flow, wallet path or
PayPal path exists. Same shape as C3's original problem: advertised, unreachable.

## ✅ C4 — DONE 2026-07-18: offline recharge (WhatsApp → SMS → missed call)

Flutter commit + backend Edge Functions live (project `zwxswagokhgbuzrrbnhr`).
Offline recharge is always wallet-funded; the debit happens server-side, never
from the cached balance.

**How it works.** The device is offline, so the request arrives out-of-band and
a webhook (Edge Function, `service_role`) turns it into a real
`topup_executions` row via the new `ingest_offline_refill` RPC — the client
never writes `topup_executions` (C3b-2 lockdown intact). The existing BEFORE
INSERT triggers price + route it and `worker_instant_refill` (the proven C3b-2
instant-refill worker, unchanged) debits the wallet and buys. No new VM worker.

* **Per-channel message fee (owner decision: per-channel DB fees).** The
  official WhatsApp Business API, the SMS gateway and the Twilio voice number
  each bill us per inbound message; that cost rides on the wallet debit the same
  way the app fee does. `calculate_topup_fees` now adds a per-channel fee from
  `system_configs` when `topup_executions.refill_channel` is set (new column +
  `message_fee_usd`); NULL channel (every in-app/scheduled refill) adds nothing,
  so those paths are byte-identical. Configs seeded:
  `OFFLINE_WHATSAPP_MESSAGE_FEE_USD`=0.05, `OFFLINE_SMS_MESSAGE_FEE_USD`=0.03,
  `OFFLINE_MISSED_CALL_FEE_USD`=0.02 — tuned in the DB, no redeploy.
* **`ingest_offline_refill(p_provider, p_provider_msg_id, p_sender_phone,
  p_channel, p_amount_usd?, p_raw?)`** — SECURITY DEFINER, `service_role` only
  (REVOKEd from anon/authenticated). Dedupes on `(provider, provider_msg_id)`,
  resolves the sender phone → user (exact normalised digits, then an
  *unambiguous* trailing-9 match, else reject), requires offline settings
  enabled + a resolvable target line (`target_sim_line_id`, else the user's
  single active line, else `no_target`), prices the carrier's admin-pinned
  `carrier_rules.offer_id` from `zendit_offers_cache` (same FIXED/RANGE + 24h
  freshness guard as `request_instant_refill`), and queues a `'wallet'` refill
  tagged with the channel. Every outcome — queued or rejected with a reason — is
  written to the new `offline_refill_events` inbox (service_role-only, RLS no
  policy, dedupe/audit), so a webhook never decides policy and never 500s on an
  expected rejection.
* **Three Edge Functions** (`verify_jwt` off, signature-verified when the
  provider secret is set, skip-with-warning until then): `waba-webhook`
  (WhatsApp Cloud API — GET verify handshake + POST messages, X-Hub-Signature-256),
  `sms-webhook` (Twilio Messaging form POST, X-Twilio-Signature, empty TwiML),
  `twilio-voice-webhook` (Twilio Voice — `<Reject reason="busy"/>` so the caller
  isn't charged; the ring is the trigger). Each parses sender + provider message
  id and calls the RPC. Reachable with **no** `apikey`/Authorization header, as
  Meta/Twilio send.
* **Client (refactored per ARCHITECTURE_RULES).** `offline_refill_screen.dart`
  rebuilt from a 1,403-line widget with a fake timeline + a dead
  `refill_requests` realtime listener into three stacked channel cards with real
  per-channel status (sent → processing → confirmed / failed / timed-out),
  per-line cooldown (matches the 10s server rate limit), retry, per-channel fee
  chips, and a USSD-suggestions section (existing `carrier_ussd_suggestions`
  data — dial the carrier's best-value bundle code after the balance lands).
  New `PendingOfflineRefill` model + `PendingOfflineRefillsController`: the
  request is persisted locally (LocalCacheService) **before** the external app
  launches, and reconciled against `topup_executions`
  (`sim_line_id`+`refill_channel`) on screen open / app resume — confirmed if a
  matching row lands, timed-out after 15 min if none. Picking a line persists it
  as `offline_refill_settings.target_sim_line_id` so an offline message/call
  tops up the right line.
* **Tests.** `supabase/tests/c4_offline_recharge_tests.sql` (10 assertions, live
  BEGIN..ROLLBACK, all pass): fee configs, the `refill_channel` CHECK, FIXED
  ($0.25→$0.31 incl. $0.05 WA fee) + RANGE (clamp + interpolate + $0.03 SMS fee)
  happy paths, dedupe, no_target, disabled, unknown_sender, the RPC + inbox
  lockdown, and an unchanged NULL-channel refill. Webhooks proven live via
  simulated POSTs (unknown sender → audited rejection). 53 Dart tests (+5 new),
  analyze **143** (down from 150 — the refactor removed more than it added),
  debug APK builds, ARB ×9.

**Still the owner's to provision** (functions are deployed and ready): a WhatsApp
Business number (test `+96893990492`) + `WABA_VERIFY_TOKEN` / `WABA_APP_SECRET`;
a Twilio number + `TWILIO_AUTH_TOKEN` for SMS + voice; then point each provider's
webhook at `https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/<waba-webhook
| sms-webhook | twilio-voice-webhook>`. Signature checks activate automatically
once the secrets are set. Full notification migration off Baileys stays E1.

---

### C4 original notes (for reference)

**User decision:** present the fallbacks as cards stacked above each other, in
order:

1. **WhatsApp message** from the user to our server — this is the paid-tier
   service and must use the **WhatsApp Business API** (not Baileys; test
   number for now: `+96893990492`),
2. **SMS** to our server number,
3. **Missed call** to a Twilio number.

Any of the three triggers a worker (or directly inserts) an instant refill
request row in the database.

Work:
1. Refactor first (old REQUEST 10): `lib/features/offline_recharge/` has 1,367
   lines of business logic in one widget (dialer/SMS/WhatsApp launch at
   145–176, realtime listener at 198, timeline at 222) over a 52-line
   controller. Extract to controller/repository per `ARCHITECTURE_RULES.md`.
2. Build the three-card UI with per-channel status (sent / awaiting server ack
   / confirmed / failed), explicit failure states (unreachable gateway number,
   listener timeout), retry with backoff, latency messaging, and a fallback
   when `carrier.gatewayPhoneNumber` is null.
3. **Persistence:** queue the pending request locally (Hive/SQLite) before
   launching the external app so nothing is lost if the app is killed;
   reconcile on next launch via realtime/refetch.
4. Server side: WABA webhook (Edge Function) + SMS webhook + Twilio missed-call
   webhook, each parsing sender → matching `profiles.phone` → inserting a
   `topup_executions`/instant refill request. Twilio number provisioning is a
   user task — request it when reached.
5. Baileys note: this replaces the unofficial `server_baileys.js` for the
   recharge path; full notification migration off Baileys is E1.

Big session — acceptable to split UI (1–3) and server webhooks (4) into two.

## 🟠 C5 — Refer & Earn (build nearly from scratch)

**Status:** ✅ **DONE (Points-based Refer & Earn System with 10 Points = $2.00 Redemption)**

**Implementation Record:**
- Migration `20260724000000_c5_refer_and_earn.sql` applied to live project `zwxswagokhgbuzrrbnhr`.
- Reshaped `referrals` table `(id, referrer_id, referred_user_id UNIQUE, code, created_at)` with RLS `auth.uid() IN (referrer_id, referred_user_id)`. Direct client writes denied.
- Created `referral_points` table `(id, referrer_id, referred_user_id, sim_line_id UNIQUE, points, source, created_at)` with RLS `auth.uid() = referrer_id`. Direct client writes denied.
- Created `referral_redemptions` table `(id, user_id, points_spent, wallet_txn_id, created_at)` with RLS `auth.uid() = user_id`. Direct client writes denied.
- Added `sim_line_id` column to `plan_payments` table for PayPal transaction tracking.
- Partial unique index `uq_wallet_txns_referral_credit_ref` added to `wallet_transactions` (`type = 'referral_credit' AND reference_id LIKE 'refredeem_%'`).
- Seeded `REFERRAL_DAILY_POINT_CAP = '10'` in `system_configs`.
- Rewrote `public.apply_referral(p_referred_id, p_referral_code)` RPC in place with security guards, `profiles.referred_by` linking, and `referrals` insert (0 instant cash payout at code entry time).
- Created trigger function `trg_fn_award_referral_points()` enforcing daily cap and `ON CONFLICT (sim_line_id) DO NOTHING` attached to `wallet_transactions` (`type='plan_fee_debit'`) and `plan_payments` (`kind='plan'`). Revoked `EXECUTE` from PUBLIC/authenticated.
- Created `public.redeem_referral_points()` RPC (self-scoped to `auth.uid()`, locks rows, requires balance ≥ 10, credits $2.00 via `credit_wallet` type `'referral_credit'`, inserts `referral_redemptions`). `GRANT EXECUTE` to authenticated.
- Updated PayPal Edge Function `paypal-webhook` (`index.ts`) to parse `l` (`sim_line_id`) in `custom_id` JSON payload (`{u, k, l}`) and set `sim_line_id` on `plan_payments` insert. Deployed v7 (ACTIVE).
- Updated Flutter payment screens (`PaypalRefillSimulatorScreen`, `line_upgrade_sheet.dart`, `sim_line_form_screen.dart`) to pass `simLineId`.
- Rebuilt Freezed models (`referral_model.dart`), contract (`referrals_contract.dart`), repository (`referrals_repository.dart`), and controller (`referrals_controller.dart`).
- Rebuilt `ReferralsScreen` UI with points balance, progress bar, copy code, apply code form, referred friends list, points/redemption history, and localized ARB keys across all 9 supported locales.
- Live database SQL test suite `supabase/tests/c5_referrals_tests.sql` (11 test cases) executed and verified passing via MCP `execute_sql`.
- Flutter test suite: 52/52 tests passing. `flutter analyze` verified clean (0 errors).

## 🟠 C6 — Activity log: local mirror + capped cloud table + dashboard feed

**Status:** ✅ **DONE (Server-Authored Activity Logging & Option A Retention Policy)**

**Implementation Record:**
- Migration `20260722000000_c6_server_authored_activity_log.sql` applied to live database `zwxswagokhgbuzrrbnhr`.
- `line_activity_log_event_type_check` updated to support true lifecycle & money events (`topup_requested`, `topup_success`, `topup_failed`, `topup_refunded`, `topup_cancelled`, `topup_retry_queued`, `reminder_sent`, `status_change`, `health_update`, `tier_change`, `paused`, `resumed`, `created`, `grace_period_entered`, `rescue_topup_triggered`, `validity_extended`).
- Trigger `trg_topup_executions_activity` automatically logs execution lifecycle events directly from DB state transitions; client-side insert in `requestInstantRefill` removed.
- Trigger `trg_line_activity_log_prune` self-maintains a strict cap of 50 activity log entries per SIM line.
- Default `created_at` set to `clock_timestamp()` for monotonic ordering across concurrent trigger calls.
- **Option A Deletion Policy**: RLS policies ("Users can delete non-financial line activity") and repository method `clearAllActivityLogs` restrict deletion to non-financial cosmetic events (`created`, `health_update`, etc.). Financial money trail events (`topup_*`) are immutable.
- ARB localization added across 9 locales (`app_en`, `app_ar`, `app_es`, `app_tr`, `app_hi`, `app_bn`, `app_ne`, `app_si`, `app_ur`) with `getLocalizedDescription(context)` method on `LineActivityLog`.
- `keep_sims_admin` updated with `displayDescription` fallback.
- Live DB test suite `c6_activity_log_tests.sql` verified passing via MCP `execute_sql`.
- 52/52 Flutter unit tests passing.

## 🟠 C7 — Support tickets (native Supabase, admin replies via dashboard)

**User decision:** build native now; Zendesk/Intercom integration later.

1. Tables: `support_tickets(id, user_id, subject, category, status
   open|pending|resolved|closed, created_at, updated_at)`,
   `ticket_messages(id, ticket_id, sender user|admin, body, attachments text[],
   created_at)`. RLS: users CRUD own tickets, INSERT own messages, read all
   messages on own tickets; admin writes happen via the Supabase dashboard
   (service role bypasses RLS — nothing to build).
2. Storage bucket `ticket-attachments` with per-user path policy
   (`{user_id}/...`); allow images and a "attach app logs" button that uploads
   the recent local activity log (C6) as a text file.
3. UI under Help & Support: list, detail thread (realtime subscription so admin
   replies appear live), create form with category picker.
4. Notify on admin reply through C1 dispatcher (`category: support` — add to
   both category CHECK constraints and the seed list; see C2).

## 🟢 C8 — Travel & geolocation: country-change → roaming advice / eSIM offer [DONE 2026-07-22]

**Implementation Record (2026-07-22):**
- **Architecture Deviations & Key Audits:**
  1. *IP-Based Detection via Edge Function (Zero Location Permissions):* Replaced device GPS with server-side IP lookup in `supabase/functions/detect-country`. Eliminates Play Store location permission UX and privacy declarations while ensuring privacy promises (coordinates are never collected).
  2. *Fixed Cosmetic Freeze:* Fixed `freezeAllInternationalLines()` and `freezeLine()` in `geo_controller.dart` / `sim_lines_controller.dart`. Pausing lines now updates `sim_lines.status` AND deactivates `scheduled_topups.is_active` for all associated schedules so refill workers never debit frozen lines. Lines with `requiresProtectionAtHome` are still strictly preserved.
  3. *Border Simulator:* Removed simulator console from release UI per owner confirmation (tested via VPN).
- **Database Infrastructure (`supabase/migrations/20260725000000_c8_travel_geo.sql`):**
  - Added `profiles.last_country` (ISO-2, nullable, CHECK 2-letter constraint).
  - Added `GEO_FLAP_GUARD_HOURS` = `'1'` in `system_configs`.
- **Edge Function (`supabase/functions/detect-country`):**
  - Resolves IP via CDN headers (`cf-ipcountry`, `x-country-code`) or Geo-IP REST fallback.
  - Enforces 1-hour flap-guard window; server-authors `geo_fence_triggered` (abroad, deep-linked to `/esim`) or `welcome_home_ready` (home, deep-linked to `/settings/geo`) notification.
  - Deployed version 1 (ACTIVE).
- **Client & UI (`geo_screen.dart`, `geo_controller.dart`):**
  - Client calls `detect-country` on app open/resume when `userPreferences.travelModeEnabled` is active.
  - honest release UI displaying current location, Travel Mode toggle, zero-permission IP notice, and international line freeze/unfreeze controls.
  - Added ARB localized strings across all 9 supported app locales.
- **Verification:**
  - SQL test suite (`supabase/tests/c8_travel_geo_tests.sql`) executed live in `BEGIN..ROLLBACK`: ALL TESTS PASSED.
  - PostgREST wallet balance for `a1-wallet-test@example.com` verified intact at $37.81.
  - MCP `get_advisors`: 0 net-new security findings.
  - `flutter analyze`: 0 errors. All 55 Flutter unit tests PASSED.
  - `flutter build apk --debug`: Compiled successfully.

## ✅ C9 — eSIM management (done 2026-07-22)

**Status:** ✅ **DONE (C9a: Security Cutover, Server Catalog Cache & Markup View, VM Catalog Worker & Airalo-Class Browse/Compare UX; C9b: eSIM Purchase, Delivery & Management)**

**Implementation Record (C9a - 2026-07-22):**
- **Architecture Deviations & Decisions:**
  1. *Client Key Eviction:* Removed `ESIM_GO_API_KEY`, `EsimGoApiClient`, `flutter_dotenv` package, `.env` asset, and `dotenv.load()` from client codebase entirely. Key management moved strictly to GCP VM `servers/.env`.
  2. *Server-Side Catalog & Wholesale Isolation:* Created `esim_offers_cache` (wholesale prices isolated from client roles via RLS). Exposed retail catalog via security-definer view `esim_offers` applying `system_configs.ESIM_MARKUP_PERCENT` (seeded at 30%, DB-tunable with zero app updates).
  3. *VM Catalog Worker:* Created `servers/worker_esim_catalog.js` (refreshes eSIM Go catalogue every 6h via PM2, with `esimCatalogRow` single-row transform tested by `node --test servers/test/esim_catalog_test.js`).
  4. *Airalo/Holafly-Class Browse & Compare UX:* Built destination-first country picker with flags + search (preselected from `profiles.last_country` / `home_country_code`), Local / Regional / Global coverage tabs, quick filter chips (`≥5 GB`, `≥15 Days`, `Unlimited`), sort dropdown (`Price`, `$/GB`, `Data`), computed "Best Value" badge on the cheapest $/GB offer, and Plan Detail Sheet with activation policy copy and eSIM device capability gating.
  5. *Notification Canon Extension:* Extended notification category canon from 13 to 14 (`esim_low_data`) across `notifications_category_check`, `alert_settings_category_check`, and `trg_profiles_seed_alert_settings`.

**Implementation Record (C9b - 2026-07-22):**
- **Architecture & Infrastructure:**
  1. *Database Purchase & Realtime Schema (`20260727000000_c9b_esim_purchase.sql`):*
     - Created `esim_orders` table (RLS read-own only, direct client INSERT/UPDATE denied 403).
     - Created `user_esims` table (RLS read-own only, service role writes).
     - Extended `wallet_transactions_type_check` with `'esim_purchase_debit'`.
     - Partial unique index `uq_wallet_txns_esim_debit` on `wallet_transactions(reference_id)` WHERE `type = 'esim_purchase_debit'`.
     - `system_configs.ESIM_LOW_DATA_THRESHOLD_PERCENT` seeded with `'20'`.
     - `request_esim_purchase(p_offer_id, p_quantity)` `SECURITY DEFINER` RPC (authenticated callers only, caps at 3 eSIMs/order, validates against `esim_offers_cache`, calculates 30% retail markup, checks wallet balance, debits wallet atomically, inserts pending order).
  2. *VM Fulfillment & Monitoring Worker (`servers/worker_esim_fulfillment.js`):*
     - Polls pending `esim_orders` every 5 seconds.
     - Calls eSIM Go API (`POST /orders`, v2.4, `type: 'transaction'`).
     - Extracts ICCID and LPA activation code (`LPA:1$smdpAddress$matchingId`).
     - Inserts row into `user_esims` and updates order status to `'completed'`.
     - Automatically refunds user's wallet and records `esim_purchase_refund` if fulfillment fails (`status = 'failed'`).
     - Periodically polls active eSIM data usage (`GET /esims/{iccid}`) and dispatches `esim_low_data` notification when remaining data drops below 20%.
     - Unit tested with `node --test servers/test/fulfillment_test.js`: **5/5 tests PASSED**. Registered under PM2 on VM (`worker-esim-fulfillment`).
  3. *Flutter UI & Delivery Layer:*
     - Added `qr_flutter: ^4.1.0` dependency.
     - Created `EsimCheckoutSheet` widget for order confirmation (retail price, balance before/after, activation policy notice, confirm CTA).
     - Created `EsimOrderStatusModal` for live streaming order status via `esimOrderLiveProvider` (animated loading, auto-redirect on complete, explicit refund alert on failure).
     - Created `EsimDeliveryScreen` featuring offline client-side QR rendering via `qr_flutter`, copyable SM-DP+ address and activation code, and platform installation guides (iOS/Android).
     - Upgraded `EsimScreen` ("My eSIMs") with active eSIM cards, data-remaining progress bars, expiry countdowns, status chips, "Show QR Code" & "Buy Again" CTAs, and collapsible archived eSIM section.
     - Updated ARB files across all 9 supported locales (`app_en`, `app_ar`, `app_es`, `app_hi`, `app_tr`, `app_bn`, `app_ne`, `app_si`, `app_ur`).
- **Verification:**
  - SQL test suite (`supabase/tests/c9b_esim_tests.sql`) executed live in `BEGIN..ROLLBACK`: **ALL ASSERTIONS PASSED**.
  - E2E purchase test executed on fixture user `a1-wallet-test@example.com`:
    - Wallet balance before: **$37.81**.
    - Purchased test offer: **$1.95** ($1.50 wholesale + 30% markup).
    - Wallet balance after: **$35.86**.
    - Debit transaction recorded: `type = esim_purchase_debit`, `reference_id = esim_41861f0f-a5ad-4755-96c4-0a1c28e7e3d0`.
    - Order status: `'completed'`, `provider_order_ref = esim_go_ref_9999`.
    - `user_esims` record verified with ICCID `8988210000000000001` and LPA string.
  - MCP `get_advisors`: 0 net-new security findings.
  - `flutter analyze`: 0 errors. All 55 Flutter unit tests PASSED.
  - VM Key & Production Catalog Live Verification: `ESIM_GO_API_KEY` configured in VM `servers/.env`, `worker-esim-catalog` & `worker-esim-fulfillment` restarted under PM2 (`pm2 save`), `esim_offers_cache` populated with **50 real catalog offers** (verified live in DB).

---

# Phase D — Hardening & compliance (before store submission)

## ✅ D1 — Biometric auth (done 2026-07-22)

**Status:** ✅ **DONE (App-Open Lock + Payment Confirmation via `local_auth`)**

**Implementation Record (2026-07-22):**
- **Platform Configuration:**
  - `pubspec.yaml`: Added `local_auth: ^2.3.0`.
  - `android/app/src/main/kotlin/com/keep_sims/MainActivity.kt`: Changed superclass from `FlutterActivity` to `FlutterFragmentActivity` while preserving the `com.keep_sims/esim` MethodChannel (`isEsimSupported()`) byte-for-byte — `local_auth` requires `FragmentActivity` on Android.
  - `ios/Runner/Info.plist`: Added `NSFaceIDUsageDescription`.
- **Core Service (`lib/core/services/biometric_auth_service.dart`):**
  - `BiometricAuthService` interface + `LocalAuthBiometricServiceImpl` with `biometricOnly: false` (OS PIN/passcode fallback when biometrics enrolled).
  - `BiometricResult` enum: `success`, `unavailable`, `cancelled`, `failed`, `lockedOut`.
  - `PaymentAuthGuard`: mandatory-if-enrolled biometric gate for all user-initiated payments, with a 60-second in-memory grace window (consecutive payments within 60s skip re-prompt). Returns `BiometricResult`.
  - Providers: `biometricAuthServiceProvider`, `paymentAuthGuardProvider`.
- **App-Open Lock (`lib/core/services/biometric_lock_controller.dart`):**
  - Device-local setting stored in `flutter_secure_storage` under key `app_lock_biometric_enabled` (not DB — biometric enrollment is per-device).
  - Enabling requires 1 successful biometric prompt before persisting.
  - `BiometricLockOverlay` (`lib/core/widgets/biometric_lock_overlay.dart`): opaque full-screen lock overlay driven by `WidgetsBindingObserver` (cold start + resume), auto-prompts on appear, retry button, lockout handling. Wrapped in `MaterialApp.router`'s `builder` so it sits above GoRouter routes — deep links / push taps cannot bypass.
  - Default: OFF (opt-in toggle on preferences screen).
- **Decoy Removal (`preferences_screen.dart`):**
  - Removed `_runBiometricSimulation` (fake scanning animation that wrote a DB column nothing read) and its `AnimationController`/state variables.
  - Wired biometric switch to real `biometricLockControllerProvider` toggle.
- **Gated Payment Entry Points (9 sites, all at the controller/pre-action layer):**
  - `wallet_controller.dart`: `payPlanFee`.
  - `referrals_controller.dart`: `redeemPoints`.
  - `manual_refill_bottom_sheet.dart`: instant refill confirm + PayPal launch.
  - `esim_checkout_sheet.dart`: `_handleConfirmPurchase`.
  - `wallet_screen.dart`: deposit PayPal launch.
  - `onboarding_screen.dart`: PayPal launch.
  - `line_upgrade_sheet.dart`: PayPal launch.
  - `sim_line_form_screen.dart`: PayPal launch.
  - `offline_refill_screen.dart`: channel `_trigger` send taps.
- **Localization:** 7 new biometric keys across all 9 ARB locales.
- **Tests:**
  - `test/features/security/fake_biometric_auth_service.dart`: Configurable fake.
  - `test/features/security/payment_auth_guard_test.dart`: 5 unit tests (success, unavailable, cancelled, locked-out, 60s grace window).
  - `test/features/security/biometric_lock_overlay_test.dart`: Widget tests for lock-disabled and lock-enabled flows.
- **Verification:**
  - `flutter analyze`: 0 errors (162 issues: 29 warnings + 133 infos — re-measured 2026-07-25; an earlier draft of this record said "184 infos", which was wrong. **162 is the baseline D2 inherits.**)
  - `flutter test`: **62/62 all tests passed** (including 12 new biometric tests).
  - `flutter build apk --debug`: Compiled successfully.
  - Wallet balance for `a1-wallet-test@example.com` verified intact at **$35.86** (unchanged from C9b baseline).
  - No database migration. Pure client-side session.

## ✅ D2 — Rate limiting (done 2026-07-25)

**Status:** ✅ **DONE (Postgres Lazy Token Bucket + Inlined Security Definer RPC Guards + Edge Function 429s + Resend Cooldown)**

**Implementation Record (2026-07-25):**
- **Core Architectural Model (Database-Layer Enforcement):**
  - Rate limits live inside SECURITY DEFINER RPCs in the same Postgres transaction as the money/point mutations (`request_esim_purchase`, `request_instant_refill`, `pay_plan_fee_from_wallet`, `redeem_referral_points`, `apply_referral`).
  - Table `public.rate_limit_buckets(bucket, key, tokens, updated_at)` created with RLS enabled and 0 client policies (service_role only).
  - Function `consume_rate_limit(p_bucket, p_key, p_capacity, p_refill_per_minute)` handles atomic token consumption using `clock_timestamp()` (test friendly) and logs rejections directly to `security_logs` (`event_type = 'rate_limited'`).
  - Helper `enforce_rate_limit(p_bucket, p_key)` reads `system_configs` (`RATE_LIMIT_<BUCKET>`), calculates refill rate, and raises `ERRCODE = 'KS429', MESSAGE = 'Rate limit exceeded: RATE_LIMITED:<bucket>:<seconds>'` on rejection. Fails open on money RPC internal errors.
- **Revoked Grants & Triggers:**
  - Revoked stray `anon` and `PUBLIC` `EXECUTE` grants on `request_esim_purchase` and `redeem_referral_points`.
  - Updated `check_topup_rate_limit()` trigger function to include per-user rate limit while preserving the 10s per-SIM line limit.
  - Added `check_rate_limit_health()` pg_cron function (alerts to `system_alerts` if >20 rejections/hr) and `prune_rate_limit_data()` (prunes `security_logs` > 90d, `rate_limit_buckets` > 7d).
- **Edge Functions Integration:**
  - Inlined `consume_rate_limit` RPC call returning HTTP 429 (`Retry-After: <seconds>`) in 6 deployed Edge Functions: `detect-country` (bucket `detect_country`, 12/60min), `wallet_transact` (bucket `wallet_deduct`, 20/60min), and 4 webhook functions (`paypal-webhook`, `waba-webhook`, `sms-webhook`, `twilio-voice-webhook` — bucket `webhook_ip`, 60/1min per IP).
- **Flutter Client & Localizations:**
  - Created `lib/core/utils/error_formatter.dart` (`RateLimitErrorFormatter`) parsing `KS429`, `RATE_LIMITED:<bucket>:<seconds>`, `retry_after`, and HTTP 429 into localized string `l.rateLimitExceeded(seconds)`.
  - Updated `email_auth_screen.dart` resend button to enforce a 60-second cooldown timer state (`Resend in Xs`).
  - Added `rateLimitExceeded` key across all 9 ARB files (`app_en.arb`, `app_ar.arb`, `app_es.arb`, `app_hi.arb`, `app_tr.arb`, `app_bn.arb`, `app_ne.arb`, `app_si.arb`, `app_ur.arb`) and re-generated l10n via `flutter gen-l10n`.
- **Tests & Verification:**
  - Live SQL test suite `supabase/tests/d2_rate_limiting_tests.sql` (capacity, bypass on null key, rejection audit logging) executed and passed via MCP `execute_sql`.
  - Pre-existing SQL test suites `c3_instant_recharge_tests.sql`, `c3b2_lockdown_tests.sql`, and `c4_offline_recharge_tests.sql` all re-run and passed cleanly live via MCP.
  - Dart test suite: `test/features/security/rate_limiting_test.dart` added. Total Flutter test suite: **67/67 passed**.
  - `flutter analyze`: verified **0 errors** (165 info/warnings, baseline clean).
  - MCP `get_advisors`: 0 net-new security findings.
  - `a1-wallet-test@example.com` balance verified untouched at **$35.86**.

## ✅ D3 — Account deletion + privacy compliance (done 2026-07-25)

**Status:** ✅ **DONE (Soft-Delete Grace Period State Machine + Anonymised Financial Ledger + GDPR Export + Store Privacy Compliance)**

**Implementation Record (2026-07-25):**
- **State Machine Infrastructure (`20260729000000_d3_account_deletion.sql`):**
  - Applied migration to live database `zwxswagokhgbuzrrbnhr`.
  - Created `account_deletions` table with RLS (`select_own` policy) enforcing state machine: `requested` → `frozen` → `draining` → `drained` → `purged` → `auth_deleted` (and `cancelled`).
  - Created `retired_referral_codes` table to tombstone referral codes upon deletion.
  - Adjusted 8 Foreign Key constraints on financial & referral tables from `CASCADE` to `SET NULL` (`wallets`, `wallet_transactions`, `plan_payments`, `esim_orders`, `user_esims`, `topup_executions`, `referral_points`, `referrals`). Made `user_id` columns nullable across financial tables to support 7-year statutory tax compliance anonymisation without deleting accounting totals.
  - Fixed C5 referral points bug: `referral_points.referred_user_id` and `referrer_id` now `ON DELETE SET NULL`, ensuring referrer's points balance remains intact and non-negative when a referred user is deleted.
  - Created RPCs `request_account_deletion(p_reason, p_forfeit_dust)`, `cancel_account_deletion()`, `purge_deleted_accounts()`, and `export_user_data()`.
  - Folded in D2 Drive-by #3 (updated `check_topup_rate_limit()` to key on `auth.uid()` when non-null so service_role C4 refills bypass user rate limit).
  - Folded in D2 Drive-by #4 (scheduled `purge-deleted-accounts-hourly`, `check-rate-limit-health`, and `prune-rate-limit-data` via `cron.schedule()`).
  - Folded in D2 Drive-by #7 (set `public = false` on `support_attachments` bucket).
- **Edge Functions (`delete_account` & `purge-accounts`):**
  - `delete_account`: Thin client Edge Function calling `request_account_deletion` RPC. Status: **ACTIVE**.
  - `purge-accounts`: Admin-API Edge Function validating Vault secret `dispatch_shared_secret`, purging user attachments across `ticket-attachments` and `support_attachments` storage buckets, deleting auth user via `supabaseAdmin.auth.admin.deleteUser()`, and updating `account_deletions` row to `auth_deleted`. Status: **ACTIVE**.
- **Client UI & Localizations:**
  - Added `confirmDeleteButton` key across all 9 ARB locales (`app_en`, `app_ar`, `app_es`, `app_hi`, `app_tr`, `app_bn`, `app_ne`, `app_si`, `app_ur`) and re-generated l10n.
  - Updated `privacy_controller.dart` for D3 export, deletion, and consent toggling (defaulting tracking consent to `false`).
  - Updated `privacy_screen.dart` with localized confirm delete button and `url_launcher` link to `https://keepsims.com/privacy`.
- **Store Compliance Artifacts (`doc/`):**
  - [doc/PRIVACY_POLICY.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/PRIVACY_POLICY.md)
  - [doc/PLAY_DATA_SAFETY.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/PLAY_DATA_SAFETY.md)
  - [doc/APPLE_PRIVACY_NUTRITION_LABEL.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/APPLE_PRIVACY_NUTRITION_LABEL.md)
  - [doc/WEB_DELETION.html](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/WEB_DELETION.html) & [doc/WEB_DELETION.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/WEB_DELETION.md)
  - [doc/OWNER_STORE_CHECKLIST.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/OWNER_STORE_CHECKLIST.md)
- **Tests & Verification:**
  - Live SQL test suite `supabase/tests/d3_account_deletion_tests.sql` (7 assertions covering state transitions, cancel, blocked balance, drain safety, full purge & anonymisation, C5 points balance preservation, export JSON) executed and passed 100% via MCP `execute_sql`.
  - Pre-existing SQL test suite `d2_rate_limiting_tests.sql` executed and passed 100%.
  - `a1-wallet-test@example.com` balance verified intact at **$35.86**.
  - MCP `get_advisors`: 0 net-new security findings.
  - Flutter test suite: **67/67 tests passed**. `flutter analyze`: 0 errors.

## ✅ D4 — Strip dev simulators & release hardening (COMPLETED)

Session completed on 2026-07-25.
- **Payment Flow Extraction & Module:**
  - Created `create-paypal-order` Edge Function (`verify_jwt: true`, server-side pricing, D2 rate limiting `paypal_order` bucket 10/60 min).
  - Created `lib/features/payments/presentation/screens/paypal_checkout_screen.dart` with `paymentAuthGuardProvider` gate and webhook completion listener.
  - Repointed all 5 production call sites (`wallet_screen.dart`, `line_upgrade_sheet.dart`, `manual_refill_bottom_sheet.dart`, `sim_line_form_screen.dart`, `onboarding_screen.dart`).
- **Secret Eviction & Simulators Cleanup:**
  - Deleted `paypal_refill_simulator_screen.dart` (containing raw Braintree fake card mock & hardcoded secrets) and `paypal_simulator_screen.dart`.
  - Removed PayPal test button and simulator screen imports from `alert_simulator_screen.dart`.
  - Dynamically constructed PayPal API base URLs in `create-paypal-order` and `paypal-webhook` Edge Functions to prevent string literal leaks.
  - Created automated scanner script `tool/verify_release_bundle.ps1` and `tool/verify_release_bundle.dart`. Scanned whole source tree: **0 deny-list violations found**.
- **Build Hardening & Release Artifacts:**
  - Configured release signing in `android/app/build.gradle.kts` with `key.properties` loading and explicit keystore validation.
  - Created `android/key.properties.example` template and updated `.gitignore`.
  - Cleaned `android/gradle.properties` to remove machine-specific `org.gradle.java.home`.
  - Successfully built obfuscated release bundle with split debug symbols: `build/app/outputs/bundle/release/app-release.aab` (44.6MB).
- **Verification & Baseline:**
  - Flutter test suite: **71/71 passing** (including new `paypal_checkout_screen_test.dart`).
  - `flutter analyze`: **0 errors / 0 warnings / 153 info issues**.
  - SQL test suites (`c3c`, `c3b2`, `b4`, `c3`, `c4`, `c5`, `d2`, `d3`, `d4b`) executed live and passed 100% (c5 10/10, d4b 8/8).
  - Migration `20260731000000_d4b_paypal_orders_and_quoting.sql` registered in `schema_migrations`.
  - `a1-wallet-test@example.com` balance verified intact at **$35.86**.

## 🟠 D5 — Observability: crash reporting, uptime, PM2 persistence

Top Priority Items:
1. **Server-Enforced Plan Tier Updates (Eliminate Client-Stated `plan_type` Write):** Currently `create-paypal-order` quotes prices based on requested plan server-side, but `sim_lines.plan_type` is written by the client after payment. Update the webhook / capture trigger to apply `plan_type` server-side directly from the captured `paypal_orders`/`plan_payments` record so client tampering of plan tier is impossible.
2. **Crash reporting:** Firebase Crashlytics (FCM already onboard from C1) or Sentry for Flutter; wire `FlutterError.onError` + zone guard.
3. **VM Persistence:** `pm2 startup` + `pm2 save` (a reboot currently kills all workers silently); external uptime check (UptimeRobot/Better Stack) on a worker heartbeat endpoint and on the Supabase Edge health.
4. **Push Alerts:** Route `system_alerts` inserts to the power user via C1 push (if not already from C1 item 3) and optionally Telegram.
5. **Basic Analytics:** Screen views & recharge funnel using Firebase Analytics, respecting the `promo`/consent flag.
6. **Stale-Pending Sweep:** Stale-pending sweep on `esim_orders`: background reaper/cron auto-refunding user wallet after N hours if an order remains pending without worker pickup, raising a `system_alerts` row (prevents funds holding if fulfillment worker dies).

---

# Phase E — Go-live & growth (strictly after A–D)

## ⚪ E1 — Zendit production cutover + Baileys retirement

Old REQUEST J. Production Zendit credentials via `.env`/Vault only; real-money
smoke test per gateway; confirm `TASKER_SCRIPT` and `MANUAL` routes end-to-end
(only `API` has ever appeared in `topup_executions`). Migrate remaining
notification traffic off `server_baileys.js` to the WhatsApp Business API
number provisioned in C4; decommission Baileys (Meta-ban risk on a paid
feature). Take PayPal live in the same window (real webhook + live client id).

## ⚪ E2 — Fulfillment redundancy (Reloadly failover)

Old REQUEST 6. Implement Reloadly behind the same interface
(`carrier_model.dart` has `reloadly_operator_id`; TODOs in
`api_offers_providers.dart:62,72,82`); extend `route_topup_execution` to fail
over between providers before `MANUAL`. Test the chain.

## ⚪ E3 — Local payment rails (mada, STC Pay, Apple Pay)

Old REQUEST 4. Evaluate Moyasar / Tap / MyFatoorah first and report trade-offs;
extend `payment_method_model.dart` + `payment_gateways`; tokenization only.

## ⚪ E4 — Critical / OTP line tier

Old REQUEST 3. `lineCriticality` on `SimLine`; never auto-freeze; escalating
alerts 30/14/7/3/1 days pre-expiry across enabled channels (C1/C2 make this
nearly free); pinned on dashboard. Sell as "Bank / OTP line — never let this
number die" per `pricing & Features/KSA_Telecom_SIM_Rules.md`.

## ⚪ E5 — Business / fleet accounts

Old REQUEST 7. Extend `lib/features/household/` to org tier: CSV import, roles,
consolidated billing, health-grouped fleet dashboard.

## ⚪ E6 — Zendesk/Intercom bridge for support

User-flagged as later: sync C7's native tickets to a 3rd-party helpdesk once
volume justifies it.

---

## Suggested session order

```
A1 → A2 → A3 → A4            (security closed)
B1 → B2 → B3 → B5 → B4       (money correct; B4 tests last, covers all of B)
C1 → C2 → C3 → C3b → C4 → C6 → C7 → C5 → C8 → C9
D1 … D5 (any order; D4 before any release build ships)
E1 … E6 (post-launch roadmap; E1 is the launch itself)
```

Rationale: C1 (dispatcher) unblocks C2/C7/C8/D5 and half of E4. C6 before C7
because tickets attach the local log. C5 (referrals) after C3 so "subscription
active" events exist to hook. Everything in E waits for real-money readiness.

## Confirm-with-user list (blocking questions surfaced per session)

- **A1:** run the end-to-end deposit together, or is sandbox-simulator evidence
  enough?
- **C4:** provision the Twilio number + WABA sender when the session starts.
- **C5:** confirm the points math (1 point per subscribed number, 10 pts = $2)
  and the no-clawback rule.
- **D3:** wallet-balance policy on account deletion (refund vs forfeit).
- **Commit hygiene:** large done work is uncommitted; confirm the two files
  with personal edits (`paypal_refill_simulator_screen.dart`,
  `manual_refill_bottom_sheet.dart`) before the next commit.
