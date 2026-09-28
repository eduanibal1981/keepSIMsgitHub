# KeepSIMs app-to-app recipient repair — executor implementation prompt

Prepared 22 September 2026. Reviewed local HEAD `11f3add` and relevant uncommitted native changes. Recheck the working tree before editing. This prompt supersedes “complete” claims for incoming app calling; it is a focused repair specification, not an instruction to rebuild the entire calling ecosystem.

Companion: `app-to-app-recipient-retest-20260922.md` in this directory.

## Assignment and completion standard

Implement and physically verify a reliable Android recipient experience for KeepSIMs internet voice calls. Fix cold-start acceptance, duplicate Android tasks, missing recipient controls, and recipient/native hangup. Prefer a lightweight call-only screen when the app is launched to answer. The home dashboard, SIMs, wallet, splash video and unrelated startup jobs must not be prerequisites for answering.

Work in `C:\Users\abdal\Work\KeepSIMs\keep_sims`. Preserve existing user changes and unrelated features. Read repository instructions. Do not work around problems by disabling authentication, making signaling public, adding arbitrary sleeps, or marking a call connected before real media connection. Keep provider credentials out of clients. Implement the fix; do not just return this plan rewritten.

An incoming system notification is only evidence of ringing. Completion requires: recipient acceptance reaches the correct session, two-way audio works, both sides have usable controls, either side can end, and there is no duplicate app task. A successful emulator-caller test or passing widget tests alone does not prove recipient cold-start handling.

## User's actual reproduction

- Caller A: virtual/emulated device signed in as `thehonestgoma@gmail.com`.
- Recipient B: real device signed in as `abdallajava@gmail.com`.
- B app closed: phone rings; tapping Accept launches KeepSIMs through normal slow startup; call does not connect.
- B app already open: incoming UI is a system notification, not a visible in-app incoming screen. Accept produces another KeepSIMs card in Android Recents. Audio can be heard from the virtual caller, but recipient remains on the main app screens.
- B cannot end the call; caller A can.

Use these accounts only for the authorized test scenario, not as hardcoded identities or production special cases. Confirm actual authenticated user IDs rather than treating owned SIM numbers as independent app accounts. Keep emails/numbers out of shared logs.

Screenshot 1 shows incoming Accept/Decline above the dashboard. Screenshot 2 shows two KeepSIMs task cards. The second screenshot does **not** alone prove two operating-system processes or two engines; inspect task/activity/engine IDs. Existing evidence proves at least one audio direction, not both. Test two-way audio explicitly.

“Closed” must be split into Home/background, removed from Recents, OS process eviction, and Settings → Force stop. Record which reproduces the problem; force-stop has different platform restrictions.

## Confirmed local findings and hypotheses

File references below are relative to the repository root, with lines from the reviewed snapshot.

