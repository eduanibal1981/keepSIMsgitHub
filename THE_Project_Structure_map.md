# THE PROJECT STRUCTURE MAP — KeepSIMs

Structural index of the KeepSIMs system across its three layers: **Flutter client**, **Supabase
(Postgres + Edge Functions + pg_cron)**, and the **Oracle/GCE Cloud VM worker fleet**.

**Verification stamp.** Everything in §2 marked *live* was read from the production project
`zwxswagokhgbuzrrbnhr` on **2026-08-05** (`pg_policies`, `pg_proc`, `cron.job`, `information_schema`,
Supabase advisors). Everything with a `file:line` reference was read from the working tree at
`main` @ `1d53b40`. Row counts are `pg_class` estimates, not exact.

**Repo state correction.** Local `main` = `origin/main` = `1d53b40`; **121 of 122 migrations are
committed and pushed**. Only `supabase/migrations/20260819070000_j7_admin_outbound_email.sql`
(untracked) and a modification to `supabase/tests/f0_grant_matrix_tests.sql` are outstanding.
Project notes that still say "everything D→J5 is uncommitted" are stale.

**Reading convention.** `path/to/file.dart` - line N points at the *declaration* that owns the
behaviour, not every call site. DB objects are named exactly as they exist in `public`.

---

## 0. LAYER TOPOLOGY (orientation only)

| Layer | Root | Runtime | Deploy path | Who can change it |
|---|---|---|---|---|
| Flutter client | `lib/` | Dart 3 / Riverpod 3 / go_router 17 | Play Store APK/AAB | agent |
| SQL schema | `supabase/migrations/` (122 files) | Postgres 15 | `apply_migration` (MCP) | agent |
| Edge Functions | `supabase/functions/` (18 dirs) | Deno | `deploy_edge_function` (MCP) | agent |
| Edge Fn **secrets** | Supabase dashboard | — | dashboard only | **owner only** |
| Vault secrets | `vault.secrets`, read via `get_internal_secret()` | Postgres | SQL | agent |
| Cron | `cron.job` (15 active jobs) | pg_cron | SQL | agent |
| VM workers | `servers/` + `ecosystem.config.js` | Node 22 under pm2 | `git pull` on VM | **owner only** (no SSH from workstation) |
| Admin desktop app | `../keep_sims_admin` (separate repo) | Flutter Windows | local build | agent |

- Public-schema tables: **71**. Tables carrying at least one RLS policy: **47**. The remaining
  **24 are deny-all by design** (RLS on, zero policies) and are reached only through RPCs.
- SECURITY DEFINER functions: **~180**; **81** are `authenticated`-callable (the security perimeter).
- Client config: `lib/core/supabase_client.dart` - line 17 (`initSupabase`), URL + anon key via
  `String.fromEnvironment`. **The anon key ships inside the APK and must be treated as public.**

---

# 1. FEATURE INDEX & IMPLEMENTATION MAP

## Group A — Identity, account, device trust

### [1] Authentication (Google / email+password / email OTP)
- **Code Reference:** `lib/features/auth/controller/auth_controller.dart` - line 30;
  repository `lib/features/auth/repository/auth_repository.dart` - line 27
  (Google line 59, password line 113, OTP line 193, profile fetch line 238);
  UI `lib/features/auth/ui/login_screen.dart` - line 1 and `email_auth_screen.dart`.
- **How Achieved (Code Logic):** `AuthController` is a Riverpod `AsyncNotifier` holding
  `UserProfile?`. All three sign-in paths return `Result<UserProfile>`; on success the controller
  calls `OneSignal.login(profile.id)` (line 53) so push targets the Supabase user id as
  `external_id`, and `OneSignal.logout()` on sign-out (lines 46, 172). Redirect gating lives in
  `lib/core/router/app_router.dart` - line 99 (`GoRouter.redirect`).
- **How Achieved (Database & Cloud VM):** `auth.users` → trigger `handle_new_user()` creates
  `profiles` + `wallets` + `user_preferences` + `seed_default_alert_settings()`.
  `profiles` RLS = 3 policies (insert/update own, select own-or-household).
  `sync_power_user_claim()` / `sync_suspended_claim()` mirror `profiles` flags into JWT
  `app_metadata`. **Admin status is read from the JWT, never from the table** (F4b).
- **Pending / Missing Tasks:**
  1. Leaked-password protection is **disabled** (advisor WARN) — dashboard toggle, owner task.
  2. **No phone capture anywhere in the app.** `profiles.phone` is NULL for all 8 accounts and
     nothing writes it; feature [25] resolves senders via `sim_lines.phone_number` as a workaround.
  3. Apple sign-in / iOS auth is entirely absent (blocked on the Apple Developer account).
- **Technical Improvements & Suggestions:**
  - Add a phone field + OTP + `profiles.phone_verified_at`; this unblocks the SMS/WhatsApp rail
    from resting on a fallback join.
  - `AuthRepository` re-initialises Google Sign-In lazily (line 38); hoist to app start so the
    first tap is not the one that pays the init cost.

### [2] Onboarding & profile preferences
- **Code Reference:** `lib/features/profile/presentation/ui/onboarding_screen.dart` - line 35
  (submit at line 198); profile repo `lib/features/profile/data/repository/profile_repository.dart`
  - line 12; preferences UI `lib/features/settings/presentation/screens/preferences_screen.dart`
  - line 17.
- **How Achieved (Code Logic):** A multi-step form writing `profiles` (name, home country,
  `preferred_currency`) and seeding `notification_channels` inline
  (`_InlineOnboardingChannelConfig`, line 2457).
- **How Achieved (Database & Cloud VM):** `profiles`, `user_preferences` (8 rows),
  `notification_channels` (29 rows). Column-level UPDATE grants on `profiles` are on the F6
  allow-list; `protect_is_power_user()` reverts and logs any attempt to self-promote.
- **Pending / Missing Tasks:** Currency picker lists 14 currencies matching `fx_rates`, but
  **0 of 8 accounts have picked a non-USD currency**, so feature [20] renders for nobody.
- **Technical Improvements & Suggestions:** The screen is 2,754 lines in one file; split per step
  into `presentation/steps/` — it is the single largest merge-conflict surface in the client.

### [3] Account deletion + data export (GDPR/Play)
- **Code Reference:** `lib/features/settings/presentation/controllers/privacy_controller.dart`
  - line 37 (`exportData` line 83, `deleteAccount` line 104, `cancelAccountDeletion` line 143);
  UI `lib/features/settings/presentation/screens/privacy_screen.dart` - line 13.
- **How Achieved (Code Logic):** Calls `export_user_data()` and `request_account_deletion()`;
  deletion is guarded by `DestructiveActionGuard` (typed confirmation), not the payment guard.
- **How Achieved (Database & Cloud VM):** `account_deletions` (select-own only) + RPCs
  `request_account_deletion(p_reason,p_forfeit_dust)`, `cancel_account_deletion()`,
  `export_user_data()`. Purge pipeline: `purge_deleted_accounts()` → cron job 10 `0 * * * *`,
  plus Edge Function `purge-accounts` (`verify_jwt:false`, shared-secret gated) which calls
  `delete_auth_user_by_id()`. Web deletion page at `doc/WEB_DELETION.html`.
- **Pending / Missing Tasks:** `keepsims.com/delete` is not hosted (owner). `account_deletions`
  has 0 rows — the pipeline has never run against a real request.
- **Technical Improvements & Suggestions:** Add a scheduled dry-run assertion that
  `purge_deleted_accounts()` never touches a row whose grace window has not elapsed; today the
  only proof is the function body.

### [4] Biometric app lock + destructive-action guard
- **Code Reference:** `lib/core/services/biometric_auth_service.dart` - line 35
  (`PaymentAuthGuard` line 87, `confirmPayment` line 101);
  `lib/core/services/destructive_action_guard.dart` - line 28;
  overlay `lib/core/widgets/biometric_lock_overlay.dart` - line 7;
  controller `lib/core/services/biometric_lock_controller.dart`.
- **How Achieved (Code Logic):** `local_auth` behind an interface. `PaymentAuthGuard` has a
  **60-second grace window** and a lifecycle observer (line 228) that resets it on background.
  `DestructiveActionGuard` requires typing a confirmation word and has no grace window.
- **How Achieved (Database & Cloud VM):** None — purely client-side. Deliberate: it is a
  shoulder-surf control, not an authorisation control.
- **Pending / Missing Tasks:** Audit every call site: **`PaymentAuthGuard` is the wrong guard for
  destructive actions** — its grace window means a delete seconds after a refill prompts for
  nothing. Deletes must use `DestructiveActionGuard`.
- **Technical Improvements & Suggestions:** Make the grace window a `system_configs` key so it can
  be shortened without a release; today it is a Dart constant.

### [5] Device binding + velocity anti-fraud (G10)
- **Code Reference:** `lib/core/services/device_identity_service.dart` - line 44
  (`deviceId` line 58, `appCheckHeaders` line 103, `touch` line 123, `reportBlock` line 147);
  devices UI `lib/features/settings/presentation/screens/devices_screen.dart` - line 32;
  controller `lib/features/settings/presentation/controllers/devices_controller.dart` - line 73.
- **How Achieved (Code Logic):** Device id = 16 `Random.secure()` bytes as 32 hex chars in
  **SharedPreferences** key `keepsims_device_id` (pre-existing; the service reuses the same
  generator so no install is orphaned). Every money RPC takes `p_device_id` as its **last**
  parameter with `DEFAULT NULL` so old APKs still resolve. On a `KS451` refusal the client calls
  `report_device_block()` in a fresh transaction.
- **How Achieved (Database & Cloud VM):** Deny-all tables `user_devices` (1 row),
  `device_money_events` (32 rows), `device_risk_allowlist` (0 rows).
  Functions: `guard_money_action()`, `assess_device_risk()`, `device_velocity()`,
  `touch_user_device()`, `my_devices()`, `revoke_my_device()`, `label_my_device()`,
  `report_device_block()`, `log_app_check_result()`, `app_check_should_enforce()`,
  `device_risk_shadow_report()`, `app_check_summary()`.
  Thresholds live in `system_configs` under `DEVICE_RISK_*` and are hidden from clients by a
  **RESTRICTIVE** SELECT policy on `system_configs`.
  Guard sits in `create-paypal-order` v5 / `capture-paypal-order` v3 and in the four money RPCs.
- **Pending / Missing Tasks:**
  1. `DEVICE_RISK_ENFORCE = false` and `APP_CHECK_ENFORCE = false` — **nothing has ever been
     blocked**, by design. Enabling requires reading `device_risk_shadow_report(7)` first.
  2. Android is **not registered for Firebase App Check** (owner, Play Integrity), so no real
     attestation tokens exist. iOS impossible until the Apple account exists.
  3. `attested_at` is written but not scored.
  4. Cards-per-device signal is unexercised (`payment_methods` = 2 rows; PayPal stores no cards).
- **Technical Improvements & Suggestions:** A raised refusal rolls back its own audit row —
  the `report_device_block()` re-entry is the workaround and must be preserved in any refactor.
  There is no autonomous-transaction escape in this DB (no dblink, no pg_background; pg_net's
  queue is an ordinary table).

### [6] Rate limiting (D2)
- **Code Reference:** `lib/core/utils/error_formatter.dart` - line 5 (KS429 / `COOLDOWN_ACTIVE`
  parsing, regex at line 55); test `test/features/security/rate_limiting_test.dart`.
- **How Achieved (Code Logic):** Client does not rate-limit; it **renders** the server's refusal,
  extracting the retry-after seconds from the message.
- **How Achieved (Database & Cloud VM):** `rate_limit_buckets` (deny-all, 9 rows), token bucket in
  `consume_rate_limit()` / `enforce_rate_limit()` (**service_role only** — F-4 fixed the anon
  grant). `check_topup_rate_limit()` enforces a 10s per-line anti-spam cooldown, with rows whose
  `retry_of IS NOT NULL` exempted so supplier failover is not swallowed.
  Cron: job 11 `check_rate_limit_health()` `30 * * * *`, job 12 `prune_rate_limit_data()` `0 3 * * *`.
  Config keys `RATE_LIMIT_ADMIN_EMAIL = 20/60`, `RATE_LIMIT_AFFILIATE_CLICK = 60/60`.
- **Pending / Missing Tasks:** No rate limit on `request_esim_purchase`, `transfer_wallet_credit`
  or `record_affiliate_click` beyond the generic buckets; no per-IP limit anywhere (PostgREST does
  not surface the client IP to SQL).
- **Technical Improvements & Suggestions:** Move IP-based limiting to a reverse proxy / Cloudflare
  in front of the Supabase domain — see §2.3 step 4.

---

## Group B — SIM lines and protection

### [7] SIM line CRUD + number verification
- **Code Reference:** list `lib/features/sim_lines/presentation/screens/sim_lines_list_screen.dart`
  - line 26; form `.../sim_line_form_screen.dart` - line 29 (`commitSave` line 1292);
  detail `.../sim_line_detail_screen.dart` - line 36;
  repository `lib/features/sim_lines/data/repositories/sim_lines_repository_impl.dart` - line 21
  (`getSimLines` 45, `addSimLine` 128, `updateSimLine` 189, `deleteSimLine` 219,
  `triggerMissedCall` 719, `checkCallStatus` 724, `confirmLineVerification` 734, `cancelCall` 769);
  dialog `.../widgets/number_verification_dialog.dart` - line 10.
