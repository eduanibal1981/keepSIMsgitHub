# Provider Comparison & Test Report: Ooredoo Qatar (Hala / Shahry)

> **Country:** Qatar (`QA` / `+974` / `QAT`)  
> **Carrier:** Ooredoo Q.P.S.C. (`Ooredoo Qatar` / formerly Qtel)  
> **Network Type:** MNO (Incumbent Market Leader / ~70% Market Share / Hala Prepaid & Shahry Postpaid)  
> **Balance USSD / SMS:** Dial `*129#` (Main Balance & Validity) or SMS `Balance` to `121` | **Data Balance:** Dial `*129*1#` or SMS `Balance DC` to `121`  
> **Recharge USSD:** Dial `*127*<14-digit PIN>#` or Ooredoo Qatar App / Self-Care Portal  
> **Customer Care:** `111` (within Qatar) / `+97444200700` (International) / `170` (Hala Support)  
> **Regulatory Policy (CRA Qatar):** Credit validity lasts 30–90 days by denomination; after expiry, line enters a **60-day grace period** (receive-only). A top-up within **120 days** restores line validity and recovers unused balance; past **120 days**, the SIM is permanently deactivated and recycled to the CRA pool.  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **DT One** (`dtone`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `QA` (ISO-2) | `QAT` (ISO-3) | `QA` (ISO-2) | `QA` (ISO-2) |
| **Carrier / Operator Code** | `396` ("Ooredoo Qatar") | `511` ("Ooredoo Qatar") | `Ooredoo` | `OOQA` ("Ooredoo Qatar") |
| **Delivery Mechanism** | **Direct Airtime Top-Up** (Real-Time MSISDN Credit) | **Digital PIN Voucher** (Data Vouchers) | Direct Top-Up (0 Inventory in Catalog) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** (1% Wholesale Discount) | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`OMR`** |
| **Catalog Format** | Fixed: 100 QAR ($40.16 USD), 200 QAR ($80.32 USD) | Fixed PIN: 80 QAR 12GB (`33349`), 150 QAR 25GB (`1738`) | 0 Active Offers | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary PIN Route** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (QAR) | Reloadly Wholesale (`USD`) / Op ID `396` | DT One Wholesale (`OMR` / `USD`) / Product ID | Zendit Wholesale (`USD`) | DingConnect Direct (`OOQA`) | Delivery Type |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **80.00 QAR** (12 GB Data 28D) | — | **10.252 OMR ($26.66 USD)** (`33349`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | Digital PIN Voucher |
| **100.00 QAR** (Standard Airtime) | **$39.76 USD net** ($40.16 gross, 1% disc) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | **Direct Top-Up** |
| **150.00 QAR** (25 GB Data 28D) | — | **19.221 OMR ($49.97 USD)** (`1738`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | Digital PIN Voucher |
| **200.00 QAR** (Standard Airtime) | **$79.52 USD net** ($80.32 gross, 1% disc) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | **Direct Top-Up** |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `396` (Ooredoo Qatar 100 QAR, $40.16 USD) to `+97466000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178441`, Delivered: `100 QAR`, Net Cost: `$39.7584 USD` (1% discount applied), Balance updated from `$871.81` to `$832.05`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API) — 🟢 Secondary Data PIN Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `33349` (Ooredoo PIN Qatar Internet 80 QAR / 12GB) to `+97466000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793394`, Wholesale Cost: `10.252 OMR` (~$26.66 USD), PIN instructions: `*127*PIN#` / SMS PIN to `127`
* **Test Request 2:** Product `1738` (Ooredoo PIN Qatar Internet 150 QAR / 25GB) to `+97466000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793395`, Wholesale Cost: `19.221 OMR` (~$49.97 USD)
* **Result:** **Secondary PIN Route** (`priority: 20`, `is_enabled: true`).

### 3. Zendit (Test Environment) — 🔴 Disabled Route
* **Brand Code:** `Ooredoo`
* **Catalog Status:** Returns 0 active offers for `country=QA`.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `OOQA` ("Ooredoo Qatar")
* **Validation Regex:** `^974[0-9]{8}$|^0000000000$`
* **Catalog Status:** Returns `503 Service Unavailable / RateLimited / 0 items` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **Reloadly** (`operatorId: 396` — delivers direct account airtime credits for 100 QAR and 200 QAR with instant delivery and 1% discount, `priority: 10`, `is_primary: true`).
2. **Secondary PIN / Bundle Route:** **DT One** (`operatorId: 511` — delivers 80 QAR 12GB and 150 QAR 25GB digital internet vouchers via `*127*PIN#`, `priority: 20`).
3. **Disabled Providers:** **Zendit** (`brand: Ooredoo`, `priority: 30`, `is_enabled: false`) & **DingConnect** (`OOQA`, `priority: 40`, `is_enabled: false`).
4. **CRA Qatar Regulatory Compliance:**
   - Ooredoo Hala prepaid credit extends active line validity for 30–90 days per recharge.
   - Upon balance expiry, the line enters a **60-day Grace Period** (incoming calls and SMS remain active).
   - If no qualifying top-up occurs within **120 days**, the SIM is permanently disconnected and the number is recycled to the CRA pool.
   - KeepSIMs schedules automated mini-refills every **30–60 days** to keep the line alive continuously.
