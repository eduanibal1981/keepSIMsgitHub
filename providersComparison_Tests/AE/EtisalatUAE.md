# Provider Comparison & Test Report: e& / Etisalat (United Arab Emirates)

> **Country:** United Arab Emirates (`AE` / `+971` / `ARE`)  
> **Carrier:** e& (formerly Etisalat UAE / Wasel)  
> **Network Type:** MNO (Primary National Incumbent)  
> **Balance USSD:** `*121#` or `*140#` | **Recharge USSD:** `*120*<PIN>#` | **Customer Care:** `101` / `800 101`  
> **Test Date:** 2026-08-21  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DT One** (`dtone`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `AE` (ISO-2) | `AE` (ISO-2) | `ARE` (ISO-3) | `AE` (ISO-2) |
| **Carrier / Operator Code** | `1100` ("Etisalat United Arab Emirates") | `Etisalat` | `2097` ("Etisalat United Arab Emirates") | `ETAE` ("Etisalat UAE") |
| **Delivery Mechanism** | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Airtime & PIN Voucher | Direct Airtime & Data Bundles |
| **Settlement Currency** | **`USD`** | **`USD`** | **`OMR`** (Major Units) | **`OMR`** (Major Units) |
| **Product Count** | 19 Fixed Tiers (10–500 AED) | 4 Fixed + 1 Open Range | 16 Products (Direct + PIN) | 21 SKUs |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🟢 **Quaternary Route** (`priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (AED) | Reloadly Wholesale (`USD`) / Op 1100 | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR`) / Product ID | DingConnect Direct (`ETAE`) |
| :---: | :---: | :---: | :---: | :---: |
| **5.00 AED** | — | — *(Range min $1.53)* | 0.639 OMR (`13198`) | 0.54 OMR ($1.40 USD) (`ETAEE73229`) |
| **10.00 AED** | **$3.11 USD** (Net $3.02) (`rl_1100_3.11`) | $3.27 USD (Cost $3.08) (`ETISALAT_AE_10_AED`) | 1.278 OMR (`13199`) | 1.08 OMR ($2.81 USD) (`ETAEE7322`) |
| **15.00 AED** | **$4.66 USD** (`rl_1100_4.66`) | $4.91 USD (Cost $4.61) (`ETISALAT_AE_15_AED`) | — | 1.62 OMR ($4.21 USD) (`ETAEE7323`) |
| **20.00 AED** | **$6.21 USD** (`rl_1100_6.21`) | $6.54 USD (Cost $6.14) (`ETISALAT_AE_20_AED`) | 2.555 OMR (`13200`) | 2.16 OMR ($5.62 USD) (`ETAEE7324`) |
| **25.00 AED** | **$7.76 USD** (`rl_1100_7.76`) | — | 3.194 OMR PIN (`40700`) | 2.70 OMR ($7.02 USD) (`ETAEE7325`) |
| **30.00 AED** | **$9.32 USD** (`rl_1100_9.32`) | — | 3.833 OMR (`13201`) | 3.24 OMR ($8.43 USD) (`ETAEE7326`) |
| **50.00 AED** | **$15.53 USD** (`rl_1100_15.53`) | $16.35 USD (Cost $15.35) (`ETISALAT_AE_50_AED`) | 6.387 OMR (`13202`) | 5.40 OMR ($14.04 USD) (`ETAEE7328`) |
| **100.00 AED** | **$31.06 USD** (`rl_1100_31.06`) | — | 12.774 OMR (`13203`) | 10.80 OMR ($28.09 USD) (`ETAEE7329`) |
| **200.00 AED** | **$62.11 USD** (`rl_1100_62.11`) | — | 25.548 OMR (`13204`) | 21.60 OMR ($56.18 USD) (`ETAEE7330`) |
| **500.00 AED** | **$155.28 USD** (`rl_1100_155.28`) | — | 63.871 OMR (`13205`) | 54.00 OMR ($140.44 USD) (`ETAEE7331`) |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `1100`, Amount `$3.11 USD` (10 AED) to `971501234567`
* **Status:** `200 OK` $\rightarrow$ `SUCCESSFUL`
* **Transaction ID:** `178321`, delivered `10 AED`, Cost: `$3.0167 USD` (Discount: 3%).
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `ETISALAT_AE_10_AED` (10 AED) to `+971501234567`
* **Status:** `200 OK` $\rightarrow$ `status: ACCEPTED`
* **Transaction Reference:** `test_zen_eti_1787296431913`
* **Result:** **Secondary Direct Airtime Failover** (`priority: 20`).

### 3. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `13199` (10 AED Direct Airtime) to `+971500000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240790346`, Wholesale: `6.049 OMR`
* **Result:** **Tertiary Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Catalog Status:** Provider `ETAE` active in UAE catalog (`ValidationRegex: ^9710?(?:5)([0-9]{8})$`).
* **Result:** **Quaternary Route** (`priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Top-Up:** **Reloadly** (`rl_1100_3.11` - 10 AED / $3.11 USD retail, $3.0167 net wholesale, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Zendit** (`ETISALAT_AE_10_AED` - 10 AED / $3.27 USD retail, $3.08 net cost, `priority: 20`).
3. **Tertiary Direct / PIN Failover:** **DT One** (`2097` - 10 AED direct / PIN vouchers, `priority: 30`).
4. **Quaternary Route:** **DingConnect** (`ETAE`, `priority: 40`).
5. **UAE TDRA Regulatory Compliance:**
   - e& Wasel prepaid lines require a qualifying recharge or usage within **90 days** to prevent line suspension.
   - A 10 AED mini-recharge resets the 90-day activity timer and extends the 12-month number retention window.
   - Scheduled auto-refill triggers at **Day 80–85**.
