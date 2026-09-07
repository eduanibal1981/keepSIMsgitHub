# KeepSIMs wallet payments and unused-funds refunds: implementation handoff

Prepared 2026-09-07. This is an executable implementation specification, not a statement that the changes have been implemented or deployed.

## 1. Objective and agreed release scope

Make the KeepSIMs wallet the payment source for all purchases fulfilled by KeepSIMs. Card and PayPal checkout fund the wallet; they do not independently purchase a plan, SIM recharge, or eSIM. When the wallet is insufficient, offer “Add funds and continue,” confirm the deposit on the server, and resume the original purchase without duplicate billing.

Use reservations for asynchronous fulfillment. Confirmed failure releases the reservation in full. Ambiguous provider outcomes remain processing until reconciled. Customers can request a refund of eligible unused paid funds to the original deposit payment source.

The first release includes customer UI, database accounting, payment integration, fulfillment workers, admin refund operations, reconciliation, migration, and tests. A UI-only change is incomplete.

Release boundaries:

- Minimum wallet deposit: USD 5, configurable on the server.
- Core accounting currency: USD; preserve existing display-currency conversion.
- Refund destinations: original payment sources only. A card-funded PayPal payment is refunded through its original PayPal capture; PayPal determines routing to the original funding instrument.
- No arbitrary bank payouts, withdrawals to different cards/accounts, or cash conversion of promotional/gift credits in this release.
- Bank refund support can be added for genuine bank-funded deposits after the provider and verified return-to-source process exist. A bank payout for card-funded money is a separate future product.
- Low-balance alerts are included. Automatic wallet charging is a future opt-in feature; existing auto-fund settings must not imply that an unsupported automatic charge will occur.
- Do not change the commercial meaning of Standard/Premium. Premium already includes prepaid automated refills: do not charge the wallet again for included refills or turn an included failed refill into new withdrawable wallet cash.
- Affiliate purchases completed and paid on another merchant's website are outside KeepSIMs checkout. Preserve their external flow and identify it accurately.

These new wallet-only rules supersede older project descriptions of direct PayPal fallback. Other existing carrier, entitlement, household, security, and pricing rules remain applicable.

## 2. Execution instructions and repositories

Before editing, read the applicable `.agents/AGENTS.md`, `.codex/AI_AGENT_GUIDE.md`, `.codex/BUSINESS_RULES.md`, `.codex/DATA_BACKEND_SECURITY.md`, and `.codex/CURRENT_STATUS_AND_ROADMAP.md`. Inspect current code and working-tree changes in every affected repository. Preserve unrelated user changes.

Authoritative locations:

| Repository | Required work |
|---|---|
| `C:/Users/abdal/Work/KeepSIMs/keep_sims` | Customer Flutter app, Supabase migrations/functions/tests, this specification |
| `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt` | Provider workers, reconciliation/recovery jobs, worker tests |
| `C:/Users/abdal/Work/KeepSIMs/keep_sims_admin` | Refund queue, transaction inspection, configuration and support operations |

Do not implement workers in the historical `keep_sims/servers` copy. Inspect counterpart models in both Flutter applications; they are separate copies and do not update together.

The task is to implement and verify the complete scoped change. Make routine implementation choices independently. Complete local code, migration scripts, tests and release instructions even if live credentials or provider eligibility are unavailable. Clearly report unverified integrations; do not substitute mock success. Production database application, deployment, and real-money tests require the authorization applicable to that executing session. Do not treat this planning document as proof of production deployment authorization.

## 3. Findings from source inspection

The following are confirmed in local source; verify deployed versions separately.

