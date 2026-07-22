# D1 — Biometric Auth (App Lock + Payment Confirmation): Hand-off Brief

**Written 2026-07-22, repo @ `7860b33` (C9b), live DB `zwxswagokhgbuzrrbnhr`.**
Plan section: `doc/PRODUCTION_PLAN.md` § D1. Phase C is COMPLETE — this opens
Phase D (hardening & compliance, before store submission). D1 is the first
session in a long time with **NO database migration and NO wallet movement** —
it is pure client-side work plus two Android platform files. That makes it
low-risk, but the professional bar is high: biometric prompts are where users
consciously judge whether an app "feels like a real finance app".

## Verified repo state you inherit (checked against source 2026-07-22)

- **`local_auth` is NOT in pubspec.** `flutter_secure_storage: ^10.3.1` IS
  already a dependency (line 39) — use it for the device-local settings below.
- **`MainActivity.kt` extends `FlutterActivity`**
  (`android/app/src/main/kotlin/com/keep_sims/MainActivity.kt`) and hosts the
  `com.keep_sims/esim` MethodChannel (`isEsimSupported`, C9a). `local_auth` on
  Android REQUIRES `FlutterFragmentActivity` — change the superclass, keep the
  channel byte-identical, and re-verify eSIM capability detection still returns
  true on the owner's real device (it's the C9a purchase gate; breaking it
  silently kills the eSIM store).
- `android/app/src/main/res/values/styles.xml` themes parent
  `@android:style/Theme.Light.NoTitleBar` — check the current `local_auth`
  README for whether the FragmentActivity path needs an AppCompat-descendant
  theme on your target API; fix only if the plugin requires it.
- iOS: add `NSFaceIDUsageDescription` to `ios/Runner/Info.plist`. iOS is
  secondary (no Firebase config there either) but must not crash.
- **⚠️ A DECOY biometric UI already ships.**
  `lib/features/settings/presentation/screens/preferences_screen.dart` has
  `_runBiometricSimulation` (line ~48): a fake "scanning" animation that
  pretends to enroll biometrics, then calls
  `toggleBiometricAuth` (`notification_settings_controller.dart:130`) which
  writes `user_preferences.biometric_enabled` — a DB column **nothing reads**.
  There is also an unused `user_preferences.transaction_pin_hash` column.
  This is exactly the class of fake-security theater C3b-2 deleted (the mock
  Simulate button). D1 must REPLACE the simulation with real `local_auth`,
  not layer real auth next to a fake one.
- **Money entry points in the client** (the controller-layer gates the plan
  asks for — all five, verified at these locations):
  1. Plan fee from wallet — `WalletController.payPlanFee()`
     (`lib/features/wallet/controller/wallet_controller.dart:98`).
  2. Points redemption — `ReferralsController.redeemPoints()`
     (`lib/features/referrals/controller/referrals_controller.dart:55`).
  3. Instant refill — `request_instant_refill` path launched from
     `manual_refill_bottom_sheet.dart` (confirm CTA).
  4. eSIM purchase — `request_esim_purchase` RPC
     (`lib/features/esim/data/repositories/esim_go_repository_impl.dart:70`),
     user-facing confirm lives in `EsimCheckoutSheet` (C9b).
  5. PayPal charges — 5 launch sites of `PaypalRefillSimulatorScreen`:
     `wallet_screen.dart:920` (deposit), `onboarding_screen.dart:344`,
     `manual_refill_bottom_sheet.dart:96`, `line_upgrade_sheet.dart:363`,
     `sim_line_form_screen.dart:1355`. **D4 overlap**: D4 will extract this
     screen into `lib/features/payments/` — D1 must gate the LAUNCH SITES (or
     better, the shared guard call before navigation), NOT move/rename the
     file, so D4's diff stays clean.
- NOT gated (server-initiated, no user present): scheduled/auto refills, the
  fulfillment/usage workers, webhook-ingested offline refills. Biometrics are
  a *user-presence* check; background debits are governed by RLS + RPCs.
- ARB: `biometricSecurity` / `biometricDesc` keys already exist in `app_en.arb`
  (verify all 9 locales; the fake flow used them). New strings ×9 as usual.
- Baselines at hand-off: `flutter analyze` 0 errors (info baseline **164**),
  `flutter test` 55/55, debug APK builds, a1 wallet **35.86** (D1 must not
  move it — no live purchases this session).

## Design decisions (professional judgment — follow unless owner overrides)

1. **One guard, injected, mockable.** Build a single
   `BiometricAuthService` (e.g. `lib/core/services/biometric_auth_service.dart`)
   wrapping `local_auth` behind an abstract interface, exposed via a Riverpod
   provider. Controllers call
   `await ref.read(paymentAuthGuardProvider).confirmPayment(reason)` BEFORE
   invoking the repo/RPC. Never call `local_auth` from widgets — the plan
   explicitly says controller layer, and it is the only way the 55-test suite
   can keep passing (fake the service in tests; `local_auth` cannot run in
   unit tests or CI).
