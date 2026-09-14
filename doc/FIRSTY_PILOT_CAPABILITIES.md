# Firsty Emergency Connectivity: Pilot Capability Matrix & Requirements

**Document Version:** 1.0  
**Date:** 11 September 2026  
**Status:** Working Draft (Sandbox Prototype Phase)  
**Reference Document:** `doc/FIRSTY_EMERGENCY_CONNECTIVITY_EXECUTOR_PLAN.md`

---

## 1. Pilot Environment & Parameter Matrix

This matrix establishes the operational parameters for the KeepSIMs emergency recovery pilot. Every entry is explicitly designated as **CONFIRMED** (empirically verified in sandbox or local codebase), **PROPOSED** (architecture designed and implemented in sandbox; awaiting Firsty verification), or **UNKNOWN** (requires physical field trial and partner commercial agreement).

| Parameter Category | Detail / Parameter | Value / Target | Evaluation Status | Evidence / Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Geography** | Primary Target Country | Oman (OM / +968) | **PROPOSED** | KeepSIMs core market. Firsty Free consumer signup list omits Oman, but B2B wholesale eSIM coverage covers Oman via roaming agreements. |
| **Geography** | Secondary Target Countries | UAE (+971), Saudi Arabia (+966), UK (+44) | **PROPOSED** | Common regional travel corridors for KeepSIMs users. |
| **Local Networks** | Host Carrier Networks (Oman) | Omantel, Ooredoo Oman, Vodafone Oman | **UNKNOWN** | Exact roaming host network for Firsty IMSI in Oman must be confirmed via Firsty partner profile PLMN list. |
| **Handset / OS** | Primary iOS Testbed | iPhone 13 or newer (iOS 17.5+ / 18.0) | **PROPOSED** | Dual SIM (Physical SIM + eSIM) support verified. User must manually select Cellular Data line. |
| **Handset / OS** | Primary Android Testbed | Google Pixel 7 / Samsung Galaxy S23+ (Android 14+) | **PROPOSED** | Dual SIM dual standby (DSDS) supported. EuiccManager API functional. |
| **Primary Line** | Original Physical SIM Carrier | Omantel / Ooredoo prepaid line | **CONFIRMED** | Target scenario: line has 0.000 OMR balance, expired data bundle, barred outgoing data. |
| **Original SIM State** | SMS OTP Inbound Capability | Dependent on carrier barring policy | **UNKNOWN** | Certain carriers suspend incoming SMS when balance is zero for >30 days; must be tested per carrier. |
| **Critical Apps** | Inbound Emergency Messaging | WhatsApp (Text only) | **PROPOSED** | Requires either Firsty general-data allowance or specific whitelisting of WhatsApp servers (Meta CDN/IP blocks). |
| **Critical Apps** | Intended Carrier Self-Care | Omantel App / Ooredoo Oman App | **UNKNOWN** | Carrier apps utilize proprietary CDNs, dynamic token endpoints, and deep app-check domains. Whitelisting is unconfirmed. |
| **Critical Apps** | Intended Banking Apps | Bank Muscat (mBanking) / National Bank of Oman | **UNKNOWN** | Bank apps enforce mTLS, safety-net/Play Integrity checks, and out-of-band payment gateway redirects (Thawani, Benefit, Visa/Mastercard 3DS). |
| **KeepSIMs Backend** | Zero-Rated Recovery Target | `api.keepsims.com` / Supabase Edge Functions | **PROPOSED** | Lightweight probe endpoint `<SUPABASE_URL>/functions/v1/recovery-service/probe` requires zero-rated HTTP/HTTPS access. |
| **Firsty Integration** | Firsty API Staging Host | `https://connect.test.firsty.app/api/v3` | **CONFIRMED** | Verified with OAuth2 Client Credentials flow. Sandbox returns mock profiles and packages. |
| **Firsty Integration** | Firsty Production Host | `https://connect.firsty.app/api/v3` | **UNKNOWN** | Disabled until production credentials and commercial contract are approved. |
| **Funding & Budget** | Initial Pilot Spend Cap | $100.00 USD total cap | **PROPOSED** | Managed by server-side kill switch and per-user monthly allowance ceilings in KeepSIMs backend. |
| **Funding & Budget** | Per-User Recovery Quota | 1,024 MB (1 GB) 30-day single grant | **CONFIRMED (Sandbox)** | Sandbox catalog package `CL1DBCXC5VDGLN` ("FIRSTY GLOBAL 1GB TS 30D NR") verified via CLI and API. |

---

## 2. Capabilities Matrix (Confirmed vs. Proposed vs. Unknown)

