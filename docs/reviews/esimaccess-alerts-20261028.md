# ESIM-05 — actionable eSIM alerts

28 October 2026, Asia/Muscat. Backend runtime is deployed and verified. Customer app changes are tested locally;
app binaries are unpublished. See the [deployment receipt](esimaccess-alerts-20261028/deployment.json).

The release reuses the existing notification catalogue, preferences, inbox,
durable dispatch jobs, per-target outcomes and push infrastructure. It adds ready
to install, activated, 20%/10% low-data, 48-hour near-expiry, provider-confirmed
expired and completed/support-required order events. Thresholds, freshness and
the alert-only switch are in private `alert_policy`; polling evaluates them every
worker cycle even when new sales are disabled. No supplier API endpoint changes.

Events derive only from saved authenticated ESIM-03/04 observations. Provider
callbacks remain refresh hints. Stable event keys serialize event/polling overlap,
restarts and notification deletion. A first critical reading suppresses the weaker
warning. Unknown/zero-total/inconsistent/stale/failed usage cannot produce a low-data
alert; genuine zero remaining is distinct. Expiry dates alone do not prove expiry.
Order notices never imply a refund or include raw provider errors.

Original issuance opens one entitlement cycle. Byte increases, daily resets and
expiry corrections cannot reset warnings. The private `open_alert_cycle` primitive
is idempotent and rejects old-cycle replays moving the current cycle backwards.
It has no client or public RPC surface. ESIM-08 must call it atomically with a
proven recharge settlement; ESIM-05 does not enable or infer recharge.

Generation respects `esim_updates`/`esim_low_data` opt-outs without overwriting
existing preferences. Both notification trigger and Edge restrict these events
to push; the notification row is the in-app channel. No SMS, email or Telegram
send is introduced. The outbox rechecks saved preferences, ownership, entitlement
cycle and authoritative freshness after delays, and uses the existing IANA timezone
and quiet-hours rules. Queued jobs, accepted/failed/unknown provider outcomes and
delivery attempts stay distinct in existing notification tables; an empty
`delivered_via` never claims delivery. A private event row links to that history.

New app routes resolve IDs through signed-in owner projections, including an
explicit account check against cached profiles. Profile/order IDs in payloads
cannot authorize access. Path interpolation is allowlisted before navigation.
The profile screen shows installation/usage/validity and existing permission
controls plus inbox guidance. Alerts explain that recharge is unavailable and
offer no recharge button. Buying a new eSIM remains a separate action.

## Validation

- 37 Node provider/worker tests, including idle alert sweeps and database failure.
- 15 actual Edge-module tests, including preferences, owner/cycle rejection,
  quiet-hour deferral, push-only narrowing and existing channel regressions.
- 15 isolated PGlite SQL groups over captured deployed table shapes and actual
  forward migrations/notification trigger. These cover deduplication, thresholds,
  cycles, ownership, opt-outs, stale truth, expiry and role denials.
- 29 focused Flutter tests: safe navigation, catalogue, owner isolation and prior
  profile/installation behavior. All 13 baseline tests also pass.
- Affected Dart analysis, release JavaScript syntax and actual release Deno checks
  pass. See [test logs](esimaccess-alerts-20261028/tests).

Prepared artifacts and SHA256 values: [manifest](esimaccess-alerts-20261028/release/manifest.json).
Rebuild with `python3 tools/prepare_esim_alerts_release.py`. This verifies the
previous deployed worker helper and captured outbox source before packaging only
the scoped migration, Edge sources and helper. Existing notification channel
eligibility, provider adapters, credential helpers and other workers are retained.

## Runtime receipt and limits

Applied migration `esim_actionable_alerts` at `20261028014938`; its stored SHA256
matches the release SQL (`4336a0de38df334a3b8d8342242bc0f99a96446bae3f0e2977d73002920a178b`).
`process-alert-outbox` v8 has both retrieved source files matching the release,
retains handler authentication / `verify_jwt=false`, and rejects an unauthenticated
request with HTTP 401. The VM helper matches SHA256
`543f438ee844e98b99c9591bf9d77918c9426ef7654e6ec41569c22a2c4e1557`.
Only `worker-esim-fulfillment` restarted (PID `1060343`); the worker entrypoint
and other process PIDs/restart counts are unchanged. Its real periodic sweeps are
persisted in `alert_policy.last_sweep_at`; the worker reports zero cycle errors.

Live anon/authenticated calls are denied. All four new private tables have RLS
and no client reads. Both service APIs deny anon/authenticated execution. The
security advisor remains at seven pre-existing findings, with no additions.
Both alert preference categories exist for all nine existing profiles. No alert
was generated because there are zero owned Access profiles/orders. The purchase
RPC hash and new-sales-disabled flag are unchanged.

Sources are synchronized on `codex/esim05-alerts-20261028`:
[customer implementation](https://github.com/eduanibal1981/keepSIMsgitHub/commit/432287d),
[backend helper](https://github.com/eduanibal1981/keepsims-backend/commit/5960b9d).
Default branches and the Admin app are unchanged. The customer branch follows
the prior ESIM-03/04 branch and contains only this step's selected changes;
unrelated pending local work and checkout-only line-ending differences were
excluded. The current review/evidence is recorded in the follow-up source commit.

Historical preflight:
Preflight confirms ESIM-03/04 migrations, no owned Access profiles/orders,
new sales disabled, zero worker cycle errors, reachable VM and matching base
source. The purchase RPC MD5 is `524b7d1f6f79eadaf422fb0ff3f1c315`.

There are no real Access profiles for live threshold/device-delivery acceptance.
No paid purchase, provider mutation or wallet action is part of validation.
Real provider callbacks still require the authentication hookup recorded in
the ESIM-03/04 review. Polling remains the available observation path.

## Recovery

Set only `esim_private.alert_policy.enabled=false` to stop new alert generation
and cancel delayed eSIM sends; fulfillment/reconciliation remains active. Restore
only the prior helper and outbox sources if necessary. Preserve the private
deduplication ledger and cycle history. Never restore pre-ESIM-03 fulfillment,
replay uncertain submissions, or disable recovery as an alert rollback.