- **How Achieved (Code Logic):** Riverpod `SimLinesController`
  (`.../controllers/sim_lines_controller.dart` - line 1) with optimistic local state; verification
  triggers a Twilio missed call and polls call status.
  **That local state is a snapshot** — the controller is `keepAlive` and its `build()` watches only
  the auth profile, and a save splices the row the client *constructed* rather than re-reading the
  saved one. So nothing server-side reaches the card on its own. J8c added a realtime subscription
  on `topup_executions` (already published, SELECT-own) filtered to `user_id = auth.uid()`, which
  invalidates the controller when an execution reaches `success`/`failed` — without it, a Premium
  line whose first pre-paid refill had already succeeded still read "Last Refill — No refill yet",
  because `queue_premium_refill_executions` starts the plan year at `p_start_at` and that refill
  lands seconds after the purchase. The **detail** screen has its own controller and is not covered. Protection Console (`sim_line_detail_screen.dart`)
  includes a narrow "Traveling Tomorrow" switch row directly below the main SIM data card that invokes
  `SimLinesController.toggleHomeMode()` to switch between Home Mode (`isHomeMode = true`) and Travel Mode
  (`isHomeMode = false`). When toggled ON, the text label dynamically transforms into an action button ("Buy eSIM" for eSIM-capable hardware, or "Buy Cheapest Package" for standard devices).
- **How Achieved (Database & Cloud VM):** `sim_lines` — **7 RLS policies** (own CRUD, household
  SELECT, household-manager UPDATE, power-user ALL). Triggers:
  `update_sim_line_last_topup_at()`, `trg_prevent_sim_line_plan_tampering` (BEFORE UPDATE),
  `check_free_lines_limit()`. Edge Function `twilio-voice-webhook` (`verify_jwt:false`,
  `x-twilio-signature` verified at line 90).
- **Pending / Missing Tasks:**
  1. **`sim_lines.status` DEFAULT `'unverified'` violates its own CHECK** (`active/paused/expired/
     grace_period/deactivated`) — any INSERT omitting `status` raises `23514`. Latent trap.
  2. `authenticated` holds column INSERT on `created_at` — that is what defeated the I2
     grandfather clause; any future "created before X" rule is dead on arrival.
- **Technical Improvements & Suggestions:** `sim_line_detail_screen.dart` is 3,163 lines with
  ~14 `_build*` methods; extract the four panels (header, protection layers, executions, timeline)
  into `presentation/widgets/detail/`.

### [8] Country / carrier catalogue
- **Code Reference:** `sim_lines_repository_impl.dart` - line 239 (`getSupportedCountries`),
  line 340 (`getCarriersForCountry`).
- **How Achieved (Code Logic):** Plain PostgREST selects, cached in `LocalCacheService`
  (`lib/core/services/local_cache_service.dart` - line 18).
- **How Achieved (Database & Cloud VM):** `countries` (21 rows, public SELECT + power-user UPDATE),
  `carriers` (67 rows, public SELECT only). `carriers` carries supplier columns for all four
  suppliers (`zen_*`, `dt_*`, `ding_*`, `reloadly_operator_id`) plus `api_provider` and
  `fulfillment_gateway`.
- **Pending / Missing Tasks:** `ding_carrier`/`ding_country`/`reloadly_operator_id` are **NULL for
  every carrier** — those two suppliers cannot be enabled until the codes are entered.
  13 of 50 API-routed carriers have **nothing in the offer cache** (Omantel, STC Kuwait included,
  both with live lines).
- **Technical Improvements & Suggestions:** `carriers` has SELECT-only RLS and no write policy, so
  the admin app must go through `admin_update_carrier()` — that is correct and should be asserted
  by a test, because a direct PATCH returns **HTTP 200 with 0 rows** and reads as success.

### [9] Carrier deactivation rules & activity semantics (I7)
- **Code Reference:** `sim_lines_repository_impl.dart` - line 395 (`getCarrierRule`),
  line 459 (`getCarrierRuleById`); model
  `lib/features/sim_lines/data/models/carrier_rule_model.dart`; test
  `test/features/sim_lines/carrier_rule_model_test.dart`.
- **How Achieved (Code Logic):** Rule drives the refill cadence shown on every purchase surface.
- **How Achieved (Database & Cloud VM):** `carrier_rules` (67 rows, public SELECT), one row per
  carrier enforced by a unique index (H3b). `refill_interval_days()` is now the cadence source;
  the legacy 85/28/13 snap survives only for lines with **no** carrier rule.
  `usage_required` carriers cannot be kept alive by refilling at all.
  Migrations `20260817000000_i7` … `_i7d`.
- **Pending / Missing Tasks:** **`carrier_rules.rule_type` CHECK allows only
  `('prepaid','postpaid','data_only')` but `getCarrierRule()` queries `'default'` first** — that
  branch can never match, so every live read costs a wasted round-trip and is served by the
  `'prepaid'` fallback. Unfixed since I8.
- **Technical Improvements & Suggestions:** Delete the `'default'` branch, or add `'default'` to the
  CHECK — one or the other, but the current state documents a tier that does not exist.

### [10] Carrier rules sheet + buy/don't-buy verdict (I8)
- **Code Reference:** `lib/features/sim_lines/domain/carrier_rule_advice.dart` - line 122
  (`CarrierPlanAdvice` line 69, thresholds lines 127/132, `_escalate` line 209);
  sheet `lib/features/sim_lines/presentation/widgets/carrier_rules_sheet.dart` - line 26
  (`show` line 50, fallback store search line 625);
  notice `.../widgets/carrier_activity_notice.dart` - line 26;
  test `test/features/sim_lines/carrier_rule_advice_test.dart` (13 cases).
- **How Achieved (Code Logic):** Pure-Dart verdict from the rule: `selfServiceOnly` (usage_required
  → *keep your money*), `standardIsEnough` (window ≥ 270d), `premiumWorthIt` (61–269d),
  `premiumStronglyAdvised` (≤ 60d). **No grace period escalates one level; a generous grace never
  de-escalates.** `usage_required` returns **before any money is computed**, so no price is printed
  beside a refusal. Fully localised (39 keys × 9 locales).
- **How Achieved (Database & Cloud VM):** `carrier_self_service` (29 rows) — holds app *names* only;
  **every URL column and every `verified_at` is NULL on purpose**, so the client renders a store
  search plus "check the publisher", never a link. `emit_carrier_self_service_advice(p_dry_run)`
  → cron job 24 `55 2 * * *` (after the 02:20 forecast it reads). Notification category
  `carrier_action` (its own category so it can be muted without muting `system`).
- **Pending / Missing Tasks:**
  1. `CARRIER_ADVICE_ENABLED = false` — ships inert. `p_dry_run` deliberately ignores the switch.
  2. Store URLs are unfilled; that is an owner task via `admin_upsert_carrier_self_service()`.
  3. Server-authored notification bodies are **English only** (the sheet is not).
- **Technical Improvements & Suggestions:** None outstanding on the logic; the verdict table is the
  cleanest domain module in the client and is the pattern the rest should follow.

### [11] Dashboard, health score, protection tiers
- **Code Reference:** `lib/features/dashboard/presentation/ui/dashboard_screen.dart` - line 32;
  controller `.../controller/dashboard_controller.dart` - line 72 (`refreshDashboard` line 254);
  card `.../widgets/dashboard_sim_line_card.dart` - line 21;
  tier resolution `lib/features/sim_lines/data/models/sim_line_model.dart` - line 64
  (`effectiveTier`, `isPremiumPlan` line 73, `isPaidPlan` line 76).
- **How Achieved (Code Logic):** `SimLine.effectiveTier` is the single tier helper —
  **`plan_type` is authoritative, `protection_tier` may only widen, unknown → free.** The top header avatar displays the real-time detected country flag emoji via `GeoController` (calling `detect-country` IP detection on launch). Tapping the flag avatar opens a location info dialog displaying the detected country, VPN/offline troubleshooting tips, and a Refresh button to re-detect location and refresh the dashboard.
- **How Achieved (Database & Cloud VM):** `calculate_health_score(p_sim_line_id,p_status,
  p_last_topup_at)` (authenticated); `trg_scheduled_topup_health_sync()` keeps it fresh.
- **Pending / Missing Tasks:** `profiles.subscription_tier` is `'premium'` for **zero** accounts
  while lines are `plan_type='premium'`; any surviving UI gate keyed on the account tier is hidden
  from paying customers. Audit for stragglers.
- **Technical Improvements & Suggestions:** `trg_scheduled_topup_health_sync` is one of 3 functions
  with a **mutable `search_path`** (advisor WARN) — pin it.

### [12] Depletion forecasting (G1)
- **Code Reference:** card `lib/features/sim_lines/presentation/widgets/depletion_forecast_card.dart`
  - line 23; model `lib/features/sim_lines/data/models/usage_forecast_model.dart`;
  test `test/features/sim_lines/usage_forecast_test.dart`.
- **How Achieved (Code Logic):** Card badges the forecast **MEASURED** vs **ESTIMATE** from
  `method`/`confidence`; the schedule sheet prefills from `suggested_amount_usd` and the suggested
  cadence, saying which it is suggesting from.
- **How Achieved (Database & Cloud VM):** `sim_line_usage_forecast` (read-own + household, **no
  client write path**) and `esim_usage_samples` (deny-all). Functions `compute_usage_forecasts()`,
  `snapshot_esim_usage()`, `emit_forecast_depletion_alerts()`, `refresh_usage_forecasts()` →
  cron job 20 `20 2 * * *`. A **table, not a matview**, because Postgres has no RLS on matviews.
  Gaps below `FORECAST_MIN_CYCLE_DAYS` (3) are ignored — a sub-3-day gap is a retry, not a cadence.
- **Pending / Missing Tasks:**
  1. Every live forecast still reads `carrier_rule`; the `topup_history` path is proven but
     unexercised because the DB holds zero completed top-ups more than 3 days apart.
  2. Some `suggested_amount_usd` values are **below the carrier's `price_min_usd`** ($0.20 against
     a $0.25 Vodafone EG floor). G7 clamps up; anything else reading that column quotes an
     unbuyable price.
- **Technical Improvements & Suggestions:** Clamp inside `compute_usage_forecasts()` rather than at
  each consumer, and add a CHECK/assertion that the suggestion is purchasable.

### [13] Auto-rescue top-up — "SIM insurance" (G7)
- **Code Reference:** `lib/features/sim_lines/presentation/widgets/sim_insurance_card.dart`
  - line 28; test `test/features/sim_lines/line_rescue_policy_test.dart`.
- **How Achieved (Code Logic):** A per-line dollar ceiling. `max_usd = 0` means **not insured** and
  is the default and the fail-closed state — the cap *is* the permission.
- **How Achieved (Database & Cloud VM):** `sim_line_rescue_policy` (read-own; writes via
  `set_line_rescue_policy()`), `run_auto_rescue(p_dry_run)` → cron job 22 `50 * * * *`.
  Runs its **own two-phase clock**: writes the warning itself, then waits `RESCUE_GRACE_HOURS` (24).
  Spends by inserting a `refill_instant` execution that `route_topup_execution()` flips to
  `routing` — **no worker change was needed.**
  Config: `RESCUE_ENABLED=true`, `RESCUE_GRACE_HOURS=24`, `RESCUE_COOLDOWN_DAYS=20`,
  `RESCUE_MAX_PER_RUN=25`.
- **Pending / Missing Tasks:** `sim_line_rescue_policy` holds **1 row**; a real run today spends
  nothing. The last mile still depends on the Zendit **production** key. Omantel and STC Kuwait can
  never be rescued (`suggested_offer_id` NULL).
- **Technical Improvements & Suggestions:** This is the only automation that spends a user's money
  with no human in the loop — the cooldown check **must stay above** the warn phase (a rescue clears
  `last_warned_at` and the forecast does not refresh until 02:20, so the next hourly run re-warned
  a line already in cooldown).

### [14] Home-screen widget + iOS Live Activity
- **Code Reference:** `lib/features/home_widget/domain/widget_snapshot.dart` - line 1;
  publisher `lib/features/home_widget/data/home_widget_publisher.dart` - line 39 (`publish` line 54);
  Live Activity bridge `.../data/live_activity_service.dart` - line 30 (MethodChannel line 33);
  sync `.../presentation/home_widget_sync.dart`; pin button `.../live_activity_pin_button.dart`;
  test `test/features/home_widget/widget_snapshot_test.dart`.
- **How Achieved (Code Logic):** A serialisable `WidgetSnapshot` is written through the
  `home_widget` plugin to a shared container; iOS Live Activity is invoked over a MethodChannel.
- **How Achieved (Database & Cloud VM):** None — reads existing client state.
- **Pending / Missing Tasks:** **iOS half is unwired.** The Swift exists
  (`ios/KeepSimsWidget/`, `ios/Shared/KeepSimsActivityAttributes.swift`,
  `ios/Runner/LiveActivityBridge.swift`) but no Xcode target references it; App Group
  `group.com.keep_sims.widget` is not configured. Owner task (needs a Mac + Apple account).
  **None of that Swift has ever been compiled.**
- **Technical Improvements & Suggestions:** `KeepSimsActivityAttributes.swift` must be a member of
  **both** targets — two copies in two modules are two different types and the activity silently
  never appears.

---

## Group C — Money movement

### [15] Wallet, ledger, spend analytics
- **Code Reference:** `lib/features/wallet/repository/wallet_repository.dart` - line 17
  (`_walletTransact` 35, `getWallet` 50, `getTransactions` 106, `awaitPayPalCredit` 180,
  `deduct` 234, `payPlanFee` 292, `sendGift` 359);
  UI `lib/features/wallet/ui/wallet_screen.dart` - line 25 (chart painter line 1019).
- **How Achieved (Code Logic):** **The client never writes a balance.** Every mutation goes through
  the `wallet_transact` Edge Function or a SECURITY DEFINER RPC. `awaitPayPalCredit` (line 180)
  *waits for the balance to rise* rather than sleeping — the PayPal capture webhook and the
  wallet-credit webhook are different events, observed 11s apart.
