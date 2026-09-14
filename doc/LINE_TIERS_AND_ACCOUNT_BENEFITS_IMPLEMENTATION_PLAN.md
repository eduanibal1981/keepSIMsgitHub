# KeepSIMs: per-line tiers and shared calling/eSIM benefits

Prepared: 2026-09-10. Audience: the owner and the future AI executor.

**Status: READY FOR AI IMPLEMENTATION — revision 1.2. All architectural decisions confirmed, downgrade refund policy specified, and test data reset confirmed.**

This is the complete implementation handoff requested by the owner. The owner confirmed Q7-Q12 in the follow-up to the draft and added the mandatory database fee-table design. Revision 1.1 added C12-C15. Revision 1.2 records the finalized execution decisions:
1. **Downgrade Policy**: Premium-to-Standard downgrade allows a refund of the USD 2.50 difference back to the user's KeepSIMs wallet (full USD 2.50 refund if requested within 14 days of activation; prorated refund of the remaining unused portion of the USD 2.50 difference if downgraded later in the annual cycle).
2. **Notification Accounting**: Per-line annual USD allowance pool ($0.50 Standard / $1.00 Premium in `system_configs`) absorbing real destination carrier SMS/WhatsApp costs while displaying simple message estimates in the client UI.
3. **Draft Seed Rates**: Initialize `intelcallfee` at 15% Free / 10% Standard / 5% Premium with USD 0 minima in 'draft' status; initialize `esimofferfee` at 10% Free / 7% Standard / 5% Premium in 'draft' status.
4. **Permanent Free Cutover**: Set `plan_expires_at = NULL` on Free lines and drop the `KS403` 6-month blocking trigger. All existing test lines are wiped by the owner.
5. **Phased Execution**: Proceed via Foundation-First (Package P1 & P2: database migrations, `app_fee_rules` table, canonical entitlement RPCs, and SQL unit tests first).

No application, database, worker, financial, or deployment changes are authorized by the act of writing this plan. The future executor must follow the authorization of its own execution session. This review inspects local files; it does not establish what is deployed or prove current test results.

## 1. Outcome and confirmed scope

Keep subscriptions attached to individual SIM lines. The account receives a separate benefit for international calling and standalone eSIM shopping, derived from its highest eligible active line subscription.

| ID | Confirmed requirement |
|---|---|
| C01 | Three tiers: Free, Standard, Premium. |
| C02 | Subscription prices: USD 0, USD 2.50, USD 5 respectively, **per line**, not per account. Annual billing follows the original pricing table and the subsequent discussion. |
| C03 | Refills use the purchased-for line's own tier. A Premium line cannot discount refills for a Free or Standard line. |
| C04 | Automation eligibility belongs exclusively to the line and must not inherit an account benefit. |
| C05 | Notifications, channel access, reminder schedules and any allowance belong exclusively to the line. |
| C06 | International calling and standalone eSIM purchase benefits use the account's highest eligible active line tier. |
| C07 | Fee hierarchy is regular for Free, reduced for Standard, lowest for Premium. Previously illustrated fee amounts and discount percentages are **not approved launch prices**. |
| C08 | Travel Back is a purchase entry point: an existing-line package/refill follows C03; a standalone eSIM follows C06. Entry through Travel Back does not change the underlying product's entitlement scope. |
| C09 | This task produces a profound modification plan for a future AI executor, rather than implementing the application now. |
| C10 | One database fee table is the only authority for KeepSIMs product fees. The owner edits its tier percentages and minimums through `keep_sims_admin`; no hard-coded or alternative fee source may compete with it. |
| C11 | Initial refill fees: Free 7% with USD 0.50 minimum; Standard 5% with USD 0.30 minimum; Premium 3% with USD 0.10 minimum. The minimum is a floor on the calculated fee, not an additional charge. |
| C12 | `intelcallfee` is percentage-only: Free, Standard and Premium minimums are all USD 0. Retain the shared minimum columns for other items. Supplier charges and billing increments are separate from a KeepSIMs fee floor. |
| C13 | Permanent Free retains unlimited saved lines/basic reminders. No implicit paid carrier polling; apply abuse/rate/spend controls independently, without a 10-line marketing cap or account-wide paid-line exemption. |
| C14 | Allowance UI must match the actual published unit. A fixed included message count is a guaranteed service commitment, not a conversion estimate from variable monetary credit. |
| C15 | Carrier-activity warnings depend on verified applicable tariff rules, not carrier name alone. KeepSIMs internet calls do not count as activity on the saved SIM merely because they display its number. |

Account benefit aggregation is permission to use calling/eSIM prices. It is not a new account subscription, does not change line subscriptions, and never proves that another line has been paid for.

Example: one Premium line, two Standard lines, three Free lines cost USD 10 per annual cycle when all paid terms start together. Calling and standalone eSIM purchases receive Premium rates. The Free lines retain Free refill and notification rules, and the Standard lines retain Standard rules. Separate line renewal dates remain separate.

### 1.1 Final commercial matrix

| Benefit | Free line | Standard line | Premium line |
|---|---|---|---|
| Annual membership per line | USD 0; no time limit | USD 2.50 | USD 5 |
| Saved SIM count | Unlimited across the account | Same | Same |
| Known-deadline reminders | 7 days and 1 day before deadline | Customizable schedules | Customizable schedules |
| Reminder channels | In-app and push | All supported channels; line allowance for SMS/WhatsApp | All supported channels; separately configured line allowance for SMS/WhatsApp |
| Refill app fee | max(7% of base, USD 0.50) | max(5% of base, USD 0.30) | max(3% of base, USD 0.10) |
| Automation | No | No | Separate opt-in, capability, reliable schedule and funding required |
| Network checks | Paid and explicitly requested | Configured included allowance; paid extras | Configured included allowance; paid extras |
| Offline refill requests | Existing paid-only eligibility excludes Free | Eligible, subject to existing controls | Eligible, subject to existing controls |
| Contribution to account calling/eSIM rate | Free | Standard | Premium |

Premium membership activates after its own settled payment even if automatic refill is unsupported or not enabled. Membership is not evidence that the SIM is active. A shared line contributes no account benefit. Home/travel pauses do not cancel a paid term.

## 2. Decision tree and interview register

### 2.1 Design tree

```text
Confirmed per-line commercial model
|-- A. Fee configuration (Q1)
|   `-- Actual product/destination rates, minimum margins, quote validity
|-- B. Notification funding (Q2)
|   `-- Channel matrix, exact allowance, reset/rollover, overage consent
|-- C. Mid-term upgrades (Q3)
|   `-- Rounding, effective timestamp, refund and downgrade treatment
|-- D. Renewal (Q4)
|   `-- Consent, insufficient funds, retry timing and reminder schedule
|-- E. Premium carrier eligibility (Q5)
|   `-- Initial-refill requirement, activation boundary and failed setup
|-- F. Free duration (Q6)
|   `-- Old free-grant migration, re-added numbers, expired Free lines
|-- G. Existing contracts (source audit prerequisite)
|   `-- Legacy prepaid obligations, migration cohort, grandfathering expiry
|-- H. Which lines contribute to an account benefit (source audit prerequisite)
|   `-- Owned/shared lines, deletion, transfer, suspension, replacement
`-- I. Purchase lifecycle and product catalog (source audit prerequisite)
    `-- Call-rate locking, eSIM orders/refunds, affiliate price control
```

Q1-Q12 are settled. The owner confirmed the remaining policies and specified the fee-table refinement. The interview frontier is closed for this scope. Technical details below implement those policies; the executor may resolve routine code organization and operational tuning independently without reopening confirmed product decisions.

### 2.2 Confirmed decision register

| ID | Decision | Approved policy | Owner answer |
|---|---|---|---|
| Q1 | Exact fees now versus configurable product fees | Server-configured fees per product, route and tier; validate supplier costs and approve actual rates before launch. | CONFIRMED: configurable fees; validate before launch. |
| Q2 | Funding SMS/WhatsApp reminders | All supported channels accessible on paid lines; disclosed per-line allowance; additional paid usage requires consent. Essential receipts and failure notices remain accessible on all tiers. | CONFIRMED: per-line allowance, paid extras. |
| Q3 | Standard to Premium mid-term charge | Prorate the USD 2.50 annual difference over the remaining paid term; retain renewal date; activate only after successful settlement. | CONFIRMED: prorated difference, same renewal date. |
| Q4 | Renewal behavior | Optional wallet auto-renewal with explicit consent; otherwise manual renewal; insufficient funds must not overdraw or charge an external card. | CONFIRMED: optional wallet auto-renewal. |
| Q5 | Premium when automatic refill is unsupported | Allow purchase with a clear automation limitation; retain other Premium benefits and account calling/eSIM rates. | CONFIRMED: allow Premium and disclose automation limitation. |
| Q6 | Free duration | Unlimited saved SIMs and no expiry for Free basic reminders; explicitly replace the older six-month, once-per-number grant. | CONFIRMED: Free has no time limit. |

Round 1 answers were recorded on 2026-09-10. Q1-Q6 supersede conflicting historical commercial rules.

