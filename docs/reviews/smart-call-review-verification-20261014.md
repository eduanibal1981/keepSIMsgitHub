# Smart Call country and review verification

Date: 2026-10-14 (Asia/Muscat)

The 2026-10-15 follow-up below supersedes the original empty-input manual-dialer behavior.

## Delivered

Selected or entered phone numbers open the Quick sheet review from Smart Call. National numbers require explicit country confirmation. Destination parsing preserves international prefixes, handles Arabic numerals, and supports mobile/landline metadata, including Italian significant leading zeros. Editing reveals the phone input; the manual dialer remains available for empty input. Dashboard history opens its history tab; redial uses the shared review. Native contact picker and active-call DTMF controls are preserved.

The review shows destination, effective caller ID, customer rate, billing interval, applicable connection fee and Call. Only verified personal IDs are selectable. Explicit gateway or personal choices remain local to the draft rather than updating the saved default. Caller-ID fetch failures no longer fabricate a gateway number. Missing country, missing/failed/obsolete/invalid quote, low balance and policy ineligibility disable Call. Final submission uses an immutable reviewed draft and rechecks pricing/identity; changed details require another explicit Call tap. No database, worker, or Edge Function deployment was performed.

## Checks

| Check | Result |
| --- | --- |
| Focused destination/review/controller/repository/contact/DTMF checks | 43 passing (the initial focused command reported 42; the subsequent full calling run passed the additional explicit-gateway-preference test) |
| Analysis of calling code, route integration, and calling tests | No issues |
| Calling test directory | 83 passing, one failure in unchanged `my_numbers_screen_test.dart` |
| Android debug build | Passed |
| Install and launch on emulator-5554 | Passed; restored session redirected to `/home` |
| 320px Arabic layout at 1.6x text | Widget test passed without overflow |
| Full customer Flutter test suite | 697 passing, 20 failures outside the implemented flow |
| Full repository analysis | 89 findings in other source/test/tool files; one error in `docs/reviews/voip-quality-followup-repros_test.dart:34` (callback lacks a return) |
| Diff whitespace check | Passed |

App-wide failures are in unchanged files: nine refill-pricing tests, one PayPal pricing test, the old My Numbers header assertion, two biometric-overlay tests, five currency-display tests, one scheduled-top-up channel-status test, and one onboarding-currency-transition test. They were observed, not repaired as part of this calling request. Dependencies already in the app were not upgraded; only the pinned parser/picker and their new transitive dependency were added.

The My Numbers assertion expects a retired `KeepSIMs` header while that screen displays `Virtual Numbers`. Neither its source nor its test was modified for this task.

## Verification limits

No paid call or provider connection was placed. The full review interactions were exercised in Flutter widget tests; native emulator screen inspection was unavailable through the computer-use app binding. The Android build was installed and launched successfully. iOS runtime behavior was not exercised. Server call-creation checks remain authoritative; client minimum-balance checks do not reserve balance or guarantee payment for an entire call.

Implementation plan: `docs/implementation-plans/smart-call-country-and-review-plan-20261014.md`.

## Dashboard review follow-up — 2026-10-15

Audit: the paid implementation remains in commit `26a48f6`; it was not removed by the pending illustrated-card redesign. The dashboard retained the original plan's empty-input shortcut to `CallingScreen`. The user's screenshots now explicitly require Review call for that case too.

Change: the International Calls action always opens the bottom sheet. An empty draft focuses the inline phone input. Entering a national number still requires explicit country confirmation before a quote or enabled Call. A valid international/previously selected number uses the existing compact destination, caller-ID and rate review. Closing copies number edits back to the dashboard. The new illustrated cards, history route, active-call controls and Free Call behavior are preserved. A header width constraint prevents phone-sized overflow exposed by the new integration checks.

| Check | Result |
| --- | --- |
| Dashboard review + Free Call review tests | 26 passing |
| Complete calling + VoIP test directories | 146 passing / 1 existing My Numbers header failure |
| Analysis of both calling features and their tests | No issues |
| Android debug build | Passed |
| Install/launch on emulator-5554 | Passed; app process running, existing app data retained |

The four new dashboard cases cover empty entry and country confirmation, a selected national number, an international number with effective caller ID/rate, and clearing/closing/reopening without a stale quote. The existing Free Call handoff test now selects the round icon button by its tooltip. The remaining My Numbers failure still expects `KeepSIMs` rather than the current `Virtual Numbers` header; that source/test pair was not changed. Whole-app tests/analysis and iOS were not rerun for this localized navigation correction. Sheet interactions were verified in widget tests; native emulator visual inspection was not performed. No database/backend changes, real calls or invitation sends were performed.

## Approved dialer retirement — 2026-10-15

Replaced the combined dialer/history screen with `CallHistoryScreen` at `/calling/recent`. The dashboard shortcut and old dialer URLs reach history. Call again opens the current shared Review call sheet; it fetches a new quote/effective caller ID and requires national-country confirmation rather than trusting the old call's country/price/identity. Closing review returns to history, and Back returns to Smart Call.

Deleted the 962-line `calling_screen.dart`, its exclusive 94-line `dialpad_widget.dart`, and 18 lines of obsolete controller digit/country-rate helpers. No active-call source changed; the separate DTMF keypad remains functional. The history tile now follows the active theme and wraps status/time for small screens, with Arabic labels and a labeled Call again action. Existing call records, streams, repositories, server billing/auth and Free Call logic are preserved.

| Check | Result |
| --- | --- |
| Focused history, dashboard routing/review, draft controller, active-call DTMF | 19 passing |
| Complete calling + VoIP suites | 153 passing / 1 existing My Numbers header failure |
| Analysis of both features/tests and production router | No issues |
| Android debug build | Passed |
| Emulator install/launch | Passed; app running with existing data retained |

Six new history cases cover fresh quote/identity redial, national-country confirmation, loading/empty/live updates, error/retry and 320px Arabic light/dark layouts at 1.6x text. Production-router integration covers Recent calls, Back, `/calling/dialer` and `/calling/dialer?tab=recent`. The former keypad controller test now verifies that country selection does not fabricate a destination. No real call/message, backend deployment or whole-app/iOS rerun was performed.

## Navigation icon follow-up — 2026-10-15

Changed the Smart Call bottom-navigation symbol to a person beside a handset: filled white in the active blue circle, outlined when inactive. Existing navigation/theme behavior is preserved. Five existing dashboard/navigation checks pass; shell analysis is clean. Android debug build/install/launch passed with app data retained and the process confirmed running. The broader counts above precede this icon-only follow-up; no new tests or full-suite rerun were added for it.