- **How Achieved (Database & Cloud VM):** `wallets` (8 rows; SELECT own + UPDATE own auto-fund
  settings only), `wallet_transactions` (195 rows, SELECT own only — **no client INSERT**).
  Money RPCs are all `service_role`: `credit_wallet`, `credit_wallet_for_deposit`,
  `credit_wallet_for_refund`, `debit_wallet_for_topup`. Idempotency is on `reference_id`.
  Edge Function `supabase/functions/wallet_transact/index.ts` - line 20 holds the service-role key
  and re-authenticates the caller's JWT (line 33) before acting.
- **Pending / Missing Tasks:** Reconciliation job exists (`b2_drop_legacy_wallet_fns_add_
  reconciliation`) but there is no alert wired to a non-zero drift.
- **Technical Improvements & Suggestions:** `wallet_screen.dart` recomputes the analytics series on
  every rebuild inside `_buildSpendAnalyticsChart` (line 605); memoise per transaction-list identity.

### [16] PayPal deposit
- **Code Reference:** `lib/features/payments/presentation/screens/paypal_checkout_screen.dart`
  - line 27; test `test/features/payments/paypal_checkout_screen_test.dart`;
  deep-link suppression `lib/core/router/app_router.dart` - line 366
  (`FilteringRouteInformationProvider`, so a `payment-success` deep link cannot dismiss the
  active payment screen).
- **How Achieved (Code Logic):** Client requests an order, opens approval, then **polls the wallet**
  rather than trusting the return URL.
- **How Achieved (Database & Cloud VM):**
  `supabase/functions/create-paypal-order/index.ts` (**v7**, `verify_jwt:true`) prices server-side
  via `quote_plan_price` — **never a client-supplied amount**; since J8 it forwards
  `carrier_rule_id` so a Premium year can be priced for a line that does not exist yet
  (onboarding), and passes a KS422 refusal through to the client as a 400 with the server's own
  sentence instead of a blanket 500;
  `capture-paypal-order` (v3) — **marks an order captured without writing `plan_payments`**, which
  is why plan-rail callers must wait for the payment row rather than trust checkout's success;
  `paypal-webhook/index.ts` (`verify_jwt:false`) with real signature verification against PayPal's
  `/v1/notifications/verify-webhook-signature` (`verifySignature` line 45, call line 60) using
  `PAYPAL_WEBHOOK_ID`;
  `paypal-return` (`verify_jwt:false`, read-only, moves no money) — **exists in the repo but is
  NOT a deployed function** (checked 2026-08-08), so the return-URL change committed in `522e86b`
  must not be deployed before it is.
  `paypal_orders` (46 rows, SELECT own). `custom_id` carries `{u:user,k:kind,l:line}`.
- **Pending / Missing Tasks:**
  1. Still **sandbox** (`PAYPAL_API_BASE` defaults to `api-m.sandbox.paypal.com`).
  2. A sandbox client secret remains **in git history** — rotation is an owner task.
  3. `paypal_orders` has two overlapping SELECT policies (`paypal_orders_select_own` and
     `select_own_paypal_orders`) — duplicate, harmless, should be collapsed.
- **Technical Improvements & Suggestions:** Keep the "wait for balance, never sleep" contract in any
  refactor; sleeping instead of waiting once created a paid SIM line for free.
  **A deposit is credited at its GROSS captured value** (`paypal-webhook` → `credit_wallet_for_deposit`
  with `gross`), so the platform absorbs PayPal's cut on every top-up: $20 in costs the subscriber
  $20, credits $20 and nets $18.83, and at the `PAYPAL_MIN_DEPOSIT_USD` floor of $1.00 it is a
  guaranteed **-$0.52**. Defensible for real top-ups, which is why J8b did not change it — but it is
  the reason a plan must never be bought through a deposit.

### [17] Plan purchase / tier upgrade
- **Code Reference:** `lib/features/sim_lines/domain/plan_payment.dart`
  (`tryPlanFromWallet`, and `tryStandardFromWallet` as a thin wrapper over it); called from
  `.../screens/sim_line_form_screen.dart` (both tiers, with `commitSave()` in the same method);
  upgrade sheet `.../widgets/line_upgrade_sheet.dart` - line 22;
  tests `test/features/wallet/plan_fee_result_test.dart`,
  `test/features/wallet/pending_plan_fee_test.dart`,
  `test/features/sim_lines/refill_pricing_test.dart` (the two rails, pinned to the SQL).
- **How Achieved (Code Logic):** Quote → pay → *then* insert the line carrying the tier.
  **Both tiers bill wallet-first** (C3c for Standard, J8 for Premium) at the ungrossed net, because
  the wallet gateway takes no cut; a wallet debit is synchronous, so the entitlement exists before
  the line does. **When the balance cannot cover it the fallback is a `kind:'plan'` PayPal charge
  at the grossed-up price, never a wallet top-up** — a deposit is credited at its full captured
  value, so paying for a plan through one makes KeepSIMs absorb the gateway fee (J8b; the add-line
  screen did exactly that, and also opened checkout for the un-grossed figure while its button
  advertised the grossed-up one). A plan charge cannot be part-funded from an existing balance;
  the sheet says so and points at topping the wallet up instead.
  **`pay_plan_fee_from_wallet` refuses without raising**: only insufficient balance raises;
  `DEVICE_BLOCKED` / suspended / unauthorized come back as HTTP 200 `success:false`. The client
  must branch on the envelope, not on an exception.
  A queue failure after the line exists raises `PremiumRefillQueueException`, which all three
  purchase surfaces report as "line saved, payment recorded, refills pending" — never as a failed
  save, because the phone number is now taken and a retry can only collide with it.
- **How Achieved (Database & Cloud VM):** **`plan_price_net(p_plan,p_sim_line_id,p_carrier_rule_id)`
  (J8, service_role only) is the single price**, unrounded and before any gateway fee, mirroring
  `RefillPricing.premiumYearlyTotal`. Both rails derive from it:
  `quote_plan_price(p_sim_line_id,p_plan,p_gateway,p_carrier_rule_id)` grosses it up for the
  gateway, and `pay_plan_fee_from_wallet(p_reference_id,p_sim_line_id,p_device_id,p_plan,
  p_carrier_rule_id)` charges it as-is (the wallet gateway is 0% + $0.00). Both authenticated, both
  DROP+CREATE'd rather than overloaded (PGRST203), both re-listed in `f0_grant_matrix_tests.sql`.
  `plan_payments` (SELECT own) + `trg_fn_apply_plan_tier_from_payment()`.
  `has_paid_premium_entitlement()` gates `queue_premium_refill_executions()`.
  `premium_entitlement_grandfather` (service_role only, 1 row) is the exemption list.
  Proven by `supabase/tests/j8_plan_pricing_tests.sql` (11/11).
- **Pending / Missing Tasks:**
  0. **The entitlement test is existence-only, never amount** — a $2.50 Standard debit satisfies the
     Premium queue. Pre-existing (I2b); now finally *fixable*, because `plan_price_net` can price a
     line. Belongs with I2c below.
  1. **I2c is open: a client can still *label* a line premium without paying.**
     `trg_prevent_sim_line_plan_tampering` is BEFORE UPDATE only, and `authenticated` holds column
     INSERT on `plan_type` + `plan_expires_at`. The *spend* is closed (`has_paid_premium_
     entitlement()`); the label is not. Needs a **claim protocol**: on INSERT of a paid tier by a
     non-service-role caller, require an unclaimed `plan_payments` row (or `plan_fee_debit`
     transaction) for that user and tier inside a short window, and stamp it claimed.
  2. **`plan_payments` holds exactly 1 fixture row with `user_id` and `sim_line_id` both NULL** —
     no real premium purchase has ever been recorded, so the PayPal premium path is unproven end
     to end. A strict guard written blind would brick the only revenue path. **J8 found out why:**
     the add-line screen charged Premium as a wallet *deposit* and then never debited the plan, so
     every Premium save died on KS403 with the money sitting in the wallet; and the two surfaces
     that do pay with `kind='plan'` were quoted from `topup_validity_days`, billing 13 refills where
     the queue lays down 5 (Zain KSA: $21.99 charged against $10.36 displayed).
  3. **Household managers cannot buy or upgrade a plan** (I7 open): `quote_plan_price` and
     `pay_plan_fee_from_wallet` require `user_id = auth.uid()` while `request_instant_refill`
     accepts a manager. Fix = adopt `resolve_household_payer()` in both, and count the purchase
     against `monthly_cap_usd`.
- **Technical Improvements & Suggestions:** The historic "charged but no line" bug was
  **`builder: (context)` shadowing `State.context`**, so a post-pop `ScaffoldMessenger.of()` threw
  *between the debit and the insert*. `State.mounted` never guards another element's context —
  keep the debit and the insert in one uninterruptible block.

### [18] Gift / send wallet credit (G3)
- **Code Reference:** `lib/features/wallet/ui/gift_credit_sheet.dart` - line 24;
  repo `wallet_repository.dart` - line 359 (`sendGift`, RPC at line 389);
  result codes `lib/features/wallet/model/gift_transfer_model.dart` - line 38 (`KS429`);
  test `test/features/wallet/gift_credit_test.dart`.
- **How Achieved (Code Logic):** Recipient by email; typed result envelope rather than exceptions.
- **How Achieved (Database & Cloud VM):** `transfer_wallet_credit(p_recipient_email,p_amount,
  p_reference_id,p_note,p_device_id)` — authenticated, device-guarded, and a `security_logs` writer.
  Ledger type is deliberately **not** `deposit` (which is giftable-derivable = promo laundering)
  nor `refund` (which would decrement `total_spent` for a purchase that never happened).
- **Pending / Missing Tasks:** No notification template for "you received credit" beyond the
  generic `wallet_credit` category.
- **Technical Improvements & Suggestions:** Cap gifts per rolling window in `system_configs` rather
  than relying on the generic bucket.

### [19] Household / family shared wallet + spend limits (G6, H8)
- **Code Reference:** repo `lib/features/household/data/repositories/household_repository_impl.dart`
  - line 23 (`inviteMember` 115, `respondToInvite` 122, `leaveHousehold` 129, `removeMember` 136,
  `_rpc` 156); screen `lib/features/household/presentation/screens/household_screen.dart` - line 23;
  test `test/features/household/household_spend_test.dart`.
- **How Achieved (Code Logic):** **All member-side writes are RPCs**, never table writes, returning
  a `HouseholdActionResult` envelope. The controller no longer drops to `AsyncLoading` per mutation.
  Screen is fully localised (68 keys × 9 locales incl. 2 RTL).
- **How Achieved (Database & Cloud VM):** `household_members` (**0 rows**) with exactly 2 policies:
  owner ALL, member SELECT (matching `member_id` *or* `lower(auth.jwt()->>'email')`).
  RPCs `invite_household_member(text,text)`, `respond_to_household_invite(uuid,boolean)`,
  `leave_household(uuid)` — all three on the F0 allow-list.
  Spend: `household_spend_check()`, `household_spend_mtd()`, `household_spend_summary()`,
  `my_household_allowances()`, `resolve_household_payer()`.
  Backfill: AFTER INSERT trigger on `profiles` + `claim_pending_household_invites()` /
  `resolve_pending_household_invites()`.
- **Pending / Missing Tasks:**
  1. Invites are **in-app only** — Resend exists but there is no household email template.
  2. Nothing has been driven through the UI against two live sessions.
  3. Feature [17]'s manager-cannot-buy-a-plan asymmetry.
- **Technical Improvements & Suggestions:**
  - **A column GRANT is role-wide and cannot separate owner from member — both are `authenticated`.**
    That is why the member write policy was dropped rather than narrowed. Do not reintroduce a
    member UPDATE policy; escalating `role` first would satisfy the cap trigger.
  - **Any client-side `.delete()`/`.update()` whose result is not `.select()`-checked is a silent
    no-op waiting to happen** — PostgREST reports 0 affected rows as HTTP 200. This shipped twice
    (household "leave", admin Routing tab).

### [20] Multi-currency display (G11)
- **Code Reference:** `lib/core/fx/fx_provider.dart` - line 27 (`build` 29 calling
  `get_fx_display_context`, `setDisplayCurrency` 46); `lib/core/fx/money.dart` - line 1;
  context model `lib/core/fx/fx_context.dart`;
  test `test/features/fx/money_display_test.dart`.
- **How Achieved (Code Logic):** **There is no local→USD helper anywhere, deliberately.** The RPC
  returns a *rate*, never a converted amount. Charges, caps, wallet and ledger stay USD end to end;
  the local figure is always secondary, always `≈`, and never appears on a commit control
  ("Confirm & Pay" stays dollars, or the app and the card statement disagree).
- **How Achieved (Database & Cloud VM):** `fx_rates` (14 rows, authenticated SELECT of enabled rows).
  Rates are a **table, not a `system_configs` row** — `config_value` is untyped varchar and a
  fat-fingered `50.5`→`505` would multiply every displayed price by ten with nothing to catch it.
  Policy knobs only in config: `FX_DISPLAY_ENABLED=true`, `FX_MAX_AGE_HOURS=72`,
  `FX_MAX_MOVE_PERCENT=25`, `FX_LAST_REFRESH_AT`.
  Edge Function `refresh-fx-rates` (`verify_jwt:false`) ← `kick_fx_refresh()` ← cron job 23
  `10 3 * * *`. **Staleness is decided server-side and falls back to USD** — past
  `FX_MAX_AGE_HOURS` the RPC stops returning the currency at all. The feed may UPDATE currencies,
  never ADD them. **No SECURITY DEFINER anywhere in G11** — the boundary is a grant, which cannot
  rot into a no-op.
