# Provider Comparison & Test Report: Vodafone Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** Vodafone GmbH (`Vodafone D2` / `CallYa` / `Vodafone Deutschland`)  
> **Network Type:** MNO (National #2 Network Operator / ~31M+ Mobile Customers)  
> **Balance USSD / SMS:** Dial `*100#` (CallYa instant balance) | Dial `22922` (CallYa Account Manager) | App: **MeinVodafone**  
> **Recharge USSD:** Dial `*100*<16-digit CallYa Aufladecode>#` / Dial `22922` (Follow voice menu) / Web: `https://www.vodafone.de/callya-aufladen/`  
> **Customer Care:** Dial `0172 229 0 229` / `+49 172 2290229` (Free from CallYa mobile)  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up | 60 Days Passive Grace Period (*Dondurma / Passivphase*) before line termination and number recycling | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DEU` (ISO-3) | `DE` (ISO-2) | `DE` (ISO-2) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `718` ("Vodafone Germany (D2)") | `875` ("Vodafone PIN Germany") | `Vodafone` | `VFDE` ("Vodafone Germany") / `V6DE` ("Vodafone Pins") |
| **Delivery Mechanism** | **Direct Airtime Top-Up & Digital PIN Vouchers** | Digital PIN Vouchers | Direct Top-Up (`VODAFONE_DE_001-ROW` / `002` / `003`) | Direct Top-Up & PIN (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 5 SKUs: Direct (15, 25, 50 EUR) + PIN (15, 25 EUR) | 2 Fixed PIN Amounts (15, 25 EUR) | 3 Fixed Offers (15, 25, 50 EUR) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct & PIN Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary PIN Failover** (`priority: 20`) | 🟢 **Tertiary Direct Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`VFDE`) |
| :---: | :---: | :---: | :---: | :---: |
| **15.00 EUR** (Direct Top-Up) | **8.084 OMR ($21.02 USD)** (`15313`) | — | **$18.59 USD** (`VODAFONE_DE_001-ROW`) | 🔴 *(0 Catalog Offers)* |
| **15.00 EUR** (PIN Voucher) | **8.047 OMR ($20.92 USD)** (`23386`) | **$17.86 USD** (`875`) | — | 🔴 *(0 Catalog Offers)* |
| **25.00 EUR** (Direct Top-Up) | **13.310 OMR ($34.61 USD)** (`15314`) | — | **$30.87 USD** (`VODAFONE_DE_002-ROW`) | 🔴 *(0 Catalog Offers)* |
| **25.00 EUR** (PIN Voucher) | **13.296 OMR ($34.57 USD)** (`23387`) | **$29.76 USD** (`875`) | — | 🔴 *(0 Catalog Offers)* |
| **50.00 EUR** (Direct Top-Up) | **26.548 OMR ($69.02 USD)** (`15315`) | — | **$61.58 USD** (`VODAFONE_DE_003-ROW`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct & PIN Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `15313` (Vodafone 15 EUR Direct Top-Up) to `+491720000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793480`, Delivered: `15 EUR`, Wholesale Cost: `8.084 OMR`
* **Test Request 2:** Product `23386` (Vodafone 15 EUR PIN Voucher) to `+491720000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793481`, Delivered: `15 EUR`, Wholesale Cost: `8.047 OMR`, PIN Instructions: `* 100 * (your voucher code) # and press dial.`
* **Result:** **Primary Active Provider** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary PIN Failover
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `875` (Vodafone PIN 15 EUR, $17.86 USD) to `+491520000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178484`, Delivered: `15 EUR`, Net Wholesale Cost: `$17.86 USD`, PIN Code: `773709733100143`
* **Result:** **Secondary PIN Failover** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `VODAFONE_DE_001-ROW` (Vodafone 15 EUR Top-Up) to `+491520000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_de_test_1787439262873_vodafone_de_001_row`, Wholesale Cost: `$18.59 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `VFDE` ("Vodafone Germany") / `V6DE` ("Vodafone Pins Germany")
* **Catalog Status:** Returns 0 active inventory in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **DT One** (`operatorId: 718` — full direct top-up and PIN voucher fulfillment starting at 15 EUR for 8.084 / 8.047 OMR, `priority: 10`, `is_primary: true`).
2. **Secondary PIN Failover:** **Reloadly** (`operatorId: 875` — 15 EUR PIN voucher for $17.86 USD, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Vodafone` — offers `VODAFONE_DE_001-ROW` 15 EUR for $18.59 USD, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`VFDE`, `priority: 40`, `is_enabled: false`).
5. **BNetzA Germany Regulatory Compliance:**
   - Vodafone Germany CallYa SIM cards remain active for **180 days** from the date of the last top-up.
   - If unrefilled for 180 days, the line enters a **60-day passive period** (*Passivphase*) where outgoing calls are blocked, before contract termination and number recycling.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** (delivering 15 EUR CallYa voucher or direct refill via DT One / Reloadly) to maintain the active status continuously.
