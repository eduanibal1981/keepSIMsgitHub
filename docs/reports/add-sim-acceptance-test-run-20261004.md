# SIM add acceptance test run

**Run date:** 2026-10-04 (Asia/Muscat)  
**Scope:** Add a new SIM on Free and Standard plans  
**Overall sign-off:** **PARTIAL** — core pricing and notification-delivery components have passing regression checks, but neither end-to-end add flow was exercised on a device. Two acceptance gaps are recorded below.

## Test cases

### SIM-FREE-01 — Add a new SIM on Free

**Preconditions**

- Signed-in test account; a phone number eligible for Free setup.
- Device push is enabled and registered.
- Telegram is bound and enabled for the account; the SIM line alert category allows Telegram.

**Steps**

1. Open SIM Lines and choose Add SIM.
2. Enter a new phone number and select Free.
3. Save, then inspect the SIM list and in-app notifications.
4. Check the registered device’s push notifications and the bound Telegram chat.

**Expected**

- The new line appears with Free/basic entitlement and no plan charge.
- An in-app line-added confirmation is recorded.
- A push notification reaches the registered device.
- Telegram receives the alert when the user has enabled that channel.

**Result: PARTIAL**

- The database tier/setup suite passed its Free-plan quote and entitlement checks (see evidence below).
- Code inspection confirms the add-line controller emits the line-added event after saving a reminder.
- Device push and Telegram delivery were not exercised against a real device/provider.
- **Acceptance gap:** the Add SIM screen says Free gets “Push notifications only” and that Telegram requires a paid plan. The backend migration allows Telegram for the basic/Free tier. This copy conflicts with the requested Free-plan behavior and may discourage users from enabling Telegram. See [sim_line_form_screen.dart](../../lib/features/sim_lines/presentation/screens/sim_line_form_screen.dart#L925) and [allow Telegram for Free tier migration](../../supabase/migrations/20260916070000_allow_telegram_for_free_tier.sql#L1).

### SIM-STANDARD-01 — Add a new SIM on Standard

**Preconditions**

- Signed-in test account with enough spendable wallet balance for the configured Standard setup fee.
- New phone number eligible for setup.
- Push registered; email address configured; WhatsApp number and Telegram chat bound as applicable.
- Standard alert category enables the channels under test.

**Steps**

1. Open SIM Lines and choose Add SIM.
2. Enter a new phone number and select Standard.
3. Save and confirm the plan fee.
4. Verify the line, wallet ledger/balance, in-app alert, device push, email, WhatsApp, and Telegram.
5. Repeat with email or WhatsApp unset and confirm the screen directs the user to configure the missing channel.

**Expected**

- The Standard line appears only after successful setup finalization.
- The configured Standard fee is debited once from the wallet; a retry does not debit twice.
- An in-app line-added confirmation and push notification are created.
- Enabled and configured email, WhatsApp, and Telegram destinations receive the alert.
- Missing destinations are identified and the user is directed to Alert Preferences.

**Result: PARTIAL**

- The database tier/setup suite confirmed a $2.50 Standard setup quote; this is a quote check, not proof of a completed wallet debit.
- Code inspection confirms the Standard flow reserves setup funds, saves the line, finalizes setup, and emits the line-added event.
- End-to-end wallet debit and external channel delivery were not verified.
- **Acceptance gap:** the Add SIM channel summary checks whether a WhatsApp phone, Telegram chat ID, or email address exists but does not check whether that channel’s `is_enabled` state. Since the app can prefill a login email while leaving email alerts disabled, the summary may claim a channel is active and omit the setup nudge. See [sim_line_form_screen.dart](../../lib/features/sim_lines/presentation/screens/sim_line_form_screen.dart#L902) and [notifications_repository_impl.dart](../../lib/features/notifications/data/repositories/notifications_repository_impl.dart#L230).

## Checks run

| Check | Result | Evidence |
|---|---|---|
| SIM tier and setup quote SQL suite | **PASS — 25/25 assertions** | `supabase/tests/line_tiers_and_app_fee_rules_tests.sql`, executed against the connected Supabase project inside its rollback wrapper. Free quote was $0.00; Standard quote was $2.50. |
| Notification delivery contracts | **PASS — 20/20 tests** | `node test/notification_production_contracts.test.cjs`. Direct run used because node --test hit a Windows spawn restriction. Covers provider routing, idempotency, receipts, retry behavior, and email rendering with test doubles. |
| Push delivery contracts | **PASS — 9/9 tests** | `node test/push_delivery.test.cjs`. Covers simulated provider routing and payload handling; it does not prove delivery to a physical device. |
| Flutter plan-fee/setup tests | **PARTIAL — not completed** | The selected Flutter test run stayed silent for over a minute. Retried with `--no-pub`; it again stalled before reporting test results and was stopped. |
| Existing plan billing SQL suite | **NOT VERIFIED** | `supabase/tests/c3c_plan_billing_tests.sql` stopped because its seeded user has no wallet (`Wallet not found`). The fee debit assertion did not run to completion. |
| Existing alert-preferences SQL suite | **NOT VERIFIED** | `supabase/tests/c2_alert_preferences_tests.sql` expects the former `pg_net` queue behavior; the current database did not enqueue there (`queue 0 -> 0`). This legacy check needs updating for the current notification outbox. |

The delivery contract tests use mocks/test doubles. No live notification was sent to a real user, email inbox, WhatsApp number, Telegram chat, or device.

## Follow-up before full sign-off

- Correct the Free-plan Telegram description in the Add SIM screen.
- Make the Standard channel summary respect each channel’s enabled state and clearly identify missing destinations.
- Run both add flows on a test account/device and verify the wallet ledger plus actual notification receipts.
- Repair or replace the stale billing and alert-preferences SQL fixtures, then rerun the focused Flutter tests.

**Signed:** Codex QA execution  
**Disposition:** **PARTIAL** — Free and Standard end-to-end scenarios remain open.



