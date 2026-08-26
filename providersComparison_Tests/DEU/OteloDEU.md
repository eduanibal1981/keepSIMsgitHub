# Provider Comparison & Test Report: Otelo Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** Vodafone GmbH (`Otelo` / `otelo Prepaid` / Host: Vodafone D2 Network)  
> **Network Type:** Discount Subsidiary / MVNO (~2.8M+ Customers)  
> **Balance USSD / SMS:** Dial `*100#` (Screen pop-up) | Dial `12430` (Voice IVR Portal) | App: **Mein Otelo**  
> **Recharge USSD:** Dial `*100*<16-digit Code>#` / Dial `12430` / Web: `https://www.otelo.de/prepaid/aufladen`  
> **Customer Care:** Dial `0172 124 300` / `+49 172 124300`  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up | 60 Days Passive Grace Period before line termination | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DT One** (`dtone`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DE` (ISO-2) | `DE` (ISO-2) | `DEU` (ISO-3) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `867` ("Otelo PIN Germany") | `OTELO` | `2148` ("Otelo Germany") | `OEDE` ("Otelo Germany") / `O4DE` |
| **Delivery Mechanism** | **Digital PIN Vouchers (9, 19, 29 EUR)** | Direct Top-Up (`OTELO_DE_001-ROW` / `002`) | PIN / Direct (0 pre-prod SKUs) | Direct Top-Up & PIN (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** | **`USD`** | **`OMR`** | **`OMR`** |
| **Catalog Format** | 3 Fixed PIN Amounts (9, 19, 29 EUR) | 2 Fixed Offers (9, 19 EUR) | 0 Active Products in Pre-Prod | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR`) | DingConnect Direct (`OEDE`) |
| :---: | :---: | :---: | :---: | :---: |
| **9.00 EUR** (Micro-PIN / Direct) | **$9.00 USD** (`867`) | **$11.25 USD** (`OTELO_DE_001-ROW`) | — | 🔴 *(0 Catalog Offers)* |
| **19.00 EUR** (PIN / Direct Top-Up) | **$19.00 USD** (`867`) | **$23.73 USD** (`OTELO_DE_002-ROW`) | — | 🔴 *(0 Catalog Offers)* |
| **29.00 EUR** (PIN Voucher) | **$29.00 USD** (`867`) | — | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🟢 Primary Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `867` (Otelo PIN 9 EUR, $9.00 USD) to `+491520000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178495`, Delivered: `9 EUR`, Net Wholesale Cost: `$9.00 USD`, PIN Code: `773709732483103`
* **Result:** **Primary Active Provider** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment) — 🟢 Secondary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `OTELO_DE_001-ROW` (Otelo 9 EUR Top-Up) to `+491520000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_de_test_1787439273409_otelo_de_001_row`, Wholesale Cost: `$11.25 USD`
* **Result:** **Secondary Direct Failover** (`priority: 20`).

### 3. DT One (Pre-Production API) — 🔴 Disabled Route
* **Operator Code:** `2148` ("Otelo Germany")
* **Status:** Returns 0 pre-prod products.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `OEDE` ("Otelo Germany") / `O4DE`
* **Catalog Status:** Returns 0 active inventory in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **Reloadly** (`operatorId: 867` — 9 EUR PIN voucher for **$9.00 USD**, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Zendit** (`brand: OTELO` — offers `OTELO_DE_001-ROW` 9 EUR for $11.25 USD, `priority: 20`).
3. **Disabled Providers:** **DT One** (`2148`, `priority: 30`) and **DingConnect** (`OEDE`, `priority: 40`).
4. **BNetzA Germany Regulatory Compliance:**
   - Otelo prepaid SIM cards remain active for **180 days** from the date of the last top-up.
   - Recharging with a **9 EUR PIN** via Reloadly or 9 EUR direct top-up via Zendit resets the 180-day active validity window.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** to maintain active SIM lifecycle automatically.
