# Provider Comparison & Test Report: TM (Touch Mobile) Philippines

> **Country:** Philippines (`PH` / `+63` / `PHL`)  
> **Carrier:** TM (Touch Mobile / Globe Telecom Affiliate)  
> **Network Type:** MNO Sub-Brand (Value-Focused Cellular Network)  
> **Balance USSD / SMS:** Dial `*143#` (USSD Menu) or text `BAL` to `222` | **Account App:** GlobeOne / TM App  
> **Customer Care:** `808` (TM Mobile) / `(02) 7730-1500` / `+63277301500`  
> **Regulatory Policy (NTC/DICT):** 1-Year (365 Days) Load Validity (MC 05-12-2017) | 120 Days Zero-Balance Deactivation Window  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `PHL` (ISO-3) | `PH` (ISO-2) | `PH` (ISO-2) | `PH` (ISO-2) |
| **Carrier / Operator Code** | `3128` ("Touch Mobile Philippines") | `723` ("Touch Mobile Philippines") / `939` (Bundles) / `938` (Data) | `TouchMobile` | `TMPH` ("Touch Mobile Philippines") |
| **Delivery Mechanism** | Direct Top-Up (10–1000 PHP) | Direct Airtime, Bundles & Data | Digital Plan & Airtime Recharge | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 18 Fixed Products (10–1000 PHP) | Fixed (10–300 PHP / $0.18–$5.49 USD) | 10 Fixed Offers (150–1000 PHP) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (PHP) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`TMPH`) |
| :---: | :---: | :---: | :---: | :---: |
| **10.00 PHP** (Micro-Load) | **0.076 OMR ($0.198 USD)** (`23309` 10 PHP) | **$0.18 USD** (`723` 10 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **15.00 PHP** (FBML / Airtime) | **0.110 OMR ($0.286 USD)** (`2275` FBML) / `0.114 OMR` (`23310`) | — | — | 🔴 *(0 Catalog Offers)* |
| **20.00 PHP** | — | **$0.37 USD** (`723` 20 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **25.00 PHP** | **0.189 OMR ($0.491 USD)** (`23311` 25 PHP) | — | — | 🔴 *(0 Catalog Offers)* |
| **30.00 PHP** | **0.227 OMR ($0.590 USD)** (`23312` 30 PHP) | **$0.55 USD** (`723` 30 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **50.00 PHP** | **0.378 OMR ($0.983 USD)** (`23313` 50 PHP) | **$0.92 USD** (`723` 50 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **60.00 PHP** | **0.454 OMR ($1.180 USD)** (`23314` 60 PHP) | **$1.10 USD** (`723` 60 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **90.00 PHP** | — | **$1.65 USD** (`723` 90 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **100.00 PHP** | **0.756 OMR ($1.966 USD)** (`23315` 100 PHP) | **$1.83 USD** (`723` 100 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **150.00 PHP** | **1.133 OMR ($2.946 USD)** (`23316` 150 PHP) | **$2.75 USD** (`723` 150 PHP) | **$3.39 USD** (`TOUCHMOBILE_PH_001`) | 🔴 *(0 Catalog Offers)* |
| **200.00 PHP** | — | **$3.66 USD** (`723` 200 PHP) | **$4.45 USD** (`TOUCHMOBILE_PH_002`) | 🔴 *(0 Catalog Offers)* |
| **300.00 PHP** | **2.266 OMR ($5.892 USD)** (`23317` 300 PHP) | **$5.49 USD** (`723` 300 PHP) | — | 🔴 *(0 Catalog Offers)* |
| **350.00 PHP** | **2.644 OMR ($6.874 USD)** (`23318` 350 PHP) | — | **$7.84 USD** (`TOUCHMOBILE_PH_003`) | 🔴 *(0 Catalog Offers)* |
| **450.00 PHP** | **3.399 OMR ($8.837 USD)** (`23319` 450 PHP) | — | **$9.87 USD** (`TOUCHMOBILE_PH_004`) | 🔴 *(0 Catalog Offers)* |
| **500.00 PHP** | **3.777 OMR ($9.820 USD)** (`23320` 500 PHP) | — | **$11.03 USD** (`TOUCHMOBILE_PH_005`) | 🔴 *(0 Catalog Offers)* |
| **550.00 PHP** | **4.154 OMR ($10.800 USD)** (`23321` 550 PHP) | — | **$12.19 USD** (`TOUCHMOBILE_PH_006`) | 🔴 *(0 Catalog Offers)* |
| **600.00 PHP** | **4.532 OMR ($11.783 USD)** (`23322` 600 PHP) | — | **$13.16 USD** (`TOUCHMOBILE_PH_007`) | 🔴 *(0 Catalog Offers)* |
| **700.00 PHP** | **5.287 OMR ($13.746 USD)** (`23323` 700 PHP) | — | **$15.39 USD** (`TOUCHMOBILE_PH_008`) | 🔴 *(0 Catalog Offers)* |
| **900.00 PHP** | **6.798 OMR ($17.675 USD)** (`23324` 900 PHP) | — | **$19.74 USD** (`TOUCHMOBILE_PH_009`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 PHP** | **7.553 OMR ($19.638 USD)** (`23325` 1000 PHP) | — | **$21.97 USD** (`TOUCHMOBILE_PH_010`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `23309` (Touch Mobile Philippines 10 PHP) to `+639050000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792119`, Wholesale Cost: `0.076 OMR` (~$0.198 USD)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `723` ($0.18 USD $\rightarrow$ 10 PHP) to `+639050000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178385`, Cost: `$0.171 USD`
* **Result:** **Secondary Active Direct Failover** (`priority: 20`).

### 3. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `TOUCHMOBILE_PH_001` (150 PHP / $3.39 USD) to `+639050000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `test_ph_zen_tm_1787360763914`
* **Result:** **Tertiary Direct Airtime Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `TMPH` ("Touch Mobile Philippines")
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 3128` — complete 18-product catalog from 10 PHP / 0.076 OMR up to 1000 PHP, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Reloadly** (`operatorId: 723` — reliable 10 PHP / $0.18 USD direct airtime recharge, `priority: 20`).
3. **Tertiary Failover:** **Zendit** (`brand: TouchMobile` — 10 offers from 150 PHP, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`TMPH`, `priority: 40`, `is_enabled: false`).
5. **NTC / DICT Regulatory Compliance:**
   - Under **NTC-DICT Memorandum Circular No. 05-12-2017**, TM load value remains valid for **365 days**.
   - Upon zero balance, subscribers have **120 consecutive days** to reload before the line is permanently disconnected.
   - KeepSIMs schedules automated mini-refills on **Day 100–110** of zero-balance or prior to expiry, sending a 10 PHP recharge ($0.198 USD) to keep the TM line alive perpetually.
