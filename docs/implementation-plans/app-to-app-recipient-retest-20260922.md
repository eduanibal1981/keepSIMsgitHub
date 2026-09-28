# KeepSIMs recipient calling — focused retest guide

22 September 2026. Run after the executor implements `app-to-app-recipient-repair-executor-prompt-20260922.md`. These are expected outcomes, not current test passes.

## Setup

- A: virtual caller signed into `thehonestgoma@gmail.com`.
- B: your real recipient device signed into `abdallajava@gmail.com`.
- Record the new build/version, Android version and network on both. Confirm both devices use the compatible updated call protocol/build.
- Grant microphone and necessary call-notification permissions. Begin with B unlocked, Wi-Fi working, and no active call.
- Ask the executor for a release-like test APK, its SHA/version and a visible support/call reference. Do not measure startup using hot reload.
- Avoid reinstalling/clearing data to hide an upgrade bug; the repaired build should work as an ordinary update.

For every connected test: A says “one two three”; B repeats it and says “four five six”; A repeats that back. This checks both directions. Use headphones/separated devices to avoid mistaking acoustic echo for remote audio. Finish the call from the recipient in most cases.

## Three original problems — must all pass

### T01 — Recipient app already open

1. Open B's KeepSIMs dashboard, with no call active.
2. A calls B. Observe B without opening the notification drawer.
3. Answer in the in-app incoming-call surface.
4. Perform the two-way phrase check; B taps End.

Expected: caller identity and Answer/Decline appear in KeepSIMs; Answer immediately shows Connecting/active call controls. No dashboard-only conversation. Both sides hear each other. End works on B, stops both sides when online and removes native ongoing UI. No app-call wallet debit.

### T02 — Answer from system notification, no duplicate app task

1. Open B's KeepSIMs and note the existing single card in Android Recents.
2. Press Home; A calls B. Answer using the native notification.
3. Check Recents while talking; return to the call.
4. End from B's native ongoing-call notification.

Expected: existing app task is reused. Exactly one visible KeepSIMs card remains after acceptance, containing the call surface. Returning does not start another conversation. Native End actually stops microphone/audio and ends the remote call, rather than only dismissing the notification.

The executor must confirm activity/task/media-owner counts in device traces; screenshots alone cannot establish process or engine counts.

### T03 — Closed recipient app

1. End all calls. Remove B's app from Recents, without using Settings → Force stop.
2. A calls B. Wait for ringing, then tap Accept.
3. Measure time until controls appear and until the phrase check works.
4. End from B.

Expected: only the lightweight call surface opens; no splash video/dashboard detour. Accepted action survives startup and connects. End is visible during Connecting and during the conversation. After ending, B returns to the previous system context or a small ended screen; it is not forced through the main dashboard.

If this device keeps the process alive after swiping, the executor must separately repeat with ordinary OS-process eviction. Do not use force-stop as a substitute for cold-process testing.

## Further regression cases

