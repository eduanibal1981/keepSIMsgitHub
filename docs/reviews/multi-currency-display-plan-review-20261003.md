# Multi-currency display plan review

Reviewed 3 October 2026 against repository HEAD `4f4dc03` and the current working tree.

## Judgment

**Approve the presentation-only direction; revise the attached specification before execution.** Keeping canonical USD prices primary and showing clearly approximate local equivalents is consistent with the existing G11 implementation. The original plan is not ready to execute verbatim: its rate formatter does not meet its own precision guarantee, its blanket ban on backend currency conversion contradicts existing supplier normalization, and it assumes currency and freshness behavior the client does not currently provide.

The corrected [implementation plan](../implementation-plans/multi-currency-display-plan-20261003.md) resolves these specification gaps. This review commits documentation only. It does not certify implemented coverage or authorize deployment.

## Findings

### R1 — P1: Four decimal places can still display a positive rate as zero

The proposed formatter unconditionally uses four places below 0.1 local units, even when a caller requests more precision. At the plan's example rate of 0.385 OMR per USD:

| Canonical rate | Local amount | Proposed four-place output |
| --- | --- | --- |
| USD 0.012/min | OMR 0.00462/min | OMR 0.0046/min |
| USD 0.0002/sec | OMR 0.000077/sec | OMR 0.0001/sec |
| USD 0.0001/sec | OMR 0.0000385/sec | OMR 0.0000/sec |

The checklist also expects 0.005 for the first example, whereas the proposed implementation produces 0.0046. The existing `Money.approxLocal` already respects `fx.decimalDigits`, including three-place currencies; ordinary local amounts are not uniformly rounded to two places.

**Correction:** specify adaptive rate precision with a bounded maximum and a less-than-threshold representation below that maximum. Respect requested precision, distinguish exact zero from tiny positive amounts, and add explicit expectations for per-minute rates, per-second rates, and early in-call cost estimates. Keep ordinary money formatting unchanged.

Evidence: `lib/core/fx/money.dart:36`, `test/features/fx/money_display_test.dart:180`; OMR metadata in `supabase/migrations/20260821060000_k7_add_omr_fx_rate.sql:29`.

### R2 — P1: The backend conversion prohibition is broader than the intended invariant

The repository already converts supplier-native prices into canonical USD at ingestion and records their provenance. `convertToUsd` divides a supplier amount by a trusted costing rate, and `offerCacheRow` stores native source currency/amount and the applied rate. Refill benefits also have their own denomination currency. These are existing business contracts, separate from a customer's display preference.

**Correction:** prohibit using *display FX* in payment, balance, authorization, or ledger calculations. Preserve existing supplier normalization, source-currency metadata, carrier face values, and provider payload semantics. Remove the claim that every provider API or database amount is inherently USD. Route display FX directly to rendering; never feed it into `PlanPayment`, wallet debits, or the call cost calculator.

Evidence: `servers/offer_validation.js:253`, `servers/offer_validation.js:271`, `supabase/migrations/20260821080000_k9_offer_cost_currency_provenance.sql`.

### R3 — P1: Onboarding Step 3 cannot use an unsaved Step 2 choice automatically

The currency dropdown only updates `_selectedCurrency`. The profile preference is written later by `completeOnboarding`. `FxController` reads the persisted preference through `get_fx_display_context`, so simply inserting `ApproxLocalText` in Step 3 can show USD-only output or a previously saved currency. The onboarding picker is also a hardcoded list without OMR, while the preferences picker uses the server's available currencies.

**Correction:** use the RPC's available options and explicitly persist the chosen display preference through `setDisplayCurrency` before entering Step 3, without completing onboarding or changing the subscription. Handle save failures and loading without showing a previous currency as the new choice. Refresh FX after onboarding completion as well.

Evidence: `lib/features/profile/presentation/ui/onboarding_screen.dart:95`, `:634`, `:1165`; `lib/features/profile/presentation/controller/profile_controller.dart:26`; `lib/core/fx/fx_provider.dart:46`.

### R4 — P1: Server fallback only applies when the cached context is fetched again

The RPC evaluates staleness at request time. `FxController` is kept alive and does not observe authentication, schedule refreshes, or revalidate on app resume. Only its own currency setter currently invalidates the FX provider. A long-running app can retain an expired quote, an earlier user's currency, or a signed-out USD fallback after sign-in.

