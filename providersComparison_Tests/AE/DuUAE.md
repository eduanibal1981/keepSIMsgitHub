# Provider Comparison & Test Report: du (United Arab Emirates)

> **Country:** United Arab Emirates (`AE` / `+971` / `ARE`)  
> **Carrier:** du (Emirates Integrated Telecommunications Company - EITC)  
> **Network Type:** MNO (National Mobile Operator)  
> **Balance USSD:** `*135#` | **Recharge USSD:** `*135*<PIN>#` or `*131*<PIN>#` | **Customer Care:** `155` / `800 155`  
> **Test Date:** 2026-08-21  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DT One** (`dtone`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `AE` (ISO-2) | `AE` (ISO-2) | `ARE` (ISO-3) | `AE` (ISO-2) |
| **Carrier / Operator Code** | `529` ("Du More Credit United Arab Emirates") | `du` / `Du` | `2098` ("Du United Arab Emirates") | `DUAE` ("du UAE") |
| **Delivery Mechanism** | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Airtime & PIN Voucher | Direct Airtime & Bundles |
| **Settlement Currency** | **`USD`** | **`USD`** | **`OMR`** (Major Units) | **`OMR`** (Major Units) |
| **Product Count** | 19 Fixed Tiers (10–500 AED) | 5 Fixed + 1 Open Range | 14 Products (Direct + PIN) | 21 SKUs |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🟢 **Quaternary Route** (`priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (AED) | Reloadly Wholesale (`USD`) / Op 529 | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR`) / Product ID | DingConnect Direct (`DUAE`) |
| :---: | :---: | :---: | :---: | :---: |
| **5.00 AED** | — | — *(Range min $1.53)* | — | 0.54 OMR ($1.40 USD) (`DUAE51174`) |
| **10.00 AED** | **$2.72 USD** (Net $2.67) (`rl_529_2.72`) | $3.27 USD (Cost $3.08) (`DU_AE_10_AED`) | 1.278 OMR (`13207`) | 1.08 OMR ($2.81 USD) (`DUAE5117`) |
| **15.00 AED** | **$4.08 USD** (`rl_529_4.08`) | $4.91 USD (Cost $4.61) (`DU_AE_15_AED`) | — | — |
| **20.00 AED** | **$5.44 USD** (`rl_529_5.44`) | $6.54 USD (Cost $6.14) (`DU_AE_20_AED`) | 2.555 OMR (`13208`) | 2.16 OMR ($5.62 USD) (`DUAE5118`) |
| **25.00 AED** | **$6.80 USD** (`rl_529_6.8`) | $8.18 USD (Cost $7.67) (`DU_AE_25_AED`) | — | — |
| **30.00 AED** | **$8.16 USD** (`rl_529_8.16`) | — | — | 3.24 OMR ($8.43 USD) (`DUAE5119`) |
| **50.00 AED** | **$13.60 USD** (`rl_529_13.6`) | $16.35 USD (Cost $15.35) (`DU_AE_50_AED`) | 6.387 OMR (`13209`) | 5.40 OMR ($14.04 USD) (`DUAE5120`) |
| **70.00 AED** | **$19.04 USD** (`rl_529_19.04`) | — | — | — |
| **100.00 AED** | **$27.20 USD** (`rl_529_27.2`) | — | 12.774 OMR (`13210`) | 10.80 OMR ($28.09 USD) (`DUAE5121`) |
| **200.00 AED** | **$54.40 USD** (`rl_529_54.4`) | — | 25.548 OMR (`13211`) | 21.60 OMR ($56.18 USD) (`DUAE5122`) |
| **500.00 AED** | **$136.00 USD** (`rl_529_136`) | — | 63.871 OMR (`13212`) | — |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `529`, Amount `$2.72 USD` (10 AED) to `971551234567`
* **Status:** `200 OK` $\rightarrow$ `SUCCESSFUL`
* **Transaction ID:** `178322`, delivered `10 AED`, Cost: `$2.6656 USD` (Discount: 2%).
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `DU_AE_10_AED` (10 AED) to `+971551234567`
* **Status:** `200 OK` $\rightarrow$ `status: ACCEPTED`
* **Transaction Reference:** `test_zen_du_1787296436701`
* **Result:** **Secondary Direct Airtime Failover** (`priority: 20`).

### 3. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `13207` (10 AED Direct Airtime) to `+971550000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240790347`, Wholesale: `10.081 OMR`
* **Result:** **Tertiary Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Catalog Status:** Provider `DUAE` active in UAE catalog (`ValidationRegex: ^9710?(?:5)([0-9]{8})$`).
* **Result:** **Quaternary Route** (`priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Top-Up:** **Reloadly** (`rl_529_2.72` - 10 AED / $2.72 USD retail, $2.6656 net wholesale, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Zendit** (`DU_AE_10_AED` - 10 AED / $3.27 USD retail, $3.08 net cost, `priority: 20`).
3. **Tertiary Direct / PIN Failover:** **DT One** (`2098` - 10 AED direct / PIN vouchers, `priority: 30`).
4. **Quaternary Route:** **DingConnect** (`DUAE`, `priority: 40`).
5. **UAE TDRA Regulatory Compliance:**
   - du prepaid "More Credit" lines require activity / recharge within **90 days** to prevent suspension.
   - A 10 AED mini-recharge resets the 90-day inactivity timer and maintains line active status.
   - KeepSIMs schedules automated mini-refills at **Day 80–85**.
