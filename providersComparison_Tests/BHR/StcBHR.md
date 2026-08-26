# Provider Comparison & Test Report: STC Bahrain (formerly Viva Bahrain)

> **Country:** Bahrain (`BH` / `+973` / `BHR`)  
> **Carrier:** STC Bahrain B.S.C. Closed (`STC Bahrain` / formerly `Viva Bahrain` / Saudi Telecom Company Group)  
> **Network Type:** MNO (National Mobile Network Operator)  
> **Balance USSD / SMS:** Dial `*124#` or `*142#` (Balance & validity enquiry) | **Recharge USSD:** Dial `*123*<PIN>#` or via STC App | **Account App:** STC Bahrain App (stc pay BH)  
> **Customer Care:** `124` (Local) / `+973 3312 4124` (International)  
> **Regulatory Policy (TRA Bahrain):** 90 Days Inactivity Lifecycle | Recharge vouchers grant 30 to 90 days validity | 90 Days Suspension Grace Period before permanent number termination | 10% VAT applies on prepaid services  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DingConnect** (`ding`) | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `BH` (ISO-2) | `BHR` (ISO-3) | `BH` (ISO-2) | `BH` (ISO-2) |
| **Carrier / Operator Code** | `STC` | `STC` | `STC` | `STC` |
| **Delivery Mechanism** | Direct Top-Up / App Gateway | 0 Active Products in Pre-Prod | 0 Active Products in Sandbox | 0 Active Offers in Catalog |
| **Settlement Currency** | **`OMR`** | **`OMR`** | **`USD`** | **`USD`** |
| **Catalog Format** | Local / Direct Route | 0 Active Products in BHR | 0 Active Products in BH | 0 Active Offers in BH |
| **DB Status in `carrier_provider_map`** | 🔴 **Disabled (Local Fallback)** (`priority: 10`) | 🔴 **Disabled** (`priority: 30`) | 🔴 **Disabled** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Catalog Inspection

* **Aggregator Catalog Availability:**
  - **DT One Pre-Production:** 0 dedicated STC Bahrain products currently published in test catalog (Operator IDs `1828` Batelco and `1829` Zain are active).
  - **Reloadly Sandbox:** 0 dedicated STC Bahrain operator records published in sandbox (Operator IDs `22` Batelco and `1165` Zain are active).
  - **Zendit API:** 0 catalog offers for country `BH`.
  - **DingConnect UAT:** 0 active catalog products for country `BH`.
* **Production Servicing Mechanism:** STC Bahrain subscribers are fulfilled via direct STC local gateway integrations or retail voucher distribution channels.

---

## 3. Technical Service & USSD Information

* **Balance Check:** Dial `*124#` or `*142#` on prepaid handset.
* **Recharge Voucher:** Dial `*123*<14-digit PIN>#` or top-up via stc App / stc pay BH.
* **Customer Support:** Call `124` from STC lines or `+973 3312 4124`.
* **Standard Validity:** Recharges of BD 3.50 or higher grant active validity extension of 30 to 90 days. Cumulative validity is capped under TRA Bahrain rules.

---

## 4. KeepSIMs Production Routing Decision

1. **Routing Strategy:** STC Bahrain is registered as an active supported carrier (`is_supported: true`, `fulfillment_gateway: 'API'`) in the KeepSIMs database.
2. **Refill Pricing:** Default refill threshold is set to **$3.50 USD** (`minimum_topup_amount: $3.00 USD`, `inapp_pricing: $4.99 USD`).
3. **TRA Bahrain Regulatory Compliance:**
   - STC Bahrain prepaid lines operate on a **90-day inactivity lifecycle**.
   - If no qualifying transaction occurs within 90 days, the line transitions into a **90-day grace/suspension period** (incoming-only calls and SMS) before permanent cancellation and recycling into the TRA national numbering pool.
   - KeepSIMs schedules automated mini-refills at **Day 80–85** to maintain uninterrupted service.
