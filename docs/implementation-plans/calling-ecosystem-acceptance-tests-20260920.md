# KeepSIMs calling: practical acceptance tests

Prepared 20 September 2026. Use with `calling-ecosystem-executor-prompt-20260920.md` in this directory.

These are the expected results **after implementation**, not a claim that the current app already passes. Each case can be marked PASS, FAIL, BLOCKED or NOT RUN. Mark a feature BLOCKED when its provider/device prerequisites are missing. A preview/simulator cannot pass a real calling test.

## 1. What you need

- Phone A: your KeepSIMs account. Phone B: another consenting person's separate KeepSIMs account. At least one Android and one physical iPhone for cross-platform validation.
- Phone C: a normal mobile/landline you own or have permission to call. It should not be the same number as the chosen verified caller ID. For inbound tests, C calls your DID/home number.
- A second device signed into B for multi-device tests; a separate account X for privacy tests.
- Working Wi-Fi and mobile data on separate networks; a headset/Bluetooth device if supported.
- An executor-prepared staging build, a resettable test wallet, a deterministic provider/IVR fixture, and access to receipts. Use real calls only for device/carrier checks, within an agreed small budget.
- For DID/forwarding: a genuinely provisioned supported number, known prices and a home SIM whose carrier has confirmed forwarding support/instructions. For voicemail: enabled private recording/transcription service.

Never dial the illustrative numbers in old screenshots, live emergency services or a random “test number.” Use your consenting destination. Do not change real carrier forwarding without recording the current settings and verified disable instructions. Forwarding charges appear on the carrier account, not necessarily in KeepSIMs.

Ask the executor to expose safe staging controls for exact answered duration, provider events, late/duplicate messages, unavailable routes and wallet fixtures. These must be absent from customer release builds. You should not need to edit a database manually to run ordinary app checks.

## 2. Start with this 15-minute smoke check

1. Open Calls. You can distinguish Phone calls, KeepSIMs calls and My numbers; audio testing is easy to find in help. There are no simulation buttons in a release build.
2. Run Test audio. Speak, then stay silent: the meter responds to your voice. Play the chime: you actually hear it. Leave: the microphone indicator clears.
3. A calls B. B's real phone rings; answer and speak different phrases in both directions. Both hear each other, and the connected timer starts only after connection.
4. Minimize, restore, mute/unmute and end. The bar disappears, audio stops and no app-call wallet debit exists.
5. A calls C using a quoted phone-call rate. C really rings; compare the displayed caller number with the selected mode. Answer and test two-way audio.
6. End and inspect the receipt. Destination, connected duration, billed duration, rate, fees and charge agree. A missed/unanswered attempt is not a paid conversation.
7. Lock B and call again. The real native incoming-call UI appears; answer and speak. Repeat with the app backgrounded.
8. Switch to Arabic and enlarge text. Main actions remain readable and tappable.

If any core audio, privacy or billing check fails, record it and do not treat a polished screen as a release pass. Continue unrelated tests to identify the full repair scope.

## 3. Exact money examples

These are **invented staging tariffs**, not KeepSIMs prices or carrier offers. Exact duration cases use the executor's authoritative-duration fixture; a hand stopwatch cannot establish a one-second billing boundary. For real calls, compare against the authoritative receipt duration and allow display timing differences, not unexplained charge differences.

All examples are USD with zero tax. Retain four decimal places internally and in a detailed test receipt; ordinary wallet display may use fewer places under a documented rounding rule. The underlying wallet/ledger delta must use the same documented precision consistently.

| Fixture | Rate/minute | Minimum | Increment after minimum | Answered connection fee |
|---|---:|---:|---:|---:|
| T1 | $0.1200 | 0 s | 1 s | $0.0000 |
| T2 | $0.1200 | 60 s | 1 s | $0.0000 |
| T3 | $0.1200 | 60 s | 60 s | $0.0000 |
| T4 | $0.1200 | 0 s | 1 s | $0.0300 |

