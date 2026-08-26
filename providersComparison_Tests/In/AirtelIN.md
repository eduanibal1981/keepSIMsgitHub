# Provider Comparison & Test Report: Bharti Airtel India

> **Country:** India (`IN` / `+91` / `IND`)  
> **Carrier:** Bharti Airtel Limited (`Airtel`)  
> **Network Type:** MNO (National Market Leader / 2G-4G-5G)  
> **Balance USSD:** `*121#` or `*123#` | **Customer Care:** `121` / `198` / `+919810198101`  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Zendit** (`zendit`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `IND` (ISO-3) | `IN` (ISO-2) | `IN` (ISO-2) | `IN` (ISO-2) |
| **Carrier / Operator Code** | `1371` ("Airtel India") | `Airtel` | `200` ("Airtel India") / `775` (Bundles) | `AIIN` ("Airtel India") |
| **Delivery Mechanism** | Direct Talktime & Unlimited Packs | Digital Plan Recharge & Bundles | Direct Top-Up & Bundles | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 39 Fixed Products (10–5000 INR) | 9 Fixed Bundles (349–3599 INR) | Fixed (Sandbox 0 amounts) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (INR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Zendit Wholesale (`USD`) / Offer ID | Reloadly Wholesale (`USD`) / Op ID | DingConnect Direct (`AIIN`) |
| :---: | :---: | :---: | :---: | :---: |
| **10.00 INR** (Talktime) | **0.048 OMR ($0.12 USD)** (`8141`) | — | $0.15 USD (`200`) | 🔴 *(0 Catalog Offers)* |
| **22.00 INR** (1GB 1d) | **0.104 OMR ($0.27 USD)** (`56491`) | — | — | 🔴 *(0 Catalog Offers)* |
| **33.00 INR** (2GB 1d) | **0.156 OMR ($0.41 USD)** (`56492`) | — | — | 🔴 *(0 Catalog Offers)* |
| **99.00 INR** (Unl Data 2d) | **0.468 OMR ($1.22 USD)** (`42261`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 INR** (6GB 30d) | **0.473 OMR ($1.23 USD)** (`60618`) | — | — | 🔴 *(0 Catalog Offers)* |
| **199.00 INR** (2GB 28d) | **0.940 OMR ($2.44 USD)** (`28723`) | — | — | 🔴 *(0 Catalog Offers)* |
| **349.00 INR** (1.5GB/d 28d) | **1.648 OMR ($4.28 USD)** (`28746`) | **$4.51 USD** (`AIRTEL_IN_4.5-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **409.00 INR** (2GB/d 28d) | **1.931 OMR ($5.02 USD)** (`56487`) | **$5.28 USD** (`AIRTEL_IN_5.5-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **500.00 INR** (Talktime) | **2.361 OMR ($6.14 USD)** (`3039`) | **$6.64 USD** (`AIRTEL_IN_7_FEE`) | — | 🔴 *(0 Catalog Offers)* |
| **579.00 INR** (1.5GB/d 56d) | — | **$7.25 USD** (`AIRTEL_IN_7.5-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **649.00 INR** (2GB/d 56d) | — | **$8.15 USD** (`AIRTEL_IN_8.5-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **859.00 INR** (1.5GB/d 84d) | — | **$11.70 USD** (`AIRTEL_IN_11-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **979.00 INR** (2GB/d 84d) | **4.622 OMR ($12.02 USD)** (`56490`) | **$12.63 USD** (`AIRTEL_IN_13-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **1000.00 INR** (Talktime) | **4.722 OMR ($12.28 USD)** (`3040`) | **$13.29 USD** (`AIRTEL_IN_14.5_FEE`) | — | 🔴 *(0 Catalog Offers)* |
| **1199.00 INR** (2.5GB/d 84d) | **5.661 OMR ($14.72 USD)** (`28764`) | — | — | 🔴 *(0 Catalog Offers)* |
| **3599.00 INR** (2GB/d 365d) | **16.992 OMR ($44.18 USD)** (`28771`) | **$45.16 USD** (`AIRTEL_IN_48-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **5000.00 INR** (Talktime) | **23.606 OMR ($61.38 USD)** (`26785`) | — | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `8141` (Topup Plan - 10 INR) to `+919810000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792107`, Wholesale Cost: `0.048 OMR` (~$0.12 USD)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `AIRTEL_IN_11-I-BUNDLE` (859 INR Bundle) to `+919810000101`
* **Status:** `200 OK` $\rightarrow$ `status: ACCEPTED`
* **Transaction Reference:** `test_in_zen_airtel_1787359814529`
* **Result:** **Secondary Direct Airtime / Bundle Failover** (`priority: 20`).

### 3. Reloadly (Sandbox API)
* **Operator Mapping:** Operator `200` ("Airtel India") / `775` (Bundles)
* **Status:** Operator details mapped, sandbox returns 0 amounts.
* **Result:** **Tertiary Backup Route** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `AIIN` ("Airtel India")
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1371` — 39 products offering micro-talktime starting from 10 INR at 0.048 OMR / $0.12 USD up to 365-day annual packs, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Zendit** (`brand: Airtel` — 9 bundle offers from $4.51 USD, `priority: 20`).
3. **Tertiary Failover:** **Reloadly** (`operatorId: 200`, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`AIIN`, `priority: 40`, `is_enabled: false`).
5. **India TRAI Regulatory Compliance:**
   - Airtel lines operate under TRAI's 90-day inactivity mandate.
   - Performing a micro-recharge (e.g. 10 INR talktime) or renewing an active service pack resets the line validity counter.
   - KeepSIMs schedules automated mini-refills on **Day 80–85** to ensure the connection never enters the 15-day suspension quarantine.
