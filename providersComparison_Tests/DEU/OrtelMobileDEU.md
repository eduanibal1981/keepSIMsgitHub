# Provider Comparison & Test Report: Ortel Mobile Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** Ortel Mobile GmbH (`Ortel Mobile` / Host: Telefónica Germany Network)  
> **Network Type:** Ethnic MVNO (International Communities / ~1.5M+ Users)  
> **Balance USSD / SMS:** Dial `*100#` (Instant balance pop-up on screen) | Dial `1155` (Voice IVR Portal) | App: **Ortel Mobile**  
> **Recharge USSD:** Dial `*103*<16-digit Code>#` / Dial `1155` / Web: `https://www.ortelmobile.de/guthaben-aufladen.html`  
> **Customer Care:** Dial `1155` (From Ortel mobile) / `0177 177 1138` / `+49 177 1771138`  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up | 60 Days Passive Grace Period before line termination | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DT One** (`dtone`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DE` (ISO-2) | `DE` (ISO-2) | `DEU` (ISO-3) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `665` ("Ortel PIN Germany") | `Ortel` | `2146` ("Ortel Germany") | `OTDE` ("Ortel Germany") / `O3DE` |
| **Delivery Mechanism** | **Digital PIN Vouchers (15, 20, 30 EUR)** | Direct Top-Up (`ORTEL_DE_001-ROW` / `002`) | PIN / Direct (0 pre-prod SKUs) | Direct Top-Up & PIN (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** | **`USD`** | **`OMR`** | **`OMR`** |
| **Catalog Format** | 3 Fixed PIN Amounts (15, 20, 30 EUR) | 2 Fixed Offers (15, 20 EUR) | 0 Active Products in Pre-Prod | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR`) | DingConnect Direct (`OTDE`) |
| :---: | :---: | :---: | :---: | :---: |
| **15.00 EUR** (PIN / Direct Top-Up) | **$17.86 USD ($17.6814 net)** (`665`) | **$18.75 USD** (`ORTEL_DE_001-ROW`) | — | 🔴 *(0 Catalog Offers)* |
| **20.00 EUR** (PIN / Direct Top-Up) | **$23.81 USD ($23.5719 net)** (`665`) | **$24.91 USD** (`ORTEL_DE_002-ROW`) | — | 🔴 *(0 Catalog Offers)* |
| **30.00 EUR** (PIN Voucher) | **$35.71 USD ($35.3529 net)** (`665`) | — | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🟢 Primary Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `665` (Ortel PIN 15 EUR, $17.86 USD) to `+491760000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178494`, Delivered: `15 EUR`, Net Wholesale Cost: `$17.6814 USD` (1% discount applied), PIN Code: `773709732241957`
* **Result:** **Primary Active Provider** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment) — 🟢 Secondary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `ORTEL_DE_001-ROW` (Ortel 15 EUR Top-Up) to `+491760000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_de_test_1787439269898_ortel_de_001_row`, Wholesale Cost: `$18.75 USD`
* **Result:** **Secondary Direct Failover** (`priority: 20`).

### 3. DT One (Pre-Production API) — 🔴 Disabled Route
* **Operator Code:** `2146` ("Ortel Germany")
* **Status:** Returns 0 pre-prod products.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `OTDE` ("Ortel Germany") / `O3DE`
* **Catalog Status:** Returns 0 active inventory in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **Reloadly** (`operatorId: 665` — 15 EUR PIN voucher at **$17.6814 USD net**, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Zendit** (`brand: Ortel` — offers `ORTEL_DE_001-ROW` 15 EUR for $18.75 USD, `priority: 20`).
3. **Disabled Providers:** **DT One** (`2146`, `priority: 30`) and **DingConnect** (`OTDE`, `priority: 40`).
4. **BNetzA Germany Regulatory Compliance:**
   - Ortel Mobile prepaid SIM cards remain active for **180 days** from the date of the last top-up.
   - Recharging with a **15 EUR PIN** via Reloadly or direct top-up via Zendit resets the 180-day active validity window.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** to maintain active SIM lifecycle automatically.
