# Provider Comparison & Test Report: Orange Morocco

> **Country:** Morocco (`MA` / `+212` / `MAR`)  
> **Carrier:** Orange Morocco (formerly Méditel / Orange Group)  
> **Network Type:** MNO (~33% Market Share / ~13M+ Mobile Subscribers / Prepaid Brand: **Orange Recharge**)  
> **Balance USSD:** Dial `#554#` (Balance & Line Expiration Date)  
> **Recharge USSD:** Dial `*120#` (Self-care Menu) or `*120*<PIN>#`:
>   * Direct Airtime: `*120*<PIN>#`
>   * Pass *3 (Internet 4G/5G): `*120*<PIN>*3#`
>   * Pass *1 (Calls): `*120*<PIN>*1#`
>   * Pass *6 (Social Media / WhatsApp, FB, IG): `*120*<PIN>*6#`
>   * Pass *2 (SMS): `*120*<PIN>*2#`  
> **Customer Care:** `121` (From Orange) / `+212 663 121 121` | **Self-Care App:** Orange et moi Maroc / Max It  
> **Regulatory Policy (ANRT Morocco):** 90 to 180-day active validity from last recharge + 90-day grace/suspension period before permanent disconnection & number recycling | All recharges subject to 20% Moroccan TVA (VAT) included in retail  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `MAR` (ISO-3) | `MA` (ISO-2) | `MA` (ISO-2) | `MA` (ISO-2) |
| **Carrier / Operator Code** | `387` ("Orange Morocco") | `313` ("Orange Morocco") / `690` ("Orange Bundles") / `309` ("Orange Data") | `Orange` | `ORMA` ("Orange Morocco") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Social Media Passes | Direct Airtime (Range), Calls & Data Bundles | Direct Top-Up (0 Inventory in Sandbox) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 27 Fixed Products (6 to 330 MAD) + Open Range `54511` (33 to 330 MAD) | Range `313` (36.86–330 MAD / $4.38–$39.22 USD) + Bundles `690` + Data `309` | 0 Active Offers in Sandbox | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 50`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (MAD) / Description | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) | DingConnect Direct (`ORMA`) |
| :---: | :---: | :---: | :---: | :---: |
| **5.00 MAD** (100MB Social 1d) | **0.245 OMR ($0.637 USD)** (`57216`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **6.00 MAD** (Min Entry Airtime) | **0.302 OMR ($0.785 USD)** (`50285`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **7.00 MAD** (Fixed Airtime) | **0.352 OMR ($0.915 USD)** (`50286`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **8.00 MAD** (Fixed Airtime) | **0.402 OMR ($1.045 USD)** (`50287`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **9.00 MAD** (Fixed Airtime) | **0.453 OMR ($1.178 USD)** (`50288`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **10.00 MAD** (Standard Airtime) | **0.503 OMR ($1.308 USD)** (`50289`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **10.00 MAD** (300MB Social 7d) | **0.489 OMR ($1.271 USD)** (`57217`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **15.00 MAD** (Fixed Airtime) | **0.754 OMR ($1.960 USD)** (`50294`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **20.00 MAD** (1GB Social 15d) | **0.977 OMR ($2.540 USD)** (`57218`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **20.00 MAD** (Pass *3: 2GB 7d) | — | **$2.261 USD** (`309`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **20.00 MAD** (Pass *1: 90m+500MB 7d)| — | **$2.261 USD** (`690`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **30.00 MAD** (2GB Social 30d) | **1.465 OMR ($3.809 USD)** (`57219`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **30.00 MAD** (Pass *3: 3GB 14d) | — | **$3.391 USD** (`309`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **30.00 MAD** (Pass *1: 150m+500MB 7d)| — | **$3.391 USD** (`690`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **36.86–330 MAD** (Ranged Airtime) | **2.214 to 16.235 OMR** (`54511`) | **$4.16 to $37.26 USD** (`313`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **50.00 MAD** (Social Media Pass) | **2.441 OMR ($6.347 USD)** (`66790`) | — | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **50.00 MAD** (Pass *3: 5GB 30d) | — | **$5.643 USD** (`309`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **100.00 MAD** (Pass *3: 10GB 30d) | — | **$11.286 USD** (`309`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **100.00 MAD** (Pass *1: 180m+6GB 30d)| — | **$11.305 USD** (`690`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **200.00 MAD** (Fixed Airtime) | **9.840 OMR ($25.584 USD)** (`30748`+`...`) | **$22.58 USD** (`313`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |
| **330.00 MAD** (Max Airtime) | **16.235 OMR ($42.211 USD)** (`32191`) | **$37.26 USD** (`313`) | 🔴 *(0 Offers)* | 🔴 *(0 Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `50285` (Orange Morocco 6 MAD Airtime) to `+212661000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793444`, Wholesale Cost: `0.304 OMR` (~$0.79 USD), Delivered: `6 MAD Airtime`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request 1:** Operator `313` (Orange Morocco Ranged Airtime, $5.00 USD requested) to `+212661000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178464`, Delivered: `42.08 MAD`, Cost: `$4.75 USD` (5% discount)
* **Test Request 2:** Operator `690` (Orange Morocco Bundles 90m + 500MB 7d, $2.38 USD) to `+212661000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178465`, Delivered: `20 MAD`, Cost: `$2.261 USD` (5% discount)
* **Test Request 3:** Operator `309` (Orange Morocco Data 2GB 7d, $2.38 USD) to `+212661000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178466`, Delivered: `20 MAD`, Cost: `$2.261 USD` (5% discount)
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `ORMA` ("Orange Morocco")
* **Catalog Status:** Returns `503 RateLimited / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

### 4. Zendit (Test Environment) — 🔴 Disabled Route
* **Brand:** `Orange`
* **Catalog Status:** 0 active offers returned in sandbox for country `MA`.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 50`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 387` — delivers micro-airtime starting at 6 MAD for `0.302 OMR` / ~$0.79 USD, plus 27 granular fixed denominations up to 330 MAD with instant pre-prod confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 313` for flexible ranged airtime 36.86–330 MAD, plus `690` for Calls & Data bundles and `309` for Standalone 4G/5G Data passes, `priority: 20`).
3. **Disabled Providers:** **DingConnect** (`ORMA`, `priority: 40`) and **Zendit** (`Orange`, `priority: 50`) due to 0 active inventory.
4. **ANRT Morocco Regulatory Compliance & Mini-Refill Strategy:**
   - Orange Morocco prepaid lines require a qualifying recharge or billable activity within **90 to 180 days** to prevent suspension.
   - Upon expiration, a **90-day grace/suspension period** begins (incoming calls/SMS preserved).
   - After the grace period expires with zero recharge, the line is permanently disconnected and recycled.
   - **KeepSIMs Automated Action:** Schedules automated mini-refills on **Day 60–80** (delivering 6 MAD for `0.302 OMR` / ~$0.79 USD via DT One) to permanently reset the 180-day ANRT active validity window.
