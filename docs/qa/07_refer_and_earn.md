# 07 — Refer and Earn

## Referral code
### TC-REF-001: Display and copy the signed-in user’s referral code
- **Preconditions**: The account has a referral code or a code can be generated.
- **Expected**: A stable code is displayed and copied exactly; another account’s code is never shown.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: ReferralsScreen and controller were cataloged; no Flutter run completed.

## Share referral link
### TC-REF-002: Share an attribution-preserving referral link
- **Preconditions**: A referral code exists and the platform share sheet is available.
- **Expected**: Shared link contains the account’s referral code and opens the expected onboarding route.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: No external share sheet was opened.

## Earnings and reward claim
### TC-REF-003: Show referral milestones and claim an eligible reward
- **Preconditions**: A referral has reached a payable milestone and the user meets claim requirements.
- **Expected**: Progress reflects ledger-backed referrals; claim is idempotent and wallet credit appears once.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Referral SQL suite uses fixed fixture IDs and was not run in the active database.
