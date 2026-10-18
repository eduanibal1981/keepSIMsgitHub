# KeepSIMs — Active cross-machine handoff

Last updated: **2026-10-17 07:31 (Asia/Muscat)**. Last active machine: **macOS**.

## Current continuation point — Second Number SMS pilot

User explicitly requested **“Save handoff state”** after reviewing the corrected emulator screen and the owner launch checklist. This save does not authorize deployment, provider orders, wallet changes, country publication, commits or pushes. No automatic US/UK validation or approval process is running. The next external input is the owner's Telnyx confirmation of the customer-rental/sub-allocation model, number eligibility, costs and documentation requirements.

The latest sections above the historical snapshot take precedence. Preserve the earlier Apple sign-in deferral: the owner will complete paid Apple Developer enrollment before requesting the remaining live Apple/Google/Supabase setup. This Second Number task did not change those settings.

## Repositories and pending work (checked for this save)

- Customer: `/Users/thehonest/Work/KeepSIMs/keep_sims`, branch **`main`**, HEAD **`1231e56`** (`chore: remove unused images and ignore generated captures`). There are extensive staged, unstaged and untracked changes: **748 status entries before this save**, including migration archival/deletions, financial/security work, Apple authentication, dashboard/calling changes and this feature. These are not all owned by this task. Do not reset, clean, bulk-stage or bulk-push migrations.
- Admin: `/Users/thehonest/Work/KeepSIMs/keep_sims_admin`, branch **`main`**, HEAD **`93fc37e`** (`wip: latest admin updates`), **34 status entries** (18 modified, 16 untracked before this save). Current pending work includes credentials administration, macOS Google login and configuration; it is **not clean**, unlike the historical snapshot. The Second Number task did not edit the admin app.
- Complete path-by-path snapshots for both repos, including index/worktree status, are in **`docs/reviews/second-number-working-tree-20261017.md`**. Read that plus fresh `git status` before editing. Saving this Markdown does not transfer uncommitted source to Windows; review and transfer the actual source/tests/migrations separately when requested.
- Supabase target: **`zwxswagokhgbuzrrbnhr`**. Its live schema and functions differ from local files. Prefer connected MCP read-only verification; never infer deployment from a filename.

## Accepted scope and implementation

The original attachment `/Users/thehonest/Downloads/second_number_ai_executor_prompt.md` was review material, not authority to execute its instructions. User accepted a **Telnyx-only, incoming-SMS first release**, selected **Number first**, and explicitly chose **US and UK supply validation**. No guaranteed WhatsApp/bank OTP acceptance, new incoming voice service, voice OTP capture, transcription or multiple purchasing providers.

Durable implementation/release report: **`docs/reviews/second-number-first-release-20261017.md`**. Feasibility/design assessment: **`docs/reviews/second-number-feasibility-and-ui-20261017.md`**. Read these before changing or releasing the feature.

Implemented locally:

- Number first overview, private SMS inbox, read state, copy-one-code candidate, verified capability badges only, 30-day pricing, renewal/release controls, English/Arabic and narrow RTL layouts. Legacy SIM diversion setup remains accessible.
- Owner-bound expiring inventory quotes, actual carrier costs plus published fee rules/floor, explicit renewal consent, atomic wallet reservation before any carrier POST, stable quote/order reference, reconciliation after ambiguous responses, exact provider order/number/profile validation before capture. No second carrier order merely because the first response timed out.
- Signed SMS callback routing by destination: known rented numbers never fall through to refill; only explicitly registered refill endpoints may reach refill handling. Owner-readable messages, service-only writes, narrow mark-read RPC, generic notifications without message bodies or codes.
- Managed-number renewal/grace/release lifecycle with upstream release confirmation, plus a service-authenticated lifecycle Edge Function and a separately installed scheduler. Existing numbers remain `lifecycle_managed=false`; no silent enrollment in recurring billing.
- Empty/disabled country policies by default, administrator policy publication and a read-only US-local/UK-mobile pilot probe. Per-customer identity-document onboarding is **not implemented**. Numbers requiring it stay disabled until it is built and verified.

### Main source paths

- `lib/features/calling/contract/second_number_contract.dart`
- `lib/features/calling/data/models/second_number_models.dart` and generated companions; expanded `virtual_did_model.dart` and `available_virtual_number_model.dart`
- `lib/features/calling/data/repositories/calling_repository.dart`
- `lib/features/calling/presentation/controllers/second_number_controller.dart`
- `lib/features/calling/presentation/screens/second_number_overview.dart`, `second_number_sms_screen.dart`, modified `my_numbers_screen.dart`
- `lib/features/calling/presentation/widgets/buy_virtual_number_sheet.dart`
- `lib/core/router/app_router.dart` (number-specific inbox link), English/Arabic ARBs and regenerated localization outputs
- **`supabase/migrations/20261017024520_second_number_inbox_and_lifecycle.sql`** (generated using installed CLI)
- `supabase/functions/_shared/second-number.ts`, modified `manage-dids/index.ts`, modified `sms-webhook/index.ts`, new `second-number-lifecycle/index.ts`, `supabase/config.toml`
- `supabase/tests/second_number_contract_tests.sql`, `supabase/verification/install_second_number_scheduler.sql`
- `test/features/calling/second_number_rollout_test.dart`, modified `my_numbers_screen_test.dart`, `test/second_number_backend.test.cjs`, destination-aware SMS/credential fixtures
- `tools/financial-tests/second-number.mjs`; added `test:second-number` to the already pending financial test package
- `.codex/BUSINESS_RULES.md` Second Number section; preserve other pending changes in this and all shared files.

## Runtime correction and last observed screen

Initial emulator error was a client/backend rollout mismatch. Live catalog inspection confirmed **`get_second_numbers()` and `get_pending_second_number_orders()` are absent**; logs at 03:13 UTC showed repeated 404s. Live **`manage-dids` is version 3**, without `get_countries`. Existing **`get_user_dids()`** is granted to authenticated users, filters `user_id = auth.uid()` and returns active legacy numbers.

