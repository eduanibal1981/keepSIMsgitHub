# Provider Comparison & Test Report: Ooredoo Oman

> **Country:** Oman (`OM` / `+968` / `OMN`)  
> **Carrier:** Ooredoo Oman (formerly Nawras / Omani Qatari Telecommunications Company)  
> **Network Type:** MNO (Major National Carrier)  
> **Balance USSD / SMS:** Dial `*141#` / `*102#` | **Recharge USSD:** Dial `*115*<PIN>#` | **Account App:** Ooredoo Oman App  
> **Customer Care:** `1500` / `+96895011500`  
> **Regulatory Policy (TRA Oman):** 150 Active Days from last recharge + 30 Days Grace Period before termination and number recycling  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **DT One** (`dtone`) | **DingConnect** (`ding`) | **Zendit** (`zendit`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `OM` (ISO-2) | `OMN` (ISO-3) | `OM` (ISO-2) | `OM` (ISO-2) |
| **Carrier / Operator Code** | `1168` ("Ooredoo Oman") | `2883` ("Ooredoo PIN Oman") | `OOOM` ("Ooredoo Oman") | `Ooredoo` |
| **Delivery Mechanism** | **Direct Airtime Top-Up** | Digital PIN Voucher | Direct Top-Up (UAT Mapped) | Direct Top-Up (0 Inventory in OM) |
| **Settlement Currency** | **`USD`** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`OMR`** | **`USD`** |
| **Catalog Format** | 10 Fixed Amounts ($2.95–$29.50 USD) | 4 Fixed PIN Products (1–10 OMR) | Direct Top-Up via `OOOM` | 0 Active Products in OM |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary PIN Failover** (`priority: 20`) | 🟢 **Tertiary Route** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (OMR) | Reloadly Wholesale (`USD`) / Op ID | DT One Wholesale (`OMR` / `USD`) / Product ID | DingConnect Direct (`OOOM`) | Zendit Direct (`Ooredoo`) |
| :---: | :---: | :---: | :---: | :---: |
| **1.00 OMR** | **$2.95 USD** (`1168` $2.95 Fixed) | **1.228 OMR ($3.193 USD)** (`18802` 1 OMR) | 🟢 Mapped (`OOOM`) | 🔴 *(0 Catalog Offers)* |
| **2.00 OMR** | **$5.90 USD** (`1168` $5.90 Fixed) | **2.456 OMR ($6.386 USD)** (`18803` 2 OMR) | 🟢 Mapped (`OOOM`) | 🔴 *(0 Catalog Offers)* |
| **3.00 OMR** | **$8.85 USD** (`1168` $8.85 Fixed) | — | 🟢 Mapped (`OOOM`) | 🔴 *(0 Catalog Offers)* |
| **4.00 OMR** | **$11.80 USD** (`1168` $11.80 Fixed) | — | 🟢 Mapped (`OOOM`) | 🔴 *(0 Catalog Offers)* |
| **5.00 OMR** | **$14.75 USD** (`1168` $14.75 Fixed) | **6.136 OMR ($15.954 USD)** (`18804` 5 OMR) | 🟢 Mapped (`OOOM`) | 🔴 *(0 Catalog Offers)* |
| **6.00 OMR** | **$17.70 USD** (`1168` $17.70 Fixed) | — | 🟢 Mapped (`OOOM`) | 🔴 *(0 Catalog Offers)* |
| **7.00 OMR** | **$20.65 USD** (`1168` $20.65 Fixed) | — | 🟢 Mapped (`OOOM`) | 🔴 *(0 Catalog Offers)* |
| **8.00 OMR** | **$23.60 USD** (`1168` $23.60 Fixed) | — | 🟢 Mapped (`OOOM`) | 🔴 *(0 Catalog Offers)* |
| **9.00 OMR** | **$26.55 USD** (`1168` $26.55 Fixed) | — | 🟢 Mapped (`OOOM`) | 🔴 *(0 Catalog Offers)* |
| **10.00 OMR** | **$29.50 USD** (`1168` $29.50 Fixed) | **12.271 OMR ($31.905 USD)** (`18805` 10 OMR) | 🟢 Mapped (`OOOM`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `1168` ($2.95 USD $\rightarrow$ 1.14 OMR Direct Top-Up) to `+96895000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178388`, Delivered: `1.14 OMR`, Cost: `$2.95 USD`
* **Result:** **Primary Direct Top-Up Route** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `18802` (Ooredoo PIN Oman 1 OMR) to `+96895000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792137`, Wholesale Cost: `1.228 OMR` (~$3.193 USD)
* **USSD Instructions Returned:** `"To recharge your account: Dial *115*recharge pin#", "To check your credit balance: Dial *102# or *141#", "IVR: 1500"`
* **Result:** **Secondary PIN Failover** (`priority: 20`).

### 3. DingConnect (UAT Environment)
* **Provider Code:** `OOOM` ("Ooredoo Oman")
* **Validation Regex:** `^968[0-9]{8}$`
* **Result:** **Tertiary Route** (`priority: 30`).

### 4. Zendit (Test Environment)
* **Catalog Status:** 0 active offers for brand `Ooredoo` in Oman.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **Reloadly** (`operatorId: 1168` — verified seamless direct airtime recharge starting at $2.95 USD delivering 1.14 OMR directly to the MSISDN, `priority: 10`, `is_primary: true`).
2. **Secondary Failover:** **DT One** (`operatorId: 2883` — digital PIN voucher failover with 4 denominations 1–10 OMR at 1.228 OMR wholesale, `priority: 20`).
3. **Tertiary Route:** **DingConnect** (`providerCode: OOOM`, `priority: 30`).
4. **Disabled Provider:** **Zendit** (`brand: Ooredoo`, `priority: 40`, `is_enabled: false`).
5. **TRA Oman Regulatory Compliance:**
   - Ooredoo Oman prepaid lines carry **150 active days** from the last recharge plus a **30-day grace period** (total 180 days).
   - After 180 days total without recharge, the number is terminated and credit forfeited, with a 3-month store buyback grace.
   - KeepSIMs schedules automated mini-refills on **Day 135–145**, executing a direct top-up via Reloadly to reset the 150-day active timer safely.