| ID | Evidence | Consequence and certainty |
|---|---|---|
| F1 — P0, confirmed | `lib/core/router/app_router.dart:456` returns `FilteringRouterConfig`; its definition at line 503 implements `RouterConfig`, not `GoRouter`. `incoming_call_manager.dart:35–48` only assigns/navigates when `router is GoRouter`. | Both normal and fallback navigation paths are no-ops with the actual provider. This directly explains a connected recipient remaining on the dashboard without the call screen. The wrapper preserves payment-return behavior and must not simply be deleted. |
| F2 — P0, confirmed integration gap | `voip_callkit_service.dart:15,31–32` exposes native `onCallEnded`, but `incoming_call_manager.dart` never assigns it. | Native End events do not terminate the controller/media/backend conversation. Fixing the on-screen button alone leaves this path broken. |
| F3 — P0, confirmed gap; device timing to verify | Main initializes the manager only after the first Flutter frame (`lib/main.dart:194–196`). Manager listens to `onEvent`; no app use of CallKit `activeCalls()`, `isAccepted`, its background action handler, or durable accepted-action recovery was found. | Accept can occur before the UI listener is ready. The FCM background handler currently shows ringing UI; it is not recovery of a user's later Accept/End action. Trace whether Accept is lost on the reported build. |
| F4 — P0, confirmed startup obstacle | `app_router.dart:133–136` forces every route through splash. `placeholder_screens.dart` plays the splash video and has a 3.5-second fallback. Auth routing depends on profile-loading state; `main.dart` initializes multiple services before `runApp`. | Call route can be delayed or redirected to splash/login/home during startup. Profile-loading must not be treated as signed out; preserve the pending action. |
| F5 — P1, probable duplicate-task contributor | MainActivity uses `singleTop` and empty task affinity (`AndroidManifest.xml:21–22`). The installed callkit plugin uses a transient activity and package-launch intent. MainActivity's custom `onNewIntent` only consumes general notification payloads. | Task reuse and call-intent handling are incomplete candidates for the two cards. Verify merged manifest, intent flags and actual task IDs before deciding the launch-mode fix. Do not claim this manifest alone proves the cause. |
| F6 — P1, confirmed duplication risk | Root widget schedules `initialize()` after every build. Manager has no once-only guard, adds anonymous OneSignal listeners repeatedly, replaces `_fcmSub` without cancelling the previous subscription and observes all session changes with status `initiating`. | Preference/locale rebuilds and offer saves can retrigger ringing/listeners. Push + realtime can duplicate the same invitation and navigation. |
| F7 — P1, confirmed competing handlers | Generic notification service also registers FCM/OneSignal callbacks; `foreground_push_service.dart:showOneSignal` always re-displays the notification after cleanup. Generic navigation does not allowlist the call route. | A call event can be processed as an ordinary alert as well as a call, causing extra display/navigation. Route calls through one dispatcher. |
| F8 — P0 reliability, confirmed gaps | Caller broadcasts the offer before saving it (`voip_calling_controller.dart:183–187`); DB subscription only handles terminal states (`383–394`). Receiver uses STUN-only config (`242–250`). ICE buffering exists but only for candidates it actually receives. | Persisted SDP alone does not replay candidates sent before a cold recipient joined. An early answer can miss a later stored offer; caller cannot recover a missed answer via its current DB listener. TURN asymmetry can break real-network calls. |
| F9 — P1, confirmed | Signaling subscription waits up to eight seconds but catches the failure and returns success (`voip_signaling_service.dart:101–105`). Channel is not private in its construction. | Setup can continue on a failed signaling connection. Membership authorization and explicit failure handling are required. |
| F10 — P0 control/lifecycle, confirmed | `connecting` is not included in `VoipActiveCallState.isActive`; `missed` is omitted from controller terminal states. End awaits a backend request before `_cleanup()` (`419–442`). | Connecting sessions lack normal active/minimize protection; local microphone teardown can wait for network. Late callbacks can interfere with a later call. |

Useful improvements already present: persisted offer RPC, ICE-before-remote-description buffering, explicit track stopping, background FCM ringing, and foreground/realtime incoming delivery. Preserve these while fixing their lifecycle gaps. Do not report the older push-auth mismatch as still present without checking the latest dispatcher: it has changed since the original plan.

### Installed plugin details you must respect

The locally resolved `flutter_callkit_incoming` version is 3.1.5. Inspect lockfile, installed source and merged manifest, not just examples for a different version. Its Dart API returns `Future<List<CallKitParams>>` from `activeCalls()`; each item has `id` and `isAccepted`. Do not copy older map-indexing examples blindly.

The installed plugin exposes `onBackgroundMessage`, `acceptCallHandle`, `activeCalls`, native events and `setCallConnected`. Native `send` targets attached UI listeners or a registered background executor; app registration/recovery still needs to be implemented and verified after process death. Merely exposing an API does not guarantee cold delivery. Inspect callback registration persistence, isolate startup and early-event buffering in the installed version. Any needed plugin patch must be pinned in a maintainable dependency/fork, not only modified in a local package cache.

## Desired user experience

1. **Already in KeepSIMs:** show an in-app incoming-call surface above the current screen, with Answer/Decline and caller identity. Keep required native Telecom registration synchronized. Avoid a second competing ringtone/banner or duplicate session. Answer immediately shows Connecting with a working End button, then active controls.
2. **Background/locked/ordinary cold start:** use native incoming UI where permitted. After explicit Accept, bring up only the call screen. Skip the marketing splash and dashboard. Show caller, connection state, End, mute and audio output. Native End remains available when minimized/locked.
3. **While talking:** Home/Back/lock do not accidentally drop media. If the user chooses to browse KeepSIMs, initialize the main shell on demand and show a persistent call bar. Both parties can end from the app or native ongoing-call controls.
4. **On completion:** a cold call-only launch returns to the prior system context or a small ended screen with “Open KeepSIMs.” It must not force the dashboard. A warm call returns to the previous app screen. Do not close unrelated tasks or discard unsaved app state.
5. **Security:** answering may expose only the call surface on the lock screen. Existing biometric protection remains in force for wallet/profile/full-app browsing. Use valid restored authentication and server participant checks; bypassing a splash is not bypassing authorization.

