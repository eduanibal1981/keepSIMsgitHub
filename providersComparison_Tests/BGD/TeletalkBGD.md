# Provider Comparison & Test Report: Teletalk Bangladesh

> **Country:** Bangladesh (`BD` / `+880` / `BGD`)  
> **Carrier:** Teletalk Bangladesh Limited (`Teletalk` / 100% State-Owned National Operator)  
> **Network Type:** MNO (State-Owned Carrier / ~6.5M+ Subscribers / Prefix `+88015`)  
> **Balance USSD / SMS:** Dial `*152#` (Main Balance), `*152*1#` (Data / Internet Bundle Balance) | **Recharge USSD:** Dial `*151*<16-digit PIN>#` or MyTeletalk App  
> **Customer Care:** `121` (From Teletalk) / `+8801500121121` / `01500121121`  
> **Regulatory Policy (BTRC Bangladesh):** 365-day inactivity rule + 90-day grace/notice period before permanent disconnection & number recycling (total 450 days) | Subject to 15% VAT + 20% Supplementary Duty (SD) + 1% Surcharge on telecom recharges  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `BGD` (ISO-3) | `BD` (ISO-2) | `BD` (ISO-2) | `BD` (ISO-2) |
| **Carrier / Operator Code** | `1448` ("Teletalk Bangladesh") | `27` ("Teletalk Bangladesh") | `TeleTalk` | `TQBD` ("Teletalk Bangladesh") |
| **Delivery Mechanism** | Direct Airtime Top-Up (Micro-recharge from 10 BDT) | Direct Airtime Top-Up (2% Discount) | Direct Top-Up (`TELETALK_BD_OPEN` / `001-018`) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `11749` (10–1000 BDT) + 59 Fixed Products (10–1000 BDT) | Range `27` (20–5000 BDT / $0.18–$44.98 USD) | Open Range (10–1000 BDT) + 18 Fixed Offers (56.24–1012.32 BDT) | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (BDT) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`TQBD`) |
| :---: | :---: | :---: | :---: | :---: |
| **10.00 BDT** (Ultra Micro-Entry) | **0.039 OMR ($0.101 USD)** (`11749` / `12821`) | — | — | 🔴 *(0 Catalog Offers)* |
| **15.00 BDT** (Micro-Entry) | **0.059 OMR ($0.153 USD)** (`37802`) | — | — | 🔴 *(0 Catalog Offers)* |
| **20.00 BDT** (Min Entry) | **0.078 OMR ($0.203 USD)** (`13613`) | **$0.18 USD ($0.176 net)** (`27`) | **$0.22 USD** (`TELETALK_BD_OPEN`) | 🔴 *(0 Catalog Offers)* |
| **25.00 BDT** (Micro-Entry) | **0.097 OMR ($0.252 USD)** (`13622`) | — | — | 🔴 *(0 Catalog Offers)* |
| **30.00 BDT** (Standard Top-Up) | **0.117 OMR ($0.304 USD)** (`13612`) | — | — | 🔴 *(0 Catalog Offers)* |
| **50.00 BDT** (Standard Top-Up) | **0.194 OMR ($0.504 USD)** (`3466`) | **$0.45 USD ($0.441 net)** (`27`) | — | 🔴 *(0 Catalog Offers)* |
| **56.24 BDT** (Standard Top-Up) | — | — | **$0.60 USD** (`TELETALK_BD_001`) | 🔴 *(0 Catalog Offers)* |
| **100.00 BDT** (Standard Top-Up) | **0.387 OMR ($1.006 USD)** (`3467`) | **$0.90 USD ($0.882 net)** (`27`) | — | 🔴 *(0 Catalog Offers)* |
| **112.48 BDT** (Standard Top-Up) | — | — | **$1.30 USD** (`TELETALK_BD_002`) | 🔴 *(0 Catalog Offers)* |
| **200.00 BDT** (Standard Top-Up) | **0.774 OMR ($2.012 USD)** (`3468`) | **$1.80 USD ($1.764 net)** (`27`) | — | 🔴 *(0 Catalog Offers)* |
| **400.00 BDT** (Standard Top-Up) | **1.548 OMR ($4.025 USD)** (`3469`) | **$3.60 USD ($3.528 net)** (`27`) | — | 🔴 *(0 Catalog Offers)* |
| **500.00 BDT** (Standard Top-Up) | **1.935 OMR ($5.031 USD)** (`8851`) | **$4.50 USD ($4.410 net)** (`27`) | — | 🔴 *(0 Catalog Offers)* |
| **1000.00 BDT** (Max Recharge) | **3.870 OMR ($10.062 USD)** (`8849`) | **$9.00 USD ($8.820 net)** (`27`) | **$11.23 USD** (`TELETALK_BD_OPEN`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `3466` (Teletalk Bangladesh 50 BDT) to `+8801500000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793336`, Wholesale Cost: `0.194 OMR` (~$0.504 USD), Delivered: `50 BDT`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `27` (Teletalk Bangladesh Airtime, $0.50 USD requested) to `+8801500000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178434`, Delivered: `55.58 BDT`, Net Cost: `$0.49 USD` (2% discount applied)
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `TELETALK_BD_001` (Teletalk 56.24 BDT Top-Up) to `+8801500000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_bd_test_1787436138727_teletalk_bd_001`, Wholesale Cost: `$0.60 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `TQBD` ("Teletalk Bangladesh")
* **Validation Regex:** `^88015\d{8}$`
* **Catalog Status:** Returns `503 Service Unavailable / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1448` / Open Range `11749` — ultra low-cost micro-recharge starting from **10 BDT / 0.039 OMR (~$0.10 USD)**, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 27` — 2% wholesale discount, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: TeleTalk` — offers `TELETALK_BD_OPEN` and fixed tiers 001–018, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`TQBD`, `priority: 40`, `is_enabled: false`).
5. **BTRC Bangladesh Regulatory Compliance:**
   - Teletalk prepaid SIMs remain active for **365 consecutive days** of zero usage/recharge.
   - After 365 days, a **90-day grace and notice period** applies before number recycling.
   - KeepSIMs schedules automated mini-refills on **Day 180–300** (delivering 10–20 BDT for ~$0.10–$0.20 USD via DT One) to keep the state-owned line active indefinitely at ultra-low operational cost.