| ID | Test action | Expected billed duration and charge |
|---|---|---|
| M01 | T1, connect for exactly 45 s. | 45 s, **$0.0900**. A $5.0000 wallet becomes $4.9100 after settlement. |
| M02 | T1, exactly 61 s. | 61 s, **$0.1220**, not $0.2400. |
| M03 | T2, exactly 45 s; repeat 61 s. | 60 s/$0.1200, then 61 s/$0.1220. Minimum is visible before calling. |
| M04 | T3, exactly 45 s; repeat 61 s. | 60 s/$0.1200, then 120 s/$0.2400. A 45 s call is not shown as two minutes. |
| M05 | T4, exactly 45 s. | $0.0300 + $0.0900 = **$0.1200**. Fee is itemized once. |
| M06 | T1, 0.2 s of valid connected time; then 60.1 s. | With the prompt's ceil-to-second rule: 1 s/$0.0020 and 61 s/$0.1220. |
| M07 | Use any tariff, but never answer. | No answered connection fee or conversation debit; temporary reservation released after conclusive termination. |
| M08 | T1, wallet/budget $0.1000; request max affordable call. | Authorized maximum 50 s. Cutoff honors the budget; final customer charge <=$0.1000. Any late provider termination cannot overdraw the customer. |
| M09 | T2, only $0.1000 spendable. | Calling blocked before PSTN dialing because the 60 s minimum costs $0.1200. |
| M10 | T4, budget $0.1000. | $0.0300 fee leaves $0.0700 for 35 s; affordable duration is 35 s, not 50 s. |
| M11 | T1, wallet $5.0000; authorize a $0.2000 cap; end after 45 s. | Initially $0.2000 held, $4.8000 spendable. Finally $0.0900 debited, $0.1100 released, wallet $4.9100 and no active hold. |
| M12 | On one household wallet: authorize $0.8000 from $1.0000; another permitted user requests $0.3000. | Second request cannot reserve $0.3000. Same user starting another call is separately blocked by call admission. |
| M13 | Call has $0.8000 held from $1.0000; attempt a $0.3000 recharge purchase/refund/gift. | Competing wallet action cannot consume held funds. No later call-settlement shortfall. |
| M14 | Top up while a $0.1000 capped call is active. | Wallet increases, but call cap stays unchanged unless you explicitly authorize an extension supported by the implementation. |
| M15 | Replay the same completion event three times and concurrently. | One final debit, one receipt, no extra lot consumption; settled amount unchanged. |
| M16 | Cause temporary settlement failure after hangup, then recover. | “Charge processing” or equivalent; no fake paid receipt. Later exactly one consistent charge and released remainder. |

Also ask for boundary examples with a connection fee plus a minimum, tax, currency conversion, very low rates and zero-duration answer events. The executor must publish their exact rounding/tax contract and expected values before marking those cases passed.

## 4. Everyday UI, navigation and accessibility

| ID | What to do | Expected result |
|---|---|---|
| U01 | Open each calling area and an existing saved `/calling`, `/calling/internet`, `/calling/sip-test` link. | Correct flow opens; old routes still work. Paid and app calls are plainly labeled. |
| U02 | Paste your test number with spaces/parentheses; try local format with selected country; then ambiguous/invalid text. | Equivalent valid forms normalize consistently. Ambiguous input asks for country/clarification; invalid input cannot dial. |
| U03 | Open contacts, deny permission, then type a number manually. | Clear explanation; manual dialing works. No repeated coercive prompts. |
| U04 | View an empty favorites/history/family list. | Useful next action, no fabricated contacts or claim that adding a SIM makes it a callable app account. |
| U05 | Link a consenting family member B; also add an unregistered SIM line. | B can be called as a person; unregistered line has an honest unavailable/invite or explicitly paid-call option. |
| U06 | Rapidly search two different numbers; let the first response arrive last. | Only the latest search result is shown; no call to the previous person. |
| U07 | Enable Arabic, large text and screen reader; inspect quote, call screen, receipts and voicemail. | Correct RTL, readable numbers, labeled buttons, no clipping or reliance on color alone. |
| U08 | Use a small screen and gesture navigation; minimize the active call. | Bar respects safe areas and navigation; timer/status update and restore/end remain usable. |
| U09 | Disable network while entering a destination and restore it. | Input preserved; honest offline/retry state; no automatic paid call on reconnect. |
| U10 | Install a customer release build. | No debug caller names, simulated incoming calls, fake “ONLINE” or engineering stats presented as facts. |

