# Provider Comparison & Test Report: Tunisie Telecom (TT)

> **Country:** Tunisia (`TN` / `+216` / `TUN`)  
> **Carrier:** Tunisie Telecom (Société Nationale des Télécommunications — Incumbent National Operator, ~31% Mobile Market Share)  
> **Network Type:** MNO (~4.8M+ Mobile Subscribers / State-owned & Tecom Investments)  
> **Balance USSD:** Dial `*122#` (Main Airtime Balance & Expiration), `*122*2#` (Internet & Forfait Balance), `*122*3#` (Bonus Minutes/Data)  
> **Recharge USSD:** Dial `*123*<PIN>#`  
> **Forfait / Bundle Menu:** Dial `*140#` or `*140*0#` (Forfait Net & Pass 4G/5G)  
> **Customer Care:** `1298` (From Mobile) / `1198` (Fixed Line) / `+216 71 00 12 98` | **Self-Care App:** My TT (Tunisie Telecom)  
> **Regulatory Policy (INTT Tunisia):** 90 to 180-day active validity from last recharge + 90-day grace/quarantine period before permanent disconnection & number recycling | Recharges subject to 19% Tunisian TVA (VAT) + telecom royalty tax  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `TUN` (ISO-3) | `TN` (ISO-2) | `TN` (ISO-2) | `TN` (ISO-2) |
| **Carrier / Operator Code** | `678` ("Tunisie Telecom Tunisia") | `507` ("Tunisie Telecom Tunisia") | `TunisieTelecom` | `TWTN` ("Tunisie Telecom Tunisia") |
| **Delivery Mechanism** | Direct Airtime Top-Up (Fixed) | Direct Airtime Top-Up (Fixed) | Direct Airtime Top-Up (Fixed) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 3 Fixed SKUs (5.40, 10.80, 21.60 TND) | 3 Fixed SKUs (5.40, 10.80, 21.60 TND / $2.40–$9.60 USD) | 3 Fixed Offers (5.40, 10.80, 21.60 TND) | 0 Active Products in UAT (503 RateLimited) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Direct Route** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (TND) / Description | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`TWTN`) |
| :---: | :---: | :---: | :---: | :---: |
| **5.40 TND** (Min Entry Airtime) | **0.852 OMR ($2.215 USD)** (`8572`) | **$2.352 USD** (`507`, 2% discount) | **$2.09 USD** (`TUNISIETELECOM_TN_001`) | 🔴 *(0 Offers)* |
| **10.80 TND** (Standard Airtime) | **1.703 OMR ($4.428 USD)** (`8573`) | **$4.704 USD** (`507`, 2% discount) | **$4.16 USD** (`TUNISIETELECOM_TN_002`) | 🔴 *(0 Offers)* |
| **21.60 TND** (Standard Airtime) | **3.405 OMR ($8.853 USD)** (`8574`) | **$9.408 USD** (`507`, 2% discount) | **$8.33 USD** (`TUNISIETELECOM_TN_003`) | 🔴 *(0 Offers)* |

> **Note on Denominations:** The standard national face values (5.40, 10.80, 21.60 TND) reflect the statutory telecom tax increment embedded in Tunisie Telecom's recharge cards (e.g. 5 TND face value + 400 millimes fiscal stamp/royalty = 5.40 TND delivered).

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `8572` (Tunisie Telecom 5.4 TND Airtime) to `+21690000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793456`, Wholesale Cost: `0.852 OMR` (~$2.215 USD), Delivered: `5.40 TND`
* **Test Request 2:** Product `8573` (Tunisie Telecom 10.8 TND Airtime) to `+21690000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793457`, Wholesale Cost: `1.703 OMR` (~$4.428 USD), Delivered: `10.80 TND`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `507` (Tunisie Telecom 5.4 TND, $2.40 USD fixed) to `+21690000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178478`, Requested: `$2.40 USD`, Delivered: `5.40 TND`, Wholesale Cost: `$2.352 USD` (2% discount)
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Route
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `TUNISIETELECOM_TN_001` (Tunisie Telecom 5.4 TND Topup) to `+21690000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
  * **Delivered Artifact:** Transaction ID `zen_tun_1787439188274_TUNISIETELECOM_TN_001`
* **Result:** **Tertiary Direct Route** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `TWTN` ("Tunisie Telecom Tunisia")
* **Catalog Status:** Returns `503 RateLimited / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 678` — provides direct delivery of standard Tunisie Telecom denominations: 5.40 TND for **0.852 OMR** / ~$2.215 USD, 10.80 TND for **1.703 OMR**, and 21.60 TND for **3.405 OMR** with instant pre-prod confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 507` — fixed SKUs 5.4, 10.8, 21.6 TND from $2.352 USD cost with 2% discount, `priority: 20`).
3. **Tertiary Direct Route:** **Zendit** (`brand: TunisieTelecom` — 3 fixed offers from 5.40 TND @ $2.09 USD wholesale cost, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`TWTN`, `priority: 40`) due to 0 active UAT catalog inventory.
5. **INTT Tunisia Regulatory Compliance & Mini-Refill Strategy:**
   - Tunisie Telecom prepaid mobile lines require a qualifying recharge at least once every **90 to 180 days** to keep the line active.
   - If the active window lapses, the line enters a **90-day grace/quarantine window** (incoming calls and incoming SMS only).
   - Failure to recharge before the end of the grace period leads to SIM deactivation, loss of accumulated credit, and release of the number back to the INTT pool.
   - **KeepSIMs Automated Action:** Schedules automated mini-refills on **Day 60–80** (delivering 5.40 TND for `0.852 OMR` / ~$2.215 USD via DT One) to maintain continuous line validity.
