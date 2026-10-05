# 11 — Smart Calls and VoIP

## Smart Call dashboard
### TC-CAL-001: Show connection state and registered SIP extension
- **Preconditions**: SIP account is configured or intentionally unavailable.
- **Expected**: Connection state, extension, and retry/error feedback match the actual registration state.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: No carrier or trunk was registered during this audit.

## My Numbers
### TC-CAL-002: List and manage assigned virtual numbers
- **Preconditions**: Account has assigned numbers or an empty inventory.
- **Expected**: Numbers and status are account-scoped; buy, refresh, or release actions require confirmation and correct pricing.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Virtual-number purchase was not submitted.

## Voicemail inbox
### TC-CAL-003: Load voicemail, play audio, and show transcription
- **Preconditions**: A test voicemail has audio and optional transcription.
- **Expected**: Playback controls use the selected message; transcript and status belong to that voicemail.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Voicemail widget/controller tests exist but Flutter execution stalled.

## Savings calculator
### TC-CAL-004: Compare roaming and VoIP costs
- **Preconditions**: Destination, duration, and usage inputs are valid.
- **Expected**: Chart and totals update consistently when rates or usage change.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Savings calculation tests exist but Flutter execution stalled.

## SIP diagnostics
### TC-CAL-005: Run ping, ICE, and codec diagnostics
- **Preconditions**: Test-mode SIP/network credentials and STUN/TURN endpoints are configured.
- **Expected**: Each diagnostic reports its own result and timeout; diagnostics do not place a paid outbound call.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: No external trunk or live diagnostics were run.

## Internet Calling
### TC-CAL-006: Search for app users and prepare an internet call
- **Preconditions**: A second test account is available or search returns no match.
- **Expected**: Search results are account-scoped; calling an app user uses the internet-call flow and no PSTN charge path.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: VoIP UI tests exist but Flutter execution stalled.

## WhatsApp Call launcher
### TC-CAL-007: Launch the WhatsApp-style in-app call screen
- **Preconditions**: A test recipient and app-to-app call capability are available.
- **Expected**: Launcher passes the correct recipient and call state; cancellation returns without starting a paid trunk call.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: No call was placed.

## Call media backend contracts
### TC-CAL-008: Validate call session signaling and media authorization
- **Preconditions**: Backend call test doubles provide caller, recipient, and session state.
- **Expected**: Authorized sessions transition through expected signaling states; unauthorized or duplicate transitions are rejected.
- **Status**: VERIFIED
- **Notes/Found Issues**: test/call_media_backend.test.cjs passed 15/15 tests with test doubles; this does not prove real network audio.

## Paid PSTN dialer
### TC-CAL-009: Catalog dialer controls without placing a live call
- **Preconditions**: Dialer route is open; no paid trunk test is authorized.
- **Expected**: Keypad, DTMF buttons, number entry, mode controls, and call-history tab are cataloged; no outbound PSTN call is placed.
- **Status**: CATALOGED - UNTESTED: Paid Live Trunk
- **Notes/Found Issues**: Required exclusion. No outbound PSTN call was attempted.
