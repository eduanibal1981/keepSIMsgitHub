# Alert Preferences: dashboard, channel editors, and final alarm

Updated 1 October 2026. This plan records the agreed design and the implementation in this checkout. Review previews use fixture data, not delivery receipts. The Android review build is for testing, not a store release.

## Product decision

Use the compact dashboard with focused bottom sheets. Show four delivery channels, a separate Alarm Clock entry under **Last line of defense**, and Quiet hours / Weekly summary navigation. All rows open their corresponding editor. Put switches and forms in the editors so a row tap has one predictable action.

The WhatsApp row explicitly shows **Sends to +[saved international number]** immediately below its title. This is the saved destination, never an inferred number from a SIM or the user's home country. The overview changes after a successful save and a server refresh.

Edit Auto-Notify in the Protected Console opens these same channel editors directly above its existing sheet. Closing an editor returns to the same SIM and renewal selection; no intermediate Alert Preferences page is required. Alarm Clock also opens its shared preferences sheet directly, with missing-date actions inside it. Channel preferences remain global, and paid-line delivery eligibility remains unchanged.

## Page structure and interactions

1. Header: **Alert preferences**, with ordinary back navigation.
2. Short introduction and a compact count of enabled channel preferences. An enabled preference does not prove recipient delivery.
3. **Alert channels**: one grouped surface with Push notifications, Email alerts, WhatsApp alerts, and Telegram bot. Use a consistent icon style, state text, and chevron. Show the email destination and WhatsApp destination beneath their respective titles. Telegram needs a verified binding, not just a chat ID.
4. One short note: paid channels apply only to eligible Standard and Premium SIMs. Global preferences remain editable even if the user currently has no eligible paid SIM. The existing backend remains responsible for entitlement and provider routing.
5. **Last line of defense**: Alarm Clock, with the final reminder schedule and actual device readiness.
6. **Quiet hours & schedule**: Quiet hours and Weekly summary, each with a focused sheet.
7. **Alert types & price watches**: move the long category controls here without removing existing category preferences or the price-watch entry.

Use charcoal text, neutral surfaces, a restrained teal accent, consistent spacing and readable body text. Amber is reserved for setup or permission problems. Main navigation respects the enclosing app shell. Keep the page scrollable on small screens and with large text; do not shrink touch targets to force everything above the fold. Sheet content scrolls and accounts for the keyboard and safe areas.

## Channel sheets

| Channel | Overview | Editor | Persistence |
|---|---|---|---|
| Push | On / Off / Unavailable | Preference switch, device subscription information, test request | Existing channel controller and authenticated test endpoint |
| Email | Saved destination and state | Preference switch, editable address, Save Settings | Existing email/email_address compatibility keys |
| WhatsApp | **Sends to [saved number]** and state | Preference switch, international number, Save Settings | Existing phone/phone_number compatibility keys |
| Telegram | On / Off / Setup required / Unavailable | Verified binding state, secure Link Telegram Bot action, switch after binding | Existing single-use binding token and channel preference |

- Switches save immediately. Destination edits require Save Settings.
- Disable conflicting actions while a switch or destination save is pending.
- A failed switch save restores its previous value and gives a plain-language error.
- Preserve unsaved destination text while the user switches a channel on or off.
- Validate email shape and international phone format before saving. Strip spaces, parentheses and hyphens; normalize an explicit `00` prefix to `+`. Never invent a country code. E.164-shaped input does not itself verify that the destination is registered with WhatsApp.
- Refresh saved channel state on app resume so returning from Telegram updates the binding display.
- A platform-paused channel is **Unavailable** even if its preference is enabled. Preserve the preference for when the channel resumes.
- Push test controls remain in the push editor. A queued test or provider acceptance is not confirmed display on a device.

## Quiet hours and weekly summary

Quiet hours affect routine alerts. Existing critical-event exceptions remain governed by the backend policy. The sheet explains that device Do Not Disturb still applies. Enabling quiet hours retains the existing 10:00 PM–7:00 AM default and separate start/end selectors.