- **Pending / Missing Tasks:** Only **6 of ~88** `$x.xx` render sites are wired (wallet balance,
  eSIM list, eSIM checkout, PayPal deposit, both refill sheets). 0 of 8 users have selected a
  non-USD currency. Picker strings are hardcoded English.
- **Technical Improvements & Suggestions:** Wire the remaining ~82 sites via a single
  `Money.display()` call rather than per-screen formatting; the deleted
  `CurrencyFormatter.format()` used to relabel a USD amount without converting it and is exactly
  what a future session will reach for.

---

## Group D — Refill execution

### [21] Instant refill
- **Code Reference:** `sim_lines_repository_impl.dart` - line 647 (`requestInstantRefill`,
  RPC at line 663), line 833 (`fetchLineRefillOffers` → `list_refill_offers`, line 840),
  line 774 (legacy `fetchZenditOffers`);
  sheet `lib/features/sim_lines/presentation/widgets/manual_refill_bottom_sheet.dart` - line 19;
  test `test/features/sim_lines/refill_pricing_test.dart`.
- **How Achieved (Code Logic):** Offer list is provider-aware; the sheet quotes fee-inclusive
  landed cost. `error_formatter.dart` renders `COOLDOWN_ACTIVE`/`KS429` with a retry-after.
- **How Achieved (Database & Cloud VM):** `request_instant_refill(p_sim_line_id,p_offer_id,
  p_payment_gateway_code,p_amount_usd,p_device_id)` — authenticated, 5 args exactly (a 6th would
  overload → PGRST203). Inserts into `topup_executions` (17 rows; **SELECT-only for clients**),
  `route_topup_execution()` sets gateway + provider (`COALESCE(NEW.api_provider, carrier default)`
  — it used to *overwrite*, sending DTOne purchases to Zendit).
  **VM:** `servers/worker_instant_refill.js` - `executeRefill` line 111, `pollQueue` line 312,
  realtime listener line 349, poll 3s/200ms busy. **The wallet debit lives in the worker**, not in
  the RPC, and it only claims `API` rows.
- **Pending / Missing Tasks:**
  1. Zendit **production** key outstanding — every cached price is sandbox.
  2. 13 in-flight executions have been **stuck >24h**.
  3. Carriers with an empty offer cache cannot instant-refill at all.
- **Technical Improvements & Suggestions:** Landed cost = `base + gateway%(base) + app%(base) +
  msg_fee`, and the percentages do not vary by supplier, so **ordering by base cost IS ordering by
  landed cost** — do not duplicate the fee maths in a comparison path.

### [22] Scheduled top-ups (mini / custom / premium)
- **Code Reference:** `lib/features/scheduled_topups/repository/scheduled_topup_repository.dart`
  - line 16 (`getSchedules` 30, `createSchedule` 135, `updateSchedule` 236, `toggleSchedule` 315,
  `deleteSchedule` 348, `getExecutionsForLine` 375, paginated 448, `retryExecution` 488,
  `cancelExecution` 507, `rescheduleMiniRefill` 524, `resetMiniRefillToDefault` 542,
  `updateMiniRefillDates` 556);
  sheet `lib/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart` - line 29;
  premium config `lib/features/sim_lines/presentation/widgets/premium_refill_config_sheet.dart`
  - line 22;
  math `lib/features/scheduled_topups/domain/refill_schedule_math.dart` - line 5
  (`safetyAdjustedDelayDays` maps 90→85, 30→28, 14→13);
  history screen `.../screens/sim_line_executions_history_screen.dart` - line 16;
  test `test/features/scheduled_topups/refill_schedule_math_test.dart`.
- **How Achieved (Code Logic):** Chip labels are **not** the execution days — the snap must key on
  execution days, or a measured 28-day cycle lands on the 14-day chip and doubles the spend.
- **How Achieved (Database & Cloud VM):** `scheduled_topups` (6 rows; own ALL + household SELECT +
  household-manager ALL), `topup_executions` (SELECT only).
  RPCs: `reschedule_mini_refill`, `reset_mini_refill_to_default`, `update_mini_refill_dates`,
  `retry_topup_execution`, `cancel_topup_execution`, `queue_premium_refill_executions`.
  Triggers `trg_fn_sync_custom_refill_queue()`,
  `trg_fn_cancel_executions_on_schedule_delete()`, `trg_fn_log_topup_activity()`,
  `trg_fn_notify_topup_result()`.
  Reaper: `reap_stuck_executions()` → cron job 8 `*/5 * * * *`;
  `check_refill_pipeline_health()` → cron job 9 `30 * * * *`.
  **VM:** `servers/worker_auto_mini_refill.js` (line 111 `executeRefill`; **no wallet debit** —
  the yearly plan pre-paid) and `servers/worker_auto_custom_refill.js` (line 111).
- **Pending / Missing Tasks:** `queue_premium_refill_executions` horizon may only narrow — that fix
  is in, but the *label* hole ([17] item 1) is the remaining half of the same exploit.
- **Technical Improvements & Suggestions:** `worker_auto_mini_refill.js` and
  `worker_auto_custom_refill.js` are near-identical (309 lines each, same function names at the
  same offsets). Factor into one worker parameterised by execution type + debit policy; the current
  duplication is how a fix lands in one and not the other.

### [23] Multi-supplier routing, margin-aware selection, failover (I1, I5)
- **Code Reference (VM):** `servers/providers/zendit.js`, `dtone.js`, `ding.js`, `reloadly.js`;
  cache builder `servers/worker_offers_cache.js` - `catalogPairs` line 76 (reads
  `supplier_policy` line 78 and `carrier_provider_map` line 86), `refreshPair` line 112,
  `refreshAll` line 164; price validation `servers/offer_validation.js` (+ its own test file).
- **How Achieved (Code Logic):** Client is unaware of suppliers — it lists offers from
  `list_refill_offers()` and never names a provider.
- **How Achieved (Database & Cloud VM):**
  `carrier_provider_map` (72 rows) supersedes the single-valued `carriers.api_provider` for routing;
  `supplier_policy` (4 rows) carries `risk_premium_percent` and `flat_penalty_usd` which shift a
  **comparison cost only and are never charged**.
  Selection: `supplier_candidates()` (split out because a STABLE function may not write a TEMP
  table), `supplier_effective_cost()`, `choose_supplier_for_offer()`, `pick_best_refill_offer()`.
  Failover: `topup_executions.attempted_providers` + `trg_fn_supplier_failover()` →
  `retry_execution_at_next_supplier()`.
  Switching needs **both** `SUPPLIER_SWITCH_MIN_SAVING_USD` (0.05) **and** `_PERCENT` (2.0), so a
  cent never churns suppliers. `SUPPLIER_SELECTION_MODE = margin_aware`.
  `SUPPLIER_RETRY_SKIP_REASONS` is a pattern list so permanent failures never retry.
- **Pending / Missing Tasks (ordered — the order matters):**
  1. `SUPPLIER_RETRY_ENABLED = false`; ding + reloadly `is_globally_enabled = false`. Inert.
  2. Credentials into `servers/.env` **on the VM** (owner-gated): `DING_API_KEY`,
     `RELOADLY_CLIENT_ID`/`_SECRET`, DTOne **production** pair, Zendit **production** key.
  3. Populate `carriers.ding_carrier`/`ding_country`/`reloadly_operator_id` — NULL for all.
  4. Let `worker_offers_cache.js` fill `provider_offers_cache`.
  5. **Only then** flip `carrier_provider_map.is_enabled` and the config switches.
     *A supplier enabled with an empty cache ranks as infinitely cheap by absence.*
  6. **Both new adapters are UNVERIFIED against the live APIs** — normalisation is unit-smoke
     tested only. Diff a real response before trusting the numbers.
  7. DTOne carries a 5% risk premium purely because it is pre-production; drop to 0 on go-live.
- **Technical Improvements & Suggestions:**
  - Reloadly is the only supplier with **OAuth, not a static key**: token cached in-module, sandbox
    is a *different host*, and the token `audience` must match the host or every call 401s in a way
    that reads like a bad credential.
  - Reloadly models an **operator, not a product list** — one operator yields several cache rows
    with synthesised ids `rl_<operatorId>_<amount>`.
  - **Neither new adapter has a fallback catalogue, on purpose.** Inventing prices puts fictional
    money in front of a user.

### [24] Script / manual fulfilment gateway (I4)
- **Code Reference:** DB-only on the client side; admin surface lives in `keep_sims_admin`.
- **How Achieved (Database & Cloud VM):** `refill_scripts` (deny-all, 0 rows) with a
  `refill_scripts_no_instant` CHECK making `refill_instant` **unrepresentable**.
  `script_claim_next_execution(p_runner_id,p_max)` / `script_complete_execution(...)` (service_role).
  Gateway value is **`TASKER_SCRIPT`** — `carriers_fulfillment_gateway_check` has reserved it since
  day one; inventing `'SCRIPT'` fails the CHECK.
  `route_topup_execution()` falls back to API for instant *and* when no enabled script covers the
  type. `script_complete_execution` skips the debit for `refill_mini` (pre-paid).
  Manual path: `admin_complete_manual_refill()` / `admin_switch_gateway_to_manual()` now debit
  `amount` (fee-inclusive) under `exec_<id>` — previously a MANUAL row marked success charged nobody.
- **Pending / Missing Tasks:** **The runner does not exist.** Where it lives (the device that can
  dial USSD or drive the carrier app) is an owner decision and is the last piece before scripted
  recharges can run.
- **Technical Improvements & Suggestions:** Ship the runner as a thin polling client of
  `script_claim_next_execution` so it needs only the service-role key and no schema knowledge.

### [25] Offline refill — USSD / SMS / missed call / WhatsApp (C4, G9)
- **Code Reference:** screen `lib/features/offline_recharge/ui/offline_refill_screen.dart` - line 92
  (`_trigger` line 208, USSD section line 886);
  repo `lib/features/offline_recharge/repository/offline_refill_repository.dart` - line 9
  (`getSettings` 17, `saveSettings` 101, `getUssdSuggestions` 144, `queuePendingRefill` 252,
  `getPendingRefills` 283, `_reconcile` 302);
  test `test/features/offline_recharge/pending_offline_refill_test.dart`.
- **How Achieved (Code Logic):** The screen works with **no data**: endpoints and USSD codes are
  read from a local cache (`LocalCacheService`) warmed at line 106 of
  `sim_lines_repository_impl.dart`. Pending requests queue locally and reconcile on reconnect.
- **How Achieved (Database & Cloud VM):**
  Tables: `offline_refill_settings` (2 rows, own CRUD), `offline_refill_endpoints` (3 rows,
  authenticated SELECT of active rows), `carrier_ussd_suggestions` (8 rows),
  `offline_refill_events` (deny-all), `offline_command_log` (**deny-all — it holds raw sender
  phone numbers**), unique on `(provider, provider_msg_id)` so a provider retry **replays** the
  stored reply.
  Router: `handle_inbound_command(p_provider,p_provider_msg_id,p_sender_phone,p_channel,p_body,
  p_raw)` classifies → acts → logs → returns reply text, so SMS and WhatsApp cannot drift.
  `resolve_sender_user()` falls back to `sim_lines.phone_number`.
  `build_balance_reply()` masks numbers (`****1020`) and is gated on the same `is_enabled` consent.
  `ingest_offline_refill()` now only spends on REFILL or a bare amount.
  Edge Functions: `sms-webhook` (`x-twilio-signature`, line 113),
  `waba-webhook` (`x-hub-signature-256` HMAC, `hmacSha256Hex` line 84, compare line 139),
  `twilio-voice-webhook` (signature line 90).
  `sync_offline_endpoint_configs()` mirrors the primary row per channel into the matching
  `OFFLINE_*_NUMBER` config key **because the offline screen reads that key through an on-device
  cache** — moving the data must not break that.
- **Pending / Missing Tasks:**
  1. **`WABA_ACCESS_TOKEN` + `WABA_PHONE_NUMBER_ID` unset** → WhatsApp classifies correctly and
     spends nothing, but its reply is logged and dropped. SMS replies for free in the TwiML
     `<Message>`, so SMS needs no outbound credential.
  2. All three offline numbers are still **Oman placeholders**; `offline_refill_events` = 0 rows,
     `offline_command_log` = 0 rows. Nothing has ever come in.
  3. WhatsApp channel is globally disabled (`WHATSAPP_VPS_API_KEY` unset; 16 of 16 sends skipped).
- **Technical Improvements & Suggestions:** Unknown sender → **silence** is correct and must stay:
  a reply is an oracle for "is this phone a user?" and bills an SMS. The reply is deliberately thin
  because caller ID is spoofable.

---

## Group E — eSIM, comparison, travel

### [26] eSIM catalogue sync (J1, J3)
- **Code Reference (VM):** `servers/worker_esim_catalog.js` - `esimCatalogRow` line 28,
  `fetchEsimGoCatalogue` line 90, `refreshEsimCatalog` line 135, retirement sweep line 199.
  **Edge twin:** `supabase/functions/sync-esim-catalogue/index.ts` (v1, `verify_jwt:false`,
  shared-secret gated; note at line 112 explains why `verify_jwt` is not the gate — the anon key
  ships inside the APK).
- **How Achieved (Database & Cloud VM):** `esim_offers_cache` — **5,412 rows** (was 50).
  `kick_esim_catalogue_sync()` (service_role) + `admin_sync_esim_catalogue(text)` (audit-logged)
  + cron job 25 `40 3 * * *`.
  Facts that must not be re-derived: `perPage=200` works and `pageCount` is authoritative
  (28 pages); **unlimited arrives as `dataAmount: -1`, not 0** (3,894 of 5,412 rows), so
  `price_per_gb_usd` is **NULL, never 0**, and every sort uses `NULLS LAST`;
  eSIM Go sells unlimited in four speed tiers, so `speed_tier` is required or the throttled row
  wins every comparison; coverage is 1..106 countries per bundle → local ≤2 / regional 3–49 /
  global ≥50. Retirement sweep is gated on `complete AND rows>0` — either alone would retire the
  whole shop on a successful empty fetch.
