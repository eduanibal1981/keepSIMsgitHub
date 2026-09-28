# KeepSIMs calling: implementation prompt and evidence-based plan

Prepared 20 September 2026. Copy this entire file to the implementation executor. Companion acceptance guide: `calling-ecosystem-acceptance-tests-20260920.md` in this directory.

## 1. Your assignment

You are implementing the KeepSIMs calling experience in `C:\Users\abdal\Work\KeepSIMs\keep_sims`. Deliver reliable, understandable, attractive voice calling for travelers, expats and families. Fix the existing implementation before expanding it. Implement in the phases below, with reviewable changes and evidence at each gate; do not merely return another plan.

Read these inputs first:

- `C:\Users\abdal\Work\KeepSIMs\walkthrough.md` — a previous executor's account, not independent proof of deployment or device behavior.
- `C:\Users\abdal\Work\KeepSIMs\adding to calls.md` — desired additions, corrected and expanded by this prompt.
- Repository guidance, `ARCHITECTURE_RULES.md`, `DESIGN.md`, existing calling implementation and prior caller-ID plan.
- This prompt and its companion acceptance tests.

The working tree contains extensive existing modifications and new files. Inventory them and preserve the user's work. Do not reset, overwrite unrelated changes, recreate existing tables, or start a competing wallet/call stack. Follow the project's architecture boundaries for new work; reconcile the documented layer layout with the existing feature layout without a gratuitous full rewrite.

The deliverable is a production-capable implementation where dependencies permit it, plus explicitly identified disabled capabilities where they do not. Never substitute simulations, invented metrics, fake provider adapters, or static success screens for real functionality. Continue independent work when a provider account, physical device, number purchase or product decision is unavailable. Report that dependency precisely; do not label the affected phase complete.

Production rollout must follow the authorization and deployment rules in the execution session. Building this plan did not purchase DIDs, authorize arbitrary carrier spending, or deploy backend changes. If workers are needed, `.agents/AGENTS.md` identifies `C:\Users\abdal\Work\KeepSIMs\backend-sync-wt` as the authoritative worker checkout and direct SSH/SCP deployment workflow. Do not edit only the non-authoritative worker copy or assume a local file is deployed.

## 2. Assessment of the current implementation

This assessment is based on local source inspection. Live Supabase policies, provider configuration, deployed function versions, billing and handset behavior were not independently inspected. Reconfirm the findings against the execution baseline.

Good foundations to retain: separation of paid and app calling, explicit caller-ID preferences, ownership checks, server signature verification and timestamp checking, single-use media sessions, conditional destination-dial claims, provider command IDs, bridge-based connection state, server-side `finish_media_call` locking, and explicit stopping of WebRTC tracks. These are useful improvements, not proof that the whole system is ready.

