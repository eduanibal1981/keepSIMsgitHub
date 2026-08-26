# Provider Comparison & Test Report: Virgin Mobile KSA (Saudi Arabia)

> **Country:** Saudi Arabia (`SA` / `+966` / `SAU`)  
> **Carrier:** Virgin Mobile KSA (Virgin Mobile Saudi Arabia Consortium / Host: STC)  
> **Network Type:** MVNO  
> **Balance USSD:** `*102#` | **Recharge USSD:** `*101*<PIN>#` | **IVR:** `101`  
> **Test Date:** 2026-08-20  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `SAU` (ISO-3) | `SA` (ISO-2) | `SA` (ISO-2) | `SA` (ISO-2) |
| **Carrier / Operator Code** | `2086` ("Virgin PIN Saudi Arabia") | `427` ("Virgin PIN Saudi Arabia") | `Virgin Mobile` | `VRSA` ("Virgin KSA") |
| **Delivery Mechanism** | Digital PIN Voucher | Digital PIN Voucher | **Unsupported** *(0 offers)* | Direct Airtime & PIN Voucher |
| **Settlement Currency** | **`OMR`** (Major Units) | **`USD`** | `USD` | **`OMR`** (Major Units) |
| **Product Count** | 4 Products (20 to 100 SAR PINs) | 5 Fixed PIN Tiers | **0 Offers** | 9 SKUs (Airtime & Data) |
| **DB Status in `carrier_provider_map`** | 🟢 Enabled (`priority: 20`) | 🟢 Enabled (`priority: 25`) | 🔴 **Disabled** (`is_enabled: false`) | 🟢 **Primary Provider** (`is_primary: true`, `priority: 10`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (SAR) | DT One Wholesale (`OMR`) / Product ID | Reloadly Cost (`USD`) / Product ID | Zendit Wholesale (`USD`) | DingConnect Wholesale (`OMR`) / SKU |
| :---: | :---: | :---: | :---: | :---: |
| **15.00 SAR** | — | **$4.55 USD** (`rl_427_4.55`) | — *(Unsupported)* | **1.98 OMR** (`VRSASA3546`) |
| **20.00 SAR** | **2.499 OMR** (`14520`) | **$6.05 USD** (`rl_427_6.05`) | — *(Unsupported)* | **2.63 OMR** (`VRSASA19763`) |
| **30.00 SAR** | **3.749 OMR** (`25202`) | **$9.00 USD** (`rl_427_9`) | — *(Unsupported)* | **3.94 OMR** (`VRSASA22615`) |
| **50.00 SAR** | **6.247 OMR** (`14521`) | **$15.05 USD** (`rl_427_15.05`) | — *(Unsupported)* | **6.57 OMR** (`VRSASA5260`) |
| **100.00 SAR** | **12.493 OMR** (`14522`) | **$30.15 USD** (`rl_427_30.15`)| — *(Unsupported)* | **13.14 OMR** (`VRSASA29925`) |
| **Data: 1.5GB Data (34.50 SAR)**| — | — | — *(Unsupported)* | **4.47 OMR** (`VRSA31715`) |
| **Data: 10GB Data (119.60 SAR)**| — | — | — *(Unsupported)* | **15.47 OMR** (`VRSA76788`) |
| **Data: 50GB Data (224.83 SAR)**| — | — | — *(Unsupported)* | **29.07 OMR** (`VRSA77725`) |
| **Data: 100GB Data (329.99 SAR)**| — | — | — *(Unsupported)* | **42.67 OMR** (`VRSA35849`) |

---

## 3. Live Test & Simulation Results

### 1. DingConnect (UAT Environment)
* **Dry-Run Test (`ValidateOnly: true`):** SKU `VRSASA3546` (15 SAR) $\rightarrow$ `ResultCode: 1` (`ProcessingState: Complete`)
* **Live Simulation:** SKU `VRSASA3546` with UAT number `966000000000` $\rightarrow$ `ResultCode: 1`, `TransferRef: 860880043`, Delivered PIN: `000509137138`

### 2. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `14520` (20 SAR PIN) to `+966500000101`
* **Status:** `201 Created` $\rightarrow$ Polled status: `COMPLETED`
* **Delivered Artifact:** Transaction ID `2240786993`, Delivered PIN: `916752527`

### 3. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `427`, $4.55 USD to `966570000000`
* **Status:** `200 OK` $\rightarrow$ `SUCCESSFUL`
* **Transaction ID:** `178170`, delivered `17.10 SAR`

### 4. Zendit (Test Environment)
* **Result:** **0 offers available** for Virgin in SA. Disabled in `carrier_provider_map`.

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Provider:** **DingConnect** (`VRSA` / `VRSASA3546` - 15 SAR / 1.98 OMR). Ding offers the lowest entry recharge tier (15 SAR) in Saudi Arabia.
2. **Secondary / PIN Failover:** **DT One** (`2086` / `14520` - 20 SAR PIN / 2.499 OMR) or **Reloadly** (`427` / `rl_427_4.55` - $4.55 USD).
3. **Disabled Provider:** **Zendit** (`is_enabled: false`) due to zero catalog offers.
4. **CST Rule Compliance:** 15 SAR recharge satisfies the 90-day qualifying activity window.
