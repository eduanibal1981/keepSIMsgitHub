# Provider Comparison & Test Report: Deutsche Telekom Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** Deutsche Telekom AG (Telekom Deutschland GmbH / `MagentaMobil Prepaid` / `T-Mobile D1`)  
> **Network Type:** MNO (National Market Leader / ~54M+ Mobile Customers)  
> **Balance USSD / SMS:** Dial `*100#` (Instant balance pop-up) | Dial `2000` (Voice IVR balance) | App: **MeinMagenta**  
> **Recharge USSD:** Dial `*101*<16-digit CashCode>#` / Dial `2000` (Follow IVR voice prompt) / Web: `https://www.telekomaufladen.de/`  
> **Customer Care:** Dial `2202` (Free from Telekom mobile) / `0800 33 02202` / `+49 171 88 2202`  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up/billable event | 60 Days Passive Grace Period (*Eingehende Erreichbarkeit* / incoming calls only) before line deactivation and number recycling | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DEU` (ISO-3) | `DE` (ISO-2) | `DE` (ISO-2) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `602` ("Deutsche Telekom Germany") | `664` ("Deutsche Telekom PIN") / `873` ("Telekom PIN") | `Telekom` | `TLDE` ("T-Mobile Germany") / `M4DE` ("T-Mobile Pins") |
| **Delivery Mechanism** | **Direct Airtime Top-Up & Digital PIN Vouchers** | Digital PIN Vouchers | Direct Top-Up (`TELEKOM_DE_001-ROW` / `002` / `003`) | Direct Top-Up & PIN (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 16 SKUs: Direct (10, 15, 20, 25, 30, 35, 40, 45, 50, 75, 100 EUR) + PIN (5, 10, 15, 20, 30 EUR) | 3 Fixed PIN Amounts (15, 30, 50 EUR) | 3 Fixed Offers (15, 30, 50 EUR) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct & PIN Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary PIN Failover** (`priority: 20`) | 🟢 **Tertiary Direct Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`TLDE`) |
| :---: | :---: | :---: | :---: | :---: |
| **5.00 EUR** (Micro-PIN Voucher) | **2.781 OMR ($7.23 USD)** (`24361`) | — | — | 🔴 *(0 Catalog Offers)* |
| **10.00 EUR** (Micro-PIN Voucher) | **5.508 OMR ($14.32 USD)** (`24362`) | — | — | 🔴 *(0 Catalog Offers)* |
| **10.00 EUR** (Direct Top-Up) | **5.382 OMR ($13.99 USD)** (`46871`) | — | — | 🔴 *(0 Catalog Offers)* |
| **15.00 EUR** (Standard Top-Up / PIN) | **8.020 OMR ($20.85 USD)** (`24363` / `15304`) | **$17.65 USD** (`664` / `873`) | **$16.84 USD** (`TELEKOM_DE_001-ROW`) | 🔴 *(0 Catalog Offers)* |
| **20.00 EUR** (Direct Top-Up / PIN) | **10.626 OMR ($27.63 USD)** (`17650` / `24364`) | — | — | 🔴 *(0 Catalog Offers)* |
| **25.00 EUR** (Direct Top-Up) | **13.266 OMR ($34.49 USD)** (`17648`) | — | — | 🔴 *(0 Catalog Offers)* |
| **30.00 EUR** (Direct Top-Up / PIN) | **15.911 OMR ($41.37 USD)** (`15305` / `24365`) | **$35.29 USD** (`664` / `873`) | **$31.66 USD** (`TELEKOM_DE_002-ROW`) | 🔴 *(0 Catalog Offers)* |
| **35.00 EUR** (Direct Top-Up) | **18.556 OMR ($48.25 USD)** (`30100`) | — | — | 🔴 *(0 Catalog Offers)* |
| **40.00 EUR** (Direct Top-Up) | **21.201 OMR ($55.12 USD)** (`17649`) | — | — | 🔴 *(0 Catalog Offers)* |
| **45.00 EUR** (Direct Top-Up) | **23.953 OMR ($62.28 USD)** (`30101`) | — | — | 🔴 *(0 Catalog Offers)* |
| **50.00 EUR** (Direct Top-Up) | **26.486 OMR ($68.86 USD)** (`15306`) | **$58.82 USD** (`664` / `873`) | **$55.83 USD** (`TELEKOM_DE_003-ROW`) | 🔴 *(0 Catalog Offers)* |
| **75.00 EUR** (Direct Top-Up) | **39.707 OMR ($103.24 USD)** (`43130`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 EUR** (Direct Top-Up) | **52.928 OMR ($137.61 USD)** (`43131`) | — | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct & PIN Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `46871` (Telekom 10 EUR Direct Top-Up) to `+491701234567`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793484`, Delivered: `10 EUR`, Wholesale Cost: `5.382 OMR`
* **Test Request 2:** Product `24361` (Telekom 5 EUR PIN Voucher) to `+491701234567`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793485`, Delivered: `5 EUR`, Wholesale Cost: `2.781 OMR`, Instructions: `To top up *101*Top-up-code# or dial 2000 or *100#`
* **Result:** **Primary Active Provider** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary PIN Failover
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `664` (Deutsche Telekom PIN 15 EUR, $17.65 USD) to `+491510000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178483`, Delivered: `15 EUR`, Net Wholesale Cost: `$17.65 USD`, PIN Code: `773709732972504`
* **Result:** **Secondary PIN Failover** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `TELEKOM_DE_001-ROW` (Telekom 15 EUR Top-Up) to `+491510000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_de_test_1787439260604_telekom_de_001_row`, Wholesale Cost: `$16.84 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `TLDE` ("T-Mobile Germany") / `M4DE` ("T-Mobile Pins Germany")
* **Catalog Status:** Returns 0 active inventory in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **DT One** (`operatorId: 602` — unmatched catalog breadth with 16 SKUs from 5 EUR PIN at 2.781 OMR and 10 EUR direct top-up at 5.382 OMR up to 100 EUR, `priority: 10`, `is_primary: true`).
2. **Secondary PIN Failover:** **Reloadly** (`operatorId: 664` / `873` — 15 EUR PIN voucher for $17.65 USD, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Telekom` — offers `TELEKOM_DE_001-ROW` 15 EUR for $16.84 USD, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`TLDE`, `priority: 40`, `is_enabled: false`).
5. **BNetzA Germany Regulatory Compliance:**
   - Deutsche Telekom prepaid SIM cards (MagentaMobil Prepaid) remain active for **180 days** from the date of the last top-up.
   - If unrefilled for 180 days, the line enters a **60-day passive period** (*Passivphase*) where outgoing calls are barred but incoming calls/SMS remain active before permanent disconnection and number release.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** (delivering 5 EUR PIN or 10 EUR top-up via DT One) to reset the 180-day BNetzA active validity window continuously.
