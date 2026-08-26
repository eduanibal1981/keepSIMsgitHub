# Provider Comparison & Test Report: Telenor Pakistan

> **Country:** Pakistan (`PK` / `+92` / `PAK`)  
> **Carrier:** Telenor Pakistan (Pvt.) Limited (`Telenor`)  
> **Network Type:** MNO (Major National Carrier / ~45M+ Subscribers)  
> **Balance USSD / SMS:** Dial `*444#` (USSD Balance Menu - 0.24 PKR fee) | **Recharge USSD:** Dial `*555*<14-digit PIN>#` | **Account App:** My Telenor  
> **Customer Care:** `345` / `042-111-345-100` / `+923451111345`  
> **Regulatory Policy (PTA Pakistan):** 180 Days Active Line Validity from last qualifying transaction/recharge | 30 Days Suspension Grace Period before permanent deactivation & recycling | 15% Advance Income Tax (AIT/WHT) deducted on recharge  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `PAK` (ISO-3) | `PK` (ISO-2) | `PK` (ISO-2) | `PK` (ISO-2) |
| **Carrier / Operator Code** | `655` ("Telenor Pakistan") | `353` ("Telenor Pakistan") | `Telenor` | `TPPK` ("Telenor Pakistan") / `UWPK` (Data) |
| **Delivery Mechanism** | Direct Airtime Top-Up & EasyCards | Direct Airtime Top-Up & Bundles (`804`) | Direct Top-Up (`TELENOR_PK_OPEN`) & Bundles | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 220 Fixed Products (100–10000 PKR) | Open Range (100–5000 PKR) | 41 Offers (77–4396 PKR open & fixed) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Top-Up** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🟢 **Tertiary Direct Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (PKR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`TPPK`) |
| :---: | :---: | :---: | :---: | :---: |
| **77.58 PKR** (Open Min) | — | — | **$0.30 USD** (`TELENOR_PK_OPEN` min) | 🔴 *(0 Catalog Offers)* |
| **100.00 PKR** (Airtime Load) | **0.168 OMR ($0.437 USD)** (`3378`) | **$0.41 USD ($0.3895 net)** (`353`) | — | 🔴 *(0 Catalog Offers)* |
| **105.00 PKR** (Airtime Load) | **0.177 OMR ($0.460 USD)** (`38545`) | — | — | 🔴 *(0 Catalog Offers)* |
| **110.00 PKR** (Airtime Load) | **0.185 OMR ($0.481 USD)** (`16168`) | — | — | 🔴 *(0 Catalog Offers)* |
| **120.00 PKR** (3 Day Hybrid) | **0.202 OMR ($0.525 USD)** (`25314` / `67270`) | — | — | 🔴 *(0 Catalog Offers)* |
| **125.00 PKR** (Airtime Load) | **0.210 OMR ($0.546 USD)** (`38164`) | — | — | 🔴 *(0 Catalog Offers)* |
| **129.32 PKR** (Fixed Bundle) | — | — | **$0.51 USD** (`TELENOR_PK_001`) | 🔴 *(0 Catalog Offers)* |
| **150.00 PKR** (Airtime Load) | **0.252 OMR ($0.655 USD)** (`3379`) | **$0.62 USD ($0.589 net)** (`353`) | — | 🔴 *(0 Catalog Offers)* |
| **200.00 PKR** (Airtime Load) | **0.336 OMR ($0.874 USD)** (`3380`) | **$0.82 USD ($0.779 net)** (`353`) | — | 🔴 *(0 Catalog Offers)* |
| **258.63 PKR** (Fixed Bundle) | — | — | **$1.01 USD** (`TELENOR_PK_002`) | 🔴 *(0 Catalog Offers)* |
| **300.00 PKR** (Airtime Load) | **0.504 OMR ($1.310 USD)** (`3381`) | **$1.24 USD ($1.178 net)** (`353`) | — | 🔴 *(0 Catalog Offers)* |
| **500.00 PKR** (Airtime Load) | **0.840 OMR ($2.184 USD)** (`3382`) | **$2.06 USD ($1.957 net)** (`353`) | **$1.95 USD** (`TELENOR_PK_OPEN`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 PKR** (Airtime Load) | **1.680 OMR ($4.368 USD)** (`3383`) | **$4.12 USD ($3.913 net)** (`353`) | **$3.91 USD** (`TELENOR_PK_OPEN`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `3378` (Telenor Pakistan 100 PKR) to `+923400000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792664`, Wholesale Cost: `0.168 OMR` (~$0.437 USD)
* **Benefits Delivered:** 100 PKR total base credits (86.96 PKR after 15% PTA tax deduction)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `353` (Telenor Pakistan, $0.41 USD requested amount) to `+923400000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178400`, Delivered: `99.53 PKR`, Net Wholesale Cost: `$0.3895 USD` (5% international discount applied)
* **Result:** **Secondary Direct Failover** (`priority: 20`).

### 3. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `TELENOR_PK_001` (129.32 PKR Top-Up) to `+923400000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `test_pk_zen_telenor_1787385063603`, Wholesale Cost: `$0.51 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `TPPK` ("Telenor Pakistan") | Customer Care: `+92 42 111 345 100`
* **Validation Regex:** `^92[0-9]{10}$`
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 655` — extensive catalog of 220 products starting from 100 PKR airtime at 0.168 OMR wholesale, EasyCards, and hybrid packs, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Reloadly** (`operatorId: 353` — open range top-up from 100 PKR to 5,000 PKR at $0.3895 USD net for 100 PKR, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Telenor` — 41 open-range and bundle offers, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`TPPK`, `priority: 40`, `is_enabled: false`).
5. **PTA Pakistan Regulatory Compliance:**
   - Telenor Pakistan prepaid SIM cards remain active for **180 days** from the date of the last qualifying paid event or recharge.
   - If unrefilled for 180 days, the line enters a **30-day grace/suspension period** (incoming calls only) before permanent cancellation and recycling.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** (using 100 PKR direct top-up / ~$0.44 USD via DT One) to reset the 180-day PTA validity counter indefinitely.