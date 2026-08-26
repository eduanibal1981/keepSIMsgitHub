# Provider Comparison & Test Report: Vodafone Idea (Vi) India

> **Country:** India (`IN` / `+91` / `IND`)  
> **Carrier:** Vodafone Idea Limited (`Vi`)  
> **Network Type:** MNO (National MNO / 2G-3G-4G)  
> **Balance USSD:** `*199#` or `*111#` | **Customer Care:** `199` / `198` / `+919820098200`  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Zendit** (`zendit`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `IND` (ISO-3) | `IN` (ISO-2) | `IN` (ISO-2) | `IN` (ISO-2) |
| **Carrier / Operator Code** | `2016` ("Vi India") / `1373` / `1372` | `VodafoneIdea` | `716` ("Vodafone-Idea India") / `773` / `774` | `VFIN` ("Vi India") |
| **Delivery Mechanism** | Direct Airtime, Talktime & Packs | Digital Plan Recharge & Bundles | Direct Top-Up & Bundles | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 83 Fixed Products (10–6995 INR) | 8 Fixed Bundles (299–1000 INR) | Fixed (Sandbox 0 amounts) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (INR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Zendit Wholesale (`USD`) / Offer ID | Reloadly Wholesale (`USD`) / Op ID | DingConnect Direct (`VFIN`) |
| :---: | :---: | :---: | :---: | :---: |
| **10.00 INR** (Talktime) | **0.048 OMR ($0.12 USD)** (`28303`) | — | $0.15 USD (`716`) | 🔴 *(0 Catalog Offers)* |
| **20.00 INR** (Talktime) | **0.095 OMR ($0.25 USD)** (`28304`) | — | — | 🔴 *(0 Catalog Offers)* |
| **50.00 INR** (Talktime) | **0.237 OMR ($0.62 USD)** (`28307`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 INR** (Talktime) | **0.473 OMR ($1.23 USD)** (`28314`) | — | — | 🔴 *(0 Catalog Offers)* |
| **299.00 INR** (1.5GB/d 28d) | — | **$3.86 USD** (`VODAFONEIDEA_IN_4.5-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **379.00 INR** (2GB/d 30d) | — | **$4.84 USD** (`VODAFONEIDEA_IN_5.5-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **479.00 INR** (1GB/d 48d) | — | **$6.13 USD** (`VODAFONEIDEA_IN_7-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **500.00 INR** (Talktime) | **2.361 OMR ($6.14 USD)** (`28347`) | **$6.46 USD** (`VODAFONEIDEA_IN_7_FEE`) | — | 🔴 *(0 Catalog Offers)* |
| **579.00 INR** (1.5GB/d 56d) | — | **$7.40 USD** (`VODAFONEIDEA_IN_8.25-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **625.00 INR** (50GB 60d) | — | **$7.99 USD** (`VODAFONEIDEA_IN_9-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **998.00 INR** (2GB/d 84d) | **4.712 OMR ($12.25 USD)** (`56632`) | **$12.88 USD** (`VODAFONEIDEA_IN_13-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **1000.00 INR** (Talktime) | **4.722 OMR ($12.28 USD)** (`28354`) | **$12.90 USD** (`VODAFONEIDEA_IN_14.5_FEE`) | — | 🔴 *(0 Catalog Offers)* |
| **1599.00 INR** (Unl Data 84d) | **7.550 OMR ($19.63 USD)** (`56635`) | — | — | 🔴 *(0 Catalog Offers)* |
| **3499.00 INR** (1.5GB/d 365d) | **16.520 OMR ($42.95 USD)** (`56525`) | — | — | 🔴 *(0 Catalog Offers)* |
| **3599.00 INR** (2GB/d 365d) | **16.992 OMR ($44.18 USD)** (`56646`) | — | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `28303` (Vi India - Topup Plan - 10 INR) to `+919820000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792108`, Wholesale Cost: `0.048 OMR` (~$0.12 USD)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `VODAFONEIDEA_IN_4.5-I-BUNDLE` (299 INR Bundle) to `+919820000101`
* **Status:** `200 OK` $\rightarrow$ `status: ACCEPTED`
* **Transaction Reference:** `test_in_zen_vi_1787359814917`
* **Result:** **Secondary Direct Airtime / Bundle Failover** (`priority: 20`).

### 3. Reloadly (Sandbox API)
* **Operator Mapping:** Operator `716` ("Vodafone-Idea India") / `773` (Bundles) / `774` (Data)
* **Status:** Operator details mapped, sandbox returns 0 amounts.
* **Result:** **Tertiary Backup Route** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `VFIN` ("Vi India")
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 2016` — largest catalog with 83 products starting at 10 INR / 0.048 OMR, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Zendit** (`brand: VodafoneIdea` — 8 structured bundle offers from $3.86 USD, `priority: 20`).
3. **Tertiary Failover:** **Reloadly** (`operatorId: 716`, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`VFIN`, `priority: 40`, `is_enabled: false`).
5. **India TRAI Regulatory Compliance:**
   - Standard 90-day inactivity rule applies.
   - Performing a 10 INR micro-recharge maintains account active status.
   - KeepSIMs schedules automated mini-refills on **Day 80–85** to maintain line continuity.
