# Tier-aware refill pricing and carrier-rule interval implementation plan

Prepared: 2026-09-14  
Audience: AI executor implementing and verifying the change  
Status: implementation plan only; this document does not authorize deployment or live financial operations

## 1. Required outcome

Fix every refill-selection entry point so it shows and ultimately charges the refill fee belonging to the target SIM line:

| Line tier | Fee rule | Example on a USD 0.20 carrier cost |
|---|---:|---:|
| Free / Basic | max(7%, USD 0.50) | USD 0.70 total |
| Standard | max(5%, USD 0.30) | USD 0.50 total |
| Premium | max(3%, USD 0.10) | USD 0.30 total |

The published row in `app_fee_rules` remains the authority. The figures above are required fallbacks and acceptance-test fixtures, not a second configurable source.

The fix must cover all of these surfaces:

1. Manual Refill (regression protection; it is currently the correct reference behavior).
2. The suggested schedule on the “Runs out in … days” card.
3. The sheet opened by the forecast card’s “Use it” button.
4. The Custom Auto-Refill row on the SIM detail screen.
5. Editing an existing custom refill schedule.
6. Free/Basic, Standard, and Premium lines independently; an account’s highest tier must not discount another line.

The interval selector must also:

- remove the production “1 Hour” test option;
- add the line’s exact carrier-rule interval as a first-class option;
- display the Vodafone Egypt example as `Carrier rule · 76 days`;
- save and execute that option at 76 days without translating it to 85/90 days or applying another safety reduction.

This ticket does not change annual membership prices, upgrade/downgrade behavior, plan eligibility, or which tiers are allowed to enable automation. Preserve the currently approved access policy while correcting prices for every tier that can reach these surfaces.

## 2. Current-source diagnosis

### 2.1 Why Manual Refill is right and both other entry points are wrong

`lib/features/sim_lines/presentation/widgets/manual_refill_bottom_sheet.dart` resolves `widget.simLine.effectiveTier`, selects that tier from `refillFeeRulesProvider`, and passes both the tier percentage and minimum floor to `RefillPricing.quote`.

`lib/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart` does not do that. Its `_appFeePercent` and `_minAppFeeUsd` read `appFeePercentProvider` and `minAppFeeUsdProvider`. Those two providers explicitly return the Premium rule. Therefore every line shown in this sheet is quoted as Premium. The screenshot confirms this: USD 0.20 + USD 0.10 = USD 0.30 is the Premium minimum, although the line badge is Basic.

Both “Use it” and Custom Auto-Refill instantiate `ScheduledTopupSheet`, so one shared pricing correction must serve both entry points.

### 2.2 Why the forecast amount is also misleading

`lib/features/sim_lines/presentation/widgets/depletion_forecast_card.dart` prints `UsageForecast.suggestedAmountUsd` directly. The forecast table stores a carrier/recommended/base amount; it is not a tier-aware customer total. The card can therefore say “A refill of $0.25” while the sheet shows a different retail total.

The card and sheet must consume one typed quote instead of independently formatting a raw forecast amount.

### 2.3 Why 76 days is invisible in the selector

`ScheduledTopupSheet` builds a static tier-dependent list:

- Premium: `[0, 7, 14, 30, 85]`
- other tiers: `[0, 7, 14, 30, 90]`

The forecast job correctly derives 76 from a 90-day carrier inactivity window by calling `public.refill_interval_days`. `_maybeApplySuggestedFrequency` can set `_frequencyDays` to 76, but no 76-day chip exists, leaving an invisible selected value. The subscription tier should not alter a carrier’s rule.

### 2.4 Financial data-shape defect to close with the UI fix

The custom sheet stores its computed retail total in `scheduled_topups.amount`. `trg_fn_sync_custom_refill_queue` then copies that same value into both `topup_executions.amount` and `topup_executions.base_cost_usd`, with a null payment gateway. This loses the separation between supplier cost and customer charge and bypasses the normal tier-aware `calculate_topup_fees` path. A frontend-only price correction would leave the database vulnerable to stale or modified client totals and can cause provider price validation to compare the retail total to the supplier price.

The implementation must preserve separate base cost, app fee, and customer total and make the server authoritative at schedule save/queue time.

## 3. Target design

### 3.1 One typed line-refill quote

Introduce a typed quote used by Manual Refill, the forecast card, and ScheduledTopupSheet. Suggested shape:

