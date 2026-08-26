# Provider Comparison & Test Report: O2 Telefónica Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** Telefónica Germany GmbH & Co. OHG (`O2 Germany` / `Telefónica Deutschland` / `O2 Loop` / `O2 Prepaid`)  
> **Network Type:** MNO (National #3 Network Operator / ~45M+ Mobile Connections)  
> **Balance USSD / SMS:** Dial `*101#` (Instant balance pop-up on screen) | Dial `5667` (O2 Voice IVR Portal) | App: **Mein O2**  
> **Recharge USSD:** Dial `*103*<16-digit Aufladenummer>#` / Dial `5667` (Option 1: Guthaben aufladen) / Web: `https://www.o2.de/mein-prepaid/aufladen`  
> **Customer Care:** Dial `0176 888 55 282` / `+49 176 88855282` (From O2 Mobile)  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up | 60 Days Passive Grace Period (*Passivphase* / incoming calls only) before SIM deactivation and number release | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DEU` (ISO-3) | `DE` (ISO-2) | `DE` (ISO-2) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `451` ("O2 Germany") | `868` ("O2 PIN Germany") | `O2` | `O2DE` ("O2 Germany") / `O1DE` ("O2 Pins") |
| **Delivery Mechanism** | **Direct Airtime Top-Up & Digital PIN Vouchers** | Digital PIN Vouchers | Direct Top-Up (`O2_DE_001-ROW` / `002` / `003`) | Direct Top-Up & PIN (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 7 SKUs: Direct (15, 20, 30, 50 EUR) + PIN (15, 20, 30 EUR) | 3 Fixed PIN Amounts (15, 20, 30 EUR) | 3 Fixed Offers (15, 20, 30 EUR) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct & PIN Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary PIN Failover** (`priority: 20`) | 🟢 **Tertiary Direct Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`O2DE`) |
| :---: | :---: | :---: | :---: | :---: |
| **15.00 EUR** (Direct Top-Up) | **8.149 OMR ($21.19 USD)** (`15301`) | — | **$18.75 USD** (`O2_DE_001-ROW`) | 🔴 *(0 Catalog Offers)* |
| **15.00 EUR** (PIN Voucher) | **8.047 OMR ($20.92 USD)** (`23408`) | **$17.86 USD** (`868`) | — | 🔴 *(0 Catalog Offers)* |
| **20.00 EUR** (Direct Top-Up) | **10.743 OMR ($27.93 USD)** (`15302`) | — | **$24.93 USD** (`O2_DE_002-ROW`) | 🔴 *(0 Catalog Offers)* |
| **20.00 EUR** (PIN Voucher) | **10.637 OMR ($27.66 USD)** (`23409`) | **$23.81 USD** (`868`) | — | 🔴 *(0 Catalog Offers)* |
| **30.00 EUR** (Direct Top-Up) | **16.106 OMR ($41.88 USD)** (`15303`) | — | **$37.36 USD** (`O2_DE_003-ROW`) | 🔴 *(0 Catalog Offers)* |
| **30.00 EUR** (PIN Voucher) | **15.956 OMR ($41.49 USD)** (`23410`) | **$35.71 USD** (`868`) | — | 🔴 *(0 Catalog Offers)* |
| **50.00 EUR** (Direct Top-Up) | **26.787 OMR ($69.65 USD)** (`17647`) | — | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct & PIN Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `15301` (O2 15 EUR Direct Top-Up) to `+491760000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793464`, Delivered: `15 EUR`, Wholesale Cost: `8.149 OMR`
* **Test Request 2:** Product `23408` (O2 15 EUR PIN Voucher) to `+491760000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793466`, Delivered: `15 EUR`, Wholesale Cost: `8.047 OMR`, PIN Instructions: `*103*<voucher_code># and dial`
* **Result:** **Primary Active Provider** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary PIN Failover
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `868` (O2 PIN 15 EUR, $17.86 USD) to `+491760000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178485`, Delivered: `15 EUR`, Net Wholesale Cost: `$17.86 USD`, PIN Code: `773709732932053`
* **Result:** **Secondary PIN Failover** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `O2_DE_001-ROW` (O2 15 EUR Top-Up) to `+491760000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_de_test_1787439264626_o2_de_001_row`, Wholesale Cost: `$18.75 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `O2DE` ("O2 Germany") / `O1DE` ("O2 Pins Germany")
* **Catalog Status:** Returns 0 active inventory in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **DT One** (`operatorId: 451` — complete direct top-up and PIN voucher rails starting at 15 EUR for 8.149 / 8.047 OMR, `priority: 10`, `is_primary: true`).
2. **Secondary PIN Failover:** **Reloadly** (`operatorId: 868` — 15 EUR PIN voucher for $17.86 USD, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: O2` — offers `O2_DE_001-ROW` 15 EUR for $18.75 USD, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`O2DE`, `priority: 40`, `is_enabled: false`).
5. **BNetzA Germany Regulatory Compliance:**
   - O2 Germany prepaid SIM cards remain active for **180 days** from the date of the last top-up.
   - If unrefilled for 180 days, the line enters a **60-day passive period** (*Passivphase*) where outgoing calls are blocked, before contract termination and number forfeiture.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** (delivering 15 EUR O2 top-up or voucher via DT One / Reloadly) to reset the 180-day BNetzA active validity timer.