Compatibility correction is implemented and applied to the running emulator:

- Only **`PGRST202`** (missing-function/schema-cache) permits the list to fall back to `get_user_dids()`. Auth, permission, internal SQL and connection failures remain errors; no broad catch-to-empty or direct table bypass.
- The optional pending list is empty only for that same missing-RPC condition.
- The exact old Edge response `400 / Unknown action 'get_countries'`, or an empty published country list, becomes disabled coverage. Actual server/auth/network errors retain retry behavior.
- Overview disables acquisition until coverage loads successfully. Repository search/purchase also preflight published coverage, preventing this release from invoking old inventory/purchase actions. Pending-list failures have explanatory text; no isolated refresh link. Pull-refresh keeps failures in provider state.
- Current screen: **“Numbers are not available yet. US and UK coverage and prices are being validated.”**, clock card, disabled **Get Second Number**, privacy/verification caveats. No prior generic load error or stray Refresh status link. This is a launch-status notice, not an asynchronous validation job.

Used `flutter attach -d emulator-5554` and hot restart (initial hot reload retained old loaded source). Existing sign-in persisted. Opened Second Number from Home and visually confirmed the corrected screen against the actual current backend. Disconnected the debugger afterward; `com.keep_sims/.MainActivity` remained foreground. Do not uninstall/clear app data. Android package remains `com.keep_sims`; do not apply the proposed iOS ID to Android.

## Verified evidence (from implementation/fix turns, not rerun merely for saving)

- **117 calling tests passed** after the compatibility correction: `flutter test test/features/calling`.
- Focused analysis: **no issues** with `flutter analyze lib/features/calling test/features/calling/second_number_rollout_test.dart test/features/calling/my_numbers_screen_test.dart`.
- Backend tests: **50 passed** via `node --test test/second_number_backend.test.cjs test/sms_notification_auth.test.cjs test/endpoint_webhook_auth.test.cjs test/provider_secrets.test.cjs`; plus **4** targeted existing credential-rotation DID/SMS checks.
- Isolated native PostgreSQL: **13 scenarios passed**, including concurrent purchase sessions, wallet provenance, owner/role denial, deduplication, private notifications, renewal/grace/release, legacy billing isolation and catalog/grants. Temporary database cleaned up. PGlite also exercised 12 scenarios. This does not mean production migration was applied.
- Complete older credential-consumer test file has unrelated PayPal/voice fixture failures. Existing full-app/financial release gates are not certified green by the feature checks. See current reports rather than old global test counts.
- Account inventory probe through connected SQL was denied on `get_internal_secret` (**42501**); no credential was returned and no provider order made. Later direct execution of `get_user_dids` by the inspection role was also denied; this role differs from authenticated customer access. Do not bypass either permission boundary. Customer list runtime was verified using the signed-in emulator instead.

## Owner responsibilities and latest provider findings

Owner was advised to confirm the existing Telnyx account's business verification/billing; disclose KeepSIMs' customer rental/sub-allocation model; confirm eligibility of intended customers, exact US/UK SMS number types, setup/rental/inbound-message costs and required documents. Then approve 30-day retail pricing, usage/fair-use, cancellation/refund and retention terms and a small paid pilot budget. No monetary amount, customer terms, paid test or launch country was approved beyond **validation of US and UK**.

Official Telnyx UK documentation checked on 17 October lists identity and address documents for UK mobile numbers and asks businesses to disclose sub-allocation. Confirm whether approved business documentation suffices or each end user needs documents. If individual onboarding is required, add it before UK publication; do not mark all customers as approved or publish `not_required` without evidence. US and UK can launch independently once eligible; the owner has not yet selected a US-only release.

- UK requirements: https://support.telnyx.com/en/articles/1311457-united-kingdom-uk-did-requirements
- Requirement groups: https://support.telnyx.com/en/articles/9801714-requirement-groups-for-ordering-phone-numbers
- Incoming SMS setup: https://support.telnyx.com/en/articles/4348981-receiving-sms-on-your-telnyx-number

## Exact next steps on resume

1. Read this current handoff, the implementation/release report, `.agents/AGENTS.md`, `.codex/AI_AGENT_GUIDE.md`, and relevant financial/security context. Inspect both repositories again and preserve staged, unstaged and untracked work. **Do not treat the historical clean-admin or old HEAD values below as current.**
2. Obtain the owner's Telnyx response on sub-allocation, customer eligibility, stock/cost and regulatory documents. Re-check provider documentation and actual account observations at release time. No approval/background validation is currently pending on the app's behalf.
3. Resolve the separately pending wallet/funding security release and its checks. The Second Number migration explicitly depends on `assert_wallet_funding_integrity(uuid,numeric)`. Read `.codex/DATA_BACKEND_SECURITY.md` and the current financial remediation reports. Do not deploy this feature by applying all local migrations.
4. When a scoped rollout is requested and ready, verify target live dependencies, apply only the reviewed migration, then run the exact contract/grant/negative-role checks and advisors. Repository rules require explicit authorization for live migrations/deploy/provider spending; saving this handoff is not that authorization.
5. Deploy matching `manage-dids`, `sms-webhook`, and `second-number-lifecycle`, with checked `verify_jwt` settings. Configure the existing approved secret path for `TELNYX_API_KEY`, the messaging profile ID and provider signing public key; connect the profile's incoming callback to the deployed SMS endpoint. Use secure backend settings, never copy credentials into source, this handoff or chat.
6. Run administrator-only `manage-dids` action `validate_pilot` for read-only US-local SMS / UK-mobile SMS observations. Confirm regulatory eligibility separately; inventory capability is not proof of bank/WhatsApp verification support. If documents are needed, complete the onboarding integration before enabling the relevant policy.
7. Once a controlled paid pilot is separately authorized, buy through the new quoted/reserved/reconciled path and verify actual incoming SMS, owner isolation, private notifications, ambiguous purchase recovery, billing/renewal/grace and upstream-confirmed cancellation. Do not create a second order to resolve a timeout.
8. Approve and publish only validated country/retail/usage policies using the admin RPC. Configure Vault's lifecycle credential, review/install the scheduler separately, and verify actual HTTP responses/Edge runs as well as cron enqueue success. Enable customer acquisition only after these checks.
9. Workers were not changed; this feature uses the Edge lifecycle path. If worker changes are later requested, `../backend-sync-wt` is authoritative and `.agents/AGENTS.md` specifies direct SCP/PM2 deployment.

