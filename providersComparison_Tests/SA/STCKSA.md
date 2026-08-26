# Provider Comparison & Test Report: STC (Saudi Arabia)

> **Country:** Saudi Arabia (`SA` / `+966` / `SAU`)  
> **Carrier:** STC (Saudi Telecom Company / Sawa / Jawwy)  
> **Network Type:** MNO (Primary National Incumbent)  
> **Balance USSD:** `*166#` | **Recharge USSD:** `*155*<PIN>#` | **IVR:** `1500`  
> **Test Date:** 2026-08-19  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `SAU` (ISO-3) | `SA` (ISO-2) | `SA` (ISO-2) | `SA` (ISO-2) |
| **Carrier / Operator Code** | `3221` ("STC Saudi Arabia") | `1124` ("STC Saudi Arabia") | `STC` | `XCSA` (Direct), `S6SA` (PIN), `SESA` (Data), `SGSA` (Flex/Like), `SHSA` (TV) |
| **Delivery Mechanism** | Digital PIN Voucher | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Airtime & PIN Voucher |
| **Settlement Currency** | **`OMR`** (Major Units) | **`USD`** | **`USD`** | **`OMR`** (Major Units) |
| **Product Count** | 12 Products | 6 Fixed Tiers | 8 Fixed Offers | 28+ SKUs |
| **DB Status in `carrier_provider_map`** | 🟢 Secondary PIN (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`) | 🟢 **Secondary Direct** (`priority: 20`) | 🟢 **Primary Direct & PIN** (`is_primary: true`, `priority: 10`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (SAR) | DT One Wholesale (`OMR`) / Product ID | Reloadly Cost (`USD`) *(Disabled)* | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`XCSA`) | DingConnect PIN (`S6SA`) |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **20.00 SAR** | 2.532 OMR (`59797`) | — | $7.10 USD (`STC_SA_001_USD`) | **2.68 OMR ($6.97 USD)** (`XCSASA72721`) | 2.68 OMR (`S6SASA72721`) |
| **23.00 SAR** | — | — | $8.20 USD (`STC_SA_002_USD`) | **3.09 OMR ($8.04 USD)** (`XCSASA86002`) | 3.09 OMR (`S6SASA52404`) |
| **28.75 SAR** *(Sawa 25)* | 3.639 OMR (`32085`) | $12.01 USD (`rl_1124_12.01`) | $10.20 USD (`STC_SA_003_USD`) | **3.86 OMR ($10.04 USD)** (`XCSASA44742`) | 3.86 OMR (`S6SASA44742`) |
| **34.50 SAR** *(Sawa 30)* | 4.366 OMR (`32086`) | $14.41 USD (`rl_1124_14.41`) | $12.30 USD (`STC_SA_004_USD`) | **4.63 OMR ($12.04 USD)** (`XCSASA46567`) | 4.63 OMR (`S6SASA46567`) |
| **57.50 SAR** *(Sawa 50)* | 7.276 OMR (`32087`) | $24.02 USD (`rl_1124_24.02`) | $20.40 USD (`STC_SA_005_USD`) | **7.71 OMR ($20.05 USD)** (`XCSASA23360`) | 7.71 OMR (`S6SASA23360`) |
| **115.00 SAR** *(Sawa 100)* | 14.551 OMR (`32088`) | $48.04 USD (`rl_1124_48.04`) | $40.80 USD (`STC_SA_006_USD`) | **15.41 OMR ($40.08 USD)** (`XCSASA41978`) | 15.41 OMR (`S6SASA41978`) |
| **230.00 SAR** *(Sawa 200)* | 29.100 OMR (`32089`) | $96.07 USD (`rl_1124_96.07`) | $81.50 USD (`STC_SA_007_USD`) | **30.81 OMR ($80.13 USD)** (`XCSASA82987`) | 30.81 OMR (`S6SASA82987`) |
| **345.00 SAR** *(Sawa 300)* | 43.650 OMR (`32090`) | $144.11 USD (`rl_1124_144.11`)| $122.30 USD (`STC_SA_008_USD`) | **46.22 OMR ($120.21 USD)** (`XCSASA78089`)| 46.22 OMR (`S6SASA78089`) |

---

## 3. Live Test & Simulation Results

### 1. DingConnect (UAT Environment)
* **Dry-Run Test (`ValidateOnly: true`):** SKU `S6SASA52404` $\rightarrow$ `ResultCode: 1` (`ProcessingState: Complete`)
* **Live Simulation:** SKU `S6SASA52404` with UAT number `966000000000` $\rightarrow$ `ResultCode: 1`, `TransferRef: 860860734`, Delivered PIN: `000614197769`

### 2. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `STC_SA_001_USD` (20 SAR) to `+966500000000`
* **Status:** `200 OK` $\rightarrow$ `status: ACCEPTED`
* **Transaction Reference:** `test_zen_1787161918571`

### 3. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `32085` (28.75 SAR PIN) to `+966500000101`
* **Status:** `201 Created` $\rightarrow$ Polled status: `COMPLETED`
* **Delivered Artifact:** Transaction ID `2240786609`, Delivered PIN: `55173004801808`

### 4. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `1124`, $12.01 USD (28.75 SAR) to `966500000000`
* **Status:** `200 OK` $\rightarrow$ `SUCCESSFUL`
* **Transaction ID:** `178150`, delivered `28.75 SAR`
* **Action:** **Disabled in Supabase** due to uncompetitive pricing (+18% markup over Zendit).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Top-Up:** **DingConnect** (`XCSASA72721` - 20 SAR / 2.68 OMR = $6.97 USD, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Zendit** (`STC_SA_001_USD` - 20 SAR / $7.10 USD, `priority: 20`).
3. **Tertiary PIN Failover:** **DT One** (`59797` - 20 SAR PIN / 2.532 OMR, `priority: 30`) or **DingConnect PIN** (`S6SASA72721`).
4. **Disabled Provider:** **Reloadly** (`is_enabled: false` in `carrier_provider_map`).
5. **CST Rule Compliance:** STC lines require a qualifying recharge within 90 days (180 days total line termination). The 20 SAR mini-recharge qualifies and resets the 90-day activity timer.