| ID / priority | Local evidence | Required response |
|---|---|---|
| F01 / P0 trust | `lib/features/calling/presentation/screens/sip_diagnostics_screen.dart`: `_latencyMs = 38`, fixed codec/jitter/loss labels and “STUN Passed”; microphone meter uses `math.Random()`; `_toggleSpeakerTest()` changes UI for four seconds without playing sound. | Replace all asserted measurements with real observations or “Not measured.” Implement audible playback. A local loopback cannot certify a SIP trunk or a destination carrier. |
| F02 / P0 connectivity | `voip_calling_controller.dart` creates the session without an offer, later broadcasts an offer; `voip_signaling_service.dart` calls `subscribe()` without awaiting readiness. The receiver relies on a stored offer that can be null. | Durable negotiation, acknowledged channel readiness, replay/recovery and candidate buffering; late acceptance must work. |
| F03 / P0 incoming calls | `initiate-voip-call/index.ts` calls `dispatch-alert` with service authorization and `voip_payload`/`fcm_tokens`; dispatcher requires `x-keep-sims-secret` and a different notification payload. Non-success responses are not checked. Retrieved APNs VoIP tokens are not sent through an APNs path here. | Implement a compatible authenticated call-push contract with delivery outcomes. Do not remove the existing dispatcher's authentication to accommodate the caller. |
| F04 / P0 device lifecycle | `incoming_call_manager.dart` listens to foreground FCM; inspected `ios/Runner/AppDelegate.swift` has no PushKit registration/receive integration. A simulator proves only UI behavior. | Trace all native/plugin entry points; implement and physically validate foreground, background, cold start and locked-screen behavior. Record platform limitations honestly. |
| F05 / P0 privacy | `20260920000000_voip_internet_calling.sql` grants participant `FOR ALL` access to sessions. A participant can potentially alter identities/timestamps or delete records. Signaling channel construction is not marked private. | Participant-scoped reads, narrowly authorized server transitions, immutable identities, private signaling with actual membership policies. Validate deployed grants/configuration; a UUID topic is not authorization. |
| F06 / P0 money | `make-call/index.ts` falls back to $0.15/min when lookup fails and uses a flat $0.15 balance threshold. `CallMedia.ready()` calculates a provider time limit from total balance, not reserved spendable funds. Existing wallet holds/lots are not used on this path. | Fail closed on unknown rates. Atomic call authorization using existing wallet infrastructure; reserve funds against concurrent calls, purchases and refunds. Retain the provider cutoff as a backstop. |
| F07 / P0 settlement | `finish_media_call` locks the call and charges elapsed bridge time, but does not apply a full fee/minimum/increment tariff. Legacy CDR code has separate settlement logic. `debit_wallet_for_call` clamps balance to zero while recording the full amount and does not use funding lots. | One financial contract and consistent ledger/lot/hold settlement; preserve existing locking. Reconcile missing/reordered events rather than using “terminal” to permanently skip unfinished billing. |
| F08 / P0 lifecycle | VoIP active state excludes `connecting`; controller terminal list omits `missed`; end/decline release media after awaiting backend work. Old callbacks/timers can affect a new call. | Typed state model, global call/audio ownership, immediate local cleanup independent of networking, generation guards and bounded reconnection. |
| F09 / P1 networks | Caller can receive static TURN configuration, but receiver hardcodes public STUN. ICE candidates can arrive before remote description and errors are only logged. | Both peers receive short-lived TURN credentials; buffer ICE, implement restart/recovery and test forced relay and different networks. |
| F10 / P1 honesty/usability | Internet calling screen unconditionally shows “ONLINE,” exposes simulation controls and describes owned SIM lines as callable family contacts. A registered push token does not establish presence. | Honest availability, real family account linking/consent, useful empty states and debug-only simulation. |
| F11 / P1 abuse/concurrency | VoIP busy check is read-then-insert; end endpoint accepts arbitrary caller-supplied status within database constraints; lookup returns profile information by number. | Atomic admission/answer/end transitions; bounded inputs; discoverability settings, blocking and enumeration/OTP abuse limits. |
| F12 / P1 maintainability | Three `call-media.ts` copies currently have identical hashes, under `_shared`, `make-call`, and `telnyx-cdr`. | Choose one deploy-compatible source or deterministic generation with parity check, so fixes cannot diverge. |

Validation performed while preparing this plan:

- `node --test --test-isolation=none test/call_media_backend.test.cjs`: **14 passed, 1 failed**. Failure: “media and app answer in either order dial one destination with automatic bridge,” at line 68, expected zero provider calls after first event, actual one. Current `media_ready` sets `app_answered` and immediately allows destination dialing; the test still expects two events. Decide and prove the intended invariant before changing the test.
- Default Node test isolation was blocked by a process-spawn permission error; the no-isolation command ran the test code successfully.
- `flutter test test/features/voip_calling/ test/features/calling/` produced no result during the attempted run and was stopped. The walkthrough's 31 passing tests and clean analysis were **not reproduced** in this review.
- No real calls, number orders or production changes were made. Claims about a universal Android audio HAL deadlock fix need device evidence; stopping leaked tracks is necessary but does not prove that root cause or guarantee hot-restart safety.

## 3. Product promise and scope corrections

Use these principles in product copy, calculations and implementation:

1. **KeepSIMs-to-KeepSIMs:** “No KeepSIMs calling charge. Uses Wi-Fi or mobile data.” Network data/roaming charges may apply. Do not market an unconditional zero-cost service or promise HD audio without negotiated quality.
2. **Call phone numbers:** show the exact destination quote and billing rules. Do not guarantee worldwide availability or that gateway routing bypasses carrier restrictions. A shared gateway identifies the gateway, not a private callback number assigned to the customer.
3. **Receive your home calls over the internet:** replace “Zero-Roaming” as an absolute guarantee. Separate DID rental, incoming minutes, carrier forwarding, data and possible roaming charges. An Oman SIM forwarding to a US DID may be costly or unsupported. Select the home carrier and line before recommending a number; do not default everyone to US +1.
4. **Verified caller ID:** ownership verification is distinct from route eligibility and recipient display. Keep the user-selected identity unless they explicitly accept a fallback. Do not fabricate headers to circumvent provider or destination rules. Offer SMS or voice OTP only where supported; flash-call verification is a separate capability, not automatically equivalent.
5. **Savings:** use dated, sourced, comparable tariffs or explicitly user-entered estimates. Never hardcode “70–90% cheaper,” $1 DID rental, roaming prices, wallet non-expiry or carrier package expiry as established facts. A 45-second call under ordinary 60-second rounding bills 60 seconds, not 120. Compare 61 seconds to demonstrate a 120-second rounded duration.
6. **No second login needed to own a SIM, but a SIM is not a second app user.** Map a family line to an independently authenticated, consenting person before offering app calling. Do not silently convert an app call into a paid phone call.
7. Scope is voice. Video, conferencing, call recording of live conversations and consumer SIP credential distribution are not prerequisites. BYOD remains a separately gated later phase below.

## 4. Customer experience to build

Retain distinct call flows and existing deep links, but improve the information hierarchy:

- Main Calls area: **Phone calls**, **KeepSIMs calls**, **My numbers**. Enable My numbers only when number service is available. Put **Test audio** in a secondary help/settings entry; keep its route working. No developer vocabulary or workbench in release builds.
- Phone calls: comfortable dialpad, country picker, paste normalization, optional native contact picker, favorites and recent calls. Country is derived from numbering metadata; do not infer a ported subscriber's actual carrier from prefix alone.
- Pre-call sheet: name/normalized destination, selected caller ID, price/minute, billing minimum and increment, connection fee/tax where applicable, spendable balance, maximum authorized duration and explicit Call button. Show phone-call/app-call alternatives only when valid, clearly labeled, and explicitly chosen.
- KeepSIMs calls: linked contacts/favorites, privacy-aware search, missed calls and user-triggered invitation sharing. Permission refusal still permits manual numbers. Never upload the entire address book without a defined consent and privacy design.
- Active call: peer identity, truthful “Connecting,” “Ringing,” “Connected,” “Reconnecting” states; mute; audio output chooser; end; minimize; and DTMF keypad for PSTN IVRs. Add accessibility labels and correct native action integration. No disconnected buttons presented as working hold/transfer features.
- Minimized bar: safe-area aware, clear status and duration, restore/end actions, no tab obstruction. Place it in an appropriate overlay-aware UI structure; retain screen-reader labels and tooltips where supported.
- Completion: outcome, connected duration, billed duration, final charge/processing state, wallet receipt and one-tap repeat. Paid redial obtains a fresh quote. Failed calls explain the next useful action.
- My numbers: number, monthly price, renewal date, incoming tariff, status, forwarding readiness, voicemail and cancellation. Trial/limited-availability labels must match real entitlements.
- Travel setup: carrier/line compatibility → cost explanation → number acquisition/assignment → manual forwarding instructions → test call → verified working status → return-home disable reminder. Do not mark success from copying a code.
- Voicemail inbox: caller/date/duration, play/pause/seek, original-language transcript, optional translated text clearly labeled, unread state, delete and callback with a fresh quote. Low-confidence or failed transcription must not hide the recording.
- Reuse actual theme components and typography. Use cyan for primary actions, green for available/app calls and warm accents for setup information consistently with `DESIGN.md`; avoid copying WhatsApp branding. Support English/Arabic, RTL, long names, large text, TalkBack/VoiceOver and light/dark themes where the application supports them.
- Use progressive permission requests, clear loading/empty/offline states, retry without losing input, optional haptics and no excessive animation. Target 48 logical-pixel tap areas and accessible text/control contrast.

## 5. Phase A — baseline and release-blocking repairs

### A1. Reproduce and define state contracts

Inventory local/deployed migrations and function versions, package/plugin versions and provider capabilities. Produce a call-flow map for paid outbound, app outbound/inbound, DID inbound and voicemail. Distinguish what is implemented from what is deployed and physically verified.

