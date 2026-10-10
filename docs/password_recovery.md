# Password recovery with an email code

The customer app has a **Forgot password?** link below the password field on
email sign-in (`EmailAuthScreen`). The flow requests an email code, verifies it,
accepts a new password and matching confirmation, and returns the user to sign-in.

The app accepts 6–8 digit codes and requires at least 8 password characters.
Supabase still enforces the project's password policy, OTP expiration, and
request limits. Resend is disabled for 60 seconds after a successful send.
Unknown emails receive the same neutral confirmation as existing accounts.

---

## 1. Supabase Hosted Setup (Mandatory)

The app verifies recovery codes via the GoTrue REST API (`type: recovery`) and
expects a numeric OTP code (`{{ .Token }}`). It does not consume action links.

### Step 1: Update Email Template in Supabase Dashboard
1. Open the project's Authentication email templates:
   **[Supabase Email Templates](https://supabase.com/dashboard/project/zwxswagokhgbuzrrbnhr/auth/templates)**
2. Select **Reset password**.
3. Set the email subject:
   ```text
   Your KeepSIMs password reset code
   ```
4. Copy the complete HTML from `supabase/templates/recovery.html` into the template editor and save.
   - The template displays `{{ .Token }}` inside a styled code container.
   - Includes 60-minute expiry and security notices.
   - Branded with SIM Shield / KeepSIMs styling.

### Step 2: Verify Auth Settings
In **Authentication -> Providers -> Email** / **Auth Settings**:
- **Email OTP Expiration:** Default is 3600 seconds (1 hour). Ensure it is at least 3600 seconds.
- **Rate Limit:** Supabase enforces rate limits (e.g. 1 email per 60s per user). The app's 60-second cooldown UI matches this limit.
- **Custom SMTP:** If your project uses custom SMTP (e.g., SendGrid, Resend, Amazon SES), verify the sender domain is verified and sending properly.

> [!NOTE]
> `supabase/config.toml` includes the recovery template for local development.
> Do NOT run `supabase db push` or config pushes just to update this email, as
> hosted configuration should be managed in the dashboard or via targeted Auth settings.

---

## 2. Architecture & Session Security

`PasswordRecoveryContract` and its Riverpod controller are independent from
the signed-in profile controller. `PasswordRecoveryRepository` calls the
Supabase Auth REST endpoints `/recover`, `/verify`, `/user`, and `/logout`
using the public project key. Verification must produce a session for the
requested email before an update is allowed.

- **Zero Storage Leakage:** The recovery token remains in memory for the lifetime of
  the recovery screen. It is never written to Supabase Flutter storage or broadcast
  to other tabs/processes.
- **Session Revocation:** After updating the password via `PUT /auth/v1/user`,
  the repository calls `POST /auth/v1/logout` with `scope: local`, discarding
  the temporary recovery session.
- **Auto-Disposal:** Leaving `ForgotPasswordScreen` disposes the Riverpod provider
  and closes the underlying HTTP client.

---

## 3. Code Improvements & Bug Fixes Applied

1. **GoTrue Error Parsing (`PasswordRecoveryRepository`)**:
   - Fixed an issue where Supabase GoTrue returned HTTP `403` with integer `code: 403` and string `error_code: "otp_expired"`. Previously `data['code'] ?? data['error_code']` evaluated to integer `403`, causing `code == 'otp_expired'` to fail.
   - Now robustly inspects `error_code`, `code`, and message content for `otp_expired`, rate limits (`429`, `over_email_send_rate_limit`), and session expiration (`401`).
2. **Nested Session Handling**:
   - Supports both standard top-level session maps and nested `{'session': ...}` response structures.
3. **Cooldown Reset on Email Correction (`ForgotPasswordScreen`)**:
   - Fixed a bug where clicking "Use a different email" left the 60s cooldown timer running, locking out the user from sending a code to their corrected email. Clicking "Use a different email" now resets the cooldown timer immediately.
4. **Instant Error Dismissal on Typing**:
   - Red error banners automatically clear as soon as the user starts modifying the code, password, or email field (`onChanged: (_) => _clearErrorIfAny()`).
5. **Seamless Email Preservation**:
   - Email is passed from `EmailAuthScreen` to `ForgotPasswordScreen` on push, and passed back via route `extra` upon completing or cancelling reset so users don't have to re-enter their email address.
6. **Password Visibility Toggle**:
   - Added visibility toggle icon on the Confirm Password field in addition to New Password.

---

## 4. Verification

All tests can be executed with:

```bash
flutter test test/features/auth
```

Automated coverage includes:
- `test/features/auth/password_recovery_repository_test.dart` (14 unit tests)
- `test/features/auth/forgot_password_screen_test.dart` (8 widget tests)
- Static analysis: `dart analyze lib/features/auth lib/core/router/app_router.dart`
