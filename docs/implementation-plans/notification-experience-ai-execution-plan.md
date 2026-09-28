# KeepSIMs notification experience — AI execution plan

Prepared: 16 September 2026. Status: implementation specification; no application or production changes made by this planning task.

## 1. Outcome

Make each notification answer three questions immediately: **What happened? Which number? What should I do next?**

Deliver clearer Android notification artwork, concise intent-based messages, accurate dates, appropriate urgency, reliable taps, and consistent in-app presentation. Arabic and English are required. Preserve other supported app languages with an explicit English fallback for new push templates until translated.

Success means a newly added number produces a concise confirmation based on saved state; an urgent recharge issue is visually distinct and uses the urgent Android channel; tapping either opens the correct authenticated destination.

## 2. Execution rules and scope

- Read applicable repository instructions and relevant skills before work. Re-read the working tree: this plan records a local inspection, not a live-production audit.
- Preserve existing uncommitted work. The app, notification repository, dispatcher, translations, and scheduling code already have changes. Record baseline diffs and tests; never reset, overwrite, or stage unrelated changes.
- Work in the current project unless isolation can include its existing required changes. A clean worktree from HEAD alone could omit dependencies.
- Implement through the checkpoints below. Keep a short progress/evidence document alongside this plan. Explain evidence-based deviations.
- Use deterministic templates and event rules; do not add an AI service to generate notification text at runtime.
- This document plans implementation; it does not itself authorize sending customer notifications, charging for real recharges, or releasing to production. During a later implementation task, follow the user's deployment authorization and project rules.
- Do not redesign payment execution, carrier intervals, subscription entitlements, or the unrelated messaging channels. Adapt their notification producers only as needed.
- Android is the visual acceptance platform. Shared payload and localization changes must preserve existing iOS behavior; do not claim custom Android icons work on iOS.
- Exclude advertising banners, full-screen intents, alarm/call impersonation, repeated buzzing, forced DND bypass, and a custom notification layout. Use the platform template.

## 3. Verified local starting point

| Component | Observed behavior | Required work |
| --- | --- | --- |
| `lib/features/sim_lines/presentation/controllers/sim_lines_controller.dart` | Hardcoded English `Welcome to KeepSIMs`; full phone number; interval-only copy. Reminder save returns a Result which is not checked before sending confirmation. | Use the actual saved outcomes, event type, and next scheduled date. |
| `lib/features/notifications/data/repositories/notifications_repository_impl.dart` | Inserts into `notifications`; emits `/sim_lines/{id}` as action URL. | Structured metadata and canonical destination; preserve preferences. |
| `supabase/functions/dispatch-alert/index.ts` | OneSignal primary, FCM fallback. Already specifies `large_icon: launcher_icon` and `small_icon: ic_launcher_foreground`; English-only payload; no OneSignal navigation data or explicit Android channel. | Dedicated artwork, typed presentation policy, localized payload, channel, navigation, and delivery safeguards. |
| `lib/main.dart` | Initializes OneSignal. No `addClickListener` or `addForegroundWillDisplayListener` found in the inspected `lib` tree. | Add lifecycle-safe click handling after verifying SDK API. |
| `lib/core/router/app_router.dart` | Line detail route is `/sim-lines/detail/:id`. | Resolve typed notification targets to this route; support old payloads safely. |
| `notifications_screen.dart` | Category-based colors/icons; line taps use correct route. | Reuse event presentation and navigation policy; retain legacy fallback. |
| `notification_model.dart` | Existing category/title/body/action URL, but no typed event metadata. | Add backward-compatible fields as required. |
| `locale_provider.dart` / `user_preferences_model.dart` | App locale stored locally; server preferences also have language. | Reconcile these sources for server-sent push. |
| Notification migrations | Several generations of dispatch trigger, including H4 channel catalog gates. | Inspect the latest effective definitions; do not recreate the older C1 trigger verbatim. |

Important: the screenshot does not establish the phone's Android version, actual channel settings, or installed icon resources. Verify them on the real test device.

The worker source of truth is `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt`, per `.agents/AGENTS.md`. If worker changes prove necessary, inspect instructions there and modify/test that authoritative checkout. Its files are at the checkout root. Do not assume the `servers/` mirror in this repository is authoritative. Authorized worker deployment uses direct SSH/SCP from that checkout, remote syntax checks, and the relevant PM2 restart. Supabase Edge Functions have a separate deployment path.