| Existing surface | Required modification |
|---|---|
| `lib/features/sim_lines/domain/plan_payment.dart` | Replace direct PayPal fallback with shared wallet funding/resume flow; preserve server quotes and pending-fee adoption. |
| `lib/features/profile/presentation/ui/onboarding_screen.dart` | Resume paid line setup after wallet funding without losing form state or charging twice. |
| `lib/features/sim_lines/presentation/screens/sim_line_form_screen.dart` | Same flow for additional paid lines. |
| `lib/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart` | Wallet-only upgrades with preserved entitlement semantics. |
| `lib/features/sim_lines/presentation/widgets/manual_refill_bottom_sheet.dart` | Quote, wallet funding, order reservation and tracked fulfillment. |
| `lib/features/esim/presentation/widgets/esim_checkout_sheet.dart` | Replace insufficient-balance dead end with funding/resume; remove direct wallet queries from UI while touching this flow. |
| `lib/features/wallet/{contract,repository,controller,model,ui}/` | Typed balances, funding, refund eligibility, refund requests/history, pending states. |
| `lib/features/payments/presentation/screens/paypal_checkout_screen.dart` | Deposit-only checkout for new flows; approval/return URL is not proof of wallet credit. |
| `lib/features/payments/repository/payments_repository.dart` | Stored-card creation currently generates mock tokens. Replace with a real provider-backed integration or hide unsupported card controls. |
| `supabase/functions/wallet_transact/index.ts` | `ensureWallet` currently seeds USD 45.20 and welcome/referral rows. Remove production sample funding and balance realignment; create a zero wallet atomically. Replace client-amount deduction with order-bound server pricing. |
| `supabase/functions/create-paypal-order/index.ts` | Existing plan/deposit kinds and `PAYPAL_MIN_DEPOSIT_USD` with USD 1 fallback. Reject new non-deposit kinds after cutover; enforce common USD 5 minimum and configured limits. |
| `supabase/functions/capture-paypal-order/index.ts`, `paypal-webhook/index.ts`, `paypal-return` | Converge on one idempotent deposit finalization operation and durable recovery. Preserve settlement of already-created legacy plan payments. |
| `supabase/functions/paypal-webhook/index.ts` | Current deposits credit gross amount and record gross/fee/net. Preserve full purchased wallet credit; treat processor fees as merchant expense by default. Extend verified refund/dispute handling. |
| `supabase/functions/execute_zendit_recharge/index.ts` | Legacy direct-purchase surface; inspect deployment and callers. Remaining nonterminal responses can currently reach `success: true`. Route through the canonical order/worker path or disable this bypass. |
| `supabase/migrations/` and `supabase/tests/` | Preserve existing debit/refund grant lockdown and add reservation, provenance, refund, reconciliation and compatibility coverage. |

Inspect the worker entry points `worker_instant_refill.js`, `worker_auto_mini_refill.js`, `worker_auto_custom_refill.js`, and `worker_esim_fulfillment.js` in the authoritative backend. Trace their adapters, claim/finalize/refund RPCs, reapers, manual admin completion and provider callbacks before changing settlement.

Also trace calling, offline vouchers, household spend and gifts. They consume wallet value and must respect holds and source allocation even when their UI does not open a checkout screen.

Local source and migration history may differ from deployment. Inventory actual functions, grants, triggers, cron jobs and running workers through read-only inspection before release. Do not infer live behavior from migration filenames.

## 4. Product and pricing contract

All service prices come from server-side catalogues/rules. Flutter may render an estimate but cannot authorize a debit based on a client-supplied price, balance, fee, provider or entitlement.

Define:

- `P`: final service amount in USD cents, including applicable service fees/taxes.
- `B`: available wallet amount eligible for that purchase, after holds and restrictions.
- `M`: configured minimum deposit, initially 500 cents.
- If `B >= P`, required deposit is zero.
- Otherwise `required_deposit = max(M, P - B)`.

| Price | Available | Required deposit | Available after success |
|---|---:|---:|---:|
| $3 | $0 | $5 | $2 |
| $12 | $0 | $12 | $0 |
| $12 | $4 | $8 | $0 |
| $12 | $10 | $5 | $3 |

Permit a larger custom deposit within configured limits. Reject below-minimum and above-maximum amounts server-side. If a purchase needs more than a permitted deposit/balance limit, explain the constraint; do not silently split charges to evade limits.

Default economics: paying $5 credits $5. Gateway fees are recorded separately and absorbed by KeepSIMs. Preserve service margin logic, but remove gateway-fee gross-up from new wallet service purchases; never charge gateway fees again each time deposited money is spent. Do not introduce customer deposit/refund fees without a separately approved policy. Record any legacy fees accurately rather than retroactively rewriting receipts.

Example checkout copy: “Add $5.00 to your wallet. $3.00 will pay for this recharge and $2.00 will remain available.” Show the actual refill and purchase as separate receipt entries.

Recheck the quote, balance, funding owner, limits and entitlement before reserving. If price increases or the product changes after external checkout, request fresh purchase consent; keep the confirmed deposit available. If price falls, charge only the lower amount. If the purchase was cancelled or expired, a late deposit still credits the wallet but does not trigger an unwanted purchase.

