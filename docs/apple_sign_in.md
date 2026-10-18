# Apple sign-in setup and verification

Status checked on 16 October 2026, Asia/Muscat.

## Implemented locally

- The customer iPhone app's Apple button opens native authorization, then
  exchanges the ID token with Supabase. Each attempt uses a fresh raw nonce;
  Apple receives its SHA-256 hash and Supabase verifies the original nonce.
- Cancellation quietly restores the login screen. Both social buttons are
  disabled while signing in, and the Apple button shows progress.
- Apple provides a name only at first authorization. The repository saves it
  in Auth metadata and fills an empty `profiles.full_name`, without replacing
  a name the user already edited. A pending name is retained in Keychain,
  keyed to the Apple account, if exchange or persistence fails. It is retried
  on that account's next Apple login and deleted once saved. Tokens and nonces
  are never included in this pending record. A name-save failure does not
  invalidate an otherwise successful session.
- The controller waits until the name-save attempt and profile fetch finish
  before responding to the SDK's `signedIn` event. A previous account's cached
  profile is cleared after successful authentication.
- Native Apple login is currently offered on iOS only. Android/web/macOS are
  not wired to an unconfigured OAuth flow.
- Proposed iOS bundle ID: `com.keepsims.app`, including Debug, Profile,
  Release, and corresponding RunnerTests identifiers. Apple availability
  has **not** been confirmed or reserved.
- `ios/Runner/AppleSignIn.entitlements` is referenced in all Runner build
  configurations. A separate file avoids activating the pre-existing,
  unconfigured widget App Group in `Runner.entitlements`.
- Dependencies: `sign_in_with_apple` 8.2.0 and `crypto` 3.0.7, with lockfile.
  The admin app and database schema are unchanged.

## Account and dashboard findings

| Surface | Observed state | Remaining action |
| --- | --- | --- |
| Apple Developer | Account offers enrollment; enrollment opens at the entity-type choice | Complete individual/company enrollment, verification, agreements and payment |
| Xcode Apple Accounts | Existing Apple account is visible, with only a Personal Team | Use the paid program team after enrollment; obtain its Team ID |
| Apple App ID | No App ID registered or checked for availability in this task | Register `com.keepsims.app` if available; enable Sign in with Apple; refresh provisioning |
| Google Cloud `keepsims-console` | Existing iOS OAuth client has bundle ID `com.keep_sims` and an empty Team ID | Prepared an **unsaved** change to `com.keepsims.app`; retain the same OAuth client ID and URL scheme |
| Supabase `zwxswagokhgbuzrrbnhr` | Apple provider is disabled; Client IDs and OAuth secret are empty | Prepared an **unsaved** enabled/native-only configuration with Client ID `com.keepsims.app`, empty OAuth secret, and the existing email requirement preserved |
| Firebase `keepsimsfcm` | Only the Android `com.keep_sims` app is registered | Register iOS separately if enabling Firebase/push/App Check on iPhone; no registration was created here |

The Google and Supabase browser forms were staged for review, but their Save
buttons were not pressed. The user explicitly deferred the remaining live
setup until after paid Apple Developer registration on 16 October 2026.
Do not apply those settings as part of saving/resuming the handoff. Browser
form state may expire; the screenshots preserve the proposed values. When
the user asks to resume the live setup, check the final registered bundle ID
and the current provider settings before saving. If the proposed bundle ID
changes during Apple registration, update all three configurations together.

The live database was inspected read-only: `handle_new_user()` creates the
profile on insertion, but no auth-user update trigger synchronizes later name
metadata. The authenticated role can update `profiles.full_name`; the existing
UPDATE policy restricts writes to the user's own unsuspended account. The
client sends only that display-name column, never roles or entitlements.

## Verification

- Authentication analysis: clean; all 43 authentication tests pass.
- Focused authentication tests cover token exchange, fresh/hash-matched nonce,
  cancellation, missing tokens, returning users without name/email, preserving
  an edited profile name, failed exchange/name-save recovery, account-cache
  isolation, safe error messages, controller event ordering, duplicate attempts,
  and iOS/Android button behavior.
- The iOS simulator debug build succeeds as `com.keepsims.app`. This is an
  unsigned build check, not a signed device or Apple-server login test.
- Full-project analysis still has pre-existing findings outside auth,
  including a non-returning test fake in
  `docs/reviews/voip_quality_followup_repros_test.dart`.
- Full suite: 796 pass, 20 failures/errors outside authentication. Details are recorded in
  `output/apple-sign-in/full-test-summary.json`; test and build evidence is
  under `output/apple-sign-in/`.

## After membership is active

1. Confirm/register the final App ID and enable Sign in with Apple on Apple's
   developer portal. Set Xcode's paid Team ID for Runner and provisioning.
2. Save the reviewed Google/Supabase settings for the same final bundle ID.
3. Build and run on a provisioned iPhone. Test first authorization with name,
   returning authorization without name, Hide My Email, cancellation, and
   sign-out/sign-in. Confirm both Auth metadata and the profile display name.
4. Configure Apple's private email relay if sending account emails to relay
   addresses. Firebase iOS/push registration is a separate platform setup step.

Native ID-token authentication does not require a Services ID or `.p8` OAuth
secret. Android/web Apple login requires additional OAuth configuration and
secret rotation, and is outside this implementation.

References: [Supabase Apple authentication](https://supabase.com/docs/guides/auth/social-login/auth-apple),
[native Flutter plugin setup](https://pub.dev/packages/sign_in_with_apple),
[Apple enrollment](https://developer.apple.com/help/account/membership/program-enrollment/).
