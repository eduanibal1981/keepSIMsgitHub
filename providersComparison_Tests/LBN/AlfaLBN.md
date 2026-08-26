# Provider Comparison & Test Report: Alfa Lebanon (MIC1 / Orascom TMT)

> **Country:** Lebanon (`LB` / `+961` / `LBN`)  
> **Carrier:** Mobile Interim Company 1 S.A.L. (`Alfa Lebanon` / Managed by Orascom Telecom Media & Technology)  
> **Network Type:** MNO (Major National Operator / ~47% Market Share / Alfa Prepaid & Postpaid)  
> **Balance USSD / SMS:** Dial `*111#` or `*140#` (Main Balance & Active Validity) | SMS to `1050` | Alfa Self-Care Portal / Mobile App  
> **Recharge USSD:** Dial `*141*<14-digit PIN>#` or via Alfa App  
> **Customer Care:** `111` (from mobile within Lebanon) / `+9613391111` / `+9613030000`  
> **Regulatory Policy (MoT Lebanon):** Denominations are regulated by the Lebanese Ministry of Telecommunications (MoT) Sayrafa USD pricing. Recharge validity scales by denomination: $1.22 (micro-refill), $3.03 (13 days), $4.50 (35 days), $7.58 (35 days), $15.15 (65 days), $22.73 (95 days), and $77.28 (365 days / 1 full year). Upon validity expiry, lines enter a **12-day retention phase** (receive-only) followed by a **60-day grace period** before line deactivation and recycling.  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Zendit** (`zendit`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `LBN` (ISO-3) | `LB` (ISO-2) | `LB` (ISO-2) | `LB` (ISO-2) |
| **Carrier / Operator Code** | `2793` ("Alfa Lebanon USD") | `Alfa` | `1017` ("Alfa Lebanon PIN") | `AALB` ("Alfa Lebanon") |
| **Delivery Mechanism** | **Direct Airtime Top-Up** (Real-Time MSISDN Credit) | **Direct Airtime Top-Up** (Real-Time API Credit) | **Digital PIN Voucher** (Voucher Token) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** (Direct USD Billing) | **`USD`** | **`OMR`** |
| **Catalog Format** | 7 Fixed Tiers: $1.22, $3.03, $4.50, $7.58, $15.15, $22.73, $77.28 | 7 Fixed Offers: `ALFA_LB_001` to `008` | Fixed PIN: $25.40 USD | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary PIN Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (USD) | Active Validity | DT One Wholesale (`OMR` / `USD`) / ID | Zendit Wholesale (`USD`) / Offer ID | Reloadly Wholesale (`USD`) / Op ID `1017` | DingConnect Direct (`AALB`) | Delivery Type |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **$1.22 USD** | Balance Refill | **0.751 OMR ($1.95 USD)** (`44471`) | **$2.50 USD** (`ALFA_LB_001`) | — | 🔴 *(0 UAT Offers)* | **Direct Top-Up** |
| **$3.03 USD** | 13 Days | **1.709 OMR ($4.44 USD)** (`44472`) | **$6.25 USD** (`ALFA_LB_002`) | — | 🔴 *(0 UAT Offers)* | **Direct Top-Up** |
| **$4.50 USD** | 35 Days | **2.487 OMR ($6.47 USD)** (`44473`) | **$9.50 USD** (`ALFA_LB_003`) | — | 🔴 *(0 UAT Offers)* | **Direct Top-Up** |
| **$7.58 USD** | 35 Days | **4.114 OMR ($10.70 USD)** (`44475`) | **$15.75 USD** (`ALFA_LB_005`) | — | 🔴 *(0 UAT Offers)* | **Direct Top-Up** |
| **$15.15 USD** | 65 Days | **8.122 OMR ($21.12 USD)** (`44476`) | **$31.50 USD** (`ALFA_LB_006`) | — | 🔴 *(0 UAT Offers)* | **Direct Top-Up** |
| **$22.73 USD** | 95 Days | **12.130 OMR ($31.54 USD)** (`44477`) | **$47.25 USD** (`ALFA_LB_007`) | — | 🔴 *(0 UAT Offers)* | **Direct Top-Up** |
| **$25.40 USD** | 60 Days | — | — | **$25.40 USD** (Op `1017`) | 🔴 *(0 UAT Offers)* | Digital PIN Voucher |
| **$77.28 USD** | 365 Days (1 Year) | **40.970 OMR ($106.52 USD)** (`44478`) | **$161.00 USD** (`ALFA_LB_008`) | — | 🔴 *(0 UAT Offers)* | **Direct Top-Up** |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `44471` (Alfa Lebanon USD - 1.22 USD Micro-Refill) to `+96171000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793408`, Wholesale Cost: `0.751 OMR` (~$1.95 USD), Credit Party: `+96171000101`
* **Test Request 2:** Product `44473` (Alfa Lebanon USD - 4.50 USD / 35 Days) to `+96171000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793409`, Wholesale Cost: `2.487 OMR` (~$6.47 USD), Validity: `35 Days`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Production Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups/purchases`
* **Test Request 1:** Offer `ALFA_LB_001` (Alfa 1.22 USD send) to `+96171000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
  * **Delivered Artifact:** Transaction ID `zen_lb_test_1787438138317_alfa_lb_001`, Status: `ACCEPTED`
* **Test Request 2:** Offer `ALFA_LB_003` (Alfa 4.50 USD send) to `+96171000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
  * **Delivered Artifact:** Transaction ID `zen_lb_test_1787438140572_alfa_lb_003`, Status: `ACCEPTED`
* **Result:** **Secondary Active Direct Route** (`priority: 20`, `is_enabled: true`).

### 3. Reloadly (Sandbox API) — 🟢 Tertiary PIN Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `1017` (Alfa Lebanon PIN $25.40 USD) to `+96171000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178446`, PIN Code: `773709732477925`, Serial: `716107`, Validity: `60 days`, Instructions: `Dial *233*PIN#` / `*141*PIN#`
* **Result:** **Tertiary PIN Failover** (`priority: 30`, `is_enabled: true`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `AALB` ("Alfa Lebanon")
* **Validation Regex:** `^961[0-9]{7,8}$|^0000000000$`
* **Catalog Status:** Returns 0 products in UAT (`503 RateLimited / 0 items`).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Top-Up Route:** **DT One** (`operatorId: 2793` — delivers direct airtime credits starting at $1.22 USD micro-refill (0.751 OMR / ~$1.95 USD) and $4.50 USD (35D at 2.487 OMR / ~$6.47 USD), `priority: 10`, `is_primary: true`).
2. **Secondary Direct Top-Up Failover:** **Zendit** (`brand: Alfa` — provides full range of 7 direct offers `ALFA_LB_001` to `008` starting at $1.22 USD send, `priority: 20`, `is_enabled: true`).
3. **Tertiary PIN Voucher Backup:** **Reloadly** (`operatorId: 1017` — delivers $25.40 USD emergency recharge PIN vouchers with automatic payload extraction, `priority: 30`, `is_enabled: true`).
4. **Disabled Provider:** **DingConnect** (`providerCode: AALB`, `priority: 40`, `is_enabled: false`).
5. **MoT Lebanon Regulatory Compliance Strategy:**
   - Alfa prepaid lines require regular top-ups to maintain valid active status (35 days per $4.50 USD recharge).
   - Upon validity expiration, the line enters a **12-day retention period** (receive-only), followed by **60 days of suspension**.
   - If not refilled within 72 inactive days, the SIM is disconnected and the number is recycled into the national pool by MoT.
   - KeepSIMs schedules automated mini-refills every **25–30 days** using the $1.22–$4.50 USD tier to maintain line life continuously at minimum cost.
