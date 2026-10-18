# Admin credentials and macOS completion review

Date: 2026-10-16 (Asia/Muscat).

**2026-10-17 update:** the targeted credential-control database migration is now
deployed and the Mac Credentials page loads. The local SQL filename matches the
applied remote version `20261016205533`. Matching Edge/VM releases and actual
provider rotation remain pending. See the [database release record](credential-backend-release-20261017.md).

Status at this original review: **local implementation complete; backend release and actual provider rotation were pending**. The user requested completion of the interrupted Task 2 implementation and a Mac admin build. No production migration, credential replacement/revocation, supplier operation, VM change or process restart was performed during that original review.

## Confirmed previous work

The prior agent had implemented the credential registry, admin-only Vault replacement/list APIs, a masked admin screen, removal of the reported embedded source fallbacks, server-issued relay credentials, isolated SQL tests, and macOS platform settings. Its focused backend/scanner/admin tests were reproducible. The initial Mac bundle was universal and locally signed. The live project still has no provider credential registry/rotation API, so those local changes were not deployed.

## Work finished in this continuation

- Extended Vault credential resolution to the remaining local PayPal, Telnyx, Twilio and Zendit Edge consumers. Replacements take precedence over stale environment values on each request/token acquisition. A Vault error fails safely instead of silently restoring an obsolete key. No provider access token is cached across replacement versions.
- Kept the legacy lower-case Zendit Vault alias as a migration fallback only when the canonical entry is absent. Protected both it and the known environment aliases from the legacy generic admin writer bypassing managed versions.
- Added the complete admin rotation record: store a masked replacement, review affected consumers, complete external checks, then record an operator confirmation for that exact version. The three acknowledgments cover consumer synchronization, recovery/provider authentication checks, and old-key revocation. The server locks the row, rejects stale versions and audits the operator. Repeated confirmation is idempotent; another replacement automatically returns the record to pending.
- Added a local UI access gate for ordinary sessions, in addition to the authoritative server authorization. Metadata reads and edits remain unavailable to those sessions.
- Added minimum length validation for new relay signing secrets, cleared sensitive fields, kept fixed error messages and preserved write-only server responses.
- Removed raw PayPal authentication/Zendit offer error-body reflection in the touched token/offer paths.
- Fixed a pre-existing missing closing brace in the eSIM Go section of `sync-esim-catalogue`. It previously made the local module fail TypeScript parsing. A focused test verifies that a targeted Zendit sync works independently of eSIM Go and uses the canonical Vault value.
- Added credential-consumer regressions to the secret-scan workflow and documented the SQL fixture command.
- Rebuilt and packaged the Mac app. The final check exposed an incremental Flutter build leaving the outer app signature stale after `App.framework` changed. Added `../keep_sims_admin/tools/build_macos_local.sh`, which builds, seals the outer app with the release entitlements, verifies embedded code and packages the result. It does not re-sign broken nested code or weaken signing checks.

The backend mutation stores a provider-issued replacement; it does not issue a provider key itself. `operator_confirmed` is a human attestation, not an automatic provider probe or proof that the provider revoked a key. Management PATs, service-role authority and VM private keys are not added to Flutter.

## Where to find the result

- Mac app: `../keep_sims_admin/build/macos/Build/Products/Release/keep_sims_admin.app`
- Packaged app: `../keep_sims_admin/build/macos/KeepSIMs-Admin-macOS.zip`
- Archive integrity file: `../keep_sims_admin/build/macos/KeepSIMs-Admin-macOS.zip.sha256`
- Admin feature: `../keep_sims_admin/lib/features/credentials/`
- Backend migration: `supabase/migrations/20261016205533_admin_provider_credentials.sql`
- Server resolver: `supabase/functions/_shared/provider-secrets.ts`
- Rotation inventory and operational procedure: [credential rotation runbook](credential-rotation-20261016.md)

Open **Credentials** in the admin navigation after signing in with an authorized power-user session. The originally reported not-yet-deployed state was resolved by the targeted 2026-10-17 database release.

## Verification

| Check | Result |
| --- | --- |
| Complete admin Flutter test suite | 14 passed |
| Analysis of changed admin feature/integration/test files | No issues |
| Customer relay credential tests and focused client analysis | 4 passed; no analysis issues |
| Actual Edge modules with isolated DB/provider adapters, including refund regressions | 47 passed |
| Complete credential migration in an isolated PGlite fixture | 30 passed |
| Redacted secret scanner regression suite | 10 passed |
| Active-source scan across customer, admin and authoritative worker repositories | Zero active findings; one archived SQL exposure remains inventoried |
| Shared credential/relay helper TypeScript type checks | Passed |
| TypeScript syntax/transformation of changed Edge modules and new credential helpers | 23 modules, zero errors |
| Mac release build | Passed |
| All four bundled Mach-O binaries | Both arm64 and x86_64; minimum macOS 12.0 |
| Deep, strict bundle signature verification | Passed after final packaging step |
| Release entitlements | App sandbox and outbound network enabled; debugger entitlement absent |
| Native startup | Sign-in screen visibly rendered |
| Fresh Mac bundle comparison with four known historical embedded strings | Zero exact matches; values were not printed |
| ZIP integrity check | Passed |