```text
LineRefillQuote
  simLineId
  offerId
  offerValue (range offers only)
  effectiveTier: free | standard | premium
  feeRuleVersion
  feePercentage
  feeMinimumUsd
  baseCostUsd
  appFeeUsd
  totalUsd
  currency: USD
```

Rules:

1. Resolve the target line first. Never use `profiles.subscription_tier` or an account commerce benefit for a line refill.
2. On the client, use the same line entitlement currently used by the correct Manual Refill flow (`SimLine.effectiveTier`) until the canonical server response is returned.
3. On the server, use `resolve_line_entitlement(sim_line_id).effective_tier` and `resolve_app_fee('refills', tier, base_cost)`.
4. A fixed offer’s base cost comes from the current provider-offer catalogue, never from a client-supplied display total.
5. A range offer accepts the chosen range value/amount, validates it against the current offer limits, then calculates the fee.
6. Round with the existing `RefillPricing.round2`/Postgres `round(..., 2)` contract.
7. If no authoritative line, offer, or published fee rule can be resolved, disable confirmation and show an unavailable/retry state. Do not silently switch the line to Premium pricing.

### 3.2 Shared client fee resolver

Create a small pure resolver (or a Riverpod family backed by a pure resolver) rather than copying Manual Refill’s switch into another widget. It must accept a line tier plus the loaded `app_fee_rules` map and return the correct rule, including the tier-specific fallback.

Recommended placement:

- pure model/resolver: `lib/features/sim_lines/domain/line_refill_quote.dart`;
- async composition of line + offer + fee rules: `lib/features/sim_lines/presentation/providers/line_refill_quote_provider.dart`.

`appFeePercentProvider` and `minAppFeeUsdProvider` may remain only for explicitly Premium legacy callers. Do not use them in any target-line refill UI. Add comments/deprecation guidance so a future caller cannot repeat this bug.

### 3.3 Stable state in the schedule sheet

Refactor `ScheduledTopupSheet` to receive the `SimLine` (or an immutable line-entitlement snapshot) rather than recovering the line in `initState` from controller state. Update both callers:

- `DepletionForecastCard`;
- `_openScheduleSheet` in `sim_line_detail_screen.dart`.

Keep only user choices in widget state: selected offer, range value, selected interval, active flag. Derive `baseCostUsd`, `appFeeUsd`, and `totalUsd` from the latest quote. Do not leave `_amount` as a stale copy made before fee rules finish loading.

At save time, use the current quote returned by the server. The wallet sufficiency check must use `totalUsd`, while provider validation and purchase use `baseCostUsd`.

For display, use consistent copy on all three surfaces, for example:

```text
$0.70
Base $0.20 · Free fee $0.50
```

Show the actual effective tier and actual rule values. Do not hardcode labels such as “Free 7%” when an administrator can publish a later percentage. The minimum floor should be visible when it is the applied fee.

### 3.4 Forecast-card quote

Build a `suggestedLineRefillQuoteProvider(lineId)` that combines:

1. the usage forecast;
2. the forecast’s `suggested_offer_id`;
3. the current line offer catalogue;
4. the target line’s effective tier and published refill rule.

Prefer the current catalogue base price for `suggested_offer_id`. Use `suggested_amount_usd` only as a validated range selection or as an estimate when no concrete offer is available. If the card has only an estimate, label it `Estimated total` and re-quote before enabling Save.

The card and the preselected offer inside the sheet must use the same quote object. If the offer disappeared or changed, show that the recommendation needs refreshing instead of displaying one amount and selecting another.

### 3.5 Carrier interval options

Introduce a pure `ScheduleIntervalOption` builder. Inputs should include the current carrier rule, the forecast, and an existing schedule. Output rules:

1. Never include zero or a one-hour option.
2. Compute the carrier option with the same contract as the server:
   `RefillPricing.refillIntervalDays(rule.inactivityLimitDays, override: rule.refillIntervalDaysOverride)`.
3. Label it `Carrier rule · N days`; for the reported line, N is 76.
4. Include normal custom presets that remain approved by product, deduplicating any value equal to the carrier option.
5. Do not vary the carrier interval by Free/Standard/Premium tier.
6. If editing an older schedule whose positive interval is not otherwise in the list, add `Current · N days` so the saved value is visible.
7. The carrier-derived number is already safety-adjusted. Pass it through unchanged when calculating `nextExecutionAt`.
8. Centralize next-execution calculation in `RefillScheduleMath`; remove the duplicated switch from `ScheduledTopupSheet`.

