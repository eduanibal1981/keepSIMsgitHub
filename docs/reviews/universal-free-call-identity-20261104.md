# Universal Free Call identity — implementation and verification

4 November 2026, Asia/Muscat. Customer workspace: `keep_sims`.

[Verification receipt and deployment hashes](universal-free-call-identity-20261104/verification.json).

## Scope and existing-versus-missing audit

Inspection covered the project handoff, memory router, architecture/security
rules, Flutter Free Call/Recent/People/review/controller/repository/signaling,
the actual hosted Auth/profile/caller-ID/session schemas, policies, triggers,
and deployed calling functions. The plan's project reference was truncated;
the verified project is `zwxswagokhgbuzrrbnhr` (`simSaveDB`).

| Feature | Before | After | Verification |
|---|---|---|---|
| Permanent ID | No public calling alias | One cryptographically generated immutable alias per Auth UID; unique ledger, bounded collision retries, deletion tombstones, server provisioning and lazy recovery | Native PostgreSQL generation/collision/concurrency tests; all 9 hosted users backfilled; format and body checks |
| Phone discovery | Exact legacy RPC considered Auth phones, verified caller IDs and DIDs; managed claims could suppress a match; no discovery consent | Only confirmed Auth phones or timestamped, server-verified caller IDs; explicit per-number consent bound to current proof; conflicting owners fail closed; managed SIMs/test passes/DIDs excluded | Positive native tests; live conflict rejection; live positive blocked by existing test data |
| Email discovery | Missing | Exact verified Auth email with explicit consent; case normalization only, no provider-specific rewriting; changing email invalidates the previous consent | Native tests and hosted positive check with temporary consent rolled back |
| Recent filtering | Real grouped history, no text filtering | Local partial filtering of recorded names/phones/public IDs/permitted historical emails; Arabic digits supported; existing canonical peer IDs reused | Flutter tests; real emulator history preserved |
| Privacy/blocking | No Free Call discovery settings or blocks found | ID visibility, email opt-in, individual verified-phone opt-in, block/unblock UI; private tables, guarded RPCs, account and signed-session quotas; lifecycle checks | Native ACL/ownership/session/quota/block tests; hosted anonymous denial and advisor review |
| Backend | Existing Supabase RPCs and Edge/WebRTC signaling | Additive migration and existing `initiate-voip-call` hardened; UUID validation, call-insert eligibility guard, no profile phone disclosure | Hosted migration, 18/18 SQL body matches; Edge v11, 3/3 runtime file matches; HTTP negative probes |
| Calling | Canonical account IDs, review, microphone permission, existing push/Realtime/WebRTC | All identifier modes feed the same existing reviewed call path; no automatic call on search | Native session routing, Edge adapters, 69 Flutter cases; emulator confirmation; no real two-account media test |
| People | Accepted family members, individually selected device contact, managed-number section | Preserved; no address-book upload or background matching | Existing Flutter tests and emulator checks |

The Node worker repository is correctly `../backend-sync-wt`, origin
`eduanibal1981/keepsims-backend`, main at
`c18e2ac793f288165505990e9ecd26207fd99fe2`. This feature requires no worker
changes, VM deployment/restart, paid calls, wallet operations or supplier calls.
Unrelated dirty files in both repositories were preserved.

## Design decisions

- Internal identity remains `auth.users.id`. Public IDs are routing aliases,
  never credentials. The 31-character alphabet excludes `I`, `L`, `O`, `0`, `1`.
  PostgreSQL pgcrypto supplies secure bytes; rejection sampling avoids modulo
  bias. There are 12 bounded allocation attempts, a unique public ID and unique
  user constraint, and a per-user transaction lock for concurrent provisioning.
- There is no immutable registration-country attribute on existing profiles.
  `home_country_code` is editable and `last_country` is not registration
  provenance. Neither SIM country nor these fields is inferred. The trusted
  `auth.users.raw_app_meta_data.registration_country` is used when it contains
  an ISO alpha-2 country; otherwise issuance uses `XX`. All 9 current accounts
  use `KXX-…`. Country and issue time stay immutable. Current signup does not
  collect a country before Auth provisioning, so missing-country signups also
  receive the documented neutral prefix.
- The ledger retains an unlinked alias after account deletion, preventing reuse
  without retaining the deleted account UID. Phone consents, blocks and routing
  grants cascade away. Active deletion requests/suspension/bans prevent lookup.