2. **Mandatory-if-enrolled, permissive-if-not** (this IS the plan's wording):
   - Device has biometrics/device-credential enrolled → payment requires a
     successful OS prompt. No in-app toggle to disable it.
   - Nothing enrolled / no hardware / plugin unavailable → payment proceeds
     WITHOUT a prompt (typed result `unavailable`, not an error). Do not build
     a custom PIN — `transaction_pin_hash` stays dead; deprecate it in a
     comment, don't migrate.
   - Use `biometricOnly: false` so the OS itself offers PIN/pattern/passcode
     fallback — that is the plan's "PIN/passcode fallback via the OS prompt".
   - Typed outcomes: `success` / `unavailable` (proceed) vs `cancelled` /
     `failed` / `lockedOut` (block, surface the OS message; NEVER auto-retry
     into a permanent lockout).
3. **Grace window ~60s, in-memory only.** A successful payment auth suppresses
   re-prompting for 60 seconds (deposit immediately followed by a refill must
   not double-prompt — this is what Airalo/banking apps do). Store the
   timestamp in the service instance, never persisted.
4. **App-open lock is a separate, optional feature** (setting, default OFF):
   - Toggle lives in Settings (replace the decoy in `preferences_screen.dart`);
     enabling requires ONE successful biometric auth first (standard practice —
     proves the user can get back in).
   - Store the toggle in `flutter_secure_storage`, **device-local**. Do NOT
     use `user_preferences.biometric_enabled` — enrollment is per-device; a
     DB-synced flag would lock a user's second device that has no biometrics.
     Stop writing the DB column; leave it in place (no migration).
   - Implementation: a lock overlay ABOVE the Navigator (builder-wrapped at
     the `MaterialApp.router` level in `main.dart`), driven by a
     `WidgetsBindingObserver` — locked on cold start and on resume after
     background. An overlay, not a route: routes can be bypassed by deep links
     and push-notification taps (OneSignal deep-links `/esim` from C8/C9
     notifications — those must land BEHIND the lock).
   - The overlay must be opaque from the first frame (no content flash) and
     auto-fire the OS prompt on appear, with a "Unlock" retry button.
5. **Do NOT set `FLAG_SECURE`.** It would block screenshots app-wide — and
   users legitimately screenshot their eSIM QR codes (C9b delivery screen).
   Revisit per-screen only if the owner asks.
6. **Honest framing** (README/plan record + any UI copy): this is a local,
   client-side gate. The server-side money path (RLS, SECURITY DEFINER RPCs,
   idempotent ledgers) is unchanged and remains the real security boundary.
   A rooted device can bypass the client gate; it cannot bypass RLS.
7. **No server round-trips in the guard.** The prompt must work offline
   (offline recharge screen exists precisely for that context).

## Scope checklist

1. Add `local_auth` (current stable) to pubspec; `MainActivity` →
   `FlutterFragmentActivity`; `NSFaceIDUsageDescription`; theme check.
2. `BiometricAuthService` + `paymentAuthGuard` provider + typed result enum;
   fake implementation for tests.
3. Gate the 5 payment entry points listed above at controller/launch level.
4. App-open lock: secure-storage setting + Settings toggle (kill
   `_runBiometricSimulation` and the fake animation) + lifecycle overlay.
5. ARB strings ×9 (reuse `biometricSecurity`/`biometricDesc` where apt; new
   keys for prompt reasons, lock screen, lockout error, unavailable notice).
6. Tests: unit tests for guard logic (enrolled/unavailable/cancel/lockout ×
   each gated controller via fake service), widget test for the lock overlay
   (locked → unlock flow), all existing 55 stay green.
7. Manual verification on the owner's real Android device (the C1b device):
   real fingerprint prompt on a wallet payment, cancel blocks the RPC, app
   lock on/off, eSIM capability channel still works, debug APK builds.
8. Update `doc/PRODUCTION_PLAN.md` § D1 with an implementation record in the
   house style (deviations included) and flip D1 to ✅ DONE. Update memory
   status file. Commit `feat(security): D1 biometric app lock & payment
   confirmation` — single commit, no C-phase leftovers mixed in.

## Confirm with owner at session start (non-blocking — proceed with defaults)

1. Grace window 60s for payment re-prompts — OK? (default: yes)
2. App-open lock re-locks on every background/resume (no timeout tiers) —
   simplest honest version; add timeout tiers later if it annoys. (default: yes)
3. Gate the offline-recharge "send request" taps too? They debit the wallet
   server-side on webhook ingestion. Recommendation: YES, same guard — it's a
   user-initiated spend and the prompt works offline. (default: yes)
4. `PaypalRefillSimulatorScreen` gating happens at launch sites, extraction
   itself stays D4 — confirm D4 is still a separate session. (default: yes)

## Session conventions (house rules — do not deviate)

- **NO migration this session** — if you find yourself writing SQL, stop and
  re-read the scope. No SQL tests either; the Dart suite carries D1.
- `flutter analyze` 0 errors (info baseline **164**); all Flutter tests pass
  (55 at hand-off + new ones); debug APK builds.
- ARB keys in all 9 locales (en, ar, es, hi, tr, bn, ne, si, ur); use the Edit
  tool for non-Latin files (PowerShell 5.1 mojibake); no blanket `dart format`.
- Wallet baseline **35.86** — verify untouched at session end.
- One commit, `feat(security): …`, pushed to `origin/main`.

## Known residual risks to carry forward (NOT D1 work — do not fix here)

- C9b's "e2e purchase" used synthetic fixtures (`esim_go_ref_9999`, ICCID
  `8988210000000000001`) — the real eSIM Go `/orders` v2.4 contract is still
  unverified; `ESIM_GO_API_KEY` still pending in VM `servers/.env` and
  `esim_offers_cache` real-catalog fill unconfirmed. Belongs to eSIM go-live.
- No stale-`pending` sweep on `esim_orders` (worker death = order stuck, money
  held) — candidate for D5 observability or E-phase.
- A2 key rotation, C4 WABA/Twilio provisioning, Zendit Edge Fn dashboard
  delete — still pending user (see memory).

## Execution prompt for the implementing agent

See the fenced prompt handed alongside this brief (chat); this brief is the
source of truth if they diverge.