Introduce a canonical state model with adapters for existing database values. Suggested conversation states: idle → preparing → inviting → ringing → connecting → connected → reconnecting → ending → ended; store terminal reason separately (declined, busy, missed, timeout, cancelled, failed, completed). Keep media state, provider-leg state and billing state separate. Define permitted actor/event transitions and terminal monotonicity. Migrate compatibly; preserve existing call history.

Use one app-wide coordinator to arbitrate PSTN, app calling and diagnostics. Default to one active conversation per user until explicit multi-call behavior is implemented. Lock participating users atomically, in deterministic order, with expiry/heartbeat recovery. A household wallet may serve multiple users only with independent financial reservations. An incoming invitation must not overwrite a current outgoing or connecting call.

Capture a generation/session token before every asynchronous step; ignore callbacks for replaced/ended calls. End locally in under one second on a healthy device even offline; detach microphone, audio routing and native UI independently of durable server cleanup. Persist retryable end intent, enforce server leases/timeouts and retry cleanup. Do not let an old cleanup dispose a new call's audio resources.

### A2. Repair app signaling and native incoming calls

Create session → authorize media config → persist versioned offer → send invitation, or an equivalent explicitly proven sequence. Store/retrieve offer and answer through participant-authorized operations with short retention. Wait for channel subscription acknowledgement before sending. Carry session ID, negotiation revision and message ID. Buffer ICE until the matching remote description exists; replay or use a durable candidate exchange where needed. Keep SDP, ICE addresses and TURN credentials out of ordinary logs.

Make channels private and enforce membership for both sending and receiving. Inspect project Realtime settings and policies; table RLS alone does not secure Broadcast. Use short-lived authenticated TURN access for both peers, including TCP/TLS relay where supported. Do not issue shared permanent relay credentials. Define bounded ICE restart and reconnect deadlines; terminate clearly on failure.

Use a dedicated authenticated call-push service or explicitly compatible dispatcher extension. Maintain an outbox/retry record and inspect provider response codes. Push accepted by provider is not proof of handset ringing. Use Android high-priority call-appropriate delivery and actual Telecom integration where supported by the selected plugin/OS. Implement iOS APNs VoIP delivery, PushKit registration/token rotation, native CallKit reporting and audio-session activation. Verify native plugin capabilities before assuming a full-screen notification implements all Telecom features.

Handle token refresh, login/logout, account switching, device removal, cold-start answer and native hangup. Use short invitation expiry and call IDs to deduplicate push/realtime deliveries. Cancel all sibling-device invitations when one device accepts or the caller cancels; first accepted device wins via an atomic claim. Validate session availability when answering a delayed push. Respect platform restrictions on force-stopped apps instead of promising universal wake-up.

### A3. Repair diagnostics and lifecycle regressions

Measure microphone energy from actual captured audio/stats; silence must not animate a fake signal. Ship a real bundled chime and route it through the selected output. Offer separate local playback/loopback and network-quality checks. Label network stats with scope, timestamp and source; unavailable values display “Not measured.” Never turn missing stats into a green pass.

Local tests incur no KeepSIMs call debit and never invoke PSTN dialing. Run mic/echo tests exclusively, stop all tracks/peers/renderers/timers on exit, and handle permission/lifecycle interruptions. Test repeated start/stop, leaving during initialization, real calls after diagnostics and diagnostics during a call. Keep simulation gated out of release builds.

### A4. Secure identities and transitions

Replace broad client session writes with validated operations. Allow only the callee to accept and only participants to perform permitted termination actions. Set authoritative timestamps server-side. Prevent changing participants, reopening ended calls, deleting financial records or forging duration. Enforce payload size, UUID/phone validation, request rate limits and bounded history pagination.

Protect phone lookup with discoverability consent, block lists, exact normalized lookup, minimum useful input length, throttling and minimal returned fields. Tokens do not establish “online.” Use invitation links for users who opt out of phone discovery. Revoke unnecessary default RPC execution privileges, test anonymous/other-user access and review security-definer search paths. Remove direct-write fallbacks that bypass the new transition contract.

Gate A: F01–F05, F08–F11 have regression tests and required device evidence; no fake diagnostics, unauthorized signaling or indefinite call setup. Resolve the existing Node test failure through a documented readiness invariant and behavioral tests, not merely changing an assertion.

## 6. Phase B — outbound calling, quotes and money correctness

### B1. Quote and caller-ID contract

