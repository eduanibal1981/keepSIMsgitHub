# Retail data and ownership — Task 19

Reviewed and implemented locally: 2026-10-18 (Asia/Muscat).
**REPAIRED LOCALLY; NOT DEPLOYED.** No migration, client, Edge or worker was
released. No customer rows were read, provider orders placed, balances changed,
or production mutation/denial tests performed.

## Finding status and evidence

| Surface | Evidence before this repair | Status |
| --- | --- | --- |
| Authoritative refill quote | Fresh live definition returns wholesale cost, expected margin and profitability; authenticated EXECUTE; no owner check. Task 18's local replacement already checks ownership and is service-only. | REPAIRED LOCALLY; live repair remains pending |
| Raw provider shelves/effective and Zendit views | Fresh live grants allow customer reads; effective view explicitly includes supplier cost and override note. Captured provider policies are permissive. | REPAIRED LOCALLY |
| Refill catalogue RPCs | Current source/export returns supplier fixed/range prices; clients add fees and display a base/fee split. | REPAIRED LOCALLY |
| Return trips and calling | October 16 retail repair removes supplier response columns and validates ownership. Task 3 intentionally retains captured return shapes for its separate containment release. | Existing local repair completed and reasserted here |
| eSIM catalogue and receipts | Catalogue view is retail-shaped but uses old markup pricing; direct order reads/streams include wholesale, markup and supplier reference/error fields. Grants on raw eSIM cache/suppliers are unnecessarily broad; grants alone do not establish visible rows under RLS. | REPAIRED LOCALLY |
| Related receipts/approvals | Execution/schedule fields, raw CDR, worker approval routes and setup pricing snapshots contain internal pricing or provider evidence. | REPAIRED LOCALLY |
| DID search/purchase | Task 17's explicit retail DTOs and private quote/order storage already remove supplier cost and service-margin decomposition. | REPAIRED LOCALLY, retained; provider/deployment proof remains Task 17's gate |
| Production state | Read-only metadata confirms the new migration is absent. | UNVERIFIED for closure; existing live exposure remains |

[Fresh live register](retail-ownership-live-20261018.json) records grants,
return shapes and body digests, without customer data. Definitions and policies
were also compared with the supplied export and the October 16 catalogue.
The live security advisor was read; it reports existing definer-view notices.
It cannot certify an unapplied migration. No finding is marked VERIFIED DEPLOYED.

## Changes

`20261018060000_retail_ownership_contract.sql` is a forward completion of the
existing repair, after its wallet/pricing and Task 3 dependencies:

- Revoke table **and column** access to raw provider/eSIM shelves, diagnostic
  views and package costs. Preserve service-role supplier reads and internal
  pricing/selection RPCs. Explicitly deny client execution of arbitrary-user
  entitlement, supplier-selection, paid-evidence and wholesale quote helpers.
- Recreate package/calling RPCs with retail return shapes and ownership checks.
  Their DROP uses RESTRICT, without CASCADE. Reassert active/history grants and
  safe search paths. This also handles Task 3's older contained response shapes.
- Rebuild `esim_offers` with the canonical account retail resolver and composite
  offer identities. Its deliberate definer projection uses a caller-checked
  `customer_esim_price(provider,bundle)` wrapper and explicit retail columns.
  Customers receive no wholesale base-table grants. Own eSIM receipts use an
  invoker view and explicit base-column grants under owner RLS.
- Return retail fixed/range endpoint totals from both catalogue RPCs. The exact
  selected range value is priced by `get_customer_refill_quote`; the customer
  response is a positive allowlist and contains no fee/cost decomposition.
- Add `request_retail_instant_refill`, accepting the reviewed retail ceiling
  and native dispatch value. It uses existing supplier, risk, household and
  execution logic internally, checks the resulting charge, and rolls back
  price drift. Exact selected range units survive rounded USD interpolation.
  Legacy supplier-basis submission is service-only. Errors do not echo supplier
  values. This change does not claim to redesign general request idempotency.
- Add customer execution/schedule/call/approval projections. Owner RLS applies
  to invoker receipt views. Approval views independently require the requester
  and current owner/accepted manager relationship, excluding internal routes,
  execution snapshots and raw errors. Setup pricing snapshots are not readable
  by customers. Fixed generic failure messages retain useful receipt status.
- Replace trip policies with owner-and-line checks for every operation. A saved
  accepted price remains the active/history price when the catalogue changes.
  Unknown historical prices remain null; an accepted non-planning package cannot
  be replaced to rewrite history. No historical prices are backfilled.
- Keep admin supplier inspection through barrier views guarded by the actual
  `assert_admin()` contract. Ordinary users and forged user_metadata are denied;
  app_metadata-authorized administrators retain supplier information. The admin
  catalogue, cache-refresh polling and execution repository use those views.

