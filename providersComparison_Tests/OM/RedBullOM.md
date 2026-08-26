# Provider Comparison & Test Report: Red Bull Mobile Oman

> **Country:** Oman (`OM` / `+968` / `OMN`)  
> **Carrier:** Red Bull MOBILE Oman (Mazoon Mobile / Red Bull Group)  
> **Network Type:** MVNO / Digital Brand (Host: Omantel)  
> **Balance USSD / SMS:** Dial `*600*11#` | **Recharge USSD:** Dial `*600*<PIN>#` | **IVR:** `1233` | **Account App:** Red Bull MOBILE Oman App  
> **Customer Care:** `1234` / `+96894001234`  
> **Regulatory Policy (TRA Oman):** 180 Days Active Line Validity from last qualifying transaction/recharge + 30 Days Grace Period  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) | **Zendit** (`zendit`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `OMN` (ISO-3) | `OM` (ISO-2) | `OM` (ISO-2) | `OM` (ISO-2) |
| **Carrier / Operator Code** | `3444` ("Red Bull Oman") | `RedBull` | `RedBull` | `RedBull` |
| **Delivery Mechanism** | Digital PIN Voucher (Micro-PIN) | Unsupported in Sandbox | Unsupported in Ding | Unsupported in Catalog |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`OMR`** | **`USD`** |
| **Catalog Format** | 6 Fixed PIN Products (0.3–10 OMR) | 0 Active Products | 0 Active Products | 0 Active Products in OM |
| **DB Status in `carrier_provider_map`** | 🟢 **Exclusive Primary Route** (`is_primary: true`, `priority: 10`) | 🔴 **Disabled** (`priority: 20`) | 🔴 **Disabled** (`priority: 30`) | 🔴 **Disabled** (`priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (OMR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) | DingConnect Direct | Zendit Direct |
| :---: | :---: | :---: | :---: | :---: |
| **0.30 OMR** (Micro-PIN) | **0.369 OMR ($0.959 USD)** (`42652` 0.3 OMR) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **0.50 OMR** | **0.615 OMR ($1.599 USD)** (`44308` 0.5 OMR) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **1.00 OMR** | **1.230 OMR ($3.198 USD)** (`28165` 1 OMR) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **3.00 OMR** | **3.689 OMR ($9.591 USD)** (`28166` 3 OMR) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **5.00 OMR** | **6.148 OMR ($15.985 USD)** (`28168` 5 OMR) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **10.00 OMR** | **12.295 OMR ($31.967 USD)** (`28170` 10 OMR) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `42652` (Red Bull PIN Oman 0.3 OMR) to `+96894000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792139`, Wholesale Cost: `0.369 OMR` (~$0.959 USD)
* **USSD Instructions Returned:** `"To recharge your account: dial * 600 * recharge pin # , to check your credit balance: dial *600*11#", "IVR: 1233"`
* **Result:** **Exclusive Primary Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly / Zendit / DingConnect
* **Status:** Unsupported in Reloadly sandbox, Zendit OM catalog, and DingConnect.
* **Result:** **Disabled Providers** (`is_enabled: false`).

---

## 4. KeepSIMs Production Routing Decision

1. **Exclusive Primary Route:** **DT One** (`operatorId: 3444` — exclusive digital PIN provider covering 6 denominations from 0.3 OMR to 10 OMR, wholesale entry at 0.369 OMR / ~$0.959 USD, `priority: 10`, `is_primary: true`).
2. **TRA Oman Regulatory Compliance:**
   - Red Bull Mobile Oman lines maintain an active validity of **180 days** from any recharge event (including 0.3 OMR micro-PIN).
   - If inactive, a **30-day grace period** applies before line termination.
   - KeepSIMs schedules automated mini-refills on **Day 140–150** using DT One's 0.3 OMR PIN to extend validity for 180 days at under $1.00 USD.
