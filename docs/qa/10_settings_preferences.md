# 10 — Settings and Preferences

## Settings navigation
### TC-SET-001: Open each settings destination and return safely
- **Preconditions**: The user is authenticated and settings routes are available.
- **Expected**: Preferences, Privacy, Devices, Geo, Household, Referrals, Payments, and Offline Refill open their registered destinations.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Route registrations were inspected; settings navigation was not exercised.

## Theme and language
### TC-SET-002: Persist theme and language with correct text direction
- **Preconditions**: Device supports light/dark mode and supported LTR/RTL locales.
- **Expected**: Selected theme and language persist after restart; RTL locale mirrors layout and direction-dependent navigation.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Preferences and locale tests exist but Flutter did not run.

## Privacy controls
### TC-SET-003: Save analytics consent and export or delete account data
- **Preconditions**: User can access privacy controls and has verified destructive-action credentials.
- **Expected**: Consent is stored; export returns the account’s data; deletion requires confirmation and cannot be triggered by a canceled flow.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Privacy screen includes consent, export, and guarded deletion; no live account deletion/export was attempted.

## Linked devices
### TC-SET-004: Revoke a selected device session
- **Preconditions**: Account has multiple active device sessions.
- **Expected**: Only the selected session is revoked and the current account remains signed in unless its own session is selected.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Devices controller/screen were inspected; no session was revoked.

## Geo and regional settings
### TC-SET-005: Save home country and regional display preferences
- **Preconditions**: Supported country, currency, and device location permissions are available.
- **Expected**: Home country and formatting settings persist; travel detection and manual region changes update dependent summaries.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Geo controller tests exist but Flutter execution stalled. This is the single catalog entry for home-country behavior.