For household-funded purchases, the server resolves the actual payer. A manager cannot deposit into or refund the owner's wallet merely by supplying its ID. Preserve existing allowance/fallback rules, display the payer, and ask the owner to fund their wallet when required.

## 5. Accounting design and invariants

Extend the existing ledger rather than adding an independent competing balance system. Choose exact names after inspecting current schema; the entities below describe required responsibilities. Add forward-only migrations, constraints and indexes together.

Use integer minor units in API/domain money calculations. SQL may retain exact `numeric` with a two-decimal constraint or migrate to integer cents; document the conversion and compatibility strategy. Do not use floating-point arithmetic as the authority for charging or refund allocation.

Required entities:

| Entity | Required information |
|---|---|
| Wallet summary | Currency, posted balance, active held amount, available amount, restricted amount, eligible refundable amount, version/time |
| Funding source lots | Wallet/owner, origin type, original deposit/ledger reference, provider and merchant environment, order/capture ID, currency, funded amount, remaining amount, refund deadline/capability, dispute/restriction status |
| Purchase intent/order | Owner and payer, service/line/offer identity, immutable quote snapshot and expiry, funding mode, idempotency key, reservation and entitlement references, fulfillment status |
| Holds/reservations | Wallet/source allocations, order or refund owner, amount, active/captured/released state, reason and timestamps |
| Source allocations | Exact paid/promotional/gift lots held, spent, restored, gifted or externally refunded by each operation |
| Refund request and items | Requester/payer, amount, allocation snapshot, one or more original captures, per-item amount/status/provider refund ID/idempotency key, review reason and audit times |
| Provider event inbox | Unique provider/environment/event identity, validation and processing status, retry metadata; protected payload retention |
| Durable job/outbox | Committed work awaiting external capture/refund/fulfillment, claim lease, attempt count and next reconciliation time |

Expose safe read models to the customer. Keep capture identifiers, operational payloads and provider secrets out of unnecessary client responses.

Balance semantics: reservation moves value out of available funds without a posted debit. Success posts the debit and consumes that same reservation atomically. Release changes availability without adding new posted credit. Use explicit statuses/types so history and analytics do not count reservations as purchases. Existing genuinely posted debits still require a linked compensating credit on confirmed failure, once.

Invariants to implement and test:

1. Available funds never become negative through ordinary spending, gifting or refunds. Every spender checks the same available funds under a database lock.
2. Every posted value change has an immutable ledger entry and source allocation in the same transaction. Summary totals are derived or transactionally maintained; never repair balances from an incomplete type list.
3. One logical operation has one durable idempotency key. Reuse with different parameters is rejected. Keys are scoped to the authenticated owner/action; knowing another user's key grants no access.
4. A reservation is captured or released at most once. Opposing terminal callbacks cannot both change value.
5. External refunds cannot exceed either the eligible unspent paid balance or the remaining refundable original payment amount after previous/pending refunds, reversals and disputes.
6. Failed purchases restore the exact original funding categories and payer. Promotional spending does not become cash-refundable through a failure.
7. Gifted funds remain non-cash-refundable to the recipient in this release. Transfer consumes the sender's refundable allocation; it cannot leave both parties entitled to refund the same money. Carry origin/restriction ancestry through gift chains and reversals.
8. Use eligible promotional credits first, then gifted credit, then paid deposits oldest first, with stable ID tie-breaking, unless a product restriction prevents using that source. For refund allocation, return eligible unspent paid lots oldest first. Lock allocations consistently and never substitute a newer deposit for already-consumed funds.
9. Unclassified legacy value may remain spendable under its existing rules, but is not automatically cash-refundable until its source is verified. This classification does not extinguish customer refund rights; route unresolved cases to support.
10. All pending provider outcomes retain their accounting protection until resolved. Elapsed time, a local crash or an HTTP error alone is not proof that money was not moved.

Update `wallet_reconciliation`, total-deposited/spent summaries, admin dashboards, household allowance calculations, referral/gift eligibility and exports for every new transaction type. Add conservation checks that compare source balances, holds, ledger balances, external capture/refund totals and plan-funded coverage separately. Pending deposits are not spendable wallet liabilities; processor fees do not reduce the customer's purchased credit.

## 6. Deposit and card integration

