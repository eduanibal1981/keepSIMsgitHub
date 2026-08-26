# Provider Comparison & Test Report: Tchibo Mobil Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** Tchibo Mobil (Tchibo Mobilfunk GmbH & Co. KG / JV between Tchibo & Telefónica Germany)  
> **Network Type:** Joint Venture MVNO (~1.8M+ Customers on Telefónica Network)  
> **Balance USSD / SMS:** Dial `*101#` (Instant balance pop-up) | Dial `4055` (Voice IVR balance) | App: **Tchibo Mobil**  
> **Recharge USSD:** Dial `*103*<16-digit Aufladecode>#` / Dial `4055` / Web: `https://www.tchibo-mobil.de/aufladen`  
> **Customer Care:** Dial `040 55 55 55 40` (Mon–Sat 08:00–22:00)  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up | 60 Days Passive Grace Period before line termination | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) | **DT One** (`dtone`) | **Zendit** (`zendit`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DE` (ISO-2) | `DE` (ISO-2) | `DEU` (ISO-3) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `872` ("Tchibo Mobile PIN Germany") | `E825B8DE` ("Tchibo Germany") | Unsupported | Unsupported |
| **Delivery Mechanism** | **Digital PIN Voucher (20 EUR)** | Direct Top-Up (0 Inventory in UAT) | Unsupported | Unsupported |
| **Settlement Currency** | **`USD`** | **`OMR`** | **`OMR`** | **`USD`** |
| **Catalog Format** | 1 Fixed PIN Amount (20 EUR) | 0 Active Products in UAT | 0 Active Products | 0 Active Products |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Route** (`is_primary: true`, `priority: 10`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 20`) | 🔴 **Disabled** (`is_enabled: false`) | 🔴 **Disabled** (`is_enabled: false`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | Reloadly Wholesale (`USD` / Net) / Op ID | DingConnect Direct (`E825B8DE`) | DT One Wholesale (`OMR`) | Zendit Wholesale (`USD`) |
| :---: | :---: | :---: | :---: | :---: |
| **20.00 EUR** (PIN Voucher) | **$23.81 USD** (`872`) | 🔴 *(0 Catalog Offers)* | 🔴 *(Unsupported)* | 🔴 *(Unsupported)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🟢 Primary Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `872` (Tchibo Mobile PIN 20 EUR, $23.81 USD) to `+491760000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178497`, Delivered: `20 EUR`, Net Wholesale Cost: `$23.81 USD`, PIN Code: `773709732308265`
* **Result:** **Primary Active Provider** (`priority: 10`, `is_primary: true`).

### 2. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `E825B8DE` ("Tchibo Germany")
* **Catalog Status:** Returns 0 active inventory in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 20`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **Reloadly** (`operatorId: 872` — 20 EUR PIN voucher for **$23.81 USD**, `priority: 10`, `is_primary: true`).
2. **Disabled Providers:** **DingConnect** (`E825B8DE`, `priority: 20`), **DT One** (unsupported), and **Zendit** (unsupported).
3. **BNetzA Germany Regulatory Compliance:**
   - Tchibo Mobil prepaid SIM cards remain active for **180 days** from the date of the last top-up.
   - Recharging with a **20 EUR PIN** via Reloadly resets the 180-day active validity window.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** to maintain active SIM lifecycle automatically.
