# Provider Comparison & Test Report: Maroc Telecom (IAM)

> **Country:** Morocco (`MA` / `+212` / `MAR`)  
> **Carrier:** Maroc Telecom (Itissalat Al-Maghrib / IAM — Incumbent National Market Leader)  
> **Network Type:** MNO (~50% Market Share / ~20M+ Mobile Subscribers / Prepaid Brand: **Jawal**)  
> **Balance USSD:** Dial `#580#` (Main Airtime Balance), `#554#` (Pass Jawal Balance & Expiration)  
> **Recharge USSD:** Dial `*444#` or `*555#` followed by `<PIN>`:
>   * Direct Airtime: `*444*<PIN>#` or `*555*<PIN>#`
>   * Pass *3 (Internet 4G/5G): `*444*<PIN>*3#`
>   * Pass *1 (National / International Calls): `*444*<PIN>*1#`
>   * Pass *6 (Social Media): `*444*<PIN>*6#`
>   * Pass *22 (Multiple Bonus Promotion): `*444*<PIN>*22#`  
> **Customer Care:** `888` (From Jawal) / `+212 537 719 000` / `0801000888` | **Self-Care App:** Mon Espace MT  
> **Regulatory Policy (ANRT Morocco):** 90 to 180-day active validity from last recharge + 90-day grace/suspension period before permanent disconnection & number recycling | All recharges subject to 20% Moroccan TVA (VAT) included in retail  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `MAR` (ISO-3) | `MA` (ISO-2) | `MA` (ISO-2) | `MA` (ISO-2) |
| **Carrier / Operator Code** | `1533` ("Maroc Telecom Morocco") | `311` ("Maroc Telecom Morocco") / `310` ("Maroc Telecom Morocco Data") | `MarocTelecom` | `MOMA` ("Maroc Telecom Morocco") / `0MMA` ("Maroc Telecom Bundles") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Pass *3 Data / Social | Direct Airtime Top-Up & Data Bundles | Direct Top-Up (0 Inventory in Sandbox) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 21 Fixed Products (5 to 300 MAD Airtime, Pass *3 Data, Social Media) | Fixed Amounts `311` (5 to 300 MAD / $0.63–$37.50 USD) + Data `310` (500MB to 10GB / $0.75–$13.45 USD) | 0 Active Offers in Sandbox | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 50`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (MAD) / Description | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) | DingConnect Direct (`MOMA`) |
| :---: | :---: | :---: | :---: | :---: |
| **5.00 MAD** (Min Entry Airtime) | **0.242 OMR ($0.629 USD)** (`4073`) | **$0.63 USD** (`311`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **5.00 MAD** (Pass *3: 500MB 7d) | **0.243 OMR ($0.632 USD)** (`1914`) | **$0.735 USD** (`310`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **5.00 MAD** (100MB Social 3d) | **0.242 OMR ($0.629 USD)** (`57220`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **10.00 MAD** (Standard Airtime) | **0.484 OMR ($1.258 USD)** (`4074`) | **$1.25 USD** (`311`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **10.00 MAD** (Pass *3: 1GB 7d) | **0.486 OMR ($1.264 USD)** (`1915`) | **$1.323 USD** (`310`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **10.00 MAD** (300MB Social 7d) | **0.484 OMR ($1.258 USD)** (`57221`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **20.00 MAD** (Standard Airtime) | **0.967 OMR ($2.514 USD)** (`4072`) | **$2.50 USD** (`311`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **20.00 MAD** (Pass *3: 2GB 7d) | **0.971 OMR ($2.525 USD)** (`1916`) | **$2.597 USD** (`310`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **20.00 MAD** (1GB Social 15d) | **0.967 OMR ($2.514 USD)** (`57222`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **25.00 MAD** (Pass *3: 2.5GB 14d) | **1.214 OMR ($3.156 USD)** (`49027`) | **$3.283 USD** (`310`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **30.00 MAD** (Standard Airtime) | **1.451 OMR ($3.773 USD)** (`4057`) | **$3.75 USD** (`311`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **30.00 MAD** (Pass *3: 3GB 14d) | **1.457 OMR ($3.788 USD)** (`1917`) | **$3.92 USD** (`310`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **30.00 MAD** (2GB Social 30d) | **1.451 OMR ($3.773 USD)** (`57223`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **50.00 MAD** (Standard Airtime) | **2.417 OMR ($6.284 USD)** (`4058`) | **$6.25 USD** (`311`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **50.00 MAD** (Pass *3: 5GB 30d) | **2.428 OMR ($6.313 USD)** (`1918`) | **$6.566 USD** (`310`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **50.00 MAD** (Unlimited Social 30d)| **2.417 OMR ($6.284 USD)** (`60697`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **100.00 MAD** (Standard Airtime) | **4.834 OMR ($12.568 USD)** (`4059`) | **$12.50 USD** (`311`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **100.00 MAD** (Pass *3: 10GB 30d) | **4.855 OMR ($12.623 USD)** (`1919`) | **$13.181 USD** (`310`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **150.00 MAD** (Standard Airtime) | — | **$18.75 USD** (`311`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **200.00 MAD** (Standard Airtime) | **9.668 OMR ($25.137 USD)** (`4075`) | **$25.00 USD** (`311`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **200.00 MAD** (Pass *3: 20GB 30d) | **9.710 OMR ($25.246 USD)** (`1920`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **300.00 MAD** (Max Airtime) | **14.501 OMR ($37.703 USD)** (`4076`) | **$37.50 USD** (`311`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `4073` (Maroc Telecom 5 MAD Airtime) to `+212660000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793425`, Wholesale Cost: `0.244 OMR` (~$0.634 USD), Delivered: `5 MAD base + 60 MAD promo bonus (Multiple x22 Promo)`
* **Test Request 2:** Product `1914` (Maroc Telecom Jawal Internet Pass 500MB) to `+212660000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793426`, Wholesale Cost: `0.243 OMR` (~$0.632 USD), Delivered: `500 MB Data`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request 1:** Operator `311` (Maroc Telecom Airtime, $0.63 USD fixed) to `+212660000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178462`, Delivered: `5 MAD`, Cost: `$0.63 USD`
* **Test Request 2:** Operator `310` (Maroc Telecom 500MB Data 3 Days, $0.75 USD) to `+212660000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178463`, Delivered: `6.89 MAD / 500MB`, Cost: `$0.735 USD` (2% discount)
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `MOMA` ("Maroc Telecom Morocco") / `0MMA` ("Maroc Telecom Bundles")
* **Catalog Status:** Returns `503 RateLimited / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

