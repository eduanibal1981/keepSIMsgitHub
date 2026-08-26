# Provider Comparison & Test Report: Grameenphone Bangladesh

> **Country:** Bangladesh (`BD` / `+880` / `BGD`)  
> **Carrier:** Grameenphone Ltd. (`Grameenphone` / `GP` / Telenor Group)  
> **Network Type:** MNO (National Market Leader / ~83M+ Subscribers / ~43% Market Share)  
> **Balance USSD / SMS:** Dial `*566#` (Main Balance), `*121*1*2#` (Internet Data), `*121*1*3#` (Minutes) | **Recharge USSD:** Dial `*555*<16-digit PIN>#` or FlexiLoad / MyGP App  
> **Customer Care:** `121` (From GP) / `+8801701000121` / `01701000121`  
> **Regulatory Policy (BTRC Bangladesh):** 365-day inactivity rule + 90-day grace/notice period before permanent disconnection & number recycling (total 450 days) | Subject to 15% VAT + 20% Supplementary Duty (SD) + 1% Surcharge on telecom recharges  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `BGD` (ISO-3) | `BD` (ISO-2) | `BD` (ISO-2) | `BD` (ISO-2) |
| **Carrier / Operator Code** | `249` ("GrameenPhone Bangladesh") | `26` ("Grameenphone Bangladesh") / `834` ("Grameenphone Data") | `GrameenPhone` | `GEBD` ("Grameenphone Bangladesh") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Data Bundles | Direct Airtime Top-Up & Data Bundles | Direct Top-Up (`GRAMEENPHONE_BD_OPEN` / `001-018`) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `11747` (20–1000 BDT) + 136 Fixed Products (50–1000 BDT) | Range `26` (20–5000 BDT / $0.18–$44.98 USD) + 8 Data Bundles (`834`) | Open Range (21.25–935.34 BDT) + 18 Fixed Offers (50–1000 BDT) | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (BDT) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`GEBD`) |
| :---: | :---: | :---: | :---: | :---: |
| **20.00 BDT** (Min Entry) | **0.078 OMR ($0.203 USD)** (`11747`) | **$0.18 USD** (`26`) | **$0.27 USD** (`GRAMEENPHONE_BD_OPEN`) | 🔴 *(0 Catalog Offers)* |
| **50.00 BDT** (Standard Top-Up) | **0.194 OMR ($0.504 USD)** (`3428`) | **$0.45 USD** (`26`) | **$0.60 USD** (`GRAMEENPHONE_BD_001`) | 🔴 *(0 Catalog Offers)* |
| **100.00 BDT** (Standard Top-Up) | **0.387 OMR ($1.006 USD)** (`3429`) | **$0.90 USD** (`26`) | **$1.30 USD** (`GRAMEENPHONE_BD_002`) | 🔴 *(0 Catalog Offers)* |
| **149.00 BDT** (2GB 80Mins 7D) | — | **$1.31 USD** (`834`) | — | 🔴 *(0 Catalog Offers)* |
| **179.00 BDT** (10GB 7Days) | — | **$1.57 USD** (`834`) | — | 🔴 *(0 Catalog Offers)* |
| **200.00 BDT** (Standard Top-Up) | **0.773 OMR ($2.010 USD)** (`3430`) | **$1.80 USD** (`26`) | **$2.50 USD** (`GRAMEENPHONE_BD_004`) | 🔴 *(0 Catalog Offers)* |
| **308.00 BDT** (5GB 30Days) | — | **$2.70 USD** (`834`) | — | 🔴 *(0 Catalog Offers)* |
| **400.00 BDT** (Standard Top-Up) | **1.546 OMR ($4.020 USD)** (`3431`) | **$3.60 USD** (`26`) | **$5.00 USD** (`GRAMEENPHONE_BD_008`) | 🔴 *(0 Catalog Offers)* |
| **500.00 BDT** (Standard Top-Up) | **1.932 OMR ($5.023 USD)** (`7412`) | **$4.50 USD** (`26`) | **$6.30 USD** (`GRAMEENPHONE_BD_010`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 BDT** (Max FlexiLoad) | **3.863 OMR ($10.044 USD)** (`7427`) | **$9.00 USD** (`26`) | **$11.82 USD** (`GRAMEENPHONE_BD_OPEN`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `3428` (GrameenPhone Bangladesh 50 BDT) to `+8801700000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793333`, Wholesale Cost: `0.194 OMR` (~$0.504 USD), Delivered: `50 BDT`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `26` (Grameenphone Bangladesh Airtime, $0.50 USD requested) to `+8801700000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178432`, Delivered: `55.58 BDT`, Cost: `$0.50 USD`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `GRAMEENPHONE_BD_001` (Grameenphone 50 BDT Top-Up) to `+8801700000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_bd_test_1787436133085_grameenphone_bd_001`, Wholesale Cost: `$0.60 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `GEBD` ("Grameenphone Bangladesh")
* **Validation Regex:** `^8801(?:3|7)\d{8}$`
* **Catalog Status:** Returns `503 Service Unavailable / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 249` / Open Range `11747` — delivers exact amounts from 20 BDT with verified instant confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 26` / `834` — flexible range and curated data bundles, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: GrameenPhone` — offers `GRAMEENPHONE_BD_OPEN` and fixed tiers 001–018, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`GEBD`, `priority: 40`, `is_enabled: false`).
5. **BTRC Bangladesh Regulatory Compliance:**
   - Grameenphone prepaid SIMs remain active for **365 consecutive days (12 months)** of zero recharge/outgoing activity.
   - Upon reaching 365 days of inactivity, the SIM enters a **90-day grace and notice period** (total **450 days** or 15 months).
   - If no qualifying transaction occurs within 450 days, the number is recycled to the national pool.
   - KeepSIMs schedules automated mini-refills on **Day 180–300** (delivering 20–50 BDT for ~$0.20–$0.50 USD via DT One) to permanently reset the 365-day BTRC active validity window.
