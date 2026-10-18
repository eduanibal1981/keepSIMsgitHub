# Financial fixture and ledger contract review

2026-10-17 (Asia/Muscat). Task 6 is complete locally. The financial release gate
is **red**: production accounting fixes remain Tasks 7–8. No migration, provider
request, payment, customer balance change, backfill or worker deployment occurred.

The old fixture omitted the production ledger type CHECK. Its earlier passing
results did not establish compatibility with production. The replacement
reconstructs captured catalog definitions, then applies all eight actual pending
October 16 financial migration files unchanged. Their SHA-256 hashes still match
the October 16 migration cleanup manifest.

## What the fixture now preserves

[The snapshot](../../supabase/tests/fixtures/financial_production_snapshot.json)
contains 42 bounded public tables, 651 columns with exact types/precision,
defaults, NOT NULLs and generated expressions, 217 CHECK/PK/UNIQUE/FK constraints,
76 unique indexes, 64 RLS policies, table/API ACLs, 29 column ACLs, 42 actual
function definitions and their EXECUTE ACLs, 11 installed actual triggers and the
existing `wallet_reconciliation` view, including its security-invoker option and
ACL. The export's `captured_date` uses the database's UTC date (October 16);
this review and local execution use Asia/Muscat (October 17).

[The read-only export query](../../supabase/tests/fixtures/capture_financial_production_snapshot.sql)
can refresh this bounded snapshot through Supabase MCP. Review the exported diff
before replacement. It reads catalogs/function sources, not customer records.
Its scope is explicit; new tables, overloads, caller patterns and trigger
dependencies require review rather than automatic expansion. The snapshot also
records signatures, `md5(prosrc)` and literal type references for 33 live functions
that reference the ledger or wallet mutation/capture helpers. These are static
references, not proof of invocation or complete dynamic call tracing.

