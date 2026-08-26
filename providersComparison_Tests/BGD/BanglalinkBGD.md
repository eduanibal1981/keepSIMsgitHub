# Provider Comparison & Test Report: Banglalink Bangladesh

> **Country:** Bangladesh (`BD` / `+880` / `BGD`)  
> **Carrier:** Banglalink Digital Communications Ltd. (`Banglalink` / VEON 100%)  
> **Network Type:** MNO (#3 Operator / ~44M+ Subscribers / ~23% Market Share)  
> **Balance USSD / SMS:** Dial `*124#` (Main Balance), `*5000*500#` (Internet Data), `*124*2#` (Bonus/Min) | **Recharge USSD:** Dial `*123*<16-digit PIN>#` or i-TopUp / My Banglalink App  
> **Customer Care:** `121` (From Banglalink) / `+8801911304121` / `01911304121`  
> **Regulatory Policy (BTRC Bangladesh):** 365-day inactivity rule + 90-day grace/notice period before permanent disconnection & number recycling (total 450 days) | Subject to 15% VAT + 20% Supplementary Duty (SD) + 1% Surcharge on telecom recharges  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Zendit** (`zendit`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `BGD` (ISO-3) | `BD` (ISO-2) | `BD` (ISO-2) | `BD` (ISO-2) |
| **Carrier / Operator Code** | `1447` ("Banglalink Bangladesh") | `Banglalink` | `24` / `28` ("Banglalink Bangladesh") / `833` ("Data") | `BGBD` ("Banglalink Bangladesh") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Data Bundles | Direct Top-Up (`BANGLALINK_BD_OPEN` / `001-018`) | Direct Airtime Top-Up & Data Bundles | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `11745` (20–1000 BDT) + 119 Fixed Products (50–1000 BDT) | Open Range (10–1000 BDT) + 18 Fixed Offers (50–1000 BDT) | Range `24` / `28` (20–5000 BDT / $0.18–$44.98 USD) | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (BDT) | DT One Wholesale (`OMR` / `USD`) / Product ID | Zendit Wholesale (`USD`) / Offer ID | Reloadly Wholesale (`USD`) / Op ID | DingConnect Direct (`BGBD`) |
| :---: | :---: | :---: | :---: | :---: |
| **20.00 BDT** (Min Entry) | **0.078 OMR ($0.203 USD)** (`11745`) | **$0.24 USD** (`BANGLALINK_BD_OPEN`) | **$0.18 USD** (`24`/`28`) | 🔴 *(0 Catalog Offers)* |
| **50.00 BDT** (Standard Top-Up) | **0.195 OMR ($0.507 USD)** (`3432`) | **$0.60 USD** (`BANGLALINK_BD_001`) | **$0.45 USD** (`28`) | 🔴 *(0 Catalog Offers)* |
| **99.00 BDT** (3GB 72 Hours) | **0.385 OMR ($1.001 USD)** (`2414`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 BDT** (Standard Top-Up) | **0.389 OMR ($1.011 USD)** (`3433`) | **$1.30 USD** (`BANGLALINK_BD_002`) | **$0.90 USD** (`28`) | 🔴 *(0 Catalog Offers)* |
| **199.00 BDT** (15GB 7 Days) | **0.773 OMR ($2.010 USD)** (`2516`) | — | — | 🔴 *(0 Catalog Offers)* |
| **200.00 BDT** (Standard Top-Up) | **0.777 OMR ($2.020 USD)** (`3434`) | **$2.50 USD** (`BANGLALINK_BD_004`) | **$1.80 USD** (`28`) | 🔴 *(0 Catalog Offers)* |
| **400.00 BDT** (Standard Top-Up) | **1.553 OMR ($4.038 USD)** (`3435`) | **$5.00 USD** (`BANGLALINK_BD_008`) | **$3.60 USD** (`28`) | 🔴 *(0 Catalog Offers)* |
| **500.00 BDT** (Standard Top-Up) | **1.941 OMR ($5.047 USD)** (`7411`) | **$6.30 USD** (`BANGLALINK_BD_010`) | **$4.50 USD** (`28`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 BDT** (Max Recharge) | **3.881 OMR ($10.091 USD)** (`7420`) | **$12.03 USD** (`BANGLALINK_BD_OPEN`) | **$9.00 USD** (`28`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `3432` (Banglalink Bangladesh 50 BDT) to `+8801900000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793335`, Wholesale Cost: `0.195 OMR` (~$0.507 USD), Delivered: `50 BDT`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `BANGLALINK_BD_001` (Banglalink 50 BDT Top-Up) to `+8801900000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_bd_test_1787436136971_banglalink_bd_001`, Wholesale Cost: `$0.60 USD`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Reloadly (Sandbox API) — 🟢 Tertiary Failover
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `28` (Banglalink Bangladesh Airtime, $0.50 USD requested) to `+8801900000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178435`, Delivered: `55.58 BDT`, Cost: `$0.50 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `BGBD` ("Banglalink Bangladesh")
* **Validation Regex:** `^8801(?:4|9)\d{8}$`
* **Catalog Status:** Returns `503 Service Unavailable / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1447` / Open Range `11745` — delivers exact amounts from 20 BDT with verified instant confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Zendit** (`brand: Banglalink` — offers `BANGLALINK_BD_OPEN` and fixed tiers 001–018, `priority: 20`).
3. **Tertiary Direct Failover:** **Reloadly** (`operatorId: 28` / `24` — flexible range, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`BGBD`, `priority: 40`, `is_enabled: false`).
5. **BTRC Bangladesh Regulatory Compliance:**
   - Banglalink prepaid SIMs remain active for **365 consecutive days** of zero usage/recharge.
   - After 365 days, a **90-day grace and notice period** applies before number de-registration and recycling.
   - KeepSIMs schedules automated mini-refills on **Day 180–300** (delivering 20–50 BDT for ~$0.20–$0.50 USD via DT One) to keep the SIM permanently active.