## Cross-machine tooling and local-only references

- Flutter: `/opt/homebrew/bin/flutter`; SDK cache `/opt/homebrew/share/flutter`. Formatter/tests/analyzer and ADB required the normal sandbox escalation on this Mac.
- ADB: `/Users/thehonest/Library/Android/sdk/platform-tools/adb`; emulator `emulator-5554` (Android 17/API 37). This is local runtime evidence, not a signed production release.
- When regenerating Freezed/Riverpod outputs, use the project's full build-runner workflow; a filtered run previously removed other ignored generated dependencies. Generated files are not hand-edited.
- SQL runner dependencies were cached under `/private/tmp/keepsims-financial-tests/node_modules/`; `PGLITE_MODULE_PATH` and `EMBEDDED_POSTGRES_MODULE_PATH` point to their package `dist/index.js` files. Native runner: `SECOND_NUMBER_NATIVE=1 ... node tools/financial-tests/second-number.mjs`; its temporary local PostgreSQL listener required sandbox escalation. Paths are disposable; recreate dependencies on the destination machine if needed.
- Approved Number first visual fragment (Mac-local, outside Git): `/Users/thehonest/.codex/visualizations/2026/10/17/01a147b4-4a58-70c3-97a6-07c427d9e559/second-number-ui.html`. Read the visualize skill fully before modifying it. The actual product is Flutter, not this design fragment.
- Temporary emulator evidence `/private/tmp/second-number-fixed.png` shows the verified corrected state. Temporary files and debugger URLs are not portable; rely on the durable reports and source.

---

## Historical handoff preserved below — 16 October 2026

The following older snapshot is retained for Apple/calling/dashboard continuity. Its branch IDs, file lists, active-task wording and clean-admin statement are historical. Current status and next steps above supersede them; Apple enrollment deferral remains in force.


Last updated: **2026-10-16 01:36 (Asia/Muscat)**. Last active machine: **macOS**.

Explicit save-handoff snapshot: customer/admin branches, the complete pending file list, and stored Apple authentication verification were inspected. No tests/builds, live settings, deployments, commits or pushes were performed just to save this handoff. **The user will complete paid Apple Developer registration first and explicitly deferred the remaining live Apple/Google/Supabase setup until then.** This is a saved continuation point, not authorization to apply the staged settings.

## Current workspace and task status

- Customer app: `/Users/thehonest/Work/KeepSIMs/keep_sims`, branch `main`, HEAD `563bb9f` (`docs(handoff): update handoff state with clean tree and commit 26a48f6`). Prior paid/free implementation is committed in `26a48f6`. **Working tree has uncommitted Apple authentication, dashboard, and calling follow-up changes**, listed in the complete snapshot below; no new commit/push was made.
- Admin app: `/Users/thehonest/Work/KeepSIMs/keep_sims_admin`, branch `main`, HEAD `93fc37e` (`wip: latest admin updates`). **Clean** at this handoff; no admin code was changed for these tasks.
- Supabase: `zwxswagokhgbuzrrbnhr` (`simSaveDB`). Two calling migrations are already LIVE; see exact source/live-version mapping below.
- Earlier calling status: The 2026-10-15 screenshot follow-up, approved cleanup and person/handset navigation icon are implemented and installed on the Android emulator: International Calls always opens Review call, and Recent Calls now has a dedicated page. The old dialer UI is removed. Broader real-device call acceptance checks remain. Earlier migrations are already live; this follow-up requires no backend update.
- Active task status: Native iOS Apple sign-in is implemented locally and verified with 43 passing auth tests, clean auth analysis and a successful simulator build. Live provider settings and Apple provisioning are deferred pending the user's paid Developer enrollment. See the current Apple section and exact resume steps below.
- Cross-machine resumption: Preserve/review all uncommitted files below before switching machines. Pulling the existing remote branch alone will not transfer the Apple implementation, dashboard changes or illustrated call cards.

## Current Apple sign-in handoff — 2026-10-16

User instruction: “ok i will complete that after i register to the paid developer account, Save handoff state”. **Wait for the user to finish paid enrollment and request continuation. Do not save the previously staged Google or Supabase forms now.**

Implementation and account report: `docs/apple_sign_in.md`. Evidence: `output/apple-sign-in/`.

Implemented in the customer app only:

- `AuthContract.signInWithApple()` → repository native authorization → nonce-verified Supabase ID-token exchange → controller → login UI. The Apple button appears on iOS only; cancellation is quiet, repeated taps are blocked and its progress indicator belongs to the Apple button.
- Each attempt uses a fresh raw nonce; Apple receives SHA-256, Supabase receives the raw nonce. Tokens/provider payloads are not logged or stored in the pending-name record.
- Apple's one-time name is saved to Auth metadata and fills only an empty `profiles.full_name`. A pending name is held in Keychain for the same Apple account if exchange/save fails, retried on its next login and cleared after persistence. A name-save failure does not invalidate a valid session. Prior account profile cache is cleared after successful authentication.
- Controller suppresses early `signedIn` navigation while the name-save/profile-fetch attempt is pending. No schema migration or admin app change was needed.
- **Proposed** iOS bundle ID `com.keepsims.app` in Debug/Profile/Release and RunnerTests. **Apple availability has not been verified or reserved.** Android remains `com.keep_sims`; do not rename it.
- `ios/Runner/AppleSignIn.entitlements` contains `com.apple.developer.applesignin = [Default]`; all Runner build configurations reference it, and the project marks the capability enabled. The old dormant widget App Group entitlement is deliberately not activated.
- Added exact dependencies `sign_in_with_apple: 8.2.0`, `crypto: 3.0.7`, lockfile and generated macOS plugin registration. macOS Apple login itself is not enabled.

