# Multi-currency display v2.0 — implementation verification

Date: 3 October 2026

The Flutter presentation layer now shows optional, approximate local-currency amounts beside canonical USD prices. The existing USD financial values, pricing helpers, payment requests, and provider payloads remain intact. No database migration, backend worker edit, or deployment was performed.

## Completed targets

| Area | Result |
| --- | --- |
| Formatting | Preserved ordinary `Money.approxLocal`; added bounded, adaptive rate precision and a less-than threshold for positive rates below the precision limit. Zero remains zero. Invalid or unavailable FX hides the estimate. |
| Identity and lifecycle | FX follows account identity and saved currency, clears estimates during refresh, refreshes on resume, cancels background timers, and retries failures with USD fallback. Expiry uses server `age_hours`/`max_age_hours`, monotonic request duration, and a conservative safety margin. |
| Onboarding | Uses RPC currency options with the specified seeded fallback including OMR. Saves currency before advancing from step 2, reports save failure for retry, and shows configured Standard/Premium USD prices with local estimates. Preference saving does not change subscription tier or complete onboarding. |
| Subscriptions | Added local estimates to line-upgrade prices and the minimum-adjusted shortfall confirmation, the configured protection-fee component in upsell, and SIM setup fee/refill/total quotes. The upgrade action shows the existing wallet USD quote. |
| Recharge | Preserved the wallet balance estimate; added the low-balance threshold estimate, PayPal preset estimates, scheduled final-price estimates, and live gift/refund previews. Refund MAX and typing leave input values in USD. Existing manual-refill estimates were retained and given readable dark-surface styling. |
| eSIM | Added list-price and per-GB estimates to offer cards and price estimates to details. Stale/unquoteable offers suppress local prices. Preserved the existing checkout estimate and USD purchase amount. |
| Smart Call | Added local rate estimates to country chips, search results, route banners, per-second billing, and running call cost, preserving both existing USD units. Added local cost/savings estimates to both calculators. Ringing remains free. |
| Charge explanations | Added localized approximate-currency/charged-in-USD explanations in all nine existing languages. |
| Layout | Preset buttons wrap; checkout scrolls at short heights; long eSIM currency labels, call-rate chips, and refund balance labels fit narrow layouts. USD remains visible. |

Display helpers are only used in rendering. They do not write back into text controllers or supply amounts to payment, balance, authorization, call-costing, or ledger calculations.

## Verification results

- **Final affected-feature suite: 210 passed.** Includes FX, calling, profile, payments, eSIM, wallet, refill pricing, and line-refill quotes. It covers the final upgrade label and live gift/refund previews. See [test log](../../output/multi-currency-v2/affected-verified.txt).
- **Full repository suite: 610 passed, 3 failed.** The failures are outside the currency implementation: the paid-line channel-status test expects one `ACTIVE` badge while alarm and push both render it; two biometric-overlay tests fail during disposal in the unchanged VoIP controller. See [full suite log](../../output/multi-currency-v2/full-suite-final.txt). The final minor upgrade-label change and its new test were subsequently verified by the affected-feature suite.
- **Static analysis completed: 99 diagnostics.** Its error is in the unchanged `docs/reviews/voip-quality-followup-repros_test.dart:34`, where a callback may return null instead of `SignalingSubscriptionResult`. Existing warnings/info remain. A subsequent additional analysis of the final changed files could not start because automatic approval review hit the account usage limit. See [analysis log](../../output/multi-currency-v2/analyze-verified.txt).
- **Generation completed.** FX model/provider generation and localization generation succeeded. The generator reports an existing `json_annotation` version-constraint warning; no dependency upgrade was made. See [generation log](../../output/multi-currency-v2/generation-final.txt).
- **Boundary checks passed.** Original backend/schema file hashes still match the working-tree baseline; `servers/` is clean. Token comparisons, ignoring formatting/comments/trailing commas, confirm unchanged PayPal checkout/capture methods and unchanged gift/refund submission methods. Financial controllers/models were not edited. See [boundary results](../../output/multi-currency-v2/boundary-verification.json).
- Narrow-width, enlarged-text, light/dark, Arabic RTL, long-currency-label, stale-price, expired-rate, failed-refresh, account-change, and pause/resume checks are included in the FX widget/lifecycle tests.

The workspace already contained unrelated changes. They were retained. Four existing UI files received scoped additions for this task; a separate notification-controller change observed after the initial snapshot was left untouched. Payment and backend verification used the initial working-tree hashes where appropriate rather than assuming a clean checkout.

Live payment/provider transactions and deployment were not part of this presentation-only verification. Implementation changes remain in the working tree for review; this execution did not create an implementation commit.