| Capability / Flow | Classification | Explanation & Verification Method |
| :--- | :--- | :--- |
| **Sandbox API Authentication** | **CONFIRMED** | OAuth2 Client Credentials exchange (`POST /auth/token`) verified with 24-hour JWT issuance. |
| **Sandbox eSIM Provisioning** | **CONFIRMED** | Provisioning request (`POST /esims`) returns valid LPA activation string (`LPA:1$sandbox.firsty.app$...`), matching ID, and ICCID. |
| **Sandbox Package Order** | **CONFIRMED** | Package ordering (`POST /profiles/{p}/esims/{e}/packages`) assigns 1,024 MB global data package. |
| **Sandbox Usage Query** | **CONFIRMED** | Usage polling (`GET /profiles/{p}/esims/{e}/usage`) returns real-time quota remaining. |
| **Offline Cache of Instructions** | **CONFIRMED** | Local encrypted cache in KeepSIMs mobile client preserves LPA code, QR representation, and device instructions offline. |
| **Additive Reachability Probe** | **CONFIRMED** | Lightweight probe differentiates socket/DNS transport failures from application/HTTP errors without breaking existing connectivity providers. |
| **Zero-Rated KeepSIMs Access** | **PROPOSED** | Technical design proposes whitelisting KeepSIMs API domain so clients with zero data balance can ping backend and claim recovery allowance. |
| **Partner-Funded General Data** | **PROPOSED** | Technical design proposes granting a partner-sponsored 1 GB package upon verified KeepSIMs emergency trigger. |
| **Automated Cellular Switching** | **UNKNOWN** | Operating system restrictions (iOS CoreTelephony / Android EuiccManager) prevent third-party apps from silently toggling the active data SIM without user confirmation. User-guided flow implemented. |
| **Zero-Balance Roaming Latch** | **UNKNOWN** | Unknown whether Firsty eSIM will latch onto Omantel/Ooredoo cellular towers if the user has never purchased a retail package and holds zero balance. |
| **Banking / 3D-Secure Passthrough** | **UNKNOWN** | Unknown if banking authentication or 3-D Secure OTP verification can function on sponsored access without full open-Internet general data. |

---

## 3. Partner Outreach Questions for Firsty

> [!IMPORTANT]
> The following 8 questions must be transmitted to the Firsty partner engineering and commercial teams by the project owner. **Do not send automated outreach.** These responses are required prior to initiating Phase 4 (physical live-device testing).

### Question 1: Zero-Rated Whitelisting on Zero-Balance Profiles
> *"Can Firsty provide a real test eSIM configured for domestic and roaming connectivity where KeepSIMs API endpoints (`api.keepsims.com`, Supabase project edge endpoints) are permanently zero-rated, allowing an end user with zero general-data balance to establish an HTTPS connection without a prior data purchase?"*

### Question 2: Market & Network Coverage (Oman & Middle East)
> *"Which specific mobile network operators (MNOs) in Oman (e.g., Omantel, Ooredoo Oman, Vodafone Oman) and the GCC support Firsty wholesale roaming? Does the profile permit long-term domestic latching for residents whose primary line is disconnected, or does it enforce anti-permanent roaming cutoffs?"*

### Question 3: Bootstrap Activation Delay & Failure Behavior
> *"When a user on a zero-rated backup profile reaches KeepSIMs and our backend issues an API call to grant a partner-funded general-data package, what is the expected network propagation delay before the packet gateway activates general data for that IMSI? What error codes or webhooks are fired if the gateway fails to open?"*

### Question 4: Traffic Classification & Dependency Whitelisting
> *"How does Firsty classify whitelisted traffic (e.g., SNI inspection, destination IP CIDRs, or APN-level proxying)? Can CDNs (Cloudflare, Fastly), DNS queries, and TLS 1.3 encrypted client hellos (ECH) operate over the sponsored channel?"*

### Question 5: Third-Party Authentication & Gateway Dependencies
> *"In an emergency recovery session where general data is not yet funded, can essential third-party identity and security endpoints be sponsored alongside KeepSIMs (specifically: Firebase App Check, Apple DeviceCheck, Google Play Integrity, and SMS gateway webhooks)?"*

### Question 6: Pricing, Dormancy & Inactivity Fees
> *"What are the commercial terms for backup emergency profiles? Specifically: What is the recurring monthly cost per provisioned profile while dormant? What is the wholesale per-MB or per-GB fee for partner-funded packages? Does an unused eSIM profile expire or deactivate after a period of dormancy?"*

### Question 7: Bootstrap Path from Absolute Zero
> *"If an eSIM profile has been installed on a device but has had no network activity for months, does it maintain a signaling channel with local cell towers to receive push-triggered packages, or must the mobile handset initiate an outbound data attempt over the Firsty APN to trigger network attachment?"*

### Question 8: Native SDKs & Supported Switching Entitlements
> *"Does Firsty provide a mobile SDK (iOS/Android) or privileged carrier entitlements for in-app eSIM activation and automated cellular data switching, or is the partner integration restricted to standard LPA activation strings (`LPA:1$...`) requiring native OS user prompts?"*

---

## 4. Next Actions for Phase 4 Readiness

1. **Owner Action:** Submit Section 3 questions to Firsty partner representative.
2. **Owner Action:** Designate physical test devices (1x iPhone running iOS 17+, 1x Android device running Android 14+) with active eSIM slots.
3. **Owner Action:** Procure an experimental prepaid physical SIM (Omantel or Ooredoo) that can be deliberately drained of credit and data for testing.
4. **Engineering Action:** Keep all live provisioning disabled until written answers and commercial terms are accepted. All development and automated testing remains strictly isolated to the sandbox adapter.