Weekly summary is an Email digest on Sunday at 9:00 AM in the saved notification time zone. Preserve explicit digest consent. A stored enabled flag without consent is shown as **Confirm**, not as a working summary. Keep consent, paid-SIM eligibility, and quiet-hours enforcement in the existing backend; do not duplicate those policies in the view.

## Alarm timing: resolve the 48-hour / 6:00 PM conflict

The implemented interpretation is **the latest 6:00 PM in the device time zone that gives at least 48 hours' notice before the estimated cutoff**. This can be earlier than exactly 48 hours. The sheet explains this explicitly. Do not change or delay the existing server-side 48-hour notification event.

Calculation:

1. Take the authoritative, eligible SIM cutoff as an absolute timestamp.
2. Subtract 48 elapsed hours.
3. Choose 6:00 PM on that threshold's local calendar date.
4. If that evening is later than the threshold, choose the preceding local evening.
5. Use calendar-day arithmetic for the local evening; retain the 48-hour threshold as elapsed time. Recalculate after device time-zone or clock changes.

Examples in Asia/Muscat:

| Estimated cutoff | Local alarm | Notice |
|---|---|---|
| 12 October, 6:00 PM | 10 October, 6:00 PM | Exactly 48 hours |
| 12 October, 10:00 AM | 9 October, 6:00 PM | 64 hours; 10 October at 6:00 PM would be too late |
| 12 October, 11:00 PM | 10 October, 6:00 PM | 53 hours |

If a user enables the alarm after its planned evening, schedule a prompt catch-up (approximately one minute later) only while the estimated cutoff remains in the future. Do not wait another day or describe that catch-up as a full 48-hour warning.

## Alarm readiness and behavior

This is a separate, explicitly enabled **device** alarm. It does not wait for Email, WhatsApp, Telegram or Push to fail: reliable failure proof is generally unavailable. It provides an independent reminder from the verified clock data already synchronized to the app.

- Schedule only active, unpaused SIMs with an eligible authoritative clock, a cutoff and a cycle token.
- Show missing dates, qualifying recharge amounts, qualifying usage, missing/stale carrier rules, paused protection and inactive SIMs as distinct readiness states. Do not invent a cutoff or display an armed device alarm from incomplete data.
- Keep account/device opt-in off by default. Never enable it automatically during a redesign or test.
- **Off** means device opt-in is disabled. **Allow access** means an OS permission or notification/sound setting blocks scheduling. **Scheduled** means local reminders are pending. **Not armed** means no reminder is currently pending; the readiness list explains required actions.
- An eligible deactivation estimate is data readiness, not proof of a scheduled ringing alarm. The per-SIM auto-notify entry uses **READY** for that distinction.
- Store local scheduling identities by SIM and cycle. Consume each cycle before playback so repeated broadcasts cannot ring the same logical alarm twice.
- Reconcile local schedules after SIM/clock data refresh, device restart, application replacement, permission grant and time/time-zone changes. Cancel resolved, removed or paused line schedules when refreshed data shows they no longer qualify.
- Clear pending local schedules and ringing notifications on logout/account change. Do not let another account inherit opt-in or alarms.
- Exclude the device alarm preferences from cloud backup and device transfer so another phone does not inherit this device's opt-in or cached schedules.
- Preserve existing pending schedules during transient readiness-fetch failures rather than erasing them because a request is offline. The sheet states that local alarms use the last synchronized SIM data. Refresh after an external recharge.
- Playback is bounded to at most three minutes with an explicit **Stop alarm** notification action. No automatic refill, payment, snooze or repeated daily alarm is introduced.
- Respect notification permission, the alarm channel's sound settings, alarm volume and device Do Not Disturb. Do not claim a hardware guarantee or force volume/silent-mode overrides.

