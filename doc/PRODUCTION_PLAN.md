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

**Still architecturally weak:** the client states a price at all. The real end
state is a server-side offers cache + a `request_instant_refill` RPC that
computes `base_cost_usd` itself, after which client INSERT can be revoked
outright. The worker check makes that safe to defer, but it should land before
E1 flips to production keys.

### 🟠 C3b-3 — offline: cache `carriers` + `carrier_rules` (found 2026-07-17)

Only `sim_lines` is cached locally (`cached_sim_lines`). `carriers` and
`carrier_rules` are not, so **offline** — the one state the offline-recharge flow
exists for — `offline_refill_screen.dart` falls back to
`activeCarrier?.defaultRefillAmount ?? 5.00` **and**
`activeCarrier?.gatewayPhoneNumber ?? '+968 24 555 0110'`. An offline user on a
non-Oman carrier is shown the wrong amount and told to message **the wrong
number**. Both tables are small, change rarely (they are admin-curated, which is
the whole point of pinning `offer_id` / `minimum_topup_amount` there rather than
fetching Zendit per line), and are exactly what the offline path needs. Cache
them alongside `cached_sim_lines`. Belongs with C4 (offline recharge) if that
lands first.

### 🟠 C3b-2 — remaining (not started)

**Latent money bug.** Client `DELETE` on `topup_executions` is a silent no-op —
HTTP 200, 0 rows — because the table has SELECT/INSERT/UPDATE policies but *no
DELETE policy*. `deleteExecution`, `cancelSchedule` and `cleanMockLogs` all
believe they cancelled queued work and did not. `topup_executions.scheduled_topup_id`
is `ON DELETE SET NULL`, so deleting a schedule **orphans** its pending
executions instead of removing them, and `worker_auto_mini_refill` claims on
`status='pending' AND execution_time <= now()` with no parent-schedule check —
so a cancelled schedule's refills would still fire and debit the wallet. Nothing
is burning today (verified: zero orphaned pending rows), and Zendit is still on
sandbox keys.

Scope: add `cancel_topup_execution` RPC + `'cancelled'` to
`topup_executions_status_check`; make cancellation actually stop the worker;
migrate the two live client UPDATE sites (`retryFailedExecution`, which has the
client marking an execution `'refunded'`, and `updateMiniRefillDates`) to
SECURITY DEFINER RPCs; then revoke UPDATE/DELETE/INSERT on `topup_executions`
from `anon` + `authenticated` (A4 item 2). Also trim the excess grants: `anon`
currently holds INSERT/UPDATE/DELETE/TRUNCATE on this table (RLS and PostgREST
contain it today, but the grants have no business existing).

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
`system_configs.APP_FEE_PERCENT` is the pay-as-you-go rate. Both stay. Do not
"unify" them — and note `inapp_pricing` is load-bearing for the premium quote,
not a dead column.

## 🟠 C4 — Offline Recharge: stacked fallback cards (WhatsApp → SMS → missed call)

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

**User decision (encoded; confirm the arithmetic in-session before coding):**
points system. A referred user's phone-number subscription on a **Standard or
Premium** plan earns the referrer points; **10 numbers subscribed = 2 USD** —
i.e. 1 point per subscribed number, and at 10 points the user can convert to
$2.00 wallet credit. Multiple referred users can contribute (10 users × 1 line
or 1 user × 10 lines both qualify).

1. Schema: `referral_codes(user_id, code UNIQUE)`,
   `referrals(referrer_id, referred_user_id UNIQUE, code, created_at)`,
   `referral_points(id, referrer_id, referred_user_id, sim_line_id UNIQUE,
   points, source, created_at)` (UNIQUE on `sim_line_id` prevents double
   counting), `referral_redemptions(user_id, points_spent, wallet_txn_id,
   created_at)`. RLS: read own rows only; **all writes server-side**.
2. Award trigger: on a sim line's subscription becoming active on a Standard or
   Premium plan where the owner is a referred user → insert 1 point row. Handle
   downgrades/cancellations (points are awarded once, not clawed back — confirm).
3. Redemption: RPC (`SECURITY DEFINER`, service-role-ish gating like
   `wallet_transact`) that atomically deducts 10 points and credits $2 via
   `credit_wallet` — never from the client.
4. Existing `apply_referral` RPC (locked down in REQUEST A) — read it first;
   reuse or replace deliberately.
5. UI in `lib/features/referral/` (or create): code + share link, points
   balance, progress to next $2, redemption button, history.
6. Abuse controls: self-referral block, same-device heuristic, cap pending
   points per referrer per day.

## 🟠 C6 — Activity log: local mirror + capped cloud table + dashboard feed

**User decision:** store full history locally (SQLite/Hive) for offline; keep
only the **newest 20 rows per user** in Supabase `activity_logs`.

1. Table `activity_logs(id, user_id, type, title, metadata jsonb, created_at)`;
   RLS read-own; inserts from server paths (wallet txns, refill status changes,
   profile updates) via trigger or from the existing write sites.
