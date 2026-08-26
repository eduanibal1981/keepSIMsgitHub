# Provider Comparison & Test Report: MTNL (Delhi / Mumbai) India

> **Country:** India (`IN` / `+91` / `IND`)  
> **Carrier:** Mahanagar Telephone Nigam Limited (`MTNL`)  
> **Network Type:** MNO (State-Owned Metro Operator: Delhi NCR & Mumbai Circles)  
> **Balance USSD:** `*444#` or `*123#` | **Customer Care:** `1500` / `1800-22-1500`  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Zendit** (`zendit`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `IND` (ISO-3) | `IN` (ISO-2) | `IN` (ISO-2) | `IN` (ISO-2) |
| **Carrier / Operator Code** | `368` ("MTNL India") | `MTNL` (0 offers) | `194` ("MTNL India" - 503) | `MNIN` ("MTNL India") |
| **Delivery Mechanism** | Direct Regular Talktime Top-Up | N/A (0 Offers) | N/A (Inactive) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | `USD` | `USD` | `OMR` |
| **Catalog Format** | 5 Fixed Products (10–1000 INR) | 0 Active Offers | Inactive (503) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Exclusive Primary** (`is_primary: true`, `priority: 10`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (INR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Zendit Direct (`MTNL`) | Reloadly Direct (`194`) | DingConnect Direct (`MNIN`) |
| :---: | :---: | :---: | :---: | :---: |
| **10.00 INR** (Talktime) | **0.048 OMR ($0.12 USD)** (`13500`) | 🔴 *(0 Catalog Offers)* | 🔴 *(503 Inactive)* | 🔴 *(0 Catalog Offers)* |
| **50.00 INR** (Talktime) | **0.237 OMR ($0.62 USD)** (`13502`) | 🔴 *(0 Catalog Offers)* | 🔴 *(503 Inactive)* | 🔴 *(0 Catalog Offers)* |
| **100.00 INR** (Talktime) | **0.473 OMR ($1.23 USD)** (`13503`) | 🔴 *(0 Catalog Offers)* | 🔴 *(503 Inactive)* | 🔴 *(0 Catalog Offers)* |
| **500.00 INR** (Talktime) | **2.361 OMR ($6.14 USD)** (`13506`) | 🔴 *(0 Catalog Offers)* | 🔴 *(503 Inactive)* | 🔴 *(0 Catalog Offers)* |
| **1000.00 INR** (Talktime) | **4.722 OMR ($12.28 USD)** (`13507`) | 🔴 *(0 Catalog Offers)* | 🔴 *(503 Inactive)* | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `13500` (MTNL India - Topup Plan INR 10) to `+919868000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792110`, Wholesale Cost: `0.048 OMR` (~$0.12 USD), Benefits: Rs. 7.47 Regular Talktime
* **Result:** **Exclusive Primary Active Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment)
* **Catalog Status:** 0 offers available for brand `MTNL`.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 20`).

### 3. Reloadly (Sandbox API)
* **API Response:** `503 Service Unavailable` (`OPERATOR_UNAVAILABLE_OR_CURRENTLY_INACTIVE`).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `MNIN` ("MTNL India")
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Exclusive Primary Provider:** **DT One** (`operatorId: 368` — DT One is the sole operational provider delivering verified regular talktime recharges for MTNL in Delhi NCR and Mumbai circles from 10 INR / 0.048 OMR / $0.12 USD, `priority: 10`, `is_primary: true`).
2. **Disabled Providers:**
   - **Zendit** (0 offers, `priority: 20`, `is_enabled: false`).
   - **Reloadly** (Inactive / 503, `priority: 30`, `is_enabled: false`).
   - **DingConnect** (`MNIN`, 0 UAT inventory, `priority: 40`, `is_enabled: false`).
3. **India TRAI Regulatory Compliance:**
   - Standard 90-day inactivity mandate applies.
   - Performing a 10 INR talktime top-up refreshes line validity.
   - KeepSIMs schedules automated mini-refills on **Day 80–85** for MTNL SIM lines.