| ID | Round 2 policy | Owner answer |
|---|---|---|
| Q7 | Free reminders 7/1 days before known deadline; paid custom schedules; configured per-line annual SMS/WhatsApp allowance; no rollover/pooling; consent before extras; permitted low-cost channels continue when exhausted. | CONFIRMED in owner follow-up. |
| Q8 | Premium membership activates after its own payment; refill/automation activation is separate; automation Premium-only with explicit opt-in, capability, reliable schedule and funded purchase. | CONFIRMED in owner follow-up. |
| Q9 | Owned lines only contribute; shared lines excluded; operational pause retains paid term; deletion removes contribution after warning; calls/eSIM use purchasing account tier/wallet; controlled audited replacement. | CONFIRMED in owner follow-up. |
| Q10 | Preserve validated paid terms/prepaid obligations; existing Premium gets new account benefits; new prices apply to new terms/upgrades; reconcile ambiguity. | CONFIRMED in owner follow-up. |
| Q11 | Retain configured included network-check allowance for paid lines; extras priced by line tier; Free paid checks only with intent; offline refill requests remain eligible-paid-line features. | CONFIRMED in owner follow-up. |
| Q12 | Accepted call tariff and authorized eSIM price remain locked; future purchases use current tier; stale/increased quotes require consent; external affiliate prices are not discounted by KeepSIMs. | CONFIRMED: adopt this price-commitment policy. |

Q12 was confirmed on 2026-09-10; the owner subsequently confirmed the full Q7-Q12 policy text. Fee-table clarification is recorded as C10-C11 and section 6.

The subsequent executor-review discussion is also accepted: C12-C15 and sections 6.1, 8 and 12 implement those refinements. The quoted executor recommendations are review input, not a competing specification: the proposed 10-line polling cutoff and blanket Vodafone UK/Three UK restrictions are explicitly not adopted.

### 2.3 Configuration delegated to the admin before launch

Implement the complete configuration/validation UI and server contracts without inventing non-refill fee amounts. Before enabling a service, the owner publishes its actual tier fees, validates supplier costs and any messaging/check allowance, and reviews representative customer prices. Earlier USD 0.25/0.50 allowance examples and 30%/60% discounts are not seed values. Missing configuration is an unavailable offer, not a free service or permission to use a legacy fallback.

Preserve existing refund/security policy unless expressly changed here. Deleting a line removes its contribution but does not itself grant a new cash refund; any refund uses the existing authorized process and reconciles entitlement and prepaid obligations. Support replacement transfers at most one existing term, atomically, within the authorized ownership policy; it never duplicates a term or silently moves another line's benefits.

### 2.4 Scope of finalization

This file is ready for implementation of the confirmed design. Publishing additional service prices is an intentional admin step before enabling those services, rather than a reason to leave local implementation unfinished. The present session changes the plan file only; deployment and real transactions remain governed by the future executing session.

## 3. Source authority, repositories and evidence limits

Read project instructions before implementation and recheck current working trees. Existing unrelated edits must be preserved.

| Surface | Authoritative location / instruction |
|---|---|
| Customer Flutter app; database migrations/functions/tests | `C:/Users/abdal/Work/KeepSIMs/keep_sims` |
| Provider workers and their tests | `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt` |
| Admin Flutter app and pricing/support controls | `C:/Users/abdal/Work/KeepSIMs/keep_sims_admin` |
| Worker deployment | Follow `keep_sims/.agents/AGENTS.md`: direct copy from authoritative backend, syntax checks and process verification; historical git-pull workflow is superseded. |
| Architecture and security | `.codex/AI_AGENT_GUIDE.md`, `.codex/BUSINESS_RULES.md`, `.codex/DATA_BACKEND_SECURITY.md`, `.codex/ARCHITECTURAL_DECISIONS.md`, `ARCHITECTURE_RULES.md` |

The customer repository's `servers/` directory is a historical copy, not the implementation target for workers. Local source is evidence of implementation text, not deployment state. Older documents contain historical operational counts, credentials metadata and test baselines; do not repeat them as current facts or copy sensitive values into the handoff.

### 3.1 Existing specifications to reconcile

1. `doc/SIM_SETUP_INCIDENT_REVIEW_AND_IMPLEMENTATION_PLAN_V2.md` is the latest inspected setup incident specification. Preserve its single-orchestrator requirement, server-authorized financial state transitions, truthful activation, idempotency and failure handling. Q6 explicitly replaces its six-month Free policy with permanent Free. Its Premium fee is replaced by C02 for the new model.
2. `doc/WALLET_PAYMENTS_IMPLEMENTATION_PLAN.md` defines wallet-only service purchases, available-balance holds, provider reconciliation and payment-source refund provenance. Preserve those rules unless the owner explicitly changes them. Do not reintroduce direct plan purchases through an external payment merely because a legacy code path exists.
3. `.codex/BUSINESS_RULES.md` still contains older one-Free-line and prepaid annual Premium wording. After approval and implementation, update it to reflect this specification and explicit legacy exceptions.
4. Earlier assistant tables and sample discounts are design suggestions, not technical authority or approved cost data.

## 4. Current-source findings and required corrections

These are local-source findings dated 2026-09-10. The executor must inspect the latest definitions and deployed counterparts before release.

| Finding | Evidence surface | Required direction |
|---|---|---|
| Client entitlement falls back to `protection_tier` and does not itself validate paid expiry. Existing tests deliberately preserve widening. | `lib/features/sim_lines/data/models/sim_line_model.dart`; `test/features/sim_lines/line_entitlement_test.dart` | Introduce canonical server entitlement; migrate legacy data deliberately rather than retaining unlimited fallback. Update tests to the approved contract. |
| Premium pricing and payment helpers contain historical annual/prepaid concepts alongside initial-fee-plus-refill logic. | `lib/features/sim_lines/domain/plan_payment.dart`; `refill_pricing.dart`; server `plan_price_net`, `quote_plan_price`, `pay_plan_fee_from_wallet` | Separate fixed annual membership from each refill's product price and funding model. Update quote, payment, receipt and worker paths together. |
| Standard fee recovery has specific protections against false successful RPC responses and repeated payment after interrupted setup. | `test/features/wallet/plan_fee_result_test.dart`; `pending_plan_fee_test.dart` | Preserve refusal parsing and idempotent recovery; strengthen binding to owner, line, tier, term and order. |
| Old UI still includes six-month Free and account-style plan limits. | `sim_line_form_screen.dart`; `line_upgrade_sheet.dart`; onboarding and upsell surfaces | Replace only according to recorded decisions; no hidden account cap or six-month reaper may survive a no-expiry Free decision. |
| Travel preparation opens eSIM shopping on capable devices or a package/refill flow otherwise. | `lib/features/sim_lines/presentation/screens/sim_line_detail_screen.dart`, `_buildTravelTomorrowRow` | Carry explicit product kind and target line where applicable; never use navigation context to infer discount scope. |
| The repository already has a setup incident specification warning about two parallel refill paths and account payments accepted as line payment. | `doc/SIM_SETUP_INCIDENT_REVIEW_AND_IMPLEMENTATION_PLAN_V2.md` | Resolve these dependencies before a new price model is enabled; a new badge or fee table is insufficient. |

### 4.1 Database impact map: latest local definitions found

Paths in this table are relative to `supabase/migrations/`. Inspect actual deployed definitions again before editing; the sequence below is local migration evidence only.

| File / functions | Observed behavior | Modification required |
|---|---|---|
| `20260908120000_sim_setup_orders_and_pay_per_refill.sql`: `plan_price_net`, `quote_premium_breakdown`, `create_sim_setup_order` | Premium quote is the common base fee plus first refill; Standard uses base fee. | Introduce separate configured 250/500-cent membership prices. Separate subscription quote from optional/required initial refill according to Q8. |
| `20260820000000_j8_premium_plan_pricing_and_wallet_purchase.sql`: `quote_plan_price`, `pay_plan_fee_from_wallet` | Legacy quote applies gateway gross-up. Wallet helper debits and stamps expiry but does not itself create `plan_payments` or set `plan_type`. | Converge on canonical line-term payment settlement; stop contradictory rails and retain safe legacy reconciliation. |
| `20260909010000_fix_standard_line_setup_and_sim_line_binding.sql`: `finalize_sim_setup_order`, `capture_sim_setup_holds` | Binds line, captures holds, writes payment/tier and schedules; Premium requires first-refill success. | Preserve one server finalizer and correct schema binding; split membership and automation activation only according to Q8. |
| `20260801010000_d5b_observability_and_plan_tier_hardening.sql`: `trg_fn_apply_plan_tier_from_payment` | Sets expiry to now plus one year; catches errors rather than aborting insertion; does not sync legacy tier. | Avoid resetting existing term on retry/early renewal; canonical transactional term settlement owns state. |
| `20260908180000_v2_canonical_sim_setup_and_free_grants.sql`: `has_paid_premium_entitlement` | Grandfather bypass precedes expiry; same-line recent plan payment is accepted without checking metadata Premium tier. | Require explicit applicable term/payment or bounded exception; remove payment-age heuristics as primary evidence. |
| Same migration: `check_free_grant_eligibility`, `record_free_grant_after_insert` | Enforces once-per-number six-month Free grants. | Q6 explicitly supersedes this enforcement. Preserve audit records but allow permanent Free, including valid re-add/fallback flows. |
| `20260908210000_refill_mini_queue_and_wallet_reminders.sql`: `trg_fn_sync_custom_refill_queue`, `update_sim_line_last_topup_at`, `process_due_notifications` | Recurring jobs can be created without fresh entitlement; next execution copies prior pricing. Notification generation is cadence-based. | Revalidate tier and obtain current approved quote/cap when scheduling execution; implement Q7 reminder windows without duplicate legacy fan-out. |
| `20260717060000_c3b2_cancel_and_claim_guard.sql`: `claim_due_executions` | Checks due/pending and active schedule but not paid tier/expiry; permits parentless scheduled work. | Guard automation claims by canonical target-line entitlement and valid execution kind/provenance. |
| `20260821020000_k3_repoint_supplier_readers_and_pricing.sql`: `queue_premium_refill_executions` | Legacy yearly prepaid queue remains alongside new recurring logic. | Version/fence old contracts, remove new-model callers and prevent two schedulers for one obligation. |
| `20260825030000_minimum_app_fee.sql`: `calculate_topup_fees` | Global app percentage/minimum; conditional gateway/base inputs; no target-line tier. | Apply versioned target-line policy once. Preserve supplier cost separately from retail and validate failover economics. |
| `20260815000000_i5_supplier_policy_and_failover.sql`: `request_instant_refill` | Separates household actor/payer and target line; authoritative offer resolution. | Preserve these boundaries; choose fee from target line, never actor/payer's other Premium line. |
| `20260811050000_h4_notification_channel_catalog.sql`: `trg_fn_dispatch_notification` | Falls back from line legacy tier to profile tier/default Standard; only literal basic is restricted; quota fields not fully enforced. | Eliminate privilege-widening fallback. Use canonical per-line policy and atomic allowance accounting. |
| `20260908230000_real_live_verification_system.sql` | Raw paid tier/legacy Premium can qualify; null expiry is treated as paid; has annual allowance and cost controls. | Use canonical line term; preserve validated allowance/hold rules according to Q11. |
| `20260825020000_m2_offline_voucher_tier_expansion.sql` | Raw Standard/Premium can permit offline use despite expiry. | Apply Q11 through canonical line eligibility and preserve request authentication/spend controls. |

