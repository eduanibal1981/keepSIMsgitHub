# Provider Comparison & Test Report: Congstar Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** congstar Services GmbH (`Congstar` / `congstar Prepaid` / Host: Deutsche Telekom D1 Network)  
> **Network Type:** Discount Sub-Brand / MVNO (~6M+ Customers on Telekom Network)  
> **Balance USSD / SMS:** Dial `*100#` (Instant balance on screen) | Dial `9577` (Congstar Account Manager) | App: **congstar App**  
> **Recharge USSD:** Dial `*101*<16-digit CashCode>#` / Dial `9577` / Web: `https://www.congstar.de/prepaid/services/guthaben-aufladen/`  
> **Customer Care:** Dial `0221 79 700 700` (Mon–Sat 08:00–22:00)  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up/event | 60 Days Passive Grace Period before line termination | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DT One** (`dtone`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DE` (ISO-2) | `DE` (ISO-2) | `DEU` (ISO-3) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `850` ("Congstar PIN Germany") | `Congstar` | `2139` ("Congstar Germany") | `C4DE` ("Congstar Germany") / `C7DE` / `C8DE` |
| **Delivery Mechanism** | **Digital PIN Voucher (Micro-Refill 5 EUR)** | Direct Top-Up (`CONGSTAR_DE_001-ROW` / `002`) | Direct Top-Up (0 pre-prod SKUs) | Direct Top-Up & PIN (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** | **`USD`** | **`OMR`** | **`OMR`** |
| **Catalog Format** | 1 Fixed PIN Amount (**5 EUR**) | 2 Fixed Offers (15, 30 EUR) | 0 Active Products in Pre-Prod | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Micro-Refill Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR`) | DingConnect Direct (`C4DE`) |
| :---: | :---: | :---: | :---: | :---: |
| **5.00 EUR** (Micro-PIN Voucher) | **$5.95 USD ($5.8905 net)** (`850`) | — | — | 🔴 *(0 Catalog Offers)* |
| **15.00 EUR** (Direct Top-Up) | — | **$18.52 USD** (`CONGSTAR_DE_001-ROW`) | — | 🔴 *(0 Catalog Offers)* |
| **30.00 EUR** (Direct Top-Up) | — | **$36.91 USD** (`CONGSTAR_DE_002-ROW`) | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🟢 Primary Micro-Refill Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `850` (Congstar PIN 5 EUR, $5.95 USD) to `+491510000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178487`, Delivered: `5 EUR`, Net Wholesale Cost: `$5.8905 USD`, PIN Code: `773709732299753`
* **Result:** **Primary Active Micro-Refill Provider** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment) — 🟢 Secondary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `CONGSTAR_DE_001-ROW` (Congstar 15 EUR Top-Up) to `+491510000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_de_test_1787439266383_congstar_de_001_row`, Wholesale Cost: `$18.52 USD`
* **Result:** **Secondary Direct Failover** (`priority: 20`).

### 3. DT One (Pre-Production API) — 🔴 Disabled Route
* **Operator Code:** `2139` ("Congstar Germany")
* **Status:** Returns 0 pre-prod products.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `C4DE` / `C7DE` / `C8DE`
* **Catalog Status:** Returns 0 active inventory in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Micro-Refill Route:** **Reloadly** (`operatorId: 850` — lowest micro-refill entry price in Germany at **5 EUR PIN ($5.89 USD net)**, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Zendit** (`brand: Congstar` — offers `CONGSTAR_DE_001-ROW` 15 EUR for $18.52 USD, `priority: 20`).
3. **Disabled Providers:** **DT One** (`2139`, `priority: 30`) and **DingConnect** (`C4DE`, `priority: 40`).
4. **BNetzA Germany Regulatory Compliance:**
   - Congstar prepaid SIM cards remain active for **180 days** from the date of the last top-up.
   - Delivering a **5 EUR CashCode PIN** via Reloadly resets the 180-day active validity timer at minimal cost.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** to maintain active SIM lifecycle automatically.