- **Pending / Missing Tasks:** **`worker_esim_catalog.js` and `sync-esim-catalogue` write the same
  table with the same conflict key and must stay in step** — divergence is a silent data bug.
  Only Nepal has no bundle at all (and `ne` is a shipped locale).
- **Technical Improvements & Suggestions:** Retire the VM worker in favour of the Edge Function; two
  writers to one table with no leader election is the standing risk here.

### [27] eSIM purchase + fulfilment (C9)
- **Code Reference:** repo `lib/features/esim/data/repositories/esim_go_repository_impl.dart`
  - line 10 (`getPlans` 69, `validatePlanPurchase` 125, `requestPurchase` 130 → RPC line 132,
  `getUserEsims` 150, `getOrderHistory` 199, `watchOrder` 233);
  screens `lib/features/esim/presentation/screens/esim_screen.dart` - line 21,
  `esim_plans_screen.dart` - line 35;
  checkout `.../widgets/esim_checkout_sheet.dart` - line 11;
  status `.../widgets/esim_order_status_modal.dart` - line 7;
  device capability `lib/core/services/esim_capability_service.dart` - line 31 (MethodChannel).
- **How Achieved (Code Logic):** `getPlans()` now filters **server-side** with
  `.or('countries.cs.{XX},roaming_enabled.cs.{XX}')`. It previously selected the whole view and
  filtered in Dart — fine at 50 rows, but **PostgREST silently caps at 1000**, so it was returning
  an arbitrary cheapest-1000 slice and calling it the catalogue.
- **How Achieved (Database & Cloud VM):** `esim_orders` (SELECT own), `user_esims` (SELECT own),
  `esim_offers_cache` (deny-all — wholesale), view `esim_offers` (markup isolation),
  `esim_suppliers` (deny-all — holds markup override and secret names).
  `request_esim_purchase(p_offer_id,p_quantity,p_device_id)`. `reap_stale_esim_orders()` →
  cron job 13. GIN indexes on `countries` and `roaming_enabled` (J1).
  **VM:** `servers/worker_esim_fulfillment.js` — `callEsimGoOrderApi` line 68,
  `processPendingOrders` line 117, LPA assembly line 11, notification insert line 225,
  heartbeat `sendWorkerHeartbeat` line 102 (poll 10s; usage poll 4h).
- **Pending / Missing Tasks:**
  1. **The only order ever placed used a fixture reference — the live eSIM Go order contract is
     unverified.** `esim_orders` = 1 row, `user_esims` = 1 row.
  2. Destination picker is a hardcoded 50-country shortcut against a **220-country** catalogue.
  3. Second eSIM supplier is a business decision, still open.
- **Technical Improvements & Suggestions:** The fulfilment worker polls `data_remaining_mb` but
  keeps no history — feature [12] samples it nightly instead. If the worker ever writes history,
  remove the duplicate sampling rather than letting both run.

### [28] eSIM comparison + affiliate rail (J2, J2b)
- **Code Reference:** controller
  `lib/features/esim/presentation/controllers/esim_compare_controller.dart` - line 44
  (filters line 15, `refresh` line 54);
  card `lib/features/esim/presentation/widgets/compare_offer_card.dart` - line 19;
  filter sheet `.../widgets/compare_filter_sheet.dart` - line 22;
  repo `esim_go_repository_impl.dart` - line 17 (`compareOffers` → `compare_esim_offers`, line 24)
  and line 49 (`recordAffiliateClick` → RPC line 54);
  test `test/features/esim/compare_offer_test.dart` (14 cases).
- **How Achieved (Code Logic):** Two rails in one list — **resale** (we hold wholesale, take the
  money, owe an eSIM) and **affiliate** (no inventory, no money, no fulfilment; revenue is a
  reversible commission reported days later). Forcing the second through `esim_orders` would mean
  an order we cannot fill and a debit we must not take.
- **How Achieved (Database & Cloud VM):** Five tables — `affiliate_networks` (3),
  `affiliate_partners` (2), `affiliate_offers` (0), `affiliate_clicks` (0),
  `affiliate_conversions` (0) — **all deny-all to anon AND authenticated**.
  Reads reach the app only through `compare_esim_offers(...)` (10 args, authenticated), which
  leaves `commission_percent` behind — the same markup isolation that hides wholesale.
  `record_affiliate_click(p_offer_id,p_country_code,p_device_id)` builds the tracking URL
  **server-side**; `affiliate_clicks.id` **is** the token sent to the network as `subId1`, a random
  uuid, so the network learns "click 9f3c… converted" and only we can say who — **the user id never
  leaves the DB** and attribution cannot be forged from a device.
  `url_encode()` emits `%` per **byte** (Postgres has no urlencode; `%C3A9` for é is a different,
  broken URL). The whole 5,412-row comparison runs in **10.8 ms**.
- **Pending / Missing Tasks:**
  1. **Ships inert: `AFFILIATE_ENABLED=false` and both partners `is_active=false`** — proven by
     probe to yield 0 affiliate rows.
  2. **Billion Connect publishes no machine-readable product list** (`/Catalogs` returns 0 and
     401s for the read-only pair), so offers must be typed by hand. `affiliate_offers` = 0 rows.
  3. **Affilae/Orange is not wired** — `app.affilae.com/api/*` serves the SPA shell for every path,
     so no endpoint is verified; Orange is unapproved anyway and is seeded with a NULL tracking URL.
  4. Nothing has been driven through the compare UI against a live session.
- **Technical Improvements & Suggestions:**
  - A hand-typed partner price rots: `source='manual'` + `price_checked_at` +
    `AFFILIATE_PRICE_MAX_AGE_DAYS` (14) make the RPC return `price_is_stale`, and the card then
    shows the offer **with no number**. Keep that.
  - `record_affiliate_click` **refuses `NO_TRACKING_URL`** rather than opening a bare link —
    untracked traffic is worse than not showing the offer.

### [29] Affiliate conversion reader (J5)
- **Code Reference:** `supabase/functions/sync-affiliate-network/index.ts` (v1, service-role client
  at line 103).
- **How Achieved (Database & Cloud VM):** `kick_affiliate_sync(p_since_days)` (service_role) +
  `admin_sync_affiliate_network(int,text)` + cron job 26 `10 4 * * *` (after the 03:40 catalogue
  sync). Reads Impact's **`/Reports/mp_action_listing_fast`, not `/Actions`** — the report's column
  names were read from its own `/MetaData` endpoint, so they are verified.
  Impact enforces a hard **45-day max** between `ActionDateStart`/`End`, so the window is chunked.
  The nightly look-back is a deliberate 45-day **over-fetch** because Impact restates an action for
  weeks (PENDING→APPROVED→REVERSED); the upsert is idempotent on
  `(network_code, external_action_id)`. `Subid1` is accepted **only if it parses as a uuid**.
  An unrecognised status maps to **pending, never approved**.
  `affiliate_networks.is_active = true` for `impact` — that switch only controls whether we poll
  for our own commissions; the user-facing gates are still off.
- **Pending / Missing Tasks:**
  1. **The status/amount mapping is UNVERIFIED against a real conversion** — no live row has ever
     passed through `normaliseAction`. Every raw payload is kept in `affiliate_conversions.raw`;
     diff a real record before trusting the numbers.
  2. Impact's `/Ads` is **not** synced, so a coupon-code change (e.g. `NEWBC20` being replaced) is
     never noticed.
  3. Impact read-only + read-write credential pairs arrived in plaintext chat and are **in neither
     repo**. Only the **read-only** pair should ever be wired; both should be rotated.
- **Technical Improvements & Suggestions:** Add a `/Ads` reader on the same cron so coupon drift is
  a row change, not a customer complaint.

### [30] Price-drop / best-offer watch (G2)
- **Code Reference:** `lib/features/price_watch/presentation/providers/price_watch_provider.dart`
  - line 65 (`watchEsimCountry` 78, `setActive` 95, `setThreshold` 106, `remove` 119,
  `enablePromoConsent` 133);
  screen `lib/features/price_watch/presentation/screens/price_watch_screen.dart` - line 26;
  test `test/features/price_watch/offer_price_watch_test.dart`.
- **How Achieved (Database & Cloud VM):** `offer_price_watches` (3 rows, full own CRUD),
  `offer_price_history` (**6,195 rows, deny-all — it holds wholesale eSIM prices**), written by
  AFTER triggers `trg_fn_record_topup_price_history()` / `trg_fn_record_esim_price_history()`.
  `detect_offer_price_drops()`, `sync_auto_price_watches()`, `offer_watch_metrics()`,
  `prune_offer_price_history()`, `refresh_offer_price_watch()` → cron job 21 `40 2 * * *`.
  `last_best_usd` is **retail** for eSIM ($/GB), not wholesale.
- **Pending / Missing Tasks:** Alerts land in a category most users have muted — see [33].
- **Technical Improvements & Suggestions:** `offer_price_history` grows without bound at 6k rows
  already; confirm `prune_offer_price_history()` is actually scheduled (it is **not** in `cron.job`).

### [31] "Roam or eSIM?" calculator (G5)
- **Code Reference:** `lib/features/roam_calculator/presentation/providers/roam_quote_provider.dart`
  - line 17 (`RoamQuoteInput`; RPCs at lines 62 and 82);
  screen `.../screens/roam_calculator_screen.dart` - line 39;
  test `test/features/roam_calculator/roam_quote_test.dart`.
- **How Achieved (Database & Cloud VM):** `carrier_roaming_rates` (16 rows, authenticated SELECT;
  writes service_role only). `bundle_price_usd` is **GENERATED** from `local_price / fx_rate_to_usd`
  so no dollar figure is ever hand-typed. `destination_country_code = '*'` is a worldwide pass.
- **Pending / Missing Tasks:**
  1. **All 16 rows are unverified estimates** (`is_estimate=true`, `verified_at=NULL`) read off
     public carrier pages. The UI drops the caveat automatically once a row is verified.
  2. **44 of 50 carriers have no tariff at all**, including every carrier real users hold lines on
     (Vodafone EG, Etisalat EG, Zain KSA, Mobily, e&, Omantel, STC Kuwait).
  3. Zong's and Jazz's quoted figures are **+ tax** on their own pages; the seeded number does not
     add it.
  4. The comparative-claims wording is a business/legal call, not a technical one.
- **Technical Improvements & Suggestions:** Same stance as [10] and [28]: an unverified number is
  shown as an estimate or not at all.

### [32] Travel geo detection (C8)
- **Code Reference:** `lib/features/geo/controller/geo_controller.dart` - line 12
  (`checkCurrentLocationOnAppOpen` 63, `toggleTravelMode` 104, `freezeAllInternationalLines` 118,
  `resumeAllInternationalLines` 156);
  screen `lib/features/geo/ui/geo_screen.dart` - line 15;
  test `test/features/geo/geo_controller_test.dart`.
- **How Achieved (Database & Cloud VM):** Edge Function `detect-country` (`verify_jwt:true`,
  service-role client at line 91, D2 rate-limited 12/60min). Writes
  `profiles.home_country_code` / current country and a `welcome_home_ready` notification on arrival.
- **Pending / Missing Tasks:** `welcome_home_ready` has **0 rows ever** because the geo path never
  fires. The **"back home" wizard (I6) is blocked on the catalogue**: `provider_offers_cache` is
  *airtime only* — no `data_amount_mb`, `voice_minutes`, `sms_count` or `validity_days` on any row,
  so "buy a data + minutes bundle before you land" cannot be assembled.
- **Technical Improvements & Suggestions:** Extend `provider_offers_cache` with those four columns
  and teach `worker_offers_cache.js` to fill them; that single change unblocks I6 *and* the
  airtime side of the comparison engine.

---

## Group F — Engagement, messaging, support

### [33] Notifications — in-app inbox + multi-channel dispatch (C1, C2)
- **Code Reference:** repo
  `lib/features/notifications/data/repositories/notifications_repository_impl.dart` - line 10
  (`getNotifications` 25, `markAsRead` 42, `getAlertSettings` 88, `updateAlertSetting` 108,
  `getNotificationChannels` 169, `updateNotificationChannel` 225, `simulateNotification` 246);
  token registration `.../data/repositories/device_token_repository.dart` - line 43
  (OneSignal observer line 56, FCM refresh line 62, upsert line 111);
  inbox `.../screens/notifications_screen.dart` - line 16;
  settings `.../screens/notification_settings_screen.dart` - line 17;
  simulator `lib/features/settings/presentation/screens/alert_simulator_screen.dart` - line 11;
  init `lib/main.dart` - line 65 (OneSignal), line 70 (Firebase).
- **How Achieved (Code Logic):** OneSignal is primary and targets `external_id` = user id; FCM is a
  fallback token stored for debugging and direct send. **No `FirebaseMessaging` message handlers are
  registered deliberately** — OneSignal owns display.
- **How Achieved (Database & Cloud VM):** `notifications` (84 rows, full own CRUD),
  `alert_settings` (120 rows), `notification_channels` (29 rows),
  `notification_deliveries` (136 rows, SELECT own), `device_push_tokens` (3 rows, own CRUD),
  `notification_channel_catalog` (5 rows, authenticated SELECT).
  Fan-out: trigger `trg_fn_dispatch_notification()` → Edge Function
  `supabase/functions/dispatch-alert/index.ts` (552 lines, `verify_jwt:false`) with
  OneSignal (line 229), FCM HTTP v1 (service account line 104), Telegram (line 297),
  Resend (line 335), WhatsApp VPS (line 399).
  `process_due_notifications()` → cron job 7 `0 * * * *`;
  `schedule_delayed_notification()`; `trg_fn_notify_wallet_credit()`,
  `trg_fn_notify_topup_result()`, `trg_fn_notify_system_alert()`.
  `notification_channel_catalog.is_globally_enabled` gates the dispatcher **including the push
  safety net** — without that, disabling push is silently undone for every user whose other
  channels are off.
