# Provider Comparison & Test Report: Nepal Telecom (NTC / Namaste)

> **Country:** Nepal (`NP` / `+977` / `NPL`)  
> **Carrier:** Nepal Telecom / Nepal Doorsanchar Company Ltd (`NTC` / `Namaste` / `Nepal Doorsanchar`)  
> **Network Type:** MNO (National Incumbent & State-Owned Operator / ~14M+ Subscribers / ~50% Mobile Market Share)  
> **Prefixes:** `984`, `985` (Postpaid), `986`, `974`, `976`, `975`, `972` (`+977984xxxxxxx`, `+977986xxxxxxx`, `+977974xxxxxxx`, `+977976xxxxxxx`)  
> **Balance USSD / SMS:** Dial `*400#` (Direct Balance Check & Main Validity Expiry Date), `*1415#` (Data Packs, Minutes, & SMS Offers Menu) | **Recharge USSD:** Dial `*412*<14-digit PIN>#` or Nepal Telecom App  
> **Customer Care:** `1498` (From NTC Mobile) / `197` (Directory Inquiry) / `+97714221197`  
> **Regulatory Policy (NTA Nepal & NTC Lifecycle):** Tiered denomination-based validity lifecycle. NPR 10 adds 5 days, NPR 50 adds 30 days, NPR 100 adds 60 days, NPR 200 adds 140 days, NPR 500 adds 360 days (1 full year), NPR 1000 adds 730 days (2 full years). Post-expiry: 30 days One-Way Barred $\rightarrow$ 30 days Two-Way Barred $\rightarrow$ 60 days Frozen/Grace Period before permanent MSISDN recycling. Recharges subject to statutory Telecommunication Service Charge (TSC: 10%) and 13% VAT.  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `NPL` (ISO-3) | `NP` (ISO-2) | `NP` (ISO-2) | `NP` (ISO-2) |
| **Carrier / Operator Code** | `1443` ("NTC Nepal") | `326` ("NTC GSM Nepal") / `1123` ("NTC Nepal Data") | `NTCGSM` | `NENP` ("Nepal Telecom Nepal") / `8NNP` ("Nepal Telecom Nepal Data") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Data Bundles | Direct Airtime Top-Up & Data Bundles | Direct Fixed Top-Up (`NTCGSM_NP_2.5-I` to `12-I`) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `11939` (10–10000 NPR) + 89 Fixed Airtime & Data Packs | Range `326` (50–20000 NPR / $0.38–$150.86 USD) + 20 Data Bundles (`1123`) | 3 Fixed Offers (`NTCGSM_NP_2.5-I` to `NTCGSM_NP_12-I`) | 0 Active Products in UAT (ResultCode: 3) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (NPR) | Validity Added | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`NENP`) |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **10.00 NPR** (Micro-Entry Rail) | **5 Days** | **0.031 OMR ($0.081 USD)** (`6972`) | — | — | 🔴 *(0 Catalog Offers)* |
| **15.00 NPR** (Micro-Topup) | **5 Days** | **0.046 OMR ($0.120 USD)** (`37177`) | — | — | 🔴 *(0 Catalog Offers)* |
| **20.00 NPR** (Micro-Topup) | **10 Days** | **0.062 OMR ($0.161 USD)** (`6973`) | — | — | 🔴 *(0 Catalog Offers)* |
| **22.44 NPR** (600MB 1-Day Data) | **1 Day** | **0.069 OMR ($0.179 USD)** (`61849`) | **$0.1615 USD** (`1123`) | — | 🔴 *(0 Catalog Offers)* |
| **25.50 NPR** (Voice+Data 1-Hr) | **1 Hour** | **0.079 OMR ($0.205 USD)** (`64110`) | — | — | 🔴 *(0 Catalog Offers)* |
| **30.00 NPR** (Standard Top-Up) | **15 Days** | **0.092 OMR ($0.239 USD)** (`6974`) | — | — | 🔴 *(0 Catalog Offers)* |
| **35.00 NPR** (Standard Top-Up) | **15 Days** | **0.108 OMR ($0.281 USD)** (`37176`) | — | — | 🔴 *(0 Catalog Offers)* |
| **40.00 NPR** (Standard Top-Up) | **20 Days** | **0.123 OMR ($0.320 USD)** (`6975`) | — | — | 🔴 *(0 Catalog Offers)* |
| **50.00 NPR** (Standard Airtime) | **30 Days** | **0.154 OMR ($0.400 USD)** (`6976`) | **$0.361 USD** (`326`) | — | 🔴 *(0 Catalog Offers)* |
| **100.00 NPR** (Standard Airtime) | **60 Days** | **0.307 OMR ($0.798 USD)** (`4569`) | **$0.722 USD** (`326`) | — | 🔴 *(0 Catalog Offers)* |
| **200.00 NPR** (Quarterly Validity) | **140 Days** | **0.613 OMR ($1.594 USD)** (`4570`) | **$1.444 USD** (`326`) | — | 🔴 *(0 Catalog Offers)* |
| **236.34 NPR** (Zendit Tier 1) | **140 Days** | **0.725 OMR ($1.885 USD)** (`11939`) | **$1.705 USD** (`326`) | **$2.00 USD** (`NTCGSM_NP_2.5-I`) | 🔴 *(0 Catalog Offers)* |
| **500.00 NPR** (Annual Validity!) | **360 Days (1 Year)** | **1.531 OMR ($3.981 USD)** (`4571`) | **$3.610 USD** (`326`) | — | 🔴 *(0 Catalog Offers)* |
| **597.80 NPR** (Zendit Tier 2) | **360 Days** | **1.831 OMR ($4.761 USD)** (`11939`) | **$4.316 USD** (`326`) | **$4.90 USD** (`NTCGSM_NP_6-I`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 NPR** (2-Year Validity!) | **730 Days (2 Years)** | **3.062 OMR ($7.961 USD)** (`4574`) | **$7.220 USD** (`326`) | — | 🔴 *(0 Catalog Offers)* |
| **1181.69 NPR** (Zendit Tier 3) | **730 Days** | **3.619 OMR ($9.409 USD)** (`11939`) | **$8.532 USD** (`326`) | **$9.60 USD** (`NTCGSM_NP_12-I`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `6972` (NTC Nepal 10 NPR Micro-Refill) to `+9779840000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793440`, Wholesale Cost: `0.031 OMR` (~$0.081 USD), Delivered: `10 NPR`
* **Test Request 2:** Product `6976` (NTC Nepal 50 NPR Airtime) to `+9779840000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793441`, Wholesale Cost: `0.154 OMR` (~$0.400 USD), Delivered: `50 NPR`
* **Test Request 3:** Product `61849` (NTC 600 MB All Time Data Pack / 22.44 NPR) to `+9779840000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793443`, Wholesale Cost: `0.069 OMR` (~$0.179 USD), Delivered: `22.44 NPR (600 MB)`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request 1:** Operator `326` (NTC GSM Nepal Airtime, $1.00 USD requested) to `+9779840000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178471`, Delivered: `132.57 NPR`, Wholesale Cost: `$0.95 USD` (5% discount applied)
* **Test Request 2:** Operator `1123` (NTC Nepal Data $0.17 USD bundle) to `+9779840000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178472`, Delivered: `22.44 NPR`, Wholesale Cost: `$0.1615 USD`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request 1:** Offer `NTCGSM_NP_2.5-I` (NTC GSM 2.5 USD / 236.34 NPR Top-Up) to `+9779840000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
  * **Transaction Reference:** `zen_np_test_1787438811371_ntcgsm_np_2_5_i`, Wholesale Cost: `$2.00 USD`
* **Test Request 2:** Offer `NTCGSM_NP_6-I` (NTC GSM 6 USD / 597.80 NPR Top-Up) to `+9779840000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
  * **Transaction Reference:** `zen_np_test_1787438812637_ntcgsm_np_6_i`, Wholesale Cost: `$4.90 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `NENP` ("Nepal Telecom Nepal") / `8NNP` ("Nepal Telecom Nepal Data")
* **Validation Regex:** `^977(9(?:84|85|86|74|76|04)[0-9]{7})$`
* **Catalog Status:** Returns `ResultCode: 3 / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1443` / Open Range `11939` + Fixed micro-recharge rail starting from **10 NPR (0.031 OMR / $0.08 USD)** and high-value validity packs like **500 NPR (360-day full year extension for $3.98 USD)**, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 326` / `1123` — flexible range airtime from $0.38 USD and 20 curated data bundles from $0.17 USD, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: NTCGSM` — offers `NTCGSM_NP_2.5-I`, `NTCGSM_NP_6-I`, `NTCGSM_NP_12-I`, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`NENP`, `priority: 40`, `is_enabled: false`).
5. **Nepal Telecom Statutory Validity & KeepSIMs Auto-Refill Strategy:**
   - Nepal Telecom's prepaid lifecycle is uniquely advantageous:
     * A single **500 NPR recharge ($3.98 USD via DT One)** grants **360 days (1 full year)** of active validity.
     * A single **1000 NPR recharge ($7.96 USD via DT One)** grants **730 days (2 full years)** of active validity.
     * Alternatively, a micro-refill of **10–50 NPR ($0.08–$0.40 USD)** provides 5–30 days of active status.
   - Once validity expires, NTC provides a 30-day incoming-only phase + 30-day two-way barred phase + 60-day grace period before recycling.
   - KeepSIMs optimal strategy: Users can choose either an **annual preservation refill (500 NPR / ~$3.98 USD once every 350 days)** or **quarterly micro-refills (50 NPR / ~$0.40 USD every 60–90 days)**.
