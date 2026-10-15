# Free Call review implementation and verification

Date: 2026-10-15, Asia/Muscat. Customer Flutter app and Supabase project `zwxswagokhgbuzrrbnhr`.

Implemented and installed on Android emulator `emulator-5554`. iOS simulator compilation also passed. Actual two-device calls and outbound invitation sending were **NOT RUN**; no paid call or wallet debit was performed.

## Behavior delivered

Selected Smart Call numbers now open the Free Call quick sheet, with country confirmation for national numbers, signed-in calling profile and Free cost. The requirement for both people to have KeepSIMs is immediately under the number. Confirmed no-match shows WhatsApp and SMS invitations; lookup failures, ambiguous/unverified ownership, and self outcomes remain distinct. Invitations open the caller's installed application/native composer with one confirmed number and editable text; the person presses Send. Explicit share fallback is available when a channel is unavailable. No request for SMS-send permission or automatic messages was added.

Empty entry opens a simplified, theme-aware Recent/People page. Native contacts, household account IDs, and history redial use the same review. Recent records group by stable peer/day; individual status/direction is retained in details. The final Call action rechecks identity after microphone permission and fences stale requests/account changes. Paid fallback returns the same canonical number to the existing paid rate review.

The existing `https://keepsims.com/app` returns a marketing page whose store buttons point to `#`; it is not a verified download route. The user confirmed manual sending through their own apps without supplying a real download link. Current invitation text contains install/sign-in instructions, with an optional verified HTTPS URL supplied through `FREE_CALL_APP_DOWNLOAD_URL` at build time.

## Database changes and boundaries

The live legacy `lookup_voip_contact_by_phone` matched suffixes, prioritized raw SIM claims and other accounts, and returned LIMIT 1. The new client uses `resolve_free_call_recipient(text,uuid)`; older clients retain the legacy RPC. Phone lookup requires a canonical exact match to a verified caller ID, an active server-owned DID, or a confirmed Auth phone, deduplicated by account ID. Raw SIM and editable profile claims are unverified or ambiguous, not phone ownership proof. Known account IDs require an accepted household relationship or caller-owned call history. Self, invalid, unavailable, ambiguous, unverified and no-match outcomes cannot be selected arbitrarily. A push token is never treated as live presence.

The caller-ID table's authenticated column grants and owner-only RLS allowed clients to write verification flags. `protect_caller_id_verification_fields` now rejects client verification/timestamp writes and clears proof on a phone change. Label/default changes and existing trusted server verification remain functional. Existing records were not rewritten or deleted.

Approved lookup update and necessary verification guard deployed:

| Local migration | Live migration version |
| --- | --- |
| `20261014212438_resolve_free_call_recipient_exact.sql` | `20261014214138` |
| `20261014214959_protect_caller_id_verification_fields.sql` | `20261014215139` |

MCP generated deployment timestamps separately from the CLI-created local filenames. Live function bodies match reviewed local source exactly. The resolver is SECURITY DEFINER with empty search path, authenticated-only execution, an authenticated active-account check, caller-keyed quota and minimal result data. Anonymous/service roles cannot execute it. The guard is SECURITY INVOKER, enabled on the intended table, and not directly executable by API roles.

Security advisors intentionally flag the authenticated SECURITY DEFINER resolver as callable. This exposure is required to resolve a narrowly checked recipient without granting broad profile/Auth-table access; authentication, ownership/relationship checks, quota, safe search path and negative checks were reviewed. [Advisor explanation](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). Existing unrelated advisor findings remain outside this task.

## Verification results

- **23/23** focused Free Call/browsing checks pass, including dashboard selection handoff, country/Arabic digits, stale result and account fences, self/error/ambiguous outcomes, permissions, final identity recheck, duplicate taps, exact invitation targets/channel selection, unavailable-channel fallback, paid handoff and Arabic 320px/1.6x layout.
- VoIP + paid calling regression: **139 pass / 1 existing failure**. `my_numbers_screen_test.dart` expects the retired KeepSIMs header; the unchanged screen renders Virtual Numbers.
- Full app tests: **719 pass / 20 existing failures**, matching the previously observed unrelated categories (refill pricing, PayPal, Virtual Numbers header, biometrics, FX parsing/display, scheduled tier pricing and onboarding currency).
- Scoped analysis of changed implementation/routes/tests: **no issues**. Repository-wide analysis: **89 existing findings**, including the existing docs/repro callback error; not a clean whole-project baseline.
- Android debug build/install/launch: **PASS**, process running, no AndroidRuntime crash reported after install.
- iOS simulator debug build: **PASS**, including native MessageUI composer compilation. Flutter regenerated a project comment/Pods metadata and temporarily resolved Sentry Cocoa differently; those unrelated project/lock edits were removed. No signed iOS release or device SMS test is claimed.
- Isolated SQL migration-body checks: **PASS**, fake rows only in pg_temp, full rollback. Cross-country suffix, duplicate owners, raw/unverified claims, verified Auth phone/DID/caller-ID, self, arbitrary ID denial, accepted household/history peers, rate-limit outcome and grant boundaries covered. Verification guard checks reject forged flags/timestamps, retain label/default edits, clear proof on number changes and permit trusted server writes.
- Live SQL checks: **PASS**, self/invalid/no-match/arbitrary-ID/unauthenticated outcomes and grants, plus installed guard behavior on an isolated fixture table. Quota/test rows rolled back; no real recipient lookup data was printed.

Generate the reproducible isolated queries with `python3 tools/build_free_call_sql_tests.py --suite recipient --output /tmp/free-recipient-tests.sql` and `--suite verification-fields --output /tmp/free-verification-tests.sql`; execute through Supabase MCP. These test the actual migration body using only fixture-schema substitution. They do not deploy migrations.

## Remaining release checks

Two distinct accounts on two devices: answer, decline, no-answer, busy, end from either side, two-way speech, microphone denial, background/locked recipient, network switching and TURN. Confirm WhatsApp and SMS composers on physical Android/iOS devices with a deliberately authorized recipient; let the human send. Provide a working store/test download URL before relying on invitations for installation. No real invitation, live person-to-person call or physical iOS test was performed by this task.

Repository housekeeping: unrelated formatting and iOS-generated project/lock changes were restored. The existing `whatsapp_call_screen.dart` content is byte-for-byte identical to its indexed CRLF source; current LF attributes can still make Git report an EOL-only working-tree difference after it was touched. No call-screen logic was changed.
