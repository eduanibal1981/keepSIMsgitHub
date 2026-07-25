# Owner Store Submission Checklist — Keystores, URLs & Secret Rotation

When submitting KeepSIMs to the **Google Play Console** and **Apple App Store Connect**, use this reference checklist:

---

## 1. Release Keystore Generation (Required for Android Release Build)

The Android release build requires a valid production signing keystore. **Release builds without `key.properties` will fail Gradle execution loudly.**

### Generate Release Keystore:
Run the following command in terminal:
```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Create `android/key.properties`:
Create file `android/key.properties` (never commit to git):
```properties
storePassword=<YOUR_STORE_PASSWORD>
keyPassword=<YOUR_KEY_PASSWORD>
keyAlias=upload
storeFile=../upload-keystore.jks
```

### Play App Signing Enrollment:
- Enroll in **Play App Signing** in Google Play Console.
- Upload `android/upload-keystore.jks` public cert / app bundle signed with the upload key.
- Google Play will re-sign the APKs for distribution using Google's app signing key.

---

## 2. Secrets Rotation Notice

- **Sandbox PayPal Secrets Rotation**: The sandbox PayPal Client ID and Secret were present in git history in earlier development commits. Before moving to production, **rotate the sandbox and live secrets in the PayPal Developer Dashboard** (`https://developer.paypal.com`).
- Store updated secrets in Supabase Edge Function Secrets (`PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET`, `PAYPAL_WEBHOOK_ID`).

---

## 3. Webhook Return / Cancel URLs & Deep Linking

- PayPal checkout uses return and cancel URLs:
  - Return URL: `https://keepsims.com/paypal-return`
  - Cancel URL: `https://keepsims.com/paypal-cancel`
- Host landing pages at these URLs or configure Android App Links / iOS Universal Links to deep-link back into the app (`com.keep_sims://paypal-return`).
- In-app copy instructs the user: *"Complete authorization in your browser window. Once approved, payment will automatically capture."*

---

## 4. Store Console Fields

### Google Play Console

| Play Console Field | Value to Enter | Artifact Location |
|---|---|---|
| **Privacy Policy URL** | `https://keepsims.com/privacy` | [doc/PRIVACY_POLICY.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/PRIVACY_POLICY.md) |
| **Data Deletion Request URL** | `https://keepsims.com/delete-account` | [doc/WEB_DELETION.html](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/WEB_DELETION.html) |
| **Data Safety Questionnaire** | Complete using [doc/PLAY_DATA_SAFETY.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/PLAY_DATA_SAFETY.md) | [doc/PLAY_DATA_SAFETY.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/PLAY_DATA_SAFETY.md) |

### Apple App Store Connect

| App Store Connect Field | Value to Enter | Artifact Location |
|---|---|---|
| **Privacy Policy URL** | `https://keepsims.com/privacy` | [doc/PRIVACY_POLICY.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/PRIVACY_POLICY.md) |
| **Account Deletion URL (Optional)** | `https://keepsims.com/delete-account` | [doc/WEB_DELETION.html](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/WEB_DELETION.html) |
| **App Privacy Nutrition Label** | Complete using [doc/APPLE_PRIVACY_NUTRITION_LABEL.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/APPLE_PRIVACY_NUTRITION_LABEL.md) | [doc/APPLE_PRIVACY_NUTRITION_LABEL.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/doc/APPLE_PRIVACY_NUTRITION_LABEL.md) |

---

## 5. Recommended Statutory Retention Setting
* **Financial Ledger Retention:** 7 Years (statutory tax/VAT compliance).