### 4.2 Flutter and admin impact map

Customer paths below are relative to the customer repository.

| Files / surfaces | Required work |
|---|---|
| `lib/core/providers/app_config_provider.dart` | Replace common base-fee assumptions with versioned membership and product policy contracts; no actionable checkout fallback when authoritative price is unavailable. |
| `lib/features/sim_lines/domain/plan_payment.dart`, `refill_pricing.dart` | Converge quotes, wallet funding, setup, upgrade and pending-payment recovery. Retain old formulas only behind explicit legacy-contract handling. |
| `lib/features/sim_lines/presentation/controllers/sim_lines_controller.dart` | Remove activation/scheduling from generic add/edit; prevent local metadata updates from creating paid jobs or extending terms. |
| `lib/features/sim_lines/presentation/screens/sim_line_form_screen.dart`; `lib/features/profile/presentation/ui/onboarding_screen.dart` | Use canonical server setup; remove client-created expiry and superseded Free gating; unify resumed purchases. |
| `lib/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart`; `lib/features/profile/presentation/widgets/subscription_upsell_sheet.dart` | Replace account limits/prepaid claims and present approved line prices, proration and account bonus. |
| `lib/features/sim_lines/presentation/widgets/manual_refill_bottom_sheet.dart` | Render authoritative target-line quote, accepted price and funding/fulfillment state. |
| `lib/features/sim_lines/presentation/widgets/carrier_activity_notice.dart`; `lib/features/sim_lines/domain/carrier_rule_advice.dart` | Explain automation capability independently from Premium membership value. |
| `lib/features/sim_lines/data/models/sim_line_model.dart` | Stop legacy widening as paid authorization; consume canonical term/effective entitlement response. |
| `lib/features/calling/data/repositories/calling_repository.dart`; calling UI/models/controllers | Replace direct global tariff display with authenticated user-specific quote; selected caller SIM does not choose discount. |
| `lib/features/esim/data/repositories/esim_go_repository_impl.dart` | Replace global-view prices with user-specific authoritative prices; fix `requestPurchase` response parsing to match current SQL JSON envelope rather than casting to String. |
| `lib/features/esim/presentation/screens/esim_plans_screen.dart`, `esim_screen.dart`; `widgets/esim_checkout_sheet.dart` | Apply correct price before sorting/filtering/badges; typed order/quote state and accurate member discount explanation. |
| `lib/features/household/`; line list/repository | Visible shared lines cannot determine account benefit; retain authorized target-line management and independent funding rules. |
| `lib/l10n/*.arb`, generated localizations, `pricing & Features/keepsims-pricing.html` and related CSS | Replace obsolete plan promises; regenerate generated files via normal tooling. |

Admin repository targets include `lib/features/control/presentation/config_screen.dart`, `suppliers_screen.dart`, `lib/features/admin/data/models/system_config.dart`, `lib/features/verification_pricing/`, and `lib/features/sim_lines/data/models/sim_line_model.dart`. Inspect duplicated contracts independently; customer models do not automatically update admin models.

### 4.3 Calling: quote-to-settlement repair

`supabase/functions/make-call/index.ts` uses a global `get_call_rate_for_number` tariff and a hard-coded fallback if rate lookup fails. It starts a call after a minimum-balance check, without reserving the full authorized budget. Replace this with an authoritative tier-aware quote and bounded call funding. Unknown tariff is a typed unavailable state, not a fabricated chargeable rate.

`supabase/migrations/20260831000000_international_calling_and_cdr.sql` defines `call_rates`, `call_records` and `debit_wallet_for_call`. Current retail-rate snapshot is a useful foundation. Extend the snapshot to tariff version, applied tier, connection fee, billing increment, accepted budget and required internal cost evidence. The current debit idempotency check precedes its wallet lock and the balance can be clamped to zero while a larger expense is recorded; repair atomicity and reconcile actual debit with ledger.

`supabase/functions/telnyx-cdr/index.ts` reads the stored rate, but its inspected calculation does not apply the rate table's billing increment or connection fee. Define the approved retail billing rule and enforce it consistently in the quote, admission and settlement. Provider costs and retail pay-per-second terms must be distinct; do not silently switch customer billing quantum to a provider's quantum.

The source audit found authentication/credential fallback concerns on this existing money path. Recheck the current user edits before changing it. Missing verification configuration must fail closed; do not copy secret fallback values into code, logs, tests or this plan. This is a direct dependency of safe call charging, not authorization for an unrelated security rewrite.

### 4.4 eSIM: personalized catalog and fulfillment

Latest local purchase/view definitions were found in `20260830000000_esimaccess_integration.sql`: `request_esim_purchase` and `esim_offers`. Purchase markup comes from supplier override/global configuration, and order creation plus debit are atomic. Preserve atomicity while adding tier policy and approved wallet-reservation semantics; verify current deployment before replacing a working settlement contract.

`20260823000000_n1_compare_filter_ranges.sql` combines KeepSIMs-resold and external affiliate offers. Tier-aware retail prices must feed comparison, sorting, filter bounds, per-GB values and best-value labels consistently. A personalized price must not be stored in a shared public catalog cache keyed only by offer.

Current purchase identity can match a bundle name across provider rows. Use a stable provider-qualified offer/version in quotes and orders; never silently select the newest different provider between display and authorization. Revalidate availability and capability. Handle duplicate purchase intent separately from an intentional second purchase of the same bundle.

### 4.5 Authoritative worker changes

Under `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt`, inspect and modify as needed:

- `worker_auto_mini_refill.js`, `worker_auto_custom_refill.js`: claim/execute/refund/reconcile and next-job generation.
- `worker_instant_refill.js`: target-line quote and hold enforcement for manual/offline actions.
- `worker_esim_fulfillment.js`: accepted order snapshot, provider identity and funding/refund parity.
- `offer_validation.js`: supplier denomination and customer retail must remain distinct; existing fallback through `base_cost_usd`/`amount` requires explicit review.
- Provider adapters, recovery/reaper paths and tests, especially `test/wallet_reservation_fulfillment_test.js`, `test/fulfillment_test.js` and `offer_validation.test.js`.

The audited refill workers reserve a new hold if one is absent and do not recheck line expiry/funding kind immediately before dispatch. Combined with the migration default `funding_kind = wallet_due`, that can misclassify historical prepaid obligations. Do not ship tiered pricing until evidence-based funding classification and dispatch guards cover this path.

## 5. Target entitlement contract

### 5.1 Keep three concepts separate

1. **Purchased line subscription:** owner, stable line identity, tier, start/end timestamps, billing-model version, paid order/payment reference and lifecycle state.
2. **Effective line entitlement:** benefits available now after validating subscription dates, payment settlement and explicit exceptions.
3. **Account commerce benefit:** the highest eligible line entitlement contributing to calling/eSIM rates for that account. Derive it; never treat it as a paid account subscription.

Proposed conceptual operations, to be adapted to existing safe server abstractions:

```text
resolve_line_entitlement(actor, line, as_of)
resolve_account_commerce_benefit(benefit_owner, as_of)
quote_purchase(actor, product_kind, target_line?, offer_or_route, quantity)
```

Names above are proposed contracts, not claims that those functions exist. A database enum, table or service should be reused where its semantics are sound. Do not add a parallel entitlement system without an explicit migration and replacement map.

### 5.2 Required eligibility algorithm

```text
line_tier = tier backed by a settled, applicable, unexpired line term
            or a validated, bounded legacy grant
            otherwise permanent Free basic benefits

account_call_esim_tier = max(Free, eligible contributing line_tiers)
```

Use explicit rank Free=0, Standard=1, Premium=2; do not compare strings alphabetically. Define a paid term as a UTC half-open interval `[starts_at, ends_at)`; at the exact end timestamp it is expired. Use an annual calendar term with an explicit leap-day rule, not device-local date arithmetic. UI may estimate time left but cannot authorize benefits.

- A pending checkout, unbound payment, stale `profiles.subscription_tier`, stale `protection_tier`, future-dated term or payment authorization alone cannot unlock a paid tier.
- Legacy grants require explicit provenance, expiry and scope. A broad flag before an expiry check is not a valid permanent paid entitlement.
- A call/eSIM tier resolver must never be reused as a refill, notification, automation or live-check authorization function.
- Validate the actor's rights independently from the recipient's tier and from whose wallet funds the operation. A household payer's Premium line must not silently upgrade another owner's line.
- Cache only as a convenience. Recompute or validate on purchase authorization and expiry boundaries. Invalidate after activation, upgrade, expiry, refund/revocation, deletion and ownership changes.
- If the client cannot refresh, show last-known information as provisional and require an online server quote for spending. Do not silently charge a higher tier rate because a client cache is stale.

