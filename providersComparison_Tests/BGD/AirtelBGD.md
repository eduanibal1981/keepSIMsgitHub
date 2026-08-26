# Provider Comparison & Test Report: Airtel Bangladesh

> **Country:** Bangladesh (`BD` / `+880` / `BGD`)  
> **Carrier:** Airtel Bangladesh (`Airtel` / Robi Axiata Limited / Bharti Airtel)  
> **Network Type:** Sub-Brand / Operating on Robi Axiata Network Rails (Prefix `+88016`)  
> **Balance USSD / SMS:** Dial `*778#` (Main Balance), `*3#` or `*8444*88#` (Internet Data), `*778*2#` (Minutes/Bonus) | **Recharge USSD:** Dial `*123*<16-digit PIN>#` or My Airtel BD App  
> **Customer Care:** `121` (From Airtel) / `+8801678600786` / `01678600786`  
> **Regulatory Policy (BTRC Bangladesh):** 365-day inactivity rule + 90-day grace/notice period before permanent disconnection & number recycling (total 450 days) | Subject to 15% VAT + 20% Supplementary Duty (SD) + 1% Surcharge on telecom recharges  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `BGD` (ISO-3) | `BD` (ISO-2) | `BD` (ISO-2) | `BD` (ISO-2) |
| **Carrier / Operator Code** | `1449` ("Airtel Bangladesh") | `28` ("Airtel Bangladesh") / `832` ("Airtel Bangladesh Data") | `Airtel` | `AXBD` ("Airtel Bangladesh / Cirkle") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Data Bundles | Direct Airtime Top-Up & Data Bundles | Direct Top-Up (`AIRTEL_BD_OPEN` / `001-018`) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `11744` (20–1000 BDT) + 49 Fixed Products (50–1000 BDT) | Range `28` (20–5000 BDT / $0.18–$44.98 USD) | Open Range (10–1000 BDT) + 18 Fixed Offers (50–1000 BDT) | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (BDT) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`AXBD`) |
| :---: | :---: | :---: | :---: | :---: |
| **20.00 BDT** (Min Entry) | **0.078 OMR ($0.203 USD)** (`11744`) | **$0.18 USD** (`28`) | **$0.26 USD** (`AIRTEL_BD_OPEN`) | 🔴 *(0 Catalog Offers)* |
| **50.00 BDT** (Standard Top-Up) | **0.195 OMR ($0.507 USD)** (`3470`) | **$0.45 USD** (`28`) | **$0.60 USD** (`AIRTEL_BD_001`) | 🔴 *(0 Catalog Offers)* |
| **100.00 BDT** (Standard Top-Up) | **0.389 OMR ($1.011 USD)** (`3471`) | **$0.90 USD** (`28`) | **$1.30 USD** (`AIRTEL_BD_002`) | 🔴 *(0 Catalog Offers)* |
| **200.00 BDT** (Standard Top-Up) | **0.778 OMR ($2.023 USD)** (`3472`) | **$1.80 USD** (`28`) | **$2.50 USD** (`AIRTEL_BD_004`) | 🔴 *(0 Catalog Offers)* |
| **300.00 BDT** (Standard Top-Up) | **1.167 OMR ($3.034 USD)** (`8842`) | **$2.70 USD** (`28`) | **$3.80 USD** (`AIRTEL_BD_006`) | 🔴 *(0 Catalog Offers)* |
| **398.00 BDT** (15GB 30Days) | **1.547 OMR ($4.022 USD)** (`1643`) | — | — | 🔴 *(0 Catalog Offers)* |
| **400.00 BDT** (Standard Top-Up) | **1.555 OMR ($4.043 USD)** (`3473`) | **$3.60 USD** (`28`) | **$5.00 USD** (`AIRTEL_BD_008`) | 🔴 *(0 Catalog Offers)* |
| **500.00 BDT** (Standard Top-Up) | **1.944 OMR ($5.054 USD)** (`8843`) | **$4.50 USD** (`28`) | **$6.30 USD** (`AIRTEL_BD_010`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 BDT** (Max Recharge) | **3.887 OMR ($10.106 USD)** (`8846`) | **$9.00 USD** (`28`) | **$12.84 USD** (`AIRTEL_BD_OPEN`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `3470` (Airtel Bangladesh 50 BDT) to `+8801600000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793337`, Wholesale Cost: `0.195 OMR` (~$0.507 USD), Delivered: `50 BDT`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `28` (Airtel Bangladesh Airtime, $0.50 USD requested) to `+8801600000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178435`, Delivered: `55.58 BDT`, Cost: `$0.50 USD`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `AIRTEL_BD_001` (Airtel 50 BDT Top-Up) to `+8801600000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_bd_test_1787436140472_airtel_bd_001`, Wholesale Cost: `$0.60 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `AXBD` ("Airtel / Cirkle Bangladesh")
* **Validation Regex:** `^88016[0-9]{8}$`
* **Catalog Status:** Returns `503 Service Unavailable / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1449` / Open Range `11744` — delivers exact amounts from 20 BDT with verified instant confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 28` / `832` — flexible range and curated data bundles, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Airtel` — offers `AIRTEL_BD_OPEN` and fixed tiers 001–018, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`AXBD`, `priority: 40`, `is_enabled: false`).
5. **BTRC Bangladesh Regulatory Compliance:**
   - Airtel Bangladesh operates on Robi Axiata network infrastructure and adheres to the **365-day inactivity rule** + **90-day grace and notice period** (total 450 days).
   - KeepSIMs schedules automated mini-refills on **Day 180–300** (delivering 20–50 BDT for ~$0.20–$0.50 USD via DT One) to keep the SIM permanently active.