A Flutter call-only route still needs the relevant engine, authentication and media stack. It can avoid loading the rest of the product; it cannot promise zero process startup. Prefer one foreground Flutter engine/provider container owning the conversation. Background messaging isolates may exist, but must not create an independent competing WebRTC session. Fully native/headless answering without any Flutter UI is a separate architecture and is not necessary to fix this incident.

## Implementation order

### 1. Capture one trace per failure and fix real router ownership

Record build SHA, package/application ID, signing/build flavor, device model, Android version, launch state and caller/recipient call ID. Ensure two installations/work profiles/cloned apps are not being confused with duplicated tasks. Capture redacted Android task/Telecom/notification traces and app events for the user's three scenarios.

Provide a typed navigation service or separate provider exposing the **same underlying GoRouter** used by `FilteringRouterConfig`. Keep the existing filtered `MaterialApp.router` config. Do not create a second router or cast the wrapper to `GoRouter`. Make the incoming manager depend on that stable navigator abstraction. Include lifecycle/disposal ownership and prevent router recreation on routine preference changes.

Represent the target as a call-specific route, e.g. `/voip-call/:callId`, while preserving old links if needed. Repeated events for the same call focus/update the existing route. They must not push duplicates. Show the Connecting surface as soon as an authorized acceptance starts; do not wait for all network/media work before navigating. Failures must leave an ended/error state with End/Close, not an empty dashboard.

Add an integration test using the real wrapped router. A mocked plain GoRouter would miss F1.

### 2. Introduce a single call coordinator and durable action inbox

Unify all entry points: in-app buttons, native Accept/Decline/End, native ongoing notification, FCM, OneSignal and Realtime. Normalize them to call ID + event/action + source + account/device + generation/revision + expiry. Dispatch once into a process-level coordinator with one media owner.

Initialize incoming listeners exactly once, as lifecycle-owned work outside `build()`. Register handlers before starting event consumption. Track/remove named subscriptions on dispose/sign-out, including OneSignal. Initialization retry must not multiply listeners. Exclude call-category messages from the generic notification renderer/router before they display or navigate.

Persist pending user actions atomically in app-private storage or a native bridge **before** relying on Flutter navigation. Support native `onCreate`/`onNewIntent`, the appropriate plugin action/background callback and startup/resume reconciliation. Use storage that observes cross-isolate writes correctly; do not rely solely on cached `SharedPreferences` values. Preserve end/cancel tombstones and invitation expiry so an old Accept cannot resurrect an ended call.

On startup/resume, combine pending actions, typed `activeCalls()` state and an authenticated session fetch. Recover only genuinely accepted invitations, not every ringing entry. Verify recipient/current account, server status, expiry and device acceptance. Consume/acknowledge once after a durable transition; retry safely after crash. Action data from an intent is untrusted until validated. Never store access tokens in notification extras.

Register plugin background handling where needed, using a top-level release-retained callback and necessary initialization. Background handlers may persist/reconcile actions; do not navigate or access UI Riverpod state from another isolate. A background End/Decline must reach durable session termination even with no visible UI. If the plugin cannot reliably deliver a cold action, implement a small tested native callback/bridge; do not add a guessed sleep and hope the listener starts in time.

### 3. Use a call-first startup path

Before splash/profile routing, detect a validated pending incoming-call action. Restore minimum auth and call configuration with a bounded wait, then show the call-only surface. Keep a distinct booting/auth-restoring state; null profile during loading must not erase the call or launch login/home. A truly invalid/revoked/wrong-account session fails closed with a clear call error and native cleanup.

Defer dashboard/SIM/wallet/home-widget sync, background refill sync, nonessential profile/preferences fetches and other unrelated work until the user opens the main shell or after the critical call path. Keep necessary notification registration, authentication and call services functioning. Trace actual dependency cost rather than arbitrarily deleting initialization.