## 4. Product decisions

### 4.1 Visual language

- Small icon: a dedicated, recognizable SIM outline using an opaque white shape on a transparent background, optimized for notification scale. Use a native vector or platform-compatible generated assets, with no tiny lettering or excessive padding.
- Large icon: simple bundled status artwork: success/check, reminder/bell, warning/triangle, failure/error. Use consistent shape weight and generous internal legibility. Bundle platform-compatible resources in the app; do not require downloading images to show an alert.
- Recommended resource names: `ic_stat_keepsims`, `ic_notif_success`, `ic_notif_reminder`, `ic_notif_warning`, `ic_notif_error`. Verify supported formats and density variants with the installed SDK.
- Title starts with exactly one symbol: ✅ success, 🔔 reminder, ⚠️ warning, ❌ confirmed failure. Add meaningful words; meaning must survive monochrome rendering and screen-reader output.
- Keep KeepSIMs branding in the OS app header. Avoid repeating the brand in each title.
- Do not promise a larger OS header icon. Android/Samsung chooses its size and position. A separate large icon may improve visibility but must be tested collapsed and expanded.
- In-app cards use the same intent, with theme-aware accessible colors and an icon plus text. Avoid duplicate emoji decoration if the card already renders a status icon.

### 4.2 Copy rules

- Target title length: roughly 20–40 visible characters; body: one or two short sentences. Treat this as an editorial target, not a hard character truncation rule for translations.
- Put event and line identity first. Prefer `{nickname} · {last4}`; fallback `Line ending {last4}`. Sanitize user nicknames, normalize whitespace, and limit their display length without splitting Unicode characters.
- Default to masked numbers in push. Add an explicit full-number push preference, off by default. Changes affect future notifications; do not claim to erase previously delivered content.
- Show the next actual reminder or recharge date from persisted state. Do not calculate a fresh date by adding the interval again in the sender.
- Persist timestamps in UTC; format using a known user IANA timezone. Sync device timezone with preferences; handle travel updates. If timezone is unknown, avoid a potentially wrong relative-day claim and use an explicitly qualified date/time or omit it.
- Make the absolute date authoritative. Only include “in N days” when computed from local calendar dates at send time. Omit the relative phrase for significantly delayed or stale messages.
- Distinguish reminders, scheduled automatic recharge, and confirmed recharge. “Number added” never means the carrier has verified activation or protection.
- Only show amounts/currency from authoritative recharge data. Do not infer carrier expiry or deactivation from the reminder interval.
- If data is missing, use an honest shorter message. Never ship placeholders, `null`, raw error traces, or an invented next date.

### 4.3 Event catalog and templates

Existing preference categories remain compatibility keys. Add an independent `event_type`; do not rename existing categories without migrating their settings and consumers.

| Event type | Existing category mapping | English title | Body template / factual condition | Priority |
| --- | --- | --- | --- | --- |
| `line_added` | `system` | ✅ Number added | `{line}. Next recharge reminder: {date}.` Only after reminder save succeeds. | Quiet |
| `auto_recharge_scheduled` | `system` | ✅ Auto-recharge scheduled | `{line}. Next automatic recharge: {date}.` Only after an active auto-recharge schedule is saved. | Quiet |
| `line_setup_incomplete` | `system` | ⚠️ Finish setting up your number | `{line} was added. Open KeepSIMs to finish setting up reminders.` Adapt for the failed setup step. | Normal |
| `recharge_succeeded` | `top_up_success` | ✅ Recharge successful | `{line} was recharged with {amount} {currency}.` Confirmed provider/business success only. | Normal |
| `recharge_reminder` | Reuse verified reminder category | 🔔 Recharge due in {days} days | `{line}. Recharge by {date}.` Only where that due date is supported; otherwise say “Recharge reminder: {date}.” | Normal |
| `recharge_due_today` | Reuse verified reminder category | ⚠️ Recharge due today | `{line}. Open KeepSIMs to review your recharge.` Do not issue if already completed or superseded. | Urgent |
| `recharge_failed` | `top_up_failed` | ❌ Recharge failed | `{line}. Open KeepSIMs to review the issue.` Urgent only when user action is required now; automatic recovery pending is normal. | Conditional |
| `wallet_low` | `wallet_low` | ⚠️ Wallet balance is low | `Add funds before {date} for {line}.` Only when the next recharge and shortfall are known. | Normal |
| `recharge_blocked_funds` | `wallet_depleted` | ⚠️ Recharge needs funds | `{line}. Add funds to continue your recharge.` Confirm a current blocked operation. | Urgent |
| `line_critical` | `line_critical` | ⚠️ Your number needs attention | `{line}. {verified reason and next step}.` Do not assert loss/expiry without evidence. | Urgent |

