# Provider Comparison & Test Report: Ncell Nepal

> **Country:** Nepal (`NP` / `+977` / `NPL`)  
> **Carrier:** Ncell Axiata / Spectrlite UK (`Ncell` / `Ncell Nepal`)  
> **Network Type:** MNO (Private Market Leader / ~13M+ Subscribers / ~47% Mobile Market Share)  
> **Prefixes:** `980`, `981`, `982`, `970` (`+977980xxxxxxx`, `+977981xxxxxxx`, `+977982xxxxxxx`, `+977970xxxxxxx`)  
> **Balance USSD / SMS:** Dial `*901#` or `*101#` (Main Balance & Expiry), `*901#` (Data Pack / Internet Balance) | **Recharge USSD:** Dial `*902*<16-digit PIN>#` or `*102*<16-digit PIN>#` or Ncell App  
> **Customer Care:** `9005` (From Ncell) / `9805554444` / `+9779805554444`  
> **Regulatory Policy (NTA Nepal):** 180-day dormancy threshold followed by a 90-day grace period (total 270 days) before permanent line disconnection and MSISDN recycling. Recharges of 30–50 NPR reset line validity. Recharges subject to statutory Telecommunication Service Charge (TSC: 10%) and 13% VAT.  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `NPL` (ISO-3) | `NP` (ISO-2) | `NP` (ISO-2) | `NP` (ISO-2) |
| **Carrier / Operator Code** | `1442` ("NCell Nepal") | `328` ("NCell Nepal") / `1121` ("NCell Nepal Data") | `Ncell` | `NCNP` ("Ncell Nepal") / `6NNP` ("Ncell Nepal Data") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Data Bundles | Direct Airtime Top-Up & Data Bundles | Direct Fixed Top-Up (`NCELL_NP_6-I` to `24-I`) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `11938` (50–3000 NPR) + 65 Fixed Airtime & Data Packs | Range `328` (50–5000 NPR / $0.38–$37.72 USD) + 13 Data Bundles (`1121`) | 4 Fixed Offers (`NCELL_NP_6-I` to `NCELL_NP_24-I`) | 0 Active Products in UAT (ResultCode: 3) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (NPR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`NCNP`) |
| :---: | :---: | :---: | :---: | :---: |
| **30.00 NPR** (100MB Data Sangai Beema) | **0.093 OMR ($0.242 USD)** (`47518`) | **$0.2185 USD** (`1121`) | — | 🔴 *(0 Catalog Offers)* |
| **40.00 NPR** (1.5GB 1-Day Data) | **0.124 OMR ($0.322 USD)** (`60718`) | — | — | 🔴 *(0 Catalog Offers)* |
| **50.00 NPR** (Min Direct Airtime) | **0.154 OMR ($0.400 USD)** (`4658`) | **$0.361 USD** (`328`) | — | 🔴 *(0 Catalog Offers)* |
| **60.00 NPR** (Standard Airtime) | **0.185 OMR ($0.481 USD)** (`15932`) | **$0.433 USD** (`328`) | — | 🔴 *(0 Catalog Offers)* |
| **75.00 NPR** (Standard Airtime) | **0.231 OMR ($0.601 USD)** (`15841`) | **$0.542 USD** (`328`) | — | 🔴 *(0 Catalog Offers)* |
| **90.00 NPR** (500MB Data PLUS) | **0.278 OMR ($0.723 USD)** (`59073`) | **$0.649 USD** (`328`) | — | 🔴 *(0 Catalog Offers)* |
| **99.00 NPR** (49 Mins, 2GB 7Days) | **0.305 OMR ($0.793 USD)** (`56086`) | **$0.714 USD** (`328`) | — | 🔴 *(0 Catalog Offers)* |
| **100.00 NPR** (Standard Top-Up) | **0.308 OMR ($0.801 USD)** (`4568`) | **$0.722 USD** (`328`) | — | 🔴 *(0 Catalog Offers)* |
| **200.00 NPR** (Standard Top-Up) | **0.616 OMR ($1.602 USD)** (`4572`) | **$1.444 USD** (`328`) | — | 🔴 *(0 Catalog Offers)* |
| **500.00 NPR** (Standard Top-Up) | **1.541 OMR ($4.007 USD)** (`4573`) | **$3.610 USD** (`328`) | — | 🔴 *(0 Catalog Offers)* |
| **668.82 NPR** (Tier 1 Top-Up) | **2.060 OMR ($5.356 USD)** (`11938`) | **$4.829 USD** (`328`) | **$5.60 USD** (`NCELL_NP_6-I`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 NPR** (Standard Top-Up) | **3.082 OMR ($8.013 USD)** (`4575`) | **$7.220 USD** (`328`) | — | 🔴 *(0 Catalog Offers)* |
| **1337.64 NPR** (Tier 2 Top-Up) | **4.120 OMR ($10.712 USD)** (`11938`) | **$9.658 USD** (`328`) | **$11.20 USD** (`NCELL_NP_12-I`) | 🔴 *(0 Catalog Offers)* |
| **2006.46 NPR** (Tier 3 Top-Up) | **6.180 OMR ($16.068 USD)** (`11938`) | **$14.487 USD** (`328`) | **$16.80 USD** (`NCELL_NP_18-I`) | 🔴 *(0 Catalog Offers)* |
| **2675.28 NPR** (Tier 4 Top-Up) | **8.240 OMR ($21.424 USD)** (`11938`) | **$19.316 USD** (`328`) | **$22.30 USD** (`NCELL_NP_24-I`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `4658` (NCell Nepal 50 NPR Airtime) to `+9779800000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793437`, Wholesale Cost: `0.154 OMR` (~$0.400 USD), Delivered: `50 NPR`
* **Test Request 2:** Product `47518` (NCell RS 30 - 100MB Data Sangai Beema) to `+9779800000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793439`, Wholesale Cost: `0.093 OMR` (~$0.242 USD), Delivered: `30 NPR (100 MB)`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request 1:** Operator `328` (NCell Nepal Airtime, $1.00 USD requested) to `+9779800000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178469`, Delivered: `132.57 NPR`, Wholesale Cost: `$0.95 USD` (5% discount applied)
* **Test Request 2:** Operator `1121` (NCell Nepal Data $0.23 USD bundle) to `+9779800000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178470`, Delivered: `30 NPR`, Wholesale Cost: `$0.2185 USD`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request 1:** Offer `NCELL_NP_6-I` (Ncell 6 USD / 668.82 NPR Top-Up) to `+9779800000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
  * **Transaction Reference:** `zen_np_test_1787438808427_ncell_np_6_i`, Wholesale Cost: `$5.60 USD`
* **Test Request 2:** Offer `NCELL_NP_12-I` (Ncell 12 USD / 1337.64 NPR Top-Up) to `+9779800000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
  * **Transaction Reference:** `zen_np_test_1787438810107_ncell_np_12_i`, Wholesale Cost: `$11.20 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `NCNP` ("Ncell Nepal") / `6NNP` ("Ncell Nepal Data")
* **Validation Regex:** `^977(9(?:80|81|82|70|71|72|73)[0-9]{7})$`
* **Catalog Status:** Returns `ResultCode: 3 / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1442` / Open Range `11938` + Fixed 30–50 NPR micro-packs — lowest cost entry starting at 0.093 OMR / $0.24 USD, instant pre-prod confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 328` / `1121` — flexible range top-up from $0.38 USD and 13 curated data bundles from $0.23 USD, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Ncell` — offers `NCELL_NP_6-I`, `NCELL_NP_12-I`, `NCELL_NP_18-I`, `NCELL_NP_24-I`, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`NCNP`, `priority: 40`, `is_enabled: false`).
5. **NTA Nepal Regulatory & Dormancy Compliance:**
   - Ncell prepaid lines require active recharge or usage within **180 days**.
   - Following 180 days of dormancy, the line enters a **90-day grace period** (total **270 days**).
   - If no qualifying recharge occurs within 270 days, the MSISDN is permanently revoked and recycled into the national pool.
   - KeepSIMs automated mini-refill schedule: Dispatches a **30–50 NPR micro-refill** ($0.24–$0.40 USD via DT One) on **Day 90–120** to indefinitely extend line life.
