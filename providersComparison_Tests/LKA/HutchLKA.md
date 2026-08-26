# Provider Comparison & Test Report: Hutchison Sri Lanka (Hutch / Etisalat)

> **Country:** Sri Lanka (`LK` / `+94` / `LKA`)  
> **Carrier:** Hutchison Telecommunications Lanka (Pvt) Ltd (`Hutch` / CK Hutchison Holdings — merged with Etisalat Sri Lanka)  
> **Network Type:** MNO (~5M+ Subscribers / ~17% Market Share)  
> **Mobile Prefixes:** `+9478`, `+9472` (Legacy Etisalat Sri Lanka)  
> **Balance USSD / SMS:** Dial `*344#` (Main USSD Service Menu & Balance Inquiry), `*131#` (Data Portal) | **Recharge USSD:** Dial `*102*<16-digit PIN>#` or Hutch Self Care App  
> **Customer Care:** `1788` (Local Hutch) / `+94785785785` / `0785785785`  
> **Regulatory Policy (TRCSL Sri Lanka):** 180-day inactivity threshold + 90-day grace/incoming-only period before permanent disconnection & number recycling | Telecom recharges subject to 18% VAT + 2.5% Social Security Contribution Levy (SSCL) + Telecommunications Levy (TL)  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `LKA` (ISO-3) | `LK` (ISO-2) | `LK` (ISO-2) | `LK` (ISO-2) |
| **Carrier / Operator Code** | `1609` ("Hutchison Sri Lanka") | `475` ("Hutchison Sri Lanka") / `1181` ("Hutchison sri Lanka Data") | `Hutch` | `HSLK` ("Hutch (Etisalat) Sri Lanka") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Data Bundles | Direct Airtime Top-Up & Data Bundles | Direct Top-Up (`HUTCH_LK_5-I` / `10-I`) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `11295` (50–3000 LKR) + 56 Fixed Products (Data/Airtime) | Range `475` (100–3000 LKR / $0.63–$18.94 USD) + 6 Data Bundles (`1181`) | Fixed Offers (792 LKR / 1584 LKR) | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (LKR) / Product | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`HSLK`) |
| :---: | :---: | :---: | :---: | :---: |
| **49.00 LKR** (Data 612MB 5D) | **0.067 OMR ($0.174 USD)** (`44592`) | — | — | 🔴 *(0 Catalog Offers)* |
| **50.00 LKR** (Standard Airtime) | **0.068 OMR ($0.177 USD)** (`6076` / `11295`) | — | — | 🔴 *(0 Catalog Offers)* |
| **62.00 LKR** (Data Plan) | **0.084 OMR ($0.218 USD)** (`44593`) | — | — | 🔴 *(0 Catalog Offers)* |
| **98.00 LKR** (Standard Airtime) | **0.133 OMR ($0.346 USD)** (`38280`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 LKR** (Standard Airtime) | **0.135 OMR ($0.351 USD)** (`6077` / `11295`) | **$0.63 USD** (`475`) | — | 🔴 *(0 Catalog Offers)* |
| **123.00 LKR** (Data Plan) | **0.166 OMR ($0.432 USD)** (`44594`) | — | — | 🔴 *(0 Catalog Offers)* |
| **197.00 LKR** (Data Plan) | **0.266 OMR ($0.692 USD)** (`44595`) | — | — | 🔴 *(0 Catalog Offers)* |
| **200.00 LKR** (Standard Airtime) | **0.270 OMR ($0.702 USD)** (`6078` / `11295`) | **$1.26 USD** (`475`) | — | 🔴 *(0 Catalog Offers)* |
| **300.00 LKR** (Standard Airtime) | **0.405 OMR ($1.053 USD)** (`6079` / `11295`) | **$1.89 USD** (`475`) | — | 🔴 *(0 Catalog Offers)* |
| **308.00 LKR** (Data Plan) | **0.415 OMR ($1.079 USD)** (`44597`) | — | — | 🔴 *(0 Catalog Offers)* |
| **500.00 LKR** (Standard Airtime) | **0.674 OMR ($1.752 USD)** (`6081` / `11295`) | **$3.16 USD** (`475`) | — | 🔴 *(0 Catalog Offers)* |
| **1.2GB Data 14 Days** | — | **$0.30 USD** (`1181`) | — | 🔴 *(0 Catalog Offers)* |
| **2.5GB Data 30 Days** | — | **$0.60 USD** (`1181`) | — | 🔴 *(0 Catalog Offers)* |
| **5.0GB Data 30 Days** | — | **$0.90 USD** (`1181`) | — | 🔴 *(0 Catalog Offers)* |
| **10.0GB Data 45 Days** | — | **$1.50 USD** (`1181`) | — | 🔴 *(0 Catalog Offers)* |
| **792.00 LKR** (Fixed Airtime) | **1.068 OMR ($2.777 USD)** (`11295`) | **$5.00 USD** (`475`) | **$5.50 USD** (`HUTCH_LK_5-I`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 LKR** (Standard Airtime) | **1.348 OMR ($3.505 USD)** (`6086` / `11295`) | **$6.31 USD** (`475`) | — | 🔴 *(0 Catalog Offers)* |
| **1584.00 LKR** (Fixed Airtime) | **2.135 OMR ($5.551 USD)** (`11295`) | **$10.00 USD** (`475`) | **$11.00 USD** (`HUTCH_LK_10-I`) | 🔴 *(0 Catalog Offers)* |
| **3000.00 LKR** (Max Range Airtime) | **4.042 OMR ($10.509 USD)** (`59592` / `11295`) | **$18.94 USD** (`475`) | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `11295` (Hutchison Sri Lanka Open Range 50 LKR) to `+94780000101`
  - **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  - **Delivered Artifact:** Transaction ID `2240793437`, Wholesale Cost: `0.068 OMR` (~$0.177 USD), Delivered: `50 LKR`
* **Test Request 2:** Product `6076` (Hutchison Sri Lanka 50 LKR Fixed) to `+94780000101`
  - **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  - **Delivered Artifact:** Transaction ID `2240793419`, Wholesale Cost: `0.068 OMR` (~$0.177 USD), Delivered: `50 LKR`
* **Test Request 3:** Product `44592` (Standard Data Plan 49 LKR / 612MB) to `+94780000101`
  - **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  - **Delivered Artifact:** Transaction ID `2240793439`, Wholesale Cost: `0.066 OMR` (~$0.172 USD), Delivered: `612 MB 5D`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request 1:** Operator `475` (Hutchison Sri Lanka Airtime, $0.63 USD requested) to `+94780000101`
  - **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  - **Delivered Artifact:** Transaction ID `178453`, Delivered: `99.79 LKR`, Cost: `$0.63 USD`
* **Test Request 2:** Operator `1181` (Hutchison Sri Lanka Data 1.2GB, $0.30 USD) to `+94780000101`
  - **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  - **Delivered Artifact:** Transaction ID `178456`, Delivered: `96.07 LKR / 1.2GB Data`, Cost: `$0.30 USD`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `HUTCH_LK_5-I` (Hutch 792 LKR Top-Up) to `+94780000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_lk_test_1787438770596_hutch_lk_5-i`, Wholesale Cost: `$5.50 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `HSLK` ("Hutch (Etisalat) Sri Lanka")
* **Validation Regex:** `^940?([0-9]{9})$`
* **Customer Care:** `+94-785-785-785`
* **Catalog Status:** Returns `503 Service Unavailable / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1609` / Open Range `11295` — exact amounts from 50 LKR at **0.068 OMR (~$0.177 USD)** with verified instant pre-prod confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 475` / `1181` — flexible range top-ups from $0.63 USD and ultra-low cost $0.30 data packs, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Hutch` — fixed offers `HUTCH_LK_5-I` and `10-I`, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`HSLK`, `priority: 40`, `is_enabled: false`).
5. **TRCSL Sri Lanka Regulatory Compliance:**
   - Hutch prepaid SIM lines remain valid for **180 consecutive days (6 months)** without recharge or billable activity.
   - Following 180 days, the line enters a **90-day Grace Period** before permanent disconnection and recycling of both Hutch (`+9478`) and legacy Etisalat (`+9472`) MSISDNs.
   - KeepSIMs schedules automated mini-refills on **Day 90–120** (delivering 49–50 LKR for ~$0.17 USD via DT One) to reset the TRCSL 180-day countdown clock and preserve customer identity and WhatsApp/banking OTPs indefinitely.