Retire the tier-specific 90-to-85 behavior in `UsageForecast.suggestedChipFor`. Replace it with an exact interval accessor or have the option builder use the carrier rule directly. A carrier deadline/cadence is independent of membership tier.

## 4. Server and schema implementation

Create a new forward-only migration after the current latest migration. Do not edit a migration that may already be applied.

### 4.1 Preserve the pricing components

Add the necessary schedule snapshot fields (names may be adapted to current conventions):

```text
scheduled_topups.base_cost_usd
scheduled_topups.app_fee_usd
scheduled_topups.pricing_tier
scheduled_topups.fee_rule_version
```

Keep `scheduled_topups.amount` as the customer total for compatibility. Add constraints for non-negative components and `amount = round(base_cost_usd + app_fee_usd, 2)` on refill schedules, allowing notify rows to retain their existing shape.

If an existing shared quote/snapshot type already supplies these fields, extend it instead of creating a parallel source.

### 4.2 Authoritative quote/save path

Add a server operation for custom schedules, or extend an existing safe schedule RPC, so one transaction:

1. authenticates the actor and verifies ownership/authorized manager access;
2. locks or consistently reads the target line;
3. resolves its canonical effective tier;
4. resolves the selected fixed/range offer from the current routable catalogue;
5. resolves the published refill fee and version;
6. validates `frequency_days BETWEEN 1 AND 365`;
7. computes base, fee, and total;
8. creates/updates the schedule and returns the authoritative quote/schedule snapshot;
9. lets the queue trigger rebuild only the affected pending execution.

Client values may identify the line, offer, range choice, interval, and active state. Client base cost, fee, tier, and total are display claims and must be ignored/overwritten.

If direct table writes remain available for notification schedules, add a database trigger that normalizes and validates every refill schedule so the RPC cannot be bypassed. Otherwise route notify and refill schedules through separate narrowly scoped RPCs and revoke direct refill writes.

### 4.3 Queue correctly

Update the latest definition of `trg_fn_sync_custom_refill_queue` so a queued refill has:

- `base_cost_usd = scheduled_topups.base_cost_usd`;
- `amount = scheduled_topups.amount` (or allow `calculate_topup_fees` to overwrite it);
- `app_fee_usd = scheduled_topups.app_fee_usd`;
- a wallet payment marker/code that activates the normal tier-aware fee calculation, if that is the established execution contract;
- the selected `offer_id` and range `offer_value`;
- the applied tier/rule version snapshot for audit if those columns exist or are added.

Do not copy the retail total into `base_cost_usd`. Verify the worker’s `chargedOfferPriceUsd` compares the provider offer to base cost while the wallet debit/refund uses the customer total.

When the next recurring execution is inserted, recalculate the line’s then-current tier and published fee rule or call the same authoritative pricing function. Do not blindly copy a year-old fee snapshot. Any supplier price increase beyond the user-authorized range/cap requires the project’s existing re-quote/consent behavior rather than a silent higher charge.

### 4.4 Remove hourly schedules safely

Before adding a positive-frequency constraint:

1. count and report all `scheduled_topups.frequency_days = 0` rows by schedule type and active state;
2. pause them (`is_active = false`, paused status) rather than silently converting them to a chargeable cadence;
3. cancel their pending/pending-payment executions using the existing cancellation mechanism;
4. retain the rows for audit and allow users to edit them into a valid interval;
5. add a database constraint requiring `frequency_days BETWEEN 1 AND 365` for new/updated production schedules;
6. remove the one-hour branches from active notification/refill scheduling functions after the data fix.

For an old zero-frequency schedule opened in the new app, show a clear “Choose a new interval” state and keep Save disabled until a positive option is selected.

### 4.5 Backfill existing custom schedules without guessing

For every existing refill schedule:

1. re-resolve its `offer_id` and range value against the current catalogue;
2. resolve the target line’s canonical tier and current published fee rule;
3. backfill base, fee, total, tier, and rule version;
4. rebuild only pending executions that have not been claimed or settled.

If the offer cannot be resolved, pause the schedule and flag it for reselection. Do not infer base cost by subtracting a guessed fee from the old `amount`, because the reported bug proves that the old amount may use the wrong tier.

## 5. Client file-by-file work

### `lib/core/providers/app_config_provider.dart`

