# Provider Comparison & Test Report: Vodafone Qatar

> **Country:** Qatar (`QA` / `+974` / `QAT`)  
> **Carrier:** Vodafone Qatar Q.S.C. (`Vodafone Qatar` / Vodafone Group & Qatar Foundation)  
> **Network Type:** MNO (#2 National Operator / Vodafone Prepaid Flex, Combo & Postpaid)  
> **Balance USSD / SMS:** Dial `*129#` (Main Balance & Validity) or My Vodafone Qatar App | **Data Balance:** Dial `*129#` or `*100#`  
> **Recharge USSD:** Dial `*127*<PIN>#` or `*233*<PIN>#` (or dial `111` / `611`)  
> **Customer Care:** `111` (from Vodafone SIM) / `+97470000111` / `8007111`  
> **Regulatory Policy (CRA Qatar):** Recharges of 10–80 QAR grant 30-day credit validity, while **line validity extends for 180 days** from the recharge timestamp. If no recharge occurs within **180 days**, the line is suspended with a **180-day grace/reactivation window** before the MSISDN is permanently extinguished and recycled to the CRA pool.  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `QAT` (ISO-3) | `QA` (ISO-2) | `QA` (ISO-2) | `QA` (ISO-2) |
| **Carrier / Operator Code** | `2722` ("Vodafone PIN Qatar") | `395` ("Vodafone PIN Qatar") | `Vodafone` | `VFQA` ("Vodafone Qatar") |
| **Delivery Mechanism** | **Digital PIN Voucher** (Airtime Credits) | **Digital PIN Voucher** (Delivered in Response Payload) | Direct Top-Up (0 Inventory in Catalog) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** (1% Wholesale Discount) | **`USD`** | **`OMR`** |
| **Catalog Format** | Fixed PIN: 10 QAR (`17355`), 20 QAR (`17356`), 200 QAR (`17361`), 300 QAR (`17362`) | Fixed PIN: $3.60, $6.20, $12.50, $17.80, $19.60, $23.20, $31.00, $35.60 USD | 0 Active Offers | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary PIN Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary PIN Route** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (QAR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID `395` | Zendit Wholesale (`USD`) | DingConnect Direct (`VFQA`) | Delivery Type |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **10.00 QAR** (Min Entry) | **1.288 OMR ($3.35 USD)** (`17355`) | **$3.564 USD net** ($3.60 gross, 1% disc) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | **Digital PIN Voucher** |
| **20.00 QAR** (Standard Airtime) | **2.576 OMR ($6.70 USD)** (`17356`) | **$6.138 USD net** ($6.20 gross, 1% disc) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | **Digital PIN Voucher** |
| **40.00 QAR** (Standard Airtime) | — | **$12.375 USD net** ($12.50 gross, 1% disc) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | Digital PIN Voucher |
| **60.00 QAR** (Standard Airtime) | — | **$17.622 USD net** ($17.80 gross, 1% disc) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | Digital PIN Voucher |
| **75.00 QAR** (Standard Airtime) | — | **$22.968 USD net** ($23.20 gross, 1% disc) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | Digital PIN Voucher |
| **100.00 QAR** (Standard Airtime) | — | **$30.690 USD net** ($31.00 gross, 1% disc) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | Digital PIN Voucher |
| **200.00 QAR** (Large Refill) | **25.776 OMR ($67.02 USD)** (`17361`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | Digital PIN Voucher |
| **300.00 QAR** (Max Voucher) | **38.664 OMR ($100.53 USD)** (`17362`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | Digital PIN Voucher |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary PIN Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `17355` (Vodafone PIN Qatar 10 QAR) to `+97477000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793396`, Wholesale Cost: `1.288 OMR` (~$3.35 USD), Delivered: `10 QAR`, Balance/Recharge: `*129#` / `*127*PIN#`
* **Test Request 2:** Product `17356` (Vodafone PIN Qatar 20 QAR) to `+97477000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793397`, Wholesale Cost: `2.576 OMR` (~$6.70 USD), Delivered: `20 QAR`
* **Result:** **Primary Active PIN Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary PIN Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `395` (Vodafone PIN Qatar, $3.60 USD) to `+97477000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178442`, Delivered: `13.12 QAR`, Net Cost: `$3.564 USD` (1% discount applied), PIN Details: Code `773709732465539`, Serial `457506`, Instructions: `Dial *233* and PIN #`
* **Result:** **Secondary Active PIN Route** (`priority: 20`, `is_enabled: true`).

### 3. Zendit (Test Environment) — 🔴 Disabled Route
* **Brand Code:** `Vodafone`
* **Catalog Status:** Returns 0 active offers for `country=QA`.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `VFQA` ("Vodafone Qatar")
* **Validation Regex:** `^974[0-9]{8}$|^0000000000$`
* **Catalog Status:** Returns `503 Service Unavailable / RateLimited / 0 items` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary PIN Route:** **DT One** (`operatorId: 2722` — delivers 10 QAR, 20 QAR, 200 QAR, 300 QAR digital vouchers with lowest wholesale entry rate at 1.288 OMR / ~$3.35 USD, `priority: 10`, `is_primary: true`).
2. **Secondary PIN Route:** **Reloadly** (`operatorId: 395` — delivers instant digital PIN codes in payload response starting at $3.564 USD net, `priority: 20`).
3. **Disabled Providers:** **Zendit** (`brand: Vodafone`, `priority: 30`, `is_enabled: false`) & **DingConnect** (`VFQA`, `priority: 40`, `is_enabled: false`).
4. **CRA Qatar Regulatory Compliance:**
   - Vodafone Qatar prepaid recharges provide 30 days of credit spending validity, but **180 days of overall line validity**.
   - If no recharge is completed for **180 consecutive days**, the SIM is suspended.
   - The subscriber has a **180-day grace/reactivation window** before the number is permanently cancelled and recycled to the national pool.
   - KeepSIMs schedules automated mini-refills on **Day 90–150** (delivering 10 QAR for ~$3.35 USD via DT One) to permanently reset the 180-day line validity clock.
