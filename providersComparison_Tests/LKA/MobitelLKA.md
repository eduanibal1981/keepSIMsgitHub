# Provider Comparison & Test Report: Mobitel Sri Lanka (SLT-Mobitel)

> **Country:** Sri Lanka (`LK` / `+94` / `LKA`)  
> **Carrier:** Mobitel (Pvt) Ltd / Sri Lanka Telecom (`SLT-Mobitel` / National Carrier)  
> **Network Type:** MNO (National Operator / ~8M+ Subscribers / ~26% Market Share)  
> **Mobile Prefixes:** `+9471`, `+9470`  
> **Balance USSD / SMS:** Dial `#141#` (Balance & Validity Inquiry), `*141*1*1#` (Data Balance), `#888#` (Self Care Portal) | **Recharge USSD:** Dial `*102*<14-digit PIN>#` or SLT-Mobitel SelfCare App / mCash  
> **Customer Care:** `1717` (Local Mobitel) / `+94712755777` / `0712755777`  
> **Regulatory Policy (TRCSL Sri Lanka):** 180-day inactivity threshold + 90-day grace/incoming-only period before permanent disconnection & number recycling | Telecom recharges subject to 18% VAT + 2.5% Social Security Contribution Levy (SSCL) + Telecommunications Levy (TL)  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `LKA` (ISO-3) | `LK` (ISO-2) | `LK` (ISO-2) | `LK` (ISO-2) |
| **Carrier / Operator Code** | `409` ("Mobitel Sri Lanka") | `471` ("Mobitel Sri Lanka") | `Mobitel` | `MSLK` ("Mobitel Sri Lanka") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Data Bundles | Direct Airtime Top-Up (Range) | Direct Top-Up (`MOBITEL_LK_5-I`) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `11296` (20–10000 LKR) + 48 Fixed Products (Data/Anytime plans) | Range `471` (100–3000 LKR / $0.37–$11.11 USD) | Fixed Offer `MOBITEL_LK_5-I` (772 LKR / $5.60 USD) | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (LKR) / Product | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`MSLK`) |
| :---: | :---: | :---: | :---: | :---: |
| **20.00 LKR** (Micro-Entry) | **0.028 OMR ($0.072 USD)** (`11296`) | — | — | 🔴 *(0 Catalog Offers)* |
| **50.00 LKR** (Standard Airtime) | **0.070 OMR ($0.182 USD)** (`38281` / `11296`) | — | — | 🔴 *(0 Catalog Offers)* |
| **58.00 LKR** (Anytime 512MB 7D) | **0.081 OMR ($0.211 USD)** (`63341`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 LKR** (Standard Airtime) | **0.139 OMR ($0.361 USD)** (`3265` / `11296`) | **$0.37 USD** (`471`) | — | 🔴 *(0 Catalog Offers)* |
| **118.00 LKR** (Anytime 1.1GB 21D) | **0.164 OMR ($0.426 USD)** (`63342`) | — | — | 🔴 *(0 Catalog Offers)* |
| **200.00 LKR** (Standard Airtime) | **0.277 OMR ($0.720 USD)** (`3266` / `11296`) | **$0.74 USD** (`471`) | — | 🔴 *(0 Catalog Offers)* |
| **239.00 LKR** (Anytime 3.38GB) | **0.331 OMR ($0.861 USD)** (`51537`) | — | — | 🔴 *(0 Catalog Offers)* |
| **300.00 LKR** (Standard Airtime) | **0.416 OMR ($1.082 USD)** (`3267` / `11296`) | **$1.11 USD** (`471`) | — | 🔴 *(0 Catalog Offers)* |
| **399.00 LKR** (Anytime 5.1GB 30D) | **0.553 OMR ($1.438 USD)** (`63343`) | — | — | 🔴 *(0 Catalog Offers)* |
| **500.00 LKR** (Standard Airtime) | **0.693 OMR ($1.802 USD)** (`3268` / `11296`) | **$1.85 USD** (`471`) | — | 🔴 *(0 Catalog Offers)* |
| **536.00 LKR** (6.5GB 30 Days) | **0.743 OMR ($1.932 USD)** (`56894`) | — | — | 🔴 *(0 Catalog Offers)* |
| **697.00 LKR** (Anytime 10.2GB 30D) | **0.966 OMR ($2.512 USD)** (`63344`) | — | — | 🔴 *(0 Catalog Offers)* |
| **772.00 LKR** (Standard Airtime) | **1.070 OMR ($2.782 USD)** (`11296`) | **$2.86 USD** (`471`) | **$5.60 USD** (`MOBITEL_LK_5-I`) | 🔴 *(0 Catalog Offers)* |
| **999.00 LKR** (Anytime 15.3GB 30D) | **1.384 OMR ($3.598 USD)** (`63345`) | — | — | 🔴 *(0 Catalog Offers)* |
| **1000.00 LKR** (Standard Airtime) | **1.385 OMR ($3.601 USD)** (`3269` / `11296`) | **$3.70 USD** (`471`) | — | 🔴 *(0 Catalog Offers)* |
| **3000.00 LKR** (High Tier Airtime) | **4.155 OMR ($10.803 USD)** (`45002` / `11296`) | **$11.11 USD** (`471`) | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `11296` (Mobitel Sri Lanka Open Range 50 LKR) to `+94710000101`
  - **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  - **Delivered Artifact:** Transaction ID `2240793435`, Wholesale Cost: `0.069 OMR` (~$0.180 USD), Delivered: `50 LKR`
* **Test Request 2:** Product `38281` (Mobitel Sri Lanka 50 LKR Fixed) to `+94710000101`
  - **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  - **Delivered Artifact:** Transaction ID `2240793412`, Wholesale Cost: `0.070 OMR` (~$0.182 USD), Delivered: `50 LKR`
* **Test Request 3:** Product `63341` (Anytime Plan 512MB 7 Days - 58 LKR) to `+94710000101`
  - **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  - **Delivered Artifact:** Transaction ID `2240793435`, Wholesale Cost: `0.081 OMR` (~$0.211 USD), Delivered: `512 MB 7D`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `471` (Mobitel Sri Lanka Airtime, $0.37 USD requested) to `+94710000101`
  - **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  - **Delivered Artifact:** Transaction ID `178452`, Delivered: `99.9 LKR`, Cost: `$0.37 USD`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `MOBITEL_LK_5-I` (Mobitel 772 LKR Top-Up) to `+94710000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_lk_test_1787438768845_mobitel_lk_5-i`, Wholesale Cost: `$5.60 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `MSLK` ("Mobitel Sri Lanka")
* **Validation Regex:** `^940?([0-9]{9})$`
* **Customer Care:** `+94 71 2755777`
* **Catalog Status:** Returns `503 Service Unavailable / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 409` / Open Range `11296` — micro-recharges starting from **20 LKR at 0.028 OMR (~$0.072 USD)** with verified instant pre-prod confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 471` — open range top-ups from 100 LKR / $0.37 USD, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Mobitel` — offer `MOBITEL_LK_5-I` for 772 LKR, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`MSLK`, `priority: 40`, `is_enabled: false`).
5. **TRCSL Sri Lanka Regulatory Compliance:**
   - Mobitel prepaid SIM lines remain valid for **180 consecutive days (6 months)** without recharge or billable activity.
   - Following 180 days, the line transitions into a **90-day Grace/Incoming-Only Period**.
   - If no qualifying transaction occurs within 270 total days (180 + 90), the MSISDN is permanently recycled by SLT-Mobitel.
   - KeepSIMs schedules automated mini-refills on **Day 90–120** (delivering 20–50 LKR for ~$0.07–$0.18 USD via DT One / Reloadly) to reset the TRCSL 180-day countdown clock and preserve customer identity and WhatsApp/banking OTPs indefinitely.
