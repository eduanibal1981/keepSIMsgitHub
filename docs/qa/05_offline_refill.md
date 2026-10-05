# 05 — Offline Refill and Emergency Recovery

## Offline refill setup
### TC-OFF-001: Choose the target SIM and cache offline channel details
- **Preconditions**: A supported SIM, carrier policy, and offline contact configuration exist.
- **Expected**: Chosen line, contact numbers, and fees are shown and available offline after initial sync.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Offline channel data is cached in the screen/controller; device offline behavior was not exercised.

## USSD, SMS, WhatsApp, and missed-call actions
### TC-OFF-002: Prepare a refill request for the selected SIM
- **Preconditions**: The line has a configured offline refill target and the carrier supports the chosen channel.
- **Expected**: The action uses the correct target line and displays pending, confirmed, rejected, or retryable status without duplicate charges.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: SMS provider authentication contracts passed within the notification Node suite; carrier-side refill delivery was not tested.

## Offline voucher and emergency PIN
### TC-OFF-003: Collect, reveal, copy, and settle a stored voucher
- **Preconditions**: A valid voucher is prepared for an entitled line; biometrics are configured for reveal or settlement.
- **Expected**: PIN remains sealed until authentication, copied text matches the stored voucher, and settlement updates wallet/ledger exactly once.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Voucher model tests exist but Flutter did not run. The legacy L SQL suite selects an arbitrary real wallet/profile and was not executed.

## Emergency recovery guide
### TC-OFF-004: Open offline guide and backup eSIM actions
- **Preconditions**: The user has no connectivity and may or may not have a backup eSIM stored locally.
- **Expected**: Cached guide remains readable and the screen clearly distinguishes a prepared backup profile from a sandbox or unavailable profile.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: The recovery screen includes backup eSIM and offline refill routes; no offline-device run was available.

## Emergency contacts
### TC-OFF-005: View or manage emergency contact details
- **Preconditions**: The recovery screen is opened before travel.
- **Expected**: Emergency contacts are visible offline and can be reached without network access.
- **Status**: FAILED
- **Notes/Found Issues**: No emergency-contact list or management control was found in RecoveryGuidanceScreen; current content focuses on backup eSIM and refill fallback options.
