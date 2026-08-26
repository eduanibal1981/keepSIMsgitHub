# Provider Comparison & Test Report: Robi Axiata Bangladesh

> **Country:** Bangladesh (`BD` / `+880` / `BGD`)  
> **Carrier:** Robi Axiata Limited (`Robi` / `Axiata Group` / Bharti Airtel)  
> **Network Type:** MNO (#2 Operator / ~58M+ Subscribers / ~30% Market Share)  
> **Balance USSD / SMS:** Dial `*222#` (Main Balance), `*3#` or `*8444*88#` (Internet Data), `*222*2#` (Minutes/Bonus) | **Recharge USSD:** Dial `*123*<16-digit PIN>#` or EasyLoad / My Robi App  
> **Customer Care:** `121` (From Robi) / `+8801819400400` / `01819400400`  
> **Regulatory Policy (BTRC Bangladesh):** 365-day inactivity rule + 90-day grace/notice period before permanent disconnection & number recycling (total 450 days) | Subject to 15% VAT + 20% Supplementary Duty (SD) + 1% Surcharge on telecom recharges  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `BGD` (ISO-3) | `BD` (ISO-2) | `BD` (ISO-2) | `BD` (ISO-2) |
| **Carrier / Operator Code** | `1446` ("Robi Bangladesh") | `25` ("Robi Bangladesh") / `835` ("Robi Bangladesh Data") | `Robi` | `RLBD` ("Robi Bangladesh") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Data Bundles | Direct Airtime Top-Up & Data Bundles | Direct Top-Up (`ROBI_BD_OPEN` / `001-018`) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `11748` (20–1000 BDT) + 92 Fixed Products (50–1000 BDT) | Range `25` (20–5000 BDT / $0.18–$44.98 USD) + 13 Data Bundles (`835`) | Open Range (10–1000 BDT) + 18 Fixed Offers (50–1000 BDT) | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (BDT) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`RLBD`) |
| :---: | :---: | :---: | :---: | :---: |
| **20.00 BDT** (Min Entry) | **0.078 OMR ($0.203 USD)** (`11748`) | **$0.18 USD** (`25`) | **$0.24 USD** (`ROBI_BD_OPEN`) | 🔴 *(0 Catalog Offers)* |
| **50.00 BDT** (Standard Top-Up) | **0.195 OMR ($0.507 USD)** (`3424`) | **$0.45 USD** (`25`) | **$0.60 USD** (`ROBI_BD_001`) | 🔴 *(0 Catalog Offers)* |
| **68.00 BDT** (3GB 1Day) | — | **$0.60 USD** (`835`) | — | 🔴 *(0 Catalog Offers)* |
| **98.00 BDT** (3GB 3Days) | — | **$0.86 USD** (`835`) | — | 🔴 *(0 Catalog Offers)* |
| **100.00 BDT** (Standard Top-Up) | **0.389 OMR ($1.011 USD)** (`3425`) | **$0.90 USD** (`25`) | **$1.30 USD** (`ROBI_BD_002`) | 🔴 *(0 Catalog Offers)* |
| **198.00 BDT** (15GB 7Days) | — | **$1.74 USD** (`835`) | — | 🔴 *(0 Catalog Offers)* |
| **200.00 BDT** (Standard Top-Up) | **0.778 OMR ($2.023 USD)** (`3426`) | **$1.80 USD** (`25`) | **$2.50 USD** (`ROBI_BD_004`) | 🔴 *(0 Catalog Offers)* |
| **228.00 BDT** (30GB 7Days) | **0.887 OMR ($2.306 USD)** (`1889`) | **$2.00 USD** (`835`) | — | 🔴 *(0 Catalog Offers)* |
| **308.00 BDT** (5GB 30Days) | — | **$2.70 USD** (`835`) | — | 🔴 *(0 Catalog Offers)* |
| **400.00 BDT** (Standard Top-Up) | **1.555 OMR ($4.043 USD)** (`3427`) | **$3.60 USD** (`25`) | **$5.00 USD** (`ROBI_BD_008`) | 🔴 *(0 Catalog Offers)* |
| **500.00 BDT** (Standard Top-Up) | **1.944 OMR ($5.054 USD)** (`7413`) | **$4.50 USD** (`25`) | **$6.30 USD** (`ROBI_BD_010`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 BDT** (Max Recharge) | **3.887 OMR ($10.106 USD)** (`7423`) | **$9.00 USD** (`25`) | **$11.90 USD** (`ROBI_BD_OPEN`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `3424` (Robi Bangladesh 50 BDT) to `+8801800000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793334`, Wholesale Cost: `0.195 OMR` (~$0.507 USD), Delivered: `50 BDT`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `25` (Robi Bangladesh Airtime, $0.50 USD requested) to `+8801800000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178433`, Delivered: `55.58 BDT`, Cost: `$0.50 USD`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `ROBI_BD_001` (Robi 50 BDT Top-Up) to `+8801800000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_bd_test_1787436135218_robi_bd_001`, Wholesale Cost: `$0.60 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `RLBD` ("Robi Bangladesh")
* **Validation Regex:** `^88018\d{8}$`
* **Catalog Status:** Returns `503 Service Unavailable / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1446` / Open Range `11748` — delivers exact amounts from 20 BDT with verified instant confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 25` / `835` — flexible range and comprehensive data bundles, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Robi` — offers `ROBI_BD_OPEN` and fixed tiers 001–018, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`RLBD`, `priority: 40`, `is_enabled: false`).
5. **BTRC Bangladesh Regulatory Compliance:**
   - Robi prepaid lines remain active for **365 consecutive days** of zero usage/recharge.
   - After 365 days, a **90-day grace and notice period** applies before number de-registration and recycling.
   - KeepSIMs schedules automated mini-refills on **Day 180–300** (delivering 20–50 BDT for ~$0.20–$0.50 USD via DT One) to keep the SIM permanently active.