Arabic baseline examples (localize complete sentences, never concatenate translated fragments):

| English title | Arabic title | Arabic body example |
| --- | --- | --- |
| ✅ Number added | ✅ تمت إضافة الرقم | الرقم المنتهي بـ {last4}. تذكير الشحن القادم: {date}. |
| ✅ Auto-recharge scheduled | ✅ تمت جدولة الشحن التلقائي | الرقم المنتهي بـ {last4}. موعد الشحن التلقائي القادم: {date}. |
| ⚠️ Finish setting up your number | ⚠️ أكمل إعداد رقمك | تمت إضافة الرقم المنتهي بـ {last4}. افتح KeepSIMs لإكمال إعداد التذكيرات. |
| ✅ Recharge successful | ✅ تم الشحن بنجاح | تم شحن الرقم المنتهي بـ {last4} بمبلغ {amount} {currency}. |
| ⚠️ Recharge due today | ⚠️ موعد الشحن اليوم | الرقم المنتهي بـ {last4}. افتح KeepSIMs لمراجعة الشحن. |
| ❌ Recharge failed | ❌ تعذّر الشحن | الرقم المنتهي بـ {last4}. افتح KeepSIMs لمراجعة المشكلة. |

Supply Arabic templates for every enabled event, including plural rules. Test mixed Arabic, Latin nicknames, dates, currency, and phone digits using bidi isolation. Review on-device rendering and have a fluent reviewer check final copy where available.

### 4.4 Android priority policy

Use app-created, localized channels with stable IDs:

| ID | User-facing name | Android importance | Default behavior |
| --- | --- | --- | --- |
| `ks_confirmations_v1` | Setup confirmations | LOW | Quiet, no vibration |
| `ks_updates_v1` | Recharge updates | DEFAULT | System default sound; no forced pop-up |
| `ks_urgent_v1` | Urgent recharge alerts | HIGH | Sound, normal vibration, heads-up eligible |

