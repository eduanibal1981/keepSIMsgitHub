# 08 — Profile and Onboarding

## Profile details
### TC-PRO-001: Edit profile name and contact destinations
- **Preconditions**: Authenticated user has editable name, phone, email, and WhatsApp destination values.
- **Expected**: Valid changes save and refresh the profile; invalid phone/email values are rejected with a clear message.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: The profile edit sheet supports name and home country; email and WhatsApp use separate contact editors. Home-country selection is covered once in TC-SET-005.

## Avatar
### TC-PRO-002: Change the profile avatar
- **Preconditions**: User grants access to a supported image source.
- **Expected**: Selected image uploads, appears on profile, and remains after reload.
- **Status**: FAILED
- **Notes/Found Issues**: ProfileScreen displays avatarUrl or initials but no avatar picker/upload action was found.

## Password and 2FA security controls
### TC-PRO-003: Update password and enable or disable two-factor authentication
- **Preconditions**: User has an active authenticated session.
- **Expected**: Password change requires current authentication and 2FA state persists securely.
- **Status**: FAILED
- **Notes/Found Issues**: No password update or 2FA control was found in ProfileScreen or Settings routes. Biometric lock is separate and cataloged in TC-PRO-004.

## Biometric lock
### TC-PRO-004: Enable biometric protection for guarded money actions
- **Preconditions**: Device supports biometrics and the user has configured authentication.
- **Expected**: Successful biometric auth enables the lock; cancel, failure, or lockout changes no money or security preference.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Security guard and fake biometric test utilities exist; Flutter tests did not run.

## Onboarding walkthrough
### TC-PRO-005: Complete onboarding and save the completion flag
- **Preconditions**: A new account has not completed onboarding.
- **Expected**: The welcome step requires explicit acceptance of the Terms of Service and Privacy Policy before advancing. Both policy links open externally without accepting on the user's behalf. Walkthrough saves the selected preferences and routes to the authenticated home after completion.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Local widget checks passed on 2026-10-10 (20 tests): consent gating and retention on Back, policy URLs and browser-open failure, optional permission setup/skip, notification denial/grant/revocation and return from settings, concurrent requests, alarm opt-in, compact permission layouts with enlarged text in both themes, and contact transitions. Full account completion remains untested. The separate currency transition suite has one existing price expectation mismatch (`$8.50 USD`); these changes do not alter pricing. The carrier validation badge in the preceding SIM step also overflows at 320px with 1.8x text; permission-layout checks resize after reaching the alerts step. Previews are under `output/onboarding-consent/` and `output/onboarding-permissions/`.

## Onboarding SIM setup
### TC-PRO-006: Select an initial SIM and finish protected setup
- **Preconditions**: New user has a valid phone number and an eligible plan.
- **Expected**: SIM details and plan are saved once; failed authentication or payment leaves onboarding incomplete.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: No test account onboarding flow was completed.
