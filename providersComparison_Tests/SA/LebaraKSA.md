# Provider Comparison & Test Report: Lebara KSA (Saudi Arabia)

> **Country:** Saudi Arabia (`SA` / `+966` / `SAU`)  
> **Carrier:** Lebara KSA (Lebara Mobile Saudi Arabia / Host: Mobily)  
> **Network Type:** MVNO  
> **Balance USSD:** `*110#` | **Recharge USSD:** `*111*<PIN>#` | **IVR:** `1755`  
> **Test Date:** 2026-08-20  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `SAU` (ISO-3) | `SA` (ISO-2) | `SA` (ISO-2) | `SA` (ISO-2) |
| **Carrier / Operator Code** | `2085` ("Lebara PIN Saudi Arabia") | `Lebara` | `Lebara` | `ESSA` ("Lebara KSA") |
| **Delivery Mechanism** | Digital PIN Voucher | **Unsupported** in SA | **Unsupported** *(0 offers)* | Direct Airtime & PIN Voucher |
| **Settlement Currency** | **`OMR`** (Major Units) | `USD` | `USD` | **`OMR`** (Major Units) |
| **Product Count** | 9 Products (Airtime & Data PINs) | **0 Offers** | **0 Offers** | 10 SKUs (Airtime & Data) |
| **DB Status in `carrier_provider_map`** | 🟢 Enabled (`priority: 20`) | 🔴 **Disabled** | 🔴 **Disabled** | 🟢 **Primary Provider** (`is_primary: true`, `priority: 10`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (SAR) | DT One Wholesale (`OMR`) / Product ID | Reloadly Cost (`USD`) | Zendit Wholesale (`USD`) | DingConnect Wholesale (`OMR`) / SKU |
| :---: | :---: | :---: | :---: | :---: |
| **23.00 SAR** | **2.867 OMR** (`53582`) | — *(Unsupported)* | — *(Unsupported)* | **3.07 OMR** (`ESSA76375`) |
| **25.00 SAR (Data 1GB)** | **3.083 OMR** (`24246`) | — *(Unsupported)* | — *(Unsupported)* | — |
| **30.00 SAR** | **3.738 OMR** (`32072`) | — *(Unsupported)* | — *(Unsupported)* | **4.00 OMR** (`ESSASA12244`) |
| **35.00 SAR** | — | — *(Unsupported)* | — *(Unsupported)* | **4.67 OMR** (`ESSA9800`) |
| **55.00 SAR (Data 3GB)** | **6.775 OMR** (`24247`) | — *(Unsupported)* | — *(Unsupported)* | **7.17 OMR** (`ESSASA90088`) |
| **60.00 SAR** | **7.476 OMR** (`32073`) | — *(Unsupported)* | — *(Unsupported)* | **8.01 OMR** (`ESSASA51894`) |
| **105.00 SAR (Data 10GB)**| — | — *(Unsupported)* | — *(Unsupported)* | **13.68 OMR** (`ESSASA222`) |
| **115.00 SAR** | **14.329 OMR** (`32074`) | — *(Unsupported)* | — *(Unsupported)* | **15.34 OMR** (`ESSASA31863`) |
| **130.00 SAR (Data 10GB)**| **16.031 OMR** (`32380`) | — *(Unsupported)* | — *(Unsupported)* | **16.63 OMR** (`ESSASA68202`) |
| **230.00 SAR** | **28.657 OMR** (`32075`) | — *(Unsupported)* | — *(Unsupported)* | **30.68 OMR** (`ESSASA70433`) |
| **345.00 SAR** | **42.985 OMR** (`32076`) | — *(Unsupported)* | — *(Unsupported)* | **46.02 OMR** (`ESSASA94750`) |

---

## 3. Live Test & Simulation Results

### 1. DingConnect (UAT Environment)
* **Dry-Run Test (`ValidateOnly: true`):** SKU `ESSA76375` (23 SAR) $\rightarrow$ `ResultCode: 1` (`ProcessingState: Complete`)
* **Live Simulation:** SKU `ESSA76375` with UAT number `966000000000` $\rightarrow$ `ResultCode: 1`, `TransferRef: 860880159`, Delivered PIN: `001675016992`

### 2. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `24246` (25 SAR Data SIM PIN) to `+966500000101`
* **Status:** `201 Created` $\rightarrow$ Polled status: `COMPLETED`
* **Delivered Artifact:** Transaction ID `2240786996`, Delivered PIN: `1559303168`

### 3. Reloadly (Sandbox API)
* **Result:** Operator not present in Reloadly's Saudi Arabia catalog. Disabled in `carrier_provider_map`.

### 4. Zendit (Test Environment)
* **Result:** **0 offers available** for Lebara in SA. Disabled in `carrier_provider_map`.

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Provider:** **DingConnect** (`ESSA` / `ESSA76375` - 23 SAR / 3.07 OMR).
2. **Secondary / PIN Failover:** **DT One** (`2085` / `53582` - 23 SAR PIN / 2.867 OMR).
3. **Disabled Providers:** **Reloadly** & **Zendit** (`is_enabled: false`) due to lack of catalog support.
4. **CST Rule Compliance:** 23 SAR recharge satisfies the 90-day qualifying window.