Implement one shared server operation to finalize a verified captured deposit. Both capture reconciliation and verified webhooks call it. Validate the stored order's owner, kind, expected amount/currency, merchant account, environment and external capture before crediting. Do not trust browser redirects, client success flags or provider metadata alone to select an arbitrary recipient.

Create the wallet before initiating checkout. Replace sample initialization with an atomic zero-balance upsert. Any legitimate welcome/referral grant must be an explicit, idempotent promotional grant. A missing ledger must never trigger balance reset or fabricate deposited cash.

Persist the funding request and idempotency key before calling the gateway. PayPal create/capture retries must adopt the original operation. Credit exactly once even if capture response, webhook and reconciliation arrive concurrently. Keep explicit deposit states such as `created`, `approval_pending`, `capture_pending`, `credited`, `failed`, `cancelled`; do not use `captured` alone as proof that the local wallet is credited.

Credit and durable processing state must commit atomically. If a verified event cannot be applied immediately, persist recoverable work before acknowledging it. A captured deposit with a missing wallet/order must generate an operational case and reconciliation, not disappear after a successful webhook acknowledgement.

Keep legacy non-deposit webhook handling for orders created before cutover. Never reinterpret a legacy plan capture as both wallet deposit and paid entitlement. Reject unknown order kinds explicitly; they must not fall through to deposit creation.

Card funding is an integration dependency, not an existing completed feature. Prefer the already-configured merchant provider's supported hosted card checkout if the account/country/product is eligible. Confirm that capability from the account and current provider documentation. If it is unavailable, obtain the chosen card processor configuration and build its adapter using the same deposit/refund contracts. Do not assume Stripe is configured or silently select a new merchant provider.

Use hosted/tokenized card collection and required provider authentication. Store only provider references and safe display metadata; never PAN or CVV. Distinguish PayPal checkout that may offer card funding from a guaranteed independent card option. Keep card capability hidden until supported and tested. Deliver and report PayPal completion separately if merchant card capability remains unavailable; do not claim the requested card funding/refund feature is complete.

## 7. Service checkout and fulfillment

Create a reusable typed wallet purchase coordinator following existing layers: domain/model, contract, repository, controller/provider, UI. Avoid new direct Supabase calls in widgets. Add typed results for insufficient funds, pending deposit, expired quote, restricted account, pending fulfillment and completed/released purchase.

Persist purchase intent/resume identity on the server; retain local navigation/form context as a convenience. App restart, webhook delay, two devices, repeated taps and changed accounts must not create duplicate purchases or reuse another user's intent. A deposit is not itself purchase authorization beyond the customer's explicit “Add funds and continue” consent for the recorded product/price.

Canonical asynchronous state flow:

`awaiting_funds -> ready -> reserved -> submitted -> processing -> succeeded`

Alternative outcomes:

- Before external submission, cancellation/confirmed validation failure can release the hold.
- After submission, confirmed terminal provider failure releases once.
- Unknown result becomes `reconciliation_required`, retaining the hold.
- Contradictory terminal evidence becomes an incident for reconciliation; do not silently execute both transitions.

Persist a stable supplier transaction reference before submission. Workers atomically claim orders and use the provider's idempotency/adoption facilities. Never hold a database transaction open during network calls. If the provider cannot guarantee safe retry or lookup, escalate ambiguous attempts instead of automatically submitting a second recharge.

Update every worker finalizer, reaper, timeout handler, admin action and callback to use the same guarded transitions. A stale-job reaper must not release funds solely because a timestamp expired. Supplier fallback is allowed only after establishing that the previous supplier did not fulfill.

For synchronous plan activation, debit and entitlement creation/adoption should share one database transaction. For paid line creation before a line ID exists, bind the pending fee/order to the intended owner, carrier and plan; preserve existing retry adoption. An abandoned unconsumed fee needs a server-side cancellation/recovery path, not just the current local timeout. Never reverse a fee while leaving an active paid entitlement.

Premium-covered refills use a distinct funding mode such as `plan_coverage`: consume/restore their prepaid allowance, with zero new wallet debit. Keep successful existing subscriptions and legacy paid entitlements intact. Annual plan cancellation/proration is outside unused-wallet-refund eligibility unless separately specified.