- Keep `refillFeeRulesProvider` as the configuration loader.
- Add validation for malformed/negative/hierarchy-breaking client data and use the tier-specific fallback map.
- Mark the scalar Premium providers as unsuitable for target-line quotes.
- Do not duplicate configured percentages elsewhere.

### `lib/features/sim_lines/domain/line_refill_quote.dart` (new)

- Add the typed quote and pure tier-rule selection/calculation helper.
- Reuse `RefillPricing.quote` for arithmetic and rounding.
- Include tests for all three tiers and minimum-floor versus percentage cases.

### `lib/features/sim_lines/presentation/providers/line_refill_quote_provider.dart` (new)

- Compose line, offer catalogue, forecast recommendation, and fee rule.
- Expose both selected-offer and suggested-offer quote providers.
- Represent loading/error/unavailable explicitly; never emit a Premium fallback for a known Free/Standard line.

### `lib/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart`

- Accept the target `SimLine` or canonical entitlement snapshot.
- Delete `_lineIsPremium`, `_appFeePercent`, `_minAppFeeUsd`, and other global/Premium pricing reads.
- Replace price calculations with the shared quote.
- Derive the final total at render and save time; do not persist a stale `_amount` state copy.
- Show tier-aware base/fee/total text for fixed and range offers.
- Use the new interval-option builder, include `Carrier rule · 76 days`, and remove `1 Hour`.
- Use centralized schedule math and exact carrier-derived cadence.
- Save refill schedules through the authoritative server operation.

### `lib/features/sim_lines/presentation/widgets/depletion_forecast_card.dart`

- Replace direct rendering of `suggestedAmountUsd` with the shared suggested quote.
- Display the customer total and applied tier fee, or an explicitly labelled estimate/unavailable state.
- Pass the same target line and recommendation to the sheet opened by “Use it.”

### `lib/features/sim_lines/presentation/widgets/manual_refill_bottom_sheet.dart`

- Refactor to the shared quote/rule resolver without changing its correct behavior.
- Keep the server-authoritative instant-refill flow.
- Make the tier label reflect loaded rule values rather than hardcoded percentages.

### `lib/features/sim_lines/data/models/usage_forecast_model.dart`

- Remove subscription-tier translation from carrier cadence.
- Expose the server value as an exact suggested interval and distinguish carrier-derived versus generic preset behavior in the option builder.

### `lib/features/scheduled_topups/domain/refill_schedule_math.dart`

- Remove frequency-zero/one-hour production semantics.
- Provide one function used by display and save.
- Ensure an already safety-adjusted carrier interval is not adjusted twice.

### Generated/localized files

- Add localized strings for `Carrier rule`, `Current`, the tier-fee breakdown, unavailable quote, and invalid legacy interval.
- Regenerate Riverpod/Freezed/localization output with the project’s normal generators; do not hand-edit generated files.

## 6. Test plan

### 6.1 Pure Dart tests

Add tests that pin:

- USD 0.20 base -> Free USD 0.50 fee / USD 0.70 total;
- USD 0.20 base -> Standard USD 0.30 fee / USD 0.50 total;
- USD 0.20 base -> Premium USD 0.10 fee / USD 0.30 total;
- percentage wins when it exceeds the minimum;
- missing configuration falls back for the actual tier, not Premium;
- a Free line stays Free even when the account owns a Premium line;
- a carrier rule with a 90-day inactivity window produces 76 days;
- the interval options contain 76, never contain 0, deduplicate collisions, and expose an existing unusual positive interval;
- carrier-derived 76 is passed through unchanged by next-execution math.

Update `usage_forecast_test.dart` to remove the obsolete Premium 90 -> 85 expectation.

### 6.2 Widget tests

Build `ScheduledTopupSheet` with provider overrides for one offer at USD 0.20 and each line tier. Assert the visible total and fee breakdown for all three tiers. Cover both construction paths:

1. direct Custom Auto-Refill;
2. forecast card -> “Use it.”

Also assert:

- `Carrier rule · 76 days` is visible and selectable;
- it is initially selected for the reported carrier recommendation;
- `1 Hour` is absent;
- Save sends 76 and the offer identity, not a client-authored tier/fee;
- an unresolved quote disables Save;
- an old zero-frequency edit requires a new interval;
- changing fee-provider state cannot leave a stale selected total.

Add a forecast-card test that verifies it never prints raw USD 0.25 as though it were a fee-inclusive total.

