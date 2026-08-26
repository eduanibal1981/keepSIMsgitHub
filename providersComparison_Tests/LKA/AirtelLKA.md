# Provider Comparison & Test Report: Airtel Sri Lanka (Dialog Axiata Rails)

> **Country:** Sri Lanka (`LK` / `+94` / `LKA`)  
> **Carrier:** Bharti Airtel Lanka (Pvt) Ltd (Merged into Dialog Axiata PLC)  
> **Network Type:** Consolidated Network Operator / Sub-Brand (~3M+ Migrated Subscribers)  
> **Mobile Prefix:** `+9475`  
> **Balance USSD / SMS:** Dial `*550#` (Legacy Airtel Balance) or `#456#` / `#123#` (Integrated Dialog Menu) | **Recharge USSD:** Dial `*555*<PIN>#` / `*123*<PIN>#` or MyDialog / My Airtel App  
> **Customer Care:** `1755` (Airtel Care) / `1777` (Dialog Support) / `+94755555555` / `0755555555`  
> **Corporate Merger Context:** In 2024, Bharti Airtel and Dialog Axiata completed a comprehensive merger transaction in Sri Lanka. Airtel Lanka operates under Dialog Axiata PLC, sharing unified telecom infrastructure, frequency spectrum, and billing rails. All wholesale top-up providers process Airtel Sri Lanka (`+9475`) recharges directly via Dialog Axiata operator channels.  
> **Regulatory Policy (TRCSL Sri Lanka):** 180-day inactivity threshold + 90-day grace/incoming-only period before permanent disconnection & number recycling | Telecom recharges subject to 18% VAT + 2.5% Social Security Contribution Levy (SSCL) + Telecommunications Levy (TL)  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `LKA` (ISO-3) | `LK` (ISO-2) | `LK` (ISO-2) | `LK` (ISO-2) |
| **Carrier / Operator Code** | `360` ("Dialog Sri Lanka" / Airtel Rails) | `472` ("Dialog Sri Lanka" / Airtel Rails) | `Dialog` | `DGLK` ("Dialog Sri Lanka") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Data Bundles | Direct Airtime Top-Up & Data Bundles | Direct Top-Up (`DIALOG_LK_001` - `003`) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `11294` (50–10000 LKR) + 40 Fixed Products | Fixed `472` ($0.40–$12.00 USD / 100–3000 LKR) | Fixed Offers (1551, 3000, 5000 LKR) | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (LKR) / Product | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`DGLK`) |
| :---: | :---: | :---: | :---: | :---: |
| **50.00 LKR** (Min Entry Top-Up) | **0.066 OMR ($0.171 USD)** (`11294`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 LKR** (Standard Airtime) | **0.131 OMR ($0.341 USD)** (`11294`) | **$0.38 USD** (`472` / $0.40 face - 5% disc) | — | 🔴 *(0 Catalog Offers)* |
| **200.00 LKR** (Standard Airtime) | **0.262 OMR ($0.681 USD)** (`11294`) | **$0.76 USD** (`472` / $0.80 face) | — | 🔴 *(0 Catalog Offers)* |
| **265.00 LKR** (2.5GB Data 30D) | **0.347 OMR ($0.902 USD)** (`61512`) | — | — | 🔴 *(0 Catalog Offers)* |
| **298.00 LKR** (Call Blaster 400Mins/SMS) | **0.390 OMR ($1.014 USD)** (`61509`) | — | — | 🔴 *(0 Catalog Offers)* |
| **500.00 LKR** (Standard Airtime) | **0.655 OMR ($1.703 USD)** (`11294`) | **$1.90 USD** (`472` / $2.00 face) | — | 🔴 *(0 Catalog Offers)* |
| **1551.00 LKR** (Standard Top-Up) | **2.031 OMR ($5.281 USD)** (`44032`) | — | **$6.50 USD** (`DIALOG_LK_001`) | 🔴 *(0 Catalog Offers)* |
| **3000.00 LKR** (High Tier Airtime) | **3.928 OMR ($10.213 USD)** (`19197`) | **$11.40 USD** (`472` / $12 face) | **$12.50 USD** (`DIALOG_LK_002`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `11294` (Open Range 50 LKR on Dialog rails) to `+94750000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793442`, Wholesale Cost: `0.066 OMR` (~$0.171 USD), Delivered: `50 LKR`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `472` (Dialog Sri Lanka Airtime, $0.40 USD requested) to `+94750000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178458`, Delivered: `100 LKR`, Cost: `$0.38 USD`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `DIALOG_LK_001` (Dialog 1551 LKR Top-Up) to `+94750000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_lk_test_1787438772348_dialog_lk_001`, Wholesale Cost: `$6.50 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `DGLK` ("Dialog Sri Lanka")
* **Catalog Status:** Returns `503 Service Unavailable / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 360` / Open Range `11294` — delivered via consolidated Dialog Axiata network rails from 50 LKR at **0.066 OMR (~$0.171 USD)** with verified instant pre-prod confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 472` — Dialog Sri Lanka operator rail, $0.38 USD net for 100 LKR, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Dialog` — offer `DIALOG_LK_001`, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`DGLK`, `priority: 40`, `is_enabled: false`).
5. **TRCSL Sri Lanka Regulatory Compliance:**
   - Airtel Sri Lanka (`+9475`) lines follow Dialog Axiata's TRCSL **180-day inactivity threshold + 90-day grace period** (total 270 days) before number recycling.
   - KeepSIMs schedules automated mini-refills on **Day 90–120** (delivering 50–100 LKR for ~$0.17–$0.38 USD via DT One / Reloadly) to reset the TRCSL 180-day countdown clock and preserve customer identity and WhatsApp/banking OTPs indefinitely.
