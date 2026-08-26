# Provider Comparison & Test Report: Ay Yildiz Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** Telefónica Germany GmbH & Co. OHG (`Ay Yildiz` / `Ay Yildiz Prepaid` / Host: Telefónica Network)  
> **Network Type:** Ethnic Brand (Turkish-German Community Specialist / ~1.2M+ Subscribers)  
> **Balance USSD / SMS:** Dial `*100#` (Screen pop-up) | Dial `1155` (Voice IVR Portal) | App: **Mein Ay Yildiz**  
> **Recharge USSD:** Dial `*100*<16-digit Aufladecode>#` / Dial `1155` / Web: `https://www.ayyildiz.de/guthaben-aufladen`  
> **Customer Care:** Dial `1155` (From Ay Yildiz mobile) / `0177 177 1177` / `+49 177 1771177`  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up | 60 Days Passive Grace Period before line termination | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Zendit** (`zendit`) | **DT One** (`dtone`) | **DingConnect** (`ding`) | **Reloadly** (`reloadly`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DE` (ISO-2) | `DEU` (ISO-3) | `DE` (ISO-2) | `DE` (ISO-2) |
| **Carrier / Operator Code** | `AyYildiz` | `2135` ("Ay Yildiz Germany") | `AYDE` ("Ay Yildiz Germany") / `A9DE` | `Ay Yildiz` |
| **Delivery Mechanism** | **Direct Top-Up (`AYYILDIZ_DE_001-ROW` / `002`)** | PIN / Direct (0 pre-prod SKUs) | Direct Top-Up & PIN (0 Inventory in UAT) | Unsupported |
| **Settlement Currency** | **`USD`** | **`OMR`** | **`OMR`** | **`USD`** |
| **Catalog Format** | 2 Fixed Offers (15, 20 EUR) | 0 Active Products in Pre-Prod | 0 Active Products in UAT | 0 Active Products |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Route** (`is_primary: true`, `priority: 10`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (EUR) | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR`) | DingConnect Direct (`AYDE`) | Reloadly Wholesale (`USD`) |
| :---: | :---: | :---: | :---: | :---: |
| **15.00 EUR** (Direct Top-Up) | **$18.73 USD** (`AYYILDIZ_DE_001-ROW`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(Unsupported)* |
| **20.00 EUR** (Direct Top-Up) | **$24.97 USD** (`AYYILDIZ_DE_002-ROW`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(Unsupported)* |

---

## 3. Live Test & Simulation Results

### 1. Zendit (Test Environment) — 🟢 Primary Route
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `AYYILDIZ_DE_001-ROW` (Ay Yildiz 15 EUR Top-Up) to `+491760000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `zen_de_test_1787439271650_ayyildiz_de_001_row`, Wholesale Cost: `$18.73 USD`
* **Result:** **Primary Active Provider** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API) — 🔴 Disabled Route
* **Operator Code:** `2135` ("Ay Yildiz Germany")
* **Status:** Returns 0 pre-prod products.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 20`).

### 3. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `AYDE` ("Ay Yildiz Germany") / `A9DE`
* **Catalog Status:** Returns 0 active inventory in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **Zendit** (`brand: AyYildiz` — direct top-up offers `AYYILDIZ_DE_001-ROW` 15 EUR for $18.73 USD and 20 EUR for $24.97 USD, `priority: 10`, `is_primary: true`).
2. **Disabled Providers:** **DT One** (`2135`, `priority: 20`), **DingConnect** (`AYDE`, `priority: 30`), and **Reloadly** (unsupported).
3. **BNetzA Germany Regulatory Compliance:**
   - Ay Yildiz prepaid SIM cards remain active for **180 days** from the date of the last top-up.
   - Recharging with **15 EUR** via Zendit direct top-up resets the 180-day active validity timer.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** to maintain active SIM lifecycle automatically.