- Verified phone proofs come from confirmed Auth phones and the existing
  Telnyx caller-ID ownership verification. Caller-ID verification fields are
  already protected by a deployed database trigger. SIM OTP/development passes,
  profile phones, managed SIMs and supplier DIDs do not authorize discovery.
  Per-number opt-in binds to source ID and verification timestamp. Unlinking,
  editing or reverifying the source invalidates its prior consent.
- Email consent is bound to the verified Auth email value. A new email requires
  new consent. No dots or plus tags are stripped. Email addresses and other
  registered numbers are never returned in results or push payloads.
- A successful lookup gives a private 15-minute routing grant, rather than a
  fabricated call/history row. Recent/accepted-household relationships retain
  their existing direct account review. The database insert trigger checks
  eligibility, blocks and call-attempt quotas even for service-role Edge writes.
- Quotas apply to the authenticated account (20 burst, 5/minute), signed Auth
  session (15 burst, 4/minute) and call attempts (8 burst, 2/minute). No arbitrary
  request header is trusted as the user's IP. No address book is uploaded.
- Private schema/table/function grants are revoked from clients and service
  role. Only the small authenticated public RPC surface is exposed, with safe
  search paths and fresh caller checks. Client mutation/TRUNCATE permissions on
  Free Call sessions are revoked; existing server offer/answer/end APIs remain.
- Recent history's legacy RPC signature stays compatible, but private editable
  profile phones are no longer disclosed. The new history RPC adds public IDs.
  Old records remain accessible; recorded identifiers, when present, can be
  filtered locally. Missing canonical peer IDs cannot trigger an arbitrary call.

## Meaningful files

- `supabase/migrations/20261104053008_universal_free_call_identity.sql`.
- `supabase/functions/initiate-voip-call/index.ts`, its existing dependency lock,
  and the scoped function configuration in `supabase/config.toml`. Existing
  `_shared/provider-secrets.ts` and `_shared/turn-credentials.ts` are reused.
- Flutter domain: `free_call_identity.dart`, `free_call_recipient.dart`,
  `free_call_history_group.dart`; session model: `voip_call_session_model.dart`.
- `voip_calling_repository.dart`, `free_call_identity_controller.dart`,
  `free_call_review_controller.dart`, `internet_calling_screen.dart`,
  `free_call_identity_card.dart`, `free_call_review_sheet.dart`.
- English/Arabic ARBs and regenerated localization outputs. Other supported
  locales receive the standard English fallback for the new strings.
- `test/features/voip_calling/free_call_identity_test.dart`, updated screen test,
  `test/free_call_identity_edge.test.cjs`, caller UUID in the existing TURN test,
  `supabase/tests/fixtures/free_call_identity.sql`,
  `tools/financial-tests/free-call-identity.mjs`.

## Commands and results

| Executed command/check | Result |
|---|---|
| `flutter gen-l10n` | Generated; existing untranslated-message notices remain |
| `dart format` on changed Dart files | Passed |
| `flutter analyze` | Clean full application analysis |
| `flutter test test/features/voip_calling --reporter expanded` | 69 passed, including 9 new identifier/search/privacy/layout cases |
| `node tools/financial-tests/free-call-identity.mjs` | 17 native PostgreSQL scenarios passed, using real pgcrypto and independent sessions |
| `node --test test/free_call_identity_edge.test.cjs test/turn_credentials_security.test.cjs` | 10 integrated-workspace passes; 14 committed-checkout passes, including four tests removed by pre-existing local edits |
| `npx --yes deno check --no-config --node-modules-dir=none --frozen supabase/functions/initiate-voip-call/index.ts` | Passed (Deno 2.9.6; no claim of the older release toolchain pin) |
| `flutter test --reporter expanded` | 1,479 passed, 2 failed; the alarm tests listed below also fail when rerun independently |
| `flutter build apk --debug` | Passed; installed on the available Android emulator, no publication |
| Supabase migration and source checks | Applied; all 9 IDs present, no malformed IDs; 18/18 function bodies match; no automatic phone/email opt-ins |
| Hosted RPC smoke | Authenticated success, anonymous denial, complete ID/email positives with consent rolled back, partial negatives, unchanged call count |
| Hosted Edge smoke | Unauthorized 401, self 400, nonexistent/blocked target same generic 403; relay configuration resolves before the target lookup |

The two full-suite failures are outside this change:

1. `test/features/sim_lines/sim_line_form_save_test.dart` —
   `add SIM: success with alarm`, `pumpAndSettle` timeout.
2. `test/features/profile/onboarding_notification_contacts_test.dart` —
   `alarm access is requested only after enabling alarms`, timeout.

Both reproduce in their own files. Their runtime/test files were not changed by
this task. The full suite is therefore **not** reported as passing.

An isolated committed checkout independently passes the same 69 Flutter cases,
17 native database scenarios, 14 Edge cases and focused analysis. Localizations
were regenerated from HEAD plus only the feature messages. Unrelated existing
localization/configuration/test edits were not bundled into the feature commits.
The native fixture includes its captured rate-limit dependency, and does not
require the workspace's untracked schema snapshot.

## Hosted deployment

- Migration source version: `20261104053008`. The MCP-assigned installed history
  version is `20261104054624`, name `universal_free_call_identity`. The source and
  hosted SQL bodies match; remote history was not rewritten or bulk replayed.
- `initiate-voip-call` is ACTIVE (version recorded in the receipt). Existing `verify_jwt=false` is retained;
  the handler verifies the bearer with Auth, and database session creation checks
  current account/block/routing eligibility. Retrieved index/shared runtime files
  match local source exactly. Retrieval omits the supplied lock, so hosted lock
  enforcement is not attested.
- The previously unconfigured `TURN_SHARED_SECRET` was provisioned securely from
  the **existing coturn server configuration**. No value is stored in this repo,
  receipts or command arguments. The VM configuration and processes were not
  changed. Supabase's configured secret replaces reliance on the legacy fallback.
- Security advisors were compared before/after. New informational no-policy
  findings are intentional private, grant-revoked tables. New authenticated
  SECURITY DEFINER notices correspond to the deliberately guarded API surface.
  No new feature-specific ERROR was introduced. Six pre-existing security-definer
  view errors and other unrelated notices remain; no broad advisor remediation
  was attempted. Guidance: https://supabase.com/docs/guides/database/database-linter.

## Emulator and remaining acceptance

Actual emulator: `Medium_Phone_API_37.0`, `emulator-5554`, Android 17/API 37.
The real updated app uses the existing authenticated account and hosted backend;
no account creation, fabricated history, real supplier operation or phone call
was needed. Free Call loads with its ID and real grouped history. Native Android
copy shows the correct ID in the clipboard preview; sharing opens the platform
sheet. Partial contact-name input filters real history locally. People retains
family/managed-number content. A complete other-account ID and an existing Recent
call both produce eligible confirmation with the canonical public ID and Free
Call button. Complete unknown email and phone identifiers produce the generic
no-match flow. The email result offers invitation sharing; the phone retains
the existing user-composed invitation options. No paid action was selected.
Further checks are in the receipt.

There is one live verified phone shared by four caller-ID records across
accounts, and **zero unambiguous verified phones**. The live positive phone
smoke correctly failed closed. No paid caller-ID records were deleted or
reassigned to force a pass. A uniquely ownership-verified test number is required
for positive hosted/emulator phone acceptance. The positive path is covered by
native service tests. Email discovery remains off on hosted accounts; its live
positive test used a rolled-back consent transaction.

No real two-account incoming push/audio/media delivery was verified. Only one
authenticated emulator is used. Database routing and Edge push targeting are
tested separately. The existing relay credential was reused, not rotated;
historical deployed/source fallback material still warrants coordinated relay
credential rotation across calling consumers as separate release maintenance.
Existing broader Android release, signing and performance acceptance gates from
the handoff remain in effect.

## User experience

Open **Calls → Free Call**. The compact **My KeepSIMs ID** row offers Copy and
Share. Enter a complete ID, full international number or verified email and tap
Search. Review the account, then deliberately tap **Call free**. Phone/email
recipients must first enable their chosen verified identity under Free Call
privacy. Partial names or identifiers filter **Recent** locally. People retains
family contacts and individual contact selection. The confirmation sheet offers
blocking; Free Call privacy offers unblock controls.

## Source synchronization

The feature source is committed separately from the pre-existing dirty work.
The accompanying receipt records runtime source commit
`a73457af23eaaf3d0157762ecb999419d8257f07`, remote branch
`feat/universal-free-call-identity-20261104`, and deployed hashes.
The customer app's existing `main` origin is
`eduanibal1981/keepSIMsgitHub`; no backend-worker commit is needed.
