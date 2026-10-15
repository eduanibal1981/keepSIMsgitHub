# KeepSIMs — Active cross-machine handoff

Last updated: **2026-10-15 (Asia/Muscat)**. Last active machine: **macOS**.

## Current workspace and task status

- Customer app: `/Users/thehonest/Work/KeepSIMs/keep_sims`, branch `main`, HEAD `26a48f6` (`wip: handoff state`). **Committed and pushed to `origin/main`**. Working tree clean.
- Admin app: `/Users/thehonest/Work/KeepSIMs/keep_sims_admin`, branch `main`, HEAD `93fc37e` (`wip: latest admin updates`). **Clean** at this handoff; no admin code was changed for these tasks.
- Supabase: `zwxswagokhgbuzrrbnhr` (`simSaveDB`). Two calling migrations are already LIVE; see exact source/live-version mapping below.
- Task status: Implementation work is finished for the accepted Quick sheet designs (paid & free calling); live device acceptance checks remain. All code, migrations, tests, and documentation are committed and pushed.
- Cross-machine resumption: When switching to Windows or another machine, run `git pull origin main` to sync HEAD `26a48f6`.

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

- Dashboard selection opens `CallReviewSheet`; empty number retains the manual dialer. Recent/redial use the shared review and history tab.
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

| Check | Most recent result |
| --- | --- |
| Focused Free Call/browse tests | **23/23 pass** |
| VoIP + paid calling suites | **139 pass / 1 existing failure** |
| Entire customer test suite | **719 pass / 20 existing failures** |
| Scoped changed-code/routes/tests analysis | **No issues** |
| Whole-repo analysis | **89 existing findings** |
| Android debug build/install/launch | **Pass**, emulator `emulator-5554`, no AndroidRuntime crash reported |
| iOS simulator debug compile | **Pass**, including native MessageUI |
| Real two-account calls / physical device invite sending | **NOT RUN** |

The calling failure expects a retired KeepSIMs header in `my_numbers_screen_test.dart`; unchanged UI says Virtual Numbers. Full-suite failure categories: refill pricing (9), PayPal (1), Virtual Numbers header (1), biometric overlay (2), FX parsing/display (5), scheduled top-up pricing/channel status (1), onboarding currency transition (1). Whole-repo analysis includes the existing callback return error in `docs/reviews/voip-quality-followup-repros_test.dart:34`. Do not attribute these baselines to this new flow or claim all tests pass.

Build artifacts currently exist at:

- `build/app/outputs/flutter-apk/app-debug.apk` (installed on the emulator).
- `build/ios/iphonesimulator/Runner.app` (simulator build only; no signed release/device run).

Flutter's iOS build temporarily regenerated project/Pods metadata and resolved Sentry Cocoa differently; unrelated project/lock edits were restored. That compile does not prove the exact restored lockfile's next clean resolution. Local Flutter/cache access and ADB may require the normal sandbox escalation. The installed app retains its existing sign-in data; do not uninstall/clear app data to retest.

## Committed files (commit `26a48f6`)

All 63 modified and new files (feature code, tests, plans, verification reports, and migrations) were committed in `26a48f6` (`wip: handoff state`) and pushed to `origin/main`. Working tree is clean.

### What is included in `26a48f6`:
- **Paid calling review flow**: `CallReviewSheet`, `DestinationCountryPicker`, `CallDestination` model/tests, `SmartCallDialerController` updates.
- **Free Call review & invite flow**: `FreeCallReviewSheet`, `FreeCallReviewController`, `FreeCallInvitationService`, `FreeCallRecipient`, `FreeCallHistoryGroup`, `InternetCallingScreen` overhaul, and 23 focused tests.
- **Google Sign-In resilience**: `GoogleSignInFailure` typed error mapping and tests.
- **Supabase migrations & tests**: `20261014212438_resolve_free_call_recipient_exact.sql`, `20261014214959_protect_caller_id_verification_fields.sql`, test suites and runner.
- **Platform integrations**: Android `MainActivity.kt` / `build.gradle.kts` (SENDTO/SMS channel, path fixing), iOS `AppDelegate.swift` (MessageUI SMS compose).
- **Documentation**: Implementation plans and verification reports in `docs/implementation-plans/` and `docs/reviews/`.
- **Pre-existing working tree state preserved**: Drive migrator state files, preview PNGs, web manifest, EOL adjustments.

## Exact next steps on resume

1. Read this handoff, `.agents/skills/keepsims-memory/SKILL.md`, `.agents/AGENTS.md`, and relevant `.codex` rules. Run `git status` (and `git pull origin main` if resuming on Windows or another machine). Working tree should be clean on HEAD `26a48f6`. Admin was clean at handoff.
2. Treat login, paid review, Free Call Quick sheet and the two listed live migrations as completed. If the user reports a concrete new issue, reproduce that issue and change only the affected layer. Existing transport-repair documents are history, not authority to rewrite working media code.
3. For runtime acceptance, use two **different** accounts on two devices. Verify selected-number handoff, national-country confirmation, self/unknown/error handling, a verified registered recipient, and a real no-match invite. Obtain a specific authorized recipient before an assistant places a real call or sends a real message; the intended UI leaves Send to the human.
4. Call acceptance checklist: A→B and B→A; answer, decline, busy, no answer, hangup from either side, two-way speech, mic denial/settings, background/locked recipient, network changes/TURN and truthful connected duration/history. Include a physical device before claiming reliable background/cold delivery. No paid call or free-call wallet charge should occur implicitly.
5. On physical Android/iOS, verify WhatsApp and SMS open the caller's app/composer with the exact confirmed number and editable text. Verify unavailable-channel fallback and explicit Check again after return. Canceling/returning must not imply Sent/Installed. A real download/test link is still needed if invitations are to guide installation; add it through the documented build define when supplied.
6. Reuse focused checks first: `flutter test test/features/voip_calling/free_call_review_test.dart test/features/voip_calling/internet_calling_screen_test.dart`. Expand only for changes/new failures; existing broad baselines above are not green. SQL regression uses Supabase MCP and isolated generated queries; no paid branch/VM action is required.
7. If asked to prepare a commit/handoff to another machine, review and select the actual source/tests/docs/migrations separately from unrelated assets/Drive state/EOL files. Saving this Markdown alone does **not** transfer uncommitted source. No commit, push, reset, migration reapplication or worktree cleanup was requested by the save-handoff instruction.
8. No backend worker files changed here. If future worker changes are requested, `../backend-sync-wt` is authoritative; follow `.agents/AGENTS.md` for the direct deployment process.

## Local reference visuals and temporary verification outputs

Approved visual proposals (Mac-local and outside Git):

- `/Users/thehonest/.codex/visualizations/2026/10/14/01a13b7f-79ea-7bf0-8a13-8680ed97cb10/call-review.html`
- `/Users/thehonest/.codex/visualizations/2026/10/14/01a13b7f-79ea-7bf0-8a13-8680ed97cb10/free-call-review.html`

Both selected variants were Quick sheet. They are design references, not the shipped Flutter implementation. Reload the full visualize skill before editing them. Generated preview browser tabs/servers were closed; do not rely on a still-running preview. Do not assume these Mac paths or build artifacts exist on Windows.

Temporary logs were under `/private/tmp/ks-free-*` (focused tests, final regression/full suite, scoped/full analysis, Android/iOS build). They may disappear and must not be treated as durable handoff data; the two verification reports preserve the conclusions.
