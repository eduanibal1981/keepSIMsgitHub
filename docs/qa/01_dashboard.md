# 01 — Dashboard

## Greeting and profile badge
### TC-DAS-001: Render account greeting and profile entry
- **Preconditions**: An authenticated profile has a name, email, and avatar URL or initials fallback.
- **Expected**: Greeting and identity match the current profile; profile action opens the profile route.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Route and widget are present; no Dashboard Flutter test completed.

## Active SIM overview
### TC-DAS-002: Summarize SIM statuses and next due alerts
- **Preconditions**: The account has active, expiring, and inactive lines with distinct next due dates.
- **Expected**: Counts, status badges, and due summaries reflect the account’s lines; selecting a line opens its detail route.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Dashboard summary uses its own card. SIM-line list/card behavior is cataloged once in TC-SIM-001.

## Quick actions
### TC-DAS-003: Navigate from Add SIM, Top-up, eSIM, and Support actions
- **Preconditions**: Dashboard is loaded and the user is signed in.
- **Expected**: Each action opens its corresponding in-app route without losing the current session.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Routes are registered in app_router.dart; tap behavior was not exercised.

## Wallet summary
### TC-DAS-004: Show wallet balance and preferred-currency amount
- **Preconditions**: Wallet has a known USD balance and a saved display currency.
- **Expected**: Dashboard shows the current balance and the converted amount using the active FX rate.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Balance formatting is covered once with wallet display in TC-WAL-001; no duplicate currency-format test.

## Balance visibility control
### TC-DAS-005: Hide and reveal the wallet amount
- **Preconditions**: Dashboard wallet summary is visible.
- **Expected**: A visibility control masks the amount and restores it without changing the underlying balance.
- **Status**: FAILED
- **Notes/Found Issues**: No balance visibility/obscure toggle was found in the dashboard or wallet screen sources.

## Notification preview
### TC-DAS-006: Preview and open the newest alert
- **Preconditions**: At least one unread in-app notification exists.
- **Expected**: Preview shows the latest alert and opens the matching notification or destination when selected.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Notification-center actions are cataloged once in TC-AUTH-004.

## App shell and quick switcher
### TC-DAS-007: Open navigation drawer and switch the active SIM context
- **Preconditions**: The app has two or more SIM lines.
- **Expected**: Drawer routes are reachable and switching SIM context updates the displayed line without changing another line’s data.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Shared drawer is used across app routes; app-shell interaction was not runtime-tested.