## 5. Audio tests and resource release

| ID | What to do | Expected result |
|---|---|---|
| A01 | Run microphone test, speak, then remain quiet. | Meter reflects measured input and falls with silence; no random bounce. If measurement is unsupported, it says so. |
| A02 | Deny microphone permission; retry after granting it in settings. | No crash/false pass. Actionable permission state, then successful capture after permission. |
| A03 | Play chime on speaker, earpiece and supported headset. | Audible sound from the selected route; unavailable routes are not claimed as active. |
| A04 | Run echo test with headphones; stop and immediately leave. | You hear your voice; stopping ends playback/capture and clears the microphone indicator. |
| A05 | Start/stop tests 20 times; leave during initialization; reopen and make a real call. | No stuck capture, concurrent test sessions, frozen UI or lost call audio. |
| A06 | Inspect stats before any network test, offline, then after a real network test. | Unmeasured/offline is not “Passed.” Measurements have correct units/scope/time; local loopback is not labeled carrier latency. |
| A07 | Start diagnostics during an active phone/app call. | Existing call remains intact; conflicting diagnostics are blocked with a useful explanation. |
| A08 | Compare wallet before and after all local diagnostics. | No call debit or PSTN provider call. Any data use is described honestly. |
| A09 | Executor repeats hot restart and process relaunch during/after diagnostics on Android. | No reproducible hang or leak; device/OS logs retained. This is a developer regression test, not proof from a UI timer. |

## 6. App-to-app calling

For every connected case, speak different phrases in both directions. Hearing a local ring tone alone does not prove two-way media.

| ID | What to do | Expected result |
|---|---|---|
| V01 | A calls B with both apps open on Wi-Fi; answer. | Exactly one invitation, real ringing, correct identity and two-way audio; no wallet charge. |
| V02 | Wait 20–30 s before B answers. | Connection still succeeds; the initial offer was not lost before B subscribed. |
| V03 | Put A on Wi-Fi and B on mobile data; repeat in reverse. | Two-way audio and correct end behavior on different networks. |
| V04 | Executor forces relay-only connectivity; call both ways. | Both peers connect through authenticated TURN; no static public credential exposure. |
| V05 | Lock B, call and answer; repeat backgrounded and ordinary OS-terminated/cold launch. | Native incoming UI and answer lead into the correct live call. Record exact OS/build. Simulator cannot pass this. |
| V06 | Explicitly force-stop B on Android or use the relevant iOS user-termination scenario, then call. | Actual platform limitation is documented. No false guarantee of ringing; A eventually receives no-answer/unavailable and no charge. |
| V07 | A hangs up while B rings; deliver an old push afterward. | Ringing is cancelled; stale notification cannot establish/reopen the ended call. |
| V08 | B declines; repeat without answering for 45 s. | Correct declined versus missed/timeout history; neither party remains busy afterward. |
| V09 | Answer on one of B's two devices; answer on the other almost simultaneously. | Exactly one device owns the conversation; the other stops ringing and reports answered elsewhere. |
| V10 | A and B call each other simultaneously; also double-tap Call. | Deterministic single-call result; no two competing sessions/audio streams. |
| V11 | Attempt a phone call while an app call is connecting, then reverse the modes. | Shared coordinator prevents a second competing conversation. |
| V12 | Toggle mute, speaker and Bluetooth; disconnect the headset. | Mute changes what the other person hears; route indication follows actual output; sensible fallback on disconnect. |
| V13 | Minimize/restore five times, navigate elsewhere and end from the bar. | Same session survives navigation; end stops media and removes native UI/bar promptly. |
| V14 | Break internet for a short interval, then reconnect; repeat beyond 15 s. | Short outage uses bounded recovery where possible; long failure ends clearly. No infinite “Reconnecting.” |
| V15 | Disable network and tap End; immediately start another call after network returns. | Local capture/UI stop in <1 s on a healthy device; pending cleanup does not destroy the new session. Server eventually records termination. |
| V16 | B ends through native call controls, then A does so on the next call. | Both sides terminate and release media; no stuck native call tile. |
| V17 | Log out B, switch to X on the same device, then call B. | X does not receive B's private call. Token ownership is updated/revoked correctly. |
| V18 | B blocks A or disables phone discovery; A searches/calls B. | Published privacy rule is enforced by server; no unauthorized ringing/profile leakage. |
| V19 | B has a push token but is offline. | UI does not unconditionally say ONLINE; invitation ends truthfully if unreachable. |
| V20 | Interrupt with a normal cellular call, alarm/audio focus change and device lock. | Documented interruption behavior, correct audio recovery/termination; no microphone leak. |