### 5.3 Product scope matrix

| Operation | Entitlement scope | Funding/other controls |
|---|---|---|
| Manual refill / existing-line package | Target line | Preserve owner/manager authorization and household wallet rules. |
| Automatic mini/custom refill | Target line | Premium-only; require explicit automation consent, valid supported offer, available funds and spending cap. |
| Line expiry/reminder notification | Target line | Preferences cannot widen tier; usage belongs to that line. |
| Line live network check | Target line | Decide included checks versus paid checks; preserve consent and route limits. |
| International call | Account commerce benefit | Server destination tariff; snapshot accepted rate and billing quantum. |
| Standalone eSIM purchase/top-up | Account commerce benefit | Verify offer availability, device support, quantity and authoritative price. |
| Travel Back existing-line package | Target line | Same quote path as any other refill/package. |
| Travel Back standalone eSIM | Account commerce benefit | Same quote path as any other standalone eSIM. |
| Subscription purchase/upgrade | Requested line term | Fixed configured membership prices, not product-tier discounts. |
| Wallet deposit/refund/gift | Existing funding policy | Do not apply a product-tier discount to transferred money or processor fees. |

## 6. Pricing and money contracts

### 6.1 Single source of truth: database fee table

Implement **`public.app_fee_rules`** as the only mutable authority for KeepSIMs product-fee percentages and minimums. The owner manages it through `keep_sims_admin`. An equivalent existing table may be migrated/renamed if inspection proves it can fulfill this exact contract; do not create competing configuration sources.

Use the owner's requested one-row-per-item admin layout. Keep all three tiers together so a publication changes their rules atomically. The persisted table is versioned: one item can have historical and draft versions, but exactly one published applicable version at an instant. A read-only current-rules view may simplify the UI; it is not a second writable source.

| Column | Type/contract |
|---|---|
| `id` | UUID, immutable version identity. |
| `appfees_item` | Stable allowlisted product key; see item catalog below. |
| `version` | Increasing integer per item; unique with `appfees_item`. |
| `free_percentage` | Exact numeric percentage points: `7` means 7%, not 0.07. Nonnegative, finite and required before publication. |
| `free_minimum` | Exact numeric USD fee floor; `0.50` means fifty cents. |
| `stand_percentage`, `stand_minimum` | Same units for Standard. Admin labels must spell out Standard. |
| `prem_percentage`, `prem_minimum` | Same units for Premium. Admin labels must spell out Premium. |
| `currency` | USD for this release; display conversion does not change accounting currency. |
| `fee_basis` | `base_amount_usd`: authoritative unmarked product/supplier base, before KeepSIMs fee and tax. Never a previous retail total, wallet deposit or client amount. |
| `charge_unit` | Registered product charging event, e.g. purchase, connected billable call, billable verification or billable message. Required before publication; not a free-form arbitrary billing multiplier. |
| `status` | draft / published / retired. Publication creates an immutable version; edits create a new draft. |
| `effective_from`, `effective_to` | UTC applicability interval; published intervals for an item cannot overlap. A disabled/unpriced item has no applicable published rule. |
| `created_at`, `created_by`, `published_at`, `published_by`, `change_reason` | Audit metadata populated/validated by trusted server code. |

Use PostgreSQL exact numeric types with adequate precision (for example numeric(12,6) percentage points and numeric(18,6) USD values), not floating-point money. Validate supported precision/range, nonnegative base and fees, a strictly positive valid quantity, and finite numeric values. Publication must enforce `free_percentage >= stand_percentage >= prem_percentage` and `free_minimum >= stand_minimum >= prem_minimum`. Equal rates/floors are permitted and must be presented truthfully.

For `appfees_item = 'intelcallfee'`, persist **`free_minimum = stand_minimum = prem_minimum = 0`** and enforce that invariant through database validation and the publication operation. The admin UI shows those three fields as zero/read-only with 'Percentage-only calling fee'. This product-policy constraint is not a competing fee source: the stored percentages and zero values still come from `app_fee_rules`. Other items retain editable minimums. A future nonzero calling minimum is a change to the product promise, not an ordinary accidental fee edit.

Membership prices remain fixed amounts per annual line term in a separate versioned **membership price** configuration: Free=0, Standard=250, Premium=500 USD cents. They are not percentage product fees. Notification allowances and wholesale catalogs are also distinct data, not alternative sources of the app fee.

#### Approved initial refill row

| appfees_item | free_percentage | free_minimum | stand_percentage | stand_minimum | prem_percentage | prem_minimum |
|---|---:|---:|---:|---:|---:|---:|
| `refills` | 7 | 0.50 | 5 | 0.30 | 3 | 0.10 |

Seed this as the initial owner-specified refill fee version. Publish/enable it only through the reviewed cutover and cost validation; do not change historical order charges. The owner can subsequently edit and publish the next version in the admin app.

#### Fee-item catalog and routing

Retain the owner's supplied keys, including `intelcallfee` and `linepakagefee`, as stable identifiers with readable admin labels. They are identifiers, not user-facing spelling. A typed server-side product registry maps a purchase to its fee item and entitlement scope. Callers may not submit an arbitrary cheaper fee key.

| `appfees_item` | Admin label | Tier source | Charge event / routing |
|---|---|---|---|
| `refills` | SIM refills | Target line | One authorized manual, automatic or offline airtime-refill purchase. Same policy across all three entry paths. |
| `intelcallfee` | International calls | Purchasing account's highest active owned line | One completed connected billable call, based on its accepted tariff and actual billable usage. Percentage fee only; all three app-fee minima are zero. |
| `esimofferfee` | eSIM offers | Purchasing account's highest active owned line | One KeepSIMs eSIM bundle purchase, including an eSIM data top-up. External affiliate checkout excluded. |
| `linepakagefee` | Existing-SIM packages | Target line | One provider product explicitly classified as a package for that existing line. A plain refill launched from Travel Back remains `refills`. |
| `liveverifysmsfee` | Live verification by SMS | Target line | One explicitly requested billable verification attempt, after the included-allowance policy is applied. Enable only if an actual supported SMS verification product exists. |
| `liveverifycallfee` | Live verification by call | Target line | One explicitly requested billable verification call; distinct from an ordinary international call. |
| `notificationsmsfee` | Extra SMS reminders | Target line | One billable logical reminder after the line's included allowance; consent required. |
| `notificationwhatsappfee` | Extra WhatsApp reminders | Target line | Same allowance/consent rule for a billable WhatsApp reminder. |
| `liveverifylookupfee` | Live network lookup | Target line | Additional registry entry only where a distinct chargeable lookup service is actually implemented. Do not create a new paid lookup just to populate this row. |

Create non-refill rows as unpriced drafts until the owner enters validated values and publishes them. For the calling draft, initialize the three explicitly approved minimums to zero while leaving the three unapproved percentages unset; zero minima alone do not make that draft publishable. **Do not copy the refill rates into all services, seed invented percentages, or represent missing values as zero.** Disabled or unsupported products remain unavailable through this path. An intentionally fee-free published rule uses explicit zero values and still obeys supplier cost and funding requirements.

No separate automation fee, Travel Back entry fee, offline-service markup or generic eSIM markup may stack on top of these rows by accident. Existing-SIM packages use `linepakagefee` instead of `refills`, not both. Verification channels use their own item, not `intelcallfee` plus a second verification fee. Notification transport cost is base cost, not permission for another hidden markup. Separate legitimate purchased items may each have a fee, but a retry/fallback for one purchased item is not a second purchase.

Do not introduce tier fees on deposits, refunds, gifts, taxes or subscription payments. Those remain governed by their existing explicit policies. Preserve external provider rates, foreign-exchange quotes and taxes as separately sourced inputs; only the KeepSIMs app-fee percentage and floor come from `app_fee_rules`.

#### Authoritative formula and examples

```text
B = authoritative base_amount_usd, excluding any existing KeepSIMs markup
p = selected tier's percentage points from the applicable published rule
m = selected tier's minimum fee in USD

app_fee_usd = round_usd(max(B * p / 100, m))
customer_total_usd = round_usd(B + app_fee_usd + applicable_tax_usd)
```

The minimum is a floor, not a surcharge: never calculate `B * p / 100 + m`. Use the existing audited USD rounding convention consistently in server quotes, authorization and receipts. Keep authoritative base and fee snapshots; the final decimal calculation occurs on the server, not independently in Flutter/Node.

| Refill base B | Free fee / total | Standard fee / total | Premium fee / total |
|---|---|---|---|
| USD 1.00 | 0.50 / 1.50 | 0.30 / 1.30 | 0.10 / 1.10 |
| USD 5.00 | 0.50 / 5.50 | 0.30 / 5.30 | 0.15 / 5.15 |
| USD 10.00 | 0.70 / 10.70 | 0.50 / 10.50 | 0.30 / 10.30 |
| USD 100.00 | 7.00 / 107.00 | 5.00 / 105.00 | 3.00 / 103.00 |

Examples exclude taxes. Refill base is the existing authoritative unmarked supplier/product base, not automatically the airtime face value; store supplier denomination/face value separately so an added fee never changes the amount delivered by the carrier.

#### Percentage-only calling and immutable usage pricing

For calling, the common formula specializes to `app_fee_usd = round_usd(B * p / 100)` because all three minimums are zero. Do not add a connection surcharge, minimum KeepSIMs fee or fixed app charge under another name. Keep the accepted tariff and percentage locked for the entire started call.

A call has unknown duration when started. Snapshot the accepted base tariff, billing quantum, supplier connection-cost treatment and fee-rule version, including percentage and zero minimum. Display the **final customer rate including the KeepSIMs percentage**, with its billing unit, before connection. An optional breakdown may show base and app fee; the primary rate must not omit the app fee.

