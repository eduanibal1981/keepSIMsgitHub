# Provider Comparison & Test Report: Lycamobile Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** Lycamobile Germany GmbH (`Lyca Mobile` / `Lycamobile Deutschland` / Host: Vodafone D2 Network)  
> **Network Type:** International MVNO (~2M+ Subscribers)  
> **Balance USSD / SMS:** Dial `*131#` (Screen pop-up) | Dial `321` (Voice IVR balance) | App: **Lyca Mobile Germany**  
> **Recharge USSD:** Dial `*131*<16-digit PIN>#` / Dial `321` / Web: `https://www.lycamobile.de/de/recharge/`  
> **Customer Care:** Dial `322` (From Lycamobile) / `069 945 199 322` / `+49 69 945199322`  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up | 60 Days Passive Grace Period before line termination and number recycling | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **DT One** (`dtone`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DE` (ISO-2) | `DEU` (ISO-3) | `DE` (ISO-2) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `864` ("Lycamobile PIN") / `865` (AllNet Flat) | `2121` ("Lyca Germany") | `Lycamobile` | `LYDE` ("Lycamobile Germany") |
| **Delivery Mechanism** | **Digital PIN Vouchers (Micro-Refill 5 EUR) & Bundles** | PIN / Direct (0 pre-prod SKUs) | Direct Top-Up (0 Catalog Offers) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** | **`OMR`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 6 Fixed PINs (5, 10, 20, 30, 40, 50 EUR) + 1 Bundle (19.99 EUR) | 0 Active Products in Pre-Prod | 0 Active Products | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Micro-Refill Route** (`is_primary: true`, `priority: 10`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 20`) | 🔴 **Disabled** (`is_enabled: false`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | Reloadly Wholesale (`USD` / Net) / Op ID | DT One Wholesale (`OMR`) | Zendit Wholesale (`USD`) | DingConnect Direct (`LYDE`) |
| :---: | :---: | :---: | :---: | :---: |
| **5.00 EUR** (Micro-PIN Voucher) | **$5.92 USD** (`864`) | — | — | 🔴 *(0 Catalog Offers)* |
| **10.00 EUR** (PIN Voucher) | **$11.84 USD** (`864`) | — | — | 🔴 *(0 Catalog Offers)* |
| **19.99 EUR** (AllNet Flat Bundle) | **$23.80 USD** (`865`) | — | — | 🔴 *(0 Catalog Offers)* |
| **20.00 EUR** (PIN Voucher) | **$23.69 USD** (`864`) | — | — | 🔴 *(0 Catalog Offers)* |
| **24.99 EUR** (AllNet Plus PIN) | **$29.75 USD** (`866`) | — | — | 🔴 *(0 Catalog Offers)* |
| **30.00 EUR** (PIN Voucher) | **$35.53 USD** (`864`) | — | — | 🔴 *(0 Catalog Offers)* |
| **40.00 EUR** (PIN Voucher) | **$47.38 USD** (`864`) | — | — | 🔴 *(0 Catalog Offers)* |
| **50.00 EUR** (PIN Voucher) | **$59.22 USD** (`864`) | — | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🟢 Primary Micro-Refill Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `864` (Lycamobile PIN 5 EUR, $5.92 USD) to `+491520000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178492`, Delivered: `5 EUR`, Wholesale Cost: `$5.92 USD`, PIN Code: `773709732439821`
* **Result:** **Primary Active Micro-Refill Provider** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API) — 🔴 Disabled Route
* **Operator Code:** `2121` ("Lyca Germany")
* **Status:** Returns 0 pre-prod products.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 20`).

### 3. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `LYDE` ("Lycamobile Germany")
* **Catalog Status:** Returns 0 active inventory in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **Reloadly** (`operatorId: 864` — lowest entry price starting at **5 EUR PIN ($5.92 USD)** and denominations up to 50 EUR, `priority: 10`, `is_primary: true`).
2. **Disabled Providers:** **DT One** (`2121`, `priority: 20`), **DingConnect** (`LYDE`, `priority: 30`), and **Zendit** (0 offers).
3. **BNetzA Germany Regulatory Compliance:**
   - Lycamobile Germany prepaid SIM cards remain active for **180 days** from the date of the last top-up.
   - Recharging with a **5 EUR PIN** via Reloadly resets the 180-day active validity window.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** to maintain active SIM lifecycle automatically.
