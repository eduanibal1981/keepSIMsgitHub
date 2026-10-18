# Offline-voucher request state — Task 21

**Repaired locally; not deployed.** The supplied production schema's
`offline_voucher_requests.status` accepts `open`, `fulfilled` and `cancelled`.
The original `offline_voucher_state()` joins `pending`/`processing`, so a real
open request never reaches the customer card. The isolated suite reproduces
that failure before applying the forward migration.

## Resulting contract

`20261018080000_offline_voucher_request_state.sql` preserves the existing
active-request-only JSON contract:

| Stored lifecycle | Customer `request` | Admin queue |
| --- | --- | --- |
| `open` | `{due_at, reason}` | Default open queue |
| `fulfilled` | `null` | Explicit fulfilled/history filter |
| `cancelled` | `null` | Explicit cancelled/history filter |
| No request | `null` | No row |

Closed history cannot duplicate a line or hide its current open request. The
existing partial unique index allows one open request per line. Owned lines
remain filtered by `auth.uid()`; both request and grant joins now also require
the same owner, excluding inconsistent rows whose line belongs to another
request/grant owner. Missing identity fails closed, anonymous execution is
denied, and authenticated/service execution remains explicit. Service sessions
still need an owner UID to obtain that owner's state.

The response retains the exact request and grant field sets. It contains no
PIN, encrypted PIN, fingerprint, serial, provider receipt or private admin note.
Raw stock/grant/request table access remains unavailable to customer roles.
Eligibility, stock expiry rules, verified redemption templates, feature flags,
voucher issuance/settlement and recovery endpoints retain their current behavior.
This narrow state repair does not certify legacy voucher eligibility as paid
receipt proof or establish offline rescue readiness.

## Consumers traced

Customer `OfflineVoucherRepository.getState()` parses/caches the response as
`OfflineVoucherState`; `VoucherLineState.request` is an optional **open** promise.
`EmergencyPinCard` uses `request.dueAt` for the expected-by message when awaiting
stock. It already handles a null request with generic preparation copy, so no
new response discriminator, generated model or UI flow is needed. Closed and
absent requests cannot supply an active deadline. A cached open promise remains
an offline snapshot until the next successful state refresh; this repair does
not invent freshness while disconnected. Bearer PINs stay in `VoucherVault`.

Admin `AdminApi.voucherRequests()` and `voucherRequestsProvider` already default
to `open`. The Requests tab uses the resulting due/overdue values and the guarded
cancel action. Captured `admin_list_voucher_requests()` calls `assert_admin()`;
its default, terminal-state filters and null all-history filter remain accurate.
No admin application edits are necessary.

## Verification

- **18 isolated PostgreSQL scenarios passed**, using PGlite 0.5.10 and the
  production financial baseline plus four exact voucher table shapes, captured
  constraints/indexes/table ACLs/RLS and two independently hash-verified original
  RPC definitions. Includes the original bug, each lifecycle, transitions,
  closed history plus an open row, one-open uniqueness, rejection of the invented
  lifecycle values, both request reasons, owner and malformed-owner cases,
  anonymous/missing identity, raw-table denials, secret-free grants, disabled or
  absent flag, admin filters and ordinary-customer admin denial.
- **41 offline-recharge Flutter tests passed**, including nine added model/cache
  serialization and widget cases consuming actual SQL-generated payloads. Each
  lifecycle verifies that only an open request renders an expected-by deadline;
  revealed grants retain their outstanding-obligation behavior.
- Focused Dart analysis finds no voucher errors or lints. The broader analysis
  also covering the final Task 18 pricing display adjustment reports two
  existing unused declarations and three existing onboarding lints; no errors.
- `git diff --check` passes for tracked changes.

Run from the repository root (or use `test:vouchers` in the harness package):

```sh
PGLITE_MODULE_PATH=/path/to/pglite/dist/index.js \
FINANCIAL_TEST_REPORT=docs/reviews/offline-voucher-state-results-20261018.json \
node tools/financial-tests/vouchers.mjs
flutter test --no-pub test/features/offline_recharge
```

The SQL suite writes `test/fixtures/offline_voucher_state_payloads.json` only
when all scenarios pass. The data-free fixture can be regenerated with
`capture-voucher-fixture.py /path/to/schema.sql`; mismatched independently
recorded function hashes fail capture. Results are recorded in
[the SQL report](offline-voucher-state-results-20261018.json).

## Release boundary

No Supabase SQL MCP tools are exposed in this session, so no fresh live metadata
or behavior verification is claimed. Tests use synthetic identities and inert
local encrypted-byte sentinels. Auth lifecycle, REST/RLS integration, voucher
mutation/crypto triggers, real stock, providers and recovery services are outside
this bounded state-query test.

Before an authorized targeted release, run
`supabase/verification/offline_voucher_state_preflight.sql` against current live
metadata and compare the function body, constraints, unique index, ownership,
grants and flag with this reviewed shape. Apply only the reviewed migration in
the project's approved dependency order; avoid an unfiltered migration push.
Then run the read-only SQL contract checks and verify the customer/admin views
with approved existing accounts/data. This task enables no feature, loads no
production stock and activates no unverified recovery endpoint.
