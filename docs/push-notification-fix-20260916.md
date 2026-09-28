# Push notification repair — 16 September 2026

## Confirmed causes

- Version 26 converted an omitted OneSignal `recipients` field into zero. It
  then sent the same logical alert through subscription IDs, legacy player IDs,
  external aliases, and FCM. Device logs show those supposedly failed OneSignal
  messages actually arriving. An HTTP 2xx response with a nonempty message ID
  indicates acceptance; it is not a device display receipt.
- The foreground listener deliberately hid `line_added` and
  `auto_recharge_scheduled` notifications. Quiet Android channels already control
  sound and heads-up behavior; preventing display removed the tray card too.
- Direct FCM messages had no foreground display handler. Android only renders
  the notification payload automatically when the app is in the background.
- At 04:53 Muscat time, the connected Android device rejected the new test card
  with `Package has already posted or enqueued 50 notifications`. Old duplicate
  and restored cards had exhausted Android's per-app limit.

## Changes

`dispatch-alert` version 27 targets each registered device once. A successful
OneSignal message ID stops fallback even if the recipient count is absent or
warnings exist. Definite rejection falls back only for that device. Unknown
responses retry once using the same deterministic notification/target UUID;
they do not switch transport and risk another card. Provider acceptance logs
explicitly say that display is not confirmed. Existing database status values
are retained for compatibility.

Android foreground FCM messages now use a native notification bridge, preserving
channels and tap destinations. OneSignal messages retain their SDK renderer.
FCM taps use the default launcher rather than an undeclared custom click action.
OneSignal foreground suppression is replaced with a controlled display: pause
automatic display, make room, then display once. Startup and foreground display
trim older tray cards to the latest 20 and mark removed OneSignal cards dismissed.
At 40+ cards, recovery clears the OneSignal tray/restoration cache before showing
the next notification. Native-only cancellation was verified insufficient: the
SDK restored duplicate cards and hit the limit again. The in-app notification
history is retained.

## Verification

- Nine backend tests cover response classification, per-device targeting,
  selective fallback, idempotent retries, and the full dispatcher with mocked
  providers, including authorization and Android payloads.
- Flutter notification tests cover foreground display, duplicate suppression,
  excluding OneSignal-owned messages, navigation and backlog cleanup.
- Live test notification `4d43fd8b-fc4c-451f-ba6a-1c80ecb1afdc` was accepted once
  for each of the two registered devices. Repeating the request returned the
  same provider IDs (`26c487a8-a109-4d45-bb75-6bf6ef939c74` and
  `eea12a51-7340-4176-be0d-b5044d3b9fbb`), with no FCM send.
- The connected device received that message, but its initial display was
  blocked by the existing notification backlog. Do not describe this initial
  test as confirmed display on both phones.
- The owner confirmed receiving exactly one `KeepSIMs notification check` on
  the separate physical phone. This confirms physical display for the backend
  fix, independently of the connected device's backlog.
- `127.0.0.1:16384` and `emulator-5554` have the same Android ID; they are two
  connections to one device, not two independent device verifications.
- Final debug APK installed successfully, preserving app data. At 05:06 Muscat
  time, test `284d5ec4-2948-4e2d-810b-634c2b5198db` produced exactly one Android
  notification record (`2046780935`) on `ks_confirmations_v1`, importance 2,
  while `com.keep_sims/.MainActivity` was the top resumed activity. The old
  backlog was gone. Both registered devices were accepted through OneSignal,
  with no FCM fallback. Foreground FCM fallback was verified by automated tests,
  not by deliberately breaking a live provider.
- Final validation: 9 backend tests and 22 distinct Flutter notification tests
  passed; the changed Dart services pass analysis without issues.

The final APK is `build/app/outputs/flutter-apk/app-debug.apk`; older release APKs
from intermediate verification do not contain the final restoration-cache fix.
It is a locally signed test build. This workspace has no production signing
key. Foreground behavior on the physical phone still needs the updated app.

References: [OneSignal Create Notification](https://documentation.onesignal.com/reference/push-notification),
[Firebase foreground messages](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