The customer app removes supplier receipt/model fields and base/fee widgets,
uses retail totals once, refreshes exact range prices server-side, and checks a
fresh total before consent. A stale async range response cannot replace another
selection. Receipt/status streams immediately poll narrow views every 2–3 seconds,
without subscribing to raw table payloads. This adds bounded polling load and
that much update latency. Schedule/execution caches use new, user-scoped retail
keys, so old raw cache entries are not a fallback. Existing downloaded data is
not claimed erased. The historical mock-provider-ID filter is removed from the
retail history query because that provider field is private.

Scheduled pricing/engine write enforcement and legacy queue retirement remain
Task 20. Removing client supplier fields is not proof of server write enforcement.
No Task 20 migration or queue-lifecycle change was made.

## Verification actually run

- **23/23 isolated native PostgreSQL scenarios passed.** Real selected production
  tables, constraints, grants, RLS and financial triggers are rebuilt by the
  existing harness. The extension captures two more tables, four views and 13
  independently hash-verified real functions. Tests also start from Task 3's
  actual contained RPC return shapes and inject historical column grants.
- Coverage includes anonymous/foreign ownership denials, direct-column and
  SELECT-star denial, customer catalogue/receipt success, exact range pricing,
  free-fee promotions, repeated read safety, accepted-manager/viewer behavior,
  trip writes/history/unknowns, admin spoof denial and privileged supplier access.
  Actual fixed/range submission preserves internal costs and retail charges,
  including fractional fixed supplier costs at a fee-rounding boundary.
  An insertion-time price change rolls back the execution and sanitizes its error.
- **81/81 focused Flutter tests passed:** eSIM catalogue/comparison and receipt
  HTTP adapters, immediate receipt polling, retail-only model serialization,
  calling/DID compatibility, return trips, retail quote validation and forecast/
  schedule displays. No production HTTP calls occurred.
- **18/18 DID backend tests passed** with isolated adapters.
- Customer analysis of affected paths: **no errors**, six existing controller
  `invalid_use_of_internal_member` warnings and five existing `avoid_print`
  informational diagnostics. Admin analysis:
  **no errors**, three existing `unawaited_return_in_try_block` warnings and ten
  existing informational diagnostics. No unrelated lint cleanup was attempted.
- Dart models/providers were regenerated. Node syntax checks and scoped diff
  whitespace checks passed.

[SQL results](retail-ownership-results-20261018.json) name each scenario.
Reproduce the SQL suite with `npm run test:retail --prefix tools/financial-tests`.
Set `EMBEDDED_POSTGRES_MODULE_PATH` for an existing pinned dependency cache and
`RETAIL_TEST_REPORT` to save results. It starts a disposable native database on
localhost port 56557 (`RETAIL_TEST_PORT` overrides), then removes it. Local shared
memory permission is required. The unavailable Supabase CLI prevented its normal
migration-file generator; the forward file is versioned explicitly and verified
by executing its unchanged contents in the isolated database.

The harness retains documented external Auth, rate/risk, notification and health
adapters. It does not certify the complete Supabase trigger graph, cryptographic
JWT verification, PostgREST relationship/schema caching, Realtime delivery,
provider behavior or production deployment. No full-app build/release gate ran.

## Coordinated release requirements

1. Review the read-only `supabase/verification/retail_ownership_preflight.sql` on
   the target environment and compare actual columns, signatures, policies,
   dependencies and grants. Confirm Task 3's containment and Task 18's configured
   canonical pricing prerequisites; preserve existing financial/provider gates.
2. Task 3's independent containment must precede the coordinated financial/
   canonical retail repair. Its body preflight deliberately rejects newer retail
   bodies. **Do not blindly apply files in filename order or run unfiltered db
   push.** Apply the reviewed financial/Task 9–13/18 dependency chain, including
   `20261016050000_retail_customer_contracts.sql`, then Task 19. An existing
   equivalent containment must be verified rather than replayed over newer code.
3. Release compatible customer **and admin** clients with the new projections and
   RPC. Old clients expecting supplier columns, base-table SELECT-star, raw
   streams or legacy range submission will fail closed. Use the established
   maintenance/update gate during cutover; do not restore wholesale grants.
4. Reload and verify PostgREST schema/cache and view relationships. With scoped
   authorized accounts, verify anonymous/foreign denial, own receipt/quote reads,
   accepted household-manager access and admin catalogue/execution filtering.
   Compare the read-only grant/function matrix after release. Review intentional
   definer projections by their static columns and caller predicates; do not
   satisfy an invoker-view permission failure with wholesale base grants.
5. Run the broader Task 24 API, client/build and worker regression gates. Validate
   polling load and receipt latency. Any actual paid/provider smoke test needs
   the separate Task 25 authorization and budget. Roll forward with a reviewed
   compatibility fix; never roll back security by restoring customer cost access.

Supabase's [RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security)
explains why grants, row policies and deliberate view execution context must be
reviewed together.

Task 19's local acceptance checks are complete. Task 20 can proceed locally using
these retail read contracts; its financial-write and queue checks remain required.
Operational rollout remains pending and is not implied by this completion.