## 7. Paid phone calls and caller ID

| ID | What to do | Expected result |
|---|---|---|
| P01 | Enter C's valid number and inspect the confirmation sheet. | Destination, selected caller ID, rate, minimum/increment, fees, currency and authorized budget visible before commitment. |
| P02 | Choose Gateway and call C; inspect C's handset. | Actual routing uses the disclosed gateway identity where carrier presentation permits. It does not claim your personal number or promise private callback delivery. |
| P03 | Verify your personal number with valid OTP, select it and call an approved corridor. | Only your verified number becomes selectable; C's actual observed identity and carrier limitations are recorded. |
| P04 | Enter wrong/expired OTP, resend quickly, then try verification from another account. | Expiry/attempt/cooldown protections work; another account cannot inherit your verification. |
| P05 | Select a verified caller ID incompatible with destination policy. | Clear restriction before charge; explicit choice to use an eligible alternative, never silent identity substitution. |
| P06 | Try dialing your selected caller-ID number or a defined unsupported/emergency/premium fixture. | Correct policy restriction; no live emergency or unsupported route attempt. |
| P07 | Cause rate lookup failure/stale quote; tap Call. | No invented $0.15 rate or paid attempt. Refresh/choose a supported destination; changed quote requires confirmation. |
| P08 | C answers after ringing. | UI moves through truthful states; timer/charge start on the defined connected event, not app registration or local microphone readiness. |
| P09 | C is busy, declines, never answers; A cancels while ringing. | Distinct correct history outcomes, no conversation charge, reservation eventually released. |
| P10 | C answers and immediately ends; then A ends an answered call. | Both legs are terminated; duration/receipt match each scenario; no dangling carrier leg. |
| P11 | Call the consented IVR fixture; press 1, 2, # with the in-call keypad. | Remote IVR receives the intended DTMF sequence once; local keypad animation alone does not pass. |
| P12 | Lose app connectivity or kill A while connected. | Provider cap/watchdog prevents an unlimited call; subsequent receipt/history reconcile correctly. |
| P13 | Double-tap Call; retry after an ambiguous network response. | At most one logical call and one live destination leg per intent, with stable receipt/charge. |
| P14 | Hang up during preparation, app-leg connection and destination dialing. | Each stage cleans up; delayed provider responses cannot resurrect or ring a cancelled call. |
| P15 | Call again from Recent calls after a tariff change. | Fresh quote displays current terms; old receipt remains unchanged. |
| P16 | Let the authorized budget run out. | Useful low-budget notice, bounded cutoff, no customer overspend; end reason explains budget exhaustion. |

Run M01–M16 as part of this section, including both a phone-call-only run and concurrent unrelated wallet spending.

## 8. Virtual numbers and forwarding

