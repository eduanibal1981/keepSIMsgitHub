# Provider Comparison & Test Report: Salam Mobile KSA (Saudi Arabia)

> **Country:** Saudi Arabia (`SA` / `+966` / `SAU`)  
> **Carrier:** Salam Mobile KSA (Salam Telecom / Integrated Telecom Company / Host: Zain KSA)  
> **Network Type:** MVNO / Telecommunications  
> **Balance USSD:** `*106#` | **Recharge USSD:** `*104*<PIN>#` | **IVR / Care:** `1101`  
> **Test Date:** 2026-08-20  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `SAU` (ISO-3) | `SA` (ISO-2) | `SA` (ISO-2) | `SA` (ISO-2) |
| **Carrier / Operator Code** | `Salam` | `Salam` | `Salam` | `UQSA` ("Salam KSA") |
| **Delivery Mechanism** | **Unsupported** in SA | **Unsupported** in SA | **Unsupported** *(0 offers)* | Direct Airtime & PIN Voucher |
| **Settlement Currency** | `OMR` | `USD` | `USD` | **`OMR`** (Major Units) |
| **Product Count** | **0 Offers** | **0 Offers** | **0 Offers** | 3 SKUs (Airtime 20 to 100 SAR) |
| **DB Status in `carrier_provider_map`** | 🔴 **Disabled** | 🔴 **Disabled** | 🔴 **Disabled** | 🟢 **Exclusive Primary** (`is_primary: true`, `priority: 10`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (SAR) | DT One Wholesale (`OMR`) | Reloadly Cost (`USD`) | Zendit Wholesale (`USD`) | DingConnect Wholesale (`OMR`) / SKU |
| :---: | :---: | :---: | :---: | :---: |
| **20.00 SAR** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **2.65 OMR** (`UQSASA83969`) |
| **50.00 SAR** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **6.61 OMR** (`UQSASA14400`) |
| **100.00 SAR** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **13.21 OMR** (`UQSASA63664`) |

---

## 3. Live Test & Simulation Results

### 1. DingConnect (UAT Environment)
* **Dry-Run Test (`ValidateOnly: true`):** SKU `UQSASA83969` (20 SAR) $\rightarrow$ `ResultCode: 1` (`ProcessingState: Complete`)
* **Live Simulation:** SKU `UQSASA83969` with UAT number `966000000000` $\rightarrow$ `ResultCode: 1`, `TransferRef: 860880391`, Delivered PIN: `001549548216`

### 2. DT One, Reloadly, & Zendit
* **Result:** No catalog inventory available across DT One, Reloadly, or Zendit for Salam in Saudi Arabia. Disabled in `carrier_provider_map`.

---

## 4. KeepSIMs Production Routing Decision

1. **Exclusive Primary Provider:** **DingConnect** (`UQSA` / `UQSASA83969` - 20 SAR / 2.65 OMR).
2. **Disabled Providers:** **DT One**, **Reloadly**, and **Zendit** (`is_enabled: false`) due to lack of inventory.
3. **CST Rule Compliance:** 20 SAR recharge satisfies the 90-day qualifying window under CITC/CST regulations.
