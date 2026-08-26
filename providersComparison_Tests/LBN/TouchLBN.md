# Provider Comparison & Test Report: Touch Lebanon (MIC2 / Zain Group)

> **Country:** Lebanon (`LB` / `+961` / `LBN`)  
> **Carrier:** Mobile Interim Company 2 S.A.L. (`Touch Lebanon` / Managed by Zain Group)  
> **Network Type:** MNO (National Market Leader / ~53% Market Share / Magic Prepaid & Postpaid)  
> **Balance USSD / SMS:** Dial `*220#` or `*111#` (Main Balance & Active Validity) | SMS to `1144` | touch Lebanon Mobile App  
> **Recharge USSD:** Dial `*200*<14-digit PIN>#` or `*220*<PIN>#` or touch Self-Care Portal  
> **Customer Care:** `111` (from mobile within Lebanon) / `+9613792111` / `1788` (Support)  
> **Regulatory Policy (MoT Lebanon):** Denominations are governed by the Lebanese Ministry of Telecommunications (MoT) Sayrafa USD pricing. Recharge validity ranges from 15 to 370 days ($3.79 for 15D, $4.50 for 35D, $7.58 for 35D, $15.15 for 65D, $22.73 for 95D, $77.28 for 370D). When active validity expires, lines enter a **12-day retention period** (receive-only) followed by a **60-day suspension grace period** before permanent line disconnection and number pool recycling.  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Zendit** (`zendit`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `LBN` (ISO-3) | `LB` (ISO-2) | `LB` (ISO-2) | `LB` (ISO-2) |
| **Carrier / Operator Code** | `2794` ("Touch Lebanon USD") | `Touch` | `276` ("Touch Lebanon PIN") | `TMLB` ("Touch Mobile Lebanon") |
| **Delivery Mechanism** | **Direct Airtime Top-Up** (Real-Time MSISDN Credit) | **Direct Airtime Top-Up** (Real-Time API Credit) | **Digital PIN Voucher** (Voucher Token) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** (Direct USD Billing) | **`USD`** | **`OMR`** |
| **Catalog Format** | 6 Fixed Tiers: $3.79, $4.50, $7.58, $15.15, $22.73, $77.28 | 6 Fixed Offers: `TOUCH_LB_001_USD` to `006_USD` | Fixed PIN: $25.40 USD | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary PIN Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (USD) | Active Validity | DT One Wholesale (`OMR` / `USD`) / ID | Zendit Wholesale (`USD`) / Offer ID | Reloadly Wholesale (`USD`) / Op ID `276` | DingConnect Direct (`TMLB`) | Delivery Type |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **$3.79 USD** | 15 Days | **2.116 OMR ($5.50 USD)** (`44310`) | **$6.00 USD** (`TOUCH_LB_001_USD`) | — | 🔴 *(0 UAT Offers)* | **Direct Top-Up** |
| **$4.50 USD** | 35 Days | **2.487 OMR ($6.47 USD)** (`44311`) | **$7.00 USD** (`TOUCH_LB_002_USD`) | — | 🔴 *(0 UAT Offers)* | **Direct Top-Up** |
| **$7.58 USD** | 35 Days | **4.114 OMR ($10.70 USD)** (`44313`) | **$12.00 USD** (`TOUCH_LB_003_USD`) | — | 🔴 *(0 UAT Offers)* | **Direct Top-Up** |
| **$15.15 USD** | 65 Days | **8.122 OMR ($21.12 USD)** (`44315`) | **$24.00 USD** (`TOUCH_LB_004_USD`) | — | 🔴 *(0 UAT Offers)* | **Direct Top-Up** |
| **$22.73 USD** | 95 Days | **12.130 OMR ($31.54 USD)** (`44316`) | **$35.00 USD** (`TOUCH_LB_005_USD`) | — | 🔴 *(0 UAT Offers)* | **Direct Top-Up** |
| **$25.40 USD** | 60 Days | — | — | **$25.40 USD** (Op `276`) | 🔴 *(0 UAT Offers)* | Digital PIN Voucher |
| **$77.28 USD** | 370 Days (1 Year) | **40.970 OMR ($106.52 USD)** (`44317`) | **$118.00 USD** (`TOUCH_LB_006_USD`) | — | 🔴 *(0 UAT Offers)* | **Direct Top-Up** |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `44310` (Touch Lebanon USD - 3.79 USD / 15 Days) to `+96170000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793406`, Wholesale Cost: `2.116 OMR` (~$5.50 USD), Credit Party: `+96170000101`
* **Test Request 2:** Product `44311` (Touch Lebanon USD - 4.50 USD / 35 Days) to `+96170000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793407`, Wholesale Cost: `2.487 OMR` (~$6.47 USD), Validity: `35 Days`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Production Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups/purchases`
* **Test Request 1:** Offer `TOUCH_LB_001_USD` (Touch 3.79 USD send) to `+96170000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
  * **Delivered Artifact:** Transaction ID `zen_lb_test_1787438133438_touch_lb_001_usd`, Status: `ACCEPTED`
* **Test Request 2:** Offer `TOUCH_LB_002_USD` (Touch 4.50 USD send) to `+96170000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
  * **Delivered Artifact:** Transaction ID `zen_lb_test_1787438136064_touch_lb_002_usd`, Status: `ACCEPTED`
* **Result:** **Secondary Active Direct Route** (`priority: 20`, `is_enabled: true`).

### 3. Reloadly (Sandbox API) — 🟢 Tertiary PIN Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `276` (Touch Lebanon PIN $25.40 USD) to `+96170000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178445`, PIN Code: `773709732762894`, Serial: `765879`, Validity: `60 days`, Instructions: `Dial *233*PIN#` / `*200*PIN#`
* **Result:** **Tertiary PIN Failover** (`priority: 30`, `is_enabled: true`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `TMLB` ("Touch Mobile Lebanon")
* **Validation Regex:** `^961[0-9]{7,8}$|^0000000000$`
* **Catalog Status:** Returns 0 products in UAT (`503 RateLimited / 0 items`).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Top-Up Route:** **DT One** (`operatorId: 2794` — delivers instant direct airtime credits starting at $3.79 USD (15D) and $4.50 USD (35D) at lowest wholesale entry of 2.116–2.487 OMR, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Top-Up Failover:** **Zendit** (`brand: Touch` — provides seamless multi-tier API top-ups `TOUCH_LB_001_USD` to `006_USD`, `priority: 20`, `is_enabled: true`).
3. **Tertiary PIN Voucher Backup:** **Reloadly** (`operatorId: 276` — delivers $25.40 USD emergency recharge PIN vouchers with automatic payload extraction, `priority: 30`, `is_enabled: true`).
4. **Disabled Provider:** **DingConnect** (`providerCode: TMLB`, `priority: 40`, `is_enabled: false`).
5. **MoT Lebanon Regulatory Compliance Strategy:**
   - Touch Magic prepaid accounts require refills every 35 days (for $4.50 USD denomination) to maintain active status.
   - Upon validity expiry, lines enter a **12-day retention period** (receive-only), followed by **60 days of suspension**.
   - If not refilled within 72 total inactive days, the SIM is disconnected and the number is recycled by MoT.
   - KeepSIMs schedules automated refills every **25–30 days** using the $4.50 USD tier (2.487 OMR / ~$6.47 USD via DT One) to guarantee unbroken line connectivity.
