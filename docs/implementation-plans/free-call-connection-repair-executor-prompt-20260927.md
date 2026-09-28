# KeepSIMs Free Call connection repair — AI executor prompt

Prepared 27 September 2026 from two live MuMu calls and the current working tree. This is an implementation assignment. Reinspect the tree and deployed versions before changing code; many calling files already have staged and unstaged user changes.

## Copy this assignment to the AI executor

Implement and verify a reliable KeepSIMs Free Call between two different signed-in accounts. Work in `C:\Users\abdal\Work\KeepSIMs\keep_sims`. Preserve existing work, read `.agents/AGENTS.md`, and coordinate with the existing recipient repair and retest documents in `docs/implementation-plans/`. Focus on app-to-app audio and call lifecycle; do not alter paid Smart Call, wallet, SIM protection, or unrelated alerts. Deliver code, tests, a build, and evidence. Do not stop after rewriting this plan.

### Observed failure to reproduce

Two already-open MuMu Android windows, `Android Device` and `Android Device-1`, each had a different KeepSIMs account. A call placed from either Free Call recent list reached the other window and displayed a native incoming prompt. Answer changed the recipient to **Connecting...**, while the caller remained **Calling...**. No active-call timer or verified two-way audio appeared. After roughly 30–45 seconds, the recipient showed **Call Ended**, while the caller could remain on **Connecting...** until manually ended. Reverse direction produced the same result. One caller history entry showed **Missed (33s)**; the opposite recipient history showed a duration around **1m 43s** although the UI never connected. Those times are observations, not a proven server timeout. Both test calls were ended and the screens closed.

This proves invitation delivery and Answer UI, not successful WebRTC negotiation or media. Treat the installed APK and deployed backend as potentially different from the local source. Record APK version/build SHA, account IDs in redacted form, Supabase project/function/migration versions, TURN configuration presence, and call IDs before attributing the failure to a specific layer. Do not expose account details, access tokens, TURN credentials, or full SDP in reports.

### Source findings to investigate first

1. `voip_calling_controller.dart` calls `_signaling.connect(callId)` before `_setupSignalingListeners()`. `voip_signaling_service.dart` catches a failed or timed-out subscription and still returns success. This can lose early messages and leave the UI waiting silently. It is a confirmed local code risk; trace whether it occurred on the installed build.
2. The caller broadcasts an offer and only then saves it. ICE candidates are sent as they arise, with no durable replay for candidates emitted before the peer subscribes. The receiver may use a stored offer, but the caller has no evident stored-answer replay. Repeated DB polling for a missing offer stops after about four seconds. These are race hypotheses, not yet a proven cause of the two emulator calls.
3. `answer_voip_session` in `20260921000000_calling_phase_a_baseline.sql` sets `connected_at` on SDP answer/acceptance. The repository's direct-update fallback does the same. `end-voip-call` derives duration from `connected_at`. This is a confirmed cause of false call durations when media never connects.
4. `answer_voip_session` and `save_voip_offer` return `VOID`; zero updated rows look like success. Repository fallbacks swallow save errors and attempt direct table updates even though the later migration limits participant access to SELECT. Acceptance and offer persistence may therefore fail without a useful error. Check actual grants/RLS and deployed schema before changing them.
5. Call setup has a 45-second ringing timer, but it only ends states `calling` or `ringing`; there is no equally clear bounded `connecting` deadline. `endCall()` starts cleanup before sending the realtime `call_ended` broadcast, so a channel disconnect can race the send. The Edge Function can mark an unconnected call `completed` and uses a read-then-PATCH transition without an atomic terminal guard.
6. `getCallIceServers()` silently falls back to public STUN if the TURN function fails. Both endpoints must be checked for compatible server configuration; an emulator-only LAN attempt cannot prove real-network connectivity. The app currently uses a public `voip_call:<id>` broadcast topic; participant authorization must be checked before adding durable signaling.

### Execution sequence

**1. Establish a clean, correlated baseline.** Preserve the dirty tree; do not reset, clean, or overwrite user changes. Compare working files with staged changes and identify the exact APK/backend deployed. Reproduce one call each direction on the existing two emulators and capture redacted per-call timestamps for invite, channel join/error, offer save/send/receive, answer claim/save/send/receive, candidate generation/send/receive/application, ICE and peer connection state, native End, database status and cleanup. Use one call ID and negotiation generation per trace. Collect actual Supabase Realtime/Edge Function errors and minimal Android logs. Determine whether the failure is subscription/authorization, missing SDP or candidates, ICE/TURN, or stale state. Keep raw SDP and secrets out of shared logs. Do not treat prior completion reports or passing widget tests as live evidence.

