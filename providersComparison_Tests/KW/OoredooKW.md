# Provider Comparison & Test Report: Ooredoo Kuwait

> **Country:** Kuwait (`KW` / `+965` / `KWT`)  
> **Carrier:** Ooredoo Kuwait (National Mobile Telecommunications Company - NMTC / Ooredoo Group, formerly Wataniya Telecom)  
> **Network Type:** MNO (~33% Market Share)  
> **Balance USSD / SMS:** Dial `*121#` or `*555#` (Main Balance) | SMS "Balance" to `121`  
> **Recharge USSD:** Dial `*111*<14-digit PIN>#` or Ooredoo Kuwait App / QuickPay Portal  
> **Customer Care:** `121` (From Ooredoo) / `+965 1805555`  
> **Regulatory Policy (CITRA Kuwait):** Under CITRA regulations, prepaid line validity is the higher of the last recharge denomination or current validity. 1.5 KWD grants 7–14 days, 3–5 KWD grants 30 days, 10 KWD grants 90–180 days, and 25 KWD grants 365 days. After expiry, the SIM enters a 90-day grace period before permanent disconnection and recycling at 180 days.  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `KWT` (ISO-3) | `KW` (ISO-2) | `KW` (ISO-2) | `KW` (ISO-2) |
| **Carrier / Operator Code** | `1811` ("Ooredoo Kuwait") | `1166` ("Ooredo Kuwait") | `Ooredoo` | `WTKW` ("Ooredoo Kuwait") / `WKKW` ("Pins") |
| **Delivery Mechanism** | Direct Airtime Top-Up (Open Range & Fixed) | Direct Airtime Top-Up (Flexible Range) | Direct Top-Up (0 Inventory in Sandbox) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `15206` (1.50–50.00 KWD) + 8 Fixed Products (1.5–25 KWD) | Flexible Range ($5.70–$740.00 USD / ~1.48–192.40 KWD) | 0 Active Products in Sandbox | 0 Active Products in UAT (503 / RateLimited) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (KWD) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`WTKW`) |
| :---: | :---: | :---: | :---: | :---: |
| **1.50 KWD** (Min Entry Refill) | **2.355 OMR ($6.12 USD)** (`24345` / `15206`) | **$5.70 USD** (`1166`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **2.00 KWD** (Standard Top-Up) | **3.133 OMR ($8.15 USD)** (`53990`) | **$7.70 USD** (`1166`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **2.50 KWD** (Standard Top-Up) | **3.916 OMR ($10.18 USD)** (`53991`) | **$9.62 USD** (`1166`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **3.00 KWD** (30-Day Airtime) | **4.699 OMR ($12.22 USD)** (`11089`) | **$11.54 USD** (`1166`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **5.00 KWD** (Standard Top-Up) | **7.831 OMR ($20.37 USD)** (`11090`) | **$19.23 USD** (`1166`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **10.00 KWD** (Quarterly Top-Up) | **15.662 OMR ($40.73 USD)** (`11091`) | **$38.46 USD** (`1166`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **20.00 KWD** (Semi-Annual Top-Up)| **31.324 OMR ($81.47 USD)** (`53992`) | **$76.92 USD** (`1166`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **25.00 KWD** (Annual 365D Validity)| **39.155 OMR ($101.83 USD)** (`53993`) | **$96.15 USD** (`1166`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `24345` (Ooredoo Kuwait 1.5 KWD) to `+96560000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793387`, Wholesale Cost: `2.353 OMR` (~$6.12 USD), Delivered: `1.5 KWD`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `1166` (Ooredoo Kuwait Airtime, $5.70 USD requested) to `+96560000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178438`, Delivered: `1.76 KWD`, Wholesale Cost: `$5.70 USD`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🔴 Disabled Route
* **Brand Code:** `Ooredoo`
* **Catalog Status:** Returns `200 OK` with `0` active offers for country `KW`.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `WTKW` ("Ooredoo Kuwait") / `WKKW` ("Ooredoo Pins Kuwait")
* **Validation Regex:** `^965[0-9]{8}$`
* **Catalog Status:** Returns `503 Service Unavailable / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1811` / Open Range `15206` — full continuous amount selection from 1.50 KWD up to 50.00 KWD, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 1166` — wide range with instant automated execution, `priority: 20`).
3. **Disabled Providers:** **Zendit** (`Ooredoo`, `priority: 30`, `is_enabled: false`) and **DingConnect** (`WTKW`, `priority: 40`, `is_enabled: false`).
4. **CITRA Kuwait Regulatory Compliance:**
   - Ooredoo Kuwait prepaid SIMs require top-ups according to denomination validity.
   - Refills of 1.5–3 KWD grant 7–30 days active validity.
   - An inactivity grace period of 90 days allows incoming calls/SMS before the line is placed into suspension.
   - Permanent number recycling occurs at 180 total days of inactivity.
   - KeepSIMs triggers automated refills (1.5 KWD / ~$6.12 USD via DT One) on **Day 60–80** to perpetually reset the active status and protect subscriber identity.
