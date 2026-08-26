# Provider Comparison & Test Report: Türk Telekom (TT Mobil / Avea)

> **Country:** Turkey (`TR` / `+90` / `TUR`)  
> **Carrier:** TT Mobil İletişim Hizmetleri A.Ş. (`Türk Telekom` / `Turk Telekom` / formerly `Avea`)  
> **Network Type:** MNO (State-Affiliated Incumbent Telecom / ~26M+ Subscribers)  
> **Balance USSD / SMS:** Dial `*123#` (Instant balance) or send SMS `TL` to `9333` | **Recharge USSD:** Dial `*9333#` or `*100#` | **Account App:** Türk Telekom Online İşlemler  
> **Customer Care:** `500` (From Türk Telekom) / `444 1 500` / `+905005000500`  
> **Regulatory Policy (BTK Turkey):** 184 Days (6 Months) Active Period from last recharge | 92 Days Passive / Inactive Period (Kısıtlı Süreç) before permanent contract termination & recycling (Total 276 days) | Subject to monthly Wireless Usage Fee (*Telsiz Kullanım Ücreti*) and 10% ÖİV Special Communication Tax  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `TUR` (ISO-3) | `TR` (ISO-2) | `TR` (ISO-2) | `TR` (ISO-2) |
| **Carrier / Operator Code** | `46` ("Turk Telecom Turkey") | `510` ("Turk Telecom Turkey") / `1176` ("Turk Telecom Turkey Data") | `TurkTelekom` | `AVTR` ("Avea (Turk Telekom) Turkey") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Yalın / Mobil WiFi Bundles | Direct Airtime Top-Up & Mobil WiFi Bundles | Direct Top-Up (`TURKTELECOM_TR_004_USD`) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** (3% International Discount) | **`USD`** | **`OMR`** |
| **Catalog Format** | 20 Fixed Products (300–2000 TRY) | 4 Airtime (300–750 TRY) + 6 Data Bundles (420–1350 TRY) | 1 Fixed Offer (300 TRY) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (TRY) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`AVTR`) |
| :---: | :---: | :---: | :---: | :---: |
| **300.00 TRY** (Standard Top-Up) | **3.083 OMR ($8.016 USD)** (`48513`) | **$8.41 USD ($8.157 net)** (`510`) | **$15.00 USD** (`TURKTELECOM_TR_004_USD`) | 🔴 *(0 Catalog Offers)* |
| **400.00 TRY** (Standard Top-Up) | **4.111 OMR ($10.689 USD)** (`54780`) | **$11.21 USD ($10.874 net)** (`510`) | — | 🔴 *(0 Catalog Offers)* |
| **420.00 TRY** (Magnet 30GB 3 Ay) | — | **$11.77 USD ($11.417 net)** (`1176`) | — | 🔴 *(0 Catalog Offers)* |
| **460.00 TRY** (Mobil WiFi 30GB) | — | **$12.90 USD ($12.513 net)** (`1176`) | — | 🔴 *(0 Catalog Offers)* |
| **500.00 TRY** (Standard Top-Up) | **5.138 OMR ($13.359 USD)** (`54782`) | **$14.02 USD ($13.599 net)** (`510`) | — | 🔴 *(0 Catalog Offers)* |
| **635.00 TRY** (Yalın 5GB) | **6.267 OMR ($16.294 USD)** (`66783`) | — | — | 🔴 *(0 Catalog Offers)* |
| **750.00 TRY** (Standard Top-Up) | **7.707 OMR ($20.038 USD)** (`54784`) | **$21.03 USD ($20.399 net)** (`510`) | — | 🔴 *(0 Catalog Offers)* |
| **750.00 TRY** (Mobil WiFi 200GB) | **7.402 OMR ($19.245 USD)** (`63608`) | **$21.03 USD ($20.399 net)** (`1176`) | — | 🔴 *(0 Catalog Offers)* |
| **775.00 TRY** (Yalın 10GB) | **7.649 OMR ($19.887 USD)** (`66779`) | — | — | 🔴 *(0 Catalog Offers)* |
| **885.00 TRY** (Yalın 15GB) | **8.735 OMR ($22.711 USD)** (`66780`) | — | — | 🔴 *(0 Catalog Offers)* |
| **965.00 TRY** (Yalın 20GB) | **9.524 OMR ($24.762 USD)** (`66781`) | — | — | 🔴 *(0 Catalog Offers)* |
| **980.00 TRY** (Mobil WiFi 200GB 3 Ay) | **9.672 OMR ($25.147 USD)** (`63609`) | **$27.47 USD ($26.646 net)** (`1176`) | — | 🔴 *(0 Catalog Offers)* |
| **1000.00 TRY** (Standard Top-Up) | **10.276 OMR ($26.718 USD)** (`66784`) | — | — | 🔴 *(0 Catalog Offers)* |
| **1000.00 TRY** (Mobil WiFi 300GB) | **9.869 OMR ($25.659 USD)** (`63610`) | **$28.03 USD ($27.189 net)** (`1176`) | — | 🔴 *(0 Catalog Offers)* |
| **1500.00 TRY** (Standard Top-Up) | **15.414 OMR ($40.076 USD)** (`66785`) | — | — | 🔴 *(0 Catalog Offers)* |
| **2000.00 TRY** (Standard Top-Up) | **20.552 OMR ($53.435 USD)** (`66786`) | — | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `48513` (Turk Telecom 300 TRY) to `+905550000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240792690`, Wholesale Cost: `3.071 OMR` (~$7.985 USD), Delivered: `300 TRY`
* **Result:** **Primary Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Failover
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `510` (Turk Telecom Airtime 300 TRY, $8.41 USD requested) to `+905550000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178411`, Delivered: `300 TRY`, Net Wholesale Cost: `$8.1577 USD` (3% international discount applied)
* **Result:** **Secondary Direct Failover** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `TURKTELECOM_TR_004_USD` (Türk Telekom 300 TRY Top-Up) to `+905550000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `test_tr_zen_1787386165740_turktelecom_tr_004_usd`, Wholesale Cost: `$15.00 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `AVTR` ("Avea (Turk Telekom) Turkey")
* **Validation Regex:** `^90[0-9]{10}$`
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 46` — broadest catalog with 20 denominations starting from 300 TRY at **3.071 OMR / ~$7.98 USD**, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Reloadly** (`operatorId: 510` / `1176` — 300 TRY airtime at **$8.157 USD**, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: TurkTelekom` — offer `TURKTELECOM_TR_004_USD` at **$15.00 USD**, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`AVTR`, `priority: 40`, `is_enabled: false`).
5. **BTK Turkey Regulatory Compliance:**
   - Türk Telekom prepaid SIM cards (Faturasız Hat) remain active for **184 days (6 months)** from the last top-up.
   - If no recharge occurs within 184 days, the line enters a **92-day passive period** (*Kısıtlı Süreç* / Days 185–276) where outgoing calls are blocked.
   - If unrefilled after 276 days total, the subscription is permanently terminated, balance cancelled, and number recycled.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** (using a 300 TRY top-up via DT One or Reloadly) to reset the 184-day BTK active validity period indefinitely.