Extend existing `make-call`, `manage-caller-id`, `call_records`, `call_rates`, `user_caller_ids` and `user_caller_id_preferences`; do not create duplicate `call_logs` or `verified_caller_ids` just because the draft suggested them.

Issue a server quote containing opaque quote ID, expiry, normalized destination, eligible route class, requested/effective caller ID, currency, retail tariff version, connection fee, minimum, increment, tax policy and budget/max duration. Bind it to the user. The server reloads authoritative values on authorization; client-supplied rates, balances, durations and identities are never trusted. Expired or changed quotes require an updated confirmation. Missing, stale or ineligible rates block paid dialing with an actionable message.

Represent verification as user-bound challenges with expiry, attempt limits, resend cooldowns, provider status and re-verification/revocation. Guard concurrent challenges to the same number across accounts. Provider-account verification must not automatically grant every KeepSIMs user that number. Revalidate caller-ID ownership and route eligibility on every call. Preserve explicit gateway selection and never silently replace a selected identity. Document that shared-gateway callbacks are not automatically delivered to the original caller.

Complete DTMF against the actual PSTN media/provider path, verified by an IVR fixture. Normalize local numbers using explicit country context; reject ambiguous, emergency, premium or unsupported destinations according to the supported product. Explain emergency-call limitations and offer the native dialer where appropriate; do not send live emergency test calls.

### B2. One billing specification

Use exact database numeric arithmetic or integer subunits, not JavaScript/Dart floating point as the ledger authority. Keep wholesale cost and customer tariff separate. Snapshot retail terms at authorization and apply the same formula in quotes, live estimates, settlement and receipts.

For an answered call under the proposed tariff convention:

```text
d = ceil(nonnegative authoritative billable connected milliseconds / 1000)
billed_seconds = minimum_seconds
               + ceil(max(0, d - minimum_seconds) / increment_seconds)
                 * increment_seconds
charge = connection_fee + rate_per_minute * billed_seconds / 60
```

With no minimum use zero; validate increment > 0. Explicitly define zero-duration answered calls and any exceptional provider schedule. Connection fee applies on the disclosed answer event, never just an invitation. Apply final currency rounding and taxes once using the documented policy; retain finer internal precision for audit. Do not round each second separately. Unanswered app/phone calls have no customer conversation charge under this product policy; track unavoidable provider setup costs separately.

For existing paid outbound, keep the distinction between the app leg answering and the destination actually connecting. Define and reconcile the eligible media/bridge interval against provider evidence; a generic SIP answer, early media or client timer must not start customer conversation billing. DID ingress may incur provider costs before the user answers: either disclose a separately defined ingress tariff or have KeepSIMs absorb those costs. Do not apply an outbound rule silently to voicemail or inbound calls.

### B3. Wallet authorization and settlement

Inspect `wallet_holds`, `wallet_hold_allocations`, funding lots, `reserve_wallet_funds`, `capture_wallet_hold`, `release_wallet_hold` and later migrations. Extend them transactionally for variable final call amounts and partial release; do not assume existing full-hold capture supports this. Preserve funding-lot/refund restrictions and ledger accounting for every wallet consumer.

Recommended first release: reserve a disclosed maximum call budget once; compute an affordable provider-enforced cap accounting for fee/minimum/increments/tax; release unused reservation on completion. Show declining estimated spendable funds, clearly distinguish estimates/holds from final charges. A top-up during a call increases wallet funds but does not silently increase that call's authorized cap. An optional “Extend call budget” action can atomically reserve more and update the provider cap if the provider safely supports it. Do not run one long Edge Function or one database debit per second.

All competing spending/refunds must honor holds. Budget authorization is atomic with idempotent call intent creation and unique user/request key. PSTN side effects use stable provider command IDs. Ambiguous timeouts enter reconciliation, not a fresh blind dial. The `media_ready` signal must be authenticated, session-bound, one-use and adequately validated; do not invent a provider answer timestamp from a client assertion. Recover delayed provider webhooks with a documented provider-state query/retry path.

Keep independent provider cutoff and durable watchdog/reconciliation. Define measured termination latency and a server-funded safety allowance; customer debit must not exceed the authorized cap because a carrier ends late. Expired holds for uncertain active calls require provider reconciliation, not blind release. Use one transaction for final charge, ledger entry, lot consumption, hold capture/release and billing result. Do not clamp a depleted balance and record money that was never collected.

