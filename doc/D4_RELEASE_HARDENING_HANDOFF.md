# D4 — Release Hardening: Payment Flow Extraction, Secret Eviction & a Signable Build: Hand-off Brief

**Written 2026-07-25, repo @ `5d6966d` (D3), live DB `zwxswagokhgbuzrrbnhr`.**
Plan section: `doc/PRODUCTION_PLAN.md` § D4. D1, D2 and D3 are ✅ DONE and
committed. D4 is the **last gate before any build reaches a store**, and the
suggested session order says so explicitly: *"D4 before any release build
ships."*

The plan calls this session *"strip dev simulators from release builds
(finish)"*. **That framing is too small, and following it literally would ship a
broken product.** Three facts verified live in this repo today:

1. `paypal_refill_simulator_screen.dart` is **not a simulator**. It is the live
   payment UI for **all five** paid surfaces — onboarding, line form, upgrade
   sheet, manual refill, wallet top-up. The plan already knows this ("it IS the
   live payment flow used by 4 production screens" — it is 5).
2. That screen **hardcodes a PayPal client id *and client secret*** as Dart
   string literals (lines 64–68) and calls `api-m.sandbox.paypal.com` **directly
   from the device** to create *and capture* orders. A client secret compiled
   into an APK is extractable by anyone who downloads it. Today it is a sandbox
   credential; E1's plan is to swap in the live one **in the same screen**.
3. `android/app/build.gradle.kts:42` still carries the Flutter template default:
   `signingConfig = signingConfigs.getByName("debug")`. **Every release build
   this repo can currently produce is signed with the debug keystore** and
   cannot be uploaded to Play at all.

So D4 is really: **move payment authorization to the server, evict the secret,
make the release build signable and verifiably clean, and leave behind an
automated check so this class of defect cannot come back.** Renaming a file is
the smallest part of it.

One boundary to hold: **D4 makes going live possible; it does not go live.**
Swapping sandbox for production PayPal credentials, the real-money smoke test
and the Zendit cutover are **E1**. Do not pull them forward.

---

## Verified repo + DB state you inherit (checked live 2026-07-25, trust these)

- **Baselines re-measured today, independently of D3's session record.**
  `flutter analyze` → **0 errors, 162 issues** (29 warnings + 133 infos) —
  unchanged since D1. `flutter test` → **67/67**. a1 wallet **$35.86** (verified
  live). `account_deletions` 0 rows, `retired_referral_codes` 0, suspended
  profiles 0, orphaned (`user_id IS NULL`) wallets 0 — D3 left nothing behind.
  Working tree clean at `5d6966d`.

- **The payment surface, precisely.** `PaypalRefillSimulatorScreen` is imported
  and pushed from five production files:

  | Call site | Line | What it charges |
  |---|---|---|
  | `profile/.../onboarding_screen.dart` | 356 | premium yearly plan |
  | `sim_lines/.../sim_line_form_screen.dart` | 1369 | plan fee on new/changed paid line |
  | `sim_lines/.../line_upgrade_sheet.dart` | 374 | Standard/Premium upgrade |
  | `sim_lines/.../manual_refill_bottom_sheet.dart` | 109 | PayPal-funded instant refill (`kind: 'deposit'` — deliberate, see C3c) |
  | `wallet/ui/wallet_screen.dart` | 932 | wallet top-up |

  All five already gate on D1's `paymentAuthGuardProvider` before pushing —
  **keep that**; it is the one thing about this flow that is right.

- **What that screen actually does** (~1000 lines): mints a PayPal OAuth2 token
  client-side with `base64Encode('$_clientId:$_clientSecret')`, `POST`s
  `/v2/checkout/orders`, opens the approval URL, then **captures the order from
  the device**. It also carries a fake Braintree/Visa card mock (test PAN
  `4111…`, `sandbox-buyer@keepsims.com`, `api.sandbox.braintreegateway.com`) and
  an on-screen raw HTTP request/response log panel. B3's `custom_id {u,k,l}` and
  the `paymentKind` parameter from C3c live here too — **those are load-bearing,
  carry them across verbatim.**

- **The server half already exists and is good.** `paypal-webhook` **v8** is
  deployed, `verify_jwt` off, signature-verified against webhook id
  `5FA85715EA0979031` on the *"KeepSIMs us"* PayPal REST app, credits deposits
  via `credit_wallet_for_deposit` keyed `paypal_<capture_id>`, records plan
  payments in `plan_payments`, and carries `custom_id {u,k,l}` →
  `plan_payments.sim_line_id`. **You are not building payment settlement — it is
  built. You are building order *creation* server-side so the client never holds
  a credential.**

- **Only two things are `kDebugMode`-gated today**, and they are the two that
  matter least: `app_router.dart:278` (the `/settings/simulators` route →
  `AlertSimulatorScreen`) and `settings_screen.dart:313` (the menu entry, also
  requiring `isPowerUser`). `PaypalSimulatorScreen` (the *other* one, in
  `paypal_simulator_screen.dart`) is reachable only from `AlertSimulatorScreen`,
  so it tree-shakes with it. **`PaypalRefillSimulatorScreen` does not** — five
  unconditional production imports pin it into the release bundle, and the
  secret with it. `kDebugMode` tree-shaking is defeated by a single reachable
  import; that is exactly what happened here.

- **Release signing is the template default.**
  `android/app/build.gradle.kts:38-44` — `release { signingConfig =
  signingConfigs.getByName("debug") }`, TODO comment intact. There is no
  `key.properties`, no keystore, no `android/app/upload-keystore.jks`. Play
  rejects debug-signed uploads outright.

- **`google-services.json` is deliberately untracked** (C1b, owner's call — it
  holds the public-by-design Android API key). Consequence for D4: **a release
  build cannot be produced from a fresh clone or from CI** without the owner
  placing that file. Decide this now, because D4 is the session that first
  builds for real.

- **iOS has no `GoogleService-Info.plist`** (C1b), so `Firebase.initializeApp()`
  throws and is caught; FCM is inert on iOS by design. Not a D4 defect — just
  do not "fix" it by disabling the guard.

- **Housekeeping D2 flagged and D3 was asked to clear, still open** (verified):
  `android/build/reports/problems/problems-report.html` is **still tracked**,
  `android/build/` is **still absent from `.gitignore`**, and
  `android/gradle.properties:1` still pins
  `org.gradle.java.home=C:\Program Files\Android\Android Studio\jbr` — a
  machine-specific path that breaks any other developer's or CI's build.

- **Six loose dev scripts sit tracked at repo root**: `test_esim_api.dart`,
  `test_order_api.dart`, `test_gb.dart`, `test_supabase.dart`,
  `update_sim_card.dart`, `replace_tiers.dart`. They are **not** compiled into
  the app (outside `lib/`) and they read `ESIM_GO_API_KEY` from `.env` at
  runtime rather than embedding it — **no secret leak there**, do not over-react.
  But `test_order_api.dart` references `EsimGoApiClient`, which **C9a deleted**,
  so it no longer compiles, and three of them contribute the `avoid_print` infos
  at the tail of `flutter analyze`. Move them to `tool/` or delete them.

- **App `.env` / flutter_dotenv is the "no real secrets" surface by house rule**
  (see the secrets memory: it is extractable from the APK). `ESIM_GO_API_KEY`
  was evicted from the client in C9a for exactly this reason. **The PayPal
  client secret is the same class of defect, still open, and it is worse — it
  is not even in `.env`, it is a literal in a Dart file that ships.**

---

## Design decisions (professional judgment — follow unless the owner overrides)

### 1. The simulator is a symptom. Client-side PayPal is the defect.

Extracting the file into `lib/features/payments/` and gating the leftovers — the
plan's literal item 1 — leaves the client secret in the bundle and leaves order
capture on the device. Both are the actual problems. **Do the extraction *and*
the architecture move in the same session**, because doing the extraction alone
produces a clean-looking module that is still unshippable, and the next person
will believe D4 is finished.

### 2. Server-side order creation. The client never sees a credential.

Add one Edge Function, `create-paypal-order` (`verify_jwt` **on** — it is
client-called and must be authenticated, unlike the webhook):

- reads `PAYPAL_CLIENT_ID` / `PAYPAL_CLIENT_SECRET` from **Edge Function
  secrets** (already set there for B3 — reuse them, do not duplicate),
- **prices the order server-side.** Do not accept an amount from the client.
  This is settled house doctrine, not a preference: C3b-1's exploit was exactly
  "the client states a price", and C3b-2 closed it by moving pricing into
  `request_instant_refill` / `queue_premium_refill_executions`. A
  `create-paypal-order` that trusts a client amount reopens it on the PayPal
  rail. Take `{kind, sim_line_id?, plan?}` and compute the amount from
  `system_configs` / `carrier_rules` via the existing
  `PlanPayment`/`RefillPricing` server equivalents,
- stamps `custom_id {u,k,l}` itself (the webhook already depends on that shape),
- rate-limit it with D2's bucket (`paypal_order`, suggest **10 / 60 min**),
- returns only `{order_id, approve_url}`.

The client opens `approve_url` and then **waits for the webhook**, exactly as
B3's `awaitPayPalCredit` already does for deposits. **Delete client-side
capture entirely.** Capture belongs to the server; the webhook is already the
system of record and is signature-verified.

### 3. Sandbox vs live is a *server* setting, and it is E1's switch to flip.

Once the base URL lives in the Edge Function, going live is an Edge Function
secret change — no app release, no store review. That is the whole point, and it
matches the owner's standing requirement ("change it server-side, no app
update"). **Do not add a `PAYPAL_ENV` to `system_configs`** — that table is
authenticated-readable and is for non-secret business tunables; environment
selection travels with the credential, so it belongs in Edge Function secrets.

### 4. Delete the fake card. Do not gate it.

The Braintree/Visa mock (`4111…`, fabricated `bin`/`client_key`, the
`api.sandbox.braintreegateway.com` request strings) charges nothing and never
did. C3b-2 already established the precedent by **deleting** `simulateExecution`
and `executeMockTopup` rather than hiding them — that mock was live in release
and debited real wallets for fabricated successes. Dead payment UI that looks
real is a liability in a store review and in a support ticket. Delete it, and
delete the on-screen raw HTTP log panel with it (it renders `Authorization`
headers into the UI).

### 5. `kDebugMode` is necessary and insufficient. Ship a verifier.

Tree-shaking works only while **no** reachable production import pins the code —
one import defeats it silently, which is precisely this repo's current state.
The plan's item 2 asks for "a string search of the bundle"; do it, but make it
**a committed script, not a one-off**: `tool/verify_release_bundle.sh` (or
`.ps1`) that builds the release artifact and greps the extracted binary for a
deny-list — `sandbox.paypal.com`, `braintreegateway`, the client-secret literal,
`/settings/simulators`, `AlertSimulatorScreen`, `PaypalSimulatorScreen`,
`4111111111111111`, `sandbox-buyer@keepsims.com` — exiting non-zero on any hit.
An audit tells you about today; a script tells you about every build after it.
Note honestly in the record that Dart string constants survive obfuscation, so
this check is meaningful.

### 6. Fix release signing, because it is the real store blocker.

Create the `key.properties` + keystore wiring in `build.gradle.kts` (properties
file **gitignored**, keystore **never** committed), and have the build fall back
to an explicit, loud failure — not to the debug key — when the keystore is
absent. **Generating and safeguarding the upload keystore is an owner action**:
losing it means losing the ability to update the app. Prepare the exact
`keytool` command and the `key.properties` template, hand them over, and verify
the result with `apksigner verify --print-certs` / `bundletool`. Also enable
**Play App Signing** in the console (owner) so an upload-key loss is
recoverable.

### 7. Obfuscate and split debug symbols.

`flutter build appbundle --release --obfuscate
--split-debug-info=build/symbols/<version>`. This is standard for an app holding
wallets and payment flows, and it is close to free. Two consequences to write
down: **keep the symbol directory per released version** (Crashlytics in D5
needs it to symbolicate, and it cannot be regenerated later), and obfuscation
does **not** hide string literals — so §5's verifier stays load-bearing and §2's
secret eviction is the real fix, not obfuscation.

### 8. Make secret leakage impossible to reintroduce.

The systemic fix is a scan, not a memo. Add a repo secret scan (gitleaks or a
small regex script) to the same `tool/` entry point, covering `lib/`, `android/`,
`ios/`, `supabase/functions/` and the tracked root scripts. Run it in the
session and record the result. **The PayPal secret is already in git history —
scanning HEAD will not remove it. Rotating that sandbox credential in the PayPal
developer dashboard is an owner action; add it to the A2 rotation list, which is
still outstanding.**

### 9. Build an **AAB**, not an APK.

Play requires Android App Bundles. The plan's item 2 says
`flutter build apk --release`; use `flutter build appbundle --release` as the
gate and keep `--debug` APK for the fast loop. Verify with `bundletool
build-apks --mode=universal` and scan the universal APK in §5 (an AAB is a
container; grepping it directly is not equivalent).

### 10. Keep D5's and E1's work out of this session.

Crashlytics/Sentry wiring, PM2 persistence and uptime checks are **D5**. Live
PayPal credentials, the real-money smoke test, Zendit production cutover and
Baileys retirement are **E1**. D4's success condition is: *a signed, obfuscated,
verifiably clean release bundle whose payment flow holds no credentials* — with
the live/sandbox switch left in the server's hands for E1 to flip.

---

## Scope checklist

1. **New Edge Function `create-paypal-order`** (`verify_jwt` on): server-side
   pricing, PayPal credentials from Edge Function secrets, `custom_id {u,k,l}`,
   D2 rate limit `paypal_order`, returns `{order_id, approve_url}`. Deploy with
   `import_map_path: "deno.json"` and a `deno.json` (`{}`) in `files` — the
   house MCP gotcha. Migration `20260730000000_d4_release_hardening.sql` for the
   `RATE_LIMIT_PAYPAL_ORDER` seed **only if** a migration is otherwise needed;
   do not create one for a single config row if you can seed it in the same
   commit's SQL and save the file.
2. **New module `lib/features/payments/`**: `PayPalCheckoutScreen` (real flow —
   call the Edge Function, open the approval URL, await the webhook via B3's
   existing pattern), preserving `paymentKind`, `custom_id`, the D1
   `paymentAuthGuardProvider` gate at all five call sites, and C3c's
   wallet-first / PayPal-fallback behaviour. Repoint all five imports.
3. **Delete**: `paypal_refill_simulator_screen.dart` (after extraction), the
   fake-card mock, the raw HTTP log panel, and the hardcoded credentials. Keep
   `alert_simulator_screen.dart` + `paypal_simulator_screen.dart` behind the
   existing `kDebugMode` route, or delete them too if nothing else uses them —
   state which you chose and why.
4. **Release signing**: `key.properties` wiring in `android/app/build.gradle.kts`
   with a loud failure when absent; `key.properties`, `*.jks`, `*.keystore`,
   `android/build/` and `build/symbols/` added to `.gitignore`; untrack
   `android/build/reports/problems/problems-report.html`; make
   `org.gradle.java.home` non-machine-specific (drop it, or move it to a
   gitignored `local.properties`). Hand the owner the `keytool` command and the
   `key.properties` template.
5. **`tool/verify_release_bundle`** script (deny-list scan, non-zero exit) +
   secret scan over the tracked tree. Run both; paste the output into the record.
6. **Root dev scripts**: move to `tool/` or delete; fix or delete
   `test_order_api.dart`, which no longer compiles since C9a removed
   `EsimGoApiClient`.
7. **Tests**: Dart tests for the new payments module (pricing request shape,
   webhook-await state machine, the guard gate). **All 67 existing Flutter tests
   stay green.** Re-run the SQL suites that touch the money path —
   `c3c_plan_billing_tests.sql`, `c3b2_lockdown_tests.sql`, `b4_money_path_tests.sql`
   — and **`c3_instant_recharge_tests.sql`, which is currently failing** (see
   D3 review note 9; fix it in the D3b commit, then confirm green here).
8. **Gates**: `flutter analyze` 0 errors, info baseline **162**; `flutter test`
   ≥ 67; `flutter build appbundle --release --obfuscate --split-debug-info=…`
   succeeds; verifier script exits 0; MCP `get_advisors` 0 net-new; **a1 wallet
   $35.86 unchanged** — D4 must move no money at all.
9. Update `doc/PRODUCTION_PLAN.md` § D4 with the implementation record in house
   style (deviations included), flip to ✅ DONE, and update the memory status
   file. One commit, `feat(release): D4 payment extraction & release hardening`,
   pushed to `origin/main`.

---

## Confirm with owner at session start (non-blocking — proceed with defaults)

1. **Move PayPal order creation server-side** (client keeps no credentials);
   sandbox↔live becomes an Edge Function secret flipped in E1. (default: yes)
2. **Delete the fake-card / Braintree mock** rather than gate it. (default: yes)
3. **Owner generates the upload keystore** and enables Play App Signing; agent
   supplies the exact commands and the gradle wiring. (default: yes)
4. **Obfuscated release builds**, symbols retained per version for D5's crash
   reporting. (default: yes)
5. **Rotate the sandbox PayPal client secret** that is currently in the app and
   in git history — folds into the outstanding A2 rotation. (default: yes)
6. `google-services.json`: commit it (public-by-design key, unblocks CI and
   fresh clones) or keep it out and accept a manual step before every release
   build? (default: owner's existing choice stands — keep it out, and the record
   names it as a required manual step)

---

## Session conventions (house rules — do not deviate)

- Migration file (if any) saved locally the same session, round manual
  timestamp, `timestamp_phase_description`, applied with **`apply_migration`**
  so it registers in `supabase_migrations.schema_migrations` — see D3 review
  note 11, this drifted again.
- SQL tests run live via MCP inside `BEGIN..ROLLBACK` — never leave rows behind.
- ARB keys in all 9 locales (en, ar, es, hi, tr, bn, ne, si, ur); use the Edit
  tool for non-Latin files (PowerShell 5.1 mangles UTF-8); no blanket
  `dart format` — the repo is not format-clean at HEAD.
- **No new pub or npm dependency.** In particular do **not** add a PayPal SDK —
  the approval-URL + webhook flow needs none, and B3 already proved it.
- No wallet movement: **$35.86** at start and end.
- Never commit a keystore, `key.properties`, or a symbols directory.
- One commit, `feat(release): …`, pushed to `origin/main`.

---

## D3 review notes — ship these as a **D3b** commit *before* D4's main work

D3 delivered the right architecture — a real state machine, the CASCADE→SET NULL
migration done at the cheap moment (8 users, 165 ledger rows), a drain gate that
respects in-flight `routing` executions, cron jobs **actually scheduled** this
time, `support_attachments` locked down, and the full set of store artifacts.
The `apply_referral` rewrite (return a typed `KS429` instead of raising) is
exactly the right fix for D2's enumeration hole. Baselines hold: analyze 162 / 0
errors, wallet $35.86, no rows left behind.

But **the deletion pipeline cannot currently finish, and the session's own
headline threat model is unaddressed.** Seventeen items, verified live against
`zwxswagokhgbuzrrbnhr` on 2026-07-25. The first six are the D3b commit; the rest
can ride along or be scheduled.

1. **The purge never completes — `purge-accounts` is deployed with
   `verify_jwt: true`.** `purge_deleted_accounts()` calls it through
   `net.http_post` with only `Content-Type` and `x-keep-sims-secret` — **no
   `Authorization` header**. The platform rejects with 401 *before the function
   body runs*, so `auth.admin.deleteUser()` never executes: accounts stall at
   `purged` forever and the auth identity survives. The house pattern is
   `dispatch-alert` — `verify_jwt` **off**, secret checked in-function. This also
   means the `auth_deleted` state has never been exercised end-to-end.
2. **`purge-accounts`' secret check fails open.**
   `if (expectedSecret && incomingSecret !== expectedSecret)` — a null/empty
   Vault read (`get_internal_secret` missing, renamed, or erroring) sets
   `expectedSecret = ""`, which is falsy, so **the check is skipped entirely**.
   Combined with fixing item 1 (turning `verify_jwt` off), that becomes an
   **unauthenticated `deleteUser(<any user_id>)` endpoint**. Invert it: absent or
   mismatched secret → 401, always. And the function deletes whatever `user_id`
   the body names **without checking `account_deletions.status = 'purged'`** —
   add that guard so a replayed or forged body cannot delete an account that
   never requested it.
3. **The C5 referral-points fix is defeated by D3's own purge.** The FK to
   `auth.users` was changed to `SET NULL`, but the live constraint
   `referral_points_sim_line_id_fkey` is **`REFERENCES sim_lines(id) ON DELETE
   CASCADE`**, and `purge_deleted_accounts()` runs
   `DELETE FROM public.sim_lines WHERE user_id = rec.user_id`. So when a referred
   friend is purged, their lines go, the points rows cascade with them, and the
   **referrer's balance still goes negative** — the exact bug the session was
   scoped to fix. The D3 test asserted on `auth.users` deletion, not on the purge
   path, which is why it passed. Fix `sim_line_id` to `SET NULL` (adjusting the
   `UNIQUE(sim_line_id)` guard for nulls) or null it explicitly before the
   delete, and **assert it by running the real purge, not a cascade.**
4. **`p_forfeit_dust` is a client-controlled bypass of the entire wallet
   policy.** The check is
   `IF v_balance >= v_dust_limit AND NOT p_forfeit_dust THEN <block>` — so
   passing `forfeit_dust: true` lets **any** balance through, and
   `delete_account/index.ts:44` forwards `body.forfeit_dust` straight from the
   request. A user (or a stolen session) can delete an account holding $500 and
   the money is simply orphaned. The brief's tier-2 rule is *"above dust,
   deletion **blocks**"* — that must not be waivable by a request flag;
   `p_forfeit_dust` may only mean "I acknowledge losing the sub-$1 dust". The
   spend-or-payout C7 ticket path was never built either.
5. **The wallet is never settled.** At purge, `wallets.user_id` is set to NULL
   and the balance is left standing with **no ledger entry** — an orphaned
   liability with no journal line, in a system whose whole B-phase was spent
   making the ledger reconcile. Write a `wallet_forfeit` / `wallet_settlement`
   `wallet_transactions` row zeroing the balance so
   `wallet_reconciliation` still balances after a purge.
6. **No re-authentication anywhere, and deletion is the one destructive action
   not behind D1's guard.** `delete_account` calls `auth.getUser()` and nothing
   more — no `auth_time` / `last_sign_in_at` freshness check. The client does no
   password re-entry, no OTP, and does **not** call `paymentAuthGuardProvider`,
   even though all nine payment sites do. A $2.50 plan fee is gated; erasing the
   account is not. This was §4 of the brief and the session's stated top threat
   (ATO), and it is untouched. **Also: sessions are never revoked.**
   `request_account_deletion` sets `is_suspended` and the client calls a local
   `signOut()`; a stolen JWT on another device stays valid for its full lifetime.
   Add a global sign-out via the admin API on freeze.
7. **The freeze is real for tables and cosmetic for money.** `is_suspended` is
   enforced by ~45 RLS policies (verified) — genuinely good. But
   `request_esim_purchase`, `request_instant_refill`, `pay_plan_fee_from_wallet`
   and `redeem_referral_points` are **SECURITY DEFINER and bypass RLS**, and
   none of them reference `is_suspended` (verified via `pg_proc.prosrc`). A
   frozen, pending-deletion account can still spend real supplier money over
   PostgREST for the whole 14-day grace. Same class as C8's cosmetic-freeze bug.
   Add a suspension check to the money RPCs.
8. **`c3_instant_recharge_tests.sql` is now failing — reproduced live.** D3's
   `check_topup_rate_limit()` rewrite changed the raised message to
   `COOLDOWN_ACTIVE: Please wait 10 seconds…`; the suite asserts
   `SQLERRM LIKE '%Rate limit exceeded%'` at line 79, so the handler re-raises
   and the suite aborts at assertion 5. A live probe returned exactly
   `message=[COOLDOWN_ACTIVE: Please wait 10 seconds between refill requests for
   line …] c3_assertion_matches=[f]`. The D3 brief required re-running
   `c3`/`c3b2`/`c4`/`c5`; the session record shows only `d2` was re-run.
   Additionally, nothing maps `COOLDOWN_ACTIVE` in `RateLimitErrorFormatter`, so
   that raw English sentence still reaches a 9-locale user's screen — the exact
   presentation defect D2 was asked to fix.
9. **`instant_refill` still double-consumes its bucket.** D2 review note 3 had
   two halves; D3 fixed only the service_role half. When `auth.uid()` is
   non-null, `request_instant_refill` consumes a token **and** its INSERT fires
   the trigger, which consumes another. The configured 10/hr is still really
   5/hr.
10. **Migration/live drift is back — the C3b-2 failure the repo already paid a
    cleanup commit to close.** Two instances: (a) `20260729000000_d3_account_deletion.sql`
    is saved locally but **absent from `supabase_migrations.schema_migrations`**
    (newest registered row is still D2's) — it was applied with `execute_sql`,
    not `apply_migration`; (b) the corrected `apply_referral` exists **only in
    the live database** — D2b's commit contains no `.sql` at all, and the local
    `20260728000000_d2_rate_limiting.sql:588` still holds the old raising
    `enforce_rate_limit` version, so **re-running that file silently reverts the
    security fix**. Capture both in a real migration.
11. **Consent is still local-only, and the server write can never succeed.**
    `toggleTrackingConsent` upserts `alert_settings` with
    `category = 'analytics_consent'`; the live `alert_settings_category_check`
    permits only 14 categories and that is not one, so **every write violates the
    CHECK** and is swallowed by `catch (_)`. Consent remains a
    `SharedPreferences` bool. It also miscategorises the concept — that table is
    C2's *notification category* table, and its naming is settled canon. Give
    consent its own column or table, default off, `updated_at` as the consent
    timestamp (the C2 `promo` pattern, not the C2 `promo` *table*).
12. **`export_user_data()` is incomplete and exports another person's id.**
    Missing from the brief's coverage list: `ticket_messages` (tickets are
    exported without their messages), `line_activity_log`,
    `offline_refill_settings` + `offline_refill_events`, `household_members`,
    `notification_deliveries`, `referrals`. And `referral_points` rows are
    emitted with raw `referred_user_id` UUIDs — §6 required redacting the
    counterparty to a stable opaque id.
13. **The anti-abuse controls are inert.** `retired_referral_codes` is written at
    purge but **read by nothing** — no generation path excludes retired codes
    (§11). `email_hash` is stored but never consulted, so the re-registration
    bonus window (§10) does not exist. Either wire them or drop them and say so;
    a tombstone table nobody reads is worse than none.
14. **There is no cancel path and no disclosure in the UI.**
    `cancelAccountDeletion()` has **zero callers** (verified) — no
    pending-deletion interstitial, no consequences screen, no purge date, no
    wallet amount shown, no "Cancel deletion" action anywhere. On success the app
    routes to `/login` and the user is never told the account is recoverable for
    14 days. That disclosure is precisely what Apple and Play reviewers look for,
    and it is the whole justification for the grace period. Only **one** ARB key
    (`confirmDeleteButton`) was added and **no Dart tests** — the client half of
    the brief (§3 of its scope checklist) is essentially unbuilt.
15. **The blocked-balance error surfaces as raw English.** The RPC returns
    `'Wallet balance exceeds dust limit ($1.00). Please spend your balance or
    contact support.'`; the controller wraps it in `UserFriendlyException` and
    the screen renders it in a snackbar — untranslated in a 9-locale app, with
    no actionable spend/payout affordance.
16. **`account_deletions.status = 'frozen'` is mislabelled.**
    `purge_deleted_accounts()` advances `requested → frozen` only when
    `scheduled_purge_at <= now()`, so `frozen` actually means *"grace expired"*.
    The freeze *actions* do run at request time, so behaviour is fine, but the
    labels invert the documented machine and will mislead the next reader and any
    admin dashboard built on them.
17. **Housekeeping from D2 note 6 is still open** and was in D3's own session
    conventions: `android/build/reports/problems/problems-report.html` remains
    tracked, `android/build/` is not in `.gitignore`, and
    `org.gradle.java.home` is still a machine-specific path. **Folded into D4
    item 4 — do it there, not twice.**

**Recommended split:** items **1–6** are the D3b commit
(`fix(privacy): D3b purge pipeline, re-auth & wallet settlement`) and should land
**before** D4's main work — item 1 means account deletion does not currently
work end-to-end, and item 2 is a latent unauthenticated-delete endpoint the
moment item 1 is fixed the obvious way. Items 8 and 10 belong there too (a
failing suite and a revertible security fix should not sit in the tree while you
refactor payments). Items 7, 9, 11–16 can ride in the same commit if time
allows, or become a short D3c. Item 17 is D4.

---

## Known residual risks to carry forward (NOT D4 work — do not fix here)

- **eSIM go-live is still unproven.** C9b's "e2e purchase" used synthetic
  fixtures (`esim_go_ref_9999`, ICCID `8988210000000000001`, LPA
  `TEST-MATCH-123`); the real eSIM Go `/orders` v2.4 contract is unverified and
  `ESIM_GO_API_KEY` is still absent from the VM's `servers/.env`. **E-phase.**
- No stale-`pending` sweep on `esim_orders` — **D5** (already recorded there).
- Crash reporting, PM2 startup persistence and uptime checks — **D5**. Note the
  dependency created here: obfuscated builds need their per-version symbol
  directory retained for D5's symbolication.
- **Still pending owner**: A2 key rotation (now including the PayPal sandbox
  client secret exposed in `paypal_refill_simulator_screen.dart` and in git
  history); C4 WABA/Twilio provisioning — until those secrets are set, three
  webhooks accept unsigned requests, and D2's IP bucket caps cost but is **not**
  a substitute for signature verification; dashboard delete of the
  `execute_zendit_recharge` 410 tombstone; the hosted URLs for
  `doc/PRIVACY_POLICY.md` and `doc/WEB_DELETION.html` (the app already links
  `https://keepsims.com/privacy`, which must resolve before store submission).

## Execution prompt for the implementing agent

See the fenced prompt handed alongside this brief (chat); **this brief is the
source of truth if they diverge.**
