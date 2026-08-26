# Provider Comparison & Test Report: Fonic Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** Telefónica Germany GmbH & Co. OHG (`Fonic` / `FONIC mobile` / Host: Telefónica Network)  
> **Network Type:** Discount Brand (~2M+ Subscribers)  
> **Balance USSD / SMS:** Dial `*101#` (Screen pop-up) | Dial `5667` (Voice IVR balance) | App: **FONIC App**  
> **Recharge USSD:** Dial `*103*<16-digit Aufladenummer>#` / Dial `5667` / Web: `https://www.fonic.de/service/aufladen`  
> **Customer Care:** Dial `0176 888 6423`  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up | 60 Days Passive Grace Period before line termination | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **DT One** (`dtone`) | **DingConnect** (`ding`) | **Zendit** (`zendit`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DE` (ISO-2) | `DEU` (ISO-3) | `DE` (ISO-2) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `853` ("FONIC PIN Germany") | `2768` ("Fonic PIN Germany") | `F1DE` ("Fonic Germany") | `Fonic` |
| **Delivery Mechanism** | **Digital PIN Vouchers (20, 30 EUR)** | PIN / Direct (0 pre-prod SKUs) | Direct Top-Up (0 Inventory in UAT) | Unsupported |
| **Settlement Currency** | **`USD`** | **`OMR`** | **`OMR`** | **`USD`** |
| **Catalog Format** | 2 Fixed PIN Amounts (20, 30 EUR) | 0 Active Products in Pre-Prod | 0 Active Products in UAT | 0 Active Products |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Route** (`is_primary: true`, `priority: 10`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | Reloadly Wholesale (`USD` / Net) / Op ID | DT One Wholesale (`OMR`) | DingConnect Direct (`F1DE`) | Zendit Wholesale (`USD`) |
| :---: | :---: | :---: | :---: | :---: |
| **20.00 EUR** (PIN Voucher) | **$23.81 USD** (`853`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(Unsupported)* |
| **30.00 EUR** (PIN Voucher) | **$35.71 USD** (`853`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(Unsupported)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🟢 Primary Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `853` (Fonic PIN 20 EUR, $23.81 USD) to `+491760000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178496`, Delivered: `20 EUR`, Net Wholesale Cost: `$23.81 USD`, PIN Code: `773709733077300`
* **Result:** **Primary Active Provider** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API) — 🔴 Disabled Route
* **Operator Code:** `2768` ("Fonic PIN Germany")
* **Status:** Returns 0 pre-prod products.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 20`).

### 3. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `F1DE` ("Fonic Germany")
* **Catalog Status:** Returns 0 active inventory in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **Reloadly** (`operatorId: 853` — 20 EUR PIN voucher for **$23.81 USD**, `priority: 10`, `is_primary: true`).
2. **Disabled Providers:** **DT One** (`2768`, `priority: 20`), **DingConnect** (`F1DE`, `priority: 30`), and **Zendit** (unsupported).
3. **BNetzA Germany Regulatory Compliance:**
   - Fonic prepaid SIM cards remain active for **180 days** from the date of the last top-up.
   - Recharging with a **20 EUR PIN** via Reloadly resets the 180-day active validity window.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** to maintain active SIM lifecycle automatically.