Android uses a user-granted exact-alarm path and a private receiver/service, independent of notification providers. The service rechecks local opt-in before audio starts. Reboot restoration uses local records; it cannot know an external recharge or carrier-policy change that has not synchronized to the device. Android documents [exact-alarm permission and reboot handling](https://developer.android.com/develop/background-work/services/alarms/schedule) and [foreground-service start exemptions for exact alarms](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).

Device ringing is implemented for Android in this change. Other platforms show an unavailable ringing capability while retaining the existing clock and notification channels. A separate iOS AlarmKit implementation and acceptance run would be needed for equivalent device ringing.

## Implementation map

| Area | Files |
|---|---|
| Dashboard and navigation | `lib/features/notifications/presentation/widgets/alert_preferences_dashboard.dart`, `notification_settings_screen.dart` |
| Existing preference persistence | `lib/features/notifications/presentation/controllers/notification_settings_controller.dart` |
| Device alarm model / contract / repository / controller / UI synchronization | `lib/features/alert_alarm/` |
| Shared Alarm Clock sheet and per-SIM readiness | `lib/features/sim_lines/presentation/widgets/alarm_clock_preferences_sheet.dart` |
| Auto-notify alarm entry | `lib/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart` |
| Android schedule, receiver and bounded playback | `AlertAlarmScheduler.kt`, `AlertAlarmReceiver.kt`, `AlertAlarmService.kt` |
| Platform bridge, permissions and startup synchronization | `MainActivity.kt`, `AndroidManifest.xml`, `lib/main.dart` |

The alarm module follows model → contract → repository → controller → UI. Native calls return a Result through the repository. UI widgets watch controller/provider state rather than directly loading initial data. No new database table, migration, live deployment or notification-provider route is needed for this redesign. Existing global preferences and owner-scoped clock reads are reused.

## Issues found and repaired

1. Long nested channel cards, repeated badges and orange emphasis obscured the main choices: replaced by grouped navigation and focused sheets.
2. WhatsApp previously guessed a country code, including an Egypt fallback: replaced by explicit international validation.
3. Unsaved destination text could be overwritten by channel state updates: preserved until Save Settings.
4. A missing channel row could silently report success: now returns an error; successful saves trigger a server refresh.
5. Telegram readiness must include verified binding; returning from Telegram now refreshes saved state.
6. Existing auto-notify copy promised a 24-hour hardware fail-safe despite a 48-hour clock and no native ringing implementation: removed the claim, added honest readiness and a separate Android opt-in alarm.
7. Alarm loading/read failures could look like a missing recharge date: now show checking/retry rather than treating a request failure as evidence of missing activity.
8. Push backlog trimming must not remove an ongoing alarm notification: ongoing notifications are excluded.
9. New alarm scheduling is idempotent per cycle, account-scoped and cleared on logout; old in-flight alarm work is checked again before playback.
10. Legacy destination keys could display a different recipient from the sender: the overview and editors now use canonical `phone_number` / `email_address` first, with the same legacy fallback as delivery. Saves write both compatibility keys.
11. Test-push and Telegram actions now prevent duplicate requests and check that the sheet remains open before continuing; destination fields cannot change during a pending save.

## Verification and release acceptance

Completed automated verification:

- 21 focused Flutter tests covering dashboard navigation, saved WhatsApp destination, recipient-key precedence, phone validation/normalization, failed-save rollback, dirty-field preservation, small-screen/large-text layout, the alarm editor, existing clock-model cases, auto-notify badges and alarm eligibility/account-isolation/logout/offline filtering.
- Four Android/JVM timing tests covering the exact 48-hour boundary, early/late cutoffs and a daylight-saving transition.
- Rendered light/dark previews with fixture data. These demonstrate layout, not real device delivery.

Before a signed release, use an owner-controlled test SIM and recipient to verify native ringing, Stop, notification taps, permission denial/revocation, channel sound disabled, app closed, reboot, changed time zone, changed cutoff, paused protection and external recharge synchronization. No customer alert should be sent solely as a UI test. Check actual Android devices for Doze, OEM battery restrictions and alarm volume; unit tests cannot prove audible delivery. Confirm the iOS capability label remains honest until equivalent support exists. Complete localized copy review for the supported app languages before a multilingual store release.

The final APK/source analysis result and preview links are recorded in the accompanying verification report. Roll back by disabling the device opt-in (cancels its pending alarms) or reverting this local feature; keep the existing server-side urgent clock event and channel preferences intact.
