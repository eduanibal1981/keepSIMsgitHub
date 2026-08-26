# Provider Comparison & Test Report: Jazz Pakistan (PMCL / Mobilink / Warid)

> **Country:** Pakistan (`PK` / `+92` / `PAK`)  
> **Carrier:** Pakistan Mobile Communications Limited (`Jazz` / `Mobilink` / `Warid`)  
> **Network Type:** MNO (National Market Leader / ~70M+ Subscribers)  
> **Balance USSD / SMS:** Dial `*111#` (USSD Balance Menu - 0.24 PKR fee) | **Recharge USSD:** Dial `*123*<14-digit PIN>#` | **Account App:** Jazz World  
> **Customer Care:** `111` / `042-111-300-300` / `+923000000111`  
> **Regulatory Policy (PTA Pakistan):** 180 Days Active Line Validity from last qualifying transaction/recharge | 30 Days Suspension Grace Period before permanent deactivation & recycling | 15% Advance Income Tax (AIT/WHT) deducted on recharge  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `PAK` (ISO-3) | `PK` (ISO-2) | `PK` (ISO-2) | `PK` (ISO-2) |
| **Carrier / Operator Code** | `400` ("Jazz Pakistan") | `354` ("Jazz Pakistan") / `351` ("Warid Pakistan") | `Jazz` / `Warid` | `MBPK` ("Jazz Pakistan") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Data Bundles | Direct Airtime Top-Up & Bundles (`1306`) | Direct Top-Up (`JAZZ_PK_OPEN`) & Bundles | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 196 Fixed Products (40–10000 PKR) | Open Range (200–10000 PKR) | 52 Offers (98–12257 PKR open & fixed) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Top-Up** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🟢 **Tertiary Direct Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (PKR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`MBPK`) |
| :---: | :---: | :---: | :---: | :---: |
| **40.00 PKR** (Weekly SMS) | **0.068 OMR ($0.177 USD)** (`61899`) | — | — | 🔴 *(0 Catalog Offers)* |
| **50.00 PKR** (Super GupShup) | **0.084 OMR ($0.218 USD)** (`59774`) | — | — | 🔴 *(0 Catalog Offers)* |
| **70.00 PKR** (PUBG Offer) | **0.119 OMR ($0.309 USD)** (`63170`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 PKR** (Airtime Load) | **0.168 OMR ($0.437 USD)** (`3760`) | — | **$0.38 USD** (`JAZZ_PK_OPEN` min $0.38) | 🔴 *(0 Catalog Offers)* |
| **110.00 PKR** (Airtime Load) | **0.185 OMR ($0.481 USD)** (`16153`) | — | — | 🔴 *(0 Catalog Offers)* |
| **120.00 PKR** (3 Day Max) | **0.202 OMR ($0.525 USD)** (`19761` / `64275`) | — | — | 🔴 *(0 Catalog Offers)* |
| **150.00 PKR** (Weekly Extreme) | **0.252 OMR ($0.655 USD)** (`6088` / `66890`) | — | — | 🔴 *(0 Catalog Offers)* |
| **200.00 PKR** (Airtime Load) | **0.336 OMR ($0.874 USD)** (`3761`) | **$0.82 USD ($0.779 net)** (`354`) | — | 🔴 *(0 Catalog Offers)* |
| **245.15 PKR** (Fixed Bundle) | — | — | **$0.94 USD** (`JAZZ_PK_002`) | 🔴 *(0 Catalog Offers)* |
| **300.00 PKR** (Airtime Load) | **0.504 OMR ($1.310 USD)** (`3762`) | **$1.24 USD ($1.178 net)** (`354`) | — | 🔴 *(0 Catalog Offers)* |
| **500.00 PKR** (Airtime Load) | **0.840 OMR ($2.184 USD)** (`3763`) | **$2.06 USD ($1.957 net)** (`354`) | **$1.93 USD** (`JAZZ_PK_OPEN`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 PKR** (Airtime Load) | **1.680 OMR ($4.368 USD)** (`3764`) | **$4.12 USD ($3.913 net)** (`354`) | **$3.86 USD** (`JAZZ_PK_OPEN`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `3760` (Jazz Pakistan 100 PKR) to `+923000000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792663`, Wholesale Cost: `0.168 OMR` (~$0.437 USD)
* **Benefits Delivered:** 100 PKR total base credits (86.96 PKR after standard 15% PTA WHT deduction)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `354` (Jazz Pakistan, $0.82 USD requested amount) to `+923000000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178399`, Delivered: `199.06 PKR`, Net Wholesale Cost: `$0.779 USD` (5% international discount applied)
* **Result:** **Secondary Direct Failover** (`priority: 20`).

### 3. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `JAZZ_PK_002` (245.15 PKR Top-Up) to `+923000000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `test_pk_zen_jazz_1787385062178`, Wholesale Cost: `$0.94 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `MBPK` ("Jazz Pakistan") | Customer Care: `+92-21-111-301301`
* **Validation Regex:** `^92[0-9]{10}$`
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 400` — deep inventory of 196 products starting from 40 PKR micro-packs at 0.068 OMR and 100 PKR direct airtime at 0.168 OMR wholesale, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Reloadly** (`operatorId: 354` — flexible open range top-up from 200 PKR to 10,000 PKR with 5% discount, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Jazz` — 52 open-range and fixed offers, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`MBPK`, `priority: 40`, `is_enabled: false`).
5. **PTA Pakistan Regulatory Compliance:**
   - Jazz prepaid SIM cards remain active for **180 days** from the date of the last qualifying paid event or recharge.
   - If unrefilled for 180 days, the line enters a **30-day grace/suspension period** (incoming calls only) before permanent cancellation, balance forfeiture, and number recycling.
   - 15% Advance Income Tax (AIT) is deducted by the Pakistani government upon load delivery.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** (using a 100 PKR direct top-up / ~$0.44 USD via DT One) to reset the 180-day PTA validity counter indefinitely.