Create channels before receiving v2 messages. Use OneSignal `existing_android_channel_id` for these app-created IDs; do not confuse it with `android_channel_id`, which references OneSignal dashboard categories. Android DEFAULT is called High in the OneSignal dashboard; Android HIGH corresponds to its Urgent setting. [OneSignal channel reference](https://documentation.onesignal.com/docs/en/android-notification-categories)

Android visual importance and transport delivery priority are separate. Select expedited provider/FCM delivery only for time-sensitive, visible alerts. Normal confirmations use normal transport priority. Neither setting guarantees delivery time or a banner. [FCM priority reference](https://firebase.google.com/docs/cloud-messaging/android-message-priority)

Honor Android settings, DND, category opt-outs, app channel switches, entitlements, and operator channel controls. Do not create new channel IDs to circumvent a user mute. Existing Android channel importance cannot simply be overwritten; document upgrade behavior.

Inspect existing quiet-hours enforcement. Preserve it; if stored quiet hours currently have no enforcement, implement a reliable scheduled deferral using the existing scheduler/outbox rather than sleeping in an Edge Function. Default: all events respect quiet hours; no new urgent override switch in this release. Revalidate deferred urgent events at dispatch and discard resolved/stale alerts. Handle overnight windows, DST, timezone changes, and absent timezone explicitly.

## 5. Data and rendering design

### 5.1 Event contract

Extend existing notification storage additively with the smallest required fields after inspecting the schema. Proposed logical contract:

```text
schema_version: 2
event_type: known enum-like string
notification_id: persistent UUID
source_event_key: stable business event identity
sim_line_id: optional owned line UUID
occurred_at: UTC timestamp
scheduled_at / expires_at: optional UTC timestamps
template_version: integer
template_data: validated event-specific facts
target: allowlisted destination + entity ID
```

Preserve `category`, `title`, `body`, and `action_url` for old clients. Store a resolved, localized title/body snapshot so the in-app history matches the sent message. Historical messages do not silently change when the user later changes language.

Derive intent, icon, channel, and permissible actions server-side from the event and current trusted facts. Never accept client-provided arbitrary urgent priority, resource URLs, foreign user IDs, or payment state. Reuse a server-owned event creation path/RPC where available; otherwise add an ownership-checked entry point for setup events.

Use a single versioned presentation catalog, with generated/validated client mappings if needed. Avoid independently maintained switch statements drifting between Dart, SQL, and TypeScript. A practical arrangement is an authoritative server renderer and a compact client intent/icon map validated against the same fixtures.

Update the latest effective insertion/dispatch path to carry metadata. Render before external sending and persist a consistent snapshot without causing a second insert-trigger send. Keep legacy records readable. Legacy known categories get a documented conservative presentation fallback; unknown categories stay normal priority with their existing text.

### 5.2 Language, privacy, and compatibility

- Use the user's selected app language as the server push language. Sync it to existing preferences; do not let device-language targeting unexpectedly override it. Account preference is the default across devices.
- New privacy/timezone fields require validated defaults and backward-compatible reads. Keep service credentials on the server and ownership checks/RLS intact.
- Send only identifiers needed for navigation, masked display text by default, and allowlisted action IDs. Escape generated text appropriately for any existing HTML/Markdown delivery adapters touched by the change.
- Record a per-install capability/version marker after channels/resources are installed. A user can have an old and new device simultaneously: do not blindly alias-broadcast v2 resource names to every device. Partition by supported capability or send compatible settings to all until adoption is verified.
- Keep legacy payload rendering available behind a server rollout flag. New payload fields must not break older app deserialization.

## 6. Implementation checkpoints

### N0 — Baseline and producer inventory

1. Record current app/backend diffs and relevant test outcomes.
2. Trace app insert → current trigger → dispatch-alert → OneSignal/FCM; enumerate recharge, wallet, line-status, and reminder producers.
3. Inspect installed OneSignal/Flutter versions and Android min/target SDK, actual drawable/mipmap resources, token registration, schema, preference gates, and existing schedulers.
4. Record category-to-event mapping and actual test-device Android/Samsung versions. Distinguish local observations from live checks.

Exit: writer map and compatibility notes exist; no production writes required.

### N1 — Event contract, templates, and truthful setup

1. Implement the additive contract and deterministic EN/AR catalog, including fallback and privacy rules.
2. Check `Success`/`Failure` from reminder and auto-recharge schedule saves. Use returned persisted dates, not optimistic inputs.
3. Emit one appropriate setup confirmation. For Premium, prefer the automatic-recharge confirmation when it is valid; do not send two competing confirmations for the same user operation.
4. If the line is saved but scheduling fails, preserve the line and payment state, show the incomplete-setup message, and provide a safe resume path. Never retry a charge just to repair a notification.
5. If notification creation fails, do not make the already-successful number addition look failed or encourage creating a duplicate line. Log and use the existing retry/outbox path, with a stable event key.
6. Adapt trusted producers to structured events and preserve meaningful unsupported legacy text.

Exit: tests demonstrate no false success, no duplicated setup event, accurate saved dates, and correct plan-specific copy.

### N2 — Icons, channels, and sender

1. Add dedicated small and large Android resources. Verify release packaging/shrinker retention, supported formats, and monochrome small-icon rendering.
2. Register the three channels natively at app startup; preserve `MainActivity` eSIM functionality. Localize names/descriptions without resetting behavior.
3. Add validated OneSignal payload fields for icon/channel, title/body, typed data, IDs, supported buttons, TTL, and stable idempotency key. Check the installed SDK and current REST schema rather than copying assumed parameters.
4. Bring FCM fallback to functional parity for text, small icon, importance channel, priority, entity IDs, expiry, and click routing. Large-icon/button parity may require native handling; document visual differences. Do not introduce a second renderer that duplicates OneSignal notifications.
5. Preserve the current rule that an accepted OneSignal response with ID and no errors is not considered a failure merely because immediate recipient count is zero.
6. Handle ambiguous timeouts as unknown acceptance: bounded retries with the same provider idempotency key before cross-provider fallback. Do not claim exactly-once delivery from an HTTP timeout. Reuse logical notification IDs and test duplicates across both providers.
7. Apply preferences consistently. Investigate and fix the empty-channel push fallback if it bypasses explicit global user opt-out; distinguish “never configured” from “disabled.” Keep tier/operator/category gates intact.

Exit: inspected payload fixtures pass; resources/channels are present in a release build; normal/urgent routing works without bypassing opt-outs.

### N3 — Navigation and foreground behavior

1. Add one app-scoped OneSignal click listener through a dedicated service; avoid listener duplication on widget rebuild.
2. Resolve a typed line target to `/sim-lines/detail/{id}`; map legacy `/sim_lines/{id}` only after validation. Wallet events can use the existing wallet route.
3. Queue cold-start taps until initialization, sign-in, and biometric unlock are ready. Clear pending taps on logout/account switch. Validate ownership before loading the entity.
4. Deleted/inaccessible line: open Notifications with a localized explanation. Invalid payload: safe fallback, no arbitrary URL execution.
5. Mark the notification read after intentional opening, not delivery. Keep opening/read handling idempotent.
6. Foreground success may use the app's existing feedback without an extra intrusive banner; foreground urgent events remain visible. Use SDK-supported suppression only when equivalent feedback is actually shown.
7. For FCM fallback, verify background and cold-start taps via its actual native/Flutter path. Do not assume a OneSignal listener receives raw FCM taps.

Exit: foreground/background/cold-start and authentication tests route to the correct owned entity once.

### N4 — Actions, preferences, and in-app alignment

1. Align in-app icon/color/text with the event catalog while preserving filters, read status, and legacy records.
2. Add full-number push visibility setting and links to Android notification/channel settings; explain that device controls determine sound/banner behavior.
3. Body tap opens relevant details. Useful optional buttons: `Review recharge` for failures, `Add funds` for insufficient balance, `Remind tomorrow` for early reminders. Avoid buttons that merely duplicate body tap.
4. Buttons open an authenticated screen or confirmation flow. They never directly initiate a charge. Do not use “Recharge now” if it bypasses existing quote/approval safeguards.
5. Implement “Remind tomorrow” only with a persisted, ownership-checked, idempotent reminder action. It changes the reminder, not the recharge execution date. Disable it when tomorrow would pass the real deadline or when the event is already resolved. If this dependency is unavailable, omit the button and record it as deferred; do not ship a dead action.
6. Group related notifications by line without collapsing different urgent events together. Deduplicate identical business events using a stable source key; allow legitimate later state transitions.
7. Reuse existing notification preferences for existing categories. Add only the necessary new settings; no notification-settings redesign.

Exit: settings survive restart; buttons work honestly; line events remain distinguishable; no payment behavior changes.

### N5 — Verification and release preparation

Run the matrix below, fix regressions introduced by this work, and produce an evidence report with build identifier, tested device/OS, screenshots, payload samples without personal data, and remaining limitations.

## 7. Verification matrix

| Layer | Required coverage |
| --- | --- |
| Template/unit | Every event; EN/AR; missing nickname/date/amount; long Unicode nickname; masking; relative dates near midnight/DST; reminder vs auto-recharge; unknown event fallback. |
| Setup | Reminder save success/failure; Premium partial save; existing draft path; offline retry; notification failure after successful add; operation replay does not duplicate line, charge, or notification. |
| Database | Additive migration; old records/client reads; ownership and RLS; category/operator/tier gates; explicit push disable; idempotent source keys; dispatch trigger does not recurse/double-send. |
| Dispatcher | OneSignal accepted with unresolved recipients; explicit rejection; 429/retry; ambiguous timeout; FCM unavailable/invalid token/partial success; metadata and channel mapping; TTL and resolved-event suppression. |
| Navigation | App open/background/terminated; signed out; biometric lock; account switch; deleted line; legacy link; malicious/unknown action; raw FCM tap; repeated callback. |
| Device visual | User's Samsung device plus an available stock Android reference; collapsed/expanded/lock screen; light/dark; enlarged font; EN/AR; offline icon resources; no clipping or white-square small icon. |
| Urgency | Quiet confirmation, normal update, urgent failure; channel muted; notification permission denied; DND; quiet hours across midnight; battery/Doze behavior; no false claim that banners are guaranteed. |
| Compatibility | Old/new app installs on one account; existing channel settings after update; generated localization/model files; existing recharge and notification regression tests. |

Use focused Flutter tests/analyzer, TypeScript/Deno checks matching repository tooling, and database tests in a local/test environment. Existing C1 tests are historical references with fixed fixtures; do not blindly run them against customer data. For any real delivery test, use an explicitly designated test account/device and synthetic data. Simulate recharge outcomes without purchases.

Do not reset the user's real-device app data to make channels pass. Test a normal upgrade path; use a disposable test install for fresh-install checks. If hardware access is missing, complete automated/build checks and clearly mark physical-device validation as pending.

## 8. Rollout, monitoring, and rollback

1. **Additive server preparation:** schema support, legacy-compatible renderer/sender, capability tracking, and v2 flag disabled. Verify old requests still work.
2. **Client build:** package icons/channels, metadata readers, click handling, preference syncing, and capability registration. New-client requests must remain compatible while the flag is off.
3. **Test cohort:** enable v2 only for designated test recipients. Mixed-device accounts must use capability-aware targeting.
4. **Release:** under the actual implementation task's release authorization, enable a small cohort, then broaden after the acceptance evidence passes. Do not bulk-resend old notifications.
5. **Observe:** provider acceptance/error rates, duplicate event attempts, stale alerts skipped, navigation errors, and channel-specific outcomes where observable. Logs must distinguish provider acceptance from confirmed device delivery. Existing `delivered` labels are not proof that a user saw the message.
6. **Rollback:** disable v2 rendering/targeting, return to compatible legacy payloads, retain additive columns and history, and preserve the installed channels and users' settings. Do not destructively roll back business schedules or payments.

Avoid a new analytics system solely for this task. Extend existing delivery logging with event/template/channel/version identifiers where needed; redact tokens, full phone numbers, and secret material.

## 9. Definition of done

- [ ] Newly added numbers have concise, accurate, localized confirmation based on persisted schedule state.
- [ ] A partial setup never claims reminders or automatic recharge are active when they are not.
- [ ] Dedicated notification artwork is included and verified in the release build.
- [ ] Quiet, normal, and urgent channels work and respect user controls.
- [ ] Urgent messages require current, verified urgency; success and marketing are never routed as urgent by default.
- [ ] Push and in-app messages share consistent event meaning, and taps open the correct authenticated destination.
- [ ] Opt-outs, quiet hours, retry/fallback behavior, privacy defaults, and old-client compatibility are verified.
- [ ] No unapproved recharge, customer notification, or unrelated code change occurred during validation.
- [ ] Required automated checks pass; physical-device evidence exists or is explicitly listed as a remaining release gate.
- [ ] Final report separates implemented, tested, deployed, and deferred items, with rollback instructions.

## 10. Executor handoff prompt

> Implement `docs/implementation-plans/notification-experience-ai-execution-plan.md` in this KeepSIMs project. Start with N0 and proceed through the required checkpoints. Preserve all existing uncommitted changes and follow applicable repository/skill instructions. Implement the event catalog, accurate EN/AR messages, notification assets/channels, OneSignal/FCM payload handling, secure navigation, preference behavior, and focused tests. Make routine technical decisions without repeatedly asking for confirmation; record justified deviations and any optional deferred work. Validate the actual saved scheduling outcomes and avoid duplicate sends or charges. Build a reviewable result and report completed work, verification evidence, device checks still needed, deployment status, and rollback. This handoff covers implementation and controlled validation; follow the user's explicit release authorization for production deployment or external test sends.

## 11. Platform references

Consult current official APIs at execution time, particularly for the installed SDK version:

- [Android notification design](https://developer.android.com/design/ui/mobile/guides/home-screen/notifications) — OS-owned layout and optional large icons.
- [Android notification channels](https://developer.android.com/develop/ui/compose/notifications/channels) — importance and user control.
- [OneSignal icon requirements](https://documentation.onesignal.com/docs/en/notification-icons) — small/large resources and configuration.
- [OneSignal Android categories](https://documentation.onesignal.com/docs/en/android-notification-categories) — channel identifiers and dashboard terminology.
- [OneSignal push API](https://documentation.onesignal.com/reference/push-notification) — validate payload fields and idempotency support.
- [FCM Android delivery priority](https://firebase.google.com/docs/cloud-messaging/android-message-priority) — transport priority and Doze.
- [Supabase changelog](https://supabase.com/changelog) — verify relevant database/Edge Function changes before implementing. The markdown changelog endpoint was unavailable during planning.
