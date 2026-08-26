# Provider Comparison & Test Report: Zain Kuwait

> **Country:** Kuwait (`KW` / `+965` / `KWT`)  
> **Carrier:** Zain Kuwait (Mobile Telecommunications Company - MTC / Zain Group)  
> **Network Type:** MNO (National Market Leader / ~37% Market Share)  
> **Balance USSD / SMS:** Dial `*142#` or `*107#` (Main Balance) | SMS "B" to `999` (Data)  
> **Recharge USSD:** Dial `*141*<14-digit PIN>#` or Zain KW App / QuickPay Portal  
> **Customer Care:** `107` (From Zain) / `+965 97107107` / `+965 24644444`  
> **Regulatory Policy (CITRA Kuwait):** CITRA prepaid validity ladder applies. 1.5 KWD extends validity by 7–14 days, 3–5 KWD extends 30 days, 10 KWD extends 90–180 days, 25 KWD extends 365 days. Line enters a 90-day grace period upon expiry followed by number termination and quarantine at 180 total inactive days.  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `KWT` (ISO-3) | `KW` (ISO-2) | `KW` (ISO-2) | `KW` (ISO-2) |
| **Carrier / Operator Code** | `1812` ("Zain Kuwait") | `268` ("Zain Kuwait") | `Zain` | `ZAKW` ("Zain Kuwait") |
| **Delivery Mechanism** | Direct Airtime Top-Up (Open Range & Fixed) | Direct Airtime Top-Up (Fixed Tiers) | Direct Top-Up (0 Inventory in Sandbox) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range `12248` (1.50–50.00 KWD) + 6 Fixed Products (1.5–25 KWD) | 5 Fixed Tiers: $5.70, $11.35, $18.95, $37.85, $75.65 USD | 0 Active Products in Sandbox | 0 Active Products in UAT (503 / RateLimited) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (KWD) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`ZAKW`) |
| :---: | :---: | :---: | :---: | :---: |
| **1.50 KWD** (Min Entry Refill) | **2.361 OMR ($6.14 USD)** (`24347` / `12248`) | **$5.53 USD** ($5.70 tier / `268`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **3.00 KWD** (30-Day Airtime) | **4.722 OMR ($12.28 USD)** (`9950`) | **$11.01 USD** ($11.35 tier / `268`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **5.00 KWD** (Standard Top-Up) | **7.870 OMR ($20.47 USD)** (`9951`) | **$18.38 USD** ($18.95 tier / `268`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **10.00 KWD** (Quarterly Top-Up) | **15.740 OMR ($40.94 USD)** (`9948`) | **$36.71 USD** ($37.85 tier / `268`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **20.00 KWD** (Semi-Annual Top-Up)| **31.480 OMR ($81.87 USD)** (`53997`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **25.00 KWD** (Annual 365D Validity)| **39.350 OMR ($102.34 USD)** (`53998`) | **$73.38 USD** ($75.65 tier / `268`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `24347` (Zain Kuwait 1.5 KWD) to `+96590000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793386`, Wholesale Cost: `2.359 OMR` (~$6.13 USD), Delivered: `1.5 KWD`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `268` (Zain Kuwait Airtime, $5.70 USD requested) to `+96590000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178436`, Delivered: `1.76 KWD`, Wholesale Cost: `$5.53 USD` ($5.70 minus 3% discount)
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🔴 Disabled Route
* **Brand Code:** `Zain`
* **Catalog Status:** Returns `200 OK` with `0` active offers for country `KW`.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `ZAKW` ("Zain Kuwait")
* **Validation Regex:** `^965[0-9]{8}$`
* **Catalog Status:** Returns `503 Service Unavailable / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1812` / Open Range `12248` — supports fine-grained custom refills from 1.50 KWD up to 50.00 KWD with verified instant confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 268` — supports fixed tiers starting at $5.70 USD with automatic 3% commission discount, `priority: 20`).
3. **Disabled Providers:** **Zendit** (`Zain`, `priority: 30`, `is_enabled: false`) and **DingConnect** (`ZAKW`, `priority: 40`, `is_enabled: false`).
4. **CITRA Kuwait Regulatory Compliance:**
   - Zain Kuwait (eeZee) prepaid SIMs adhere to the CITRA validity ladder.
   - Recharge of 1.5–3 KWD provides 7–30 days active window; a 10 KWD recharge provides 90–180 days.
   - Once validity expires, the subscriber enters a 90-day grace period (incoming service only).
   - If not refilled within 180 days of total inactivity, the MSISDN is recycled to the CITRA national pool.
   - KeepSIMs schedules automated mini-refills (1.5 KWD / ~$6.13 USD via DT One) on **Day 60–80** to continuously renew the active validity window and safeguard the number against churn.
