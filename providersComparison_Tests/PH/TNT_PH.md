# Provider Comparison & Test Report: TNT (Talk 'N Text) Philippines

> **Country:** Philippines (`PH` / `+63` / `PHL`)  
> **Carrier:** TNT (Talk 'N Text / Smart Communications Affiliate)  
> **Network Type:** MNO Sub-Brand (Mass-Market Cellular Network)  
> **Balance USSD / SMS:** Dial `*123#` (USSD Menu) or text `BAL` to `214` | **Account App:** GigaLife / Smart App  
> **Customer Care:** `*888` (TNT Mobile) / `(02) 8888-1111` / `+63288881111`  
> **Regulatory Policy (NTC/DICT):** 1-Year (365 Days) Load Validity (MC 05-12-2017) | 180 Days Zero-Balance Deactivation Window  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `PHL` (ISO-3) | `PH` (ISO-2) | `PH` (ISO-2) | `PH` (ISO-2) |
| **Carrier / Operator Code** | `2897` ("TNT Philippines") | `378` ("TNT Philippines") / `722` (Bundles) / `941` (Data) / `1208` | `TNT` | `STPH` ("SmartTalk n Text Philippines") / `5SPH` |
| **Delivery Mechanism** | Direct Top-Up & SURFSAYA/GIGA Plans | Direct Airtime, Bundles & Digital PIN | Digital Plan & Airtime Recharge | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 39 Fixed Products (5–1000 PHP) | Range ($0.18–$18.30 USD) & 40+ Fixed Promos | 4 Fixed Offers (318–1056 PHP) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (PHP) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`STPH`) |
| :---: | :---: | :---: | :---: | :---: |
| **5.00 PHP** (Micro-Load) | **0.037 OMR ($0.096 USD)** (`18948` 5 PHP) | **$0.09 USD** (`722` 5 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **10.00 PHP** (Micro-Load) | **0.074 OMR ($0.192 USD)** (`18936` 10 PHP) | **$0.18 USD** (`378` range / `722`) | — | 🔴 *(0 Catalog Offers)* |
| **15.00 PHP** (FB 15 / UTP 15) | **0.110 OMR ($0.286 USD)** (`18937` / `27349`) | **$0.27 USD** (`722` 15 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **20.00 PHP** | **0.147 OMR ($0.382 USD)** (`30059` 20 PHP) | **$0.37 USD** (`722` 20 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **25.00 PHP** | **0.183 OMR ($0.476 USD)** (`18938` 25 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **30.00 PHP** (SURFSAYA 30) | **0.220 OMR ($0.572 USD)** (`27364` SURFSAYA) | **$0.55 USD** (`722` 30 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **50.00 PHP** (GIGA VIDEO 50) | **0.366 OMR ($0.952 USD)** (`25706` / `18940`) | **$0.92 USD** (`722` 50 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **60.00 PHP** (GIGA STORIES 60) | **0.440 OMR ($1.144 USD)** (`27370` / `18941`) | — | — | 🔴 *(0 Catalog Offers)* |
| **75.00 PHP** (Triple Data Video+) | **0.549 OMR ($1.427 USD)** (`30462` Triple Data) | — | — | 🔴 *(0 Catalog Offers)* |
| **99.00 PHP** (SURFSAYA 99) | **0.725 OMR ($1.885 USD)** (`27371` / `25707`) | **$1.81 USD** (`722` 99 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **100.00 PHP** | **0.732 OMR ($1.903 USD)** (`18942` 100 PHP) | **$1.83 USD** (`722` 100 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **115.00 PHP** | **0.842 OMR ($2.189 USD)** (`18943` 115 PHP) | **$2.11 USD** (`722` 115 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **120.00 PHP** | **0.879 OMR ($2.285 USD)** (`23475` 120 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **145.00 PHP** | **1.062 OMR ($2.761 USD)** (`23476` 145 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **150.00 PHP** (Panalo 150) | **1.098 OMR ($2.855 USD)** (`1826` / `24263`) | **$2.75 USD** (`722` 150 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **199.00 PHP** (SURFSAYA 199) | **1.457 OMR ($3.788 USD)** (`27301` SURFSAYA) | — | — | 🔴 *(0 Catalog Offers)* |
| **200.00 PHP** | **1.464 OMR ($3.806 USD)** (`18944` 200 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **250.00 PHP** | **1.830 OMR ($4.758 USD)** (`23478` 250 PHP) | **$4.58 USD** (`722` 250 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **300.00 PHP** | **2.196 OMR ($5.710 USD)** (`18945` 300 PHP) | **$5.49 USD** (`722` 300 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **318.00 PHP** | — | — | **$5.42 USD** (`TNT_PH_001`) | 🔴 *(0 Catalog Offers)* |
| **500.00 PHP** | **3.660 OMR ($9.516 USD)** (`18946` 500 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **529.80 PHP** | — | — | **$9.03 USD** (`TNT_PH_002`) | 🔴 *(0 Catalog Offers)* |
| **794.42 PHP** | — | — | **$13.54 USD** (`TNT_PH_004`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 PHP** | **7.319 OMR ($19.029 USD)** (`18947` 1000 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **1056.16 PHP** | — | — | **$18.00 USD** (`TNT_PH_003`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `30059` (TNT Philippines 20 PHP) to `+639080000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792120`, Wholesale Cost: `0.147 OMR` (~$0.382 USD)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `378` ($0.18 USD $\rightarrow$ 9.83 PHP) to `+639080000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178386`, PIN Code `773709733071710`, Cost: `$0.171 USD`
* **Result:** **Secondary Active Direct Failover** (`priority: 20`).

### 3. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `TNT_PH_001` (318 PHP / $5.42 USD) to `+639080000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `test_ph_zen_tnt_1787360735186`
* **Result:** **Tertiary Direct Airtime / Plan Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `STPH` ("SmartTalk n Text Philippines") / `5SPH`
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 2897` — vast 39-product catalog spanning 5 PHP micro-load (0.037 OMR) to SURFSAYA and GIGA plans, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Reloadly** (`operatorId: 378` / `722` — direct airtime and digital PIN delivery from $0.18 USD, `priority: 20`).
3. **Tertiary Failover:** **Zendit** (`brand: TNT` — 4 fixed validity/airtime packs from 318 PHP, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`STPH`, `priority: 40`, `is_enabled: false`).
5. **NTC / DICT Regulatory Compliance:**
   - Under **NTC-DICT Memorandum Circular No. 05-12-2017**, all TNT prepaid loads have a **365-day (1 year)** validity period.
   - Following zero balance, subscribers have a **180-day grace period** (6 months) before the SIM card is terminated.
   - KeepSIMs initiates automated mini-refills on **Day 150–165** of zero balance or prior to expiration, injecting a 5–10 PHP load (0.037–0.074 OMR / ~$0.10–$0.19 USD) to perpetually preserve the TNT mobile number.
