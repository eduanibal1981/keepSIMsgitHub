# Multi-currency display layer: reviewed implementation plan

Prepared 3 October 2026. Supersedes the attached draft for execution; see the [review](../reviews/multi-currency-display-plan-review-20261003.md) for findings and evidence.

Status: **approved architectural direction, implementation pending**. This document is a specification, not a report of completed feature work.

## 1. Objective and invariants

Extend the existing G11 display-currency layer across subscriptions, wallet/recharge, eSIM offers, and Smart Call prices. Keep canonical USD primary and add one clearly approximate local equivalent where useful.

1. All customer wallet balances, charged prices, authorization limits, call-cost calculations, and ledger amounts retain their existing canonical USD contracts.
2. Display conversion is one multiplication of the existing USD value by the server-approved display rate, performed only in rendering. No reverse conversion of user display amounts and no display FX in business logic, requests, debits, or ledger writes.
3. Existing supplier-native price normalization, native source-currency provenance, provider payloads, and carrier benefit denominations remain intact. These are separate from customer display currency.
4. Do not change price schemas, payment formulas, quote selection, rounding in accounting, charging paths, or provider adapters. Persist only the existing display preference through the profile repository. No new backend deployment is required by this plan.
5. Charge/authorization controls display their applicable canonical USD amount. Local figures stay secondary, carry `≈`, and never replace USD input labels or charge values. Preserve existing per-minute/per-second USD precision; `Money.usd` is unsuitable for micro-rates.
6. Load display context/options through `get_fx_display_context`. Its configured policy owns disabled, unknown-currency, and stale-rate fallback. `FX_MAX_AGE_HOURS` defaults to 72 and is configurable. Failed/loading context produces usable USD-only screens.
7. Convert only a price the adjacent USD UI can actually quote. Preserve existing offer-freshness guards, free/ringing states, unavailable rates, and null per-GB values.

The intended dependencies are:

```text
Canonical USD data -> existing pricing/call-cost logic -> USD UI value
Profile preference -> server display FX context -------> local UI estimate
```

The FX context has no dependency edge into pricing/call-cost logic. Add localized copy near monetary decisions equivalent to: "Approximate {currency} values are shown; charges are in USD." Only name a local currency when an applicable conversion is active.

## 2. Establish the execution baseline

Read applicable repository instructions, inspect the current working tree, and preserve concurrent work. Relevant pricing/screen files already have unrelated edits at plan review time. Do not overwrite those files with the pasted examples or commit unrelated changes.

The FX context, RPC, preference setter, ordinary formatter, and several estimates already exist. Inventory `ApproxLocalText` call sites first. Use existing tests as the baseline and add focused assertions for the new guarantees below. Do not claim the review's existing tests cover new behavior.

## 3. Phase A — Rate precision and FX lifecycle

### A1. Extend `lib/core/fx/money.dart`

Add `Money.approxLocalRate` and `ApproxLocalRateText` using the same provider, symbol spacing, theme defaults, and null/hidden behavior as the existing ordinary formatter. Preserve `Money.approxLocal` behavior and its existing tests.

Rate-formatting contract:

- Accept canonical USD rate, FX context, caller-provided localized unit, and requested decimals. The widget also supports style and text alignment. It owns its provider subscription; its parent need not become a consumer solely for this child.
- Reject non-finite inputs/rates/products and negative telecom rates. No conversion renders for a USD/fallback context. Exact zero may be formatted as zero when the source rate is genuinely zero.
- Validate requested decimals within 0–6. Start with the maximum of requested decimals, currency minor digits, and four places when the positive local value is below 0.1.
- Increase precision up to six places if a positive value would round to zero. Never silently reduce the caller's requested precision.
- If a positive value would still round to zero at six places, display an approximate less-than threshold such as `≈ < OMR 0.000001/min`, using the context's actual symbol and the caller's unit. Do not display it as free or zero. Localize the less-than phrasing as needed for accessibility.
- Permit an empty unit for precision-sensitive early in-call cost estimates. Ordinary balances, plan fees, and normal totals keep the existing ordinary money formatter.

Use deterministic formatter fixtures. With an English locale, symbol `OMR`, and a test rate of 0.385, USD 0.012/min displays `≈ OMR 0.0046/min`, and USD 0.0001/sec must not display zero. The 0.385 fixture is not a production rate; production uses RPC metadata and OMR's actual configured symbol.

### A2. Make retained FX context safe to reuse

Extend `lib/core/fx/fx_provider.dart` and its context model as necessary:

1. Observe the authenticated user identity and persisted display preference through existing auth/profile state. Clear previous converted data on sign-out/account change; a signed-out result must not remain cached after sign-in. Avoid invalidation loops with `setDisplayCurrency`.
2. Revalidate on app resume and after profile preference changes, including onboarding completion. During required revalidation, suppress previous converted figures explicitly; do not assume `.asData` alone removes retained data during every Riverpod refresh state.
3. While the app is active, periodically revalidate and schedule conservative revalidation before the server-approved rate can expire. The RPC already provides `age_hours` and `max_age_hours`; retain the needed metadata in the model. `age_hours` is rounded to two decimals, so allow at least one minute of margin plus request elapsed time. Use elapsed-time scheduling from the response, not device wall-clock subtraction from `as_of`.
4. If the permitted interval is already exhausted or metadata is unusable, suppress the local estimate and refresh. A failed refresh returns USD-only output. Use a bounded retry cadence rather than an immediate retry loop for unavailable FX.
5. Dispose timers and lifecycle subscriptions appropriately. Stop background polling; revalidate on return. Currency changes must not rebuild unrelated charge calculations or change in-flight request amounts.
6. Regenerate only applicable model/provider outputs using the repository's existing generation workflow if source annotations change.

Server fallback remains authoritative; client scheduling asks for a fresh verdict before reusing a quote beyond its permitted lifetime. No changes to costing FX policy are part of this phase.

## 4. Phase B — Subscription and onboarding displays

| Target | Required rendering |
| --- | --- |
| `lib/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart` | Estimate the existing displayed annual/upgrade price and the actual minimum-adjusted deposit amount in the insufficient-funds flow. |
| `lib/features/profile/presentation/widgets/subscription_upsell_sheet.dart` | Estimate monetary prices already supported by the sheet; preserve existing account/line tier behavior. |
| `lib/features/sim_lines/presentation/screens/sim_line_form_screen.dart` | Estimate existing plan fee, setup refill, and due-today values separately where shown; use the same server quote/configuration as each USD figure. |
| `lib/features/profile/presentation/ui/onboarding_screen.dart` | Show selected-currency estimates after preference synchronization, including tier and final price summaries. |

Do not hardcode Standard as USD 2.50 or treat every premium number as an annual total. Reuse the exact configuration/quote/helper already backing each USD label. Keep annual recurring fee, first refill, due today, and wallet deposit distinct. Keep loading/unavailable price states honest.

Onboarding preference synchronization is part of this phase:

1. Populate currency options from the same RPC-backed available list used in preferences. USD remains selectable; OMR is available only when offered by the server.
2. On advancing from the currency step, persist a changed choice through `FxController.setDisplayCurrency` and wait for its resolved context. This updates only the existing preference; it must not set onboarding completion or upgrade a tier.
3. Disable repeated advancement while saving. On save failure, retain the chosen form value, show a localized retryable error, and do not claim an estimate in that currency. A successful server fallback can continue with USD-only display and an explanation.
4. Handle going back and changing currency again. Final onboarding submission uses the selected code and refreshes FX afterward.

## 5. Phase C — Wallet, recharge, and amount inputs

| Target | Required rendering |
| --- | --- |
| `lib/features/wallet/ui/wallet_screen.dart` | Preserve the existing balance estimate; add missing monetary warnings and quick-deposit values where useful. |
| `lib/features/payments/presentation/screens/paypal_checkout_screen.dart` | Preserve selected/initial amount estimates; add one estimate to each existing preset chip. Preserve current preset list, selection tolerance, input validation, minimums, and handlers. |
| `lib/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart` | Estimate each quoted canonical final price/cap/threshold actually shown. Do not convert carrier-native face-value input or change recurring authorization. |
| `lib/features/sim_lines/presentation/widgets/manual_refill_bottom_sheet.dart` | Preserve existing package/range price estimates; fill verified gaps without duplicates. Confirmation amount stays the existing final USD debit. |
| `lib/features/wallet/ui/gift_credit_sheet.dart` | Live estimate of valid positive entered USD, including suggested-value updates. |
| `lib/features/wallet/ui/refund_funds_sheet.dart` | Live estimate of valid positive entered USD, including loaded eligibility and MAX updates. |

For gift/refund, use `ValueListenableBuilder<TextEditingValue>` or a correctly installed/disposed controller listener. Reading controller text in build is insufficient. Clearing or invalid input removes the estimate. Never alter controller text, parsed payment amount, eligibility logic, or submission precision to match a local estimate.

## 6. Phase D — eSIM offers and checkout

| Target | Required rendering |
| --- | --- |
| `lib/features/esim/presentation/widgets/compare_offer_card.dart` | Preserve current-price estimate; add list-price and per-GB estimates only when their USD figures are shown and quoteable. Keep list-price strikethrough and unlimited/null per-GB behavior. |
| `lib/features/esim/presentation/widgets/compare_offer_details_sheet.dart` | Add a local estimate alongside the quoted USD price summary/header. Respect existing partner-price availability and external-deal behavior. |
| `lib/features/esim/presentation/widgets/esim_checkout_sheet.dart` | Preserve existing plan-price estimate; verify wallet debit and purchase CTA use the unchanged USD price. |
| `lib/features/esim/presentation/screens/esim_plans_screen.dart` | Audit monetary filter labels and add useful estimates beside existing USD thresholds. Sorting, filter values, and affordability remain canonical USD. |