- **Pending / Missing Tasks (this is the largest operating gap in the product):**
  1. **Delivery reaches almost nobody**: 0 of 8 users have email enabled, 0 have Telegram,
     WhatsApp is globally disabled for a missing credential, push is ~13 delivered against 18
     failed with **3 device tokens for 8 users**.
  2. `'promo'` is the one opt-in category and **0 of 8 users have it on**.
  3. **The cheapest fix is not code** — default email to on for new accounts and backfill existing
     `alert_settings`.
  4. **Every server-authored notification body is English-only**, across every emitter.
- **Technical Improvements & Suggestions:** `admin_list_channels` had to match push deliveries with
  an escaped `LIKE key || E'\\_%'` because dispatch logs the *route* (`push_onesignal`/`push_fcm`),
  not the channel. Any new channel must follow that suffix convention or its counts read as zero.

### [34] Campaigns + in-app promo banner (I3)
- **Code Reference:** `lib/features/dashboard/presentation/widgets/promo_banner.dart` - line 20.
- **How Achieved (Database & Cloud VM):** `campaigns` + `campaign_deliveries` (both deny-all, 0 rows).
  RPCs `get_active_promos()`, `dismiss_promo(p_campaign_id)` (authenticated);
  `admin_list_campaigns()`, `admin_upsert_campaign()`, `admin_send_campaign()`,
  `campaign_audience(p_campaign_id)`.
  **Audience comes from `sim_lines`, not `profiles`** (only 2 distinct users hold lines at all).
  Push uses category `'promo'`, so `admin_send_campaign` returns `push_consented` to make the
  ceiling a fact rather than a mystery; **the in-app card deliberately does not require that
  consent.**
- **Pending / Missing Tasks:** 0 campaigns exist; the feature has never been exercised.
- **Technical Improvements & Suggestions:** None — the design already routes around [33]'s ceiling.

### [35] Referrals (C5)
- **Code Reference:** `lib/features/referrals/repository/referrals_repository.dart` - line 12
  (`getSummary` 18, `applyReferral` 100 → RPC line 109, `redeemPoints` 128 → RPC line 137);
  screen `lib/features/referrals/ui/referrals_screen.dart` - line 18.
- **How Achieved (Database & Cloud VM):** `referrals`, `referral_points`, `referral_redemptions`
  (SELECT own; **all 0 rows**), `retired_referral_codes` (deny-all, 8 rows).
  `apply_referral(p_referred_id,p_referral_code)`, `redeem_referral_points()`,
  trigger `trg_fn_award_referral_points()`.
- **Pending / Missing Tasks:** Never used in production. Redeemed credit lands as a distinct ledger
  type — verify it is not derivable into a giftable `deposit` before launch (same class of hole as
  [18]).
- **Technical Improvements & Suggestions:** Add a share-sheet entry point; the code is only reachable
  from Settings today.

### [36] Support tickets (C7)
- **Code Reference:** repo `lib/features/support/data/repositories/support_repository_impl.dart`
  - line 18 (`getTickets` 27, `createTicket` 75, `sendMessage` 118, `closeTicket` 146,
  `subscribeToMessages` 158, `uploadFileAttachment` 200,
  `exportLineActivityLogsAttachment` 238);
  screens `.../screens/support_tickets_list_screen.dart` - line 13,
  `create_ticket_screen.dart` - line 16, `ticket_detail_screen.dart` - line 16.
- **How Achieved (Code Logic):** Realtime subscription on `ticket_messages`; attachments go to
  Storage; a line's activity log can be exported into a ticket.
- **How Achieved (Database & Cloud VM):** `support_tickets` (**5 policies — two duplicated pairs**),
  `ticket_messages` (2 policies). Trigger
  `trg_fn_support_ticket_messages_process()`. Admin side: `admin_list_tickets()`,
  `admin_get_ticket()`, `admin_reply_ticket()`, `admin_set_ticket_status()` (H7a) with reply dedupe
  (H7d).
- **Pending / Missing Tasks:** 0 tickets, 0 messages — never exercised.
  **Collapse the duplicate policies** on `support_tickets` ("Users can create own support tickets"
  vs "Users can insert their own tickets"; same for SELECT) — overlapping permissive policies are
  how a later narrowing gets silently defeated.
- **Technical Improvements & Suggestions:** There are two `create_ticket_screen.dart` files
  (`presentation/screens/` and `presentation/ui/`) and two repository trees
  (`data/repositories/` and `repository/`). Delete the dead pair.

---

## Group G — Operations and platform

### [37] Admin control plane (Phase H) + outbound email (J7)
- **Code Reference:** separate repo `../keep_sims_admin` (`lib/core/admin/`, `lib/features/control/`,
  `affiliates_screen.dart` at `/partner-deals`, Email screen at `/email`). Windows desktop target.
- **How Achieved (Database & Cloud VM):** **47 `admin_*` SECURITY DEFINER RPCs**, every one
  `assert_admin()`-guarded and writing an `admin_audit_log` row (deny-all, 0 rows).
  **Zero new RLS policies on user-facing tables** — that is how the F-1..F-4 holes happened.
  Writes take a **jsonb patch**: absent key = unchanged, **unknown key is refused** (a
  defaulted-NULL parameter cannot distinguish "leave alone" from "set NULL", and adding a parameter
  later is PGRST203).
  Config registry: `system_configs` (92 rows) + `system_config_meta` (92 rows, deny-all).
  **A key with no meta row is UNSETTABLE (KS466)** — J6 backfilled 11 dead keys including
  `AFFILIATE_ENABLED` and `SUPPLIER_RETRY_ENABLED`.
  Email: `admin_emails` (deny-all, 0 rows), `admin_send_email(...)`, `admin_list_emails()`,
  `kick_admin_email()`, Edge Function `send-admin-email` v1 through Resend on the verified
  `keepsims.com` domain.
- **Pending / Missing Tasks:**
  1. **No email has ever been delivered through this path** — the RPC guards are proven (5/5
     refusals + queue shape, rolled back), but Resend has never accepted a message from it. The
     first real send is the test.
  2. **Nothing has been driven through either admin Flutter UI against a live power-user session** —
     screens are proven by `analyze` + a Windows build only.
  3. `ADMIN_EMAIL_ENABLED` ships **true**, a deliberate departure from the ship-it-off stance; the
     switch is a kill switch, not a rollout gate.
- **Technical Improvements & Suggestions:**
  - **`is_power_user()` reads `auth.jwt() -> 'app_metadata' ->> 'is_power_user'`, NOT
    `profiles.is_power_user`.** A test that sets only `sub` in `request.jwt.claims` yields KS460 and
    reads as a broken guard. Both admin accounts currently have column and JWT metadata in
    agreement; a drift there silently locks the admin app out.
  - The email body is **plain text and the Edge Function escapes it** — an admin form rendering
    arbitrary HTML from an SPF/DKIM-passing domain is a phishing kit if a power-user session leaks.
  - The Edge Function **claims the row** (`UPDATE … WHERE status='queued'`) before calling Resend,
    so a pg_net retry or double-click sends nothing twice. Any post-claim failure must land in a
    terminal state or the row sticks in `sending` forever.

### [38] Observability, health, heartbeats
- **Code Reference:** `lib/main.dart` - line 30 (`main`), line 48/55 (`FlutterError` +
  `PlatformDispatcher` → `Sentry.captureException`), line 113 (skips Sentry init when the DSN is
  unset, to avoid silent event drops), line 116 (`SentryFlutter.init`, `beforeSend` scrub at 121);
  analytics `lib/core/services/analytics_service.dart` - line 12 (consent check line 22).
- **How Achieved (Database & Cloud VM):** `system_alerts` (4 rows, power-user SELECT),
  `security_logs` (51 rows, **service_role only** since G10), `analytics_events` (own insert/select).
  Health: Edge Function `health` (`verify_jwt:false`) returns **503** when
  `system_configs.WORKER_ESIM_FULFILLMENT_HEARTBEAT` is >15 min stale;
  `check_worker_heartbeat_health()` → cron job 19 `*/10 * * * *`.
  UptimeRobot polls `https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/health` every 5 min.
- **Pending / Missing Tasks:**
  1. **No centralized log aggregation for Edge Functions or the VM** — Edge logs live only in the
     Supabase dashboard retention window; pm2 logs live only on the VM. No Logtail/Betterstack.
  2. Only the eSIM fulfilment worker writes a heartbeat; **the three refill workers and the offers
     cache worker do not**, so the health endpoint is blind to them.
  3. `analytics_events` = 0 rows.
- **Technical Improvements & Suggestions:** Give each pm2 process the same
  `WORKER_<NAME>_HEARTBEAT` contract and widen the `health` function to check all five. That is a
  ~20-line change and it is the difference between "the queue is stuck" and "nobody noticed for
  24h" (13 executions are currently stuck >24h).

### [39] Localisation (l10n)
- **Code Reference:** `lib/l10n/app_en.arb` + 8 locales (`ar bn es hi ne si tr ur`);
  generated `lib/l10n/app_localizations.dart` (4,921 lines); config `l10n.yaml`;
  locale state `lib/core/providers/locale_provider.dart`.
- **Pending / Missing Tasks:** **This is the largest accumulated debt in the product.**
  ~97 keys per locale were already untranslated before J; the 29 keys added by J1–J7 are
  English-only. Screens/strings known hardcoded: the currency picker, the schedule sheet, the
  forecast card, the G6/G7 surfaces, and **every server-authored notification body**.
- **Technical Improvements & Suggestions:** Add a CI check that fails when `app_en.arb` gains a key
  the other 8 files lack. Without it every phase adds to the gap silently.

### [40] Offline cache + sync queue (client resilience)
- **Code Reference:** `lib/core/services/local_cache_service.dart` - line 18
  (`writeString` 24, `writeJson` 38, `remove` 63);
  `lib/core/services/sync_queue_service.dart` - line 38 (`addToQueue` 58, `_persist` 70,
  `processQueue` 88);
  connectivity `lib/core/services/connectivity_service.dart`.
- **How Achieved (Code Logic):** Reads are cached to SharedPreferences and served on failure;
  writes queue as `SyncOperation` (line 8) and drain on reconnect.
- **Pending / Missing Tasks:** `processQueue` has no dead-letter path — a permanently failing
  operation retries forever on every reconnect.
- **Technical Improvements & Suggestions:** Add an attempt counter and surface exhausted operations
  in the UI; a silently retried *money* operation is the worst version of this bug.

---

# 2. SECURITY ARCHITECTURE & GAP ANALYSIS

## 2.1 Resolved Security Controls

**S-1 · Server-side money, no exceptions.**
`wallets` and `wallet_transactions` are SELECT-own with **no client INSERT/UPDATE grant**.
`credit_wallet`, `credit_wallet_for_deposit`, `credit_wallet_for_refund`, `debit_wallet_for_topup`
are **service_role only** (verified live in `information_schema.routine_privileges`). The four
former holes (F-1 mint, F-2 drain, F-3 anon purge, F-4 anon rate-limit reset) are closed.

**S-2 · A grant matrix that stays locked.**
`supabase/tests/f0_grant_matrix_tests.sql` asserts: T1 = zero anon-callable SECURITY DEFINER
functions; T4/T5 = the set of `authenticated`-callable definers equals the allow-list, exactly.
It has caught a **real regression in four consecutive phases** — most recently i7's
`admin_upsert_carrier_rule` shipping with PUBLIC + anon EXECUTE on a function that rewrites the
rules every schedule and price derives from (revoked in i8c; the probe now answers `42501`).

**S-3 · Prices are never client-supplied.**
`create-paypal-order` prices via `quote_plan_price` and the wallet debit via
`pay_plan_fee_from_wallet`; since J8 **both read one function, `plan_price_net`**, so the two rails
cannot quote different years for the same plan (before J8 they did: PayPal billed 13 refills where
the wallet-less client displayed 5). A carrier rule **id** may be supplied — a price may not.
Supplier-price validation lives in `servers/offer_validation.js` on the VM, not in the app;
`system_configs` + `payment_gateways` are the only sources of fee and rate truth.

**S-4 · Markup and wholesale isolation.**
`esim_offers_cache`, `esim_suppliers`, `offer_price_history`, `provider_offers_cache` writes and
`affiliate_offers.commission_percent` never reach a client. Reads go through views/RPCs that drop
the wholesale columns.

**S-5 · Verified webhook signatures on every inbound webhook.**
| Endpoint | Mechanism | File · line |
|---|---|---|
| `paypal-webhook` | PayPal `/v1/notifications/verify-webhook-signature` against `PAYPAL_WEBHOOK_ID` | `verifySignature` line 45, call line 60 |
| `waba-webhook` | HMAC-SHA256 of the raw body vs `x-hub-signature-256` | `hmacSha256Hex` line 84, compare line 139 |
| `sms-webhook` | Twilio `x-twilio-signature` | line 113 |
| `twilio-voice-webhook` | Twilio `x-twilio-signature` | line 90 |
| `sync-esim-catalogue` | Vault shared secret (403 on mismatch, proven by probe) | line 112 |

**S-6 · Deny-all-by-default for sensitive tables.**
24 public tables have RLS on with **zero policies** — every telemetry, audit, wholesale and PII
table: `offline_command_log` (raw sender phone numbers), `device_money_events`, `security_logs`,
`admin_audit_log`, `admin_emails`, `esim_usage_samples`, `offer_price_history`, all five
`affiliate_*` tables, `premium_entitlement_grandfather`, `refill_scripts`, `supplier_policy`,
`system_config_meta`, `esim_suppliers`, `carrier_provider_map`, `campaigns`, `campaign_deliveries`.

