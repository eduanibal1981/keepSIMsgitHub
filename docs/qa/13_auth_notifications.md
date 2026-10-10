# 13 — Auth and Notifications

## Login
### TC-AUTH-001: Validate email/password and social login entry points
- **Preconditions**: A test account exists; Google sign-in is available or canceled.
- **Expected**: Valid credentials open the authenticated app; invalid credentials and social-login cancellation show safe errors.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Auth repository and login screen were inspected; no live account login was performed.

## Email authentication
### TC-AUTH-002: Complete email OTP or password sign-in and resend cooldown
- **Preconditions**: A test mailbox can receive OTP and the account is eligible for sign-in.
- **Expected**: Valid OTP/password authenticates; expired/invalid token is rejected; resend obeys its cooldown.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Email-auth screen/controller tests were not executed.

## Onboarding auth redirect
### TC-AUTH-003: Route signed-out and incomplete accounts correctly
- **Preconditions**: Session states include signed out, onboarding incomplete, and fully onboarded.
- **Expected**: Router sends each state to the correct entry route and preserves permitted deep links.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Auth redirects are configured in app_router.dart; no route widget test completed.

## Password recovery
### TC-AUTH-008: Reset a password with an emailed recovery code
- **Preconditions**: Reset password email uses `supabase/templates/recovery.html`; a dedicated test mailbox/account is available for the live delivery check.
- **Expected**: Forgot password pre-fills the sign-in email; invalid emails/codes are rejected; resend waits 60 seconds; password confirmation is required; OTP verification keeps the user on recovery; completion returns to sign-in. Recovery tokens are never persisted as the app session.
- **Status**: AUTOMATED VERIFIED — LIVE EMAIL UNVERIFIED
- **Notes/Found Issues**: 11 Auth REST repository tests and 7 Flutter screen/router tests passed. Analysis found no errors and only the existing deprecated `anonKey` notice. Hosted template activation and a real mailbox reset remain unverified; see `docs/password_recovery.md`.

## Notification center
### TC-AUTH-004: Mark alerts read, mark all read, and delete an alert
- **Preconditions**: User has multiple read and unread notifications.
- **Expected**: Read state persists; mark-all affects only the current user’s alerts; delete removes only the selected alert.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Notification navigation/controller tests exist but Flutter execution stalled.

## Alert preferences and channel setup
### TC-AUTH-005: Configure push, email, SMS, WhatsApp, and Telegram destinations
- **Preconditions**: User can access alert settings and each provider is available or disabled.
- **Expected**: Category/channel choices persist; email verification and Telegram binding are verified; unavailable channels are explained.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Settings screen and provider tests were inspected. Live email, SMS, WhatsApp, and Telegram messages were not sent.

## Contextual device permissions
### TC-AUTH-009: Choose device access during setup or later
- **Preconditions**: A new or existing account can open setup, push settings, and supported device alarm settings.
- **Expected**: App startup and opening settings never prompt. Setup can continue without access. Notification permission is requested only by Enable or enabling push/alarm delivery; denial stays off without automatically opening system settings. An explicit settings action handles blocked access. Returning to the app refreshes access, including revocation. Microphone remains a first-call request; contacts and phone access are not added. Exact-alarm settings open only after alarm opt-in.
- **Status**: AUTOMATED VERIFIED - NATIVE DEVICE UNVERIFIED
- **Notes/Found Issues**: The focused Flutter suite passed 45/45 checks on 2026-10-10. Permission service/controller tests cover Android/iOS status mapping, request arguments, denial, settings failure, and request deduplication. Onboarding widget tests cover skip/continue, push preference gating, resume during a request, retry, alarm opt-in, and both themes with enlarged text. Push Settings has a later-enable check. Native OS dialogs and end-to-end push/alarm delivery still require real-device checks.

## Notification delivery contracts
### TC-AUTH-006: Route and acknowledge notifications with provider test doubles
- **Preconditions**: Dispatcher fixtures include enabled destinations, disabled channels, and retryable provider responses.
- **Expected**: Only eligible destinations are attempted; retries preserve idempotency; receipts and unknown outcomes are not falsely reported as delivered.
- **Status**: VERIFIED
- **Notes/Found Issues**: Six notification Node suites passed 40/40 tests: production contracts, push delivery, quiet hours, SMS auth, WhatsApp inbound commands, and WhatsApp receipt sync. Providers were mocked.

## Push-tap navigation
### TC-AUTH-007: Open the intended screen from a push or in-app notification
- **Preconditions**: A test notification includes a supported route and entity identifier.
- **Expected**: Tap opens the intended owned entity; malformed or foreign identifiers fall back safely.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Notification navigation tests exist but Flutter execution stalled.