Use the precision-aware formatter for tiny per-GB values. Do not recalculate prices from GB counts. A stale/unquoteable offer must not gain a seemingly fresh local quote solely because FX is fresh. Do not duplicate existing estimates or change price freshness policy as part of this task.

## 7. Phase E — Smart Call rates and savings

| Target | Required rendering |
| --- | --- |
| `lib/features/calling/presentation/widgets/country_rate_chip.dart` | Add precision-aware local rates while retaining both existing USD per-minute and per-second figures and selection behavior. |
| `lib/features/calling/presentation/screens/calling_screen.dart` | Estimate destination rate, per-second rate, and existing preview cost using the same effective USD source as each adjacent label. |
| `lib/features/calling/presentation/widgets/destination_country_search_sheet.dart` | Add local destination-rate estimates without changing USD ordering/filtering or country selection. |
| `lib/features/calling/presentation/widgets/rate_savings_calculator_widget.dart` | Add local estimates of existing savings and relevant costs/rates. Preserve USD roaming inputs and calculation formulas. |
| `lib/features/calling/presentation/screens/active_call_screen.dart` | Add local running-cost/rate estimates from existing state; preserve connected/completed versus free-while-ringing behavior. Use precision-aware display for tiny positive costs. |
| `lib/features/calling/presentation/screens/smart_call_savings_screen.dart` | Add local savings/cost/rate estimates where current USD values appear; keep estimated savings distinct from actual debits. |

Do not introduce new default rates or connection fees. Do not feed converted rates into `SmartCallCostCalculator` or the timer. Preserve authoritative cost reconciliation after completion. Percentage savings and other dimensionless results are not currency values.

## 8. Localization and layout acceptance

Use existing localization and theme conventions for new labels, the USD-charge explanation, units, and error/fallback copy. Use vertical layout, flexible text, or wrapping where two prices do not fit. Avoid adding hardcoded light/dark colors from pasted examples.

Verify small phone widths (including 320 logical pixels), long formatted currencies, large text, dark/light themes, and an RTL locale. Approximate values remain secondary and identifiable to accessibility tools. Hide estimate-specific spacing when the estimate is absent. Do not replace an existing USD unit or truncate the charge amount to make room.

## 9. Verification and completion gates

### Formatter and provider tests

- Preserve ordinary-money regression tests, including three-decimal currencies and symbol spacing.
- Add micro-rate fixtures for USD 0.012/min, USD 0.0002/sec, USD 0.0001/sec, requested precision above four, precision boundaries, exact zero, values below the six-place threshold, and non-finite/invalid inputs.
- Test USD, disabled, unknown/stale currency, loading, and request-failure states; none can replace the canonical USD figure.
- Test sign-out/sign-in, account switch, changed profile preference, resume, conservative expiry scheduling, failed expiry refresh, and timer cleanup with controlled time. Assert an earlier user's/expired local quote is not retained during revalidation.

### Widget and financial-contract tests

- Onboarding: Step 2 selection is persisted before Step 3 estimates, back navigation works, failure cannot masquerade as success, and no tier/completion write occurs during currency synchronization.
- Gift/refund: typing, clearing, programmatic suggestions/MAX, and invalid values update the estimate correctly.
- PayPal/eSIM/refill/plan actions: use test doubles to compare submitted USD amounts, caps, bundle/offer IDs, and currency fields before/after selecting a local currency. Existing PayPal create-order payload uses `currency_code: "USD"`; do not require real charges to prove presentation independence.
- Calls: USD rate/cost/savings results stay identical across display currencies; tiny positive local rates/costs do not become zero; ringing remains free.
- eSIM: stale/unavailable prices and null/unlimited per-GB values do not gain misleading estimates. Existing catalog filters continue using USD thresholds.
- Review the narrow-width/theme/large-text/RTL cases and assert no overflow in targeted widget tests where practical.

### Validation workflow

Run `flutter analyze` and focused FX, calling calculator/dialer/savings, profile, payment, eSIM, gift-credit, and refill/scheduled-pricing tests affected by the edits. Run the existing broader suite once after integrating the feature. Record unrelated baseline failures separately; do not silently claim they passed or repair unrelated work inside this change.

Inspect the final diff to confirm no business-logic FX dependency, local monetary writes, provider adapter changes, price schema changes, or changed payment formulas. The existing `supabase/tests/g11_fx_display_tests.sql` documents the server fallback contract; only run server tests in the repository's designated disposable test environment if backend compatibility needs validation. Production database logs/writes are not required for this UI-only change.

Complete every target row above with changed/already-covered/not-applicable status and evidence. The feature is complete only when new tests and rendering checks support its promised behavior. Make reviewable commits for core formatter/lifecycle, feature displays, and final verification; stage only files belonging to this work.
