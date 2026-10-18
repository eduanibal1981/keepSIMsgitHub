# macOS admin Google sign-in fix

Date: 2026-10-17

## Reported failure

The locally built admin app failed immediately with a Google Sign-In exception
about a missing reversed-client-ID URL scheme. The repository used the web OAuth
client ID for every native platform except iOS, including macOS. The Mac target
had neither the native Google callback configuration nor the signing/keychain
setup required by that SDK. Adding the reported web client's scheme alone would
not provide a correctly configured native Mac Google client.

## Change

- On macOS, `AuthRepository.signInWithGoogle` now uses Supabase browser OAuth
  through Apple's `ASWebAuthenticationSession`, with the existing PKCE client.
- `MacosGoogleSignIn` obtains the authorization URL, requires an S256 challenge,
  validates the exact callback, rejects provider errors or malformed codes,
  and exchanges the code using the SDK's stored verifier. Supabase emits its
  normal signed-in event and the existing profile/router flow opens the app.
- `MainFlutterWindow` hosts the authentication method channel and retains the
  system session, handles cancellation, and rejects overlapping sessions.
- The existing allowed callback is `io.supabase.keepsims://login-callback/`.
  The system authentication session receives the callback directly; the Mac
  app does not register the customer app's scheme with Launch Services.
- Native mobile and web sign-in selection remain as before. Profile fetches
  within authentication try blocks are awaited so their errors stay in scope.

No OAuth client secret, service-role credential, new dependency, Supabase
configuration update, backend deployment, or provider rotation was required.

## Verification

- All 28 admin tests passed, including 14 new authentication checks for PKCE
  exchange/session creation, unsuccessful callbacks, cancellation/retry, and
  refusal of implicit-token authentication.
- Focused Dart analysis of the authentication changes: no issues.
- The Google button was exercised in the rebuilt release app. Browser
  authentication returned successfully and the app displayed the authenticated
  admin area (`Connect to VPS`), replacing the reported exception.
- Live unauthenticated cancellation probes confirmed Supabase accepts the
  existing callback. A proposed admin-specific scheme was not allowlisted and
  was not used. These probes did not create an authenticated session or change
  any project configuration.
- Build/package: `../keep_sims_admin/tools/build_macos_local.sh`.
  The app remains locally signed; Developer ID signing/notarization are separate
  distribution work.

## Updated artifacts

- App: `../keep_sims_admin/build/macos/Build/Products/Release/keep_sims_admin.app`
- ZIP: `../keep_sims_admin/build/macos/KeepSIMs-Admin-macOS.zip`
- Integrity: `../keep_sims_admin/build/macos/KeepSIMs-Admin-macOS.zip.sha256`

Quit an older running copy before opening this build. A copy previously
extracted or moved into Applications does not update when the ZIP is rebuilt.

References: [Apple web authentication sessions](https://developer.apple.com/documentation/authenticationservices/authenticating-a-user-through-a-web-service),
[Supabase Flutter OAuth](https://supabase.com/docs/reference/dart/auth-signinwithoauth),
[Google native Apple-platform setup](https://developers.google.com/identity/sign-in/ios/start-integrating).