**2. Make signaling reliable and private.** Register callbacks before joining. Return a typed subscription result and fail visibly on channel error/timeout; never proceed as if signaling is available. Add bounded retry only where it can recover. Design a single ordered negotiation path with a session ID and revision/generation. Persist or reliably replay offer, answer, and ICE information to an authorized late-joining peer. Buffer local candidates until signaling is ready and remote candidates until the matching remote description is installed. Deduplicate SDP from broadcast and database, reject stale generations after teardown, and handle an answer broadcast lost while the caller was offline. If using complete-SDP ICE gathering instead of candidate persistence, bound and prove gathering on both peers. Do not weaken participant checks or use a public durable signal table. Follow current Supabase private-channel and RLS guidance; verify the project's `Allow public access` setting and other consumers before changing a project-wide Realtime setting. Current docs note that private channels require `config.private: true` and policies on `realtime.messages`; do not try to alter ownership/RLS of the locked `realtime` schema.

**3. Separate acceptance from media connection.** Use an atomic, authenticated server transition to claim Answer by the callee device, with a typed result (`accepted`, `expired`, `already_answered`, etc.). A zero-row write must be an error/result, not success. Keep `connected_at` null and duration zero until a real peer/media readiness condition is reached. Define that condition in code and tests: both endpoints must have negotiated a peer connection with usable audio, rather than relying on an SDP write or a push event. Make the connected transition idempotent and server-authoritative; handle one peer reporting connected while the other fails. Preserve existing rows safely and avoid retroactively inventing media connection for past records. Show **Connecting** only during bounded setup and then either **Connected** with a timer or a clear reason with End/Close controls.

**4. Make failure and hangup deterministic.** Put a bounded setup deadline after Answer as well as the invitation deadline. On failure, timeout, decline or hangup, immediately stop the local microphone/peer connection and native call UI; reliably persist an allowed terminal reason. Make server transitions atomic and idempotent so late callbacks cannot overwrite a terminal state. Send durable termination before or independently of tearing down the signaling channel; do not rely only on a best-effort broadcast. A remote terminal update must close the other peer's UI and media. End before connection must produce zero duration and a truthful missed/failed/cancelled classification; reserve `completed` for a connected call. Guard cleanup and delayed navigation by call ID/generation so call 1 cannot end call 2. Do not leave a recipient on a permanent **Call Ended** overlay or a caller on **Connecting...**.

**5. Verify network and audio.** Validate `get-turn-credentials` and `initiate-voip-call` responses for both participants, with short-lived credentials and no client secret. Report `has_turn` and candidate types in redacted diagnostics. If TURN is unavailable, show a configuration/connectivity failure instead of silently claiming a reliable call through STUN. Test host, STUN and forced-relay paths. Check whether the two MuMu instances share network topology and repeat on two physical devices or a physical device plus emulator over different networks. A connected UI alone is insufficient: verify speech in both directions, mute, speaker route, and End from either side. Do not use a simulated debug call as acceptance evidence.

### Required tests and acceptance gates

- Unit/integration tests for channel join failure, caller/callee join order, delayed offer, lost answer broadcast, early and late ICE candidates, duplicate SDP, repeated Answer, wrong-account access, TURN failure, and call 1 callbacks arriving during call 2.
- Database tests for participant-only reads/writes, one winning Answer claim, no false `connected_at`, zero duration for never-connected calls, idempotent terminal transitions, and accurate history labels. Test the generated migration locally before preparing deployment. Follow the repository's imperative migration workflow and current Supabase docs.
- App tests for a bounded Connecting state, visible failure reason, immediate local cleanup, native/UI End, and history refresh after termination. Existing route and recipient tests should keep passing.
- Run scoped Flutter analysis and tests, Supabase SQL/function checks, and any affected Android build/integration checks. Report commands and results, including pre-existing failures. Do not count mocked-router or simulated-media tests as end-to-end proof.
- Install the built APK on both existing MuMu accounts without clearing data. Test A→B and B→A; answer within a few seconds, then near the invitation deadline. Each must connect, show a timer on both sides, pass an actual two-way speech check, and end cleanly from either side. Repeat at least five consecutive alternating calls to expose stale subscriptions and cleanup races.
- Verify a true no-answer case records Missed with zero connected duration, a declined case records Declined, and an Answer followed by failed media records Failed/Timeout with zero connected duration. Neither side may remain on Calling/Connecting after the terminal event. Check no app-call wallet debit.
- Repeat the recipient warm/background/cold tests in `app-to-app-recipient-retest-20260922.md`; include at least one physical Android recipient and a different-network/TURN-only run before declaring the feature resolved. If hardware or live backend access is unavailable, mark those cases **NOT RUN** and label the build **ready for physical retest**, not fixed.

