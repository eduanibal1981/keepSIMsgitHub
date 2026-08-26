# Provider Comparison & Test Report: Turkcell Turkey

> **Country:** Turkey (`TR` / `+90` / `TUR`)  
> **Carrier:** Turkcell İletişim Hizmetleri A.Ş. (`Turkcell` / `Lifecell` / `Turkcell Global`)  
> **Network Type:** MNO (National Market Leader / ~38M+ Subscribers)  
> **Balance USSD / SMS:** Dial `*123#` (Instant balance on screen) | **Recharge USSD:** Dial `*122*<16-digit PIN>#` | **Account App:** Turkcell (Dijital Operatör) / Paycell  
> **Customer Care:** `532` (From Turkcell) / `0532 532 00 00` / `+905325320000`  
> **Regulatory Policy (BTK Turkey):** 180 Days Active Line Validity from last recharge/top-up | 365 Days Passive/Grace Period before permanent disconnection & number recycling | Subject to monthly Wireless Usage Fee (*Telsiz Kullanım Ücreti* ~15-20 TRY/mo) and Special Communication Tax (ÖİV 10%)  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `TUR` (ISO-3) | `TR` (ISO-2) | `TR` (ISO-2) | `TR` (ISO-2) |
| **Carrier / Operator Code** | `679` ("Turkcell Turkey") | `509` ("Turkcell Turkey") / `1177` ("Turkcell Turkey Data") | `Turkcell` | `TZTR` ("Turkcell Turkey") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Data Bundles | Direct Airtime Top-Up & Data Bundles | Direct Top-Up (`TURKCELL_TR_10-I` / `15-I`) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** (3% International Discount) | **`USD`** | **`OMR`** |
| **Catalog Format** | 16 Fixed Products (200–1960 TRY) | 4 Airtime (65–400 TRY) + 38 Data Bundles (90–3455 TRY) | 2 Fixed Offers (200 & 300 TRY) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Primary Micro-Refill Route** (`is_primary: true`, `priority: 10`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (TRY) | Reloadly Wholesale (`USD` / Net) / Op ID | DT One Wholesale (`OMR` / `USD`) / Product ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`TZTR`) |
| :---: | :---: | :---: | :---: | :---: |
| **65.00 TRY** (Micro-Airtime) | **$1.82 USD ($1.765 net)** (`509`) | — | — | 🔴 *(0 Catalog Offers)* |
| **70.00 TRY** (Micro-Airtime) | **$1.96 USD ($1.901 net)** (`509`) | — | — | 🔴 *(0 Catalog Offers)* |
| **90.00 TRY** (Oyna Paketi) | **$2.52 USD ($2.444 net)** (`1177`) | — | — | 🔴 *(0 Catalog Offers)* |
| **145.00 TRY** (Oyna İzle Paketi) | **$4.07 USD ($3.948 net)** (`1177`) | — | — | 🔴 *(0 Catalog Offers)* |
| **200.00 TRY** (Standard Top-Up) | — | **2.056 OMR ($5.346 USD)** (`67167`) | **$10.00 USD** (`TURKCELL_TR_10-I`) | 🔴 *(0 Catalog Offers)* |
| **213.00 TRY** (Günlük 6GB) | **$5.97 USD ($5.791 net)** (`1177`) | — | — | 🔴 *(0 Catalog Offers)* |
| **215.00 TRY** (Haftalık 1000 DK) | **$6.03 USD ($5.849 net)** (`1177`) | — | — | 🔴 *(0 Catalog Offers)* |
| **250.00 TRY** (Standard Top-Up) | **$7.01 USD ($6.799 net)** (`509`) | — | — | 🔴 *(0 Catalog Offers)* |
| **300.00 TRY** (Standard Top-Up) | — | **3.083 OMR ($8.016 USD)** (`67168`) | **$15.00 USD** (`TURKCELL_TR_15-I`) | 🔴 *(0 Catalog Offers)* |
| **395.00 TRY** (Fırsat 1200 DK) | — | **3.899 OMR ($10.137 USD)** (`67169`) | — | 🔴 *(0 Catalog Offers)* |
| **400.00 TRY** (Standard Top-Up) | **$11.21 USD ($10.874 net)** (`509`) | — | — | 🔴 *(0 Catalog Offers)* |
| **499.00 TRY** (Fırsat 1GB) | — | **4.925 OMR ($12.805 USD)** (`67171`) | — | 🔴 *(0 Catalog Offers)* |
| **500.00 TRY** (Standard Top-Up) | — | **5.138 OMR ($13.359 USD)** (`56570`) | — | 🔴 *(0 Catalog Offers)* |
| **750.00 TRY** (Standard Top-Up) | — | **7.707 OMR ($20.038 USD)** (`56571`) | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🟢 Primary Micro-Refill Route
* **API Endpoint:** `POST /topups`
* **Test Request 1:** Operator `509` (Turkcell Turkey Airtime 65 TRY, $1.82 USD requested) to `+905320000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178407`, Delivered: `65 TRY`, Net Wholesale Cost: `$1.7654 USD` (3% international discount applied)
* **Test Request 2:** Operator `1177` (Turkcell Turkey Data 90 TRY "Oyna Paketi", $2.52 USD requested) to `+905320000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL` (Transaction ID `178408`, Net Cost: `$2.4444 USD`)
* **Result:** **Primary Active Micro-Refill Route** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API) — 🟢 Secondary Direct Failover
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `67167` (Turkcell 200 TRY) to `+905320000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240792688`, Wholesale Cost: `2.047 OMR` (~$5.322 USD), Delivered: `200 TRY`
* **Result:** **Secondary Direct Failover** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `TURKCELL_TR_10-I` (Turkcell 200 TRY Top-Up) to `+905320000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `test_tr_zen_1787386161850_turkcell_tr_10_i`, Wholesale Cost: `$10.00 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `TZTR` ("Turkcell Turkey")
* **Validation Regex:** `^90[0-9]{10}$`
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Micro-Refill Route:** **Reloadly** (`operatorId: 509` / `1177` — lowest entry price in Turkey starting from 65 TRY airtime at **$1.765 USD** and 90 TRY bundle at **$2.444 USD**, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **DT One** (`operatorId: 679` — comprehensive catalog of 16 denominations from 200 TRY at 2.047 OMR, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Turkcell` — offers `TURKCELL_TR_10-I` [200 TRY] & `15-I` [300 TRY], `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`TZTR`, `priority: 40`, `is_enabled: false`).
5. **BTK Turkey Regulatory Compliance:**
   - Turkcell prepaid SIM cards remain active for **180 days** from the date of the last top-up.
   - If unrefilled for 180 days, the line enters a **365-day passive period** where outgoing calls are blocked but incoming service may continue temporarily, before permanent line cancellation and number forfeiture.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** (delivering 65 TRY airtime for ~$1.76 USD via Reloadly) to reset the 180-day BTK active validity window continuously.