| ID | What to do | Expected result |
|---|---|---|
| D01 | Search numbers for supported and unsupported countries/types. | Real inventory/requirements; unsupported markets do not show fabricated purchasable DIDs. |
| D02 | Inspect a number quote and proceed once. | Setup, recurring, inbound, tax and renewal terms shown; exactly one order/authorization/number assignment. |
| D03 | Double-tap order; simulate timeout after provider accepts; retry. | Reconciliation finds the same order, no second rental or double debit. |
| D04 | Simulate sold-out inventory or pending identity/address requirements. | Honest unavailable/pending state, required next steps; funds handled according to disclosed order policy. |
| D05 | C calls A's active DID; A answers on Wi-Fi. | Correct account/device rings, two-way audio, correct inbound tariff and receipt. |
| D06 | C hangs up before A answers; deliver delayed provider/push events. | All invitations stop; no reopened call or unanswered conversation charge. |
| D07 | A is offline/busy; C calls DID. | Configured unavailable/voicemail behavior; no unexplained silent connected line. |
| D08 | Select home carrier/SIM in setup; choose unsupported international forwarding. | Incompatibility/cost issue shown before rental/setup; no universal code or promise of free forwarding. |
| D09 | On a supported line, follow verified carrier instructions with the correct SIM; C calls the home number. | KeepSIMs really rings via the configured DID. Only a successful real check marks forwarding working. |
| D10 | On dual SIM, initially select the other line; then correct it. | Wizard helps identify correct line; merely copying a code never marks success. |
| D11 | Compare forwarding test with carrier usage records and KeepSIMs receipt. | App charges and carrier forwarding/data charges are distinguished. Savings do not omit known charges. |
| D12 | Disable forwarding using verified instructions and retest home number. | Home SIM receives the call normally; KeepSIMs no longer receives it via that forwarding rule. |
| D13 | Simulate renewal with sufficient/insufficient funds and duplicate renewal jobs. | One renewal debit when successful; clear grace/suspension policy when not; no duplicate rental. |
| D14 | Cancel number, inspect effective date and forwarding warning; complete release. | Clear retained-service period, no unexpected future renewal; old account loses number routing/access after release. |
| D15 | Reassign released DID in staging; call it from C. | Only new owner receives it; old owner cannot access new call history/voicemail. |
| D16 | Configure a known forwarding loop in staging. | Loop is detected/prevented or strictly capped; no escalating call chain/charges. |

Real forwarding tests are valid only for the tested carrier, plan, device and destination. Do not infer universal support from one successful route.

## 9. Voicemail, history and preferences

| ID | What to do | Expected result |
|---|---|---|
| W01 | C calls DID; A does not answer for configured 20 s. | One voicemail greeting/recording path takes over at the defined deadline; A stops ringing. |
| W02 | A answers exactly as voicemail timeout fires. | Exactly one winner: conversation or voicemail. No simultaneous recording of an answered conversation. |
| W03 | Leave “Please call me tomorrow at ten” in clear English. | Playable recording and substantially faithful transcript; no invented facts. |
| W04 | Leave “اتصل بي غدًا الساعة العاشرة” in clear Arabic. | Original Arabic meaning preserved, RTL readable; optional translation distinctly labeled. |
| W05 | Leave a message with a name/number plus background noise. | Uncertainty is visible; no confident fabricated number. Original playback remains available. |
| W06 | Force transcription outage and retry. | Recording playable; pending/failed transcript honest; later retry does not create duplicate messages/charges. |
| W07 | Inspect voicemail push on locked screen. | Privacy-preserving default; no sensitive transcript exposed without explicit preference. |
| W08 | Sign in as X and try A's recording/transcript link; then use an expired link. | Unauthorized/expired access denied. Legitimate A can request a fresh authorized playback link. |
| W09 | Delete message; refresh/relaunch; executor runs retention cleanup. | Audio, transcript and derived copies removed under documented policy; deleted item does not reappear. |
| W10 | Call back from voicemail, then inspect all-call history filters. | Fresh phone-call quote; distinct phone/app/inbound/missed/voicemail entries with correct identity and cost. |
| W11 | Enable quiet hours, block a caller and change missed-call preferences. | Behavior matches each setting; no unwanted ringing and no loss of required financial receipts. |
| W12 | End an app call and a phone call; view history after relaunch. | Correct terminal reason and duration persist; app call remains $0 KeepSIMs charge. |

