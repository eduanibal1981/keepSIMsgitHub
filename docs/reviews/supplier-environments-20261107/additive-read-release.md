# Additive supplier read release for approval

7 November 2026 · Asia/Muscat. Target: existing hosted project `zwxswagokhgbuzrrbnhr`.
Status: explicitly approved and applied on 7 November 2026. All three source digests match the approved manifest; remote migration-history versions are recorded in the receipt.

The scope is exactly these three local migrations, applied individually in this order:

1. `20261107011332_carrier_offer_counts_batched.sql` — SHA-256 `b96a0987c37028d0d6412da93b4ac336f5b4b8641b570f35583f6fc307c3e6a8`.
2. `20261107011530_airtime_supplier_environment_catalogues.sql` — SHA-256 `47d8b29c6b39f6319e565f2e27d9500f66c42546ecafb443c59e10af270e8291`.
3. `20261107024421_carrier_country_counts_batched.sql` — SHA-256 `5e08d8f64973ed475b332ab82f2591d74bcc3dd513c13f1dc74e5ebc12fee58b`.

The first replaces only Admin's repeated count computation with a set-based query and private pure helpers. The second adds private per-environment read-only catalogue snapshots/jobs and guarded catalogue RPCs; it seeds only independently versioned DT One preview data. The third gives customer country/carrier counts the same batched computation and unchanged result fields. All checkout, wallet, hold, entitlement, credential activation, tester and execution-policy migrations are excluded from this approval scope. No VM process restart, new feature flag, supplier API submission or app distribution is included.

Current authenticated HTTP baseline (serial requests using an already valid Admin session, no login/token refresh): Admin inventory 10/10 HTTP500 database statement timeouts; customer UAE 19/20 successes, one timeout, successful-request p95 9.214s. The p95 goal is <2s Admin and <1.5s customer, with zero timeouts. Samples and error codes are in `http-baseline.json`; tokens, identities and payloads are excluded.

Before application, inspect migration history and ensure none of the three names are installed, verify the two current RPC return signatures/owners/ACLs and all referenced schemas/dependencies, and compare the source digests against `read-release-manifest.json`. Apply the reviewed SQL with the migration tool, never bulk-push pending migrations. Read back each body fingerprint and grants. Verify the new private tables have RLS and no anon/authenticated/service table grants. Leave `AIRTIME_ENVIRONMENT_CATALOGUES_ENABLED` and `AIRTIME_ENVIRONMENT_EXECUTION_ENABLED` disabled on the VM.

After application, repeat the same authenticated HTTP sample sizes and country/carrier parity checks, including Etisalat UAE and Vodafone Egypt. Record timing success/failure separately from SQL execution timing; failed requests do not establish a latency pass. The catalogue contract alone cannot prove worker adoption or supplier validity.

Rollback is a reviewed forward replacement of the prior count RPC definitions, retained in private inspection evidence. Keep additive catalogue data; pause refresh requests if needed. No financial or historical-balance recovery is part of this release.

A fresh read-only SQL comparison on 7 November matched all 105 hosted carrier rows in both directions (zero differences, including diagnostics). The batched expression used inline equivalents of the two new pure helpers; it did not install any schema. Total comparison wall time 22.3s includes the existing slow RPC.

After deployment: Admin authenticated inventory 10/10 succeeded, p95 1.0359s; UAE customer reads 20/20 succeeded, p95 1.4109s. Zero timeouts in either sample. Both stated p95 goals pass for this run. Nine financial function definitions/owners/grants remain byte-equivalent by fingerprint; execution gates and the worker runtime remain unchanged.

Scoped post-deploy advisor review found the informational “RLS Enabled No Policy” notice for the two new private tables. Their deny-all API behavior is intentional: RLS is enabled, direct API-role privileges are absent, and the guarded definer RPCs provide the only access. No permissive policy was added. [Supabase linter explanation](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy). This scoped review does not certify unrelated pre-existing project advisories.

The deployed read release preserves the legacy catalogue classification for parity. Existing Zendit records labelled Production are not proof of live credentials or account mode. The new verified-Live purchase guard and isolated-Test execution contracts remain local and undeployed; this PR is not a financial-execution release.
