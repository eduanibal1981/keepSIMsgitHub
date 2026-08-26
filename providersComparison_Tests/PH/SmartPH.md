# Provider Comparison & Test Report: Smart Communications Philippines

> **Country:** Philippines (`PH` / `+63` / `PHL`)  
> **Carrier:** Smart Communications, Inc. (`Smart` / `SmartBro` / `Sun Cellular`)  
> **Network Type:** MNO (Major National Carrier / PLDT Group)  
> **Balance USSD / SMS:** Dial `*123#` (USSD Menu) or text `BAL` to `214` | **Account App:** GigaLife / Smart App  
> **Customer Care:** `*888` (Mobile) / `(02) 8888-1111` / `+63288881111`  
> **Regulatory Policy (NTC/DICT):** 1-Year (365 Days) Load Validity (MC 05-12-2017) | 180 Days Zero-Balance Deactivation Window  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `PHL` (ISO-3) | `PH` (ISO-2) | `PH` (ISO-2) | `PH` (ISO-2) |
| **Carrier / Operator Code** | `570` ("Smart Philippines") / `1934` (SmartBro) / `2952` | `372` ("Smart Philippines") / `720` (Bundles) / `789` (Data) / `1207` | `Smart` | `SMPH` ("Smart (SunCellular) Philippines") / `0SPH` |
| **Delivery Mechanism** | Direct Top-Up & Giga Plans (Video/Stories/Magic) | Direct Airtime, Bundles & Promo Top-Up | Digital Plan & Airtime Recharge | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 38 Fixed Products (5–1000 PHP) | Range ($0.27–$18.30 USD) & 50+ Fixed Promos | 5 Fixed Offers (300–1000 PHP) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (PHP) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`SMPH`) |
| :---: | :---: | :---: | :---: | :---: |
| **5.00 PHP** (Micro-Load) | **0.037 OMR ($0.096 USD)** (`22752` 5 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **10.00 PHP** (Standard Micro) | **0.074 OMR ($0.192 USD)** (`7684` 10 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **15.00 PHP** | **0.110 OMR ($0.286 USD)** (`12823` 15 PHP) | **$0.27 USD** (`372` range / `1207`) | — | 🔴 *(0 Catalog Offers)* |
| **20.00 PHP** | **0.147 OMR ($0.382 USD)** (`30058` 20 PHP) | **$0.37 USD** (`1207` 20 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **25.00 PHP** | **0.183 OMR ($0.476 USD)** (`16831` 25 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **30.00 PHP** | **0.220 OMR ($0.572 USD)** (`2599` 30 PHP) | **$0.55 USD** (`1207` 30 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **50.00 PHP** (Giga Video 50) | **0.366 OMR ($0.952 USD)** (`3586` / `28295`) | **$0.92 USD** (`1207` 50 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **60.00 PHP** (Giga Video 60) | **0.440 OMR ($1.144 USD)** (`2600` / `27286`) | **$1.10 USD** (`1207` 60 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **75.00 PHP** (Triple Data Video+) | **0.549 OMR ($1.427 USD)** (`26752` Triple Data) | **$1.37 USD** (`1207` 75 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **99.00 PHP** (Giga Stories 99) | **0.725 OMR ($1.885 USD)** (`29823` / `20161`) | **$1.81 USD** (`1207` 99 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **100.00 PHP** | **0.732 OMR ($1.903 USD)** (`3587` 100 PHP) | **$1.83 USD** (`1207` 100 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **115.00 PHP** | **0.842 OMR ($2.189 USD)** (`2601` 115 PHP) | **$2.11 USD** (`1207` 115 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **145.00 PHP** | **1.062 OMR ($2.761 USD)** (`18881` 145 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **150.00 PHP** | **1.098 OMR ($2.855 USD)** (`24262` 150 PHP) | **$2.75 USD** (`1207` 150 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **200.00 PHP** | **1.464 OMR ($3.806 USD)** (`2657` 200 PHP) | **$3.66 USD** (`1207` 200 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **300.00 PHP** | **2.196 OMR ($5.710 USD)** (`2658` 300 PHP) | **$5.49 USD** (`1207` 300 PHP) | **$6.20 USD** (`SMART_PH_6_FEE`) | 🔴 *(0 Catalog Offers)* |
| **400.00 PHP** | — | — | **$8.26 USD** (`SMART_PH_8_FEE`) | 🔴 *(0 Catalog Offers)* |
| **500.00 PHP** | **3.660 OMR ($9.516 USD)** (`2659` 500 PHP) | **$9.16 USD** (`1207` 500 PHP) | **$10.33 USD** (`SMART_PH_10_FEE`) | 🔴 *(0 Catalog Offers)* |
| **800.00 PHP** | — | — | **$16.54 USD** (`SMART_PH_16_FEE`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 PHP** | **7.319 OMR ($19.029 USD)** (`2660` 1000 PHP) | **$18.32 USD** (`372` range) | **$20.67 USD** (`SMART_PH_20_FEE`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `7684` (Smart Philippines 10 PHP) to `+639180000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792118`, Wholesale Cost: `0.074 OMR` (~$0.192 USD)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `372` ($0.27 USD $\rightarrow$ 14.74 PHP) to `+639180000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178384`, Cost: `$0.2565 USD`
* **Result:** **Secondary Active Direct Failover** (`priority: 20`).

### 3. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `SMART_PH_6_FEE` (300 PHP / $6.20 USD) to `+639180000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `test_ph_zen_smart_1787360733380`
* **Result:** **Tertiary Direct Airtime / Bundle Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `SMPH` ("Smart (SunCellular) Philippines") / `0SPH`
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 570` — comprehensive catalog of 38 fixed plans from 5 PHP / 0.037 OMR to 1000 PHP, industry-lowest micro-refill cost, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Reloadly** (`operatorId: 372` — range recharge from $0.27 USD + full promo catalog `1207`, `priority: 20`).
3. **Tertiary Failover:** **Zendit** (`brand: Smart` — 5 large denomination bundles 300–1000 PHP, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`SMPH`, `priority: 40`, `is_enabled: false`).
5. **NTC / DICT Regulatory Compliance:**
   - Under **NTC-DICT Memorandum Circular No. 05-12-2017**, all prepaid recharges have a **365-day (1 year)** validity period.
   - Once the account balance drops to zero, Smart Communications grants a **180-day grace period** (6 months) before the SIM card is terminated and disconnected.
   - KeepSIMs executes automated mini-refills on **Day 150–165** of zero-balance or prior to expiry, purchasing a 5 or 10 PHP load (0.037–0.074 OMR / ~$0.10–$0.19 USD) to perpetually maintain the Smart connection.