Retain and strengthen `finish_media_call`; audit legacy CDR traffic and migrate or adapt it to the same tariff/settlement rules. Distinguish call termination from settlement completion. Store authenticated webhook events in a durable inbox with unique provider/event key, claim/processing state and retryable failure. Verify raw-body signature/timestamp; reject invalid correlation. Tolerate duplicate, concurrent, delayed and reordered bridge/answer/hangup/CDR events. Quarantine contradictions and reconcile authoritative provider records before settling or create traceable corrections afterward.

Gate B: exact fixture charges match quote/history/ledger; concurrent purchases cannot spend reserved money; ambiguous calls cannot create duplicate legs/debits; app and diagnostic calls leave wallet unchanged. A final charge must never appear as settled before the transaction succeeds.

## 7. Phase C — DID numbers and home-call forwarding

### C1. Number lifecycle

Use current provider inventory and country/type requirements. Launch only supported, provisioned countries; do not claim Oman/UAE or bank acceptance because a country code exists. Store number ownership, provider IDs, capability/requirement status, prices/currency, renewal schedule and lifecycle: ordering, pending requirements, provisioning, active, suspension/grace, releasing, released, failed.

Quote setup/monthly/inbound fees and taxes before purchase. Make provider orders and wallet authorization idempotent; handle number-unavailable races and ambiguous orders through reconciliation. Never release funds while an order might still succeed without a recovery decision. One active assignment per DID. Enforce tenant isolation at inbound webhook routing. Authenticate caller presentation as provider-supplied information, not proof of the caller's identity.

Support renewal receipts/reminders, explicit auto-renew preference, insufficient-funds behavior, cancellation effective date and number-loss explanation. Provider release and wallet lifecycle must reconcile exactly once. Before release, help the user disable forwarding; the app cannot guarantee that their carrier forwarding was removed. Protect against reassigned-number traffic reaching an old account; purge old routing and storage access.

### C2. Inbound calls and setup wizard

Route DID ingress through authenticated provider events, authoritative DID ownership, app invitations and the existing native call/media coordinator. Choose and document whether ingress is held ringing or answered into a waiting flow; disclose resulting billing. No answered-but-silent dead air. Cancel invitations when the PSTN caller hangs up. Enforce inbound budgets and voicemail fallback when unanswered, offline or busy according to settings.

Maintain a versioned carrier capability matrix: country, carrier, prepaid/postpaid restrictions, line-selection instructions, unconditional/busy/no-answer/unreachable forwarding support, international-forwarding support, enable/check/disable instructions, charges/source/last verification. `**21*<number>#` is an example only, never a universal executable instruction. Verify exact codes with each supported carrier and device. Do not automatically execute forwarding or change SIM settings.

Prefer a compatible local DID where available and economically sensible. Show unsupported carrier/DID combinations before purchase. Explain forwarding cost separately from KeepSIMs receipt. Include dual-SIM selection, activation before departure, a real third-phone test, rechecking after network changes, forwarding loop protection, and return-home disable instructions. Offer a reminder only when the user chooses it. Block destinations that route back into the originating DID/forwarding loop.

Gate C: lifecycle and renewal tests pass; a real external handset reaches the intended account through a purchased supported DID and through a supported home-carrier forwarding path. No claim of $0 carrier charges without verified tariff evidence.

## 8. Phase D — voicemail and useful everyday features

Voicemail is enabled per number/account. Use a configurable timeout, default 20 seconds measured from the documented ringing event. Coordinate answer/timeout atomically so app answer and voicemail cannot both win. Define busy, declined, offline and do-not-disturb behavior explicitly. A greeting must clearly state recording is beginning. Obtain the necessary product consent and country-specific review before enabling recording in a new market; do not add live-call recording implicitly.

Authenticate recording events; fetch media server-side from approved provider locations, never arbitrary caller URLs. Use private storage, ownership policies, expiring download links, bounded file sizes, retention and deletion jobs. Track greeting/recording/transcribing/ready/failed states. Deduplicate recording/transcription events and invoice the documented inbound/voicemail tariff exactly once.

Detect original language or allow a preference. English and Arabic transcripts must preserve uncertainty; translation and AI summaries are optional, distinctly labeled and cannot invent names/numbers. Keep playback available if transcription fails, with bounded retry. Default push says “New voicemail” without sensitive transcript on the lock screen. Delete audio, transcripts and derived copies according to the documented retention policy.

