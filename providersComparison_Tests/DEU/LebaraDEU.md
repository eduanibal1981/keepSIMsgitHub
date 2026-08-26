# Provider Comparison & Test Report: Lebara Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** Lebara Mobile Germany GmbH (`Lebara` / `Lebara Deutschland` / Host: Telefónica & Deutsche Telekom Network)  
> **Network Type:** International MVNO (Ethnic & Roaming Specialist / ~2.5M+ Users)  
> **Balance USSD / SMS:** Dial `*141#` (Screen pop-up) | SMS `GUTHABEN` to `55255` | App: **MyLebara**  
> **Recharge USSD:** Dial `*131*<16-digit PIN>#` / Dial `5588` (IVR) / Web: `https://mobile.lebara.com/de/de/aufladen`  
> **Customer Care:** Dial `5588` (From Lebara mobile) / `01806 532 272` / `+49 1806 532272`  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up | 60 Days Passive Grace Period before termination | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **DT One** (`dtone`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DE` (ISO-2) | `DEU` (ISO-3) | `DE` (ISO-2) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `855` ("Lebara PIN") / `857` (Flexi) / `859` (Komplett) | `2728` / `6016` | `Lebara` | `ESDE` ("Lebara Germany") |
| **Delivery Mechanism** | **Digital PIN Vouchers & Direct Data/Bundles** | PIN / Direct (0 pre-prod SKUs) | Direct Top-Up (0 Catalog Offers) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** | **`OMR`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 6 Fixed PINs (10–100 EUR) + 12 Bundles (9.99–49.99 EUR) | 0 Active Products in Pre-Prod | 0 Active Products | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Provider** (`is_primary: true`, `priority: 10`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 20`) | 🔴 **Disabled** (`is_enabled: false`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | Reloadly Wholesale (`USD` / Net) / Op ID | DT One Wholesale (`OMR`) | Zendit Wholesale (`USD`) | DingConnect Direct (`ESDE`) |
| :---: | :---: | :---: | :---: | :---: |
| **9.99 EUR** (Flexi S Bundle) | **$11.89 USD ($11.5333 net)** (`857`) | — | — | 🔴 *(0 Catalog Offers)* |
| **9.99 EUR** (Komplett S Bundle) | **$11.89 USD ($11.5333 net)** (`859`) | — | — | 🔴 *(0 Catalog Offers)* |
| **9.99 EUR** (World S Bundle) | **$11.89 USD ($11.5333 net)** (`861`) | — | — | 🔴 *(0 Catalog Offers)* |
| **10.00 EUR** (PIN Voucher) | **$11.90 USD** (`855`) | — | — | 🔴 *(0 Catalog Offers)* |
| **14.99 EUR** (Flexi M Bundle) | **$17.85 USD ($17.3145 net)** (`857`) | — | — | 🔴 *(0 Catalog Offers)* |
| **15.00 EUR** (PIN Voucher) | **$17.86 USD** (`855`) | — | — | 🔴 *(0 Catalog Offers)* |
| **19.99 EUR** (Flexi L Bundle) | **$23.80 USD ($23.086 net)** (`857`) | — | — | 🔴 *(0 Catalog Offers)* |
| **20.00 EUR** (PIN Voucher) | **$23.81 USD** (`855`) | — | — | 🔴 *(0 Catalog Offers)* |
| **30.00 EUR** (PIN Voucher) | **$35.71 USD** (`855`) | — | — | 🔴 *(0 Catalog Offers)* |
| **50.00 EUR** (PIN Voucher) | **$59.52 USD** (`855`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 EUR** (PIN Voucher) | **$119.05 USD** (`855`) | — | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🟢 Primary Route
* **API Endpoint:** `POST /topups`
* **Test Request 1:** Operator `855` (Lebara PIN 10 EUR, $11.90 USD) to `+491550000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178489`, Delivered: `10 EUR`, Wholesale Cost: `$11.90 USD`, PIN Code: `773709733073622`
* **Test Request 2:** Operator `857` (Lebara Flexi Germany Bundle 9.99 EUR, $11.89 USD) to `+491550000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178491`, Delivered: `9.99 EUR`, Net Wholesale Cost: `$11.5333 USD`
* **Result:** **Primary Active Provider** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API) — 🔴 Disabled Route
* **Operator Code:** `2728` ("Lebara PIN Germany") / `6016` ("Lebara Germany")
* **Status:** Returns 0 pre-prod products.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 20`).

### 3. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `ESDE` ("Lebara Germany")
* **Catalog Status:** Returns 0 active inventory in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **Reloadly** (`operatorId: 855` / `857` / `859` — comprehensive selection of PIN vouchers from 10 EUR and all-inclusive bundles from 9.99 EUR at **$11.53 USD net**, `priority: 10`, `is_primary: true`).
2. **Disabled Providers:** **DT One** (`2728`, `priority: 20`), **DingConnect** (`ESDE`, `priority: 30`), and **Zendit** (0 offers).
3. **BNetzA Germany Regulatory Compliance:**
   - Lebara Germany prepaid SIM cards remain active for **180 days** from the date of the last recharge.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** (delivering 9.99 EUR bundle or 10 EUR PIN via Reloadly) to reset the 180-day active validity window continuously.
