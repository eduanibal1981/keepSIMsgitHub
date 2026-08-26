# Provider Comparison & Test Report: Renna Mobile Oman

> **Country:** Oman (`OM` / `+968` / `OMN`)  
> **Carrier:** Renna Mobile (Majan Telecommunication LLC)  
> **Network Type:** MVNO (Host: Omantel)  
> **Balance USSD / SMS:** Dial `*181*2#` | **Recharge USSD:** Dial `*180*<PIN>#` | **IVR:** `180` | **Account App:** Renna Mobile App  
> **Customer Care:** `1240` / `+96893001240`  
> **Regulatory Policy (TRA Oman):** 180 Days Active Line Validity from last qualifying transaction/recharge + 30 Days Grace Period  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) | **Zendit** (`zendit`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `OMN` (ISO-3) | `OM` (ISO-2) | `OM` (ISO-2) | `OM` (ISO-2) |
| **Carrier / Operator Code** | `2697` ("Renna PIN Oman") | `349` ("Renna PIN Oman") | `Renna` | `Renna` |
| **Delivery Mechanism** | Digital PIN Voucher (Micro-PIN) | Digital PIN Voucher | Unsupported in Ding | Unsupported in Catalog |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`OMR`** | **`USD`** |
| **Catalog Format** | 8 Fixed PIN Products (0.3–20 OMR) | 6 Fixed PIN Amounts ($1.50–$29.45 USD) | 0 Active Products | 0 Active Products in OM |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Micro-PIN Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary PIN Failover** (`priority: 20`) | 🔴 **Disabled** (`priority: 30`) | 🔴 **Disabled** (`priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (OMR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | DingConnect Direct | Zendit Direct |
| :---: | :---: | :---: | :---: | :---: |
| **0.30 OMR** (Micro-PIN) | **0.370 OMR ($0.962 USD)** (`42651` 0.3 OMR) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **0.50 OMR** | — | **$1.478 USD** (`349` $1.50 Fixed) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **1.00 OMR** | **1.233 OMR ($3.206 USD)** (`17106` 1 OMR) | **$2.906 USD** (`349` $2.95 Fixed) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **1.50 OMR** | **1.849 OMR ($4.807 USD)** (`17107` 1.5 OMR) | **$4.383 USD** (`349` $4.45 Fixed) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **3.00 OMR** | **3.697 OMR ($9.612 USD)** (`17108` 3 OMR) | **$8.717 USD** (`349` $8.85 Fixed) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **5.00 OMR** | **6.161 OMR ($16.019 USD)** (`17109` 5 OMR) | **$14.529 USD** (`349` $14.75 Fixed) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **7.00 OMR** | **8.625 OMR ($22.425 USD)** (`17110` 7 OMR) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **10.00 OMR** | **12.321 OMR ($32.035 USD)** (`17111` 10 OMR) | **$29.008 USD** (`349` $29.45 Fixed) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **20.00 OMR** | **24.641 OMR ($64.067 USD)** (`17112` 20 OMR) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `42651` (Renna PIN Oman 0.3 OMR) to `+96893000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792138`, Wholesale Cost: `0.370 OMR` (~$0.962 USD)
* **USSD Instructions Returned:** `"To recharge your account: Dial *180*recharge pin#", "To check your credit balance: Dial *181*2#", "IVR: 180"`
* **Result:** **Primary Micro-PIN Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `349` ($1.50 USD $\rightarrow$ 0.58 OMR PIN) to `+96893000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178389`, Net Cost: `$1.4775 USD`, PIN Code: `773709732645176`, Serial: `603055`
* **Result:** **Secondary PIN Failover** (`priority: 20`).

### 3. Zendit & DingConnect
* **Status:** Unsupported in Zendit and DingConnect catalog.
* **Result:** **Disabled Routes** (`is_enabled: false`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Micro-Refill Route:** **DT One** (`operatorId: 2697` — ultra-low wholesale entry at 0.370 OMR / ~$0.962 USD for 0.3 OMR micro-PIN, `priority: 10`, `is_primary: true`).
2. **Secondary Failover:** **Reloadly** (`operatorId: 349` — verified digital PIN voucher delivery from $1.4775 USD, `priority: 20`).
3. **TRA Oman Regulatory Compliance:**
   - Renna Mobile prepaid SIM cards maintain an active validity of **180 days** from the recharge date, even on the lowest 0.3 OMR / 0.5 OMR voucher.
   - If no recharge occurs within 180 days, a **30-day grace period** applies before line termination.
   - KeepSIMs schedules automated micro-refills on **Day 140–150** using DT One's 0.3 OMR PIN ($0.962 USD) to extend SIM validity for 180 days at minimal cost.