Scheduled wallet-funded purchases recheck funds when executed. Insufficient funds trigger a paused/awaiting-funds state and an actionable alert; no unsolicited external charge. Retry only within the execution's validity window and existing schedule policy. Offline vouchers must reserve/settle against their actual delivery/redemption rules; a revealed usable voucher cannot be refunded merely because client acknowledgement is missing.

Calling also needs an enforceable budget: reserve an initial authorized amount, bound call duration or extend reservations before the budget runs out, and settle actual usage idempotently from verified CDRs. A minimum-balance check alone permits spending funds concurrently with a wallet refund. Preserve existing call accounting and handle late/duplicate CDRs and uncertain call creation.

## 8. Refund unused paid funds

Add a wallet action called “Refund unused funds.” Do not label this unrestricted cash withdrawal.

Required read/write contracts (names are illustrative; reuse existing suitable APIs):

- `get_wallet_summary`: safe balances and capabilities.
- `quote_wallet_funding`: purchase price, shortfall, minimum/max, deposit amount and projected balance.
- `create_wallet_deposit` / `get_deposit_status`: idempotent gateway funding.
- `confirm_wallet_purchase` / `get_purchase_status`: server validation/reservation and tracked fulfillment.
- `quote_wallet_refund`: eligible amount, source allocation/destination labels, exclusions and quote expiry.
- `request_wallet_refund`: authenticate/recheck the quote, atomically reserve funds and enqueue processing.
- `get_wallet_refund_status`: per-item and overall progress, completed/pending/failed amounts.
- Restricted admin APIs: inspect/review/reconcile requests and audit decisions.

Refund quote is advisory until submission locks and revalidates the same available sources. Require the existing payment-authentication UX plus server-side account, session, ownership, device/risk and rate-limit checks. Only the owner can request return of their own paid deposits; household management rights do not grant refund rights. UI biometrics are not a substitute for backend authorization.

Show eligible amount, nonrefundable/restricted portions with explanations, masked original destinations, any provider timing guidance and a confirmation button. A $5 deposit minimum does not create a $5 refund minimum: allow an eligible small residual balance subject to actual provider constraints. Default customer refund fee is zero.

Processing sequence:

1. In one transaction create the refund and source items, reserve their amounts, and enqueue work. Persist a stable provider request key per item before calling the provider.
2. Claim one item and refund the specified amount against its original capture/payment. Do not accept a new destination from the client.
3. If completed, atomically post the external refund debit and consume its reservation/source allocation. Retain the original deposit receipt and add a linked refund receipt.
4. If pending or outcome unknown, keep that item's reservation and reconcile using the same provider operation reference. Do not create a new refund with a fresh key.
5. If definitively failed without funds returned, release only that item's reservation and show the failure. Completed sibling items remain completed.
6. Derive the parent state from item states, including partial completion. Never treat a multi-source refund as externally atomic.

For PayPal, refund the capture using Payments v2, persist the returned refund ID and reconcile its status. Its published ordinary refund window is 180 days; verify the merchant's actual terms and calculate eligibility from the original capture date. Expired/unsupported cases become support review, not automatic alternate-account payouts or an assertion that the customer forfeited their money. For direct card payments, use that processor's original-payment refund API and actual limits.

Provider idempotency retention is finite. Keep local durable operation records beyond the provider window. After an uncertain old request, establish its outcome before any new external request; absence of a local refund ID is not proof of non-execution.

Handle refunds performed manually in the provider dashboard through the same verified ingestion/reconciliation path. They must reduce eligible wallet value exactly once rather than leaving spendable refunded funds. Concurrent disputes, chargebacks, spending and refunds need atomic source restrictions. If external reversal exceeds remaining wallet value, record the unrecovered amount separately and restrict further spending/refunds for review; do not fabricate an ordinary successful debit or erase the debt by clamping accounting to zero.

## 9. Customer and admin UI

Customer UI must expose available balance first, with details for held funds, paid balance, promotional/gift credit and refundable amount. Add funding presets starting at $5 plus custom amount, shared insufficient-funds sheet, deposit progress, resumable purchase progress, refund quote/confirmation/history and transaction detail links.

Use accurate status copy:

- “Payment approved. Waiting for confirmation.” before confirmed wallet credit.
- “Recharge processing. $X is reserved.” during fulfillment.
- “Recharge failed. $X is available in your wallet again.” after release.
- “Refund requested. $X is reserved while we process it.” before external completion.
- “Refund sent to your original payment method.” only after provider completion; distinguish provider completion from bank posting time.