Zero KeepSIMs minimum does not remove a supplier connection cost or minimum billing increment. Record these separately. Any customer-payable component must be included in the displayed quote/terms and authorized budget; if KeepSIMs absorbs it, retain it as an internal cost. Do not advertise 'no minimum charge' for the entire call unless the actual retail tariff supports that claim. Preserve the disclosed pay-per-second retail behavior and do not silently pass a different supplier billing quantum to customers. A route that cannot meet the supported retail model remains unavailable until its costs and disclosure are validated.

Compute final base from actual billable duration under the accepted tariff, then apply the accepted percentage once to that call. Derive maximum duration/budget using the same disclosed formula and actual wallet availability. A legitimate variable usage total is not repricing. Expiry or a new admin publication affects the next call, not this one. Retain sub-cent precision for usage/rate calculations and apply the defined final rounding; do not round every second or invent a one-cent app-fee floor. No duplicated fee on webhook replay, call-status updates or settlement retries.

#### Central quote and publication contracts

Implement/reuse a trusted pricing function such as `resolve_app_fee(product_kind, target_line, beneficiary, base, at)` internally. Public quote endpoints load base, target, beneficiary, scope and tier themselves; callers do not choose those trusted inputs. A pure internal calculation helper may take them after authorization. All refill, call, eSIM, package, verification and messaging paths must use this authority.

Snapshots persist `app_fee_rule_id`, version, fee key, applied tier, fee basis/amount, minimum, percentage, accepted base/currency, tax, total and applicable quantity/charging unit. Historical snapshots and immutable rule versions support settlement/refunds; they are not alternative editable pricing configuration.

Publish via an admin-authorized atomic operation with expected-version checks to prevent lost updates and conflicting effective intervals. Reject unauthorized writes, overlapping publication, invalid numbers and inverted tiers. Audit before/after values, actor, time and reason. Customer clients receive only authorized price/benefit data; they cannot update rules or expose internal supplier cost through a pricing RPC.

Require validation that the same offer/route produces `Free total >= Standard total >= Premium total` after rounding. Reject publication/enablement that fails the approved minimum contribution-margin check for supported routes; show the problematic cases in admin. Do not silently raise the fee beyond the published percentage/floor to repair margin. If an offer becomes unprofitable or lacks verified cost, make it unavailable pending a reviewed rate change.

#### Retire competing fee sources

Inventory every read of `APP_FEE_PERCENT`, `MIN_APP_FEE_USD`, `ESIM_MARKUP_PERCENT`, per-supplier eSIM markup overrides, `PREMIUM_MARGIN_PERCENT`, `PREMIUM_MARGIN_PER_REFILL_USD`, precomputed retail views, line `inapp_pricing` and hard-coded call retail defaults. Migrate any needed approved new-model fee into `app_fee_rules`; remove these sources from new purchase fee calculation. Supplier tables may keep wholesale rates, denomination, availability and FX inputs. Legacy-contract snapshots may retain their historical economics for previously authorized obligations.

Update `calculate_topup_fees`, membership/refill quote APIs, eSIM catalog/comparison/filter bounds, call quote/admission/CDR, verification quoting and messaging overage pricing together. Trigger plus RPC must not apply the fee twice. Cache quotes with rule/benefit identity and expiry; invalidate when terms or publication change. Do not make the admin browser, customer app, cached public catalog or worker environment variables another pricing authority.

### 6.2 Server quote

Quote response should contain at least: quote/order ID, product kind, target line if applicable, applied tier and reason, catalog/config version, quantity/denomination, customer price and currency, charge components, expiry and any spending cap. Keep internal supplier costs private unless there is a deliberate reason to expose them.

The server loads ownership, eligibility and catalog data itself. Client-supplied tier, amount, markup, owner ID or offer/provider mapping is never authoritative. Revalidate before creating the financial authorization. If the accepted quote has expired or a higher amount is required, obtain fresh purchase consent. Do not alter already authorized order totals after funds are reserved.

Persist the accepted price and entitlement snapshot on the order/call. Completion, refund, support view and retries use that snapshot, rather than today's price or the user's current tier. Historical charges remain immutable after a tier change.

### 6.3 Membership and refill separation

For the new commercial model, USD 5 is an annual Premium membership fee. It is not a promise of free refill credit, call minutes or eSIM data. No refill is required to activate membership. If the user also chooses a refill or automation setup, show the separately authorized items and total before confirmation. Later refills have their own approved purchase/funding record.

Represent legacy prepaid refills and new wallet-funded refills with explicit, verified funding provenance. Do not infer the funding model solely from `plan_type = premium` or give all historical executions a new-model default. A prepaid obligation must not be charged again. A new-model execution must not spend at the supplier without available reserved funds.

Wallet deposits fund purchases; external checkout success alone does not settle the plan. Preserve the configured minimum deposit and explain remaining credit. Avoid adding an external gateway charge to every spend of funds that were already deposited.

### 6.4 Idempotency and settlement

- Bind subscription payment to exactly one owner, line or durable setup, tier, term and purchase intent. An account-wide discount never makes an unbound account payment reusable for other line subscriptions.
- Debit/hold creation, term creation and ledger references must be transactionally consistent, with unique idempotency constraints. Bind retries to the original intent, not merely a sufficient payment amount.
- Supplier purchase retries adopt an existing provider transaction before attempting another. Unknown result remains pending/reconciling, not a safe refund or a fresh purchase.
- A refund equals the charged amount/allocation for that order, not the current catalog amount. Released holds do not create withdrawable promotional cash.
- For running calls, authorize/reserve funds against the accepted rate and duration limit; process duplicate or out-of-order call records idempotently and reconcile provider usage to the captured retail tariff.

## 7. Subscription lifecycle

Keep operational carrier status, subscription term and renewal intent separate. Subscription transitions must follow this table; `renewal_scheduled` and `cancel_at_period_end` may be flags/intents instead of mutually exclusive term states.

| Event | Membership state/result | Money and feature result |
|---|---|---|
| Save Free line | Permanent Free | No paid verification/refill caused by saving; basic reminders require a known deadline. |
| Start Standard/Premium purchase | Pending intent; previous valid tier remains | Server quote and durable order; no paid benefit from intent alone. |
| Membership settlement succeeds | Active paid term | One membership charge; line benefits and account contribution begin immediately. |
| Membership payment definitively fails | Intent failed; previous tier remains | No paid activation; release only uncommitted membership funds once. |
| Payment outcome unknown | Intent reconciling | Recover by original reference; no speculative second debit or activation. |
| Optional refill fails after membership settlement | Paid membership remains active | Release/refund that refill under existing policy; no automatic membership downgrade or false carrier-active claim. |
| Standard upgrade settles | Premium for remainder of same term | Prorated difference once; previous Standard portion is superseded, not a second simultaneous entitlement. |
| Cancel auto-renew | Current paid term remains | Changed next-term intent; no immediate loss of paid features. |
| Downgrade Premium to Standard | Revert to Standard immediately | Full USD 2.50 difference refunded to wallet if within 14-day window; otherwise prorated refund of remaining USD 2.50 difference credited to wallet. Account calling/eSIM tier recomputed immediately. |
| Approved wallet renewal settles | Next paid term, with preserved annual boundary | One new membership charge and term; duplicate job/callback adopts same result. |
| Term ends with no funded next term | Free | Future paid line features stop; account calls/eSIM tier recomputes immediately. |
| Operational home/travel pause | Paid term unchanged | Automation may pause; account contribution remains. |
| Delete contributing line | Contribution removed | Warn first; preserve financial records and reconcile jobs; no automatic refund implied. |
| Authorized refund/revocation | Affected term revoked | Recompute benefits; refunds and remaining prepaid obligations follow existing approved policy. |
| Audited support replacement | One term rebound atomically | No copied expiry/allowance, duplicated benefit or cloned prepaid allocation. |

### New activation

Create a durable intent without paid schedules or benefits. Obtain server quote and consent; reserve/debit through the canonical wallet flow. The canonical membership finalizer activates after its own verified settlement. Carrier refill and automation setup are separate linked operations, not prerequisites for the membership. A paid term alone must not trigger a supplier purchase.

Q8 explicitly supersedes V2's requirement for a successful first refill before any Premium benefit activates. Preserve V2's single-orchestrator, funding and evidence protections while splitting its all-or-nothing setup state. If a refill fails after membership activation, preserve that paid membership and its calling/eSIM benefit; refund/release only the failed refill by the applicable funding contract. A requested membership refund follows the existing authorized refund process, not an automatic failure fallback. The user can leave automation off, including on unsupported carriers.

### Upgrade

Q3 confirms prorated Standard-to-Premium upgrades with the same renewal date. Calculate against actual seconds in the existing term, using a server quote and defined currency rounding. With the approved prices: `round_usd(2.50 * remaining_term_seconds / total_term_seconds)`. Example: exactly half of an unchanged Standard term remaining produces USD 1.25 incremental membership cost. Use the same audited rounding as other USD charges; a rounded zero creates an auditable zero-amount upgrade settlement for the remaining term, not an invented minimum subscription fee or a fresh year. No two concurrent upgrade requests may charge twice or create overlapping terms.

### Renewal and downgrade

Q4 confirms optional wallet auto-renewal with explicit consent. Cancelling renewal preserves already paid benefits until term end. Renewal at USD 2.50/5 creates the next line term once, without resetting other line terms. If renewal is unfunded, stop only benefits that depend on the expired term and recompute account commerce rates. Do not conceal a Standard conversion or external charge in a fallback action.

