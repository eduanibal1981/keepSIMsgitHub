# Provider Comparison & Test Report: Zain KSA (Saudi Arabia)

> **Country:** Saudi Arabia (`SA` / `+966` / `SAU`)  
> **Carrier:** Zain KSA (Mobile Telecommunications Company Saudi Arabia / Yaqoot)  
> **Network Type:** MNO  
> **Balance USSD:** `*142#` | **Recharge USSD:** `*141*<PIN>#` | **IVR:** `141`  
> **Test Date:** 2026-08-19  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `SAU` (ISO-3) | `SA` (ISO-2) | `SA` (ISO-2) | `SA` (ISO-2) |
| **Carrier / Operator Code** | `3213` ("Zain Saudi Arabia") | `426` ("Zain PIN Saudi Arabia") | `Zain` | `ZKSA` ("Zain KSA") |
| **Delivery Mechanism** | Digital PIN Voucher | Digital PIN Voucher | **Unsupported** *(0 offers)* | Direct Airtime & PIN Voucher |
| **Settlement Currency** | **`OMR`** (Major Units) | **`USD`** | `USD` | **`OMR`** (Major Units) |
| **Product Count** | 7 Products | 10 Fixed PIN Tiers | **0 Offers** | 13 SKUs (Airtime & Data) |
| **DB Status in `carrier_provider_map`** | 🟢 Enabled (`priority: 20`) | 🟢 Enabled (`priority: 25`) | 🔴 **Disabled** (`is_enabled: false`) | 🟢 **Primary Provider** (`is_primary: true`, `priority: 10`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (SAR) | DT One Wholesale (`OMR`) / Product ID | Reloadly Cost (`USD`) / Product ID | Zendit Wholesale (`USD`) | DingConnect Wholesale (`OMR`) / SKU |
| :---: | :---: | :---: | :---: | :---: |
| **20.00 SAR Equivalent** | — | **$6.10 USD** (`rl_426_6.1`) | — *(Unsupported)* | — |
| **34.50 SAR** | — | **$10.55 USD** (`rl_426_10.55`) | — *(Unsupported)* | **4.60 OMR** (`ZKSASA19562`) |
| **57.50 SAR** | — | **$17.55 USD** (`rl_426_17.55`) | — *(Unsupported)* | **7.67 OMR** (`ZKSASA24945`) |
| **115.00 SAR** | **14.499 OMR** (`36587`) | **$35.05 USD** (`rl_426_35.05`) | — *(Unsupported)* | **15.33 OMR** (`ZKSASA55552`) |
| **230.00 SAR** | **28.995 OMR** (`36588`) | **$70.05 USD** (`rl_426_70.05`) | — *(Unsupported)* | **30.66 OMR** (`ZKSASA41463`) |
| **345.00 SAR** | **43.492 OMR** (`36589`) | **$105.05 USD** (`rl_426_105.05`)| — *(Unsupported)* | **45.99 OMR** (`ZKSASA43951`) |
| **575.00 SAR** | **72.487 OMR** (`36591`) | **$175.10 USD** (`rl_426_175.1`) | — *(Unsupported)* | **76.65 OMR** (`ZKSASA96378`) |
| **Data: 113.85 SAR Plan** | **14.185 OMR** (`42484`) | — | — *(Unsupported)* | — |
| **Data: 184.00 SAR Plan** | **22.927 OMR** (`32392`) | — | — *(Unsupported)* | **24.36 OMR** (`ZKSA86031`) |
| **Data: 228.85 SAR Plan** | **28.514 OMR** (`42536`) | — | — *(Unsupported)* | — |
| **Data: 25GB + 25YT 30D (115 SAR)** | — | — | — *(Unsupported)* | **15.43 OMR** (`ZKSA34878`) |
| **Data: 75GB + 75YT 60D (230 SAR)** | — | — | — *(Unsupported)* | **30.84 OMR** (`ZKSA81596`) |
| **Data: 100GB + 100YT 90D (345 SAR)**| — | — | — *(Unsupported)* | **46.27 OMR** (`ZKSASA6404`) |
| **Data: Unlimited 30D (373.75 SAR)** | — | — | — *(Unsupported)* | **49.48 OMR** (`ZKSASA83572`) |
| **Data: 300GB 90D (517.50 SAR)** | — | — | — *(Unsupported)* | **68.51 OMR** (`ZKSASA84582`) |

---

## 3. Live Test & Simulation Results

### 1. DingConnect (UAT Environment)
* **Dry-Run Test (`ValidateOnly: true`):** SKU `ZKSASA19562` (34.50 SAR) $\rightarrow$ `ResultCode: 1` (`ProcessingState: Complete`)
* **Live Simulation:** SKU `ZKSASA19562` with UAT number `966000000000` $\rightarrow$ `ResultCode: 1`, `TransferRef: 860872236`, Delivered PIN: `000673586637`

### 2. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `32392` (184 SAR Internet Plan PIN) to `+966500000101`
* **Status:** `201 Created` $\rightarrow$ Polled status: `COMPLETED`
* **Delivered Artifact:** Transaction ID `2240786818`, Delivered PIN: `272905470`

### 3. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `426`, $6.10 USD to `966590000000`
* **Status:** `200 OK` $\rightarrow$ `SUCCESSFUL`
* **Transaction ID:** `178168`, delivered `22.93 SAR`

### 4. Zendit (Test Environment)
* **Result:** **0 offers available** for Zain in SA. Disabled in `carrier_provider_map`.

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Provider:** **DingConnect** (`ZKSA` / `ZKSASA19562` - 34.50 SAR / 4.60 OMR).
2. **Secondary / PIN Failover:** **Reloadly** (`426` / `rl_426_6.1` - $6.10 USD for 20 SAR equivalent PIN) or **DT One** (`3213` / `36587` - 115 SAR PIN / 14.499 OMR).
3. **Disabled Provider:** **Zendit** (`is_enabled: false`) due to zero catalog offers.
4. **CST Rule Compliance:** 34.50 SAR (or $6.10 USD PIN) satisfies the 90-day qualifying window.
