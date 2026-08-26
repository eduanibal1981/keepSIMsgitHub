# Provider Comparison & Test Report: Dialog Axiata Sri Lanka

> **Country:** Sri Lanka (`LK` / `+94` / `LKA`)  
> **Carrier:** Dialog Axiata PLC (`Dialog` / Axiata Group)  
> **Network Type:** MNO (National Market Leader / ~17.5M+ Subscribers / ~57% Market Share)  
> **Mobile Prefixes:** `+9477`, `+9476`, `+9474`, `+9475` (Integrated Airtel SL)  
> **Balance USSD / SMS:** Dial `#456#` (Balance & Validity Inquiry), `#123#` (Main Service Portal), `#678#` (Data Portal) | **Recharge USSD:** Dial `*123*<14-digit PIN>#` or MyDialog App / Ez Cash  
> **Customer Care:** `1777` (Local Dialog) / `+94777678678` / `0777678678`  
> **Regulatory Policy (TRCSL Sri Lanka):** 180-day inactivity threshold + 90-day grace/incoming-only period before permanent disconnection & number recycling | Telecom recharges subject to 18% VAT + 2.5% Social Security Contribution Levy (SSCL) + Telecommunications Levy (TL)  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `LKA` (ISO-3) | `LK` (ISO-2) | `LK` (ISO-2) | `LK` (ISO-2) |
| **Carrier / Operator Code** | `360` ("Dialog Sri Lanka") | `472` ("Dialog Sri Lanka") / `1180` ("Dialog Sri Lanka Data") | `Dialog` | `DGLK` ("Dialog Sri Lanka") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Data Bundles | Direct Airtime Top-Up & Data Bundles | Direct Top-Up (`DIALOG_LK_001` - `003`) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `11294` (50–10000 LKR) + 40 Fixed Products (Data/Blaster plans) | Fixed `472` ($0.40–$12.00 USD / 100–3000 LKR) + 5 Data Bundles (`1180`) | Fixed Offers (1551, 3000, 5000 LKR) | 0 Active Products in UAT (503 response) |
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
| **385.00 LKR** (4GB Data 30D) | **0.504 OMR ($1.310 USD)** (`61513`) | — | — | 🔴 *(0 Catalog Offers)* |
| **515.00 LKR** (6GB Data 30D) | **0.675 OMR ($1.755 USD)** (`61514`) | — | — | 🔴 *(0 Catalog Offers)* |
| **698.00 LKR** (Triple Blaster Combo) | **0.914 OMR ($2.376 USD)** (`61510`) | — | — | 🔴 *(0 Catalog Offers)* |
| **915.00 LKR** (12GB Data 30D) | **1.198 OMR ($3.115 USD)** (`61515`) | — | — | 🔴 *(0 Catalog Offers)* |
| **999.00 LKR** (Unlimited Blaster) | **1.308 OMR ($3.401 USD)** (`58022`) | — | — | 🔴 *(0 Catalog Offers)* |
| **1.5GB Data 14 Days** | — | **$0.45 USD** (`1180`) | — | 🔴 *(0 Catalog Offers)* |
| **5.0GB Data 30 Days** | — | **$1.15 USD** (`1180`) | — | 🔴 *(0 Catalog Offers)* |
| **10.0GB Data 30 Days** | — | **$2.05 USD** (`1180`) | — | 🔴 *(0 Catalog Offers)* |
| **1551.00 LKR** (Standard Top-Up) | **2.031 OMR ($5.281 USD)** (`44032`) | — | **$6.50 USD** (`DIALOG_LK_001`) | 🔴 *(0 Catalog Offers)* |
| **3000.00 LKR** (High Tier Airtime) | **3.928 OMR ($10.213 USD)** (`19197`) | **$11.40 USD** (`472` / $12 face) | **$12.50 USD** (`DIALOG_LK_002`) | 🔴 *(0 Catalog Offers)* |
| **5000.00 LKR** (Max Top-Up) | **6.546 OMR ($17.020 USD)** (`44996`) | — | **$21.00 USD** (`DIALOG_LK_003`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `11294` (Open Range 50 LKR) to `+94770000101`
  - **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  - **Delivered Artifact:** Transaction ID `2240793442`, Wholesale Cost: `0.066 OMR` (~$0.171 USD), Delivered: `50 LKR`
* **Test Request 2:** Product `61509` (Call Blaster 298 LKR) to `+94770000101`
  - **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  - **Delivered Artifact:** Transaction ID `2240793430`, Wholesale Cost: `0.390 OMR` (~$1.014 USD), Delivered: `400 Mins AnyNet + 400 SMS`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request 1:** Operator `472` (Dialog Sri Lanka Airtime, $0.40 USD face / $0.38 USD net) to `+94770000101`
  - **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  - **Delivered Artifact:** Transaction ID `178451`, Delivered: `100 LKR`, Cost: `$0.38 USD`
* **Test Request 2:** Operator `1180` (Dialog Sri Lanka Data 1.5GB 14D, $0.45 USD) to `+94770000101`
  - **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  - **Delivered Artifact:** Transaction ID `178454`, Delivered: `144.1 LKR / 1.5GB Data`, Cost: `$0.45 USD`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `DIALOG_LK_001` (Dialog 1551 LKR Top-Up) to `+94770000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_lk_test_1787438766720_dialog_lk_001`, Wholesale Cost: `$6.50 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `DGLK` ("Dialog Sri Lanka")
* **Validation Regex:** `^940?([0-9]{9})$`
* **Catalog Status:** Returns `503 Service Unavailable / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 360` / Open Range `11294` — delivers exact amounts from 50 LKR at **0.066 OMR (~$0.171 USD)** with verified instant pre-prod confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 472` / `1180` — micro-denominations from $0.38 USD and curated 1.5GB–100GB data bundles, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Dialog` — fixed tiers `DIALOG_LK_001` to `003`, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`DGLK`, `priority: 40`, `is_enabled: false`).
5. **TRCSL Sri Lanka Regulatory Compliance:**
   - Dialog prepaid SIM lines remain valid for **180 consecutive days (6 months)** without recharge or billable activity.
   - Following 180 days, the SIM enters a **90-day Grace Period** (incoming calls and SMS remain active, outgoing barred).
   - If no recharge occurs within 270 total days (180 + 90), the MSISDN is permanently recycled to the national pool.
   - KeepSIMs schedules automated mini-refills on **Day 90–120** (delivering 50–100 LKR for ~$0.17–$0.38 USD via DT One / Reloadly) to reset the TRCSL 180-day countdown clock and preserve customer identity and WhatsApp/banking OTPs indefinitely.
