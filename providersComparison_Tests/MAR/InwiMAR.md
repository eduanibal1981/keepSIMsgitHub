# Provider Comparison & Test Report: Inwi Morocco

> **Country:** Morocco (`MA` / `+212` / `MAR`)  
> **Carrier:** Inwi (Wana Corporate / Al Mada Group)  
> **Network Type:** MNO (~17% Market Share / ~8M+ Mobile Subscribers / Prepaid Brand: **Inwi Tic Tac**)  
> **Balance USSD:** Dial `*120*30#` or `*120*1#` (Balance & Validity)  
> **Recharge USSD:** Dial `*120#` (Self-care Menu) or `*120*20*<PIN>#`:
>   * Direct Airtime: `*120*20*<PIN>#`
>   * Pass *3 (Internet 4G/5G): `*120*20*<PIN>*3#`
>   * Pass *1 (Calls): `*120*20*<PIN>*1#`
>   * Pass *6 (Social Media / WhatsApp, FB, IG): `*120*20*<PIN>*6#`
>   * Pass *8 (International Calls): `*120*20*<PIN>*8#`  
> **Customer Care:** `220` (From Inwi) / `0529 000 220` / `+212 529 000 220` | **Self-Care App:** My Inwi  
> **Regulatory Policy (ANRT Morocco):** 90 to 180-day active validity from last recharge + 90-day grace/suspension period before permanent disconnection & number recycling | All recharges subject to 20% Moroccan TVA (VAT) included in retail  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `MAR` (ISO-3) | `MA` (ISO-2) | `MA` (ISO-2) | `MA` (ISO-2) |
| **Carrier / Operator Code** | `1711` ("Inwi Morocco") | `312` ("Inwi Morocco") / `308` ("Inwi Morocco Data") / `688` ("Inwi Bundles") | `Inwi` | `INMA` ("Inwi Morocco") / `I0MA` ("Inwi Bundles") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Pass *3 Data / Social | Direct Airtime Top-Up & Data Bundles | Direct Top-Up (0 Inventory in Sandbox) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 23 Fixed Products (5 to 300 MAD Airtime, Pass *3 Data, Social Media) | Fixed Amounts `312` (5 to 200 MAD / $0.60–$23.35 USD) + Data `308` (500MB to 20GB / $0.60–$26.15 USD) | 0 Active Offers in Sandbox | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 50`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (MAD) / Description | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) | DingConnect Direct (`INMA`) |
| :---: | :---: | :---: | :---: | :---: |
| **5.00 MAD** (Min Entry Airtime) | **0.245 OMR ($0.637 USD)** (`16801`) | **$0.570 USD** (`312`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **5.00 MAD** (Pass *3: 500MB 1d) | **0.245 OMR ($0.637 USD)** (`1927`) | **$0.594 USD** (`308`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **5.00 MAD** (500MB Social 1d) | **0.245 OMR ($0.637 USD)** (`57212`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **10.00 MAD** (Standard Airtime) | **0.489 OMR ($1.271 USD)** (`8158`) | **$1.140 USD** (`312`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **10.00 MAD** (Pass *3: 1GB 7d) | **0.489 OMR ($1.271 USD)** (`1928`) | **$1.336 USD** (`308`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **10.00 MAD** (1GB Social 7d) | **0.489 OMR ($1.271 USD)** (`57213`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **15.00 MAD** (Fixed Airtime) | **0.762 OMR ($1.981 USD)** (`17217`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **20.00 MAD** (Standard Airtime) | **0.977 OMR ($2.540 USD)** (`8159`) | **$2.232 USD** (`312`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **20.00 MAD** (Pass *3: 2GB 14d) | **0.977 OMR ($2.540 USD)** (`1929`) | **$2.574 USD** (`308`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **20.00 MAD** (2GB Social 15d) | **0.977 OMR ($2.540 USD)** (`57214`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **25.00 MAD** (Fixed Airtime) | **1.221 OMR ($3.175 USD)** (`17156`) | **$3.267 USD** (`308` 2.5GB) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **30.00 MAD** (Standard Airtime) | **1.465 OMR ($3.809 USD)** (`17218`) | **$3.372 USD** (`312`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **30.00 MAD** (Pass *3: 3GB 14d) | **1.465 OMR ($3.809 USD)** (`1930`) | **$3.910 USD** (`308`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **30.00 MAD** (3GB Social 30d) | **1.465 OMR ($3.809 USD)** (`57215`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **50.00 MAD** (Standard Airtime) | **2.441 OMR ($6.347 USD)** (`8160`) | **$5.557 USD** (`312`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **50.00 MAD** (Pass *3: 5GB 30d) | **2.441 OMR ($6.347 USD)** (`1932`) | **$6.484 USD** (`308`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **50.00 MAD** (Social Media Pass) | **2.441 OMR ($6.347 USD)** (`66787`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **100.00 MAD** (Standard Airtime) | **4.881 OMR ($12.691 USD)** (`8161`) | **$11.115 USD** (`312`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **100.00 MAD** (Pass *3: 10GB 30d) | **4.881 OMR ($12.691 USD)** (`1933`) | **$12.969 USD** (`308`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **150.00 MAD** (Standard Airtime) | **7.322 OMR ($19.037 USD)** (`17240`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **200.00 MAD** (Standard Airtime) | **9.762 OMR ($25.381 USD)** (`17321`) | **$22.182 USD** (`312`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **200.00 MAD** (Pass *3: 20GB 30d) | **9.762 OMR ($25.381 USD)** (`1934`) | **$25.888 USD** (`308`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **300.00 MAD** (Max Airtime) | **14.643 OMR ($38.072 USD)** (`17323`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `16801` (Inwi Morocco 5 MAD Airtime) to `+212620000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793445`, Wholesale Cost: `0.245 OMR` (~$0.637 USD), Delivered: `5 MAD Airtime`
* **Test Request 2:** Product `1927` (Inwi Internet Pass 500MB) to `+212620000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793431`, Wholesale Cost: `0.245 OMR` (~$0.637 USD), Delivered: `500 MB Data`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request 1:** Operator `312` (Inwi Morocco Airtime, $0.60 USD fixed) to `+212620000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178467`, Delivered: `5.51 MAD`, Cost: `$0.57 USD` (5% discount)
* **Test Request 2:** Operator `308` (Inwi 500MB Data 1 Day, $0.60 USD) to `+212620000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178468`, Delivered: `5.51 MAD / 500MB`, Cost: `$0.594 USD` (1% discount)
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `INMA` ("Inwi Morocco") / `I0MA` ("Inwi Bundles")
* **Catalog Status:** Returns `503 RateLimited / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