Never show “refunded” and “not charged” interchangeably for a posted debit versus a released hold. Include customer-visible references, safe destination labels and support access. Reuse current styling, accessibility and localization; update all affected ARB strings, generated translations and both currency-display paths. Ensure narrow screens and larger text do not obscure totals or confirmation buttons.

Admin work belongs in the existing control plane. Provide refund filters, source allocation/ledger/order drilldown, pending-age indicators, provider references, safe retry/reconcile actions and review notes. All actions require backend admin authorization and immutable audit entries; a signed-in admin screen alone is insufficient. Manual approval must enqueue the normal refund processor, not grant unrestricted balance editing or destination selection.

Expose validated wallet minimum/max settings, refund enablement, card capability and maintenance controls through existing configuration infrastructure. Separate kill switches for new deposits, new purchases and new refund requests. Pausing intake must not stop necessary webhook processing or reconciliation of money already in flight. Add alerts for captured-uncredited deposits, stuck holds, uncertain refunds, ledger mismatches and provider failures.

## 10. Migration, compatibility and security

Implement additive migrations first. Do not edit already-applied migrations or reset balances/history. Inventory every direct balance mutation/RPC overload and convert or retire bypasses; changing only new checkout code leaves refund double-spend paths open.

Backfill plan:

1. Snapshot/reconcile current balances and ledger; inventory all transaction categories and outstanding provider operations.
2. Map verified paid deposit receipts to source lots using actual capture references and amounts. Account for historical consumption, transfers, refunds, disputes and pending operations.
3. Classify welcome/referral/promotional/gift/admin/unknown funds explicitly. A row named `deposit` is not proof of externally funded cash. Never assign the sample welcome credit to a payment capture.
4. Produce a dry-run report of verified refundable value, unclassified value, discrepancies and in-flight transactions per wallet. Preserve original amounts. Resolve mismatches or exclude unresolved sources from automatic cash refunds with support review available.
5. Make backfill resumable/idempotent and capture changes during the migration through the same transactional writer or a controlled write pause. A stale snapshot must not overwrite concurrent spending.
6. Reconcile all converted wallets and only then enable automatic refund eligibility.

Keep old app clients from bypassing the new policy. Server-side gate creation of direct plan payments and legacy raw-amount debit paths. Return a typed upgrade-required response where safe compatibility is impossible. Existing issued PayPal plan orders must still settle once under their original contract. Version responses so older clients do not interpret held funds as spendable; use a minimum supported client version where necessary.

Enable RLS on exposed tables and apply explicit grants in the same migration. Customers get own safe reads; internal provider events/jobs/source mutation APIs are server-only. Revoke `PUBLIC` execution on privileged functions, set safe search paths, validate identity/ownership/role and maintain minimal grants. Keep existing money guard, suspension/deletion, device-binding, household and App Check protections intact; failures must not reroute to a weaker payment path. Workers need restricted authenticated invocation and leases.

Verify webhook signatures, expected merchant/environment and replay identity. Keep secrets server-side. Avoid recording raw card data, activation data or unnecessary personal information in logs. Update account deletion/purge behavior so open deposits/refunds/disputes are resolved and required financial records retained under the established retention policy; do not permit a cascade to erase unresolved financial obligations.

Before enabling the product in production, record provider confirmation that the actual merchant model and funding/refund rails are supported for the company/markets. Provider policy and legal classification depend on jurisdiction; do not invent a universal exemption for a wallet used only inside the app. This dependency does not prevent building and testing the scoped implementation.

## 11. Implementation sequence and acceptance gates

| Phase | Work | Exit evidence |
|---|---|---|
| A: Inventory | Trace customer/admin/workers, deployed contracts, all money writers, existing tests and provider capabilities. | A checked flow map and compatibility/backfill design; baseline failures recorded. |
| B: Accounting | Source lots, holds, allocations, order/refund entities, guarded RPCs, common available-balance checks, zero wallet creation, reconciliation. | SQL invariants, permissions and concurrent-operation tests pass. |
| C: Funding | USD 5 minimum, deposit-only new gateway checkout, shared finalizer, event inbox/recovery, real card adapter where supported. | Sandbox capture/replay/mismatch/delay tests; gross-to-wallet receipt reconciles. |
| D: Fulfillment | Canonical holds/finalizers across recharge/eSIM/plans/calls/vouchers, worker adoption and reapers. | Success/failure/unknown/crash recovery tests; Premium never double charged. |
| E: Refunds | Eligibility, source reservation, processor adapters, per-item lifecycle, disputes/manual provider refunds. | Partial, repeated, failed, ambiguous and concurrent refunds preserve value. |
| F: Apps | Shared add-funds/resume UX, source-aware wallet/refund screens, admin operations and translations. | Flutter unit/widget and end-to-end scenario evidence. |
| G: Migration/release | Dry-run backfill, client cutover, operational controls, deployment and recovery runbook. | Reconciliation report, reproducible deployment bundle and exact outstanding external dependencies. |

