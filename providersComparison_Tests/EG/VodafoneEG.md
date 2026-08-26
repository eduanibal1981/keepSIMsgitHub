# Provider Comparison & Test Report: Vodafone Egypt

> **Country:** Egypt (`EG` / `+20` / `EGY`)  
> **Carrier:** Vodafone Egypt  
> **Network Type:** MNO (National Market Leader)  
> **Balance USSD:** `*868*1#` or `*60#` | **Recharge USSD:** `*858*<PIN>#` | **Customer Care:** `888` (from mobile) / `16888` / `+20101888888`  
> **Test Date:** 2026-08-21  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DT One** (`dtone`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `EG` (ISO-2) | `EG` (ISO-2) | `EGY` (ISO-3) | `EG` (ISO-2) |
| **Carrier / Operator Code** | `119` ("Vodafone Egypt") | `Vodafone` | `716` ("Vodafone Egypt") | `VFEG` ("Vodafone Egypt") |
| **Delivery Mechanism** | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** | **`USD`** | **`OMR`** (Major Units) | **`OMR`** (Major Units) |
| **Catalog Format** | Open Range ($0.23–$5.67 USD) | Range (`VODAFONE_EG_OPEN`) + 9 Fixed Tiers | 23 Fixed Products (8–200 EGP) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EGP) | Reloadly Wholesale (`USD`) / Op 119 | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR`) / Product ID | DingConnect Direct (`VFEG`) |
| :---: | :---: | :---: | :---: | :---: |
| **8.00 EGP** | **$0.23 USD** (Net $0.2185) | $0.25 USD retail / $0.20 net (`VODAFONE_EG_OPEN`) | 0.076 OMR ($0.20 USD) (`4961`) | 🔴 *(0 Catalog Offers)* |
| **10.00 EGP** | **$0.28 USD** (Net $0.2660) | $0.31 USD retail / $0.25 net (`VODAFONE_EG_OPEN`) | 0.095 OMR ($0.25 USD) (`3912`) | 🔴 *(0 Catalog Offers)* |
| **15.00 EGP** | **$0.43 USD** (Net $0.4085) | $0.47 USD retail / $0.37 net (`VODAFONE_EG_OPEN`) | 0.142 OMR ($0.37 USD) (`4963`) | 🔴 *(0 Catalog Offers)* |
| **20.00 EGP** | **$0.57 USD** (Net $0.5415) | $0.62 USD retail / $0.50 net (`VODAFONE_EG_OPEN`) | 0.189 OMR ($0.49 USD) (`4955`) | 🔴 *(0 Catalog Offers)* |
| **21.73 EGP** | — | $0.65 USD retail / $0.54 net (`VODAFONE_EG_001`) | — | 🔴 *(0 Catalog Offers)* |
| **25.00 EGP** | **$0.71 USD** (Net $0.6745) | $0.78 USD retail / $0.62 net (`VODAFONE_EG_OPEN`) | 0.236 OMR ($0.61 USD) (`2604`) | 🔴 *(0 Catalog Offers)* |
| **30.00 EGP** | **$0.85 USD** (Net $0.8075) | $0.93 USD retail / $0.74 net (`VODAFONE_EG_OPEN`) | 0.283 OMR ($0.74 USD) (`4964`) | 🔴 *(0 Catalog Offers)* |
| **50.00 EGP** | **$1.42 USD** (Net $1.3490) | $1.56 USD retail / $1.24 net (`VODAFONE_EG_OPEN`) | 0.471 OMR ($1.22 USD) (`2605`) | 🔴 *(0 Catalog Offers)* |
| **100.00 EGP** | **$2.83 USD** (Net $2.6885) | $3.12 USD retail / $2.47 net (`VODAFONE_EG_OPEN`) | 0.942 OMR ($2.45 USD) (`2607`) | 🔴 *(0 Catalog Offers)* |
| **200.00 EGP** | **$5.67 USD** (Net $5.3865) | $6.23 USD retail / $4.95 net (`VODAFONE_EG_OPEN`) | 1.884 OMR ($4.90 USD) (`2606`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `119`, Amount `$0.25 USD` (8.82 EGP) to `201012345678`
* **Status:** `200 OK` $\rightarrow$ `SUCCESSFUL`
* **Transaction ID:** `178327`, delivered `8.82 EGP`, Discount: 5.0% (Net Cost: $0.2375 USD)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `VODAFONE_EG_001` (21.73 EGP) to `+201012345678`
* **Status:** `200 OK` $\rightarrow$ `status: ACCEPTED`
* **Transaction Reference:** `test_eg_zen_vodafone_1787299476901`
* **Result:** **Secondary Direct Airtime Failover** (`priority: 20`).

### 3. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `3912` (10 EGP Direct Airtime) to `+201000000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` / `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240790520`, Wholesale: `0.095 OMR` (~$0.25 USD)
* **Result:** **Tertiary Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Catalog Status:** Provider `VFEG` mapped in catalog, but returns 0 active products in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Top-Up:** **Reloadly** (`operatorId: 119` - flexible ranged refills starting at $0.23 USD with 5% discount, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Zendit** (`VODAFONE_EG_OPEN` / `VODAFONE_EG_001` - range and fixed tiers from $0.20 USD net cost, `priority: 20`).
3. **Tertiary Failover:** **DT One** (`716` - 23 fixed value products from 8 EGP at 0.076 OMR, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`VFEG`, `priority: 40`, `is_enabled: false`).
5. **Egypt NTRA Regulatory Compliance:**
   - NTRA mandates a **90-day activity requirement** from the last recharge or paid call/SMS.
   - Days 91–180 represent a suspension quarantine window. Complete deactivation and number forfeiture occur after 180 days.
   - KeepSIMs schedules automated mini-refills on **Day 80–85** to refresh line validity and keep the SIM alive continuously.