### 4. Zendit (Test Environment) — 🔴 Disabled Route
* **Brand:** `Inwi`
* **Catalog Status:** 0 active offers returned in sandbox for country `MA`.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 50`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1711` — delivers direct nominal airtime from 5 MAD for `0.245 OMR` / ~$0.64 USD, plus full Pass *3 internet data tiers up to 20GB and social media passes with instant pre-prod confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 312` for Airtime and `308` for Data — reliable secondary direct rail with 7 airtime tiers and 8 data bundles, `priority: 20`).
3. **Disabled Providers:** **DingConnect** (`INMA`, `priority: 40`) and **Zendit** (`Inwi`, `priority: 50`) due to 0 active inventory.
4. **ANRT Morocco Regulatory Compliance & Mini-Refill Strategy:**
   - Inwi prepaid lines have a standard active validity period of **90 to 180 days** from the last recharge event.
   - Following expiration, a **90-day grace/suspension period** begins (incoming calls/SMS preserved).
   - If no recharge is processed within the grace window, the line is permanently disconnected and recycled.
   - **KeepSIMs Automated Action:** Schedules automated mini-refills on **Day 60–80** (delivering 5 MAD for `0.245 OMR` / ~$0.64 USD via DT One) to permanently reset the 180-day ANRT active validity window.