Use separate reviewable commits or change groups per phase without splitting financial invariants across unsafe deploy states. Update this plan's completion checklist and relevant architecture/business-rule documentation to describe the final implemented behavior.

## 12. Required validation

Add meaningful SQL/worker/Edge/Flutter tests for the following. Use existing test infrastructure; do not rely solely on static code searches or tests that mirror implementation.

| Scenario | Required result |
|---|---|
| New/concurrent wallet creation | Exactly one zero wallet; no production sample deposits or reset. |
| Funding arithmetic | Four examples in section 4, sufficient balance, exact cents, invalid/over-limit inputs and restricted funds work. |
| Duplicate deposit delivery | Capture response + duplicate/out-of-order webhook + reconciler credit once. |
| Payment mismatch | Wrong owner/amount/currency/merchant/environment/kind never credits. |
| Approved/unconfirmed deposit | No wallet credit or service purchase yet; eventual capture resumes correctly. |
| App closes/cancels during funding | Late deposit credits once; resume/cancellation follows recorded consent. |
| Concurrent purchases | Shared wallet holds prevent overspend across two devices/workers. |
| Price/entitlement changes | Revalidated price/eligibility; price increase requires new consent. |
| Confirmed recharge/eSIM failure | Exactly one release or linked legacy reversal, with original funding categories. |
| Provider timeout then success | Hold retained; supplier purchase and settlement happen once. |
| Crash after supplier acceptance | Stable reference adoption avoids a second supplier purchase. |
| Conflicting callbacks/reaper | Terminal state cannot reverse twice; contradiction creates an incident. |
| Plan paid before line creation | Retry adopts fee/entitlement; abandoned unconsumed fee recovers safely. |
| Premium included refill | Zero additional wallet debit; failure restores coverage, not withdrawable cash. |
| Scheduled shortage | Actionable insufficient-funds state, no external auto-charge. |
| Household purchase/refund | Correct payer and allowance; manager cannot refund owner's deposits. |
| Gift/bonus/admin/legacy sources | Ineligible cash refunds blocked; failure preserves origin; transfers cannot duplicate refund rights. |
| Partial refund of one deposit | Only eligible unspent value reserved/refunded; original deposit retained. |
| Multi-deposit refund | Correct original destinations and independent item outcomes. |
| Refund races spending/gifting | One atomic winner; no double use of funds. |
| Duplicate refund request/callback | One external refund per item and one ledger debit. |
| Refund response lost or pending | Hold retained; reconciliation adopts outcome without new payout. |
| One refund item fails | Release only definitively failed item; do not undo successful siblings. |
| Old deposit/provider limit | Support review/clear capability result; no arbitrary alternate payout. |
| Manual dashboard refund/dispute | Imported once; correct restriction/debt accounting if value already spent. |
| Calling and vouchers | All paths respect reservations and actual usage/delivery; duplicate CDR/redemption safe. |
| Authorization/grants | Anon and other users denied; customer cannot invoke raw credits/refunds/admin finalizers. |
| Migration and old clients | Idempotent conversion, no balance reset, legacy payments settle once, unsafe old writes blocked. |
| Reconciliation/purge | All new types conserved; unresolved funds cannot disappear through account deletion. |

Run relevant existing SQL suites, especially money paths, PayPal orders, plan pricing/billing, debit/refund grants, gifts, household spend, eSIM and offline vouchers. Run affected Flutter tests and analysis, then the project's full applicable checks. Regenerate Freezed/JSON/localization outputs rather than hand editing generated files. Run worker syntax checks and existing/new worker suites in the authoritative repository. Add real multi-session database race tests; sequential tests alone do not prove locking.

