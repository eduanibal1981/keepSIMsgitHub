# Provider Comparison & Test Report: Mobily (Saudi Arabia)

> **Country:** Saudi Arabia (`SA` / `+966` / `SAU`)  
> **Carrier:** Mobily (Etihad Etisalat)  
> **Network Type:** MNO  
> **Balance USSD:** `*1411#` | **Recharge USSD:** `*1400*<PIN>#` | **IVR:** `1400`  
> **Test Date:** 2026-08-19  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `SAU` (ISO-3) | `SA` (ISO-2) | `SA` (ISO-2) | `SA` (ISO-2) |
| **Carrier / Operator Code** | `3220` ("Mobily Saudi Arabia") | `424` ("Mobily PIN Saudi Arabia") | `Mobily` | `MLSA` ("Mobily KSA") |
| **Delivery Mechanism** | Digital PIN Voucher | Digital PIN Voucher | **Unsupported** *(0 offers)* | Direct Airtime & PIN Voucher |
| **Settlement Currency** | **`OMR`** (Major Units) | **`USD`** | `USD` | **`OMR`** (Major Units) |
| **Product Count** | 14 Products | 13 Fixed PIN Tiers | **0 Offers** | 14 SKUs (Airtime & Data) |
| **DB Status in `carrier_provider_map`** | 🟢 Enabled (`priority: 20`) | 🟢 Enabled (`priority: 25`) | 🔴 **Disabled** (`is_enabled: false`) | 🟢 **Primary Provider** (`is_primary: true`, `priority: 10`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (SAR) | DT One Wholesale (`OMR`) / Product ID | Reloadly Cost (`USD`) / Product ID | Zendit Wholesale (`USD`) | DingConnect Wholesale (`OMR`) / SKU |
| :---: | :---: | :---: | :---: | :---: |
| **20.00 SAR** | **2.523 OMR** (`22062`) | **$6.15 USD** (`rl_424_6.15`) | — *(Unsupported)* | **2.68 OMR** (`MLSASA26818`) |
| **25.00 SAR** | **3.153 OMR** (`32078`) | **$7.70 USD** (`rl_424_7.7`) | — *(Unsupported)* | **3.35 OMR** (`MLSASA56609`) |
| **34.50 SAR** | **4.350 OMR** (`32079`) | **$10.60 USD** (`rl_424_10.6`) | — *(Unsupported)* | **4.62 OMR** (`MLSASA10994`) |
| **57.50 SAR** | **7.250 OMR** (`32080`) | **$17.60 USD** (`rl_424_17.6`) | — *(Unsupported)* | **7.70 OMR** (`MLSASA37329`) |
| **115.00 SAR** | **14.499 OMR** (`32081`) | **$35.20 USD** (`rl_424_35.2`) | — *(Unsupported)* | **15.39 OMR** (`MLSASA29793`) |
| **230.00 SAR** | **28.995 OMR** (`32082`) | **$70.40 USD** (`rl_424_70.4`) | — *(Unsupported)* | **30.77 OMR** (`MLSASA90006`) |
| **395.00 SAR** | **49.795 OMR** (`32083`) | **$120.90 USD** (`rl_424_120.9`)| — *(Unsupported)* | **53.02 OMR** (`MLSASA13972`) |
| **Data: 2GB 1M (60 SAR)** | **7.635 OMR** (`60099`) | — | — *(Unsupported)* | **8.13 OMR** (`MLSASA52938`) |
| **Data: 5GB 1M (90 SAR)** | **11.434 OMR** (`60100`) | — | — *(Unsupported)* | **12.17 OMR** (`MLSASA32381`) |
| **Data: 10GB 1M (110 SAR)**| **13.904 OMR** (`2409`) | — | — *(Unsupported)* | **14.79 OMR** (`MLSASA77742`) |
| **Data: 20GB 1M (160 SAR)**| **20.223 OMR** (`60101`) | — | — *(Unsupported)* | **21.51 OMR** (`MLSASA95097`) |
| **Data: 10GB 3M (200 SAR)**| **25.405 OMR** (`38903`) | — | — *(Unsupported)* | **27.03 OMR** (`MLSASA37008`) |
| **Data: 100GB 3M (375 SAR)**| **47.395 OMR** (`24348`) | — | — *(Unsupported)* | **50.41 OMR** (`MLSASA76233`) |
| **Data: 300GB 3M (525 SAR)**| **66.351 OMR** (`60102`) | — | — *(Unsupported)* | **70.58 OMR** (`MLSASA41788`) |

---

## 3. Live Test & Simulation Results

### 1. DingConnect (UAT Environment)
* **Dry-Run Test (`ValidateOnly: true`):** SKU `MLSASA26818` (20 SAR) $\rightarrow$ `ResultCode: 1` (`ProcessingState: Complete`)
* **Live Simulation:** SKU `MLSASA26818` with UAT number `966000000000` $\rightarrow$ `ResultCode: 1`, `TransferRef: 860870329`, Delivered PIN: `000436852098`

### 2. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `22062` (20 SAR PIN) to `+966500000101`
* **Status:** `201 Created` $\rightarrow$ Polled status: `COMPLETED`
* **Delivered Artifact:** Transaction ID `2240786802`, Delivered PIN: `2110133020`

### 3. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `424`, $6.15 USD to `966540000000`
* **Status:** `200 OK` $\rightarrow$ `SUCCESSFUL`
* **Transaction ID:** `178162`, delivered `23.11 SAR`

### 4. Zendit (Test Environment)
* **Result:** **0 offers available** for Mobily in SA. Disabled in `carrier_provider_map`.

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Provider:** **DingConnect** (`MLSA` / `MLSASA26818` - 20 SAR / 2.68 OMR).
2. **Secondary / PIN Failover:** **DT One** (`3220` / `22062` - 20 SAR PIN / 2.523 OMR) or **Reloadly** (`424` / `rl_424_6.15` - $6.15 USD).
3. **Disabled Provider:** **Zendit** (`is_enabled: false`) due to zero catalog offers.
4. **CST Rule Compliance:** 20 SAR recharge satisfies the 90-day qualifying window.
