# Provider Comparison & Test Report: Etisalat Egypt (e& Egypt)

> **Country:** Egypt (`EG` / `+20` / `EGY`)  
> **Carrier:** Etisalat Egypt (e& Egypt)  
> **Network Type:** MNO  
> **Balance USSD:** `*888#` or `*555#` | **Recharge USSD:** `*556*<PIN>#` | **Customer Care:** `333` (from mobile) / `01111234333`  
> **Test Date:** 2026-08-21  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DT One** (`dtone`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `EG` (ISO-2) | `EG` (ISO-2) | `EGY` (ISO-3) | `EG` (ISO-2) |
| **Carrier / Operator Code** | `120` ("Etisalat Egypt") | `Etisalat` | `1451` ("Etisalat Egypt") | `ETEG` ("Etisalat Egypt") |
| **Delivery Mechanism** | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** | **`USD`** | **`OMR`** (Major Units) | **`OMR`** (Major Units) |
| **Catalog Format** | 29 Fixed Tiers ($0.17–$8.33 USD) | 10 Fixed Tiers (5–100 EGP) | 91 Products (10–200 EGP + Bundles) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EGP) | Reloadly Wholesale (`USD`) / Op 120 | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR`) / Product ID | DingConnect Direct (`ETEG`) |
| :---: | :---: | :---: | :---: | :---: |
| **5.00 EGP** | **$0.17 USD** (Net $0.1615) (`rl_120_0.17`) | $0.25 USD retail / **$0.13 net** (`ETISALAT_EG_001`) | — | 🔴 *(0 Catalog Offers)* |
| **10.00 EGP** | **$0.33 USD** (Net $0.3135) (`rl_120_0.33`) | $0.50 USD retail / $0.27 net (`ETISALAT_EG_003`) | 0.090 OMR ($0.23 USD) (`3570`) | 🔴 *(0 Catalog Offers)* |
| **15.00 EGP** | **$0.50 USD** (Net $0.4750) (`rl_120_0.50`) | — | 0.134 OMR ($0.35 USD) (`4922`) | 🔴 *(0 Catalog Offers)* |
| **20.00 EGP** | **$0.67 USD** (Net $0.6365) (`rl_120_0.67`) | $0.75 USD retail / $0.51 net (`ETISALAT_EG_004`) | 0.179 OMR ($0.47 USD) (`3571`) | 🔴 *(0 Catalog Offers)* |
| **25.00 EGP** | **$0.83 USD** (Net $0.7885) (`rl_120_0.83`) | $1.55 USD retail / $0.65 net (`ETISALAT_EG_005`) | 0.224 OMR ($0.58 USD) (`4924`) | 🔴 *(0 Catalog Offers)* |
| **30.00 EGP** | **$1.00 USD** (Net $0.9500) (`rl_120_1.00`) | $1.85 USD retail / $0.78 net (`ETISALAT_EG_006`) | 0.268 OMR ($0.70 USD) (`4923`) | 🔴 *(0 Catalog Offers)* |
| **40.00 EGP** | **$1.33 USD** (Net $1.2635) (`rl_120_1.33`) | $2.51 USD retail / $1.04 net (`ETISALAT_EG_007`) | 0.358 OMR ($0.93 USD) (`4804`) | 🔴 *(0 Catalog Offers)* |
| **50.00 EGP** | **$1.67 USD** (Net $1.5865) (`rl_120_1.67`) | $3.13 USD retail / $1.30 net (`ETISALAT_EG_009`) | 0.447 OMR ($1.16 USD) (`4913`) | 🔴 *(0 Catalog Offers)* |
| **100.00 EGP** | **$3.33 USD** (Net $3.1635) (`rl_120_3.33`) | $6.22 USD retail / $2.60 net (`ETISALAT_EG_011`) | 0.894 OMR ($2.32 USD) (`3491`) | 🔴 *(0 Catalog Offers)* |
| **200.00 EGP** | **$6.67 USD** (Net $6.3365) (`rl_120_6.67`) | — | 1.787 OMR ($4.65 USD) (`4914`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `120`, Amount `$0.17 USD` (5.10 EGP) to `201112345678`
* **Status:** `200 OK` $\rightarrow$ `SUCCESSFUL`
* **Transaction ID:** `178329`, delivered `5.10 EGP`, Discount: 5.0% (Net Cost: $0.1615 USD)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `ETISALAT_EG_001` (5.00 EGP) to `+201112345678`
* **Status:** `200 OK` $\rightarrow$ `status: ACCEPTED`
* **Transaction Reference:** `test_eg_zen_etisalat_1787299478721`
* **Result:** **Secondary Direct Airtime Failover** (`priority: 20`).

### 3. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `3570` (10 EGP Direct Airtime) to `+201100000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` / `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240790522`, Wholesale: `0.090 OMR` (~$0.23 USD)
* **Result:** **Tertiary Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Catalog Status:** Provider `ETEG` mapped in catalog, but returns 0 active products in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Top-Up:** **Reloadly** (`operatorId: 120` - 29 granular denominations from $0.17 USD for 5.10 EGP with 5% discount, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Zendit** (`ETISALAT_EG_001` - 5 EGP at $0.25 USD retail / $0.13 USD cost, `priority: 20`).
3. **Tertiary Direct Failover:** **DT One** (`1451` - 91 catalog products, 10 EGP at 0.090 OMR / ~$0.23 USD, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`ETEG`, `priority: 40`, `is_enabled: false`).
5. **Egypt NTRA Regulatory Compliance:**
   - Etisalat Egypt prepaid lines remain active for **90 days** after any recharge.
   - A $0.17 USD (5 EGP) refill completely resets the 90-day activity timer.
   - KeepSIMs schedules automated mini-refills on **Day 80–85**.
