# Provider Comparison & Test Report: Globe Telecom Philippines

> **Country:** Philippines (`PH` / `+63` / `PHL`)  
> **Carrier:** Globe Telecom, Inc. (`Globe` / `GOMO`)  
> **Network Type:** MNO (Major National Carrier)  
> **Balance USSD / SMS:** Dial `*143#` (USSD Menu) or text `BAL` to `222` | **Account App:** GlobeOne  
> **Customer Care:** `211` (Mobile) / `(02) 7730-1000` / `+63277301000`  
> **Regulatory Policy (NTC/DICT):** 1-Year (365 Days) Load Validity (MC 05-12-2017) | 120 Days Zero-Balance Deactivation Window  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `PHL` (ISO-3) | `PH` (ISO-2) | `PH` (ISO-2) | `PH` (ISO-2) |
| **Carrier / Operator Code** | `246` ("Globe Telecom Philippines") | `371` ("Globe Telecom Philippines") / `374` (Bundles) / `937` (Data) | `Globe` | `GBPH` ("BS_Globe Philippines") / `G0PH` |
| **Delivery Mechanism** | Direct Top-Up & GoSURF/GoUNLI Plans | Direct Airtime, Bundles & Data Top-Up | Digital Plan & Airtime Recharge | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 22 Fixed Products (10–1000 PHP) | Fixed (10–1000 PHP / $0.18–$18.32 USD) | 5 Fixed Offers (400–1200 PHP) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (PHP) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`GBPH`) |
| :---: | :---: | :---: | :---: | :---: |
| **10.00 PHP** (Micro-Load) | **0.076 OMR ($0.198 USD)** (`12824` 10 PHP) | **$0.18 USD** (`371` 10 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **15.00 PHP** | **0.114 OMR ($0.296 USD)** (`12825` 15 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **20.00 PHP** | — | **$0.37 USD** (`371` 20 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **25.00 PHP** | **0.189 OMR ($0.491 USD)** (`2693` 25 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **30.00 PHP** (GoSURF30) | **0.220 OMR ($0.572 USD)** (`25602`) / `0.227 OMR` (`3824`) | **$0.55 USD** (`371` 30 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **50.00 PHP** | **0.378 OMR ($0.983 USD)** (`2694` 50 PHP) | **$0.92 USD** (`371` 50 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **60.00 PHP** | **0.454 OMR ($1.180 USD)** (`3825` 60 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **95.00 PHP** (GoUNLI95) | **0.696 OMR ($1.810 USD)** (`28537` GoUNLI95) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 PHP** | **0.756 OMR ($1.966 USD)** (`4749` 100 PHP) | **$1.83 USD** (`371` 100 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **150.00 PHP** | **1.133 OMR ($2.946 USD)** (`2602` 150 PHP) | **$2.75 USD** (`371` 150 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **299.00 PHP** (GoSURF299) | **2.189 OMR ($5.691 USD)** (`1734` GoSURF299) | — | — | 🔴 *(0 Catalog Offers)* |
| **300.00 PHP** | **2.266 OMR ($5.892 USD)** (`2654` 300 PHP) | **$5.49 USD** (`371` 300 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **400.00 PHP** | — | — | **$7.76 USD** (`GLOBE_PH_8_FEE`) | 🔴 *(0 Catalog Offers)* |
| **500.00 PHP** | **3.777 OMR ($9.820 USD)** (`2655` 500 PHP) | **$9.16 USD** (`371` 500 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **700.00 PHP** | **5.287 OMR ($13.746 USD)** (`17015` 700 PHP) | — | **$13.58 USD** (`GLOBE_PH_14_FEE`) | 🔴 *(0 Catalog Offers)* |
| **800.00 PHP** | — | — | **$15.53 USD** (`GLOBE_PH_16_FEE`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 PHP** | **7.553 OMR ($19.638 USD)** (`2656` 1000 PHP) | **$18.32 USD** (`371` 1000 PHP) | **$19.41 USD** (`GLOBE_PH_20_FEE`) | 🔴 *(0 Catalog Offers)* |
| **1200.00 PHP** | — | — | **$23.29 USD** (`GLOBE_PH_24_FEE`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `12824` (Globe Telecom Philippines 10 PHP) to `+639170000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792121`, Wholesale Cost: `0.076 OMR` (~$0.198 USD)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `371` ($0.18 USD $\rightarrow$ 10 PHP) to `+639170000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178379`, Cost: `$0.1764 USD`
* **Result:** **Secondary Active Direct Failover** (`priority: 20`).

### 3. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `GLOBE_PH_8_FEE` (400 PHP / $7.76 USD) to `+639170000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `test_ph_zen_globe_1787360732398`
* **Result:** **Tertiary Direct Airtime / Plan Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `GBPH` ("BS_Globe Philippines") / `G0PH`
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 246` — ultra-low wholesale entry at 0.076 OMR / ~$0.198 USD for 10 PHP micro-load, complete catalog of 22 fixed products including GoSURF and GoUNLI packs, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Reloadly** (`operatorId: 371` — reliable sandbox/production direct airtime top-up from 10 PHP / $0.18 USD, `priority: 20`).
3. **Tertiary Failover:** **Zendit** (`brand: Globe` — 5 large denomination bundles 400–1200 PHP, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`GBPH`, `priority: 40`, `is_enabled: false`).
5. **NTC / DICT Regulatory Compliance:**
   - Under **NTC-DICT Memorandum Circular No. 05-12-2017**, all prepaid loads carry a minimum **1-year (365 days)** expiration window.
   - Once the main balance reaches zero, Globe allows a **120-day grace period** before permanent SIM deactivation and number recycling.
   - KeepSIMs schedules automated mini-refills on **Day 100–110** of zero-balance or before line expiry, injecting a 10 PHP micro-refill ($0.198 USD) to extend the line's validity for an additional 365 days.
