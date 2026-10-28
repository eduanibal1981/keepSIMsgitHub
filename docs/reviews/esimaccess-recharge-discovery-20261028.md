# ESIM-07 — compatible recharge discovery and quotes

28 October 2026, Asia/Muscat. Database, Edge and scoped VM runtime are deployed and verified under the user’s approval.
Customer app source is tested locally; app binaries are unpublished. See the
[deployment receipt](esimaccess-recharge-discovery-20261028/deployment.json).

Customers can browse compatible TOPUP offers for an existing owned profile and
preview a two-minute server quote. The Edge handler validates the customer JWT
and uses customer SQL authority. SQL binds ownership, the owning payer, exact
profile, supplier account, fixed-bundle action, current package ID, duration,
USD retail total, expiry and a unique acceptance key. Neither an acceptance RPC
nor a provider recharge endpoint is added. ESIM-08 must implement atomic key
consumption alongside the future financial operation; these keys cannot spend.

Owner requests queue private discovery work. The existing fulfillment runtime
calls the small new helper through the existing account-wide supplier limiter
and Vault credential resolver. It requests only `/package/list` with `TOPUP`
and the persisted profile ICCID. It never substitutes BASE/destination offers,
calls a purchase endpoint, or exposes provider credentials/wholesale costs.
The adapter and other VM entrypoints remain untouched.

Five-minute caches bind supplier/account/profile/owner and a context fingerprint.
Profile identity/state/observation/capability changes and statement-level catalogue
changes invalidate them. Leases fence late/outdated provider results. Current
supplier enablement, profile freshness/expiry and unresolved original issuance
are checked before browsing, quoting and quote revalidation. Disabling discovery
also invalidates quotes without interrupting existing fulfillment/reconciliation.
ESIM-08 must extend the sibling-operation gate for its new operation contract.
Private raw normalized lists expire and are pruned after a day; unused quotes
are retained for 30 days. No installation payload enters these tables.

Retail pricing calls the exact deployed `resolve_esim_offer_price`, including
its tier/fee-floor behavior. No second wallet-funding fee is added. The exact
deployed `get_wallet_summary` supplies available funds after active holds;
lookup/currency/shape failures remain unknown. Insufficient and unknown funds
can receive a preview, never spending authority. Browsing neither reserves nor
debits funds. Cached version and reviewed retail total must still match when
creating a quote; later price, tier, profile, cache or supplier changes make the
quote stale. Repeated previews reuse the same current quote/key.

Recharge appears beside installation/recovery, separate from buying a new eSIM.
The UI shows allowance/validity effects, fixed/daily behavior, provisional final
expiry, wallet availability and quote expiry. Pending old-owner results are
discarded after an account change. Daily offers can be shown, but duration quotes
remain unavailable until ESIM-09 verifies that pricing contract.

Provider contract checked against the [current API reference](https://docs.esimaccess.com/)
and [recharge rules](https://esimaccess.com/docs/how-to-top-up-a-data-plan/):
TOPUP lookup supports ICCID; fixed bundles add allowance/validity and daily plans
extend validity without stacking daily data; expired profiles cannot recharge.
No hardcoded account-specific recharge count or final expiry is promised.

The [release manifest](esimaccess-recharge-discovery-20261028/release/manifest.json)
contains exact source hashes. `python3 tools/prepare_esim_recharge_release.py`
rebuilds it and verifies the ESIM-05 deployed fulfillment base. The runtime scope
is one migration, the new `esim-recharge-discovery` Edge function with JWT
verification, and two VM files for `worker-esim-fulfillment`. Deployment starts
with discovery disabled, verifies the helper's heartbeat, then enables read-only
discovery. New sales and all recharge payment acceptance remain disabled.

## Validation and acceptance limits

- 35 focused backend cases and 16 actual Edge-module cases pass on the isolated release.
- 14 SQL scenario groups compile/run over captured table shapes and the actual
  deployed fee/retail/wallet functions: owner/role denials, compatible-only lookup,
  tier/minimum fees, available-vs-posted balance, unknown balance, stale prices,
  disabled supplier, unresolved actions, leases, invalidation and non-mutation.
- 103 Flutter feature cases pass on the isolated release, including six new
  model/repository/controller/widget cases. Affected Dart analysis is clean.
  All 13 offline baseline checks also pass in the primary workspace.
- New Edge Deno checks and both backend JavaScript syntax checks pass.

There are zero owned Access profiles in the live database. Real-profile TOPUP
discovery, actual provider eligibility and paid recharge acceptance remain
UNVERIFIED. No paid tests, wallet mutation, callback registration, app publication
or other ESIM-08+ feature is authorized by this implementation.


## Deployed runtime evidence

Applied `esim_recharge_discovery_quotes` at **20261028030224**. Stored SQL SHA256
`75364bbf04ae825e7f8245b94d978f50f9c0c9b613d71513f74eb4b49ffc60e8` matches the
reviewed migration. Edge **v1** retains `verify_jwt=true`; both retrieved runtime
source files match exactly. Deno’s lock is locally checked and submitted, but
Supabase’s bundled-source retrieval does not return that non-runtime file.
Missing authentication returns HTTP 401; browser preflight returns 204.

Only `worker-esim-fulfillment` restarted, PID **1062106**. Both changed VM file
hashes match the manifest; worker entrypoint/provider sources and all unrelated
process PIDs/restart counts are unchanged. Fresh periodic helper heartbeats and
zero cycle errors are verified after enabling only `discovery_enabled=true`.
The new-sales gate remains false and purchase RPC fingerprint remains
`524b7d1f6f79eadaf422fb0ff3f1c315`. Live RLS/ACLs, cross-owner/nonexistent-profile,
anon and service-boundary checks pass. There are no live quotes/cache rows yet.

Advisor changes are the three intentional authenticated definer-RPC notices for
owner-checked customer entrypoints, plus three informational private RLS tables
without client policies. These boundaries are tested; other advisor categories
are unchanged. See [comparison](esimaccess-recharge-discovery-20261028/evidence/security-comparison.json).
The [authenticated definer-RPC notice](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
is intentional here because private-table operations need the owner-checked
server boundary. Private no-policy RLS is deny-all for clients, with service-only
execution. Existing unrelated advisor findings are outside this release.

## Rollback

Set only `esim_private.recharge_policy.discovery_enabled=false`. This closes
discovery/quotes and invalidates existing previews while leaving reconciliation,
alerts and usage running. If needed, restore only the previous fulfillment helper
after disabling discovery. Keep compatible schema and quote evidence; do not
restore pre-ESIM-03 runtime or enable sales as part of rollback.

## GitHub source synchronization

Runtime implementation source is on `codex/esim07-recharge-discovery-20261028`:
[customer](https://github.com/eduanibal1981/keepSIMsgitHub/commit/05f4ec9e107a8f12695eaff7e0530252378647f5) and
[backend](https://github.com/eduanibal1981/keepsims-backend/commit/e2e2c7c2abe90d5abc3c4157d7a2de0b6bc6257c).
The branch follows ESIM-06 customer and ESIM-05 backend release source; primary
working directories and default branches were preserved. Runtime hashes are
separately verified against the direct VM/Edge deployment, not inferred from Git.