Observed remote/account state at the last inspection:

- Apple Developer offers enrollment. The enrollment page reached the entity choice (`Individual / Sole Proprietor` was selected in the UI); no entity submission, agreement acceptance, payment or completed enrollment was performed. Do not assume an entity type is a user decision.
- Xcode recognizes the existing Apple account, but shows only a **Personal Team**. No paid Team ID, signing certificate or provisioned iPhone was configured here.
- Google Cloud project `keepsims-console`: existing iOS client `420312855823-f68m5ditqrbom89huf4b9lv7ql11giqm.apps.googleusercontent.com` still has the saved bundle ID `com.keep_sims` and empty Team ID. A form change to `com.keepsims.app` was staged **without Save**. Keep the existing OAuth client ID and URL scheme when aligning the final bundle ID.
- Supabase project `zwxswagokhgbuzrrbnhr`: Apple provider is still **disabled**, saved Client IDs and OAuth secret empty. An **unsaved** proposal enables Apple for `com.keepsims.app`, leaves OAuth secret empty and preserves the email requirement. The user's latest message defers this change; it does not approve saving it now.
- Firebase project `keepsimsfcm`: only the Android `com.keep_sims` app is registered. No Firebase iOS registration/config was created. iPhone Firebase/push/App Check remains a separate platform step.
- Native iOS ID-token login needs no Services ID or `.p8` OAuth secret. Android/web Apple OAuth is outside this implementation.
- Read-only live DB inspection confirmed `handle_new_user()` inserts profiles, but no auth-users UPDATE trigger copies a later metadata name. The repository therefore fills the profile explicitly. Existing own-account RLS and `full_name` UPDATE privilege were checked; no auth/RLS/schema was changed.

Verified results from the implementation turn (not rerun for this save):

- **43/43 authentication tests pass**, including 12 new repository, 3 controller and 2 UI tests. Auth code/tests analysis is clean.
- Full customer suite: **796 pass / 20 failures or errors outside authentication**. The report lists pricing/PayPal, Virtual Numbers header, biometric overlay, FX display, scheduled-top-up status and onboarding currency failures. Do not claim a green full suite.
- Full-repo analysis: 89 findings outside the scoped auth work, including the existing non-returning test fake in `docs/reviews/voip-quality-followup-repros_test.dart`.
- `flutter build ios --simulator --debug --no-codesign` passed for `com.keepsims.app` (latest build 18.0 seconds); built Info.plist ID checked and entitlement/project plist syntax checked. This does **not** prove signed-device provisioning or a real Apple login.
- Unrelated Xcode serialization and Sentry Cocoa resolution churn from the build was restored. The iOS Sentry Flutter package requires native 8.46.0 while the pre-existing tracked SwiftPM lockfile has 8.58.4; a future build may resolve it again. Do not interpret the simulator build as verification of a clean resolution from the restored lockfile.

Evidence files: `auth-analysis.txt`, `auth-tests.txt`, `ios-build.txt`, `full-tests.jsonl`, `full-test-summary.json`, `google-pending.jpg`, `supabase-pending.jpg`, `apple-enrollment.jpg`, `xcode-personal-team.png`, all under `output/apple-sign-in/`. The summary is authoritative for the final 43-test auth count. Browser enrollment/Google/Supabase tabs were left for handoff, but their unsaved forms may expire; **never rely on old tab IDs or screenshots as current state**. Reopen/read current state on resume.

### Exact Apple resume steps after paid enrollment

1. Read this handoff and `docs/apple_sign_in.md`, inspect both repos' `git status`, and preserve all pending work. Confirm the user has completed paid enrollment and requested continuation before modifying live setup.
2. Verify the paid team in Apple Developer/Xcode and obtain its real Team ID. Register/confirm the final App ID (proposed `com.keepsims.app`), checking availability; enable Sign in with Apple on the App ID.
3. If the registered ID differs, align the Runner/RunnerTests IDs and Google/Supabase audiences with that final ID. Set Xcode's paid Team ID and refresh provisioning. Do not use a Personal Team as evidence this restricted capability can run.
4. Read current Google iOS client and Supabase Apple settings. Prepare matching final values and obtain applicable action-time confirmation before saving the live authentication changes. Do not treat the user's deferral as a standing approval to save. No OAuth Services ID/key is necessary for native-only iOS.
5. Run the focused auth tests/analysis if code/config changed, then build and run on a provisioned iPhone. Test first authorization/name persistence, repeat authorization without name/email, Hide My Email, cancellation and sign-out/sign-in. Check Auth metadata and profile display name. No real Apple-server login was tested previously.
6. Register Firebase iOS separately if the user requests completing iPhone Firebase/push/App Check, and configure Apple's private email relay if sending to relay addresses. Preserve working Android OAuth/Firebase registrations.
7. Source, tests and evidence remain uncommitted. A Markdown save alone does not transfer them between machines. No commit/push/reset/deployment is authorized by the save-handoff request.

## Other preserved dashboard work — context from its existing report

