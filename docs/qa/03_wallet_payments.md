# 03 — Wallet and Payments

## Wallet balance card
### TC-WAL-001: Render balance, currency conversion, and offline state
- **Preconditions**: Wallet has a known balance, preferred currency, and an online or offline network state.
- **Expected**: USD and converted balances remain consistent; offline state is visible and funding actions are safely disabled.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Money-format tests exist but could not be run through Flutter in this session.

## Deposit and refund actions
### TC-WAL-002: Complete or cancel a wallet deposit and refund request
- **Preconditions**: A signed-in user has an available payment route or refundable balance.
- **Expected**: Deposit credits only after verified capture; cancellation moves no funds; refund requests reserve only eligible paid funds.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: PayPal screen tests exist but Flutter execution stalled; no live payment or refund was submitted.

## Transaction history filters
### TC-WAL-003: Filter history by All, Top-up, Spend, and Refund
- **Preconditions**: The ledger contains at least one deposit, debit, and refund.
- **Expected**: Each filter shows only its category and All restores the complete ledger.
- **Status**: FAILED
- **Notes/Found Issues**: WalletScreen currently renders an unfiltered transaction feed and count; no category filter controls were found.

## Wallet accounting
### TC-WAL-004: Maintain balances through holds, capture, release, and refund
- **Preconditions**: An isolated temporary user begins with a zero-balance wallet.
- **Expected**: Available, held, posted, and refundable balances reconcile after each action; overspending is rejected.
- **Status**: VERIFIED
- **Notes/Found Issues**: Rollback SQL wallet_accounting_invariants_tests.sql passed 7/7 assertions. A separate temporary-user rollback check passed fee debit, retry, and insufficient-funds checks.

## Automatic funding settings
### TC-WAL-005: Save automatic-fund threshold and refill amount
- **Preconditions**: At least one payment card is linked.
- **Expected**: Threshold, funding amount, and enabled state persist; enabling without a linked card is refused with an explanation.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: PaymentsScreen contains threshold and card-presence guards; the UI was not exercised.

## Wallet top-up provider choices
### TC-WAL-006: Offer only configured wallet funding methods
- **Preconditions**: User opens wallet funding methods in a supported environment.
- **Expected**: Sandbox Stripe, Apple/Google Pay, crypto, or voucher choices work only when configured and do not claim success before confirmed payment.
- **Status**: FAILED
- **Notes/Found Issues**: Inspected wallet flow routes deposits through PayPal and card management/auto-funding; no Stripe, Apple Pay, Google Pay, or crypto wallet top-up flow was found. Offline SIM vouchers are a separate feature.
