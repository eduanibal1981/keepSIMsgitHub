# Provider Comparison & Test Report: Reliance Jio India

> **Country:** India (`IN` / `+91` / `IND`)  
> **Carrier:** Reliance Jio Infocomm Limited (`Jio`)  
> **Network Type:** MNO (National Market Leader / Pure 4G-5G Network)  
> **Balance USSD / SMS:** Dial `1299` (Missed call for balance & validity SMS) or `*333#` | **Account App:** MyJio  
> **Customer Care:** `198` (Complaints) / `199` (General) / `+919888898888`  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Zendit** (`zendit`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `IND` (ISO-3) | `IN` (ISO-2) | `IN` (ISO-2) | `IN` (ISO-2) |
| **Carrier / Operator Code** | `2808` ("Reliance Jio India") | `Jio` | `786` ("Reliance-Jio India") / `186` (Bundles) | `RJIN` ("Jio India") |
| **Delivery Mechanism** | Direct Top-Up & Unlimited Validity Packs | Digital Plan Recharge & Bundle Packs | Direct Top-Up & Bundles | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 50 Fixed Products (10–3999 INR) | 8 Fixed Bundles (239–3599 INR) | Fixed (Sandbox 0 amounts) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (INR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Zendit Wholesale (`USD`) / Offer ID | Reloadly Wholesale (`USD`) / Op ID | DingConnect Direct (`RJIN`) |
| :---: | :---: | :---: | :---: | :---: |
| **10.00 INR** (Talktime) | **0.048 OMR ($0.12 USD)** (`18518` range / talktime) | — | $0.15 USD (`786`) | 🔴 *(0 Catalog Offers)* |
| **239.00 INR** (1.5GB/d 22d) | — | **$3.08 USD** (`JIO_IN_3-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **299.00 INR** (1.5GB/d 28d) | — | **$3.86 USD** (`JIO_IN_4-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **349.00 INR** (2GB/d 28d) | **1.648 OMR ($4.28 USD)** (`18922`) | **$4.54 USD** (`JIO_IN_6-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **399.00 INR** (2.5GB/d 28d) | **1.884 OMR ($4.90 USD)** (`18798`) | — | — | 🔴 *(0 Catalog Offers)* |
| **501.00 INR** (ISD Pack) | **2.366 OMR ($6.15 USD)** (`18518`) | — | — | 🔴 *(0 Catalog Offers)* |
| **579.00 INR** (1.5GB/d 56d) | — | **$7.40 USD** (`JIO_IN_9-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **629.00 INR** (2GB/d 56d) | — | **$8.12 USD** (`JIO_IN_8-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **799.00 INR** (1.5GB/d 84d) | — | **$10.30 USD** (`JIO_IN_10-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |
| **859.00 INR** (2GB/d 84d) | **4.056 OMR ($10.55 USD)** (`56510`) | — | — | 🔴 *(0 Catalog Offers)* |
| **899.00 INR** (2GB/d 90d) | **4.245 OMR ($11.04 USD)** (`56561`) | — | — | 🔴 *(0 Catalog Offers)* |
| **999.00 INR** (2GB/d 98d) | **4.717 OMR ($12.26 USD)** (`18799`) | — | — | 🔴 *(0 Catalog Offers)* |
| **1000.00 INR** (Topup) | **4.722 OMR ($12.28 USD)** (`29732`) | **$13.29 USD** (`JIO_IN_14.5_FEE`) | — | 🔴 *(0 Catalog Offers)* |
| **3599.00 INR** (2.5GB/d 365d) | **16.992 OMR ($44.18 USD)** (`63436`) | **$46.45 USD** (`JIO_IN_50-I-BUNDLE`) | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `18922` (349 INR Unlimited Calls, Daily 2GB, 28 Days) to `+919800000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792106`, Wholesale Cost: `1.648 OMR` (~$4.28 USD)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `JIO_IN_3-I-BUNDLE` (239 INR Bundle) to `+919800000101`
* **Status:** `200 OK` $\rightarrow$ `status: ACCEPTED`
* **Transaction Reference:** `test_in_zen_jio_1787359814144`
* **Result:** **Secondary Direct Airtime / Bundle Failover** (`priority: 20`).

### 3. Reloadly (Sandbox API)
* **Operator Mapping:** Operator `786` ("Reliance-Jio India") / `186` (Bundles) / `785` (Data)
* **Status:** Operator details mapped, sandbox returns 0 amounts.
* **Result:** **Tertiary Backup Route** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `RJIN` ("Jio India")
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 2808` — massive catalog of 50+ fixed plans from talktime to unlimited 28/84/365-day packs at low wholesale rates, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Zendit** (`brand: Jio` — 8 standardized validity bundle offers from $3.08 USD, `priority: 20`).
3. **Tertiary Failover:** **Reloadly** (`operatorId: 786`, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`RJIN`, `priority: 40`, `is_enabled: false`).
5. **India TRAI Regulatory Compliance:**
   - TRAI mandates deactivation after **90 days of non-usage**.
   - If the main account balance is $\ge$ Rs. 20, non-usage fees may be auto-deducted, but maintaining a valid Service Plan pack prevents deactivation.
   - A **15-day grace period** applies after Day 90 before number release.
   - KeepSIMs schedules automated refills on **Day 80–85** using optimal talktime or validity bundles to keep the Jio line perpetually active.