## 10. Provider routing and savings

| ID | What to do | Expected result |
|---|---|---|
| R01 | Executor configures one valid Telnyx route and an unconfigured alternate provider. | Real calls use the valid route; unconfigured adapter cannot pretend success. |
| R02 | Fail primary route conclusively before connection with a retry-eligible infrastructure error. | At most one safe alternate attempt; approved retail tariff/identity retained; one final receipt. |
| R03 | Make primary originate response ambiguous, then allow original call to ring. | Reconciliation happens before retry; recipient is not called twice. |
| R04 | Return busy/declined; separately trigger failure after connection. | No unsolicited carrier retry of subscriber rejection and no automatic second conversation. |
| R05 | Make cheapest route unhealthy or caller-ID-ineligible. | Eligible healthy route wins or call is blocked; price alone does not override reliability/identity policy. |
| R06 | T1 versus comparator T3, one 45 s call then one 61 s call. | 45 s: $0.0900 vs $0.1200, 25% saving. 61 s: $0.1220 vs $0.2400, about 49.17% saving. |
| R07 | Compare ten 10 s calls under T1 versus T3. | $0.2000 vs $1.2000, about 83.33% saving; round each call, not total duration. |
| R08 | Enter fictional $2.60 package with 20 minutes/7-day expiry; use five separate 60 s calls under T1. | Under full-package cost basis: $2.60 vs $0.60; unused minutes/expiry explained. This is labeled a fixture/user assumption, not a real carrier offer. |
| R09 | Same package is already paid and has enough remaining minutes. | Under incremental cost basis: carrier $0 extra vs KeepSIMs $0.60. App does not claim KeepSIMs is cheaper. |
| R10 | Add DID rental/known forwarding costs; then expire comparator source or remove FX data. | Included costs affect result; missing inputs/old sources explicitly limit or disable comparison. No fabricated saving. |

## 11. Optional SIP-phone feature

Run only if phase F is intentionally enabled; otherwise mark NOT IN RELEASE SCOPE rather than failed.

| ID | What to do | Expected result |
|---|---|---|
| B01 | Register a supported softphone with that device's KeepSIMs credentials. | Isolated endpoint registers; customer never receives trunk master/API credentials. |
| B02 | Make/receive an approved call; attempt blocked destination and simultaneous app call. | Same identity, budget, eligibility and busy rules as the app; clear failure where disallowed. |
| B03 | Revoke credentials, try registering again; inspect an existing session. | New registration blocked; active-call behavior follows documented revocation policy and does not permit unlimited spend. |

## 12. Checks the executor must demonstrate

These cannot be proved by tapping through the UI. Request redacted test output and a short explanation for each; do not accept “RLS enabled” or “all tests pass” without the relevant behavior being exercised.

