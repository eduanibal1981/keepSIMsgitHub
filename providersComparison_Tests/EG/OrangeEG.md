# Provider Comparison & Test Report: Orange Egypt

> **Country:** Egypt (`EG` / `+20` / `EGY`)  
> **Carrier:** Orange Egypt (formerly Mobinil)  
> **Network Type:** MNO  
> **Balance USSD:** `*100*3#` or `#100#` | **Recharge USSD:** `*102*<PIN>#` | **Customer Care:** `110` (from mobile) / `16110`  
> **Test Date:** 2026-08-21  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `EGY` (ISO-3) | `EG` (ISO-2) | `EG` (ISO-2) | `EG` (ISO-2) |
| **Carrier / Operator Code** | `190` ("Orange Egypt") | `118` ("Orange (Mobinil) Egypt") | `Orange` | `OREG` ("Orange Egypt") |
| **Delivery Mechanism** | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Major Units) | **`USD`** | **`USD`** | **`OMR`** (Major Units) |
| **Catalog Format** | 33 Products (10–1950 EGP + Ranged) | Open Range ($3.95–$128.91 USD) | Range (`ORANGE_EG_OPEN`) + 4 Fixed Tiers | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct (Micro-Tiers)** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EGP) | DT One Wholesale (`OMR`) / Product ID | Reloadly Wholesale (`USD`) / Op 118 | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`OREG`) |
| :---: | :---: | :---: | :---: | :---: |
| **10.00 EGP** | **0.092 OMR ($0.24 USD)** (`3913`) | — *(Min $3.95)* | — *(Min $3.95)* | 🔴 *(0 Catalog Offers)* |
| **15.00 EGP** | **0.138 OMR ($0.36 USD)** (`4897`) | — | — | 🔴 *(0 Catalog Offers)* |
| **20.00 EGP** | **0.184 OMR ($0.48 USD)** (`4651`) | — | — | 🔴 *(0 Catalog Offers)* |
| **25.00 EGP** | **0.230 OMR ($0.60 USD)** (`2608`) | — | — | 🔴 *(0 Catalog Offers)* |
| **30.00 EGP** | **0.275 OMR ($0.72 USD)** (`4898`) | — | — | 🔴 *(0 Catalog Offers)* |
| **40.00 EGP** | **0.367 OMR ($0.95 USD)** (`4899`) | — | — | 🔴 *(0 Catalog Offers)* |
| **50.00 EGP** | **0.459 OMR ($1.19 USD)** (`2609`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 EGP** | **0.917 OMR ($2.38 USD)** (`2610`) | — | — | 🔴 *(0 Catalog Offers)* |
| **170.00 EGP** | 1.559 OMR ($4.05 USD) (`54629`) | **$3.95 USD** (Net $3.8315) | $3.95 USD retail / $3.67 net (`ORANGE_EG_OPEN`) | 🔴 *(0 Catalog Offers)* |
| **176.88 EGP** | — | — | $4.50 USD retail / $3.66 net (`ORANGE_EG_4.5-I`) | 🔴 *(0 Catalog Offers)* |
| **200.00 EGP** | **1.833 OMR ($4.77 USD)** (`2611`) | **$4.65 USD** (Net $4.5105) | $4.53 USD retail / $4.21 net (`ORANGE_EG_OPEN`) | 🔴 *(0 Catalog Offers)* |
| **442.20 EGP** | 4.053 OMR ($10.54 USD) (`54629`) | $10.28 USD | $11.25 USD retail / $9.16 net (`ORANGE_EG_11-I`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `3913` (10 EGP Direct Airtime) to `+201200000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` / `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240790521`, Wholesale: `0.093 OMR` (~$0.24 USD)
* **Result:** **Primary Active Direct Route for Mini-Refills** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `118`, Amount `$3.95 USD` (169.85 EGP) to `201212345678`
* **Status:** `200 OK` $\rightarrow$ `SUCCESSFUL`
* **Transaction ID:** `178328`, delivered `169.85 EGP`, Discount: 3.0% (Net Cost: $3.8315 USD)
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `ORANGE_EG_4.5-I` (176.88 EGP) to `+201212345678`
* **Status:** `200 OK` $\rightarrow$ `status: ACCEPTED`
* **Transaction Reference:** `test_eg_zen_orange_1787299477810`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Catalog Status:** Provider `OREG` mapped in catalog, but returns 0 active products in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Top-Up (Micro-Tiers):** **DT One** (`operatorId: 190` - uniquely supports 10 EGP, 15 EGP, 25 EGP, 50 EGP micro-denominations from 0.092 OMR / ~$0.24 USD, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Reloadly** (`operatorId: 118` - open range top-ups from $3.95 USD with 3% discount, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`ORANGE_EG_OPEN` / `ORANGE_EG_4.5-I` - range and fixed bundles from $3.66 USD net cost, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`OREG`, `priority: 40`, `is_enabled: false`).
5. **Egypt NTRA Regulatory Compliance:**
   - Orange Egypt prepaid SIM cards require a qualifying paid transaction every **90 days**.
   - A 10 EGP micro-recharge via DT One resets the 90-day activity window with minimal customer spend.
   - KeepSIMs schedules automated mini-refills on **Day 80–85**.
