# Provider Comparison & Test Report: Omantel (Oman Telecommunications Company)

> **Country:** Oman (`OM` / `+968` / `OMN`)  
> **Carrier:** Oman Telecommunications Company (`Omantel` / `Hayyak`)  
> **Network Type:** MNO (National Incumbent Carrier)  
> **Balance USSD / SMS:** Dial `*100#` (USSD Menu) | **Recharge USSD:** Dial `*101*<PIN>#` | **Account App:** Omantel App  
> **Customer Care:** `1234` / `+96824241234`  
> **Regulatory Policy (TRA Oman):** 180 Days Active Line Validity from last qualifying transaction/recharge | 30 Days Suspension Grace Period before permanent deactivation and number recycling  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **DT One** (`dtone`) | **DingConnect** (`ding`) | **Zendit** (`zendit`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `OM` (ISO-2) | `OMN` (ISO-3) | `OM` (ISO-2) | `OM` (ISO-2) |
| **Carrier / Operator Code** | `348` ("Omantel PIN Oman") | `2695` ("Omantel PIN Oman") | `OMOM` ("Omantel Oman") | `Omantel` |
| **Delivery Mechanism** | Digital PIN Voucher | Digital PIN Voucher & Hayyak Packs | Direct Top-Up / PIN (UAT Mapped) | Direct Top-Up (0 Inventory in OM) |
| **Settlement Currency** | **`USD`** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`OMR`** | **`USD`** |
| **Catalog Format** | 4 Fixed Amounts ($3.00–$29.65 USD) | 8 Fixed PIN Products (1–10 OMR) | Direct / PIN via `OMOM` | 0 Active Products in OM |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary PIN Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary PIN Failover** (`priority: 20`) | 🟢 **Tertiary Route** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (OMR) | Reloadly Wholesale (`USD`) / Op ID | DT One Wholesale (`OMR` / `USD`) / Product ID | DingConnect Direct (`OMOM`) | Zendit Direct (`Omantel`) |
| :---: | :---: | :---: | :---: | :---: |
| **1.00 OMR** | **$2.955 USD** (`348` $3.00 Fixed) | **1.240 OMR ($3.224 USD)** (`17091` 1 OMR) | 🟢 Mapped (`OMOM`) | 🔴 *(0 Catalog Offers)* |
| **1.50 OMR** | — | **1.860 OMR ($4.836 USD)** (`42648` 1.5 OMR) | 🟢 Mapped (`OMOM`) | 🔴 *(0 Catalog Offers)* |
| **2.00 OMR** | — | **2.480 OMR ($6.448 USD)** (`42649` 2 OMR) | 🟢 Mapped (`OMOM`) | 🔴 *(0 Catalog Offers)* |
| **3.00 OMR** | **$8.766 USD** (`348` $8.90 Fixed) | **3.720 OMR ($9.672 USD)** (`17092` 3 OMR) | 🟢 Mapped (`OMOM`) | 🔴 *(0 Catalog Offers)* |
| **5.00 OMR** (Hayyak 5) | **$14.627 USD** (`348` $14.85 Fixed) | **6.020 OMR ($15.652 USD)** (`67393` Hayyak 5) / `6.199 OMR` (`17093`) | 🟢 Mapped (`OMOM`) | 🔴 *(0 Catalog Offers)* |
| **8.00 OMR** (Hayyak 8) | — | **9.631 OMR ($25.040 USD)** (`67392` Hayyak 8) | 🟢 Mapped (`OMOM`) | 🔴 *(0 Catalog Offers)* |
| **10.00 OMR** | **$29.205 USD** (`348` $29.65 Fixed) | **12.397 OMR ($32.232 USD)** (`17094` 10 OMR) | 🟢 Mapped (`OMOM`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `348` ($3.00 USD $\rightarrow$ 1 OMR PIN) to `+96891000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178387`, Net Cost: `$2.955 USD`, PIN Code: `773709732644934`, Serial: `603054`
* **Result:** **Primary PIN Route** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `17091` (Omantel PIN Oman 1 OMR) to `+96891000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CREATED` (Confirmed)
* **Delivered Artifact:** Transaction ID `2240792136`, Wholesale Cost: `1.240 OMR` (~$3.224 USD)
* **USSD Instructions Returned:** `"To recharge your account: Dial *101*recharge pin#", "To check your credit balance: Dial *100#", "IVR: 1234"`
* **Result:** **Secondary PIN Failover** (`priority: 20`).

### 3. DingConnect (UAT Environment)
* **Provider Code:** `OMOM` ("Omantel Oman")
* **Validation Regex:** `^968[0-9]{8}$|^0000000000$`
* **Result:** **Tertiary Route** (`priority: 30`).

### 4. Zendit (Test Environment)
* **Catalog Status:** 0 active offers for brand `Omantel` in Oman.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **Reloadly** (`operatorId: 348` — verified digital PIN voucher delivery at $2.955 USD net cost for 1 OMR PIN, `priority: 10`, `is_primary: true`).
2. **Secondary Failover:** **DT One** (`operatorId: 2695` — deep catalog of 8 fixed PIN products from 1 OMR to 10 OMR including Hayyak 5 and Hayyak 8 packs at 1.240 OMR wholesale, `priority: 20`).
3. **Tertiary Route:** **DingConnect** (`providerCode: OMOM`, `priority: 30`).
4. **Disabled Provider:** **Zendit** (`brand: Omantel`, `priority: 40`, `is_enabled: false`).
5. **TRA Oman Regulatory Compliance:**
   - Omantel Hayyak prepaid SIM cards maintain an active validity of **180 days** from the date of the last qualifying paid event or recharge.
   - If no recharge occurs within 180 days, the line enters a **30-day grace/suspension period** (incoming calls only) before permanent cancellation and recycling.
   - KeepSIMs schedules automated mini-refills on **Day 140–150** or every 90 days, delivering a 1 OMR PIN voucher to refresh the 180-day validity counter indefinitely.
