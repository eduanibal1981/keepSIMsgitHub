# eSIM profiles, event inbox and reconciliation — ESIM-03/04

28 October 2026, Asia/Muscat. ESIM-03 implementation and backend runtime are
deployed and verified. ESIM-04 runtime is deployed and verified; real provider
callback registration remains blocked by the account's URL-only webhook form.
Customer/Admin Flutter changes are tested locally; no app binary was published.

## Delivered behavior

- Profiles bind an internal UUID to supplier/account/profile and the original
  issuance order. A stable-reference or ICCID collision cannot overwrite another
  owner. Global ICCID uniqueness is retained conservatively: reuse requires
  support review rather than an unsafe upsert.
- Delivery requires genuine ICCID, stable profile reference and activation
  credentials. Partial batches retain only proven profiles. The worker and order
  modal no longer manufacture delivery records or credentials.
- Profile, installation and bundle states are distinct. Purchase is not labelled
  installed. Expiry comes from provider evidence rather than purchase-date
  arithmetic; unknown activation dates/deadlines stay unknown. Legacy data is
  preserved, while its owner view hides unverified credentials and guessed expiry.
- Exact total/used/remaining byte values distinguish zero from unknown. Failure
  retains last-known usage and an error/freshness label. Observation timestamps
  and request leases prevent older results replacing newer observations. Issued,
  active, depleted, suspended and unresolved profiles remain scheduled; terminal
  profiles receive three final checks. Owner refresh queues one throttled batch.
- A private event inbox deduplicates durable receipts, leases work, retries with
  backoff, exposes dead-letter counts and prunes completed/dead events after 30
  days. Payloads retain minimal references and a state hint, never activation codes.
- Callbacks only schedule authenticated, exact-reference provider reads. They
  cannot complete issuance, bind an unproven order, transfer ownership or settle
  money. Correlation includes supplier account, original transaction and profile.
- Submission intent is durable before the one purchase POST. Recovery never
  resubmits. Missing/ambiguous outcomes remain reconciling or support-required;
  timeout/expiry never triggers a refund. Missing provider-order references can
  be adopted only with independently proven transaction binding; otherwise an
  operator must resolve them.
- Catalogue Edge, catalogue VM and profile/recovery requests share one database
  limiter at two outgoing requests/second for the primary supplier account.
- New purchases are gated off in the database before checkout can debit funds.
  Recovery does not depend on the sales gate. No gate-enabling Admin control is
  included; ESIM-08 and remaining provider acceptance must precede enabling sales.

## Deployment evidence

Project: `zwxswagokhgbuzrrbnhr`. Source hashes are recorded in
[release manifest](esimaccess-profiles-events-20261028/release/manifest.json).
The user's existing deployment approval covered both migrations, Edge functions
and scoped VM workers. Only the two eSIM processes were stopped/restarted.

| Surface | Verified runtime |
| --- | --- |
| ESIM-03 migration | `20261028003236`, SHA256 `5502a4fdbc1536365e50c72d0b8bd1e60f8236fc276775fce04db892768ded20` |
| ESIM-04 migration | `20261028003243`, SHA256 `6d609e3c4153b85766fc7e0d48e65533f7565c1615dfb1ef490ff952e542d64c` |
| Event Edge | `esimaccess-events` v1; JWT verification off, dedicated header authentication in handler; retrieved deployed source matches artifact |
| Catalogue Edge | `sync-esim-catalogue` v8; sync-secret authentication retained; deployed source matches artifact |
| Fulfillment VM | PID `1058080`; source SHA256 `d538d047e0cbdaced6c21ce28d5db516477d40b4036f18c27e99fc8c17a8d492` |
| Catalogue VM | PID `1058079`; source SHA256 `8fe8dbe4e844ebe631ae8005692bf9a0fa87381226e0ef0a2ba4af6754ae1572` |

All eight deployed JavaScript files match the manifest. Pending local fleet
telemetry and the unrelated Edge Zendit credential-helper cutover were excluded.
Direct VM source backups are at
`/home/abdal/keepsims-esim34-source-backup-20261028`; no credentials were copied.

