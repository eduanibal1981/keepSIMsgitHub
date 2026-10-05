# KeepSIMs Screen Audit — Index

**Audit date:** 2026-10-04  
**Scope:** The 13 screen groups requested in the attached mission  
**Overall disposition:** **PARTIAL**

## Coverage

| Screen group | Cases | Verified | Failed | Cataloged, untested |
|---|---:|---:|---:|---:|
| [# 01 — Dashboard ](01_dashboard.md) | 7 | 0 | 1 | 6 |
| [# 02 — Protected SIMs ](02_protected_sims.md) | 13 | 3 | 2 | 8 |
| [# 03 — Wallet and Payments ](03_wallet_payments.md) | 6 | 1 | 2 | 3 |
| [# 04 — eSIM Store and Roaming Tools ](04_esim_store.md) | 6 | 0 | 0 | 6 |
| [# 05 — Offline Refill and Emergency Recovery ](05_offline_refill.md) | 5 | 0 | 1 | 4 |
| [# 06 — Household and Shared Lines ](06_household.md) | 4 | 0 | 0 | 4 |
| [# 07 — Refer and Earn ](07_refer_and_earn.md) | 3 | 0 | 0 | 3 |
| [# 08 — Profile and Onboarding ](08_profile_onboarding.md) | 6 | 0 | 2 | 4 |
| [# 09 — Protection Console and Simulators ](09_protection_console.md) | 4 | 0 | 0 | 4 |
| [# 10 — Settings and Preferences ](10_settings_preferences.md) | 5 | 0 | 0 | 5 |
| [# 11 — Smart Calls and VoIP ](11_smart_calls.md) | 9 | 1 | 0 | 8 |
| [# 12 — Help and Support ](12_help_support.md) | 6 | 0 | 0 | 6 |
| [# 13 — Auth and Notifications ](13_auth_notifications.md) | 7 | 1 | 0 | 6 |
| **Total** | **81** | **6** | **8** | **67** |

Verified cases cover focused component/backend contracts and rollback SQL checks; they do not imply that the entire screen or provider was exercised end to end.

## Execution summary

- **Backend JavaScript:** 60/60 tests passed across the eight files in test/*.test.cjs. Direct file execution was used because node --test hit a Windows process-spawn restriction.
- **Supabase SQL:** line_tiers_and_app_fee_rules_tests.sql passed 25/25 checks; wallet_accounting_invariants_tests.sql passed 7/7 checks; an isolated temporary-user rollback check passed Standard plan fee debit, idempotent retry, and insufficient-balance checks.
- **Flutter:** no results. Three focused runner attempts remained silent, including one small wallet test through a pseudo-terminal; the runs were stopped. Existing Flutter tests are therefore cataloged, not marked verified.
- **Legacy SQL scripts:** C3c stopped because its seeded account has no wallet; C2 expects the old pg_net queue; G2 expects a seeded price watch not present; N1 fails on a malformed JSON-to-array cast. These are fixture or test-harness failures, not passing product checks.
- **Approval review blocks:** H8 household SQL was rejected because it deletes household rows for the first real profile and mutates real invitation state. C9a eSIM SQL was rejected because it inserts a notification for a real profile and a live cache row that could trigger side effects. Neither was retried or bypassed.
- **Live delivery and device behavior:** no push/email/SMS/WhatsApp/Telegram was sent to a real destination; no carrier refill, eSIM purchase, device alarm, or physical-device flow was performed.
- **Paid dialer:** all widgets are cataloged; no outbound PSTN call was placed. The excluded case is TC-CAL-009 in 11_smart_calls.md.

## Findings requiring product follow-up

- Dashboard balance concealment control is absent.
- SIM add messaging says Free Telegram is unavailable while backend policy permits the channel; the Standard setup summary ignores each destination’s enabled state.
- Wallet history category filters and the requested Stripe / Apple Pay / Google Pay / crypto top-up methods were not found; the current wallet deposit route uses PayPal.
- Emergency recovery contact management was not found.
- Profile avatar upload, password-change, and 2FA controls were not found in the inspected routes. A separate biometric lock control exists.

## Test data and safety

Wallet and tier database checks used rollback transactions; the fee smoke test used a generated temporary account, injected test balance inside the transaction, and rolled back the account and ledger. No real user wallet was funded. The household and eSIM tests blocked by review were left untouched.

**Signed:** Codex QA execution  
**Sign-off:** **PARTIAL** — 81 cases cataloged; 6 verified, 8 failed, 67 left untested.
