# Provider Comparison & Test Report: Ufone Pakistan (PTCL Group)

> **Country:** Pakistan (`PK` / `+92` / `PAK`)  
> **Carrier:** Pakistan Telecom Mobile Limited (`Ufone 4G` / `PTCL Group`)  
> **Network Type:** MNO (National Carrier / ~25M+ Subscribers)  
> **Balance USSD / SMS:** Dial `*124#` (USSD Balance Menu - 0.24 PKR fee) | **Recharge USSD:** Dial `*333*<14-digit PIN>#` | **Account App:** My Ufone  
> **Customer Care:** `333` / `051-111-333-100` / `+923331111333`  
> **Regulatory Policy (PTA Pakistan):** 180 Days Active Line Validity from last qualifying transaction/recharge | 30 Days Suspension Grace Period before permanent deactivation & recycling | 15% Advance Income Tax (AIT/WHT) deducted on recharge  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `PAK` (ISO-3) | `PK` (ISO-2) | `PK` (ISO-2) | `PK` (ISO-2) |
| **Carrier / Operator Code** | `486` ("Ufone Pakistan") | `355` ("Ufone Pakistan") | `Ufone` | `UFPK` ("Ufone Pakistan") / `VKPK` (Data) |
| **Delivery Mechanism** | Direct Airtime Top-Up & Super Cards | Direct Airtime Top-Up & Bundles (`1308`) | Direct Top-Up (`UFONE_PK_OPEN`) & Bundles | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 210 Fixed Products (60–10000 PKR) | Open Range (100–10000 PKR) | 49 Offers (98–19463 PKR open & fixed) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Top-Up** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🟢 **Tertiary Direct Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (PKR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`UFPK`) |
| :---: | :---: | :---: | :---: | :---: |
| **60.00 PKR** (Daily Shoq Pack) | **0.103 OMR ($0.268 USD)** (`63162`) | — | — | 🔴 *(0 Catalog Offers)* |
| **70.00 PKR** (Weekly SnackVideo) | **0.120 OMR ($0.312 USD)** (`63269`) | — | — | 🔴 *(0 Catalog Offers)* |
| **80.00 PKR** (UPower All In One) | **0.137 OMR ($0.356 USD)** (`59161`) | — | — | 🔴 *(0 Catalog Offers)* |
| **90.00 PKR** (Snapchat Offer) | **0.154 OMR ($0.400 USD)** (`64166`) | — | — | 🔴 *(0 Catalog Offers)* |
| **98.61 PKR** (Open Min) | — | — | **$0.37 USD** (`UFONE_PK_OPEN` min) | 🔴 *(0 Catalog Offers)* |
| **100.00 PKR** (Airtime Load) | **0.168 OMR ($0.437 USD)** (`2788`) | **$0.41 USD ($0.3895 net)** (`355`) | — | 🔴 *(0 Catalog Offers)* |
| **105.00 PKR** (Airtime Load) | **0.177 OMR ($0.460 USD)** (`38605`) | — | — | 🔴 *(0 Catalog Offers)* |
| **110.00 PKR** (Airtime Load) | **0.185 OMR ($0.481 USD)** (`16183`) | — | — | 🔴 *(0 Catalog Offers)* |
| **120.00 PKR** (UPower Rs.120) | **0.202 OMR ($0.525 USD)** (`38606` / `59160`) | — | — | 🔴 *(0 Catalog Offers)* |
| **129.76 PKR** (Fixed 001) | — | — | **$0.49 USD** (`UFONE_PK_001`) | 🔴 *(0 Catalog Offers)* |
| **150.00 PKR** (Airtime Load) | **0.252 OMR ($0.655 USD)** (`2789`) | **$0.62 USD ($0.589 net)** (`355`) | — | 🔴 *(0 Catalog Offers)* |
| **200.00 PKR** (Airtime Load) | **0.336 OMR ($0.874 USD)** (`2790`) | **$0.82 USD ($0.779 net)** (`355`) | — | 🔴 *(0 Catalog Offers)* |
| **259.52 PKR** (Fixed 002) | — | — | **$0.98 USD** (`UFONE_PK_002`) | 🔴 *(0 Catalog Offers)* |
| **300.00 PKR** (Airtime Load) | **0.504 OMR ($1.310 USD)** (`2791`) | **$1.24 USD ($1.178 net)** (`355`) | — | 🔴 *(0 Catalog Offers)* |
| **500.00 PKR** (Airtime Load) | **0.840 OMR ($2.184 USD)** (`2792`) | **$2.06 USD ($1.957 net)** (`355`) | **$1.89 USD** (`UFONE_PK_OPEN`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 PKR** (Airtime Load) | **1.680 OMR ($4.368 USD)** (`2793`) | **$4.12 USD ($3.913 net)** (`355`) | **$3.78 USD** (`UFONE_PK_OPEN`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `2788` (Ufone Pakistan 100 PKR) to `+923300000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792666`, Wholesale Cost: `0.168 OMR` (~$0.437 USD)
* **Benefits Delivered:** 100 PKR total base credits (86.96 PKR after 15% PTA tax deduction)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `355` (Ufone Pakistan, $0.41 USD requested amount) to `+923300000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178402`, Delivered: `99.53 PKR`, Net Wholesale Cost: `$0.3895 USD` (5% international discount applied)
* **Result:** **Secondary Direct Failover** (`priority: 20`).

### 3. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `UFONE_PK_001` (129.76 PKR Top-Up) to `+923300000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `test_pk_zen_ufone_1787385065363`, Wholesale Cost: `$0.49 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `UFPK` ("Ufone Pakistan") | Customer Care: `+92-51111-333100`
* **Validation Regex:** `^92[0-9]{10}$`
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 486` — 210 products starting from 60 PKR Shoq micro-packs at 0.103 OMR and 100 PKR airtime at 0.168 OMR wholesale, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Reloadly** (`operatorId: 355` — open range top-up from 100 PKR to 10,000 PKR at $0.3895 USD net for 100 PKR, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Ufone` — 49 open-range and bundle offers, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`UFPK`, `priority: 40`, `is_enabled: false`).
5. **PTA Pakistan Regulatory Compliance:**
   - Ufone Pakistan prepaid SIM cards remain active for **180 days** from the date of the last qualifying paid event or recharge.
   - If unrefilled for 180 days, the line enters a **30-day grace/suspension period** (incoming calls only) before permanent cancellation and recycling.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** (using 100 PKR direct top-up / ~$0.44 USD via DT One) to reset the 180-day PTA validity counter indefinitely.