The worker heartbeat reported zero errors with the sales gate false. A real
catalogue-only Edge invocation returned HTTP 200: 3,187 fetched/upserted, zero
retired, complete. Other suppliers remain inactive. Existing profile/order fields
retain their original hashes (`60d367ae6f1931fc065021de1f743d77` and
`d8a169c08b625c4346048e0df1b0eca5`). The purchase RPC body remains
`524b7d1f6f79eadaf422fb0ff3f1c315`.

Live callback checks: missing secret 403, invalid secret 403, valid synthetic
event 202, duplicate 202. Exactly one minimal inbox row was saved; the worker
retried its unmatched reference without creating any profile/order or financial
action. An activation-code sentinel was absent from persistence. Only that exact
synthetic event was then removed (one row).

Live transaction-scoped role tests verified owner access, cross-owner isolation,
anonymous denial, client denial for service RPCs, non-Admin denial for the Admin
status RPC, and honest unknown legacy issuance/expiry. Private tables have RLS,
no client schema access and no client policies. The customer view uses
`security_invoker=true, security_barrier=true`; raw wholesale order columns are
not granted to clients. The security advisor's four new informational
[RLS-without-policy notices](https://supabase.com/docs/guides/database/postgres/row-level-security)
are intentional default-deny protection for these private service-only tables.

## Validation

133 focused scenario/test cases passed: 47 Node worker/provider tests, four
ingress tests, 19 isolated SQL scenario groups and 63 customer Flutter tests.
The existing 13 baseline tests also pass. Customer and affected Admin analysis
reported no issues. Both actual release Edge entrypoints pass Deno checks, and
all deployed JavaScript files pass local and VM syntax checks. Logs are in
[tests](esimaccess-profiles-events-20261028/tests/).

The isolated SQL tests exercise both forward migrations against deployed table
shapes, leases, partial issuance, identity conflicts, stale observations,
ambiguous outcomes, owner isolation, callback deduplication, retry/dead-letter
behavior and audited Admin reconciliation. They use fixtures without purchases
or wallet mutations. Read-safe live checks complement these fixtures.

## Remaining external acceptance

CONFIRMED: the customer's open Chrome account at
`https://console.esimaccess.com/developer/index` has a blank webhook setting and
an Edit form containing only URL, Cancel and Save. Inspected with permission;
cancelled without changing the account. No header/signature setting was exposed.

The deployed ingress requires `x-esimaccess-event-secret`, using a unique Vault
secret named `esimaccess_event_secret`. The secret is never returned to clients
or stored in these artifacts. Public [notification documentation](https://esimaccess.com/docs/what-webhook-notifications-do-you-send/)
and [API documentation](https://docs.esimaccess.com/) describe callback types and
URL configuration, but do not establish an incoming signature/custom-header
contract. Outgoing API HMAC authentication is not proof of incoming callback
authentication. Do not register the bare endpoint: URL-only callbacks would be
rejected. A provider-supported header/signature contract or a separately reviewed
authenticated relay is needed to finish real event hookup. Polling remains active.

UNKNOWN: real paid issuance, real profile lifecycle/usage, incoming provider
event acceptance and exact recovery after a real provider/local-persistence
failure. There are zero owned eSIM Access profiles/orders, so these have not been
claimed as live verified. No paid provider call or wallet change was made.
No profile reuse migration, notifications, top-up, cancellation/refund operation,
or other later-plan money capability is enabled by this release.

## Recovery and rollback

Keep new sales disabled. If needed, stop only `worker-esim-fulfillment`; queued
work and leases remain durable. Do not restore the old fulfillment worker: it
contained fabricated issuance/refund fallbacks. Apply a forward repair for schema
issues rather than removing provenance or events. The prior catalogue source
backup is available for a scoped catalogue rollback, provided the shared limiter
is preserved while any recovery runtime is active. Never replay an uncertain
submission as a rollback step.
