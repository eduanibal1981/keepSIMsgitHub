# Google Play Data Safety Answers

Use these exact answers when completing the **Data Safety** questionnaire in Google Play Console for KeepSIMs.

---

## 1. Data Collection & Security Overview
* **Does your app collect or share any of the required user data types?** Yes.
* **Is all of the user data collected by your app encrypted in transit?** Yes (HTTPS / TLS 1.3).
* **Do you provide a way for users to request that their data be deleted?** Yes.
* **Deletion Request URL:** `https://keepsims.com/delete-account`

---

## 2. Data Types Declared

| Data Category | Data Type | Collected / Shared | Purpose | Linked to User | Optional or Required |
|---|---|---|---|---|---|
| **Location** | Approximate Location (IP-based) | Collected | App functionality (Country carrier rules) | Yes | Required |
| **Personal Info** | Email Address | Collected | Account management, Security, Authentication | Yes | Required |
| **Personal Info** | Phone Number | Collected | App functionality (SIM protection & offline refill) | Yes | Required |
| **Personal Info** | User IDs | Collected | Account management, Analytics | Yes | Required |
| **Financial Info** | User payment info / purchase history | Collected | App functionality, Fraud prevention | Yes | Required |
| **App Info & Performance** | Crash logs & Diagnostics | Collected | Analytics, Developer communications | No | Optional |
| **Device or other IDs** | Device / Push Tokens | Collected | App functionality (Push alerts) | Yes | Required |

---

## 3. Biometric Data Declaration
* **Does your app collect Biometric data?** **NO.**
* *Note for reviewer:* Biometric authentication relies strictly on local device OS APIs (`local_auth`) and is processed entirely in the device security enclave. No biometric data is collected, stored, or transmitted to any server.