2. Prune: `AFTER INSERT` trigger deleting rows beyond the newest 20 per user
   (or a pg_cron sweep — trigger preferred, it's self-maintaining).
3. Local: Hive box (already a dependency? verify; else `sqflite`) mirroring
   every event the client sees, unlimited history, exposed with pagination.
4. Unified "Recent Activity" feed on the Dashboard merging cloud + local,
   deduped by id, offline-capable.
5. Migrate anything currently scattered (wallet txn list, refill history) to
   read from this feed where it makes sense — audit, don't force.

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

## 🟠 C8 — Travel & geolocation: country-change → roaming advice / eSIM offer

**User decision:** foreground-only tracking is enough; the trigger that matters
is "user entered a new country."

1. Audit existing `geo_controller.dart` flow: on app open/resume, resolve
   country (existing geolocation permission flow); compare to
   `profiles.last_country` (add column if missing); on change, update it and
   fire a `travel_roaming` notification (C1) with roaming advice + eSIM offer
   deep link (to C9's browse screen).
2. Interplay with B5: entering a country still triggers
   `freezeAllInternationalLines()` minus `requires_protection_at_home` lines.
3. Privacy: coordinates never stored — only ISO country code; disclose in
   privacy policy (D3 session touches this); respect the `geo_fence_triggered`
   toggle from C2 (the plan's `travel_roaming` name was superseded — see C2);
   degrade gracefully when permission denied.
4. No background location — keeps store review simple. Note the limitation
   (detection happens on next app open) in the UI copy.

## ⚪ C9 — eSIM management (big — split if needed)

Old REQUEST 11: `lib/features/esim/` is a facade (both CTAs at
`esim_screen.dart:81,96` show "coming soon"). Build browse-by-destination,
purchase against the wallet, QR/activation delivery, "My eSIMs" with data
remaining + expiry, low-data alerts via C1. eSIM Go calls go through an Edge
Function (never `ESIM_GO_API_KEY` in the app — it's currently via
`flutter_dotenv`, which bundles as an extractable asset; move it server-side as
part of this). Surface eSIMs alongside physical lines. Reasonable split:
(a) catalog + purchase, (b) management + alerts.

---

# Phase D — Hardening & compliance (before store submission)

## 🟠 D1 — Biometric auth

FaceID/fingerprint via `local_auth`: optional app-open lock (setting, default
off) and **mandatory-if-enrolled confirmation for payments** (deposit,
recharge, points redemption). PIN/passcode fallback via the OS prompt. Handle
no-biometrics devices and the Android `FragmentActivity` requirement. Gate in
the payment flows at the controller layer, not per-screen.

## 🟠 D2 — Rate limiting

Server-side, since the client is untrusted:
1. Supabase Auth: review built-in rate limits (Dashboard → Auth → Rate Limits),
   tighten OTP/signup sends.
2. Edge Functions (`wallet_transact`, `execute_zendit_recharge`,
   `dispatch_notification`, C4 webhooks): per-user + per-IP token bucket backed
   by a Postgres table or Upstash Redis; 429 with `Retry-After`.
3. DB backstop: trigger rejecting > N `topup_executions` inserts per user per
   minute.
4. Alert on sustained 429s via `system_alerts`.

## 🟠 D3 — Account deletion + privacy compliance (store requirement)

1. In-app "Delete account" (Settings → Account): re-auth, explain
   consequences, then an Edge Function (service role) that cancels schedules,
   zeroes/archives the wallet (decide with user: refund flow or forfeit-with-
   consent), deletes user rows across all tables (write the cascade explicitly
   — FK audit), deletes the auth user.
2. Data export (GDPR-friendly, cheap once C6 exists): email a JSON of profile,
   lines, transactions.
3. Update privacy policy for: foreground location/country (C8), WhatsApp/SMS
   phone-number processing (C4), and fill the Play Data Safety + App Store
   privacy questionnaires accordingly.

## 🟠 D4 — Strip dev simulators from release builds (finish)

Old REQUEST 5, partially done: simulators are `kDebugMode`-gated, **but
`paypal_refill_simulator_screen.dart` cannot be compiled out — it IS the live
payment flow used by 4 production screens.** This session:
1. Extract the real payment flow out of `paypal_refill_simulator_screen.dart`
   into a properly named feature module (`lib/features/payments/`), repoint the
   4 production call sites, then gate the remaining simulator shell.
2. Verify with `flutter build apk --release` + a string search of the bundle
   that simulator code and `/settings/simulators` routes are absent.

## 🟠 D5 — Observability: crash reporting, uptime, PM2 persistence

New suggestion + REQUEST H leftovers:
1. Crash reporting: Firebase Crashlytics (FCM already onboard from C1) or
   Sentry for Flutter; wire `FlutterError.onError` + zone guard.
2. VM: `pm2 startup` + `pm2 save` (a reboot currently kills all workers
   silently); external uptime check (UptimeRobot/Better Stack) on a worker
   heartbeat endpoint and on the Supabase Edge health.
3. Route `system_alerts` inserts to the power user via C1 push (if not already
   from C1 item 3) and optionally Telegram.
4. Basic analytics events (screen views, recharge funnel) — Firebase Analytics,
   respecting the `promo`/consent flag.

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