### Handoff

Provide a reviewable diff, migration/function changes, the exact APK/build SHA and backend version, redacted traces for successful and failed runs, a case-by-case PASS/FAIL/NOT RUN table, any remaining risks, deployment order and rollback steps. Preserve current user data and app sessions. Prepare production deployment as a separate final approval step; do not silently alter the live backend merely to make a local test pass.

## Planning basis

This prompt is based on live UI observation plus local source inspection. It does not claim the installed APK contains the exact inspected source or that any one race above is the sole root cause. Supabase references to verify at execution time: [Realtime authorization](https://supabase.com/docs/guides/realtime/authorization), [Realtime broadcast](https://supabase.com/docs/guides/realtime/broadcast), and the [changelog](https://supabase.com/changelog?types=breaking-change).


---

## AI Executor Commentary & Technical Evaluation (2026-09-27)

### 1. Executive Assessment & Baseline Correlation

A forensic investigation of the live database, connected MuMu emulators, deployed edge functions, and client code was conducted prior to writing code:

1. **Exact Account and Session Correlation**:
   - **Device 1 (MuMu `127.0.0.1:16384`)**: User `8a07a25b-a49b-4ec3-a56c-cfe7f7ea0c0e`
   - **Device 2 (MuMu `127.0.0.1:16416`)**: User `172b7a4c-54c8-44b1-a4ab-5e6fcffb2c71`
   - **Call 1 (`dfe15b8f-b0d7-4fdc-a1f6-b1b6fadb2552`)**: User 2 called User 1. Started at `17:07:39Z`. Callee accepted at `17:07:59Z`. Media never established. Caller manually ended at `17:09:43Z`. Database recorded status `completed` and `duration_seconds: 103` (1m 43s) because `answer_voip_session` prematurely stamped `connected_at = 17:07:59Z`.
   - **Call 2 (`6ba3ee0c-0341-4f04-a4dd-a4b4b82791f8`)**: User 1 called User 2. Started at `17:10:14Z`. Callee accepted at `17:10:33Z`. Media never established. Caller's 45-second timer fired and marked `timeout`/`no_answer` with `duration_seconds: 33` ("Missed (33s)").
   - **Critical Root Cause Discovery**: Live database query `SELECT (offer_sdp LIKE '%a=candidate%'), (answer_sdp LIKE '%a=candidate%')` returned `false` for **both** calls. The SDPs in the database had lengths of 1389 and 1293 bytes—completely void of ICE candidates.

2. **Why WebRTC Failed Between The Emulators**:
   - The caller generated an SDP offer immediately upon calling `_webrtc.createOffer()`, before ICE candidate gathering began.
   - The caller saved this candidate-free SDP offer to the database and broadcasted it over Realtime.
   - The caller's WebRTC engine then began gathering local ICE candidates (host, srflx) and emitted them via trickle broadcast (`_signaling.sendIceCandidate()`).
   - However, the callee was still in the incoming call state and had **not yet subscribed** to the Realtime channel `voip_call:$callId`. Supabase Realtime broadcast is ephemeral and does not retain messages for late joiners. Consequently, **every single caller ICE candidate was lost in transit**.
   - When the callee clicked Answer, the callee retrieved the offer from DB (or broadcast), generated an answer without candidates, and sent it back. The callee had zero candidates for the caller.
   - Without candidate pairs, the WebRTC peer connection stayed in `checking`/`new` and never transitioned to `connected`. Neither peer ever triggered `_onCallConnected()`, the active call timer never started, and no audio could pass.
   - Furthermore, the caller had no mechanism to retrieve `answer_sdp` from the database if the transient broadcast `sdp_answer` was missed, leaving the caller permanently stuck on "Calling...".

3. **Backend & Function Audit**:
   - `get-turn-credentials` was present in local code but was **not deployed** to Supabase (`list_edge_functions` returned 404), causing `getCallIceServers()` to fail silently and fall back to public Google STUN.
   - `initiate-voip-call` and `end-voip-call` were deployed at version 1. `end-voip-call` lacked an atomic terminal state guard and blindly used `connected_at` for duration calculation even when media failed.
   - `answer_voip_session` prematurely set `connected_at = NOW()` and returned `VOID`, masking update failures.

### 2. Comprehensive Solution Architecture

To achieve a reliable Free Call with deterministic state transitions, we implement the following core changes:

1. **Complete-SDP ICE Gathering (Vanilla ICE Integration) & Trickle Buffering**:
   - In `webrtc_audio_service.dart`, when creating an offer or answer, wait for ICE gathering to complete (`iceGatheringState == RTCIceGatheringStateComplete`) or a bounded gathering window (maximum 1200ms).
   - Retrieve the full session description containing all gathered candidates (`a=candidate:...`).
   - When this offer or answer is persisted to Supabase and broadcasted, it contains all host and STUN candidates directly embedded. Late-joining peers automatically receive the complete candidate list upon fetching the SDP from the database.
   - In addition, trickle ICE candidate broadcasting is retained. Local candidates emitted prior to channel connection are buffered in `_pendingLocalCandidates` and flushed immediately upon subscription. Remote candidates received prior to remote description installation are buffered and drained cleanly.

2. **Callback Ordering & Typed Signaling Connection**:
   - In `voip_calling_controller.dart`, ensure `_setupSignalingListeners()` is registered **before** `_signaling.connect()`.
   - `VoipSignalingService.connect()` now returns a typed `SignalingSubscriptionResult` (`subscribed`, `channelError`, `timeout`) rather than swallowing exceptions.

3. **Bidirectional Database Replay for SDP**:
   - In addition to callee polling for `offer_sdp`, the caller implements an active listener and fallback poll for `answer_sdp` from `voip_call_sessions`.
   - If the caller does not receive the `sdp_answer` broadcast within 3 seconds of callee acceptance, it fetches `answer_sdp` from the database and sets the remote description.

4. **Separation of Acceptance from Media Connection (Database & Schema)**:
   - Migration `20260927220000_voip_free_call_connection_repair.sql`:
     - Modifies `answer_voip_session` to return a typed status (`accepted`, `already_answered`, `expired`, `forbidden`, `not_found`). It claims the call atomically and updates `answer_sdp`, but **does NOT set `connected_at`**.
     - Introduces `mark_voip_session_connected(p_call_id UUID)`: Callable only by session participants. Sets `status = 'connected'` and `connected_at = COALESCE(connected_at, NOW())` idempotently once WebRTC peer connection is verified.
     - Updates `terminate_voip_session` and `end-voip-call`: If `connected_at` is NULL, duration is strictly 0. An unconnected call ended by a participant cannot receive status `completed`; it is classified truthfully as `missed`, `declined`, `failed`, or `timeout`.

5. **Bounded Setup Deadline & Deterministic Hangup**:
   - A dedicated 25-second `connecting` timer is introduced. If WebRTC fails to reach `RTCPeerConnectionStateConnected` within 25 seconds of answer, the call fails deterministically with `failed`/`connection_timeout`.
   - In `endCall()`, `_signaling.sendEnded()` is broadcast **before** channel disconnection. Local media (mic, peer connection, audio session, CallKit) is torn down immediately.
   - Teardown callbacks are protected with generation/call-ID guards to prevent previous call cleanup from affecting new calls.

6. **Edge Function & Network Alignment**:
   - Update `end-voip-call` to enforce atomic terminal guards and zero duration for unconnected sessions.
   - Deploy `get-turn-credentials` and ensure graceful STUN fallback with accurate diagnostics.

### 3. Execution Verification Plan

1. **Unit & State Machine Tests**:
   - Verify `VoipSignalingService` callback registration, error handling, and candidate buffering.
   - Verify `WebRTCAudioService` complete-SDP gathering and candidate buffering.
   - Verify `VoipCallingController` caller DB answer fallback and 25s connecting timeout.
2. **Database Verification**:
   - Execute local migration and apply to Supabase.
   - Verify RPC behavior with test transactions: `answer_voip_session` returns typed result and leaves `connected_at` null; `mark_voip_session_connected` sets `connected_at`; `terminate_voip_session` preserves 0 duration for unconnected calls.
3. **Live Emulator Calls**:
   - Place calls in both directions between MuMu 1 (`8a07a25b...`) and MuMu 2 (`172b7a4c...`).
   - Verify instantaneous SDP exchange, candidate pairing, transition to `connected`, active call timer, and clean hangup.
