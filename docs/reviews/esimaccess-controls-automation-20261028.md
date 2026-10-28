# ESIM-10/11/12 — cancellation, service controls and capped automation

28 October 2026, Asia/Muscat. Implementation and isolated tests are complete.
Runtime deployment verification is recorded below when completed. App binaries
and paid provider acceptance are separate from this source/runtime release.

Cancellation shows a short-lived itemized USD wallet refund, with each charge
bound to its original payer and actual captured debit. Zero usage alone is not
eligibility: the provider must freshly confirm GOT_RESOURCE/RELEASED, no bound
EID, a supported activation trigger and zero reported order usage immediately
before submission. Quantity greater than one, unattributed legacy charges,
external-payment refunds and unverified fee/exclusion policies require support.
No retail refund policy or supplier credit is seeded from a wholesale price.

The service-only refund-scope import requires independently verified retail
policy and every captured base/attached recharge charge. A fingerprint invalidates
it when related operations change. Supplier cancellation and retail refunds have
separate states. Empty success responses and callbacks cannot credit a wallet.
Confirmed cancellation remains refund_pending until an operator supplies exact,
itemized supplier credit evidence. Partial or ambiguous credit stays pending;
all quoted attributable credits settle atomically through the existing credit
primitive, once per original debit. Receipts and ownership history are retained.

Cancel, suspend and resume use a private operation/lease engine. Acceptance,
manual recharge and automatic recharge share the existing profile lock. A durable
marker precedes exactly one provider POST. Lost responses recover by authenticated
stable-profile queries only. Permanent revoke is excluded. Pending controls
block recharge; suspension/cancellation also pause automation. Suspension changes
network service and makes no promise that validity freezes. Customer refreshes
queue throttled backend checks. Controls remain pending until current supplier
state confirms the action; unresolved work can be escalated and queried without
resubmission.

Automation is off by default and requires an active owner session, exact profile,
payer, compatible package, reviewed price, per-action maximum, cumulative monthly
cap, trigger, minimum interval, consent revision and optional end date. Fixed
plans use recent observed remaining data; daily plans extend near expiry and
never react to daily quota depletion. Whole-duration daily pricing/limits use
the existing verified service import. No package/profile substitution occurs.
Caps are in USD, per profile, per UTC calendar month; all automated completed
charges in that month and all unresolved automated exposure from any month or
consent revision count. Refunds do not replenish that month's gross budget.
A minimum 30-minute expiry safety margin and one reservation per entitlement
cycle prevent expiry races and repeated low-data loops. Increasing a cap does
not silently change the reviewed price. Price increases require new consent.

The evaluator uses existing exact quotes, wallet reservations and settlement.
Price changes, low balance, account/profile restrictions and cap exhaustion
pause consent with an in-app/push notification under existing preferences.
Unknown/stale observations queue refresh and wait. Consent withdrawal/version
changes and global disable are rechecked at the durable submission boundary.
Unsubmitted reservations release through the existing proven-failure path;
submitted actions retain their funds and receipt recovery.

Admin support uses audited assert_admin RPCs through AdminApi: minimized profile
search by UUID or ICCID suffix, observation freshness, control/order timelines,
unresolved queue, read-only refresh/reconciliation, reasoned escalation and
separate capability pause switches. Worker/event health and catalogue observation
are shown. Current funding and credential health stay explicitly UNKNOWN where
no direct current health observation exists. No customer/administrator can
manufacture provider confirmation or force a refund through the app.

All five new account switches default false; the six existing spending/contract
switches stay false. No independently verified account refund schedule or daily
price schedule is fabricated. Enabling service controls or spending requires
separate account/profile acceptance; this release exercises isolated fixtures.

Verification: 124 customer tests, 3 admin tests, clean scoped Dart analysis,
46 Node worker cases, 10 Edge handler cases and frozen entry-point Deno checking;
27 new isolated PostgreSQL scenario groups, 23 settlement regression groups with
this migration overlaid, and five independent-session native PostgreSQL checks.
These cover ownership/ACL boundaries, activation races, exact base-plus-recharge
refunds, different payer/owner, partial credit, duplicate capture/refund, revoked
consent before/after submission, stale usage, price/cap/low-wallet pauses, daily
near-expiry extension, prior-month uncertainty, concurrent evaluators and
manual-recharge/suspend serialization. Logs and the release manifest are in
[the evidence directory](esimaccess-controls-automation-20261028/).

The scoped VM release changes only esim_fulfillment_runtime.js,
esim_profile_controls.js and providers/esimaccess_profiles.js from authoritative
backend-sync-wt. The installer checks every existing dependency hash, backs up
source, verifies syntax/hashes and restarts only worker-esim-fulfillment. The
private receipt journal, catalogue worker and other PM2 processes are preserved.
The Edge remains esim-recharge-discovery with JWT verification enabled.

Rollback pauses cancellation_enabled, service_controls_enabled and
automation_enabled. Keep compatible schema, operation history, refund bindings,
consent exposure and read-only recovery. Never replay an uncertain provider POST,
release an unknown hold, or downgrade outstanding daily/recharge recognition.

Provider contract references reviewed on this date: [current API](https://docs.esimaccess.com/),
[unused-profile cancellation](https://esimaccess.com/docs/how-do-i-refund-an-unused-order/),
[recharge/refund rules](https://esimaccess.com/docs/how-to-top-up-a-data-plan/)
and [activation/refund exclusions](https://esimaccess.com/esim-pricing-coverage/).
Provider state confirms cancellation separately from financial credit. The API
exposes no itemized cancellation receipt or documented duplicate-request guarantee.

## Verified deployment

Migration `20261028063614` (`esim_controls_automation`) is applied to
`zwxswagokhgbuzrrbnhr`. Stored SQL MD5 `27fb2671d709ad83c2dabe97f2d15306`
matches the reviewed release bytes. Edge v4 retains JWT verification; retrieved
entry/helper bytes match the manifest. Anonymous POST returns 401 and OPTIONS 204.

The three VM hashes match the manifest. Only fulfillment restarted, PID 1067931,
restart count 24, online; all other PM2 PIDs/status/restart counts are unchanged.
Backup: `/home/abdal/keepsims_backend/backups/esim10-12-20261028`. Fresh cycles
have zero errors. Live owner, service, active-session, private-table and forged
user_metadata/admin boundaries pass; the acceptance transaction was rolled back.
No profile, order, control, refund or consent rows were created. All 11 flags
remain false. Existing capture/credit primitives were not replaced by this release.

Post-deploy advisors add eight intentional private deny-client RLS information
notices and seven intentional authenticated definer RPC warnings with explicit
owner/session or assert_admin checks. There are no new anonymous exposures,
security errors, missing foreign-key indexes or duplicate-index findings. New
unused-index notices reflect empty gated tables. See the
[Supabase definer check](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
and [private RLS check](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
for the reviewed advisory categories, plus evidence/postdeploy-*.json.

Provider/device acceptance remains UNVERIFIED: no owned Access profile exists,
and no provider mutation, purchase or wallet mutation was used for live testing.
Customer/Admin source is tested locally; binaries remain unpublished. Next
planned implementation is ESIM-13. Account enablement and paid acceptance need
the actual eligible profile, allowed operations, verified policy/pricing and cap.