**Correction:** specify identity-scoped refresh, immediate clearing on sign-out/account change, app-resume revalidation, and conservative revalidation before the last server-approved context can expire. Treat 72 hours as the default configurable value. Server-provided `age_hours` is rounded to two places; scheduling must include a safety margin. Suppress previous converted data during required revalidation and fall back to USD if the request fails. Use server metadata and elapsed time, not a device wall clock that independently adjudicates staleness.

Evidence: `lib/core/fx/fx_provider.dart:27`, `lib/core/fx/fx_provider.g.dart:38`, `lib/core/fx/fx_context.dart:48`; `supabase/migrations/20260810000000_g11_fx_display_layer.sql:316`, `:356`.

### R5 — P2: Prices and deposit previews must follow the existing USD quote

The plan hardcodes Standard at USD 2.50 and supplies a premium calculation snippet as a universal template. Existing screens use configuration, server setup quotes, annual fees, first-refill costs, and gateway/deposit amounts with different meanings. A local estimate of the wrong component remains misleading even when its multiplication is correct.

**Correction:** convert the exact canonical value shown in the adjacent USD element. Preserve the existing distinction between annual fee, due today, refill price, authorization cap, and actual deposit. The shortfall helper already applies a minimum deposit; do not preview only the raw balance difference when a larger deposit will be requested. Do not change quoting or pricing formulas for this presentation task.

Evidence: `lib/features/sim_lines/domain/plan_payment.dart:29`, `:294`; `lib/features/sim_lines/presentation/screens/sim_line_form_screen.dart:997`; `lib/features/profile/presentation/ui/onboarding_screen.dart:482`; `lib/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart:509`.

### R6 — P2: The live-input example does not actually subscribe to edits

Reading `_amountController.text` during build is not a listener. Gift and refund fields lack an edit-triggered rebuild, and programmatic amount updates must refresh the preview too, including refund MAX and gift suggested amounts.

**Correction:** use a controller-backed `ValueListenableBuilder` or a properly installed/disposed listener. Hide invalid, empty, non-finite, and non-positive previews without changing submitted USD values or validation. Verify typing, clearing, suggestions, and MAX.

Evidence: `lib/features/wallet/ui/gift_credit_sheet.dart:230`, `:288`; `lib/features/wallet/ui/refund_funds_sheet.dart:378`, `:397`.

### R7 — P2: Coverage and layout instructions need to preserve current behavior

Wallet balance, PayPal selected/initial amounts, manual refill summaries, eSIM checkout, and the compare card's current price already include `ApproxLocalText`. Extend their missing values rather than duplicating estimates. The proposed country-chip replacement removes its existing USD per-second figure, and changing the parent to `ConsumerWidget` is unnecessary if only the child subscribes to FX.

The hand-off list omits named targets such as gift/refund sheets, SIM creation, savings dashboard, and filter headers. Same-row estimates, fixed-width chips, hardcoded white colors, and unconditional spacing need narrow-width, large-text, theme, and RTL verification. eSIM estimates must respect price availability/staleness guards and null per-GB values.

**Correction:** maintain a target-by-target completion matrix, preserve both existing USD rate units, localize new explanatory copy/units, and gate additional layout with the local estimate. Retain existing partner-price freshness behavior; do not present an unavailable price as a fresh local quote.

Evidence: current `ApproxLocalText` call sites; `lib/features/calling/presentation/widgets/country_rate_chip.dart:61`; `lib/features/esim/presentation/widgets/compare_offer_card.dart:300`, `:339`.

## Verification and limits

- Inspected the attachment, formatter/context/provider, relevant screen price/input paths, FX migration/tests, PayPal order currency, and supplier cost normalization.
- Reproduced the proposed precision failure using the exact example multiplication and four-decimal formatting.
- No application source, database, worker, deployment, or payment changes were made. No live provider purchases or database write probes were run.
- Existing unrelated working-tree changes are excluded from this documentation commit.
- Focused existing Flutter tests passed: 23 tests across `test/features/fx/money_display_test.dart` and `test/features/calling/smart_call_cost_calculator_test.dart`, run with `flutter test --no-pub`. These verify the existing baseline, not the proposed new formatter/lifecycle behavior.

The implementation executor must provide new precision/lifecycle/widget evidence and regression results before claiming the complete feature is delivered. Source inspection alone is not evidence that all screens render correctly.
