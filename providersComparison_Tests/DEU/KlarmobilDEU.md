# Provider Comparison & Test Report: Klarmobil Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** klarmobil GmbH (freenet Group / Host: Deutsche Telekom & Vodafone Networks)  
> **Network Type:** Independent MVNO (~1.5M+ Subscribers)  
> **Balance USSD / SMS:** Dial `*100#` (Screen pop-up) | App: **klarmobil App**  
> **Recharge USSD:** Dial `*101*<PIN>#` (Telekom network SIMs) / `*100*<PIN>#` (Vodafone network SIMs) / Web: `https://www.klarmobil.de/service/guthaben-aufladen/`  
> **Customer Care:** Dial `040 34 8585 300`  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up | 60 Days Passive Grace Period before line termination | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **DT One** (`dtone`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DE` (ISO-2) | `DEU` (ISO-3) | `DE` (ISO-2) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `854` ("Klarmobil PIN Germany") | `3117` ("Klarmobil PIN Germany") | Unsupported | Unsupported |
| **Delivery Mechanism** | **Digital PIN Vouchers (15, 30, 50 EUR)** | PIN Voucher (0 pre-prod SKUs) | Unsupported | Unsupported |
| **Settlement Currency** | **`USD`** | **`OMR`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 3 Fixed PIN Amounts (15, 30, 50 EUR) | 0 Active Products in Pre-Prod | 0 Active Products | 0 Active Products |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Route** (`is_primary: true`, `priority: 10`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 20`) | 🔴 **Disabled** (`is_enabled: false`) | 🔴 **Disabled** (`is_enabled: false`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | Reloadly Wholesale (`USD` / Net) / Op ID | DT One Wholesale (`OMR`) | Zendit Wholesale (`USD`) | DingConnect Direct |
| :---: | :---: | :---: | :---: | :---: |
| **15.00 EUR** (PIN Voucher) | **$17.86 USD** (`854`) | — | 🔴 *(Unsupported)* | 🔴 *(Unsupported)* |
| **30.00 EUR** (PIN Voucher) | **$35.71 USD** (`854`) | — | 🔴 *(Unsupported)* | 🔴 *(Unsupported)* |
| **50.00 EUR** (PIN Voucher) | **$59.52 USD** (`854`) | — | 🔴 *(Unsupported)* | 🔴 *(Unsupported)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🟢 Primary Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `854` (Klarmobil PIN 15 EUR, $17.86 USD) to `+491510000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178498`, Delivered: `15 EUR`, Net Wholesale Cost: `$17.86 USD`, PIN Code: `773709733047361`
* **Result:** **Primary Active Provider** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API) — 🔴 Disabled Route
* **Operator Code:** `3117` ("Klarmobil PIN Germany")
* **Status:** Returns 0 pre-prod products.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 20`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **Reloadly** (`operatorId: 854` — 15 EUR PIN voucher for **$17.86 USD**, `priority: 10`, `is_primary: true`).
2. **Disabled Providers:** **DT One** (`3117`, `priority: 20`), **Zendit** (unsupported), and **DingConnect** (unsupported).
3. **BNetzA Germany Regulatory Compliance:**
   - Klarmobil prepaid SIM cards remain active for **180 days** from the date of the last top-up.
   - Recharging with a **15 EUR PIN** via Reloadly resets the 180-day active validity window.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** to maintain active SIM lifecycle automatically.
