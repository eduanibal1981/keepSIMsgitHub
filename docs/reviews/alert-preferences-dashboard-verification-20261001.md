# Alert Preferences redesign: verification

Image cleanup, 16 October 2026: the captures below were removed from the repository because they are not app assets. Filenames are retained as historical capture identifiers; widget-test captures can be regenerated locally.

Reviewed 1 October 2026 in the local KeepSIMs checkout.

The compact dashboard and focused channel sheets are implemented. WhatsApp shows the saved delivery number below its title. Alarm Clock is a separate device preference under Last line of defense, and Quiet hours / Weekly summary remain readily accessible. See the [full implementation plan](../implementation-plans/alert-preferences-dashboard-plan-20261001.md) for behavior, code locations, timing examples, and release acceptance.

## Automated evidence

| Check | Result | Evidence |
|---|---|---|
| Focused Flutter suite | 21 passed; no failures | `output/alert-preferences-concepts/flutter-tests.log` |
| Android/JVM schedule tests | Four passed; no failures/errors | `build/app/test-results/testDebugUnitTest/TEST-com.keep_sims.AlertAlarmTimeTest.xml` |
| Scoped Dart source analysis | Passed; no issues found | `output/alert-preferences-concepts/dart-analysis.log` |
| Android debug review APK | Passed; final APK built successfully | `output/alert-preferences-concepts/android-build.log` |
| Widget visual review | Light/dark previews reviewed | `output/alert-preferences-concepts/implemented-light.png`, `implemented-dark.png` |

The Flutter suite covers the four-channel overview and destination display, sender-compatible canonical/legacy recipient selection, WhatsApp international validation and normalization, failed-switch rollback, unsaved destination preservation, navigation to the alarm editor and missing-date action, 320-pixel layouts at 200% text scale, existing clock states, existing per-SIM channel badges, eligible-line filtering, device opt-out, cached foreign-account data, offline preservation, and logout clearing. The final cleanup following this suite changes only lint syntax and a redundant null-aware access.

Native timing cases cover a 6:00 PM cutoff with exactly 48 hours' notice, morning and late cutoffs, and a daylight-saving transition. These are scheduler-calculation tests; they do not demonstrate sound on a device.

The previews are rendered from implemented Flutter widgets with fixture accounts, destinations and readiness. They show layout and contrast, not delivery receipts or the user's live account. The test harness omits the enclosing navigation shell.

Source analysis covers the new alarm feature, recipient helper, changed notification controllers/screens/dashboard, shared alarm sheet, changed auto-notify sheet and new Flutter tests. Startup integration is also compiled by the APK build. This is a scoped feature check, not a claim that all existing repository diagnostics were resolved. The tracked patch passes the whitespace check with Windows CRLF treated as valid line endings.

## Repairs included

- Replaced large expanded channel cards and repeated badges with grouped rows and focused editors.
- Removed automatic country-code guessing from WhatsApp and aligned the overview with the sender's actual recipient key precedence.
- Preserved dirty destination text during switch updates, blocked editing during saves, and made a missing channel row return an error.
- Required verified Telegram binding for readiness and refreshed channel preferences when returning to the app. Guarded repeated/closed-sheet actions.
- Removed the misleading 24-hour hardware fail-safe claim. A data-ready SIM is labeled READY; the device overview separately reports Off, Allow access, Not armed or Scheduled.
- Added opted-in Android scheduling and bounded alarm playback, stop notification action, reboot/time-zone reconciliation, account isolation and backup exclusions. Push backlog cleanup preserves ongoing alarm notifications.

The device schedule uses the latest local 6:00 PM at least 48 hours before the estimated cutoff. It can be 48–72 hours early; a reminder enabled after its evening is a prompt catch-up, not a claim of full 48-hour notice. Existing server-side urgent events remain unchanged.

## Practical limits and release acceptance

The Android ringing path is implemented and compiled, but audible background delivery has not been verified on a physical phone. Before a store release, verify ringing, Stop, notification navigation, denied/revoked permissions, channel sound disabled, app closed, device restart, Doze/OEM restrictions, time-zone changes, paused lines and refreshed recharge data. Local alarms use the last synchronized estimate; a recharge performed elsewhere cannot cancel a cached reminder until data refreshes.

Device ringing currently supports Android. Other platforms show the capability as unavailable. New English copy needs localization review before a multilingual release. The existing app's plugin build warnings are outside this feature's scope; retain the build log for the separate dependency migration review.

No production database/schema changes, backend deployment, customer notification, or automatic activation of the device alarm was performed. The opt-in defaults to off. Existing unrelated checkout changes have been preserved.

## Review artifacts

- Light preview (`../../output/alert-preferences-concepts/implemented-light.png`)
- Dark preview (`../../output/alert-preferences-concepts/implemented-dark.png`)
- [Android review APK](../../output/alert-preferences-concepts/KeepSIMs-alert-preferences-review.apk) — debug build, approximately 237 MiB.

Review APK SHA-256: `531D833221ECACE8B3EC315621AFE07019B128B4667DB79D967C6AE1D30746DD`.

## Follow-up: direct editors from Edit Auto-Notify

The Protected Console's Edit Auto-Notify rows now open the same channel settings sheet used by Alert Preferences. The parent sheet stays in place, preserving its SIM context and renewal selection. Closing the editor returns to it. Alarm Clock also opens its shared sheet directly, including when its recharge date is missing; the date action remains inside the alarm editor. Channel settings continue to apply globally, with existing paid-SIM delivery eligibility retained.

The two affected widget suites pass all 11 tests, including direct Email and Alarm Clock editor navigation, dismissal back to Auto-Notify, and the existing Alert Preferences editor tests. Device readiness is stubbed in navigation tests so they do not depend on native phone services or backend calls. The Android review APK has been rebuilt with this follow-up. Evidence: `direct-channel-sheet-tests.log`, `direct-channel-sheet-analysis.log` and `direct-channel-sheet-build.log` in the preview output folder.
