# Provider Comparison & Test Report: BILDmobil Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** BILDmobil (Axel Springer SE / Host: Vodafone D2 Network)  
> **Network Type:** Media Brand MVNO (~1M+ Customers)  
> **Balance USSD / SMS:** Dial `*100#` (Screen pop-up) | Dial `2142` (Voice IVR balance) | Portal: **BILDmobil Mein Konto**  
> **Recharge USSD:** Dial `*100*<16-digit Aufladecode>#` / Dial `2142` / Web: `https://www.bildmobil.de/aufladen.html`  
> **Customer Care:** Dial `01805 88 00 88` (Vodafone D2 Network)  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up | 60 Days Passive Grace Period before line termination | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **DT One** (`dtone`) | **DingConnect** (`ding`) | **Zendit** (`zendit`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DE` (ISO-2) | `DEU` (ISO-3) | `DE` (ISO-2) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `848` ("BILDMobil PIN Germany") | `3111` ("BILDmobil PIN Germany") | `B6DE` ("Bild Mobil Germany") | Unsupported |
| **Delivery Mechanism** | **Digital PIN Vouchers (10, 20 EUR)** | PIN Voucher (0 pre-prod SKUs) | Direct Top-Up (0 Inventory in UAT) | Unsupported |
| **Settlement Currency** | **`USD`** | **`OMR`** | **`OMR`** | **`USD`** |
| **Catalog Format** | 2 Fixed PIN Amounts (10, 20 EUR) | 0 Active Products in Pre-Prod | 0 Active Products in UAT | 0 Active Products |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Route** (`is_primary: true`, `priority: 10`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | Reloadly Wholesale (`USD` / Net) / Op ID | DT One Wholesale (`OMR`) | DingConnect Direct (`B6DE`) | Zendit Wholesale (`USD`) |
| :---: | :---: | :---: | :---: | :---: |
| **10.00 EUR** (PIN Voucher) | **$11.90 USD ($11.781 net)** (`848`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(Unsupported)* |
| **20.00 EUR** (PIN Voucher) | **$23.81 USD ($23.5719 net)** (`848`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(Unsupported)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🟢 Primary Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `848` (BILDmobil PIN 10 EUR, $11.90 USD) to `+491520000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178499`, Delivered: `10 EUR`, Net Wholesale Cost: `$11.781 USD` (1% discount applied), PIN Code: `773709732229262`
* **Result:** **Primary Active Provider** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API) — 🔴 Disabled Route
* **Operator Code:** `3111` ("BILDmobil PIN Germany")
* **Status:** Returns 0 pre-prod products.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 20`).

### 3. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `B6DE` ("Bild Mobil Germany")
* **Catalog Status:** Returns 0 active inventory in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **Reloadly** (`operatorId: 848` — 10 EUR PIN voucher for **$11.781 USD net**, `priority: 10`, `is_primary: true`).
2. **Disabled Providers:** **DT One** (`3111`, `priority: 20`), **DingConnect** (`B6DE`, `priority: 30`), and **Zendit** (unsupported).
3. **BNetzA Germany Regulatory Compliance:**
   - BILDmobil prepaid SIM cards remain active for **180 days** from the date of the last top-up.
   - Recharging with a **10 EUR PIN** via Reloadly resets the 180-day active validity window.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** to maintain active SIM lifecycle automatically.
