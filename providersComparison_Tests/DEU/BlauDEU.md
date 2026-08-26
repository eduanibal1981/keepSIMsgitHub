# Provider Comparison & Test Report: Blau Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** Telefónica Germany GmbH & Co. OHG (`Blau` / `Blau Mobilfunk` / `Blau World` / Host: Telefónica Network)  
> **Network Type:** Discount Sub-Brand / MVNO (~3M+ Customers)  
> **Balance USSD / SMS:** Dial `*101#` (Instant balance pop-up) | Dial `1155` (Voice IVR balance) | App: **Mein Blau**  
> **Recharge USSD:** Dial `*103*<16-digit Aufladecode>#` / Dial `1155` / Web: `https://www.blau.de/service/guthaben-aufladen/`  
> **Customer Care:** Dial `0177 177 1160` (Mon–Fri 07:00–20:00, Sat 10:00–18:00)  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up | 60 Days Passive Grace Period before line termination | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DT One** (`dtone`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DE` (ISO-2) | `DE` (ISO-2) | `DEU` (ISO-3) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `849` ("Blau PIN Germany") | `Blau` | `2754` ("Blau Germany") | `BSDE` ("Blau Germany") / `B7DE` |
| **Delivery Mechanism** | **Digital PIN Vouchers (15, 25, 30 EUR)** | Direct Top-Up (`BLAU_DE_001-ROW` / `002`) | PIN / Direct (0 pre-prod SKUs) | Direct Top-Up & PIN (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** | **`USD`** | **`OMR`** | **`OMR`** |
| **Catalog Format** | 3 Fixed PIN Amounts (15, 25, 30 EUR) | 2 Fixed Offers (15, 20 EUR) | 0 Active Products in Pre-Prod | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR`) | DingConnect Direct (`BSDE`) |
| :---: | :---: | :---: | :---: | :---: |
| **15.00 EUR** (PIN / Direct Top-Up) | **$17.86 USD ($17.5028 net)** (`849`) | **$18.99 USD** (`BLAU_DE_001-ROW`) | — | 🔴 *(0 Catalog Offers)* |
| **20.00 EUR** (Direct Top-Up) | — | **$25.33 USD** (`BLAU_DE_002-ROW`) | — | 🔴 *(0 Catalog Offers)* |
| **25.00 EUR** (PIN Voucher) | **$29.76 USD ($29.1648 net)** (`849`) | — | — | 🔴 *(0 Catalog Offers)* |
| **30.00 EUR** (PIN Voucher) | **$35.71 USD ($34.9958 net)** (`849`) | — | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🟢 Primary Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `849` (Blau PIN 15 EUR, $17.86 USD) to `+491760000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178493`, Delivered: `15 EUR`, Net Wholesale Cost: `$17.5028 USD` (2% discount applied), PIN Code: `773709732502940`
* **Result:** **Primary Active Provider** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment) — 🟢 Secondary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `BLAU_DE_001-ROW` (Blau 15 EUR Top-Up) to `+491760000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_de_test_1787439268141_blau_de_001_row`, Wholesale Cost: `$18.99 USD`
* **Result:** **Secondary Direct Failover** (`priority: 20`).

### 3. DT One (Pre-Production API) — 🔴 Disabled Route
* **Operator Code:** `2754` ("Blau Germany")
* **Status:** Returns 0 pre-prod products.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `BSDE` ("Blau Germany") / `B7DE`
* **Catalog Status:** Returns 0 active inventory in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **Reloadly** (`operatorId: 849` — 15 EUR PIN voucher at **$17.5028 USD net**, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Zendit** (`brand: Blau` — offers `BLAU_DE_001-ROW` 15 EUR for $18.99 USD, `priority: 20`).
3. **Disabled Providers:** **DT One** (`2754`, `priority: 30`) and **DingConnect** (`BSDE`, `priority: 40`).
4. **BNetzA Germany Regulatory Compliance:**
   - Blau prepaid SIM cards remain active for **180 days** from the date of the last top-up.
   - Recharging with a **15 EUR PIN** via Reloadly or direct top-up via Zendit resets the 180-day active validity window.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** to maintain active SIM lifecycle automatically.
