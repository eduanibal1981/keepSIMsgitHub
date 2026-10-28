# ESIM-13/14 — traveller groups and operational handover

28 October 2026, Asia/Muscat. Engineering implementation and local acceptance
are complete. Scoped runtime deployment/source verification is recorded below
when performed. Paid and real-device acceptance remain unverified; this is not
an assertion that provider spending can be enabled.

ESIM-13 adds private traveller/profile labels and dashboard grouping under the
purchaser's existing ownership. It adds a short-lived server quote with exact
per-profile retail totals and one parent group record. Acceptance reserves each
child atomically under the original payer's wallet lock; a refusal rolls back the
entire initial reservation transaction. Each child is a quantity-one existing
order/run/hold/receipt, so delivered, delayed, failed and cancelled members have
attributable settlement and recovery. Retries adopt the same parent/children.
The new gate defaults false. The server maximum stays three; no supplier batch
limit or account permission is inferred from public documentation.

Supplier allocations bind through each child's stable order/profile reference.
An unexpected multi-profile allocation for a single child stays unresolved.
Identity collisions never overwrite another owner's profile. One delivered child
can capture while another remains held. A proven unsubmitted failure releases
only its own hold; an eligible cancelled child follows ESIM-10's itemized credit
and unique original-debit refund binding. Group history explicitly distinguishes
reserved, captured, released, refunded and refund-pending amounts per member.

No account-to-account management, wallet delegation, pooled allowance, number,
device transfer or automatic QR sharing is introduced. Existing installation
privacy remains intact. Labels are limited to 60 characters without controls,
are owner-only through RPCs/private tables, and hide across account changes.
Admin group inspection exposes operational IDs and retail settlement while
excluding traveller labels and activation material. Existing customer and admin
boundaries remain authoritative.

Fixed group quotes use the real catalogue discriminator `total`. Final catalogue
acceptance caught and corrected an earlier new-code `total_bundle` mismatch;
fixtures now follow the actual normalized source. Original hour/day units are
preserved. Daily members carry exact days and require ESIM-09's independently
verified whole-duration pricing; missing prices do not become one-day totals.
Each group child gets an authenticated fresh provider compatibility/price check
before its one durable submission marker. New-action disable never resubmits or
releases an uncertain submitted child. Existing shared supplier throttling,
receipt journal, reconciliation and financial primitives are reused.

ESIM-14 adds customer help in the app and an
[operational runbook](esimaccess-groups-handover-20261028/operations-runbook.md).
Fresh catalogue evidence covers Oman and Egypt fixed/daily offers and a GCC
regional offer. Supplied network metadata differs by product; no market-level
network promise is inferred. Account duration prices remain unverified.
Recorded source parity checks match catalogue Edge v8, event ingress v1 and
notification outbox v8. The provider callback registration remains unresolved:
the observed account URL-only form cannot provide the ingress secret header.
The final acceptance matrix explicitly separates engineering/runtime evidence
from paid/device/callback/account enablement gaps.

Tests include all customer eSIM features and focused Admin inspection, adapter,
worker, Edge, SQL/RLS and financial cases. Existing fixed settlement, daily and
controls suites run with the new migration applied; independent-session native
PostgreSQL verifies duplicate parent acceptance, child leases, competing wallet
reservations and non-owner access. Native control settlement remains balanced.
Supplier visibility, retail pricing and installation/QR regressions are retained.
All tests use isolated fixtures; no provider purchase, wallet mutation or outbound
message is part of acceptance. See the review's evidence and release manifest.

Runtime changes are one forward migration, the existing JWT-protected recharge
Edge helper and one authoritative fulfillment runtime file. Only fulfillment may
restart. The installer verifies all existing eSIM worker/module dependency hashes
before direct copy, checks syntax, backs up source and confirms unrelated PM2
processes remain unchanged. App binaries are not published. Rollback pauses group
and affected new-action gates while retaining compatible schema, member/refund
bindings, holds, original ownership and read-only recovery. Never reissue an
uncertain child or release funds because a timer expired.

Provider reference: [current API](https://docs.esimaccess.com/). The documented
supplier batch capability does not change this release's three-member policy.

## Verified deployment and acceptance

Applied migration `20261028131332` (`esim_traveller_groups`) to project
`zwxswagokhgbuzrrbnhr`; stored SQL MD5 `5272560b2107e3c5ca501d1dc8074ded`
matches the reviewed source. Recharge Edge v5 retains JWT verification; retrieved
entry/helper bytes match the manifest. Anonymous POST returns 401; OPTIONS 204.
The existing catalogue v8, event v1 and outbox v8 sources also match their recorded
release artifacts. All thirteen current eSIM-integration migrations match source;
older migration-history coverage is itemized in the source audit rather than
inferred from filenames.

Only fulfillment restarted (PID 1076824, restart count 25, online); its deployed
hash and all thirteen existing dependency hashes match the release. Other PM2
PIDs/status/restart counts remain unchanged. The backup is
`/home/abdal/keepsims_backend/backups/esim13-14-20261028`. Fresh cycles have zero
errors. Live owner/private-table/anonymous/session/forged-user_metadata/Admin
boundaries pass. Real Oman/Egypt retail and group quotes work with acceptance
disabled; missing daily pricing refuses a five-day quote. The acceptance
transaction was rolled back; no profile, order, group, label, hold or refund was
created. All 12 existing/new action and contract gates remain false.

Fresh checks: 133 customer eSIM cases; 4 Admin cases; 87 Node worker/adapter cases;
30 Edge cases; 13 baseline checks; 12 isolated supplier-visibility groups; 22 new
group SQL groups and 65 existing fixed/daily/control scenario groups with the new
migration applied. Nine native PostgreSQL concurrency/accounting checks pass.
Scoped customer/Admin analysis and frozen Deno checking are clean. The isolated
application release sources also pass, and unrelated primary-tree edits are
excluded from the source release.

Advisors add four intentional private deny-client RLS information notices and six
intentional authenticated definer warnings, guarded by owner/session or audited
assert_admin checks. There are no new anonymous exposures, security errors,
missing foreign-key indexes or duplicate-index findings. The one new unused-index
notice reflects an empty label table. Reviewed categories:
[private RLS](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
[authenticated definer RPCs](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).

See [acceptance matrix](esimaccess-groups-handover-20261028/acceptance-matrix.json)
and [deployment receipt](esimaccess-groups-handover-20261028/deployment.json).
ESIM-14 engineering acceptance and handover are complete; production rollout,
paid/provider/device acceptance, callback hookup and app binary publication remain
explicitly open. No further implementation step is automatically enabled by this
report. Use the runbook and scoped budget/device/account evidence before rollout.
