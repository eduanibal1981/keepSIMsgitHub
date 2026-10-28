# eSIM operational handover — 28 October 2026

Scope: the eSIM Access implementation through ESIM-13, with ESIM-14 engineering
acceptance and runtime verification. Paid/device acceptance remains open. The
customer help screen covers installation, delayed usage, recharge choices,
uncertain orders, refunds, automation, service suspension and traveller groups.

## Release and source

The authoritative Node workspace is `backend-sync-wt`; VM runtime is
`/home/abdal/keepsims_backend/servers` on the recorded Google Cloud VM.
Use the frozen release manifest, scoped migration builder and VM installer in
this review. Validate current dependency hashes before copying. Transfer source
directly, run syntax checks and restart only `worker-esim-fulfillment`. A GitHub
push does not update the VM. Retain the private receipt journal and source backup.
Customer/Admin binaries are separate releases and are not published by this work.

## Enablement gates and paid acceptance

All existing sales, recharge, wallet, daily-price, cancellation, service-control
and automation gates remain off. `group_orders_enabled` also starts false; the
server maximum stays three members and every child quantity stays one. The
provider's published batch maximum is not account-specific authorization to
increase this release's limit. The shared supplier limiter remains authoritative.

Production rollout has not been performed. A named test account alone does not
restrict account-wide switches: verify a server-enforced cohort restriction before
opening a live spending gate. Keep new spending closed while that review or any
provider/device proof is incomplete. Labels/help can be released independently.

Before a paid/device exercise, obtain a named purchaser/account/profile, exact
permitted actions and spending ceiling. Verify current account credentials and
funding without copying secrets into logs. Verify actual device compatibility,
real issuance, installation/activation, provider observation freshness, one fixed
recharge, an eligible daily extension with independently imported exact pricing,
and an eligible unused cancellation with itemized supplier credit/retail policy.
Use isolated fixtures for replay/timeouts. Record receipts, UTC timestamps,
original payer/hold/debit bindings and the result of each exercise. Cancellation
is not proof a paid test will be refundable. Stop the affected new-action gate
if account acceptance fails; recovery must remain available.

Callback registration remains unresolved: the observed account form accepts only
a URL, while the deployed hint ingress requires a dedicated secret header.
Do not register an unauthenticated URL or turn off ingress checks. A verified
provider authentication contract or reviewed authenticated relay is required.

## Triage

Use the audited eSIM support panel with a profile/owner UUID or final four ICCID
digits. Inspect freshness, original order, pending operations, event health and
worker health. Never paste ICCIDs, EIDs, activation codes or credentials into
support notes or logs. Group inspection accepts the parent UUID and displays
per-member order/profile identifiers and retail settlement. Private traveller
labels and all activation details are excluded from admin group responses.

- Unable to install: use the customer's exact owned profile and installation
  guide. Do not fabricate activation material, recommend deletion casually, or
  claim original-device recovery is verified without evidence.
- Delayed usage: preserve last-known totals and provider observation timestamps.
  Queue a reasoned refresh. A poll completing does not make delayed usage fresh,
  and unknown/zero/depleted/expired are separate states.
- No recharge choices: inspect exact profile/account/variant capability and
  expiry. Refresh compatible TOPUP discovery. Do not substitute another supplier,
  new profile or package. Daily extensions add validity, not today's speed.
- Unknown provider result: inspect the child order timeline and submission marker.
  A submitted operation is queried by its stable reference; never buy again or
  release its hold on a timeout. Durable receipts recover without a supplier POST.
  Escalate exact-outcome gaps instead of editing terminal states.
- Refund pending: supplier cancellation and financial credit are separate. Keep
  the operation pending until exact itemized supplier credit and the approved
  retail/fee scope cover every captured attributable charge. Use the service-only
  refund-scope/settlement contracts through a reviewed operational import; never
  force wallet balances or supply an unverified balance delta. Each refund goes
  to the original payer. Legacy external/unattributed batch charges need support.
- Pause automation: owner withdrawal or a reasoned global pause prevents future
  submissions. Recheck consent revision, package, reviewed total, per-action cap,
  UTC monthly gross exposure and minimum interval before enabling. Unresolved
  exposure counts across month/revision changes. Submitted work still reconciles.
- Suspend versus expiry: pausing automation is separate from suspending data.
  Suspension makes no promise that validity freezes. Current supplier state must
  confirm suspend/resume; a local request alone is pending.
- Partial group: inspect each child. Every child reserves/captures/releases its
  own exact price; one delivered profile proves no other member's issuance.
  Keep genuine delivered members and their labels bound to their original child
  orders. Never redistribute supplier references between travellers. A cancelled
  member's refund cannot release or credit another member's money.
- Supplier outage/funding: report last successful observations and explicit
  UNKNOWN health. A transient read cannot silently redirect or disable recovery.
  Pause affected new actions deliberately. Account funding alone proves no
  purchase outcome; never expose secret values when checking credential health.

## Rollback and monitoring

Pause `group_orders_enabled` and affected existing new-action switches. Keep the
additive schema, quote/member bindings, original ownership, refund records and
wallet/receipt recovery. Unsubmitted prepared children may release only through
the existing proven-no-submission path. Submitted uncertain children stay held.
Do not downgrade a worker past recognition of outstanding recharge/daily actions.
Read-only profile polling, inbox processing, receipt adoption and support
reconciliation continue while new purchases are disabled.

Monitor fresh fulfillment cycles, lease/retry/support queues, event dead letters,
catalogue observation age and per-child holds/captures/refunds. The final audit
records source fingerprints, applied SQL hashes, function versions/JWT settings,
PM2 changes and eSIM-scoped accounting invariants. Existing unrelated mock/legacy
financial discrepancies are not relabelled as an eSIM release issue or cleaned up.