`docs/reviews/dashboard-sim-card-compact-verification-20261016.md` records the compact carousel (reference card 275 → 227 dp), independent tap targets, preserved actions, adaptive layouts and subsequent `SIM 1`, `SIM 2`, … default-name ordering. Its source/tests, plans, captures and latest numbered-label follow-up were already pending before the Apple task. They were not changed by the Apple work or this save. Treat their recorded checks as that task's evidence; do not redo or overwrite it from this chat.

## Complete customer working-tree snapshot at this save

```text
 M .agents/memory/ACTIVE_HANDOFF.md
 M .codex/PROJECT_MAP.md
 M docs/implementation-plans/smart-call-country-and-review-plan-20261014.md
 M docs/reviews/smart-call-review-verification-20261014.md
 M ios/Runner.xcodeproj/project.pbxproj
 M lib/core/router/app_router.dart
 M lib/core/router/placeholder_screens.dart
 M lib/features/auth/contract/auth_contract.dart
 M lib/features/auth/controller/auth_controller.dart
 M lib/features/auth/repository/auth_repository.dart
 M lib/features/auth/ui/login_screen.dart
 M lib/features/calling/presentation/controllers/smart_call_dialer_controller.dart
 D lib/features/calling/presentation/screens/calling_screen.dart
 M lib/features/calling/presentation/screens/smart_call_dashboard_screen.dart
 M lib/features/calling/presentation/widgets/call_history_tile.dart
 M lib/features/calling/presentation/widgets/call_review_sheet.dart
 D lib/features/calling/presentation/widgets/dialpad_widget.dart
 M lib/features/dashboard/presentation/ui/dashboard_screen.dart
 M lib/features/dashboard/presentation/widgets/dashboard_sim_line_card.dart
 M macos/Flutter/GeneratedPluginRegistrant.swift
 M pubspec.lock
 M pubspec.yaml
 M test/features/calling/smart_call_dialer_controller_test.dart
 M test/features/voip_calling/free_call_review_test.dart
?? assets/icons/call_dialer.png
?? assets/icons/free_app_call.png
?? docs/apple_sign_in.md
?? docs/implementation-plans/dashboard-sim-card-compact-plan-20261016.md
?? docs/reviews/dashboard-sim-card-compact-verification-20261016.md
?? ios/Runner/AppleSignIn.entitlements
?? lib/features/calling/presentation/screens/call_history_screen.dart
?? lib/features/calling/presentation/widgets/calling_options_section.dart
?? lib/features/dashboard/presentation/widgets/dashboard_sim_line_carousel.dart
?? output/apple-sign-in/
?? output/calling-options/
?? output/dashboard-sim-card-compact/
?? test/features/auth/apple_sign_in_controller_test.dart
?? test/features/auth/apple_sign_in_repository_test.dart
?? test/features/auth/apple_sign_in_screen_test.dart
?? test/features/calling/call_history_screen_test.dart
?? test/features/calling/calling_options_section_test.dart
?? test/features/calling/smart_call_dashboard_review_test.dart
?? test/features/dashboard/
```

The admin repository was rechecked: branch `main`, HEAD `93fc37e`, clean. The older calling lists below are subsets/history; the complete current customer snapshot above takes precedence.

## Prior calling follow-up — 2026-10-15

The user reported an overwritten review and provided a dashboard with an empty number plus the legacy keypad, requiring the compact Review call sheet instead. Audit found the prior implementation intact. Its original empty-input shortcut caused the screenshot mismatch. That exception is now removed; empty input opens the sheet's focused phone editor, and national numbers still require explicit country confirmation before quote/Call.

Preserved pre-existing pending UI work: the illustrated International Calls/Free Call cards, their assets and previews. A width constraint was added to the dashboard header after a phone-sized integration test exposed overflow. Free Call's dashboard test now selects its icon button via the accessible tooltip.

The user then approved removing the retired dialer UI while preserving history/redial. `CallHistoryScreen` now lives at `/calling/recent`; Call again opens the shared review with fresh identity/pricing, not the historical quote. Loading, empty, retry and live updates are covered. The history tile supports small Arabic light/dark layouts with enlarged text. Old `/calling/dialer` links redirect to history. Removed the old screen, its exclusive keypad component, and obsolete controller digit/country-rate helpers. Active-call DTMF is separate and remains unchanged/tested.

Latest icon follow-up: Smart Call's bottom navigation now shows a person beside a handset, matching the supplied reference. Active uses white filled symbols in the existing blue circle; inactive uses the outlined pair. `CurvedNavigationBarItem` accepts widgets with inherited icon theme so the composite fits the existing bar. Five existing dashboard/navigation checks pass; scoped shell analysis is clean. Android debug build/install/launch passed and the app process was confirmed running. No new tests or full-suite rerun were needed for this icon-only change.

Prior calling modified files (subset of the complete snapshot above):

- `.agents/memory/ACTIVE_HANDOFF.md` (this handoff)
- `.codex/PROJECT_MAP.md`
- `docs/implementation-plans/smart-call-country-and-review-plan-20261014.md`
- `docs/reviews/smart-call-review-verification-20261014.md`
- `lib/core/router/app_router.dart`
- `lib/core/router/placeholder_screens.dart`
- `lib/features/calling/presentation/controllers/smart_call_dialer_controller.dart`
- `lib/features/calling/presentation/screens/smart_call_dashboard_screen.dart` (includes the pre-existing card redesign; preserve it)
- `lib/features/calling/presentation/widgets/call_history_tile.dart`
- `lib/features/calling/presentation/widgets/call_review_sheet.dart`
- `test/features/calling/smart_call_dialer_controller_test.dart`
- `test/features/voip_calling/free_call_review_test.dart`

Deleted intentionally by the approved cleanup:

- `lib/features/calling/presentation/screens/calling_screen.dart`
- `lib/features/calling/presentation/widgets/dialpad_widget.dart`

Prior calling untracked files/directories (subset of the complete snapshot above):