**S-7 · Admin writes are RPC-only and audited.**
47 `admin_*` definers, each `assert_admin()`-gated and each writing `admin_audit_log`.
`assert_admin()` **raises on a missing identity** (the fix for the "occurrence 5" dead guard where
`IF auth.uid() IS NOT NULL AND NOT is_power_user()` fell open for anon).
A **refused mutation leaves no audit row** — asserted by test.

**S-8 · Privilege escalation is actively trapped.**
`protect_is_power_user()` reverts the write *and* logs the **caller** as
`privilege_escalation_attempt`; 3 in an hour suspends them. The admin app's power-user toggle now
throws with that explanation; promotion stays service_role.

**S-9 · Device risk + App Check plumbing, observe-only.**
`guard_money_action()` sits **after all validation, immediately before money moves**, so offer and
sim-line probing is not counted as spending, and idempotent early returns (`already_sent`,
`already_paid`) are before it so retries do not double-log. Each RPC refuses in its own dialect
(KS451 raise / `{success:false,code:DEVICE_BLOCKED}` / HTTP 403).

**S-10 · Consent-gated telemetry.**
`AnalyticsService._hasConsent()` (line 22) checks a stored consent flag before any event;
`user_consents` is own-CRUD and `PrivacyScreen` is the single toggle.

**S-11 · Client-side sensitive-action guards.**
`DestructiveActionGuard` (typed confirmation, no grace window) and `PaymentAuthGuard` (biometric,
60s window, lifecycle-reset).

**S-12 · Restrictive policy hiding risk thresholds.**
`system_configs` has a RESTRICTIVE SELECT policy on `DEVICE_RISK_%`; an authenticated session sees
52 of 66 rows (verified).

**S-13 · TLS everywhere.** All client↔Supabase, Supabase↔VM and VM↔supplier traffic is HTTPS;
Supabase terminates TLS with no plaintext listener. Workers hold the service-role key in
`servers/.env`, which is **not in git**.

## 2.2 Identified Security Gaps & Missing Items

Ordered by exploitability × blast radius.

**G-1 · 🔴 A client can label a SIM line premium without paying (I2c, OPEN).**
`trg_prevent_sim_line_plan_tampering` is **BEFORE UPDATE only** and `authenticated` holds column
INSERT on `plan_type` and `plan_expires_at`. The *spend* path is closed
(`has_paid_premium_entitlement()` gates `queue_premium_refill_executions`), so this no longer
yields free airtime — but the entitlement label, and anything that later trusts it, is forgeable.
*Blocked on:* the claim protocol in [17], which cannot be written blind because
`plan_payments` holds one NULL fixture row and no real premium purchase has ever been recorded.
**J8 (2026-08-08) found the reason it never was**, and left one such forged-looking line in
production as evidence: `a716e5fb…` is `plan_type='premium'` with no payment behind it, created by
the very save that then failed — not by an attacker, but by the app itself. The entitlement test is
also **existence-only**: any `plan_fee_debit` in the plan's year satisfies it, so a $2.50 Standard
fee entitles a Premium queue. An amount test is now possible via `plan_price_net`.

**G-2 · 🔴 `authenticated` holds column INSERT on `sim_lines.created_at`.**
This is what defeated the I2 grandfather clause in one line. **Any future guard of the form
"rows created before date X are exempt" is dead on arrival.** The current exemption is the
service_role-only `premium_entitlement_grandfather` table precisely because of this.

**G-3 · 🟠 No IP-level rate limiting or WAF anywhere.**
`rate_limit_buckets` is keyed on user/line/action. PostgREST does not expose the client IP to SQL,
so an attacker with the (public) anon key can hammer any authenticated RPC from unlimited IPs at
the per-user limit each. There is no reverse proxy, no Cloudflare, no `pg_hba` restriction.

**G-4 · 🟠 Webhook signature checks fail OPEN when the secret is unset.**
`sms-webhook` line 119 and `twilio-voice-webhook` line 96 both log
`"TWILIO_AUTH_TOKEN unset — skipping signature check"` and **continue**. `TWILIO_AUTH_TOKEN` is
currently unset. The same shape applies to `WABA_APP_SECRET`. Today the blast radius is limited
(unknown senders get silence, and `handle_inbound_command` only spends on an explicit REFILL), but
the moment a real Twilio number is provisioned this is an unauthenticated path into a
money-adjacent RPC.

**G-5 · 🟠 2 ERROR advisors: SECURITY DEFINER views.**
`public.esim_offers` and `public.zendit_offers_cache` are SECURITY DEFINER views — they enforce the
*creator's* RLS, not the caller's. Both are deliberate markup-isolation shims and are documented
accepted exceptions, but a view is exactly the shape F0 spent three sessions deleting, and neither
has a test asserting which columns it drops.

**G-6 · 🟠 3 functions with a mutable `search_path`.**
`trg_scheduled_topup_health_sync`, `trg_fn_log_topup_activity`, `trg_fn_notify_topup_result` —
all three are triggers on the money path. A `search_path` hijack in a SECURITY DEFINER trigger is
the classic Postgres escalation.

**G-7 · 🟠 `pg_net` is installed in the `public` schema.**
Advisor WARN. `pg_net` is how the DB reaches Edge Functions; in `public` its functions are subject
to the same blanket-grant problem that produced F-1..F-6.

**G-8 · 🟠 Duplicate/overlapping RLS policies.**
`support_tickets` has 5 policies where 3 would do (two INSERT pairs, two SELECT pairs);
`paypal_orders` has two identical SELECT-own policies. Permissive policies OR together, so a later
attempt to narrow one is silently defeated by its twin.