### 4. Zendit (Test Environment) — 🔴 Disabled Route
* **Brand:** `MarocTelecom`
* **Catalog Status:** 0 active offers returned in sandbox for country `MA`.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 50`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1533` — delivers direct nominal airtime from 5 MAD for `0.242 OMR` / ~$0.63 USD, plus full Jawal Pass *3 data and social media bundles with instant pre-prod confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 311` for Airtime and `308` for Data — reliable secondary direct rail with 10 fixed airtime tiers and 8 data bundles, `priority: 20`).
3. **Disabled Providers:** **DingConnect** (`MOMA`, `priority: 40`) and **Zendit** (`MarocTelecom`, `priority: 50`) due to 0 active inventory.
4. **ANRT Morocco Regulatory Compliance & Mini-Refill Strategy:**
   - Maroc Telecom Jawal prepaid lines have a validity period of **90 to 180 days** from the last recharge event.
   - Upon expiration of the active validity window, the line enters a **90-day grace/quarantine period** where only incoming calls/SMS are received.
   - If no recharge occurs before the grace period ends, the SIM is permanently deactivated, remaining credit is lost, and the number is recycled.
   - **KeepSIMs Automated Action:** Schedules automated mini-refills on **Day 60–80** (delivering 5 MAD for `0.242 OMR` / ~$0.63 USD via DT One) to seamlessly extend the 180-day ANRT active window.