- `assets/icons/call_dialer.png` (pre-existing UI work)
- `assets/icons/free_app_call.png` (pre-existing UI work)
- `lib/features/calling/presentation/screens/call_history_screen.dart`
- `lib/features/calling/presentation/widgets/calling_options_section.dart` (pre-existing UI work)
- `output/calling-options/` (pre-existing UI previews: `implemented-light.png`, `implemented-dark.png`)
- `test/features/calling/call_history_screen_test.dart` (six history/redial/state/layout cases)
- `test/features/calling/calling_options_section_test.dart` (pre-existing UI work)
- `test/features/calling/smart_call_dashboard_review_test.dart` (four review cases plus production routing/history/back/legacy redirects)

Fresh cleanup checks: **19 focused history/dashboard/controller/DTMF tests pass**; complete calling + VoIP suites have **153 passing / 1 existing My Numbers header failure**. Analysis across both calling features/tests and the production router is clean. Android debug build, install and launch passed on `emulator-5554`; the app process was confirmed running and existing app data was retained. Interactions are widget-tested; native screen inspection was not performed. No paid/free call or invitation was sent. Full app checks and iOS were not rerun for this follow-up. Older baselines below remain historical.

## User decisions and constraints

The user selected **Quick sheet** for both paid and free calling. National contact numbers require an explicit destination-country confirmation. The screen should be simple: recipient, appropriate caller identity, rate or Free, and one explicit Call action.

For Free Call, both people must have KeepSIMs. That requirement is directly below the number. Confirmed no-match shows **Invite via WhatsApp** and **Invite via SMS**. The caller's own installed WhatsApp/Messages app opens with recipient and editable text; **the human must press Send**. Never send invitations automatically or through backend messaging. Failed lookup/offline/uncertain presence must not be mislabeled as lacking the app.

The user explicitly approved applying the tested Supabase recipient lookup update. The lookup and necessary caller-verification-field guard were deployed and verified. There is no pending approval for those existing deployments; do not re-ask or reapply them. Further unrelated deployment, paid-call testing, or messaging a real person is not blanket-authorized.

## Completed: Google login

The Android account picker spinner was traced to Google OAuth registration (`UNREGISTERED_ON_API_CONSOLE` / `Account reauth failed`). The user registered the Mac debug certificate in the **keepsims-console** Google project and confirmed successful login using `abdallajava@gmail.com`.

- Package: `com.keep_sims`.
- Web/server client (used by app and Supabase Google provider): `420312855823-qj7f4inghifnlh1lj4rq29nmutm7lgo1.apps.googleusercontent.com`.
- New Mac Android OAuth client: `420312855823-lu5n6ff8phkintbp8chb892kgslb2fb2.apps.googleusercontent.com`.
- Mac debug SHA-1: `AC:6F:44:00:AA:70:BF:95:38:44:4D:E7:0B:E0:70:DF:32:6A:AB:5F`.
- Google initialization now supplies `clientId` only on iOS, while retaining the web `serverClientId`. Typed Google failures are surfaced; only actual intentional cancellation is suppressed. Helper: `google_sign_in_failure.dart`; four focused tests passed earlier in this chat.
- The VM hosting account/project is separate from the OAuth project. No VM/worker changes were made. Android client IDs do not replace the web client ID/secret in Supabase. On another machine, verify its actual signing fingerprint before changing registrations; keep the successful Mac registration.

## Completed: paid Smart Call country/review flow

Plan: `docs/implementation-plans/smart-call-country-and-review-plan-20261014.md`.
Verification: `docs/reviews/smart-call-review-verification-20261014.md`.

- Dashboard International Calls always opens `CallReviewSheet`; an empty number starts in its focused inline phone editor. Recent Calls uses `/calling/recent`, and redial opens the same review. The removed manual dialer must not be restored; its old URL redirects to history.
- Shared `CallDestination` metadata parser handles Arabic digits, international prefixes, national trunk rules and significant leading zeros. Confirm national-number country before lookup/quote; no price-based country guessing.
- Pinned new dependencies: `phone_numbers_parser: 9.0.28`, `country_picker: 2.0.28`, plus new transitive `universal_io`. Existing packages were not intentionally upgraded.
- Review/controller use request/revision fences, a current server quote, verified personal or gateway identity, correct billing/connection-fee details, sufficient-balance preflight, and an immutable final reviewed draft. Changes at final refresh require another Call tap. Minimum balance is NOT a reservation or a guarantee of full-call collection.
- Caller-ID failures no longer invent a gateway number. Native selected-contact picker and active-call DTMF were retained. Native contact selection uses explicit single-contact access, not bulk import/phonebook upload.
- `android/build.gradle.kts` uses filesystem roots rather than splitting Unix paths at `:` for cross-platform build-directory handling.
- Earlier paid checks: 43 focused passes, scoped analysis clean, Android install/launch passed, 320px Arabic at 1.6x passed. No paid call/provider connection was placed.

## Completed: Free Call selected-recipient review and invitations

Plan: `docs/implementation-plans/free-call-contact-and-review-plan-20261015.md`.
Verification: `docs/reviews/free-call-review-verification-20261015.md`.

Main new surfaces:

- `lib/features/voip_calling/domain/free_call_recipient.dart`: typed selection, account result and strict response contract.
- `lib/features/voip_calling/domain/free_call_history_group.dart`: peer/day grouping while retaining individual attempts.
- `lib/features/voip_calling/presentation/controllers/free_call_review_controller.dart`: account/epoch-scoped recipient resolution, explicit country confirmation, invalidation, timeout and final identity recheck.
- `lib/features/voip_calling/presentation/widgets/free_call_review_sheet.dart`: shared Quick sheet, signed-in app profile rather than paid telephone CLID, Free cost, app requirement, distinct no-match/error/self/ambiguous/unverified outcomes, permission-at-Call, invitation compose and explicit fallback.
- `lib/features/voip_calling/data/services/free_call_invitation_service.dart`: installed WhatsApp scheme; native SMS compose channel `com.keep_sims/invitations`. Android uses SENDTO; iOS uses MessageUI. No SMS-send permission/automatic send.
- `InternetCallingScreen`: simplified adaptive Recent/People browsing, explicit number entry/native contacts, shared review for history/household selections, compact invitation action. No raw name-to-phone RPC/debounce race.
- Dashboard carries selected raw number/confirmed country directly into the review. Optional number query on the Internet Calling route also opens review. Paid fallback seeds the canonical number in the existing paid review and still requires an explicit paid Call.
- Dashboard Contacts sizing and Material around the Voicemail tile were corrected after the new handoff test exposed layout/ink assertions.

