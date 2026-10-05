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