Add missed-call history, favorites, linked family contacts, block/report controls, notification preferences and quiet hours. Explain when calls are silenced versus diverted to voicemail. No automatic invitations/messages. Keep data minimization and account deletion behavior consistent across contacts, call history and recordings.

Gate D: two-language voicemail, answer/timeout races, private playback and deletion pass the companion tests; active calling remains reliable.

## 9. Phase E — provider routing and honest savings

### E1. Quality-aware routing

Keep Telnyx working as the initial production provider. Define adapters for quoting/capabilities, verification eligibility, originate, status, terminate, DTMF, webhook normalization and reconciliation. Provider credentials stay on the server; never expose a trunk master credential. Decide where alternate carriers are controlled: compatible voice APIs or a managed SBC/B2BUA/media gateway. An LCR table alone cannot bridge a WebRTC app into an arbitrary wholesale SIP trunk.

Add IDT/Tata/BICS only with contracted access, verified APIs/SIP interconnects, approved identity/country policies and tested media paths. Without those dependencies deliver disabled configuration and adapter contracts, not success-returning mocks in production.

Eligible-route filtering precedes cost ranking: destination/type, CLI, regional permissions, codecs, capacity, health, minimum/increment/fees, margin and currency. Rank total modeled wholesale cost with quality thresholds, rather than nominal price/minute alone. Track answer ratio, setup delay, short-call rate, media failures and complaints with minimum sample sizes and privacy controls. Circuit-break failing routes; cap retries and provider exposure.

Failover is allowed only before connection and after proving the prior attempt cannot still ring/connect. Do not retry a declined/busy/no-answer subscriber on another carrier merely to force a connection. Ambiguous originates require status reconciliation. Never change customer identity, exceed approved price, or double-bill because of backend failover. Freeze the customer tariff; wholesale savings do not require a mid-call retail price change.

### E2. Savings calculator

Inputs: destination/type, usage as a distribution of call durations, comparator currency, package price/minutes/expiry/eligibility/rounding, incremental versus full-package cost basis, roaming context, dated FX rate, KeepSIMs tariff and optional DID costs. Show assumptions and source dates. An already-paid bundle can have zero incremental cost within remaining minutes; KeepSIMs must be allowed to lose the comparison.

Apply rounding per call, not to aggregate monthly seconds. Display absolute cost first, then savings only for positive valid comparisons. For zero comparator cost, show an amount difference without dividing by zero. Include forwarding/data costs as known or explicitly excluded, never silently zero. Mark expired comparison sources unavailable until refreshed. Savings content must not delay the basic call button.

Gate E: simulator-based routing failure tests plus real approved-provider interop pass; calculator fixtures are exact and marketing claims trace to sources.

## 10. Optional phase F — SIP phones and softphones

Do this only after core consumer calling gates pass and a business/power-user feature is approved. Do not distribute Telnyx trunk credentials as user credentials. Provision isolated per-user/per-device endpoints behind an authenticated policy-enforcing gateway, with rotation/revoke, device/session limits, TLS/SRTP where supported, destination limits, spend reservations, fraud monitoring and number ownership. Test inbound/outbound, native-app busy behavior and immediate credential revocation. Use the same billing/records policies. Keep disabled until infrastructure and support capability exist.

## 11. Data and API deliverables

Propose an additive migration map after inspecting the actual schema; exact new table names are design choices. Required concepts:

| Domain | Reuse / extend | Additional capabilities |
|---|---|---|
| Conversations | `call_records`, `voip_call_sessions`, media sessions | Unified identifiers/projection, state revision, deadlines, device acceptance claim, terminal reason, separate billing state |
| Rates/identity | `call_rates`, `user_caller_ids`, preferences | Tariff versions, route capabilities, quote snapshots, verification challenge history |
| Money | Wallets, lots, holds, allocations, ledger | Call budget authorization, variable capture/release, idempotent settlement/corrections |
| Providers/events | Existing webhook processing | Inbox/outbox, attempts, retry/reconciliation state, health and provider correlation |
| Numbers | Add only if absent | Inventory/order/assignment/subscription lifecycle, carrier guidance, verified forwarding status |
| Voicemail | Add only if absent | Private recordings, transcript jobs, retention and settings |
| People/preferences | Existing profiles/device identity | Discoverability, blocks, family links, favorites, call notification preferences |

