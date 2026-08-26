# Provider Comparison & Test Report: Zong Pakistan (CMPak / China Mobile Pakistan)

> **Country:** Pakistan (`PK` / `+92` / `PAK`)  
> **Carrier:** CMPak Limited (`Zong 4G` / `China Mobile Pakistan`)  
> **Network Type:** MNO (National Pure 4G Pioneer / ~47M+ Subscribers)  
> **Balance USSD / SMS:** Dial `*222#` (USSD Balance Menu - 0.24 PKR fee) | **Recharge USSD:** Dial `*101*<14-digit PIN>#` | **Account App:** My Zong  
> **Customer Care:** `310` / `051-111-222-111` / `+923101111310`  
> **Regulatory Policy (PTA Pakistan):** 180 Days Active Line Validity from last qualifying transaction/recharge | 30 Days Suspension Grace Period before permanent deactivation & recycling | 15% Advance Income Tax (AIT/WHT) deducted on recharge  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `PAK` (ISO-3) | `PK` (ISO-2) | `PK` (ISO-2) | `PK` (ISO-2) |
| **Carrier / Operator Code** | `1515` ("Zong Pakistan") | `352` ("Zong Pakistan") | `Zong` | `ZNPK` ("Zong Pakistan") / `VJPK` (Data) |
| **Delivery Mechanism** | Direct Airtime Top-Up & Super Cards | Direct Airtime Top-Up & Data (`1010`) | Direct Top-Up (`ZONG_PK_OPEN`) & Bundles | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 184 Fixed Products (60–10000 PKR) | Open Range (100–10000 PKR) | 55 Offers (78–6012 PKR open & fixed) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Top-Up** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🟢 **Tertiary Direct Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (PKR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`ZNPK`) |
| :---: | :---: | :---: | :---: | :---: |
| **60.00 PKR** (Weekly Mega TikTok) | **0.101 OMR ($0.263 USD)** (`64272`) | — | — | 🔴 *(0 Catalog Offers)* |
| **78.42 PKR** (Open Min) | — | — | **$0.30 USD** (`ZONG_PK_OPEN` min) | 🔴 *(0 Catalog Offers)* |
| **80.00 PKR** (Airtime Load) | **0.135 OMR ($0.351 USD)** (`43962`) | — | — | 🔴 *(0 Catalog Offers)* |
| **84.00 PKR** (Airtime Load) | **0.141 OMR ($0.367 USD)** (`38661`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 PKR** (Airtime Load) | **0.168 OMR ($0.437 USD)** (`3923`) | **$0.41 USD ($0.3895 net)** (`352`) | — | 🔴 *(0 Catalog Offers)* |
| **105.00 PKR** (Airtime Load) | **0.176 OMR ($0.458 USD)** (`38662`) | — | — | 🔴 *(0 Catalog Offers)* |
| **110.00 PKR** (Airtime Load) | **0.185 OMR ($0.481 USD)** (`16213`) | — | — | 🔴 *(0 Catalog Offers)* |
| **120.00 PKR** (Airtime Load) | **0.202 OMR ($0.525 USD)** (`25327`) | — | — | 🔴 *(0 Catalog Offers)* |
| **150.00 PKR** (Airtime Load) | **0.252 OMR ($0.655 USD)** (`3924`) | **$0.62 USD ($0.589 net)** (`352`) | — | 🔴 *(0 Catalog Offers)* |
| **200.00 PKR** (Airtime Load) | **0.336 OMR ($0.874 USD)** (`3925`) | **$0.82 USD ($0.779 net)** (`352`) | — | 🔴 *(0 Catalog Offers)* |
| **240.00 PKR** (Bundle 001) | — | — | **$1.00 USD** (`ZONG_PK_BUNDLE_001`) | 🔴 *(0 Catalog Offers)* |
| **261.42 PKR** (Fixed 002) | — | — | **$1.00 USD** (`ZONG_PK_002`) | 🔴 *(0 Catalog Offers)* |
| **300.00 PKR** (Airtime Load) | **0.504 OMR ($1.310 USD)** (`3926`) | **$1.24 USD ($1.178 net)** (`352`) | — | 🔴 *(0 Catalog Offers)* |
| **500.00 PKR** (Airtime Load) | **0.840 OMR ($2.184 USD)** (`3927`) | **$2.06 USD ($1.957 net)** (`352`) | **$1.91 USD** (`ZONG_PK_OPEN`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 PKR** (Airtime Load) | **1.680 OMR ($4.368 USD)** (`3928`) | **$4.12 USD ($3.913 net)** (`352`) | **$3.83 USD** (`ZONG_PK_OPEN`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `3923` (Zong Pakistan 100 PKR) to `+923100000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792665`, Wholesale Cost: `0.168 OMR` (~$0.437 USD)
* **Benefits Delivered:** 100 PKR total base credits (86.96 PKR after 15% PTA tax deduction)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `352` (Zong Pakistan, $0.41 USD requested amount) to `+923100000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178401`, Delivered: `99.53 PKR`, Net Wholesale Cost: `$0.3895 USD` (5% international discount applied)
* **Result:** **Secondary Direct Failover** (`priority: 20`).

### 3. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `ZONG_PK_002` (261.42 PKR Top-Up) to `+923100000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `test_pk_zen_zong_1787385064536`, Wholesale Cost: `$1.00 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `ZNPK` ("Zong Pakistan") | Customer Care: `+92-51111-222111`
* **Validation Regex:** `^92[0-9]{10}$`
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1515` — 184 products starting from 60 PKR TikTok micro-packs at 0.101 OMR and 100 PKR airtime at 0.168 OMR wholesale, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Reloadly** (`operatorId: 352` — open range top-up from 100 PKR to 10,000 PKR at $0.3895 USD net for 100 PKR, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Zong` — 55 open-range and bundle offers, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`ZNPK`, `priority: 40`, `is_enabled: false`).
5. **PTA Pakistan Regulatory Compliance:**
   - Zong Pakistan prepaid SIM cards remain active for **180 days** from the date of the last qualifying paid event or recharge.
   - If unrefilled for 180 days, the line enters a **30-day grace/suspension period** (incoming calls only) before permanent cancellation and recycling.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** (using 100 PKR direct top-up / ~$0.44 USD via DT One) to reset the 180-day PTA validity counter indefinitely.