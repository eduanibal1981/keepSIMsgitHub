# ESIM-09 — Day Pass duration and existing-profile extensions

28 October 2026, Asia/Muscat. Customer source is implemented and tested; the
scoped database, Edge and fulfillment runtime are deployed and verified. Customer
binaries remain unpublished; account pricing and paid acceptance remain gated.

Customers choose 1–365 whole days for supported daily products and review a
short-lived server total. An eligible extension uses the same installed eSIM
and exact base variant. It adds validity without replenishing today's allowance,
undoing slowing, changing installation credentials or declaring delayed usage fresh.
Daily allowance, total package usage, reset timing and confirmed expiry remain
distinct. Missing daily usage/reset evidence is shown as unknown. Daily products
do not receive total-GB price comparisons or a misleading one-day checkout total.
Fixed-plan pricing and checkout keep their existing contract.

## Pricing and capability boundary

There is no verified account duration-price feed or owned Access test profile.
The implementation therefore seeds **no prices, discount coefficients or account
recharge-count limit**. No undocumented quote endpoint is called. Missing verified
duration pricing produces `DURATION_PRICE_UNAVAILABLE` and no payment control.

The service-only `service_esim_store_daily_price` imports an independently verified
supplier **whole-duration wholesale total** in 1/10000 USD units. It binds the
account, exact package/variant, duration, catalogue/profile context, source reference,
observation and expiry (at most 24 hours). Profile extensions additionally require
the observed provider recharge count and its verified account maximum. This is a
trusted operational import contract, not a customer-writable price or an automatic
claim that public marketing discounts apply to this account. Newer imports
invalidate prior quotes; older observations cannot replace newer prices.

Canonical retail tier fees apply once to the duration total. Quotes expire within
two minutes and bind the owner/payer, profile or new purchase, duration, quantity,
package, price evidence and single-use acceptance key. New purchases keep the
current server quantity cap of three. Available balance excludes reservations;
an unavailable balance stays unknown. Browsing and quotes never reserve funds.

`daily_duration_enabled` and `daily_contract_verified` default false, independently
of fixed-recharge/new-sales controls. All existing spending gates remain false.
Price import alone does not enable spending. Activation requires independently
verified account pricing/limits and separately scoped provider/wallet acceptance.

## Execution and recovery

Daily actions use the existing ESIM-08 order/run, reservation, capture/release,
profile locks and durable receipt journal. Initial daily purchases carry
`periodNum` and the exact duration total through quote, order, request and history.
Extensions have their own `daily_extension` discriminator while sharing the
existing recharge ledger types. The worker rechecks the current exact package
and variant before its durable submission marker. A missing/uncertain response
stays reserved; it never causes a second provider POST or a timeout refund.
Confirmed extension receipts require the reviewed period and a later supplier
expiry. Settlement preserves the daily depletion/usage counters and installed
identity, captures once and stores selected duration in the receipt history.

Aggregate package bytes do not prove today's remaining daily quota. Daily
low-data alerts are suppressed until that observation contract is verified;
validity and operation alerts continue. The confirmed entitlement starts the
new expiry alert cycle. No automatic recharge is introduced in ESIM-09.

## Verification

- 123 customer feature/navigation tests pass on the isolated release; scoped
  Dart analysis is clean. Seven new cases cover duration input, unknown pricing,
  daily usage wording, quote binding and account switching.
- 53 worker cases pass on the isolated release, including nine new daily cases;
  six changed worker modules pass syntax checks.
- 15 new isolated SQL scenario groups and 23 ESIM-08 regression groups pass.
  Eight native PostgreSQL boundary/concurrency groups pass, including concurrent
  daily acceptance/settlement and preserved daily counters/installation identity.
- 11 Edge handler cases pass; the actual entry point passes frozen Deno checking.
- Live source/ACL/owner-boundary and post-deploy health evidence are recorded with
  the release. No customer binary, paid provider action or live wallet mutation
  is part of this work. Real-provider daily purchase/extension acceptance remains
  **UNVERIFIED**.

The migration has exact live dependency source guards. Isolated SQL fixtures
remove only that deployment preflight block because their dependency formatting
differs; all functional migration SQL is executed in both database engines.

## Release and rollback

See [manifest](esimaccess-daily-duration-20261028/release/manifest.json), the
reproducible builders in `tools/`, and `evidence/` in that folder. Source bases:
customer `fa4ca67582e71093c36a46275f2d7fa6ec370e0e`, backend
`3c3961d18cd428817efe1abc18dfbaefa9e27766`. Admin changes are unnecessary.
Only `worker-esim-fulfillment` may restart. Six reviewed files are copied directly
from authoritative `backend-sync-wt`, with a source backup and hash verification.
The catalogue worker, unrelated PM2 services and private receipt journal remain
outside this release.

Rollback disables `daily_duration_enabled`; retain the schema, immutable quotes,
accepted operation evidence, receipt journal and settlement/recovery. Never
replay an uncertain supplier request, release an unknown reservation or revert
to a worker that cannot recognize outstanding daily extensions.

## Provider references

Reviewed [API contract](https://docs.esimaccess.com/),
[May 2026 daily-extension announcement](https://esimaccess.com/boost-unlimited-fup-plan-sales-with-top-up-feature/)
and [daily-plan overview](https://esimaccess.com/docs/unlimited-day-pass-plans-esimaccess/).
The current contract specifies a 1–365 day `periodNum`; the newer announcement
requires the same base variant and explains that an extension only adds days.
Its published discount examples are not imported as account pricing. Older help
that excludes daily recharge is superseded for capability discovery, while
account-specific eligibility, pricing and recharge limits still need verification.

## Verified deployment result

Applied `20261028055806` (`esim_daily_duration`) and `20261028060252`
(`esim_daily_quote_indexes`) to project `zwxswagokhgbuzrrbnhr`. Stored SQL hashes
match the release files exactly. The second forward migration adds the three
foreign-key lookup indexes identified by post-deploy performance checks; those
findings are resolved. Security additions are three intentional authenticated,
owner-checked definer RPC notices and two private deny-client RLS notices. There
are no new security errors or anonymous function exposures.

Recharge Edge **v3** retains JWT verification. Retrieved entry/helper bytes match
the release; unauthenticated POST returns **401**, OPTIONS **204**. All six VM
source hashes match; only fulfillment restarted, PID **1066763**, restart count
**23**, online. Other PM2 PIDs/status/restart counts are unchanged. Backup:
`/home/abdal/keepsims_backend/backups/esim09-20261028`. Fresh cycles report zero
errors. Existing wallet capture function hash is unchanged; order view retains
invoker/barrier options and clients cannot read wholesale columns.

Live owner quote checks fail closed on missing duration pricing; invalid duration,
missing/foreign profile, anonymous quote, private reads and customer price import
are refused. No price/quote/operation/profile rows were created. All six spending
switches remain false. Fixed-bundle regressions were also run with the ESIM-09
migration overlaid (23 scenario groups). See the evidence directory for receipts,
source parity, advisors, access checks, live state and test logs.

Source release branch: `codex/esim09-daily-duration-20261028` in customer/backend.
ESIM-10 is the next planned implementation step; enabling daily spending is a
separate verified-pricing/provider/wallet acceptance decision.
