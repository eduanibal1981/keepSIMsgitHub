# KeepSIMs Client Network Dependency & Zero-Rating Whitelist Inventory

**Document Version:** 1.0  
**Date:** 11 September 2026  
**Status:** Completed Draft (Phase 3 Deliverable)  
**Reference Document:** `doc/FIRSTY_EMERGENCY_CONNECTIVITY_EXECUTOR_PLAN.md`

---

## 1. Executive Summary & Objective

To enable offline emergency recovery via Firsty app whitelisting (zero-rated access), KeepSIMs must define the exact, minimal network surface required for an end user with **zero cellular balance** to launch the mobile client, authenticate, query account state, and trigger an authoritative refill of their physical carrier SIM line.

All endpoints cataloged below are evaluated against four operational criteria:
1. **Criticality:** Essential (blocking for recovery) vs. Optional (gracefully degraded).
2. **Traffic Classification:** Direct KeepSIMs infrastructure vs. Third-party dependency.
3. **Behavior When Blocked:** Verified offline cache fallback and timeout thresholds.
4. **Whitelisting Feasibility:** Can this host be whitelisted via SNI/IP without granting open Internet access?

---

## 2. Comprehensive Client Network Request Inventory

| Stage / User Journey | Destination Host / Domain | Protocol & Port | Purpose & Endpoint | Criticality | Behavior When Blocked / Offline | Whitelist Requirement |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **App Launch** | `<SUPABASE_URL>` | HTTPS (443) | **Auth Session Refresh:** `POST /auth/v1/token` | **Essential** | Session remains in local encrypted storage; user remains authenticated locally if JWT is within validity or offline fallback is active. | **Mandatory** |
| **App Launch** | `<SUPABASE_URL>` | HTTPS (443) | **System Configs Snapshot:** `GET /rest/v1/system_configs` | **Optional** | Uses local defaults from `LocalCacheService` (cached contact numbers, fees, and feature flags). | **Mandatory** |
| **App Launch** | `api.onesignal.com` | HTTPS (443) | Push device registration & player ID sync | **Optional** | Gracefully fails silently in background; push delivery deferred until general connectivity returns. | **Excluded** (Not whitelisted) |
| **App Launch** | `fonts.googleapis.com` / `fonts.gstatic.com` | HTTPS (443) | Dynamic font glyph download (`GoogleFonts`) | **Optional** | Fonts are locally bundled or fall back to system sans-serif/monospace fonts. | **Excluded** |
| **Recovery Check** | `<SUPABASE_URL>` | HTTPS (443) | **Fast Reachability Probe:** `GET /functions/v1/recovery-service/probe` | **Essential** | Evaluates transport reachability within 4 seconds. If blocked, app displays offline refill channels (SMS/USSD). | **Mandatory** |
| **Recovery Check** | `<SUPABASE_URL>` | HTTPS (443) | **Recovery Status & Allowance:** `POST /functions/v1/recovery-service` | **Essential** | Syncs backup profile LPA string, remaining emergency MB, and entitlement status. Falls back to local cache snapshot. | **Mandatory** |
| **Dashboard** | `<SUPABASE_URL>` | HTTPS (443) | **SIM Lines Fetch:** `GET /rest/v1/sim_lines` | **Essential** | Reads cached SIM lines snapshot from local SQLite/Keystore. Displays previously selected line. | **Mandatory** |
| **Dashboard** | `<SUPABASE_URL>` | HTTPS (443) | **Wallet Balance:** `GET /rest/v1/wallets` | **Essential** | Displays cached wallet balance with "Offline snapshot" badge if network fails. | **Mandatory** |
| **Refill Flow** | `<SUPABASE_URL>` | HTTPS (443) | **Instant Refill RPC:** `POST /rest/v1/rpc/request_instant_refill` | **Essential** | Authoritative wallet-funded top-up trigger. Server validates wallet funds and enqueues fulfillment. | **Mandatory** |
| **Refill Flow** | `<SUPABASE_URL>` | HTTPS (443) | **Offline Refill Queue Reconciliation:** `POST /rest/v1/rpc/reconcile_offline_refills` | **Essential** | Flushes pending WhatsApp/SMS/IVR trigger intents to avoid duplicate charging upon reconnection. | **Mandatory** |
| **Deposit / Pay** | `api.paypal.com` / `sandbox.paypal.com` | HTTPS (443) | PayPal Web SDK / Order creation | **Non-Zero-Rated** | Cannot be safely whitelisted under zero-rating because PayPal redirects through broad anti-fraud and banking CDNs. | **Requires General Data** |
| **Deposit / Pay** | Banking App / Gateway (Thawani, Benefit, OmanNet) | HTTPS (443) | 3-D Secure OTP challenge and inter-bank clearing | **Non-Zero-Rated** | Involves dozens of dynamic bank domains and payment aggregator IP ranges. | **Requires General Data** |
| **Third-Party** | `wa.me` / `api.whatsapp.com` | HTTPS (443) | WhatsApp deep-link trigger for `REFILL <amount>` | **Channel Dependent** | Handled natively by WhatsApp client. Works if user has zero-rated WhatsApp carrier bundle or emergency general data. | **Excluded** from KeepSIMs whitelist |

---

## 3. Whitelist Specification for Firsty Agreement

To enable the zero-rated KeepSIMs recovery session on zero-balance Firsty profiles, the following domain patterns must be approved:

```text
# KeepSIMs Core API & Supabase Infrastructure
*.supabase.co:443
api.keepsims.com:443
*.keepsims.com:443

# Required Ports and Protocols
TCP 443 (HTTPS)
TCP 80 (HTTP 301/302 Redirect to 443 only)
UDP 53 / TCP 53 (DNS resolution)
```

> [!IMPORTANT]
> **No Arbitrary Proxying**: KeepSIMs will not act as an open proxy or VPN. All whitelisted traffic is strictly authenticated via Supabase JWTs and constrained to API payloads under 64 KB.

---

## 4. Payment & Banking App Isolation Strategy

1. **Wallet-Funded Refill on Whitelist:**
   - If the user's KeepSIMs wallet holds sufficient balance (e.g. $\ge \$1.00$), the refill executes entirely through the whitelisted KeepSIMs backend without touching third-party payment gateways or banking apps.
2. **Unfunded Wallet & External Payment:**
   - If the wallet balance is zero, bank deposit cannot complete over the whitelisted channel alone due to 3-D Secure and payment gateway redirect complexity.
   - **Resolution:** The user activates the **Firsty Emergency General-Data Allowance (1 GB Sandbox / Partner grant)** through the whitelisted KeepSIMs screen first. Once the general-data session is opened, the user opens their bank or carrier app to deposit funds or recharge directly.

---

## 5. Duplicate Execution & Reconciliation Controls

- **Local Deduplication:** Every refill action generates a client-side UUID idempotency key (`refill_<simLineId>_<timestamp>`).
- **Cooldown Window:** A mandatory 12-second UI cooldown disables all retry buttons after a launch event.
- **Queue Synchronization:** On app resume, `pendingOfflineRefillsControllerProvider` cross-references all pending triggers against server execution receipts (`reconcile_offline_refills`) before permitting a new transaction.
- **Voucher Safety:** Keystore-stored emergency voucher PINs are marked redeemed locally immediately upon reveal to prevent double redemption.