[Catalog verification](../../tools/financial-tests/fixture-verification.mjs)
compares the reconstructed catalog before any migration changes it. Only
whitespace and PostgreSQL's equivalent constant varchar-array cast deparsing are
normalized. Positive SQL checks then verify CHECK rejection (including the
`NOT VALID` positive-amount CHECK on new rows), NOT NULLs, FKs, generated supplier
prices, effective API grants and owner-only wallet reads. PostgreSQL continues to
enforce a `NOT VALID` CHECK for newly inserted/updated rows; it only skips the
initial historical scan. See [PostgreSQL ALTER TABLE](https://www.postgresql.org/docs/17/sql-altertable.html).

The actual grants are preserved, including broad legacy privileges; this does
not certify those grants as safe or replace Task 3's dedicated containment suite.
Synthetic Auth identities now receive explicit `profiles` rows where the live
SIM FK requires them. Countries, carrier rules and executions supply their real
required fields. Every DO case rolls back independently, including successful
cases, JWT/role settings and synthetic catalog rows. SQLSTATE, constraint and
case name are reported without stopping later cases. Failed regressions exit 1;
they are never converted into successful expected failures.

## Reproduced release blockers

| Desired behavior | Actual failure after applying the pending migrations | Next owner |
| --- | --- | --- |
| Refund claim/finish settles a payout once and adopts a retry | `23514 wallet_transactions_type_check`: `refund_payout` is excluded | Tasks 7–8 |
| eSIM reversal restores the consumed refundable lot and keeps retries idempotent | Valid `esim_purchase_refund` falls through to a new `unverified_legacy` lot; original provenance is lost | Task 7 |
| Call reversal restores the original funding source once | Valid `call_refund` takes the same incorrect new-lot path | Task 7 |
| Verified paid liveness capture uses a supported ledger discriminator | `23514 wallet_transactions_type_check`: live settlement requests excluded `verification_debit` | Task 7 contract; Task 4/liveness integration before release |

The eSIM case passes the same explicit type as live `reap_stale_esim_orders()`.
The authoritative `../backend-sync-wt/worker_esim_fulfillment.js` instead omits
`p_type` and uses generic `refund` with an `esim_refund_<order>` reference. Both
are real interfaces to reconcile. No dedicated live hardcoded `call_refund`
producer was found: it is supported by the CHECK and parameterized refund RPC.
Its test protects that supported interface; deployed caller activity is unknown.
The funding trigger currently recognizes `refund`, `esim_refund`, `topup_refund`,
while the latter two aliases are themselves excluded by the live CHECK.

## Complete allowed-type inventory and intended accounting contract

Direction below is the required contract for future fixes, not a claim that all
current producers implement it. All amounts are positive magnitudes. A completed
credit has `balance_after - balance_before = amount`; a debit has the negative
delta. `admin_adjustment` can have either sign. Only completed entries contribute
to reconciliation. Refunds restore consumed allocations, including original cash
refundability/deadline/capture identity or promotional restrictions; they must not
mint replacement withdrawable money. No source found means **unknown/legacy**,
not permission to delete a type or fabricate historical funding.

| Live allowed type | Direction / provenance requirement | Confirmed producer or caller reference |
| --- | --- | --- |
| `deposit` | Credit verified cash; capture-backed cash refundable only within policy | `credit_wallet_for_deposit`, legacy `credit_wallet`; PayPal fulfillment |
| `topup_debit` | Debit unreserved/held original lots once | `debit_wallet_for_topup`, `settle_successful_execution`, setup capture/finalization, execution adapters |
| `refund` | Credit/reverse known original consumption | `credit_wallet_for_refund`, `admin_fail_refill`; authoritative eSIM worker uses its default |
| `referral_credit` | Credit promotional, nonwithdrawable; gifting cannot launder it | `redeem_referral_points` calls deposit helper with referral description/reference; pending M2 routes it to this type |
| `referral_withdrawal` | Debit/redeem eligible referral value under an explicit policy; no invented cash provenance | No literal producer in inspected live functions/Edge/authoritative worker source |
| `plan_fee_debit` | Debit settled membership fee once | `pay_plan_fee_from_wallet`, setup/fallback/capture functions; referral trigger observes this type |
| `home_mode_debit` | Debit service purchase once | No literal producer located; exact legacy operation unknown |
| `auto_fund` | Credit verified provider cash with capture identity | Allowed and consumed by reconciliation/UI; no literal producer located (deposit helper emits `deposit`) |
| `esim_purchase_debit` | Debit authoritative eSIM price once | `request_esim_purchase` through generic debit; stale-order recovery observes it |
| `esim_purchase_refund` | Credit original eSIM funding allocations | `reap_stale_esim_orders` explicitly passes this type; household spending observes it |
| `wallet_settlement` | Debit remaining balance during authorized account settlement | `purge_deleted_accounts` |
| `wallet_forfeit` | Debit explicitly forfeited residual balance, without inventing a payout | `purge_deleted_accounts` |
| `gift_sent` | Debit sender's transferable lots atomically with recipient credit | `transfer_wallet_credit` |
| `gift_received` | Credit recipient with policy-restricted provenance; never infer new refundable cash | `transfer_wallet_credit`; queue-resume trigger observes it |
| `admin_adjustment` | Signed credit/debit delta, positive amount, recorded actor/reason | `admin_adjust_wallet` |
| `offline_voucher_debit` | Debit redeemed voucher once | `settle_offline_voucher` through generic debit |
| `call_debit` | Debit actual call charge once, respecting active budget and other holds | `debit_wallet_for_call`, `settle_call_wallet_hold`, call completion |
| `call_refund` | Credit original call consumption once | Allowed parameterized `credit_wallet_for_refund` interface; dedicated producer/activity unconfirmed |
| `did_purchase_debit` | Debit verified DID purchase once | `supabase/functions/manage-dids/index.ts` passes `p_txn_type` to generic debit |

Two additional produced/requested types are **not allowed**: pending
`finish_wallet_refund_item` writes `refund_payout` (debit cash payout), and live
`settle_line_verification_attempt` captures `verification_debit` (debit paid
liveness). Tasks 7–8 must choose an explicit schema/code compatibility repair.
This task deliberately neither adds these values to the CHECK nor aliases them
to an unrelated debit.

Shared consumers must be reviewed for the entire set, not only the three types
observed in the aggregate live ledger at capture (`deposit`, `plan_fee_debit`,
`topup_debit`):

- Live `wallet_reconciliation` has a credit/debit whitelist, misses valid types,
  includes invalid aliases (`admin_credit`, `admin_debit`, `welcome_home_debit`,
  `voucher_purchase_debit`, `refund_payout`), and does not filter completed status.
  Pending M2 uses completed signed balance deltas. Unexplained historical drift
  must remain visible; no inferred balancing entries or automatic repairs.
- Pending `book_wallet_transaction_funding` consumes every negative completed
  delta but has the reversal whitelist mismatch above. It must preserve signed
  adjustments, gift restrictions and allocation identity across all callers.
- Live `trg_fn_resume_awaiting_funds` recognizes `credit`, `deposit`, `refund`,
  `gift_received`, `referral_credit`, `manual_credit`; two are invalid types and
  eSIM/call reversal types are missing. Queue-resume effects need later coverage.
- `household_spend_mtd`, `get_wallet_forecast`, admin overview/listing, referral
  award, export/history and settlement functions have narrower literal reads.
  The snapshot records their exact signatures and source fingerprints. They
  must not be treated as universal reconciliation models.
- Customer wallet history/repository reads the ledger generically; wallet UI and
  dashboard classify only `deposit`/`auto_fund`, referral aliases and generic
  `refund` as credit-like entries. They omit specialized reversal labels and
  signed adjustment direction. Admin operations also consume ledger-derived
  reporting. No client/display changes were made in Task 6.

## Evidence and deliberate limits

Commands (from the repository root):

```sh
npm run test:fixture --prefix tools/financial-tests
npm test --prefix tools/financial-tests
npm run test:concurrency --prefix tools/financial-tests
```

The fixture catalog comparison and 3 positive blocks pass. PGlite runs 16
financial blocks: **11 pass, 5 fail**. Native PostgreSQL runs those blocks,
3 fixture guards and 3 independent-session scenario groups: **16 pass, 6 fail**.
Five serial failures represent four distinct defects; the original refund block
also catches the payout CHECK. Native refund settlement adds the sixth failure.
Reservation/debit races, refund request/claim adoption and concurrent setup
finalization run even when settlement fails. These are block/scenario counts,
not counts of every individual assertion. Both financial runners exit 1.
Native money races use effective `service_role`; setup finalization uses effective
`authenticated` with owner claims, not the fixture owner's grant/RLS bypass.
Machine-readable outcomes and exact input hashes are retained in
[the evidence file](financial-production-contracts-20261017.json).

This is a focused financial fixture, **not a complete production baseline**:

- Only the named 42 public tables and one view are reconstructed; nonunique
  indexes, production seed/config data, extensions, cron, Vault/net, JWT signature
  verification, PostgREST resolution, service deployments and provider APIs are
  outside this fixture. Local functions/tables are created as postgres; Supabase
  owner/default-ACL parity is outside scope. Captured API/column/EXECUTE ACLs and
  RLS predicates are checked, not silently replaced with blanket grants.
- Minimal `auth.users` and claim functions stand in for Supabase Auth. Auth
  creation/profile/invite flows do not run. The fixture's five external adapters
  are rate limiting, money risk policy, household budget, admin audit and supplier
  offer lookup; they are explicitly synthetic, not certified production behavior.
- The snapshot lists 34 omitted trigger chains by exact table/name/body. They
  include notification delivery/paid notification guards, scheduling/health/alert
  clocks, routing/failover, provider execution activity, offer history/counts,
  profile suspension/power-user/invites, household management and affiliate
  normalization. No provider delivery or complete account-policy behavior can be
  inferred from their absence. Two uninstalled health/notification function names
  needed by M1 raise if accidentally invoked. Financial ledger/lot mutation,
  pricing/settlement functions, referral award, tier/tampering protection and the
  selected fee/cancellation/resume triggers use actual definitions.
- The financial runner applies only actual `202610160*.sql` files. Tasks 2–5
  have separate bounded suites; their migrations are not implicitly certified by
  this run. The former `TEST_OCTOBER4_APPLIED` mode now rejects invocation: this
  captured-live baseline is not a historical pre-October-4 snapshot.

Tasks 7–8 can now repair the failing contracts against these constraints. They
must add any newly required dependencies to the explicit fixture scope and rerun
both engines. This report does not authorize production rollout or certify the
pending financial package as ready.
