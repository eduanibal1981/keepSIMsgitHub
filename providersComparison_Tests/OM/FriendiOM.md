# Provider Comparison & Test Report: FRiENDi Mobile Oman

> **Country:** Oman (`OM` / `+968` / `OMN`)  
> **Carrier:** FRiENDi Mobile Oman (Virgin Mobile Middle East & Africa / Connect Arabia LLC)  
> **Network Type:** MVNO (Host: Omantel)  
> **Balance USSD / SMS:** Dial `*139#` | **Recharge USSD:** Dial `*138*<PIN>#` | **Account App:** FRiENDi Mobile Oman App  
> **Customer Care:** `98400000` / `1600` / `+96898400000`  
> **Regulatory Policy (TRA Oman):** 180 Days Active Line Validity from last qualifying transaction/recharge + 30 Days Grace Period  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) | **Zendit** (`zendit`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `OMN` (ISO-3) | `OM` (ISO-2) | `OM` (ISO-2) | `OM` (ISO-2) |
| **Carrier / Operator Code** | Serviced via Omantel Rails | Serviced via Omantel Rails | `OMOM` (Omantel Host) | `Friendi` |
| **Delivery Mechanism** | Digital PIN Voucher | Digital PIN Voucher | Direct Top-Up / PIN | Unsupported in Catalog |
| **Settlement Currency** | **`OMR`** | **`USD`** | **`OMR`** | **`USD`** |
| **Catalog Format** | Cross-compatible Omantel PINs | Omantel PINs (`348`) | Ding `OMOM` | 0 Active Products in OM |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary PIN Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Failover** (`priority: 20`) | 🟢 **Tertiary Route** (`priority: 30`) | 🔴 **Disabled** (`priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (OMR) | DT One Wholesale (`OMR` / `USD`) | Reloadly Wholesale (`USD`) | DingConnect Direct | Zendit Direct |
| :---: | :---: | :---: | :---: | :---: |
| **1.00 OMR** | **1.240 OMR ($3.224 USD)** (`17091`) | **$2.955 USD** (`348`) | 🟢 Mapped | 🔴 *(0 Catalog Offers)* |
| **3.00 OMR** | **3.720 OMR ($9.672 USD)** (`17092`) | **$8.766 USD** (`348`) | 🟢 Mapped | 🔴 *(0 Catalog Offers)* |
| **5.00 OMR** | **6.020 OMR ($15.652 USD)** (`67393`) | **$14.627 USD** (`348`) | 🟢 Mapped | 🔴 *(0 Catalog Offers)* |
| **10.00 OMR** | **12.397 OMR ($32.232 USD)** (`17094`) | **$29.205 USD** (`348`) | 🟢 Mapped | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Ecosystem Delivery Confirmation
* FRiENDi Mobile operates as the pioneer MVNO in the Sultanate of Oman hosted on Omantel's physical GSM/LTE network infrastructure.
* Standard prepaid refills are fully compatible with Omantel Hayyak voucher PIN structures and direct virtual voucher rails.
* **Test Verification:** Reloadly Tx `178387` and DT One Tx `2240792136` confirmed live voucher fulfillment.

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **DT One / Reloadly** (Serviced via Omantel host voucher rails and digital PIN infrastructure, `priority: 10`, `is_primary: true`).
2. **TRA Oman Regulatory Compliance:**
   - FRiENDi Mobile lines carry a **180-day active validity window** from the last recharge event, followed by a **30-day grace period**.
   - KeepSIMs schedules automated mini-refills on **Day 140–150** to extend SIM validity for another 180 days.
