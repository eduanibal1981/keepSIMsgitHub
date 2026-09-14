# Firsty Emergency Connectivity Pilot: Test Results & Phase 4 Handoff

**Document Version:** 1.0  
**Execution Date:** 11 September 2026  
**Status:** Phases 0–3 Completed; Phase 4 Blocked Pending Commercial Access  
**Reference Document:** `doc/FIRSTY_EMERGENCY_CONNECTIVITY_EXECUTOR_PLAN.md`

---

## 1. Executive Summary

Phases 0 through 3 of the Firsty Emergency Connectivity recovery architecture have been implemented, tested, and integrated into KeepSIMs in an isolated sandbox environment:
- **Phase 0 (Pilot Capabilities):** Formalized capability matrix and partner questions in [`doc/FIRSTY_PILOT_CAPABILITIES.md`](file:///C:/Users/abdal/Work/KeepSIMs/keep_sims/doc/FIRSTY_PILOT_CAPABILITIES.md).
- **Phase 1 (Offline Recovery Experience):** Implemented the additive recovery reachability model, fine-grained transport probe, local encrypted caching, dual-SIM line switching guide, and the `EmergencyEsimCard` within `OfflineRefillScreen`.
- **Phase 2 (Firsty Sandbox Adapter):** Built the server-side Firsty adapter supporting deterministic mock, staging sandbox API (`https://connect.test.firsty.app/api/v3`), and disabled-live protection, with database schema migrations, RLS policies, and idempotency controls.
- **Phase 3 (Recharge & Dependency Inventory):** Validated authoritative refill reconciliation, server-side kill switch, and completed the client network dependency inventory in [`doc/FIRSTY_CLIENT_DEPENDENCY_INVENTORY.md`](file:///C:/Users/abdal/Work/KeepSIMs/keep_sims/doc/FIRSTY_CLIENT_DEPENDENCY_INVENTORY.md).

> [!CAUTION]
> **Clear Distinction: Mock / Sandbox vs. Real Cellular Connectivity**:
> All eSIM activation strings (`LPA:1$sandbox.firsty.app$...`), profile references, and package allowances generated in this sandbox implementation are **mock resources** validated against Firsty's staging developer portal. They verify API contracts, payload schemas, idempotency, and client UI flows. **They do not emit radio frequency cellular signals and cannot provide live mobile data on a physical phone until Firsty provisions commercial live access.**

---

## 2. Test Execution & Evidence Matrix

| Test Suite / Capability | Target Component | Result | Evidence / Notes |
| :--- | :--- | :--- | :--- |
| **Firsty OAuth2 Token Grant** | Firsty Staging API (`POST /auth/token`) | **PASSED (Sandbox)** | Successfully claimed 24-hour Bearer token (`length: 273`) from Firsty staging environment. |
| **eSIM Provisioning (Mock Mode)** | `servers/providers/firsty.js` | **PASSED (Mock)** | Verified deterministic mock profile generation: `LPA:1$sandbox.firsty.app$mock_...`. |
| **eSIM Provisioning (Staging API)** | `servers/providers/firsty.js` | **PASSED (Sandbox)** | Ordered profile `9007600000000003`, eSIM `900760000000000003`, ICCID `8999915032557926068`, LPA `LPA:1$sandbox.firsty.app$740f6700ae378305ecc5522b000c760f`. |
| **Package Order (1 GB Global)** | Firsty Staging API (`POST .../packages`) | **PASSED (Sandbox)** | Ordered plan `CL1DBCXC5VDGLN` ("FIRSTY GLOBAL 1GB TS 30D NR"). Returned package ref `CL1DBCXC5VDGLN_NLHCMBJ3` with 1,024 MB capacity. |
| **Usage Query** | Firsty Staging API (`GET .../usage`) | **PASSED (Sandbox)** | Queried active usage: returned 1,024 MB remaining. |
| **Recovery State Model** | `test/features/offline_recharge/recovery_state_model_test.dart` | **PASSED (5/5)** | Verified default values, raw string LPA preservation, copyWith, and bidirectional JSON encoding/decoding. |
| **Reachability Probe Service** | `test/features/offline_recharge/recovery_reachability_service_test.dart` | **PASSED (6/6)** | Verified HTTP 200 $\rightarrow$ `reachable`, HTTP 500 $\rightarrow$ `serviceError`, SocketException $\rightarrow$ `unreachable`, TimeoutException $\rightarrow$ `unreachable`, remote metadata merging, and local installation reporting. |
| **Offline Refill Regression** | `test/features/offline_recharge/pending_offline_refill_test.dart` | **PASSED (4/4)** | Verified existing pending refill queue, terminal statuses, and reconciliation logic. |
| **Offline Voucher Regression** | `test/features/offline_recharge/offline_voucher_model_test.dart` | **PASSED (17/17)** | Verified emergency voucher PIN parsing, reveal states, and keystore survival. |
| **Total Test Pass Rate** | Combined Offline Recharge Suites | **PASSED (32/32)** | 100% pass across all unit and integration tests. |
| **Node Worker Syntax Check** | `servers/providers/firsty.js` & `backend-sync-wt/` | **PASSED** | Syntax validated with `node --check`. Single source of truth synchronized. |
| **Database Schema & RLS** | `supabase/tests/firsty_recovery_schema_tests.sql` | **READY** | Verified tables, foreign keys, unique constraint `uq_user_recovery_profile`, and RLS isolation policies. |
| **Physical RF Cellular Data** | Handset cellular tower latch | **NOT TESTED** | Requires physical test eSIM and local carrier roaming agreements from Firsty. |
| **Zero-Rated Whitelisting** | Packet gateway SNI inspection | **NOT TESTED** | Requires Firsty packet gateway whitelist configuration. |
| **Banking / Carrier App Passthrough**| Bank Muscat / Omantel app on Firsty APN | **NOT TESTED** | Blocked pending Phase 4 live device testing. |

---

## 3. Redacted Sandbox Evidence

### Firsty Staging API Session (Captured 11-Sept-2026 02:49 UTC)
```json
{
  "auth": {
    "clientId": "900760",
    "tokenType": "Bearer",
    "status": 200,
    "authenticated": true
  },
  "provisioning": {
    "profileReference": "9007600000000003",
    "esimReference": "900760000000000003",
    "iccid": "8999915032557926068",
    "activationCode": "LPA:1$sandbox.firsty.app$740f6700ae378305ecc5522b000c760f",
    "status": "released",
    "lifecycleStatus": "active"
  },
  "package": {
    "packageReference": "CL1DBCXC5VDGLN_NLHCMBJ3",
    "planReference": "CL1DBCXC5VDGLN",
    "name": "FIRSTY GLOBAL 1GB TS 30D NR",
    "capacityMb": 1024,
    "remainingMb": 1024,
    "status": "active"
  }
}
```

---

## 4. Phase 4 Readiness: Prerequisites & Next Steps

Phase 4 consists of live testing on physical mobile phones in a zero-balance, no-data emergency scenario. The following prerequisites must be fulfilled before Phase 4 can commence:

### A. Firsty Partner Access & Credentials Required
1. **Commercial Wholesale Agreement:** Formal agreement defining wholesale data rates, dormant profile fees, and zero-rating SLA.
2. **Production / Testbed API Credentials:**
   - Production `client_id` (6 digits) and `client_secret`.
   - Dedicated Test eSIM profiles (with IMSI/eUICC profiles that can attach to Oman/GCC radio networks).
3. **Written Confirmation of Zero-Rating:**
   - Confirmation that `<SUPABASE_URL>` and `api.keepsims.com` are whitelisted at zero balance on Firsty APN.
   - Clarification of whether Firsty APN permits TCP 443 SNI whitelisting without requiring an active data bundle.

### B. Designated Test Devices & Physical Setup
1. **iOS Test Handset:** iPhone 13 or newer running iOS 17.5+ or 18.0 with an unlocked eSIM slot.
2. **Android Test Handset:** Google Pixel 7 or Samsung Galaxy S23+ running Android 14+ with DSDS.
3. **Exhausted Primary SIM:** An active physical prepaid SIM (Omantel or Ooredoo) that has been depleted to 0.000 OMR balance and 0 MB data, with active voice/SMS reception if supported.

### C. Commercial & Funding Decisions for Project Owner
1. **Dormant Profile Cost:** Approval of per-profile monthly retention fee for emergency eSIMs sitting dormant on user phones.
2. **Emergency Grant Spend Cap:** Final sign-off on the default $100.00 USD pilot budget ceiling in `FIRSTY_EMERGENCY_MONTHLY_LIMIT_USD`.
3. **Per-User Quota Policy:** Confirmation that 1,024 MB (1 GB) per 30-day window is the desired emergency allowance.

> [!NOTE]
> Production connectivity and live charges remain **disabled by design** (`FIRSTY_SANDBOX_MODE = 'true'`, `FIRSTY_PROVIDER_MODE = 'firsty_sandbox'`). All changes made to the codebase are fully compatible with current uncommitted branch work and ready for owner review.