Do not initialize the splash video on a call launch. Ensure late splash/auth/deep-link callbacks cannot redirect away from an accepted active call. Preserve ordinary launcher, payment-return and email-login navigation behavior. Avoid requesting unrelated permissions while the user is answering. Existing users without microphone permission need an appropriate prompt or explicit failure, not silent connection.

Handle `BiometricLockOverlay` deliberately: a restricted call surface and hangup remain usable; entering the main product still requires its existing lock. No global unlock flag from a push payload.

Initial measured targets on the actual recipient in a release-like build: Answer→visible controls p95 <=1 s when warm, <=2 s when cold; Answer→two-way audio p95 <=3 s warm and <=5 s cold on healthy agreed networks. Native End/local microphone stop <=1 s. Report measurements and bottlenecks; these are project targets, not universal platform guarantees. Provide a bounded connection failure screen if the network cannot meet them.

### 4. Correct Android task and activity reuse

Inspect the merged manifest and installed plugin's `TransparentActivity`, `AppUtils`, call activity, Telecom connection and notification PendingIntents. Explain how Accept currently launches MainActivity and show task IDs before/after acceptance.

Choose one proven compatible launch/affinity/intent strategy. Evaluate plugin-documented launch mode against a single-task main activity strategy and the app's payment/auth flows; do not stack `singleTop`, `singleTask`, `singleInstance`, arbitrary flags and extra activities without a coherent model. Remove the empty affinity only if the chosen behavior requires it. Correct PendingIntent identity/update semantics per call, initial intent delivery and `onNewIntent` reuse. Preserve `super.onNewIntent` and other plugins' callbacks.

Do not use `CLEAR_TASK` to mask the problem by deleting the user's current task. Do not make the whole app permanently show over the lock screen. A transient native incoming activity can be excluded from Recents; after answer there must be one visible KeepSIMs task, one foreground call route and one media owner. Prove this with task/activity/engine IDs, not just a new screenshot.

### 5. Make negotiation survive cold acceptance

The caller currently creates the session/push before durable offer creation, then broadcasts and saves SDP; its saved offer need not contain candidates gathered later. Fix the actual handshake:

- Attach signaling callbacks before opening the channel; subscription failure must propagate, with bounded retry or terminal failure.
- Persist/retrieve offer and answer by negotiation revision with authorized participant access. Receiver waits/retrieves a later offer if accepted before offer readiness; caller applies a stored answer if broadcast was missed.
- Buffer local candidates until signaling is ready and remote candidates until the matching remote description is set. Existing remote buffering is useful but not sufficient for messages sent before subscription.
- Implement explicit replay/acknowledgement or a short-lived authorized durable candidate exchange. Alternatively use a tested complete-SDP gathering strategy with bounded gathering. Document the chosen approach; test a recipient joining after all caller candidates were produced.
- Use one processing path for duplicate SDP delivered by DB and broadcast; do not create two answers/peer connections. Identify messages by session/revision and ignore old generations after teardown.
- Both parties obtain server-authorized, short-lived TURN configuration for the same call. Remove receiver-only public STUN fallback as the production connectivity strategy; force-relay test required.
- Make signaling private with participant membership checks. Do not fix connection failures by weakening authorization.
- Claim acceptance atomically per device on the backend before the media transition. Return a typed success/expired/accepted-elsewhere result; a void RPC that updated zero rows is not proof of acceptance. Cancel sibling-device ringing.
- Distinguish invited, accepted/connecting, media-connected and terminal. Start duration and notify native connected state only after the defined media-ready connection event. Do not equate an SDP write or push receipt to connected audio.
- Bound reconnection and setup by server session deadline; end abandoned calls after device/process loss. Never leave a rejected/failed call permanently busy.

### 6. Repair hangup and keep recipient controls reachable

Wire native `onCallEnded` by call ID into the coordinator. The same idempotent end operation must serve recipient button, caller button, native controls, minimized bar, remote hangup, cancellation, timeout and connection failure. Preserve appropriate terminal reason. Ignore callbacks for an older/different call.

On local End: enter ending state, stop/mute microphone and close the local media resources immediately, remove native ongoing UI, then complete durable server termination/retries independently. Do not await an unbounded backend response before releasing audio. Prevent a programmatic native `endCall` callback from recursing into repeated end requests. For offline end, persist intent, show ended locally, and let leases/reconnection reconcile the remote side; do not claim instant remote delivery while offline.