**Install-link limitation:** `https://keepsims.com/app` serves a marketing page with placeholder `#` store buttons. The user clarified manual sending but supplied no real app download/test URL. Current invitations contain installation/sign-in instructions without promising that page downloads the app. A verified HTTPS download link may be supplied through the build define `FREE_CALL_APP_DOWNLOAD_URL` later. Do not invent store IDs/links.

## LIVE Supabase changes — do not reapply blindly

| Local file under `supabase/migrations/` | Live version | Purpose |
| --- | --- | --- |
| `20261014212438_resolve_free_call_recipient_exact.sql` | `20261014214138` | New exact/unique recipient resolution and authorized known-peer IDs |
| `20261014214959_protect_caller_id_verification_fields.sql` | `20261014215139` | Protect server-owned caller-ID proof from client writes |

The CLI generated local filenames; MCP generated deployment versions independently. Live function bodies were compared with local source and match. Before any future `db push`/history reconciliation, inspect this mapping/live migrations; do not accidentally create the trigger twice or infer undeployed status from local timestamps.

`resolve_free_call_recipient(text,uuid)`:

- Replaces unsafe suffix/first-match behavior for the NEW client; legacy `lookup_voip_contact_by_phone` remains for older clients. Never fall back to it from the new review.
- Canonical exact phone owner from verified caller IDs, active owned DIDs, or a confirmed Auth phone. Duplicate users/conflicting claims are ambiguous. Raw SIM/carrier setup or editable profile phones are unverified claims, not proof of phone ownership.
- Stable account-ID lookup requires an accepted household relationship or existing caller-owned call history. A route ID alone is insufficient. Self, banned/unavailable, invalid, unverified, ambiguous and no-match outcomes remain distinct.
- SECURITY DEFINER, empty search path, authenticated active-account check and caller-keyed quota. No anon/service-role EXECUTE; minimal recipient result and no guaranteed-online claim.
- Added the authenticated endpoint to `supabase/tests/f0_grant_matrix_tests.sql`'s reviewed allowlist.

`protect_caller_id_verification_fields`:

- Live inspection found owner-only RLS plus client INSERT/UPDATE privileges on `is_verified`/`verified_at`. A SECURITY INVOKER trigger now denies client-manufactured proof and clears it when the number changes.
- Label/default edits and trusted server verification through the existing `manage-caller-id` service path remain allowed. Existing records were not rewritten/deleted. API roles cannot call the trigger function directly.
- Security advisors flag the resolver's authenticated SECURITY DEFINER execution by design; the reason/controls and remediation link are recorded in the Free Call verification report. The project still has unrelated security findings; do not claim a clean project-wide audit.

SQL checks:

- `supabase/tests/free_call_recipient_exact_test.sql`
- `supabase/tests/caller_id_verification_fields_test.sql`
- `tools/build_free_call_sql_tests.py` builds the reproducible isolated pg_temp queries from the actual migration bodies. Use `--suite recipient --output /tmp/free-recipient-tests.sql` or `--suite verification-fields --output /tmp/free-verification-tests.sql`, then execute through Supabase MCP.
- Isolated assertion suites passed; all fixture objects/rows rolled back. Post-deployment live source/grant/self/invalid/no-match/arbitrary-ID/unauthenticated checks and installed guard behavior on isolated fixtures passed. No private recipient data was printed and no real call/message was generated.

## Latest verification baseline (not rerun just to save this handoff)

| Check | Last verified result and scope |
| --- | --- |
| Latest icon follow-up: existing dashboard/navigation checks | **5/5 pass**, after icon update |
| History/dashboard/controller/active-call DTMF checks | **19/19 pass**, dialer-cleanup phase |
| Focused Free Call/browse tests | **23/23 pass**, earlier recipient-review phase; covered again within the later calling suites |
| VoIP + paid calling suites | **153 pass / 1 existing failure**, after dialer cleanup and before icon-only follow-up |
| Calling features/tests and production router analysis | **No issues**, cleanup phase |
| Navigation shell analysis | **No issues**, latest icon follow-up |
| Android debug build/install/launch | **Pass**, latest icon update on `emulator-5554`; app process confirmed running, existing data retained |
| Entire customer test suite | **796 pass / 20 failures/errors outside auth**, final Apple implementation run |
| Whole-repo analysis | **89 existing findings**, historical baseline before these UI follow-ups |
| iOS simulator debug compile | **Pass** for the Apple implementation as `com.keepsims.app`; no signed device or Apple-server test |
| Authentication code/tests | **43/43 pass**, scoped analysis clean |
| Real two-account calls / physical device invite sending | **NOT RUN** |

The calling failure expects a retired KeepSIMs header in `my_numbers_screen_test.dart`; unchanged UI says Virtual Numbers. Full-suite failure categories: refill pricing (9), PayPal (1), Virtual Numbers header (1), biometric overlay (2), FX parsing/display (5), scheduled top-up pricing/channel status (1), onboarding currency transition (1). Whole-repo analysis includes the existing callback return error in `docs/reviews/voip-quality-followup-repros_test.dart:34`. Do not attribute these baselines to this new flow or claim all tests pass.

