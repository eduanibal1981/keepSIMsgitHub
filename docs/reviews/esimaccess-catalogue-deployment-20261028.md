# ESIM-02 runtime deployment — 28 October 2026

Deployed and verified after the owner's explicit approval of the migration, catalogue Edge function and scoped VM worker. Customer/Admin app binaries were not part of this deployment.

| Surface | Verified release |
| --- | --- |
| Database | `esim_catalogue_details` at `20261027232834`; SQL SHA-256 `0ca1795ee159039042daaa85cdab425b93074c76d76181e102bfa0c6eee9ca1b` |
| Compatibility repair | `esim_catalogue_runtime_compatibility` at `20261027233320`; SQL SHA-256 `7004c9d4e6096e72d3661de7176eda112a95d60cd53048855e6b8f147abfedbe` |
| Edge | `sync-esim-catalogue` version 7; `verify_jwt=false`; internal secret authentication preserved |
| VM worker | `worker-esim-catalog`, PID 1056256, Node v22.23.1; SHA-256 `8947c6acbc3eefe5047af413f119568e7c78f1c3b8eda7652c32ab0ebabc896e` |

Both stored migration hashes exactly match source. The local migration filenames retain their creation timestamps; the managed migration-history versions above record actual application. The required supplier-visibility predecessor is included as already-deployed source, not as an additional runtime change.

The Edge authenticated sync and the worker's own Vault-authenticated sync each fetched/upserted **3,187** active offers. Current facts: **1,731 total-data bundles**, **1,456 daily slowing plans**, zero unsupported unlimited classifications, both product identifiers present on every active offer. Three activation values remain explicitly unknown. eSIM Access is the only customer-visible supplier; source switches are unchanged.

Live checks cover old/v2 comparison parity, checkout/retail prices, daily filters, minimum-fee price bounds, private provider values, ordinary-user/Admin separation and anonymous denial. A trusted Admin can read aggregate diagnostics. Missing and incorrect Edge sync secrets both return HTTP 403. Daily retention is active. The purchase function fingerprint remains unchanged. No purchase, recharge, wallet mutation or new money capability was enabled by this release.

Live acceptance found two gaps in local fixtures: the old bounds formula omitted minimum fees, and the VM had Vault-only Access credentials. The forward compatibility migration fixes bounds; the catalogue worker reads Vault first and refuses fallback after a lookup error or invalid replacement. Explicit Vault absence alone permits environment fallback. Credential values are never returned in release evidence.

Validation: 25 backend tests and six isolated PostgreSQL scenario groups pass, along with 12 legacy supplier-visibility checks, 13 baseline checks, 55 customer tests, four existing Admin checks, Dart analysis, Edge type checks and Node syntax checks. The running worker completed its cycle and remained on the same PID after verification.

Scoped sources are synchronized on `codex/esim02-runtime-20261028` in the customer/database and backend repositories. The backend branch's worker deliberately excludes unrelated pending fleet telemetry. The Edge source deliberately excludes the unrelated pending Zendit credential-helper cutover. Local dirty workspaces are preserved.

VM backups contain source files only at `/home/abdal/keepsims_backend/servers/.release-backups/esim02-20261028-catalogue`. Rollback retains the additive schema and order snapshots. A pre-enrichment eSIM Access writer is rejected by the database guard; do not restore it as an active writer. Pause catalogue refresh or deploy another compatible writer while investigating. Do not touch wallet settlement or order history during rollback.

Profile identity, activation mapping, fabricated issuance/expiry fallbacks and ambiguous-error refund handling remain gated by ESIM-03/04/08. This catalogue release does not certify money-changing fulfillment.