When media truly connects, call the plugin's connected-state API once and configure an ongoing notification with Return/End actions. Handle native mute/hold/audio interruptions where supported, with explicit state mapping. Verify the installed plugin's phone-call/microphone foreground-service behavior against actual target SDK permissions/start restrictions; declaring permissions alone is not proof of background media support.

Include incoming/accepting/connecting in call ownership and reachable-control logic. Include every server terminal reason (`missed` included) in terminal cleanup. Keep generation-guarded, idempotent async disposal so finishing call X cannot dispose call Y. Guard delayed screen auto-pop (currently 1.8 s) against navigating away from a newly started call.

When no call route is visible but a call is owned, show a persistent Return/End surface even if an explicit minimize flag was never set. This is a recovery measure, not a replacement for fixing navigation. Back/Home and restoring from the notification must preserve one session. Never leave audible communication running only behind the dashboard.

### 7. Verify, package and hand off

Automated regression coverage must include:

1. Wrapped-router navigation with real provider wiring; auth loading/splash cannot steal call route.
2. Repeated root rebuilds → one listener per source; three delivery sources → one invitation.
3. Native Accept before Dart listener, followed by process startup → one recovered accepted call.
4. Ringing-only native state does not auto-answer; stale/cancelled acceptance does not reconnect.
5. Receiver before offer, receiver after ICE gathering, lost answer broadcast, duplicated SDP and failed signaling subscription.
6. Native recipient End, UI End and offline End promptly release audio; old callbacks cannot end a new call.
7. Atomic competing-device acceptance and unauthorized account/session access.
8. Connecting/minimized/missed state behavior and privacy-restricted lock screen.

Run scoped analysis/tests and Android native/integration checks. Existing PSTN/media and generic push unit tests do not exercise these recipient flows. Physically execute every required case in the companion checklist, record real two-way speech, native/app termination, warm/cold times and task IDs. Include Samsung-class recipient hardware from the incident where available and a second Android device. Test profile/release-like builds without hot reload; distinguish emulator audio issues from recipient defects.

Provide a reviewable change set, exact installable APK/build SHA, version/signing identity, backend migration/function versions if changed, rollback procedure and redacted trace evidence. Do not uninstall the user's app or reset their account to avoid reproducing upgrade/state recovery issues. Any diagnostic instrumentation must exclude tokens, full SDP and private account/phone data.

Required handoff statement for each case: PASS, FAIL, BLOCKED or NOT RUN with actual evidence. Mark recipient calling READY FOR RETEST only once F1/F2, cold recovery, task reuse, robust negotiation and local cleanup fixes are implemented and the automated integration checks pass. Mark the incident RESOLVED only after the user's three scenarios plus the companion gates pass on physical hardware. Do not claim the entire A–E ecosystem is complete based on this repair.

## Optional later improvement: native-only call controls

If the call-only Flutter surface still cannot meet agreed startup goals after profiling, propose a separate native/Telecom-owned voice runtime and UI bridge. Define persistent service/media ownership, secure auth, platform permissions, audio-route handling, process-death recovery, and reconnection to the main Flutter shell. Do not start two peer connections to “warm up” the app. This is a measured second step, not a prerequisite or excuse to leave the current controls broken.

## References and review limits

- [Android tasks and back stack](https://developer.android.com/guide/components/activities/tasks-and-back-stack): validate launch-mode/flag behavior against real task traces.
- [Android foreground-service start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start): respect background and microphone start requirements.
- [Firebase Flutter message handling](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages): a background messaging isolate is separate from UI state; distinguish ordinary termination from explicit force-stop.
- [Installed plugin version documentation](https://pub.dev/packages/flutter_callkit_incoming/versions/3.1.5): verify exact typed APIs and platform setup against the resolved implementation.
- [Supabase Realtime authorization](https://supabase.com/docs/guides/realtime/authorization): authorize private call signaling by participant.

This repair plan combines the user's observed failures with local source inspection. F1 is a deterministic code-path defect; precise duplicate-task and cold-event loss timing still need device evidence. No calls were placed, accounts altered or fixes deployed when preparing this file. No completed Flutter regression result or current physical-device pass was established by this review.