Use sandbox provider captures/refunds and non-production fulfillment fixtures for side-effect tests. Live read-only inspection can verify existing grants and state, but must not be used to manufacture financial transactions. Capture/refund test evidence must include provider IDs/status and corresponding ledger entries in a protected test report. Report tests that could not run and pre-existing failures explicitly; never label the release verified while critical money-path checks are missing.

## 13. Release and operational runbook

1. Confirm provider capability/policy, credentials/webhook registration and test environment separation. Back up/reconcile financial state and finish backfill rehearsal.
2. Deploy additive schema and compatible readers/writers with new intake flags disabled. Do not run incompatible old and new finalizers against the same orders; version execution handling or drain old claims.
3. Deploy tested authoritative workers and Edge Functions with correct JWT/signature configuration. When authorized to deploy workers, follow `.agents/AGENTS.md` direct synchronization and remote syntax/restart verification; do not use the historical mirror or assume a VM git pull deploys changes.
4. Deploy customer/admin apps, enforce the chosen legacy-client policy, and enable wallet-only purchase intake for a limited cohort. Do not also create direct plan orders for that cohort.
5. Enable eligible original-source refunds after source migration, processor tests and reconciliation pass. Keep review-required cases in the admin queue.
6. Monitor captured-uncredited deposits, held-value age, pending refunds, fulfillment uncertainty, duplicates, ledger/source mismatches, processor liquidity and fee costs.
7. On incident, pause affected new intake. Keep webhooks, reconciliation and processing of already-committed operations active. Do not reverse successful external payments, drop new tables or restore an old balance snapshot as a rollback strategy. Use audited forward corrections.

Refund liquidity must be operationally available at the processor; a wallet balance does not guarantee the merchant has sufficient external funds to send a refund. Alert and keep the request accurately pending if the provider cannot yet process it.

Final executing-agent delivery must include changed files by repository, migrations and deployment order, configuration/secret names without values, provider capabilities actually tested, test results, backfill/reconciliation evidence, remaining blockers, and an operator recovery guide. Distinguish local implementation, sandbox verification and production deployment explicitly.

## 14. Completion checklist

- [ ] All KeepSIMs-fulfilled service purchases use the common wallet accounting contract.
- [ ] Insufficient funds opens minimum-$5 funding and reliably resumes the intended purchase.
- [ ] Card/PayPal add-funds options reflect real tested capabilities; no mock card success.
- [ ] Confirmed service failure restores the original reservation/funding exactly once.
- [ ] Unknown provider outcomes never automatically release funds or resubmit purchases.
- [ ] Premium included refills and already-paid entitlements are preserved without double billing.
- [ ] Eligible unused paid funds can be refunded to their actual original sources, including partial/multiple deposits.
- [ ] Promotions, gifts, holds, disputes and unverified legacy value cannot be cashed out accidentally.
- [ ] Refunds, spending, gifts, calling and vouchers share atomic availability checks.
- [ ] Customer/admin UI, receipt/status copy, localization and recovery operations are complete.
- [ ] Migration, compatibility, reconciliation, authorization and financial race tests pass.
- [ ] Production enablement dependencies and deployment status are stated accurately.

## 15. Provider and platform references

Recheck current documentation and account-specific capabilities during implementation. These references support integration constraints, not an assumption that the merchant is approved for every feature.

- [PayPal Payments v2: capture refunds and refund lookup](https://developer.paypal.com/api/payments/v2)
- [PayPal REST idempotency](https://developer.paypal.com/api/rest/reference/idempotency/) — use stable request IDs where supported and retain local deduplication/reconciliation beyond provider retention.
- [PayPal refund guidance](https://www.paypal.com/uk/cshelp/article/how-do-i-issue-a-refund-help101) — published ordinary full/partial refund window and original fee treatment; verify the merchant's jurisdiction.
- [PayPal advanced card payments](https://developer.paypal.com/platforms/checkout/advanced) — verify actual merchant/product eligibility and the appropriate client integration.
- [Stripe refunds](https://docs.stripe.com/refunds) — original-payment constraints if Stripe is the selected card processor; Stripe is not assumed installed.
- [Supabase row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security) — exposed-table RLS and grants must be configured explicitly.
- [Supabase changelog](https://supabase.com/changelog) — verify deployed SDK/runtime/CLI compatibility and Data API exposure changes before applying schema/API changes.