Document request/response/error contracts for quote, authorize, cancel/end, accept/reject, media config, incoming push, number quote/order/cancel, forwarding check and voicemail playback/delete. Use stable machine error codes with localized user messages. Every mutating request carries appropriate idempotency, authorization and concurrency semantics. Version clients/server contracts for staged app releases. Add indexes justified by actual access patterns and secure grants/RLS/storage/realtime policies. Keep raw provider secrets, SDP and private media off customer-readable records.

## 12. Verification, rollout and definition of done

Use the companion manual guide as acceptance criteria. Add meaningful behavioral tests for state races, webhook permutations, wallet concurrency, authorization, signaling replay, TURN-only calls, push contracts and exact tariffs. Existing widget tests are necessary but insufficient. Run scoped static analysis, current Flutter tests, Node backend tests and real database transaction/RLS tests against staging. Verify real plugin behavior on physical Android and iPhone devices in release-like builds; macOS signing/device access is an explicit iOS dependency.

Create a results matrix with PASS/FAIL/BLOCKED/NOT RUN and evidence. A blocked physical test is not a pass. For performance, establish a healthy-network staging baseline, then use initial targets: local end response <1 s, no indefinite setup, no duplicate ringing, reconnect deadline <=15 s, app invitation ring timeout 45 s, voicemail default 20 s. Define paid setup timeout separately from provider ring timeout. Report measured percentiles and network conditions; these are acceptance targets, not worldwide guarantees.

Roll out flags separately for core repairs, new quote/billing contract, DID markets, voicemail, savings and alternate providers. Use additive expand/backfill/contract migrations. Old app versions either retain a compatible safe path or receive an upgrade-required response. Canary with owned/consenting destinations and a defined spend budget. Provide rollback of client/backend flags without losing billing records, pending orders or active-call settlement. Disabling call creation must still allow hangup, webhook processing and reconciliation.

Instrument call correlation, push accepted/device-ringing/answer/media timestamps, setup success, relay use, packet loss/jitter where measured, end reasons, authorization failures and unsettled balances. Alert on stuck sessions/holds, webhook failures, missing records and spend anomalies. Avoid raw phone numbers, tokens and transcripts in routine analytics. Include a user-visible support reference and a redacted diagnostic export.

At handoff deliver:

1. Changed-file and migration map; architecture/API/tariff decisions and feature flags.
2. Completed phase checklist with test artifacts, device/OS/build identifiers and factual limitations.
3. Updated walkthrough separating code, deployment, simulated tests and real-device evidence.
4. Screenshots of key English/Arabic journeys, exact sample receipts and real measured diagnostics.
5. Provider/configuration requirements, operating costs, rollout/rollback and recovery instructions.
6. Outstanding dependencies, each with a concrete missing item and the affected capability. Never say “all calling works” while these remain unverified.

## 13. Primary references checked for this plan

Recheck current versions at implementation time. These support technical constraints, not unverified country availability or retail prices.

- [Telnyx Voice API webhooks](https://developers.telnyx.com/docs/voice/programmable-voice/voice-api-webhooks): event delivery, signature validation and acknowledgement behavior.
- [Telnyx caller ID policy](https://support.telnyx.com/en/articles/3546251-caller-id-number-policy) and [verified numbers FAQ](https://support.telnyx.com/en/articles/6790265-verified-numbers-faq): number authorization does not justify arbitrary caller identity.
- [Telnyx number requests](https://support.telnyx.com/en/articles/3562148-requesting-numbers): inventory and requirements can affect fulfillment.
- [Supabase Realtime authorization](https://supabase.com/docs/guides/realtime/authorization): private channels and membership policies are required for restricted Broadcast access.
- [Apple PushKit incoming-call guidance](https://developer.apple.com/documentation/pushkit/responding-to-voip-notifications-from-pushkit): implement native incoming VoIP lifecycle correctly.
- [Android Core-Telecom](https://developer.android.com/develop/connectivity/telecom/voip-app/telecom): integrate a calling application with platform call/audio management.
- [Supabase changelog](https://supabase.com/changelog): check relevant changes before migrations and Realtime implementation; the markdown index could not be fetched during this review, so the HTML changelog was used.

No current carrier-specific forwarding code, DID price or regulatory eligibility was established in this review. Those remain required provider/carrier validation inputs, not assumed facts.
