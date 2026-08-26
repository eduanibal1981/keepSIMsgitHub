# Provider Comparison & Test Report: BSNL India

> **Country:** India (`IN` / `+91` / `IND`)  
> **Carrier:** Bharat Sanchar Nigam Limited (`BSNL`)  
> **Network Type:** MNO (State-Owned National Telecom / 2G-3G-4G)  
> **Balance USSD:** `*123#` or `*124#` | **Customer Care:** `1503` / `1800-180-1503`  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Zendit** (`zendit`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `IND` (ISO-3) | `IN` (ISO-2) | `IN` (ISO-2) | `IN` (ISO-2) |
| **Carrier / Operator Code** | `1420` ("BSNL India") / `1374` | `BSNL` | `193` ("BSNL India") / `777` / `778` | `BLIN` ("BSNL India") |
| **Delivery Mechanism** | Direct Talktime & Long-Validity Packs | Digital Plan Recharge & Bundles | Direct Top-Up & Bundles | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 31 Fixed Products (10–2399 INR) | 3 Fixed Bundles (199–249 INR) | Fixed (Sandbox 0 amounts) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (INR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Zendit Wholesale (`USD`) / Offer ID | Reloadly Wholesale (`USD`) / Op ID | DingConnect Direct (`BLIN`) |
| :---: | :---: | :---: | :---: | :---: |
| **10.00 INR** (Talktime) | **0.048 OMR ($0.12 USD)** (`11087`) | — | $0.15 USD (`193`) | 🔴 *(0 Catalog Offers)* |
| **16.00 INR** (2GB 1d) | **0.076 OMR ($0.20 USD)** (`60709`) | — | — | 🔴 *(0 Catalog Offers)* |
| **20.00 INR** (Talktime) | **0.095 OMR ($0.25 USD)** (`11369`) | — | — | 🔴 *(0 Catalog Offers)* |
| **50.00 INR** (Talktime) | **0.237 OMR ($0.62 USD)** (`3444`) | — | — | 🔴 *(0 Catalog Offers)* |
| **58.00 INR** (8GB 7d) | **0.274 OMR ($0.71 USD)** (`58638`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 INR** (Talktime) | **0.473 OMR ($1.23 USD)** (`3445`) | — | — | 🔴 *(0 Catalog Offers)* |
| **147.00 INR** (Unl Pack 24d) | **0.695 OMR ($1.81 USD)** (`37592`) | — | — | 🔴 *(0 Catalog Offers)* |
| **199.00 INR** (2GB/d 30d) | **0.940 OMR ($2.44 USD)** (`43615`) | **$2.57 USD** (`BSNL_IN_2.7-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **220.00 INR** (Full TT) | **1.039 OMR ($2.70 USD)** (`15861`) | **$2.84 USD** (`BSNL_IN_3_FEE`) | — | 🔴 *(0 Catalog Offers)* |
| **249.00 INR** (2GB/d 45d) | — | **$3.21 USD** (`BSNL_IN_3-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **347.00 INR** (2GB/d 50d) | **1.639 OMR ($4.26 USD)** (`58645`) | — | — | 🔴 *(0 Catalog Offers)* |
| **500.00 INR** (Talktime) | **2.361 OMR ($6.14 USD)** (`3488`) | — | — | 🔴 *(0 Catalog Offers)* |
| **897.00 INR** (Plan-897 165d) | **4.235 OMR ($11.01 USD)** (`58575`) | — | — | 🔴 *(0 Catalog Offers)* |
| **1499.00 INR** (Plan-1499 300d) | **7.077 OMR ($18.40 USD)** (`58578`) | — | — | 🔴 *(0 Catalog Offers)* |
| **1999.00 INR** (Plan-1999 330d) | **9.438 OMR ($24.54 USD)** (`58579`) | — | — | 🔴 *(0 Catalog Offers)* |
| **2399.00 INR** (Plan-2399 365d) | **11.326 OMR ($29.45 USD)** (`58580`) | — | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `11087` (BSNL India - Topup Plan - 10 INR) to `+919400000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792109`, Wholesale Cost: `0.048 OMR` (~$0.12 USD)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `BSNL_IN_2.7-I-BUNDLE` (199 INR Bundle) to `+919400000101`
* **Status:** `200 OK` $\rightarrow$ `status: ACCEPTED`
* **Transaction Reference:** `test_in_zen_bsnl_1787359815297`
* **Result:** **Secondary Direct Airtime / Bundle Failover** (`priority: 20`).

### 3. Reloadly (Sandbox API)
* **Operator Mapping:** Operator `193` ("BSNL India") / `777` (Bundles) / `778` (Data)
* **Status:** Operator details mapped, sandbox returns 0 amounts.
* **Result:** **Tertiary Backup Route** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `BLIN` ("BSNL India")
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1420` — 31 products from 10 INR talktime at 0.048 OMR up to 300/365-day validity plans at under $30 USD, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Zendit** (`brand: BSNL` — 3 bundle packs from $2.57 USD, `priority: 20`).
3. **Tertiary Failover:** **Reloadly** (`operatorId: 193`, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`BLIN`, `priority: 40`, `is_enabled: false`).
5. **India TRAI & BSNL Regulatory Policy:**
   - BSNL offers India's most generous validity window: **180 days** of inactivity before deactivation.
   - Following Day 180, a 15-day grace period is provided before the line is permanently disconnected.
   - KeepSIMs schedules automated mini-refills on **Day 165–175** to refresh the 180-day cycle cost-effectively.
