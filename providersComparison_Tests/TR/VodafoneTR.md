# Provider Comparison & Test Report: Vodafone Turkey

> **Country:** Turkey (`TR` / `+90` / `TUR`)  
> **Carrier:** Vodafone Telekomünikasyon A.Ş. (`Vodafone Turkey` / `Vodafone TR`)  
> **Network Type:** MNO (Second National Operator / ~25M+ Subscribers)  
> **Balance USSD / SMS:** Dial `*123#` (Instant balance) or send SMS `OZET` to `7000` | **Recharge USSD:** Dial `*111*<12-digit PIN>#` | **Account App:** Vodafone Yanımda  
> **Customer Care:** `542` (From Vodafone) / `0542 542 00 00` / `+905425420000`  
> **Regulatory Policy (BTK Turkey):** 180 Days Active Line Validity from last top-up | 90 Days Passive / Grace Period before permanent contract cancellation & line termination | Subject to monthly Wireless Usage Fee (*Telsiz Kullanım Ücreti*) and 10% ÖİV Special Communication Tax  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `TUR` (ISO-3) | `TR` (ISO-2) | `TR` (ISO-2) | `TR` (ISO-2) |
| **Carrier / Operator Code** | `662` ("Vodafone Turkey") | `512` ("Vodafone Turkey") / `1178` ("Vodafone Turkey Data") | `Vodafone` | `VFTR` ("Vodafone Turkey") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Kolay Paket | Direct Airtime Top-Up & Kolay Paket Bundles | Direct Top-Up (`VODAFONE_TR_001` – `005`) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** (3% International Discount) | **`USD`** | **`OMR`** |
| **Catalog Format** | 10 Fixed Products (250–2600 TRY) | 4 Airtime (250–600 TRY) + 24 Data Bundles (90–2600 TRY) | 5 Fixed Offers (100, 150, 200, 250, 300 TRY) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Tertiary Failover** (`priority: 30`) | 🟢 **Primary Micro-Refill Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (TRY) | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR` / `USD`) / Product ID | DingConnect Direct (`VFTR`) |
| :---: | :---: | :---: | :---: | :---: |
| **90.00 TRY** (Haftalık İletişim) | **$2.52 USD ($2.444 net)** (`1178`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 TRY** (Standard Top-Up) | — | **$5.00 USD** (`VODAFONE_TR_001`) | — | 🔴 *(0 Catalog Offers)* |
| **140.00 TRY** (Haftalık 500 DK) | **$3.92 USD ($3.802 net)** (`1178`) | — | — | 🔴 *(0 Catalog Offers)* |
| **150.00 TRY** (Standard Top-Up) | — | **$7.50 USD** (`VODAFONE_TR_002`) | — | 🔴 *(0 Catalog Offers)* |
| **200.00 TRY** (Standard Top-Up) | — | **$10.00 USD** (`VODAFONE_TR_003`) | — | 🔴 *(0 Catalog Offers)* |
| **210.00 TRY** (Haftalık Sosyal Medya) | **$5.89 USD ($5.713 net)** (`1178`) | — | — | 🔴 *(0 Catalog Offers)* |
| **250.00 TRY** (Standard Top-Up) | **$7.01 USD ($6.799 net)** (`512`) | **$12.50 USD** (`VODAFONE_TR_004`) | **2.569 OMR ($6.679 USD)** (`50568`) | 🔴 *(0 Catalog Offers)* |
| **270.00 TRY** (15 Günlük TikTok) | **$7.57 USD ($7.342 net)** (`1178`) | — | — | 🔴 *(0 Catalog Offers)* |
| **300.00 TRY** (Standard Top-Up) | **$8.41 USD ($8.157 net)** (`512`) | **$15.00 USD** (`VODAFONE_TR_005`) | **3.083 OMR ($8.016 USD)** (`50569`) | 🔴 *(0 Catalog Offers)* |
| **400.00 TRY** (Standard Top-Up) | **$11.21 USD ($10.874 net)** (`512`) | — | **4.111 OMR ($10.689 USD)** (`54785`) | 🔴 *(0 Catalog Offers)* |
| **500.00 TRY** (Kolay Paket 1GB) | — | — | **4.935 OMR ($12.831 USD)** (`67358`) | 🔴 *(0 Catalog Offers)* |
| **555.00 TRY** (Kolay Paket 3GB) | **$15.56 USD ($15.093 net)** (`1178`) | — | **5.478 OMR ($14.243 USD)** (`63138`) | 🔴 *(0 Catalog Offers)* |
| **600.00 TRY** (Standard Top-Up) | **$16.82 USD ($16.315 net)** (`512`) | — | **6.166 OMR ($16.032 USD)** (`60392`) | 🔴 *(0 Catalog Offers)* |
| **800.00 TRY** (Kolay Paket 15GB) | — | — | **7.896 OMR ($20.530 USD)** (`67357`) | 🔴 *(0 Catalog Offers)* |
| **2600.00 TRY** (Kolay Paket 6 Ay 60GB) | **$72.89 USD ($70.703 net)** (`1178`) | — | **25.660 OMR ($66.716 USD)** (`63147`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🟢 Primary Micro-Refill Route
* **API Endpoint:** `POST /topups`
* **Test Request 1:** Operator `1178` (Vodafone Turkey Data 90 TRY "Haftalık Sınırsız İletişim Paketi", $2.52 USD requested) to `+905420000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178410`, Delivered: `90 TRY`, Net Wholesale Cost: `$2.4444 USD` (3% international discount applied)
* **Test Request 2:** Operator `512` (Vodafone Turkey Airtime 250 TRY, $7.01 USD requested) to `+905420000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL` (Transaction ID `178409`, Net Cost: `$6.7997 USD`)
* **Result:** **Primary Active Micro-Refill Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `VODAFONE_TR_001` (Vodafone Turkey 100 TRY Top-Up) to `+905420000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `test_tr_zen_1787386163990_vodafone_tr_001`, Wholesale Cost: `$5.00 USD`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. DT One (Pre-Production API) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `50568` (Vodafone Turkey 250 TRY) to `+905420000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240792689`, Wholesale Cost: `2.558 OMR` (~$6.651 USD), Delivered: `250 TRY`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `VFTR` ("Vodafone Turkey")
* **Validation Regex:** `^90[0-9]{10}$`
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Micro-Refill Route:** **Reloadly** (`operatorId: 1178` / `512` — micro-bundle starting from 90 TRY at **$2.444 USD** and 250 TRY airtime at **$6.799 USD**, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Zendit** (`brand: Vodafone` — clean 100 TRY entry offer `VODAFONE_TR_001` at **$5.00 USD**, `priority: 20`).
3. **Tertiary Direct Failover:** **DT One** (`operatorId: 662` — 10 denominations including 250 TRY at 2.558 OMR / ~$6.65 USD, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`VFTR`, `priority: 40`, `is_enabled: false`).
5. **BTK Turkey Regulatory Compliance:**
   - Vodafone Turkey prepaid lines remain active for **180 days** from the date of the last top-up.
   - If no recharge occurs within 180 days, the line enters a **90-day passive period** (*Dondurma Süreci*), where outgoing service is barred (incoming service may continue for the initial 30 days).
   - If unrefilled by Day 270, the SIM card is permanently cancelled and the phone number recycled.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** (using Reloadly 90 TRY bundle / $2.44 USD or Zendit 100 TRY / $5.00 USD) to reset the 180-day validity counter indefinitely.