The SQL fixture substitutes Vault encryption, JWT verification and the audit dependency. It exercises real migration logic, roles, restrictive grants, validation, versions, rollback, completion and legacy compatibility. It is not a provider test or a production deployment. Consumer tests intercept all fetches; they make no actual payment, call, SMS, supplier or webhook request. The source scanner is a focused regression tool; historical copies and unknown/obfuscated secret formats remain outside its guarantee.

Broad customer tests and unrelated audit repairs were not rerun or claimed complete.

### Reproduce local verification

From the customer repository:

```sh
node --test test/provider_secrets.test.cjs test/turn_credentials_security.test.cjs test/credential_rotation_consumers.test.cjs test/wallet_refund_backend.test.cjs
npm ci --prefix tools/financial-tests
npm run test:credentials --prefix tools/financial-tests
python3 -m unittest discover -s tools -p 'test_scan_embedded_secrets.py' -v
python3 tools/scan_embedded_secrets.py
flutter test test/features/voip_calling/turn_credentials_test.dart
```

The credential SQL suite also accepts `PGLITE_MODULE_PATH` for an existing pinned dependency installation, as documented in [the test tooling](../../tools/financial-tests/README.md). No paid branch is needed.

From the admin repository:

```sh
dart run build_runner build
flutter test
dart analyze lib/features/credentials test/features/credentials lib/core/providers.dart lib/core/router/app_router.dart lib/core/layout/admin_shell_screen.dart lib/core/supabase_client.dart lib/features/sim_lines/data/datasources/twilio_verification_service.dart lib/features/sim_lines/presentation/controllers/line_verification_controller.dart test/widget_test.dart
./tools/build_macos_local.sh
```

The app uses an **ad hoc local signature**. Developer ID signing/notarization for broader distribution remain separate account-dependent steps.

## Exact backend release boundary

1. Release only the reviewed credential migration after checking its live dependencies (`assert_admin`, `admin_log`, Vault, and service-only `get_internal_secret`). It creates no provider values and must not be confused with the pending financial migration series.
2. Before switching a consumer to Vault, provision its correct environment/account credentials in the protected store. The migrated secret reads intentionally stop using plaintext `system_configs` values. Do not remove those legacy rows while any deployed reader still depends on them.
3. Release the matching credential helper with these local consumers, using a source/version manifest and the provider-specific maintenance rules in the runbook:

   - Telnyx: `liveness-verification`, `liveness-verification-webhook`, `validate-sim-liveness`, `send-sim-otp`, `verify-sim-otp`, `make-call`, `manage-caller-id`, `manage-dids`, `telnyx-cdr`, `admin-telnyx-billing`.
   - Twilio token consumers: the two liveness handlers, `sms-webhook`, `twilio-voice-webhook`; separately synchronize any linked WhatsApp profile using the same provider account.
   - PayPal: `create-paypal-order`, `capture-paypal-order`, `paypal-webhook`; coordinate the refund consumer as described below.
   - Zendit: `validate-sim-liveness`, `fetch_zendit_offers`, `sync-esim-catalogue`.
   - Relay: `get-turn-credentials`, `initiate-voip-call`, and the rebuilt customer relay contract.
   - Firsty: `recovery-service` remains a deferred sandbox feature and must stay undeployed/disabled.

4. **Do not deploy the pending local `process-wallet-refund` merely for this credential release.** It already contains the separate financial rewrite and requires the coordinated wallet migration release. Until that compatible release, its current deployed version still needs a protected environment update when PayPal credentials change. Do not claim the PayPal rotation complete while an older refund processor/tool consumer uses the previous credential.
5. Synchronize VM worker environments and Coturn through their protected operational release. A Vault write does not update those running processes. Keep the version pending until those consumers are verified and the old credential is revoked. API token and webhook signing-key rotation are distinct operations.
6. Deploy the matching admin app and test actual power-user success, ordinary-user denial, version conflict, sanitized error handling and no credential read-back. Provider/relay verification and actual revocation require their scoped operational authorization; they were not performed here.
7. Record completion only after the actual external work. Preserve the exposure inventory and complete historical/build-copy disposition after revocation. Do not restore a known exposed credential as a rollback shortcut.

Known audit issues such as the PayPal capture-identity bug, liveness callback signature/ownership repairs, Telnyx fail-open verification, call-budget mismatches and financial constraint repairs remain their own executor tasks. This credential work does not certify those paths as production-ready.

The storage design and private decrypted view boundary were checked against [Supabase Vault documentation](https://supabase.com/docs/guides/database/vault). Only trusted backend consumers may read decrypted values.
