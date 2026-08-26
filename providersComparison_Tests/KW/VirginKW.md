# Provider Comparison & Test Report: Virgin Mobile Kuwait

> **Country:** Kuwait (`KW` / `+965` / `KWT`)  
> **Carrier:** Virgin Mobile Kuwait (Virgin Mobile Middle East & Africa / Hosted on STC Kuwait Network)  
> **Network Type:** MVNO (Host: STC Kuwait)  
> **Balance USSD / SMS:** Dial `*102#` or via Virgin Mobile Kuwait App  
> **Recharge USSD:** Via Virgin Mobile Kuwait App or STC Kuwait Recharge Vouchers (`*500*<PIN>#`)  
> **Customer Care:** `1789` (From Virgin) / `+965 51001789`  
> **Regulatory Policy (CITRA Kuwait):** Virgin Mobile Kuwait operates under CITRA MVNO framework on the STC network infrastructure. Standard CITRA validity ladders apply. Inactive SIMs enter a 90-day grace period upon plan expiration, followed by disconnection and number recycling after 180 days of total inactivity.  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `KWT` (ISO-3) | `KW` (ISO-2) | `KW` (ISO-2) | `KW` (ISO-2) |
| **Carrier / Operator Code** | `1813` ("STC Kuwait" / Host) | `267` ("STC Kuwait" / Host) | `Virgin Mobile` | `VIKW` ("STC Kuwait" / Host) |
| **Delivery Mechanism** | Direct Airtime & STC Host Recharge | Direct Airtime & STC Host Recharge | Direct Top-Up (0 Inventory in Sandbox) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Via STC Kuwait (`1813`): 1.5–25 KWD & Open Range `12222` | Via STC Kuwait (`267`): $7.60–$44.00 USD Range | 0 Active Products in Sandbox | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (KWD) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`VIKW`) |
| :---: | :---: | :---: | :---: | :---: |
| **1.50 KWD** (Min Entry Refill) | **2.346 OMR ($6.10 USD)** (`24346`) | — *(Min: $7.60 USD / ~1.90 KWD)* | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **2.00 KWD** (Open Range Min) | **3.140 OMR ($8.17 USD)** (`12222`) | **$7.76 USD** (`267`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **3.00 KWD** (30-Day Airtime) | **4.691 OMR ($12.20 USD)** (`9945`) | **$11.64 USD** (`267`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **5.00 KWD** (Standard Top-Up) | **7.819 OMR ($20.33 USD)** (`9946`) | **$19.40 USD** (`267`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **10.00 KWD** (Quarterly Top-Up) | **15.637 OMR ($40.67 USD)** (`9947`) | **$38.80 USD** (`267`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **25.00 KWD** (Annual 365D Validity)| **39.092 OMR ($101.67 USD)** (`53995`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Route (via STC Host)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `24346` (STC Kuwait 1.5 KWD) to `+96550000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793388`, Wholesale Cost: `2.344 OMR` (~$6.10 USD)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Route (via STC Host)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `267` (STC Kuwait Airtime, $7.60 USD) to `+96550000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178440`, Cost: `$7.37 USD`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🔴 Disabled Route
* **Brand Code:** `Virgin Mobile`
* **Catalog Status:** Returns `0` active offers for country `KW`.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `VIKW`
* **Catalog Status:** Returns `503 Service Unavailable` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **DT One** (`operatorId: 1813` / Product `24346` — 1.5 KWD for 2.344 OMR / ~$6.10 USD via STC host rail, `priority: 10`, `is_primary: true`).
2. **Secondary Route:** **Reloadly** (`operatorId: 267` — via STC host rail, `priority: 20`).
3. **Disabled Providers:** **Zendit** (`Virgin Mobile`, `priority: 30`, `is_enabled: false`) and **DingConnect** (`VIKW`, `priority: 40`, `is_enabled: false`).
4. **CITRA Kuwait Regulatory Compliance:**
   - Virgin Mobile Kuwait operates under CITRA prepaid line rules.
   - Refills keep the subscriber's digital SIM account active.
   - Automated mini-refills scheduled on **Day 60–80** safeguard the Virgin Mobile line from expiration and number recycling.