| ID | Actions | Expected result |
|---|---|---|
| T04 | B locked/backgrounded; A calls; B answers and ends. | Appropriate native incoming UI; usable call controls; two-way speech; no wallet/profile exposure on lock screen. |
| T05 | B closed/locked; repeat T03. | Cold acceptance works with lock-screen restrictions; no accepted-but-forgotten call. |
| T06 | B foreground; decline. Repeat B backgrounded/closed and decline from native UI. | A sees declined; B does not need to open the dashboard; no microphone, dangling ringing or permanently busy account. |
| T07 | Let invitation go unanswered for the configured 45 seconds. | One missed/timeout result and stopped ringing on both devices. Another call can start immediately. |
| T08 | A cancels while B rings; B taps an old notification if one remains. | No resumed call or microphone capture; clear “Call ended” and stale native UI removed. |
| T09 | Answer, then immediately press End before audio connects. | Recipient can cancel connection; late setup callbacks do not reopen microphone or screen. |
| T10 | Answer after a 25-second delay. | No lost early signaling/candidates; two-way media still connects if invitation is valid. |
| T11 | Repeat 10 calls, alternating warm and closed B; use native and in-app Answer. | One invitation/route/session each time. No increasing duplicate notifications, task cards or slowdowns. |
| T12 | Change theme/language, reopen settings/dashboard, then receive a call. | Root rebuilds do not multiply ringing/listeners; labels remain legible in Arabic and English. |
| T13 | During a call press Home, lock/unlock, open Recents and restore. | One continuous session; accessible ongoing Return/End actions and correct duration. |
| T14 | Back/minimize within KeepSIMs, browse SIMs, then end from the call bar. | Bar appears, controls work, earlier screen state preserved. No silent conversation hidden behind navigation. |
| T15 | End from B with network temporarily disconnected. | Local audio/microphone stop within one second; no wait for network. Remote eventually terminates through recovery/timeout; state reconciles after reconnect. |
| T16 | End call 1; start call 2 immediately. | Old native events, cleanup or delayed screen pop cannot close call 2 or remove its controls. |
| T17 | B on mobile data, A on Wi-Fi; reverse networks. | Both directions work; real-network behavior is not inferred from an emulator/LAN-only call. |
| T18 | Executor forces TURN-only connectivity, then a short network interruption. | Both peers use authorized relay; bounded recovery or clear failure, never infinite Connecting/Reconnecting. |
| T19 | Tap Answer twice; executor delivers duplicate FCM/OneSignal/Realtime events. | One answer claim, one media session, one call screen. No new task or repeated ringtone. |
| T20 | B has a second signed-in device; both try answering. | One device wins; the other stops ringing and says answered elsewhere. No competing audio sessions. |
| T21 | B session is restoring; repeat cold answer. Then test a truly expired/revoked or wrong-account session in staging. | Restoring auth preserves pending call; invalid account/session fails clearly without accessing another user's call. |
| T22 | Enable KeepSIMs biometric lock; answer with phone locked; attempt opening Wallet. | Call controls/End usable; protected full-app pages still require unlock. |
| T23 | Deny microphone, notification/full-screen permission where applicable; receive/answer. | Clear limitation and appropriate recovery, no silent accepted call or false connected state. No requirement to bypass OS restrictions. |
| T24 | Receive a normal cellular call during the app call, then return. | Documented hold/end/audio recovery works; no permanent mute, double capture or lost hangup controls. |
| T25 | Open KeepSIMs normally; exercise email-login and existing payment return in staging. | Normal launch/deep links still work; task/route fix did not break the router's payment filtering. |
| T26 | On B use Settings → Force stop, then A calls. | Record separately as an OS limitation. After manually reopening B, normal calls recover. Do not label expected force-stop delivery restrictions as a successful cold-answer test. |
| T27 | Reverse roles: real device calls virtual device; then repeat with two physical devices when available. | Bidirectional control and media work; emulator quirks are documented, not used to waive real-recipient failures. |

## Timing and visual targets

On the agreed healthy network, use at least 20 measured samples per startup state if reporting p95. For smaller sample counts, provide all raw observations instead of claiming a stable percentile.

| Measurement | Initial acceptance target |
|---|---|
| Warm Accept → visible Connecting/End controls | p95 <=1 second |
| Cold Accept → visible call-only controls | p95 <=2 seconds |
| Warm Accept → verified two-way audio | p95 <=3 seconds |
| Cold Accept → verified two-way audio | p95 <=5 seconds |
| Recipient End → local microphone/audio stopped | <=1 second on a healthy device, including offline termination |
| Native/app session/task duplication | Zero observed |

The executor should instrument event timestamps; a screen recording is useful supplementary evidence. These are targets for the tested device/build/network, not global carrier or Android guarantees. Any failure must show an actionable error within the configured setup deadline, with working End/Close controls.

## What evidence to request from the executor

1. T01/T02/T03 recordings showing both devices, two-way phrase checks and recipient hangup.
2. Build SHA/APK version and native task IDs before/after Accept; one foreground media owner.
3. Trace linking invite → native Accept → durable recovery → route → session acceptance → SDP/ICE → media connected → recipient End → local cleanup → server termination.
4. Test proving real `FilteringRouterConfig` navigation works; a test using only a mocked GoRouter is insufficient.
5. Cold native-action recovery, repeated initialization, duplicate-delivery, delayed-candidate and offline-End tests.
6. Confirmation no app-call debit and no stale native call/active microphone after end.

Readiness rule: do not call this repaired until the three original scenarios pass on the real recipient. “The phone rings” or “caller can hear audio” is not enough. If only automated checks pass, label the build **ready for physical retest**, not **fully fixed**.

## Results template

| Case | Build / B device / OS / network | Actual result | PASS / FAIL / BLOCKED / NOT RUN | Call reference / evidence |
|---|---|---|---|---|
| T01 | | | | |
| T02 | | | | |
| T03 | | | | |

For a failure record: exact meaning of “closed”; whether Answer was native or in-app; visible destination screen; number of Recents cards; which audio direction worked; whether B's End existed/worked; time and call reference. Redact emails/phone numbers/tokens from evidence shared outside the authorized troubleshooting context.