**G-9 · 🟠 A raised refusal rolls back its own audit row.**
Proven, not theorised: blocking four money paths landed **3** `device_money_events` and **3**
`security_logs` rows, not 4. **There is no autonomous-transaction escape in this database** — no
dblink, no pg_background, and pg_net's queue is an ordinary table that rolls back too. The G10
workaround (`report_device_block()` re-run from the client's KS451 catch) covers the device path
only; **every other raising guard still loses its audit trail.**

**G-10 · 🟡 Leaked-password protection disabled.** Advisor WARN; dashboard-only toggle (owner).

**G-11 · 🟡 Credentials pasted in plaintext chat, not in either repo, not rotated.**
Impact read-only + read-write pairs, an Affilae JWT, the rotated eSIM Go token, the Ding key
(**marked Live**), Reloadly OAuth pair, DTOne pre-production pair. A PayPal sandbox client secret
**remains in git history**. All should be rotated once wiring is proven.

**G-12 · 🟡 No secret-at-rest encryption beyond Supabase Vault defaults.**
No column-level `pgcrypto`. `sim_lines.phone_number`, `offline_command_log.sender_phone` (deny-all
but plaintext), `user_esims` ICCID/LPA and `profiles.email` are stored in the clear. Acceptable
today; it is the control a payments/telecom audit will ask for first.

**G-13 · 🟡 81 authenticated-callable SECURITY DEFINER functions.**
Every one is on the F0 allow-list and asserted by T4, so this is *managed*, not unmanaged — but it
is a very large perimeter, and the allow-list is the only thing between it and an F-class incident.

**G-14 · 🟡 No CI. Nothing runs the tests.**
`.github/workflows` does not exist. `flutter test` (27 test files), `flutter analyze`, the 33 SQL
suites in `supabase/tests/` and `f0_grant_matrix_tests.sql` are all run **by hand, by an agent,
when someone remembers.** F0's grant matrix had been failing silently since G6 — four phases —
before anyone re-ran it.

**G-15 · 🟡 Two writers to `esim_offers_cache`.**
`servers/worker_esim_catalog.js` and the `sync-esim-catalogue` Edge Function write the same table
with the same conflict key and no leader election. Divergence is silent.

## 2.3 Hardening Roadmap

Ordered so each step is independently shippable and none blocks the next.

**Step 1 — Close the fail-open webhook checks (hours).**
In `sms-webhook` and `twilio-voice-webhook`, change the unset-secret branch from *warn and continue*
to **reject with 401**. Same for `WABA_APP_SECRET` in `waba-webhook`. A webhook whose secret is not
configured must not be reachable. *Gate the deploy on the owner having set `TWILIO_AUTH_TOKEN`, or
the endpoint goes dark — which is the correct failure mode.*

**Step 2 — Pin `search_path` on the 3 trigger functions (minutes).**
`ALTER FUNCTION … SET search_path = public, pg_temp;` for
`trg_scheduled_topup_health_sync`, `trg_fn_log_topup_activity`, `trg_fn_notify_topup_result`.
Clears 3 advisor WARNs and removes the one Postgres escalation shape still present.

**Step 3 — Collapse duplicate RLS policies (minutes).**
Drop `select_own_paypal_orders`, and the older of each duplicated pair on `support_tickets`.
Re-run `f0_grant_matrix_tests.sql` after.

**Step 4 — Put a reverse proxy / WAF in front of the API (days, owner-gated).**
Cloudflare (or an OCI/GCE nginx front) on a CNAME to the Supabase host, with:
per-IP rate limits on `/rest/v1/rpc/*`, a bot-fight rule, and an allow-list for the webhook paths
that must stay open. This is the only fix for **G-3**; nothing inside Postgres can see the IP.

**Step 5 — Durable audit for raising refusals (days).**
G-9 has no in-transaction fix. Two options, in preference order:
 (a) Convert remaining raising guards to the `guard_money_action` envelope pattern — the caller
 raises, the guard returns jsonb, and the audit write happens in the *caller's* pre-raise path.
 (b) Emit the audit row through `pg_net` to a `log-refusal` Edge Function — **note this still rolls
 back**, so it must be paired with (a); pg_net's queue is an ordinary table.

**Step 6 — Close the premium label hole (days).**
Implement the claim protocol from [17]. **Precondition: record one real premium purchase first**,
or a strict guard written against a schema with a single NULL fixture row will brick the only
revenue path. Revoke the column INSERT grant on `sim_lines.created_at` in the same migration
(fixes **G-2**).

**Step 7 — Stand up CI (days).**
GitHub Actions on `main` + PRs: `flutter analyze` (fail on any *error*, warn-count as a threshold),
`flutter test`, ARB key-parity check, and a nightly job that runs `f0_grant_matrix_tests.sql`
against production and fails loudly. **G-14 is the meta-gap: it is why four of the other gaps
survived four phases.**

**Step 8 — Rotate everything (owner, days).**
Supabase legacy JWT secret, Zendit sandbox key, PayPal sandbox client secret (in git history),
the Live Ding key, the Impact pairs, the eSIM Go token, the Affilae JWT. Then enable
HaveIBeenPwned leaked-password protection (**G-10**), and move `pg_net` out of `public` (**G-7**).

**Step 9 — Column-level pgcrypto for PII (weeks, do last).**
`pgcrypto` + a Vault-held key for `sim_lines.phone_number`, `offline_command_log.sender_phone`,
and `user_esims` ICCID/LPA, with `pgp_sym_decrypt` inside the existing SECURITY DEFINER read paths
so no client change is needed. Do this **after** Step 4 — an encrypted column behind an unrated
endpoint is theatre.

---

# 3. SYSTEM ARCHITECTURE & DATA FLOW

```
                              ┌──────────────────────────────────────────┐
                              │        FLUTTER CLIENT (Android)          │
                              │  lib/main.dart:30  ·  Riverpod + GoRouter│
                              │  anon key ships in APK = PUBLIC          │
                              └───────────────┬──────────────────────────┘
                                              │ HTTPS + user JWT
             ┌────────────────────────────────┼────────────────────────────────┐
             │                                │                                │
             ▼                                ▼                                ▼
   ┌───────────────────┐          ┌───────────────────────┐        ┌────────────────────┐
   │ PostgREST         │          │ EDGE FUNCTIONS (Deno) │        │ OneSignal / FCM    │
   │ /rest/v1          │          │ verify_jwt = true     │        │ (push SDK, direct) │
   │ • RLS-guarded     │          │  wallet_transact      │        └────────────────────┘
   │   SELECTs only    │          │  create-paypal-order  │
   │ • NO client write │          │  capture-paypal-order │
   │   to money tables │          │  detect-country       │
   └─────────┬─────────┘          │  delete_account       │
             │                    └───────────┬───────────┘
             │  /rest/v1/rpc                  │ service_role
             ▼                                ▼
   ┌──────────────────────────────────────────────────────────────────────────────┐
   │                     SUPABASE POSTGRES  (zwxswagokhgbuzrrbnhr)                 │
   │                                                                              │
   │  71 tables · 47 with RLS policies · 24 deny-all                              │
   │  ~180 SECURITY DEFINER fns · 81 authenticated-callable (F0 allow-list)       │
   │                                                                              │
   │  MONEY CORE                    ROUTING                    TELEMETRY          │
   │  wallets                       route_topup_execution()    device_money_events│
   │  wallet_transactions  ◄──────  carrier_provider_map       security_logs      │
   │  topup_executions              supplier_policy            admin_audit_log    │
   │  paypal_orders                 choose_supplier_for_offer()offer_price_history│
   │  plan_payments                                            offline_command_log│
   │                                                                              │
   │  ┌────────────────────── pg_cron · 15 active jobs ──────────────────────┐    │
   │  │ 7  0 * * *    process_due_notifications()                            │    │
   │  │ 8  */5 * * *  reap_stuck_executions()                                │    │
   │  │ 9  30 * * *   check_refill_pipeline_health()                         │    │
   │  │ 10 0 * * *    purge_deleted_accounts()                               │    │
   │  │ 11 30 * * *   check_rate_limit_health()                              │    │
   │  │ 12 0 3 * * *  prune_rate_limit_data()                                │    │
   │  │ 13 0 * * *    reap_stale_esim_orders()                               │    │
   │  │ 19 */10 * * * check_worker_heartbeat_health()                        │    │
   │  │ 20 20 2 * * * refresh_usage_forecasts()      ── forecast             │    │
   │  │ 21 40 2 * * * refresh_offer_price_watch()    ── price drops          │    │
   │  │ 22 50 * * * * run_auto_rescue()              ── SPENDS MONEY         │    │
   │  │ 23 10 3 * * * kick_fx_refresh()          ─┐                          │    │
   │  │ 24 55 2 * * * emit_carrier_self_service_advice()  (after job 20)     │    │
   │  │ 25 40 3 * * * kick_esim_catalogue_sync() ─┤ pg_net → Edge Fn         │    │
   │  │ 26 10 4 * * * kick_affiliate_sync(45)    ─┘ (after job 25)           │    │
   │  └──────────────────────────────────────────────────────────────────────┘    │
   │                                                                              │
   │  TRIGGER trg_fn_dispatch_notification()  ──pg_net──►  dispatch-alert          │
   │  Vault: esim_go_api_key, esim_catalogue_sync_secret, dispatch_shared_secret   │
   │         read via get_internal_secret()  (service_role only)                   │
   └───────┬────────────────────────────────────────────────┬─────────────────────┘
           │ realtime + service_role                        │ pg_net (verify_jwt=false)
           │                                                ▼
           │                              ┌──────────────────────────────────────┐
           │                              │ EDGE FUNCTIONS · verify_jwt = false  │
           │                              │ (own signature / shared-secret check)│
           │                              │  dispatch-alert    → OneSignal, FCM, │
           │                              │                      Resend, Telegram│
           │                              │  paypal-webhook    ← PayPal  [SIG ✓] │
           │                              │  paypal-return     ← browser         │
           │                              │  sms-webhook       ← Twilio  [SIG ⚠] │
           │                              │  twilio-voice-...  ← Twilio  [SIG ⚠] │
           │                              │  waba-webhook      ← Meta    [HMAC ✓]│
           │                              │  sync-esim-catalogue        [SECRET ✓]│
           │                              │  sync-affiliate-network → Impact API │
           │                              │  send-admin-email  → Resend          │
           │                              │  refresh-fx-rates  → open.er-api.com │
           │                              │  purge-accounts · health             │
           │                              └──────────────────────────────────────┘
           │
           ▼
   ┌──────────────────────────────────────────────────────────────────────────────┐
   │            CLOUD VM — GCE `keepsims-staging` (europe-west3-a)                 │
   │            /home/abdal/keepsims_backend · Node 22 · pm2 · OWNER-GATED         │
   │            servers/.env holds SUPABASE_SERVICE_ROLE_KEY + all supplier keys   │
   │                                                                              │
   │  queue-instant-refill      worker_instant_refill.js:111   DEBITS THE WALLET   │
   │  queue-auto-mini-refill    worker_auto_mini_refill.js:111 no debit (pre-paid) │
   │  queue-auto-custom-refill  worker_auto_custom_refill.js:111                   │
   │  worker-offers-cache       worker_offers_cache.js:164     every 10 min        │
   │  worker-esim-catalog       worker_esim_catalog.js:135     every 6h  ⚠ dual    │
   │  worker-esim-fulfillment   worker_esim_fulfillment.js:117 + HEARTBEAT:102     │
   │                                                                              │
   │  providers/ ── zendit.js · dtone.js · ding.js · reloadly.js                   │
   │  offer_validation.js  ← supplier price validation lives HERE, not in the app  │
   └───────────────┬──────────────────────────────────────────────────────────────┘
                   │ HTTPS
                   ▼
   ┌──────────────────────────────────────────────────────────────────────────────┐
   │ SUPPLIERS   Zendit (49/50 carriers) · DTOne (preprod) · Ding (off) ·          │
   │             Reloadly (off) · eSIM Go (5,412 bundles)                          │
   │ PAYMENTS    PayPal (SANDBOX)                                                  │
   │ MESSAGING   OneSignal · FCM · Resend · Telegram · WhatsApp VPS (disabled)     │
   │ INBOUND     Twilio SMS + Voice · Meta WhatsApp Business                       │
   │ AFFILIATE   Impact (read-only, active) · Affilae (unwired)                    │
   │ MONITORING  Sentry (client) · UptimeRobot → /functions/v1/health              │
   └──────────────────────────────────────────────────────────────────────────────┘

   ═══ CRITICAL PATH: instant refill (the money path) ═══════════════════════════
   Client  ──rpc request_instant_refill(…, p_device_id)──►  Postgres
             ├─ check_topup_rate_limit()          (10s cooldown, retry_of exempt)
             ├─ household_spend_check()           (if a manager is spending)
             ├─ guard_money_action()              (device risk — OBSERVE ONLY today)
             └─ INSERT topup_executions ──trigger route_topup_execution()──► routing
   VM worker_instant_refill.js  ──claims API row──►  debit_wallet_for_topup()
             ├─ success ──► supplier purchase (key = z_<execution_id>, idempotent)
             └─ failure ──► credit_wallet_for_refund()  +  trg_fn_supplier_failover()
                            └─ retry_execution_at_next_supplier()  [DISABLED: flag off]
   Reaper cron job 8 (*/5) sweeps anything stuck.   ⚠ 13 rows currently stuck >24h.
```

**Trust boundaries, explicitly:**
1. **Client → Postgres.** The anon key is public; the *user JWT* is the only credential. Every
   authenticated-callable SECURITY DEFINER function is on the perimeter and on the F0 allow-list.
2. **Postgres → Edge Functions.** `pg_net`, authenticated by a Vault shared secret, not by JWT.
3. **Edge Functions → Postgres.** Service-role key from Edge Fn secrets. **Owner-managed.**
4. **VM → Postgres.** Service-role key from `servers/.env`. **Owner-managed, not in git.**
5. **Suppliers → us.** Signature-verified webhooks only (see S-5 / G-4).

---

# 4. DEPLOYMENT & OPERATIONAL CHECKLIST

## 4.1 CI/CD — currently absent, this is the priority

There is **no `.github/workflows` directory**. Nothing is automated. Build this first:

- [ ] **`ci.yml` on push + PR to `main`:**
  - [ ] `flutter pub get` → `flutter analyze lib` — **fail on any error**; assert the warning count
        does not exceed the current baseline (101).
  - [ ] `flutter test` — 27 test files. Fail on any failure.
  - [ ] ARB key-parity: every key in `lib/l10n/app_en.arb` must exist in the other 8 locales.
        This is the only mechanical brake on gap **[39]**.
  - [ ] `dart format --output=none --set-exit-if-changed` on **changed files only** — the repo is
        not format-clean at HEAD and a blanket run buries every real diff.
- [ ] **`db-guard.yml`, nightly:** run `supabase/tests/f0_grant_matrix_tests.sql` against
      production as one `execute_sql` call and fail loudly. *This suite had been failing silently
      for four phases; it is the single highest-value job in this list.*
- [ ] **`release.yml` on tag:** `flutter build appbundle` with the upload keystore from Actions
      secrets, attach the AAB, run `tool/verify_release_bundle.dart`.
- [ ] **Migration discipline check:** assert every file in `supabase/migrations/` has a matching
      row in `schema_migrations` at the **same version as the filename**.
      *`apply_migration` has drifted 10+ times — stamping today's date, and more recently stamping
      nothing at all. Always re-stamp by hand, in a call containing nothing else, because MCP
      `execute_sql` wraps the whole batch in one transaction and a re-stamp beside a
      `BEGIN … ROLLBACK` proof is rolled back with it.*

**Manual deploy paths that must be documented in the repo (they are not):**
| Artifact | Command / route | Who |
|---|---|---|
| Migration | MCP `apply_migration` + hand re-stamp | agent |
| Edge Function | MCP `deploy_edge_function`; verify with `list_edge_functions` (**check `version` and `updated_at` — "deployed" has been claimed for code that only existed in git**) | agent |
| Edge Fn secret | Supabase dashboard | **owner** |
| VM worker | `git pull` in `/home/abdal/keepsims_backend` + `pm2 restart` | **owner** |
| `ecosystem.config.js` | Lists **5** apps; the VM runs **6–7** (adds `worker-offers-cache`, plus an unmanaged Baileys process). **Trust the VM's `pm2 list`, not this file.** | — |

## 4.2 Centralized logging

Current state: Sentry on the client only. Edge Function logs live in the Supabase dashboard
retention window; VM logs live in `pm2 logs` on a host nobody can reach from this workstation.

- [x] **Sentry** — `lib/main.dart` - line 116, with a `beforeSend` scrub at line 121 and an
      explicit skip at line 113 when the DSN is unset (so events are never silently dropped).
- [ ] **Sentry for Deno** in every Edge Function — today a `dispatch-alert` failure is invisible
      unless someone opens the dashboard.
- [ ] **Logtail / Betterstack (or GCE Cloud Logging) for the VM** — ship `pm2` stdout. Today a
      worker crash-loop is only detectable via the heartbeat, and only one of six workers writes one.
- [ ] **Extend the heartbeat contract to all workers.** `worker_esim_fulfillment.js` - line 102 is
      the template (`system_configs.WORKER_ESIM_FULFILLMENT_HEARTBEAT`); the health function returns
      503 at >15 min stale. Add `WORKER_<NAME>_HEARTBEAT` for the three refill workers and the
      offers-cache worker, and widen `health` to check all of them.
      *This is the ~20-line change that turns "13 executions stuck >24h" into a page.*
- [ ] **Route `system_alerts` somewhere a human reads.** `trg_fn_notify_system_alert()` exists and
      the table has 4 rows; there is no email or webhook destination configured.
- [ ] **Alert on advisor drift** — a weekly `get_advisors` diff. Baseline today:
      **2 ERROR / 86 WARN / 26 INFO**, every one a documented accepted exception.

## 4.3 Database backup verification

- [ ] **Confirm the Supabase plan's PITR window and daily backup retention.** Not verified in-repo;
      dashboard-only, owner task.
- [ ] **Perform one restore drill to a branch project.** A backup nobody has restored is a
      hypothesis. Use MCP `create_branch` → restore → run `f0_grant_matrix_tests.sql` against the
      branch → `delete_branch`.
- [ ] **Version the schema independently of Supabase.** Nightly `pg_dump --schema-only` committed
      to the repo would make schema drift a diff instead of an archaeology exercise.
- [ ] **Back up what is NOT in Postgres and NOT in git:**
      Edge Function secrets (dashboard-only), `servers/.env` on the VM, the Android upload keystore,
      `android/app/google-services.json` (untracked by owner choice — **a fresh clone will not
      build without it**). *Every one of these is a single-point-of-loss today.*
- [ ] **Verify Vault contents survive a restore** — `esim_go_api_key`,
      `esim_catalogue_sync_secret`, `dispatch_shared_secret`. If they do not, five features
      (catalogue sync, affiliate sync, admin email, FX refresh, alert dispatch) fail silently
      *after* the restore reports success.

## 4.4 Pre-launch gates (must be green before any store submission)

- [ ] PayPal moved from **sandbox** to live + webhook id re-registered + the sandbox secret in git
      history rotated.
- [ ] Zendit **production** key in `servers/.env` — until then every cached price is fictional and
      [13] auto-rescue will create an execution and fail at the supplier.
- [ ] One real eSIM Go order placed against the **live** contract (the only order ever placed used a
      fixture reference).
- [ ] One real premium purchase recorded in `plan_payments` (precondition for hardening Step 6).
- [ ] One real email delivered through `send-admin-email` (Resend has never accepted a message from
      this path).
- [ ] Notification defaults changed so email is on for new accounts + backfilled — **without this,
      every alerting feature in §1 ships to nobody.**
- [ ] All three `OFFLINE_*_NUMBER` config values replaced (still Oman placeholders).
- [ ] `TWILIO_AUTH_TOKEN` set → then hardening Step 1 deployed.
- [ ] Android registered for Firebase App Check; `device_risk_shadow_report(7)` reviewed **before**
      flipping `DEVICE_RISK_ENFORCE`.
- [ ] `keepsims.com/privacy` and the web deletion page hosted.
- [ ] HaveIBeenPwned leaked-password protection enabled.
- [ ] `execute_zendit_recharge` Edge Function deleted (410 tombstone; MCP has no delete tool —
      dashboard, owner).
- [ ] `supabase/migrations/20260819070000_j7_admin_outbound_email.sql` committed — it is the one
      piece of the schema that exists in the database and **not** in git.

---

### Appendix — live baselines as of 2026-08-05

| Metric | Value |
|---|---|
| `flutter test` | 291 / 291 |
| `flutter analyze lib` | 101 issues, 0 errors |
| `f0_grant_matrix_tests.sql` | T1 = 0 anon definers; T4/T5 = 72 allow-listed = 72 in DB |
| Supabase advisors | 2 ERROR · 86 WARN · 26 INFO |
| Public tables | 71 (47 with policies, 24 deny-all) |
| SECURITY DEFINER fns | ~180 (81 authenticated-callable) |
| Active cron jobs | 15 |
| Edge Function dirs in repo | 18 |
| Migrations | 122 (121 committed) |
| Users / wallets | 8 / 8 |
| Wallet transactions | 195 |
| eSIM bundles cached | 5,412 |
| Carriers / countries | 67 / 21 |
| Notifications / deliveries | 84 / 136 |
| Device push tokens | 3 (for 8 users) |
| Household members | 0 |
| Support tickets / referrals / campaigns / affiliate rows | 0 / 0 / 0 / 0 |

*Row counts are `pg_class` estimates. Re-verify anything you are about to act on.*