Renewal intent is per line and records tier, price/version or authorized maximum, next due date and consent. Attempt the due wallet renewal once logically; transport/job retries use the same idempotency key. A definitive insufficient-funds result falls back to Free and requests a new user renewal action; do not turn later wallet funding into an unexpected delayed charge. An ambiguous result is reconciled before another attempt. A changed price above the consented amount requires fresh consent.

Manual early renewal extends from the current paid-through boundary and creates a future term; it must not reset the current term or bring a future upgraded tier into the account benefit early. Late manual renewal starts at actual settlement. Annual boundaries use calendar-year UTC arithmetic, with February 29 clamped to February 28 in a non-leap year. Refund policy is unchanged by early renewal; do not invent automatic prorated cash refunds for cancellation.

### Downgrade from Premium to Standard

When a customer explicitly requests a downgrade from Premium ($5.00) to Standard ($2.50):
1. **Grace Period (within 14 days of Premium activation)**: A full USD 2.50 difference is credited back to the user's KeepSIMs wallet.
2. **Post-14 Days**: The unused portion of the USD 2.50 difference is prorated over the remaining term (`round_usd(2.50 * remaining_seconds / total_term_seconds)`) and credited back to the user's wallet.
3. The line immediately converts to Standard (`plan_type = 'standard'`, `protection_tier = 'standard'`), automation (`refill_mini`) is paused/cancelled, and the account's commerce benefit for international calling and eSIM purchases is immediately recomputed.

### Expiry, deletion and refunds

At expiry, the next highest contributing line controls future calling/eSIM quotes. Already authorized orders retain their valid price/funding snapshot. Refill queue creation, execution claim, final pre-purchase dispatch and notification dispatch must recheck the appropriate line permission. Deletion/refund handling must reconcile queued/held/processing operations before removing state needed for recovery. A deleted line stops contributing after the confirmed deletion; cancelled renewal alone does not.

Operational pause/home mode alone does not remove a paid membership or its account contribution, as confirmed in Q9. Preserve existing account security restrictions on spending independently. Expiry processing jobs maintain schedules and materialized state, but transaction authorization must remain correct even when those jobs run late.

## 8. Notifications and automation

### Permanent Free and abuse controls

Permanent Free means unlimited saved SIMs and continuing basic date-based reminders. It does not include automatic paid carrier liveness queries. Saving, listing, opening, editing or refreshing a line must not initiate a paid lookup, verification SMS/call or refill. A reminder computed from stored qualifying activity and a verified rule is distinct from a fresh carrier health check.

Preserve and verify existing database-level `enforce_rate_limit` controls and their endpoint coverage. Apply configurable limits to creation bursts, repeated failed requests, verification frequency, expensive provider calls and wallet spending. Use account identity with proportionate device/network signals for abuse detection; IP limits alone cannot distinguish a shared network from one attacker. Apply appropriate safeguards to paid users too. One paid line does not exempt the account's other Free lines from controls or confer verification benefits on them.

Validate phone format/normalization and prevent duplicate registration within the applicable existing ownership rules; basic validation must not trigger a billable lookup. Paginate saved-line lists, process due reminders through bounded indexed queues, deduplicate jobs and reuse eligible cached carrier/product data. Add observable throttling with retry guidance and a review/recovery path for false positives. Do not quietly suppress promised reminders or reinterpret a security throttle as a permanent product line limit.

Do **not** implement the suggested '10 active background-checked lines unless Standard/Premium' rule. This plan does not introduce an account polling subscription. Any existing authorized verification path must retain its target-line entitlement, explicit request/consent, allowance and spending controls; no new background polling entitlement is inferred from saved lines or account commerce status. Limits are server-configured operational safeguards, not invented marketing quotas.

### Notifications

Define channel eligibility in a server policy keyed by line entitlement. Global preferences select channels within that policy; they cannot enable paid channels on a Free line. The sender must receive/resolve a trustworthy line ID. For an account summary covering mixed tiers, do not include Free-line paid-channel reminders by borrowing a Premium line's permission; separate messages or apply explicit per-line filtering and accounting.

Keep line reminders, account transaction notices, purchased-eSIM service alerts and call receipts as distinct event classes. The user's per-line notification requirement applies to line benefits; account/eSIM transactional alerts require their own basic policy and must not become an accidental unlimited premium messaging allowance.

Implement the confirmed per-line allowance with explicit versioned amounts/units in admin configuration. Use a per-line, per-term, per-channel ledger of granted/reserved/used credit; USD service credit can represent variable destination costs without promising a universal message count. A publishable allowance policy must identify its accounting unit and match the customer display. Do not combine one line's allowance with another's or roll unused credit into the next term.

Keep the existing monetary-credit model as the default until a published policy explicitly guarantees a fixed message count. Present that allowance with a simple remaining balance and reset date; detailed cost calculations belong in an optional breakdown. Do not relabel variable credit as '10 included alerts', even if an average-cost estimate suggests ten. The executor must not seed ten or another invented count.

If the owner publishes a validated message-count allowance, the entitlement ledger and UI must both use that count as a guaranteed service unit for the disclosed supported destinations/channels. Show included/used/remaining messages per line and annual reset date. Keep provider costs, SMS segmentation and currency calculations internal. A promised included logical SMS cannot unexpectedly consume several user-visible units because the provider segmented it, unless that different unit was clearly defined before purchase. Cost validation must cover the actual template lengths and destinations; a hidden cost budget cannot exhaust the promised count early.

Sending both SMS and WhatsApp is two channel deliveries, not one, and should consume two included message units under a combined-count policy. If allowances remain separate per channel, show each balance separately and do not advertise a pooled total. Provider retries/callback replays for the same logical delivery cannot consume extra included units. A cost variation must not silently switch the published accounting unit mid-term. Existing allowance amounts and terms remain governed by the version granted to that line.

Use 'Push and Telegram reminders included' only on plans where those channels are available. Free remains in-app/push with its two deadline windows; do not promise Free Telegram or unlimited reminder frequency. On every paid plan, exhausted SMS/WhatsApp allowance leaves permitted basic channels available. Additional paid delivery stays off until explicit per-line consent and spending limits; a friendly counter is not permission to debit the wallet.

Reserve allowance usage atomically against the quoted delivery cost, deduplicate the logical notification and provider attempt, and reconcile failed versus provider-billable attempts. A paid overage applies the relevant `app_fee_rules` row to the server-resolved transport base; do not add the fee a second time to an already retail-priced allowance debit. Covered delivery incurs no additional wallet charge. An attempt that cannot be fully covered by allowance may spend wallet funds only within the recorded user consent/cap; otherwise use the permitted fallback and show the exhausted allowance.

Reset allowance once at the next paid-term boundary. Upgrading retains consumed/reserved usage and the same reset date; grant only the prorated positive difference between Premium and Standard allowances for the remaining term, never a fresh annual allowance. A count-based policy rounds the incremental grant down to whole message units; a credit-based policy uses its published monetary precision. Display the actual increment before upgrade. Exact configured amounts must be validated before paid-channel launch. Essential transaction/security notices remain available through appropriate basic channels; they do not unlock expensive reminder delivery on Free lines.

Free reminders run at 7 days and 1 day before an evidence-based deadline. If a line is saved inside a window, issue at most the applicable current reminder, not a backlog of missed notices. Paid users can customize schedules within operational anti-abuse limits. Never manufacture a deadline when qualifying activity evidence is absent. Paid SMS/WhatsApp extras start disabled; user consent and spending limits are per line. Exhaustion leaves permitted in-app/push/email/Telegram reminders available without inventing paid-channel success.

### Automation

Enforce line-specific tier, paid term, capability, explicit scheduling consent, authoritative qualifying offer, budget and funding model at queue and dispatch. Keep commercial eligibility separate from carrier/provider capability. A successful top-up is not automatically evidence that it extends number validity.

Future queued jobs for expired/downgraded lines must not buy. Define safe handling of in-flight provider requests: reconcile them and apply their accepted funding contract; never issue duplicate refills, pretend to cancel an already accepted provider purchase, or release an uncertain hold.

Per-line refill caps must be checked against the current approved quote. Increasing a fee or losing a discount cannot bypass the cap. Global wallet balance, household approvals and spend limits remain additional restrictions, not sources of a higher line tier.

### Carrier evidence and limitation disclosure

Keep `CarrierActivityNotice` in onboarding, line details and relevant automation setup/upgrade flows. Its contents must be derived from the **applicable carrier tariff and product rule**, not a hard-coded list of operator names. An unsupported automation capability does not prevent purchasing Premium or receiving its verified membership/account benefits.

Extend/reuse the existing carrier-rule model to record country/operator, tariff or plan family, legacy/current applicability where known, qualifying activity types, inactivity interval, qualifying top-up/product restrictions, evidence URL, reviewed timestamp, review status and reviewer. Represent whether top-ups extend **number validity** as yes / no / unknown. Do not confuse balance/bundle validity with number retention. Include effective dates and review-due metadata so changed, conflicting or stale rules can be rechecked.

The server and UI consume the same applicable rule. Show:

- **Verified outgoing-activity requirement:** explain the required carrier-network activity and that top-up alone does not satisfy it; disable automated top-up as a claimed keep-alive method. Manual credit purchases can remain available with truthful disclosure.
- **Verified qualifying top-up:** enable automation only where the configured supplier product actually satisfies that rule and the usual funding/consent checks pass.
- **Unknown, stale or conflicting applicability:** say that KeepSIMs cannot yet confirm the required activity; do not assert either that top-up works or that outgoing calls/SMS are mandatory. Do not enable automatic top-up as a keep-alive method from uncertain evidence. Premium membership and explicitly requested manual purchases remain separate.

Only show 'your Premium calling/eSIM benefits are active' when the server's current account entitlement actually supports that statement. Do not use the warning banner to promise universal number protection or discounts on external affiliate offers.