### 6.3 SQL/database tests

Extend `supabase/tests/line_tiers_and_app_fee_rules_tests.sql` or add a focused schedule-pricing test file. Test:

- Free/Standard/Premium schedule quotes use the target line’s canonical tier;
- the minimum floor and percentage arithmetic;
- an account Premium benefit cannot discount a Free target line;
- a forged client total/tier is overwritten or rejected;
- fixed and range offer base costs are validated;
- queued execution separates base, fee, and total;
- `frequency_days = 0` is rejected;
- 76 is accepted and queued exactly 76 days later;
- editing a schedule cancels/rebuilds only its eligible pending execution;
- changing a line tier before the next recurrence causes server repricing;
- unauthorized users cannot quote/save another user’s schedule;
- unresolvable legacy schedules are paused instead of guessed.

### 6.4 Worker tests

Only if the queue/worker contract changes, update the authoritative worker repository identified by `.agents/AGENTS.md`, not this repository’s historical `servers/` copy. Pin:

- provider validation receives base cost;
- debit and refund receive retail total;
- tier fee is not applied twice;
- a failed purchase refunds exactly what was debited;
- a re-quote/provider-price mismatch fails safely.

Run worker syntax/tests locally, then follow the separate approved deployment process. Do not deploy merely because this plan exists.

## 7. Verification commands and evidence

The executor should run, in order:

1. formatting on changed Dart files;
2. code generation if providers/models/localizations changed;
3. focused Dart unit and widget tests;
4. the focused SQL test file against a disposable/local database;
5. full `flutter analyze`;
6. full `flutter test`;
7. worker tests and syntax checks if an authoritative worker was changed.

Record exact pass/fail output and distinguish pre-existing failures from new failures. Do not claim live correctness from local tests alone.

## 8. Manual acceptance matrix

Use one fixed offer with USD 0.20 base cost and three otherwise equivalent lines:

| Entry point | Basic/Free | Standard | Premium |
|---|---:|---:|---:|
| Manual Refill | $0.70 | $0.50 | $0.30 |
| Forecast card suggested total | $0.70 | $0.50 | $0.30 |
| Forecast -> Use it sheet | $0.70 | $0.50 | $0.30 |
| Custom Auto-Refill sheet | $0.70 | $0.50 | $0.30 |
| Edit saved schedule | $0.70 | $0.50 | $0.30 |

For each result, verify the breakdown shows USD 0.20 base plus the correct tier fee, the saved schedule returns the same authoritative total, and the queued execution records USD 0.20 base rather than the retail total.

For the reported Vodafone Egypt line:

- the interval list includes `Carrier rule · 76 days`;
- “1 Hour” is absent;
- “Use it” preselects the carrier-rule option;
- the estimated next execution is exactly 76 days from the scheduling anchor;
- the saved `frequency_days` is 76;
- the next successful recurrence advances by 76 days.

## 9. Rollout and rollback

1. Snapshot deployed function/trigger definitions and count affected active schedules before migration.
2. Deploy schema/function changes before the client that depends on them.
3. Backfill and verify schedule pricing components; keep unresolved schedules paused.
4. Release the client and monitor quote/save failures, tier distribution, fee/base mismatches, zero-frequency rejections, and worker provider-price mismatch errors.
5. Verify representative Free, Standard, and Premium lines in production using read-only inspection before allowing real charges.

Rollback must be forward-only: pause newly created refill schedules if needed, deploy a corrective migration/function version, and roll back the client feature flag/release. Never restore hourly schedules or collapse retail total back into base cost.

## 10. Definition of done

The work is complete only when:

1. all refill entry points show one consistent tier-aware quote;
2. Basic/Free never receives Premium’s USD 0.10 minimum, and Standard/Premium each receive their own published rule;
3. the server independently calculates and records the same total;
4. base cost, app fee, and customer total remain separate through schedule, execution, debit, provider validation, and refund;
5. `Carrier rule · 76 days` is visible, selected when recommended, stored as 76, and executed as 76;
6. no production UI or save path accepts the one-hour test cadence;
7. existing zero/ambiguous schedules are safely paused or backfilled without guessed prices;
8. focused and full test suites pass, with evidence recorded;
9. no unrelated user changes in the dirty worktree are overwritten;
10. any worker edit is made and deployed only from the authoritative backend location under `.agents/AGENTS.md`.