Build artifacts currently exist at:

- `build/app/outputs/flutter-apk/app-debug.apk` (installed on the emulator).
- `build/ios/iphonesimulator/Runner.app` (simulator build only; no signed release/device run).

Flutter's iOS build temporarily regenerated project/Pods metadata and resolved Sentry Cocoa differently; unrelated project/lock edits were restored. That compile does not prove the exact restored lockfile's next clean resolution. Local Flutter/cache access and ADB may require the normal sandbox escalation. The installed app retains its existing sign-in data; do not uninstall/clear app data to retest.

## Committed files (commit `26a48f6`)

The prior 63 modified and new files (feature code, tests, plans, verification reports, and migrations) were committed in `26a48f6` (`wip: handoff state`) and pushed to `origin/main`. The current uncommitted follow-up is listed above.

### What is included in `26a48f6`:
- **Paid calling review flow**: `CallReviewSheet`, `DestinationCountryPicker`, `CallDestination` model/tests, `SmartCallDialerController` updates.
- **Free Call review & invite flow**: `FreeCallReviewSheet`, `FreeCallReviewController`, `FreeCallInvitationService`, `FreeCallRecipient`, `FreeCallHistoryGroup`, `InternetCallingScreen` overhaul, and 23 focused tests.
- **Google Sign-In resilience**: `GoogleSignInFailure` typed error mapping and tests.
- **Supabase migrations & tests**: `20261014212438_resolve_free_call_recipient_exact.sql`, `20261014214959_protect_caller_id_verification_fields.sql`, test suites and runner.
- **Platform integrations**: Android `MainActivity.kt` / `build.gradle.kts` (SENDTO/SMS channel, path fixing), iOS `AppDelegate.swift` (MessageUI SMS compose).
- **Documentation**: Implementation plans and verification reports in `docs/implementation-plans/` and `docs/reviews/`.
- **Pre-existing working tree state preserved**: Drive migrator state files, preview PNGs, web manifest, EOL adjustments.

## Prior calling acceptance steps — when separately requested

1. Read this handoff, `.agents/skills/keepsims-memory/SKILL.md`, `.agents/AGENTS.md`, and relevant `.codex` rules. Inspect `git status` before any pull or edit. Customer HEAD is `563bb9f` with the uncommitted files listed above; preserve them. Admin remains clean.
2. Treat login, paid/free reviews, the dialer retirement, dedicated Recent Calls, person/handset navigation icon and the two listed live migrations as completed. Calling implementation is complete; the active Apple continuation is described above and is deferred until paid enrollment. Later calling user acceptance: confirm the new icon, empty/selected-number Review call, Recent Calls → Call again → review, and Back on the installed emulator app. If a concrete new issue is reported, reproduce it and change only the affected layer. Existing transport-repair documents are history, not authority to rewrite working media code.
3. For runtime acceptance, use two **different** accounts on two devices. Verify selected-number handoff, national-country confirmation, self/unknown/error handling, a verified registered recipient, and a real no-match invite. Obtain a specific authorized recipient before an assistant places a real call or sends a real message; the intended UI leaves Send to the human.
4. Call acceptance checklist: A→B and B→A; answer, decline, busy, no answer, hangup from either side, two-way speech, mic denial/settings, background/locked recipient, network changes/TURN and truthful connected duration/history. Include a physical device before claiming reliable background/cold delivery. No paid call or free-call wallet charge should occur implicitly.
5. On physical Android/iOS, verify WhatsApp and SMS open the caller's app/composer with the exact confirmed number and editable text. Verify unavailable-channel fallback and explicit Check again after return. Canceling/returning must not imply Sent/Installed. A real download/test link is still needed if invitations are to guide installation; add it through the documented build define when supplied.
6. Reuse focused history/review/DTMF checks first: `flutter test test/features/calling/call_history_screen_test.dart test/features/calling/smart_call_dashboard_review_test.dart test/features/calling/smart_call_dialer_controller_test.dart test/features/calling/dtmf_keypad_test.dart`. Free Call checks: `flutter test test/features/voip_calling/free_call_review_test.dart test/features/voip_calling/internet_calling_screen_test.dart`. Expand only for changes/new failures; existing broad baselines above are not green. SQL regression uses Supabase MCP and isolated generated queries; no paid branch/VM action is required.
7. If asked to prepare a commit/handoff to another machine, review and select the actual source/tests/docs/migrations separately from unrelated assets/Drive state/EOL files. Saving this Markdown alone does **not** transfer uncommitted source. No commit, push, reset, migration reapplication or worktree cleanup was requested by the save-handoff instruction.
8. No backend worker files changed here. If future worker changes are requested, `../backend-sync-wt` is authoritative; follow `.agents/AGENTS.md` for the direct deployment process.

## Local reference visuals and temporary verification outputs

Approved visual proposals (Mac-local and outside Git):

- `/Users/thehonest/.codex/visualizations/2026/10/14/01a13b7f-79ea-7bf0-8a13-8680ed97cb10/call-review.html`
- `/Users/thehonest/.codex/visualizations/2026/10/14/01a13b7f-79ea-7bf0-8a13-8680ed97cb10/free-call-review.html`

Both selected variants were Quick sheet. They are design references, not the shipped Flutter implementation. Reload the full visualize skill before editing them. Generated preview browser tabs/servers were closed; do not rely on a still-running preview. Do not assume these Mac paths or build artifacts exist on Windows.

Temporary logs were under `/private/tmp/ks-free-*` (original paid/free work), `/private/tmp/ks-dashboard-review-*` (empty-input correction), `/private/tmp/ks-dialer-cleanup-*` (history extraction, calling suites, analysis, build) and `/private/tmp/ks-smart-call-icon-*` (latest five navigation checks, shell analysis and Android build). They may disappear and must not be treated as durable handoff data; the verification reports preserve the conclusions.