**KeepSIMs internet calls are not activity on the saved SIM's carrier account merely because caller ID displays that number.** Never advance `last_qualifying_activity_at`, reset an inactivity deadline or mark carrier liveness verified from a KeepSIMs call record alone. Distinguish this VoIP product from the carrier's own native Wi-Fi Calling service, whose treatment must be established by that tariff's rules. A successful carrier refill likewise updates qualifying activity only with applicable rule/product evidence, not because any wallet payment succeeded.

Evidence checked during the 2026-09-10 planning review:

| Official source | Finding and implementation limit |
|---|---|
| [Three PAYG support](https://www.three.co.uk/support/pay-as-you-go.html) | Current public guidance includes buying a top-up among qualifying activities within 180 days. This contradicts a blanket assertion that all Three UK lines require outgoing usage. Verify the customer's tariff and purchased product. |
| [Vodafone PAYG bundle guidance](https://www.vodafone.co.uk/sim-only/pay-as-you-go-sim/renew-bundle) | The page includes topping up among qualifying activities within 180 days. Do not hard-code Vodafone UK as always 'top-up does not extend number validity'. |

These pages support correcting the review's blanket examples; they are not proof that every legacy tariff or wholesale supplier top-up qualifies. Reverify applicable official terms and product evidence during execution before changing operational carrier rules. Update copied admin/customer carrier models, rule editor metadata and tests together; do not automatically rewrite live carrier data as part of editing this plan.

## 9. Customer and admin experience

### Customer app

- Line cards/details: display that line's tier, USD/year price, term dates, renewal setting and supported automation status.
- Pricing screen: three line plans, unlimited saved SIMs and permanent Free basic reminders as confirmed in Q6, and explicit separation of annual membership from usage charges.
- Calling/eSIM: show the applied account benefit, such as 'Premium rates from one active Premium line', and final price before authorization. Calling uses the final percentage-inclusive rate, zero KeepSIMs fee minimum and truthful supplier-cost/billing-unit disclosure.
- Mixed-line refill checkout: show the target line and its applied tier; never display the account commerce badge as the refill discount.
- Travel Back: label package versus standalone eSIM clearly and reuse canonical checkout paths.
- Notification settings: show per-line controls, supported channels, allowance remaining and annual reset date. Use a simple count only for an actual guaranteed count policy; otherwise show credit honestly. Account preference controls must explain their limited scope.
- Renewal/upgrade: show amount due now, annual renewal amount, effective date and any separately selected refill; membership does not require that refill.
- Unsupported/expired state: preserve `CarrierActivityNotice` with tariff-specific evidence and the verified/unknown distinction; describe actual available behavior without implying number protection or carrier delivery guarantees.
- Update translations, accessibility labels, widgets, onboarding, upgrade/upsell sheets, wallet receipts and `pricing & Features/` assets. Search globally for obsolete '$2.50 Premium', 'up to 5 lines', 'prepaid refills', '6 months' and account-subscription language.

### Admin app

Provide configuration and audit views for membership prices, product/tier fees, margins, notification policy, subscription lifecycle and per-line/account entitlement explanation. Existing admin authorization must govern writes; hiding a control in the UI is insufficient.

Support must see why a line or account qualified, which term/payment contributed, price version charged, funding model and relevant order state. Exceptions/grants require a reason, actor, expiry and audit event. Do not implement a free-form profile-tier override as the primary entitlement source.

Add an **App fees** page to `keep_sims_admin`, reachable from the existing control/configuration area. Display one row per `appfees_item` with Free percentage/minimum, Standard percentage/minimum, Premium percentage/minimum, USD units, charging unit, status and current version. Keep product scope/fee basis read-only registry metadata so an admin cannot accidentally make refills use an account tier.

Editing opens a draft with a base-amount preview for all three tiers, including the USD 1/5/10/100 refill examples. Show calculated percentage fee, effective minimum, selected app fee and final total separately. Include tier ordering, unsupported product, cost/margin and missing-value errors. Blank is not zero; percentage input 7 is stored as 7 and displayed as 7%.

For international calling, show all three minimums as locked USD 0 and preview percentage-only fees. Supplier tariff/connection costs are displayed separately from app-fee controls. For notification allowances, show the published unit, covered destinations/channels and customer-facing balance preview; prohibit a count label on a credit-based policy. Carrier rule editing must include applicability/evidence/review metadata and the resulting warning/automation eligibility preview.

Saving a draft does not change customer prices. Publishing shows before/after rules, effective time and representative affected totals, then atomically publishes through server admin authorization. Show conflict errors when another admin published first, plus version history and change reason. Retiring a rule prevents new quotes after its effective end while accepted orders continue under their stored version. Reverting creates a new published version with previous values; it never edits historical snapshots.

## 10. Data migration and compatibility

1. Inventory current source/deployed schemas and functions, term fields, profile/line tier fields, unbound plan payments, legacy grants, pending setup/orders and worker funding models. Report aggregate discrepancies without exposing personal data.
2. Classify every existing paid line into validated paid term, validated legacy grant/prepaid contract, pending activation, expired, refunded, or unresolved. No blanket grant based on a UI badge, and no blanket revocation of legitimate paid service.
3. Define a documented compatibility map for old pricing/funding models. Preserve remaining obligations and immutable receipts. Backfill terms/links only from defensible evidence; unresolved rows require reconciliation before new-model automation.
4. Introduce versioned canonical entitlement/quote APIs and schema changes additively. Add required ownership/date/term indexes and unique financial references. Restrict new financial fields to trusted writers.
5. Backfill in resumable, idempotent batches. Compare new versus old decisions in shadow mode with reason codes. Investigate every unauthorized widening and every unexplained loss of a paid benefit.
6. Q6 removes the Free limit: explicitly disable/replace all free-grant checks, expiry schedules, once-per-number fallback charges and stale UI. Retain historical evidence where needed; do not create a new paid term to make an expired Free line usable.
7. Handle old app versions explicitly. Reject incompatible financial requests with a typed update-required response or translate them through a safe versioned server contract. Do not let an old client activate a tier through legacy writable columns/RPCs.
8. Cut over only after both new authorization and compatible settlement workers are available. Retire obsolete paths after in-flight orders drain. Do not rewrite prior migration history.

## 11. Execution work packages and dependencies

| Package | Work | Depends on | Exit evidence |
|---|---|---|---|
| P0 | Read this final specification and confirmed decision register | Completed owner interview/review | Q1-Q12, fee-table clarification and C12-C15 review refinements recorded; no repeated approval request for the agreed design. |
| P1 | Fresh repository/deployment inventory, financial dependency map and current test baseline | P0 | Verified impact map, protected user changes, unresolved legacy cohorts identified. |
| P2 | Canonical line/account entitlements; `app_fee_rules`, typed product registry, publication and shared quoting; restricted APIs | P1 | SQL scope/expiry/version/fee-formula tests; owner refill row; unpriced drafts for other items. |
| P3 | Fixed per-line membership quotes, payment binding, upgrades and renewal | P2 | Atomicity/idempotency/lifecycle tests and correct receipts. |
| P4 | Per-line refill pricing, funded automation, notification enforcement and abuse controls | P2, P3 | Mixed-tier isolation; no implicit Free polling/hidden saved-line cap; tariff evidence at dispatch; no unfunded or duplicate purchase. |
| P5 | Calling and standalone eSIM tier prices; immutable quotes and settlement | P2 | Correct account aggregation, accepted-rate preservation, refunds and concurrency tests. |
| P6 | Customer/admin fee UI, truthful allowance display, evidence-backed carrier notices; translations/pricing assets | Stable P3-P5 contracts | UI/contract tests, mixed-tier flows, zero calling minima, no alternate editable fee source or unsupported count/retention promise. |
| P7 | Legacy migration rehearsal, reconciliation, old-client compatibility | P3-P6 | No unexplained money or entitlement changes; documented recovery. |
| P8 | Staged release preparation and, when authorized, deployment | P7 | Version evidence, smoke tests, monitoring and recovery runbook. |

An executor may parallelize independent implementation only when its governing instructions allow it. Database authorization and money invariants are prerequisites for app enablement. A missing production credential must not prevent completing authorized local code, tests and deployment instructions; it must prevent claiming an unverified integration is live.

## 12. Acceptance tests

Use the following as behavioral tests of this approved contract, not snapshots that merely mirror the implementation.

### Entitlement isolation

- Three Free lines: Free calls/eSIM prices; only Free line permissions.
- One Standard plus two Free: Standard calls/eSIM prices; Free-line refills/notifications remain Free; no Standard/Free automation inherited.
- One Premium plus one Standard plus one Free: Premium calls/eSIM; each line retains its own fee and channel policy.
- Highest paid term expires exactly now: new account quote falls to the next valid tier without waiting for a cron job.
- No paid lines remain: new calls/eSIM quotes use Free rates; previous authorized orders retain their snapshots.
- Pending/failed/refunded/replayed payment, forged profile tier or stale legacy tier cannot unlock benefits.
- Ownership/sharing/deletion/pause cases follow the finalized policy; actor, beneficiary and payer are tested separately.
- A request for another user's line is rejected even if the actor has Premium.

### Money and subscription lifecycle

- New annual Standard/Premium membership charges exactly configured USD 2.50/5 before separately disclosed product purchases; two Premium lines mean two memberships.
- Duplicate payment callbacks, retries, process crashes and concurrent upgrade/renewal requests cause one charge and one applicable term.
- An unbound payment cannot satisfy multiple line activations; a recovered Standard payment cannot be adopted as Premium merely because an amount comparison passes.
- Q3 upgrade examples cover beginning, exact midpoint, near-expiry rounding, leap day and expiry boundary.
- Q4 cases cover no consent, cancellation, insufficient available balance, holds, retry and next-term activation.
- Legacy prepaid refill is not billed twice; new-model refill cannot spend without funding; unknown provider result remains reconcilable.
- Quote price changes, tier expiry and fee-config changes between browse, authorization and fulfillment do not create hidden extra charges.

### Fee table and admin acceptance

- Seed the approved `refills` rates: 7/5/3 percentage points and USD 0.50/0.30/0.10 minima. Initialize all three `intelcallfee` minima to zero but leave its percentages unset. Other item rows have no usable published price until the owner supplies one.
- Assert every fee/total in the section 6 refill example table using exact decimal arithmetic. Test just below/at/above each floor crossover and cent-rounding boundary. Prove the formula uses max, not addition.
- A Premium account refilling its Free line at base USD 5 pays the Free fee USD 0.50, not Premium USD 0.15. Its separate call/eSIM quote uses Premium only when that item's own published rule exists.
- An automatic refill and manual refill for the same Premium line, identical offer/base and fee version produce the same app fee. Neither route adds an extra automation margin.
- Existing-line package applies `linepakagefee` alone. Travel Back navigation does not add a fee or switch product classification. Reject crafted requests that submit a cheaper item key or forged base amount.
- Covered verification/notification allowance results in no extra wallet charge. An eligible paid excess uses the exact channel item once; deduplication and retries cannot multiply its minimum.
- Publishing an updated refill percentage/minimum changes future quotes and admin/customer previews without an app/worker release. Authorized existing orders and their refunds retain the accepted version and amount.
- Changing retired `APP_FEE_PERCENT`, `MIN_APP_FEE_USD`, supplier eSIM markup, environment defaults or local client estimates does not affect new-model quotes. Tests prove the database table is the only authority, not merely the newest of two competing sources.
- Missing, disabled, malformed or expired rule fails closed with a typed unavailable-price error. Explicit published zero fee remains distinct from missing data.
- Concurrent admin publication cannot create overlapping active versions or silently lose one editor's changes. Ordinary authenticated users cannot publish, mutate or retire fees.
- Numeric validation rejects negative/nonfinite fees, incorrect percentage conventions and inverted tier hierarchies. Price previews use the server resolver and display percentage points/currency clearly.
- Calling has zero KeepSIMs minimum for every tier. Database/publication validation rejects a nonzero `intelcallfee` minimum; UI controls cannot bypass this. Short calls apply only the accepted percentage with final monetary rounding, never an invented fixed or one-cent app charge. Retries/CDR updates cannot add a fee twice.
- Calling quote, budget admission and settlement agree on the percentage-inclusive tariff. Supplier connection costs/increments remain separate and accurately disclosed or absorbed; a zero app minimum cannot produce an unsupported whole-call 'no minimum charge' claim.
- Personalized eSIM filtering/sorting and price bounds use the same tier and published rule as checkout. A price cached for one account cannot leak as another account's payable quote.
- Reverting an admin change produces a new version and audit event, without rewriting historical order snapshots. Every changed price has actor, reason and effective-time evidence.

### Calls, eSIMs and Travel Back

- Same route/offer produces correct tier price and minimum-margin behavior, with precise billing/rounding.
- Running call, duplicate/out-of-order usage event, missing callback and insufficient wallet funding settle under the accepted tariff, within authorized limits.
- eSIM fulfillment failure restores/releases exactly the authorized funds once; a completed product is not repriced following subscription expiry.
- New eSIM top-up is a new purchase with the current account benefit; past data purchases remain unchanged.
- Travel Back package uses selected line; Travel Back standalone eSIM uses account benefit, even when launched from a Free line detail screen.
- External/affiliate offers do not display unsupported member-price promises.

### Notifications and automation

- Premium account with Free target line cannot enable paid line channels, premium repeats or automation via crafted requests.
- Global/multi-line notifications cannot bypass per-line policy or pool budgets accidentally.
- Concurrent delivery attempts do not exceed an allowance or debit multiple times; provider-billable failures follow the chosen accounting rule.
- Tier changes between schedule creation, claim and dispatch are enforced. Existing in-flight provider purchases are reconciled without duplication.
- Operational home/travel pause, unsupported carrier and missing qualifying-date evidence remain independent constraints.

### Permanent Free, allowance wording and carrier evidence

- Saving/listing/opening/editing/refreshing Free lines invokes no paid verification or provider polling, including when the same account owns a Premium line. Explicit paid-check requests still require the target line's policy and funding.
- Creation bursts, verification spam and duplicate jobs are rate-limited through the existing server controls; appropriate limits also apply to paid accounts. Ordinary reminders remain correct for accounts with more than ten legitimate saved lines; no hidden ten-line eligibility cutoff exists.
- Repeated normalized numbers and crafted client requests cannot bypass safeguards or multiply provider calls. Paginated listing and bounded reminder batches work without loading/polling every line on each app refresh.
- A credit-based allowance shows remaining credit/reset date and never a guaranteed fixed count computed from an average price. A published count-based fixture shows the actual remaining units and honors the promised count across its disclosed destinations/approved templates.
- SMS segmentation/provider retries do not unexpectedly consume multiple units under a logical-message count promise. Sending both SMS and WhatsApp consumes two channel deliveries, with the actual policy's separate/combined balance shown clearly. No cross-line pooling, rollover or unauthorized overage is introduced.
- Free screens promise in-app/push reminders only. Paid Telegram wording matches channel entitlement; no 'unlimited free alerts' label implies unrestricted reminder frequency or Free Telegram.
- Carrier warning tests cover verified top-up eligibility, verified outgoing-activity requirement, unknown applicability, stale evidence, conflicting sources and a different legacy tariff on the same carrier. Operator name alone cannot select the warning or enable automation.
- Neither Vodafone UK nor Three UK is seeded as universally top-up-ineligible from the executor review. Eligibility requires applicable tariff/product evidence, with source and review metadata.
- `CarrierActivityNotice` stays visible where a real limitation/uncertainty applies; it shows active Premium account benefits only when the account resolver confirms them. Unsupported automation never blocks paid membership by itself.
- A KeepSIMs internet call with the saved SIM's caller ID cannot update that SIM's qualifying activity date, reset its retention deadline or mark carrier liveness verified. Native carrier Wi-Fi Calling is distinguished and requires its own applicable evidence.

### Security, compatibility and release

- Direct client writes to tier, term, financial amount or ownership are denied; privileged functions have deliberate grants, safe search paths and owner/role validation.
- Account-benefit responses disclose only the caller's permitted data; logs avoid raw numbers, ICCIDs, tokens and payment details.
- Old-client payloads cannot bypass new server pricing. Existing ledger reconciliation understands every new transaction type.
- Migration can resume after interruption and produces the same classifications without duplicate credit or entitlement.
- UI displays USD/year/line clearly and never suggests that one Premium line upgrades all saved lines.

## 13. Verification and rollout

Before implementation, record actual current analysis/test results; do not copy counts from old handoffs. Run focused Flutter, SQL and authoritative Node-worker suites for affected behavior, then appropriate broader checks. Add tests for financial authorization and tier isolation, rather than testing static text only.

Use isolated provider stubs/local fixtures for purchasing tests. Read-only deployed inspection may verify schema/config versions. A SQL transaction rollback does not undo external calls, notification delivery or a worker that observed committed state: do not run supplier-affecting fixtures against production under the assumption that rollback makes them safe. Obtain the executing session's scope for any real transaction or deployment.

Proposed release sequence:

1. Add safe schema/contracts/configuration with new pricing disabled; preserve old funded fulfillment.
2. Deploy compatible entitlement and settlement readers/workers; verify source/version and health.
3. Backfill and run shadow comparisons/reconciliation.
4. Update customer/admin apps and minimum-version policy.
5. Enable selected product surfaces and approved migration cohorts; monitor actual quotes, charges and denied bypasses.
6. Expand only after reconciliation remains clean; deprecate old write paths after pending orders are resolved.

Before enabling each paid product, verify a published applicable `app_fee_rules` row, product routing/charge unit, supplier base and tax inputs, cost validation, any required allowance configuration, and an end-to-end server quote/settlement test. This handoff supplies the refill fee row and the three zero calling minima; other percentages/minima remain admin configuration as specified. Disabled/unpriced non-refill rows are a supported pre-launch state; the executor must deliver their complete configuration and integration rather than fabricate prices or mark the whole implementation blocked. Verify rate-limit coverage and carrier evidence before enabling affected background operations, and review customer-facing allowance/rate/limitation copy against the published policy.

Monitor tier selected by product, conversion and renewal, margin after supplier/messaging cost, allowance use, quote/charge mismatches, unauthorized requests, duplicate financial references, pending provider transactions and unexplained legacy entitlement loss. Avoid storing personal data for these metrics unnecessarily.

Recovery: disable new purchase/renewal creation by surface, retain settlement/reconciliation for already authorized orders, restore compatible app presentation, and use forward fixes for data. Do not roll back accepted prices, erase paid terms, release uncertain holds or restart legacy unfunded automation. Define ownership of unresolved orders and a checkpoint before resuming purchases.

## 14. Executor completion report

The final executor must report:

- The approved decision/version implemented and any explicit deviations.
- Files changed in each repository and deployment surface.
- Migration/backfill evidence and remaining legacy exceptions.
- Test commands, outcomes and limitations from that execution, not inherited claims.
- Evidence of quote/charge parity, per-line isolation and account calling/eSIM aggregation.
- Deployment/version status separately from local implementation status.
- Outstanding owner actions only where genuinely required, with exact reason and scope.

Definition of done: approved business rules are enforced server-side across line features and both account products; pricing/billing and historical obligations reconcile; customer/admin presentation matches; migration and recovery are reviewable; required tests pass; and every claimed deployment is supported by evidence.