| ID | Injection/action | Evidence of success |
|---|---|---|
| E01 | Account X attempts to read/modify A/B call, join/broadcast on its channel or accept it. | Denied by actual policies/server, not just hidden UI; anonymous callers also denied. |
| E02 | Participant attempts to replace peer ID, forge timestamps/rate, delete a session or reopen an ended call. | Validated transition contract rejects each unauthorized mutation. |
| E03 | Send valid/invalid/stale webhook signatures and a valid event with wrong call-leg correlation. | Authentic events accepted; invalid events cannot mutate calls/wallets. |
| E04 | Deliver bridge/answer/hangup in different orders, concurrently and more than once; crash processing mid-way. | One correct terminal call result and exactly-once financial effect; retry/reconciliation restores unfinished work. |
| E05 | Race accept/cancel, dual-device accept, busy admission and voicemail timeout. | Exactly one permitted winner per race; losers cannot reopen state. |
| E06 | Drop offer/answer, deliver candidate before offer, reconnect signaling and replay old negotiation messages. | Valid current session recovers; stale revisions ignored; no candidate silently lost without recovery. |
| E07 | Force provider/DB timeout during originate, settlement, number order and renewal. | Durable uncertain/pending states and bounded recovery; no blind duplicate side effects. |
| E08 | Run money fixtures concurrently against the real staging database. | Holds, lots, ledger and balance conserve money; no negative spendable balance, phantom debit or double capture. |
| E09 | Retry aged sessions, expired credentials/holds and orphaned legs. | Reconciler closes/reconciles resources; does not release a hold while unknown provider spend is still active. |
| E10 | Exercise push delivery contract on real Android/iOS, expired tokens and logout/account switches. | Provider outcomes recorded; real ringing measured separately; invalid tokens retired and private payloads not misrouted. |
| E11 | Abuse lookup/OTP attempts, malformed IDs and oversized SDP/payloads. | Enforced rate/input limits and minimal private data exposure. |
| E12 | Disable feature flags during active calls/pending orders; test older supported client. | No new disabled activity; existing calls can hang up/settle and orders reconcile; older client remains safe or gets upgrade guidance. |
| E13 | Inspect logs, analytics, support export and storage policy. | No secrets, unredacted SDP, private recordings/transcripts or unnecessary full numbers leaked. |
| E14 | Repeat the existing backend test and new regressions. | Explain the repaired readiness contract; all meaningful tests pass. No skipped/deleted assertion masquerading as a fix. |

## 13. Run matrix and sign-off

Run core connected, incoming, cancellation, minimization and audio-routing cases for Android→Android, iPhone→iPhone, Android→iPhone and iPhone→Android on supported versions. At minimum include Wi-Fi↔Wi-Fi and Wi-Fi↔mobile data, physical locked devices, release-like builds and a forced-relay run. Track cellular provider/region for paid calls and forwarding. Emulator/simulator tests supplement physical testing only.

Suggested order: U/A basics → V app calling → P/M paid calling → D numbers/forwarding → W voicemail → R routing/savings → optional B. Run E security/financial races before any public launch, not after adding more features.

Initial release gates:

- No unresolved P0 audio, authorization, fake-measurement, incorrect-charge or duplicate-call defect.
- All enabled money fixtures and privacy/race tests pass. Unavailable infrastructure is BLOCKED and the related feature stays disabled.
- Actual expected incoming behavior is demonstrated on physical supported devices; platform force-stop restrictions are documented separately.
- At least 20 consecutive app-call cycles and 10 controlled paid-call cycles without stuck UI/audio/holds or duplicate charges, alongside the targeted failure cases. This is a smoke threshold, not statistical proof of reliability.
- DID/forwarding and alternate-provider availability are limited to combinations actually validated. Existing non-calling wallet purchases/refunds still work.
- Record measured setup/recovery/end latency against the implementation targets. Do not claim a universal carrier SLA from staging.

## 14. Copyable results sheet

| Test ID | Build / device / network | Actual result | PASS / FAIL / BLOCKED / NOT RUN | Evidence / support reference |
|---|---|---|---|---|
| | | | | |

For each failure, capture:

```text
Test ID:
Build/version and environment:
Device/OS and network:
Time including timezone:
Call/order/support reference:
Actions performed:
Expected result:
Actual result:
Quoted tariff, balance before/after and receipt (if relevant):
Screenshot or screen recording:
Does it repeat? How often?
```

Redact personal numbers and tokens before sharing. Never include passwords, OTPs or private voicemail audio unless deliberately needed and authorized.

## 15. Baseline findings to compare against

During preparation, local backend tests ran with `node --test --test-isolation=none test/call_media_backend.test.cjs`: **14 passed, 1 failed**. The failing readiness-order test expected no destination dial after the first readiness signal, while current code permits dialing after `media_ready`. Flutter tests did not produce a completed result during the review and were stopped. No real handset calls, forwarding, DID ordering or production billing were tested.

The current random microphone meter, fixed network figures and non-playing speaker-test action would fail A01/A03/A06. Incoming push/signaling and financial findings in the companion plan explain why the real-device and money cases are required. This guide deliberately tests outcomes a user can trust, rather than counting attractive screens as completed functionality.
