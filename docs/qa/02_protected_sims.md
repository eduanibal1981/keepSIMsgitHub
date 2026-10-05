# 02 — Protected SIMs

## SIM Lines list
### TC-SIM-001: Show loading, empty, populated, and filtered line states
- **Preconditions**: The account has no lines or has lines with varied names, carriers, and statuses.
- **Expected**: Loading and empty states are clear; populated rows and filters match the saved lines.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Existing list filter/header tests were not executable because the Flutter runner stalled.

## Free setup pricing
### TC-SIM-002: Quote a Free SIM and enforce eligibility
- **Preconditions**: A number is eligible for a Free plan and the quote service is reachable.
- **Expected**: Free setup returns a zero price and an eligible result; ineligible numbers receive a clear refusal.
- **Status**: VERIFIED
- **Notes/Found Issues**: Rollback SQL suite line_tiers_and_app_fee_rules_tests.sql passed 25/25 assertions, including Free quote and entitlement checks. This verifies pricing/eligibility, not an app-device save.

## Free SIM creation
### TC-SIM-003: Create a Free line and record its in-app setup alert
- **Preconditions**: A valid number is Free-eligible; push is registered; Telegram is bound, enabled, and allowed by the alert category.
- **Expected**: The line appears once, no plan fee is charged, and an in-app line-added alert plus eligible push and Telegram deliveries are queued.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: No end-to-end line creation or provider delivery was exercised.

## Standard setup pricing and wallet fee
### TC-SIM-004: Debit the configured Standard fee once
- **Preconditions**: A temporary test user has sufficient wallet funds; setup pricing returns Standard.
- **Expected**: The quoted fee is debited once; a retry with the same reference does not debit again; insufficient funds leave the wallet unchanged.
- **Status**: VERIFIED
- **Notes/Found Issues**: Rollback checks confirmed the current $2.50 quote, fee debit, idempotent retry, and insufficient-funds refusal. The dedicated legacy C3c fixture itself lacks a wallet.

## Standard line finalization
### TC-SIM-005: Finalize a paid Standard line and queue its setup alert
- **Preconditions**: A new eligible number is selected; the setup order is funded and the wallet reservation succeeds.
- **Expected**: The Standard line is saved only after payment confirmation; a setup notification is recorded and the line is not duplicated on retry.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Controller/form flow inspected; no end-to-end app add was run.

## Free Telegram disclosure
### TC-SIM-006: Describe Telegram correctly for Free-plan users
- **Preconditions**: The Add SIM form is set to Free and Telegram is configured.
- **Expected**: The form accurately describes Telegram availability and does not claim a paid plan is required when the backend permits Free Telegram alerts.
- **Status**: FAILED
- **Notes/Found Issues**: The form says Free alerts are push-only and Telegram requires paid. Backend policy permits Telegram for the basic tier; copy is contradictory. See sim_line_form_screen.dart and migration 20260916070000_allow_telegram_for_free_tier.sql.

## Standard channel status summary
### TC-SIM-007: Show only enabled notification destinations
- **Preconditions**: Email, WhatsApp, and Telegram destinations exist in mixed enabled/disabled states.
- **Expected**: The summary names enabled destinations and prompts the user to enable or configure missing channels.
- **Status**: FAILED
- **Notes/Found Issues**: The Add SIM summary checks configured address/chat/phone values but not each channel’s is_enabled flag; it may report a disabled email or Telegram channel as active.

## SIM detail and provider status
### TC-SIM-008: Show provider, verification, health, and expiry details
- **Preconditions**: A line has carrier/provider data, a plan expiry, and a mix of verification states.
- **Expected**: Detail view shows the matching carrier identity, health, plan tier, expiry, and verification state without stale values.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Detail widgets and controller were inspected; no screen test completed.

## Line actions and protection controls
### TC-SIM-009: Open manual refill, auto-refill, and alert-threshold controls
- **Preconditions**: A saved line is active and the user has the required plan and wallet permissions.
- **Expected**: Manual refill uses the selected line; auto-refill state persists; alarm thresholds save and render for the same line.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: The refill-price approval backend suite passed 5/5 Node tests; the Flutter actions and device alarm effects remain untested.

## Execution history
### TC-SIM-010: Load and page a line’s execution history
- **Preconditions**: The selected line has successful, failed, and pending executions.
- **Expected**: History is scoped to that line, displays accurate statuses and amounts, and pagination adds older rows without duplicates.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: No execution-history screen test completed.

## Return Trip wizard
### TC-SIM-011: Configure a return date and eligible package
- **Preconditions**: A saved SIM and destination with available packages exist.
- **Expected**: Connectivity check, arrival date, package selection, cost, and final confirmation stay consistent with the selected line and dates.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Return-trip quote and flow tests are present but the Flutter runner did not return results.

## Shared SIM refill approval
### TC-SIM-012: Reject stale refill approvals and accept a current quote
- **Preconditions**: A refill quote has an amount, expiry, and approval state.
- **Expected**: Only the current approved quote can proceed; expired or altered values are rejected without a debit.
- **Status**: VERIFIED
- **Notes/Found Issues**: test/refill_approval_backend.test.cjs passed 5/5 tests. This covers the backend contract, not a live carrier refill.

## Standard SIM notification matrix
### TC-SIM-013: Add a Standard SIM and notify through every configured channel
- **Preconditions**: A valid new SIM is eligible for Standard; the test account has sufficient wallet balance; app, device push, email, WhatsApp, and Telegram destinations are configured and enabled for the relevant alert categories.
- **Expected**: The new line is added once; an in-app alert and device push are produced; email, WhatsApp, and Telegram notifications are sent or queued for enabled destinations; missing or disabled destinations trigger a clear setup prompt; the configured Standard fee is deducted once.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Live provider delivery and end-to-end Standard creation were not exercised. Fee debit, retry idempotency, and insufficient-balance behavior are separately VERIFIED in TC-SIM-004.
