# Provider Comparison & Test Report: Friendi KSA (Saudi Arabia)

> **Country:** Saudi Arabia (`SA` / `+966` / `SAU`)  
> **Carrier:** Friendi KSA (FRiENDi mobile Saudi Arabia / Host: Zain KSA)  
> **Network Type:** MVNO  
> **Balance USSD:** `*102#` | **Recharge USSD:** `*101*<PIN>#` | **IVR:** `101`  
> **Test Date:** 2026-08-20  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `SAU` (ISO-3) | `SA` (ISO-2) | `SA` (ISO-2) | `SA` (ISO-2) |
| **Carrier / Operator Code** | `2084` ("Friendi PIN Saudi Arabia") | `Friendi` | `Friendi` | `FRSA` ("Friendi KSA") |
| **Delivery Mechanism** | Digital PIN Voucher | **Unsupported** in SA | **Unsupported** *(0 offers)* | Direct Airtime & PIN Voucher |
| **Settlement Currency** | **`OMR`** (Major Units) | `USD` | `USD` | **`OMR`** (Major Units) |
| **Product Count** | 4 Products (20 to 100 SAR PINs) | **0 Offers** | **0 Offers** | 9 SKUs (Airtime & Data) |
| **DB Status in `carrier_provider_map`** | 🟢 Enabled (`priority: 20`) | 🔴 **Disabled** | 🔴 **Disabled** | 🟢 **Primary Provider** (`is_primary: true`, `priority: 10`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (SAR) | DT One Wholesale (`OMR`) / Product ID | Reloadly Cost (`USD`) | Zendit Wholesale (`USD`) | DingConnect Wholesale (`OMR`) / SKU |
| :---: | :---: | :---: | :---: | :---: |
| **15.00 SAR** | — | — *(Unsupported)* | — *(Unsupported)* | **1.98 OMR** (`FRSASA79607`) |
| **20.00 SAR** | **2.496 OMR** (`14516`) | — *(Unsupported)* | — *(Unsupported)* | **2.63 OMR** (`FRSASA1075`) |
| **30.00 SAR** | **3.749 OMR** (`25200`) | — *(Unsupported)* | — *(Unsupported)* | **3.94 OMR** (`FRSASA23014`) |
| **50.00 SAR** | **6.247 OMR** (`14517`) | — *(Unsupported)* | — *(Unsupported)* | **6.57 OMR** (`FRSASA76399`) |
| **100.00 SAR** | **12.493 OMR** (`14518`) | — *(Unsupported)* | — *(Unsupported)* | **13.14 OMR** (`FRSASA56031`) |
| **Data: 1.5GB Data (34.50 SAR)**| — | — *(Unsupported)* | — *(Unsupported)* | **4.54 OMR** (`FRSA12913`) |
| **Data: 10GB Data 90D (115 SAR)**| — | — *(Unsupported)* | — *(Unsupported)* | **15.11 OMR** (`FRSA43544`) |
| **Data: 50GB Data (220 SAR)** | — | — *(Unsupported)* | — *(Unsupported)* | **28.90 OMR** (`FRSA15989`) |
| **Data: 100GB Data (330 SAR)**| — | — *(Unsupported)* | — *(Unsupported)* | **43.35 OMR** (`FRSA10422`) |

---

## 3. Live Test & Simulation Results

### 1. DingConnect (UAT Environment)
* **Dry-Run Test (`ValidateOnly: true`):** SKU `FRSASA79607` (15 SAR) $\rightarrow$ `ResultCode: 1` (`ProcessingState: Complete`)
* **Live Simulation:** SKU `FRSASA79607` with UAT number `966000000000` $\rightarrow$ `ResultCode: 1`, `TransferRef: 860880272`, Delivered PIN: `000733589317`

### 2. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `14516` (20 SAR PIN) to `+966500000101`
* **Status:** `201 Created` $\rightarrow$ Polled status: `COMPLETED`
* **Delivered Artifact:** Transaction ID `2240786997`, Delivered PIN: `1100344407`

### 3. Reloadly (Sandbox API)
* **Result:** Operator not present in Reloadly's Saudi Arabia catalog. Disabled in `carrier_provider_map`.

### 4. Zendit (Test Environment)
* **Result:** **0 offers available** for Friendi in SA. Disabled in `carrier_provider_map`.

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Provider:** **DingConnect** (`FRSA` / `FRSASA79607` - 15 SAR / 1.98 OMR).
2. **Secondary / PIN Failover:** **DT One** (`2084` / `14516` - 20 SAR PIN / 2.496 OMR).
3. **Disabled Providers:** **Reloadly** & **Zendit** (`is_enabled: false`) due to lack of catalog support.
4. **CST Rule Compliance:** 15 SAR recharge satisfies the 90-day qualifying activity window.
