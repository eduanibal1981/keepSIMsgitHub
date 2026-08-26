# Provider Comparison & Test Report: WE (Telecom Egypt)

> **Country:** Egypt (`EG` / `+20` / `EGY`)  
> **Carrier:** WE (Telecom Egypt / TE)  
> **Network Type:** MNO (National Telecommunications Incumbent)  
> **Balance USSD:** `*550#` | **Recharge USSD:** `*555*<PIN>#` | **Customer Care:** `111` (from mobile) / `19777`  
> **Test Date:** 2026-08-21  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Zendit** (`zendit`) | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `EG` (ISO-2) | `EGY` (ISO-3) | `EG` (ISO-2) | `EG` (ISO-2) |
| **Carrier / Operator Code** | `WETelecom` | `2982` ("WE Telecom Egypt") | `1216` ("WE Telecom Egypt") | `39EG` ("WE Telecom Egypt") |
| **Delivery Mechanism** | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** | **`OMR`** (Major Units) | **`USD`** | **`OMR`** (Major Units) |
| **Catalog Format** | 5 Fixed Tiers (100–290 EGP) | 6 Products (100–290 EGP + Ranged) | Open Range ($2.93–$14.57 USD) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EGP) | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR`) / Product ID | Reloadly Wholesale (`USD`) / Op 1216 | DingConnect Direct (`39EG`) |
| :---: | :---: | :---: | :---: | :---: |
| **87.89 EGP** | — | — | **$2.93 USD** (Net $2.7835) (`rl_1216_2.93`) | 🔴 *(0 Catalog Offers)* |
| **100.00 EGP** | **$2.63 USD** (Net $2.33) (`WETELECOM_EG_01`) | **0.995 OMR ($2.59 USD)** (`66945`) | $3.33 USD (Net $3.1635) (`rl_1216_3.33`) | 🔴 *(0 Catalog Offers)* |
| **150.00 EGP** | **$3.93 USD** (Net $3.49) (`WETELECOM_EG_02`) | **1.492 OMR ($3.88 USD)** (`66946`) | $5.00 USD (Net $4.7500) (`rl_1216_5.00`) | 🔴 *(0 Catalog Offers)* |
| **200.00 EGP** | **$5.24 USD** (Net $4.66) (`WETELECOM_EG_03`) | **1.989 OMR ($5.17 USD)** (`66947`) | $6.67 USD (Net $6.3365) (`rl_1216_6.67`) | 🔴 *(0 Catalog Offers)* |
| **250.00 EGP** | **$6.54 USD** (Net $5.83) (`WETELECOM_EG_04`) | **2.486 OMR ($6.47 USD)** (`66948`) | $8.33 USD (Net $7.9135) (`rl_1216_8.33`) | 🔴 *(0 Catalog Offers)* |
| **290.00 EGP** | **$7.59 USD** (Net $6.75) (`WETELECOM_EG_05`) | **2.884 OMR ($7.50 USD)** (`66949`) | $9.67 USD (Net $9.1865) (`rl_1216_9.67`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `WETELECOM_EG_01` (100 EGP) to `+201512345678`
* **Status:** `200 OK` $\rightarrow$ `status: ACCEPTED`
* **Transaction Reference:** `test_eg_zen_we_1787299479632`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `66945` (100 EGP Direct Airtime) to `+201500000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` / `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240790523`, Wholesale: `0.995 OMR` ($2.59 USD)
* **Result:** **Secondary Direct Airtime Failover** (`priority: 20`).

### 3. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `1216`, Amount `$2.93 USD` (87.89 EGP) to `201512345678`
* **Status:** `200 OK` $\rightarrow$ `SUCCESSFUL`
* **Transaction ID:** `178330`, delivered `87.89 EGP`, Discount: 5.0% (Net Cost: $2.7835 USD)
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Catalog Status:** Provider `39EG` mapped in catalog, but returns 0 active products in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Top-Up:** **Zendit** (`offerId: WETELECOM_EG_01` - 100 EGP at $2.63 USD retail / $2.33 USD net wholesale cost, providing the most competitive rate, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **DT One** (`operatorId: 2982` - Product 66945 at 0.995 OMR / $2.59 USD, `priority: 20`).
3. **Tertiary Direct Failover:** **Reloadly** (`operatorId: 1216` - Ranged refills from $2.93 USD with 5% discount, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`39EG`, `priority: 40`, `is_enabled: false`).
5. **Egypt NTRA Regulatory Compliance:**
   - WE prepaid mobile lines require a qualifying transaction every **90 days**.
   - Scheduled auto-refills on **Day 80–85** keep the line permanently active.
