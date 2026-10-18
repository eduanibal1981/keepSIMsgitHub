# Credential-management backend release

Date: 2026-10-17 (Asia/Muscat)

Status: **deployed and verified in the running Mac admin app**.

The user explicitly approved “Deploy credential-management backend” after review
of the scoped release. Supabase recorded migration `admin_provider_credentials`
as version `20261016205533` (2026-10-16 UTC / 2026-10-17 Asia/Muscat).
The original pending SQL file was renamed from
`20261016070000_admin_provider_credentials.sql` to the matching applied filename
`20261016205533_admin_provider_credentials.sql`; its SQL contents were unchanged.

## Confirmed diagnosis

The macOS Credentials screen reported that credential management was not deployed.
Read-only MCP inspection of project `zwxswagokhgbuzrrbnhr` confirmed that
`public.provider_credential_registry` and `public.admin_list_provider_credentials()`
were absent and no credential migration was recorded. The app's controlled error
was correct; rebuilding it could not create these missing database objects.

## Exact release

Applied only `supabase/migrations/20261016205533_admin_provider_credentials.sql`
through the targeted Supabase migration API. Do not perform an unfiltered
migration push: unrelated financial migrations and archived history are present.

The migration creates a private 13-name credential metadata registry and three
admin APIs: list metadata, store a write-only replacement, and attest completion
for the exact version. It also restricts the existing generic Vault writer so
it cannot bypass version tracking for managed names. Existing WhatsApp-specific
secret names remain compatible.

The release seeds no credential values, performs no rotations/revocations,
changes no Edge or VM runtime, removes no plaintext configuration, and makes no
provider or payment request. It does enable authorized admins to store future
replacements; storing one is not proof that running consumers use it.

## Preflight evidence

- `assert_admin()` exists and checks an authenticated identity, the trusted
  power-user claim, and suspension status. Its service-role bypass is not
  exposed by the proposed credential API grants.
- `admin_log(text,text,text,jsonb,jsonb,text)` exists and is callable by the
  migration/function owner, `postgres`. Its UUID return is compatible with
  the migration's `PERFORM` calls.
- Vault create/update functions exist, accept the supplied positional arguments
  through their defaults, and are executable by the function owner.
- `get_internal_secret(text)` is callable by service role and denied to both
  anonymous and authenticated API roles. This migration does not change it.
- No managed canonical Vault entries exist yet. Values were not retrieved.
- The one SQL caller of the generic Vault writer is the WhatsApp profile API;
  its names use per-profile `wa_*` prefixes outside the managed allowlist.
- Current isolated credential SQL suite: **30 passed**. It covers permissions,
  sanitized responses, versions, rollback and legacy compatibility; external
  infrastructure and Vault encryption are substituted in that fixture.
- Security advisor baseline collected. Existing unrelated findings are not
  evidence of this release and must not be silently changed here.

## Post-release verification

1. Migration history confirms the one applied version. The registry has 13
   metadata entries, zero recorded replacements, and zero canonical Vault entries.
2. RLS is enabled and direct registry access is revoked from all API roles.
   All four affected functions pin the empty search path and allow authenticated
   invocation only; authorization is checked in each function body.
3. Live transaction-scoped tests confirmed anonymous invocation is denied by
   permissions and ordinary authenticated invocation is rejected with `KS460`
   for list, replacement and completion. The tests used an unsupported name and
   rolled back; they created no Vault entries, records or provider requests.
4. The real signed-in admin session successfully listed metadata after pressing
   **Try again** in the running Mac app. Credential cards and store controls now
   replace the not-deployed error. No dummy or actual provider values were entered.
5. Security advisor delta: anonymous-executable definer functions decreased
   40 → 39; authenticated definer functions increased 190 → 193 for the three
   intended admin APIs. The new private registry adds one informational
   RLS-without-policy finding (40 → 41). Direct API-role table access is revoked;
   the admin functions are the intended authorized access path. Other advisor
   counts are unchanged. [Advisor explanations](https://supabase.com/docs/guides/database/database-linter).

The project-scoped MCP identity is read-only and could not switch database roles.
The live role-denial tests were therefore run successfully through the connected
Supabase plugin using transaction-local roles and claims. No grant was broadened
to accommodate testing.

Matching Edge/VM releases, provisioning of real Vault values, provider recovery
checks and old-key revocation remain separate work. “Missing from Vault” is the
verified current storage state, not evidence that existing runtime environment
credentials are absent or that a rotation has occurred.

Approval was obtained as required by `.codex/AI_AGENT_GUIDE.md`. The authorized
scope was deployment of credential management, not rotation of provider keys.
