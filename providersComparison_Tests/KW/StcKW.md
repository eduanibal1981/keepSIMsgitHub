# Provider Comparison & Test Report: STC Kuwait

> **Country:** Kuwait (`KW` / `+965` / `KWT`)  
> **Carrier:** STC Kuwait (Kuwait Telecommunications Company - KTC / STC Group, formerly VIVA Kuwait)  
> **Network Type:** MNO (~30% Market Share)  
> **Balance USSD / SMS:** Dial `*555#` or `*100#` (Main Balance) | SMS "11" to `500` (Data)  
> **Recharge USSD:** Dial `*500*<14-digit PIN>#` or mystc KW App / QuickPay Portal  
> **Customer Care:** `102` (From STC) / `+965 55102102`  
> **Regulatory Policy (CITRA Kuwait):** STC Kuwait operates on the standard CITRA denomination validity ladder (1.5 KWD = 7–14 days, 3–5 KWD = 30 days, 10 KWD = 90–180 days, 25 KWD = 365 days). Inactive lines enter a 90-day grace period upon balance expiry, followed by hard suspension and number revocation at 180 inactive days.  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `KWT` (ISO-3) | `KW` (ISO-2) | `KW` (ISO-2) | `KW` (ISO-2) |
| **Carrier / Operator Code** | `1813` ("STC Kuwait") | `267` ("STC Kuwait") | `STC` | `VIKW` ("STC Kuwait") / `V8KW` ("Pins") |
| **Delivery Mechanism** | Direct Airtime Top-Up (Open Range & Fixed) | Direct Airtime Top-Up (Flexible Range) | Direct Top-Up (0 Inventory in Sandbox) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `12222` (2.00–50.00 KWD) + 7 Fixed Products (1.5–25 KWD) | Flexible Range ($7.60–$44.00 USD / ~1.90–11.00 KWD) | 0 Active Products in Sandbox | 0 Active Products in UAT (503 / RateLimited) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (KWD) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`VIKW`) |
| :---: | :---: | :---: | :---: | :---: |
| **1.50 KWD** (Min Entry Refill) | **2.346 OMR ($6.10 USD)** (`24346`) | — *(Min: $7.60 USD / ~1.90 KWD)* | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **2.00 KWD** (Open Range Min) | **3.140 OMR ($8.17 USD)** (`12222`) | **$7.76 USD** (`267`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **3.00 KWD** (30-Day Airtime) | **4.691 OMR ($12.20 USD)** (`9945`) | **$11.64 USD** (`267`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **4.00 KWD** (Standard Top-Up) | **6.255 OMR ($16.27 USD)** (`53996`) | **$15.52 USD** (`267`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **5.00 KWD** (Standard Top-Up) | **7.819 OMR ($20.33 USD)** (`9946`) | **$19.40 USD** (`267`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **10.00 KWD** (Quarterly Top-Up) | **15.637 OMR ($40.67 USD)** (`9947`) | **$38.80 USD** (`267`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **20.00 KWD** (Semi-Annual Top-Up)| **31.274 OMR ($81.34 USD)** (`53994`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **25.00 KWD** (Annual 365D Validity)| **39.092 OMR ($101.67 USD)** (`53995`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `24346` (STC Kuwait 1.5 KWD) to `+96550000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793388`, Wholesale Cost: `2.344 OMR` (~$6.10 USD), Delivered: `1.5 KWD`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `267` (STC Kuwait Airtime, $7.60 USD requested) to `+96550000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178440`, Delivered: `2.34 KWD`, Wholesale Cost: `$7.37 USD` ($7.60 minus 3% discount)
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🔴 Disabled Route
* **Brand Code:** `STC`
* **Catalog Status:** Returns `200 OK` with `0` active offers for country `KW`.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `VIKW` ("STC Kuwait") / `V8KW` ("STC Pins Kuwait")
* **Validation Regex:** `^965[0-9]{8}$`
* **Catalog Status:** Returns `503 Service Unavailable / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1813` / Product `24346` & Open Range `12222` — lowest entry cost at 1.50 KWD / 2.344 OMR / ~$6.10 USD, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 267` — flexible range from $7.60 USD with 3% commission discount, `priority: 20`).
3. **Disabled Providers:** **Zendit** (`STC`, `priority: 30`, `is_enabled: false`) and **DingConnect** (`VIKW`, `priority: 40`, `is_enabled: false`).
4. **CITRA Kuwait Regulatory Compliance:**
   - STC Kuwait (Go prepaid) lines require top-ups to maintain active line validity.
   - Refills of 1.5–3 KWD grant 7–30 days active validity.
   - Lines that expire enter a 90-day grace period before total deactivation and number revocation at 180 inactive days.
   - KeepSIMs triggers automated refills (1.5 KWD / ~$6.10 USD via DT One) on **Day 60–80** to continuously protect line validity.
