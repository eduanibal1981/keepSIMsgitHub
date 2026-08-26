# Provider Comparison & Test Report: Pttcell Turkey

> **Country:** Turkey (`TR` / `+90` / `TUR`)  
> **Carrier:** Pttcell (`Pttcell` / PTT - Posta ve Telgraf Teşkilatı A.Ş.)  
> **Network Type:** MVNO / Postal Digital Brand (Host Network: Türk Telekom / TT Mobil)  
> **Balance USSD / SMS:** Dial `*123#` (Instant balance) or send SMS `TL` to `9333` | **Recharge USSD:** Dial `*9333#` | **Account Portal:** pttcell.com.tr / Türk Telekom Online İşlemler  
> **Customer Care:** `444 1 788` / `+904441788`  
> **Regulatory Policy (BTK Turkey):** 184 Days Active Period from last recharge (aligned with host Türk Telekom) | 92 Days Passive / Inactive Period before permanent cancellation (Total 276 days) | Subject to monthly Wireless Usage Fee (*Telsiz Kullanım Ücreti*)  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `TUR` (ISO-3) | `TR` (ISO-2) | `TR` (ISO-2) | `TR` (ISO-2) |
| **Carrier / Operator Code** | `46` (via Türk Telekom rails) | `510` (via Türk Telekom rails) | `TurkTelekom` (via TT rails) | `AVTR` (via TT rails) |
| **Delivery Mechanism** | Direct Airtime Top-Up via Host Network | Direct Airtime Top-Up via Host Network | Direct Top-Up via Host Network | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** (3% International Discount) | **`USD`** | **`OMR`** |
| **Catalog Format** | 20 Fixed Products (300–2000 TRY) | 4 Airtime (300–750 TRY) | 1 Fixed Offer (300 TRY) | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (TRY) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`AVTR`) |
| :---: | :---: | :---: | :---: | :---: |
| **300.00 TRY** (Standard Top-Up) | **3.083 OMR ($8.016 USD)** (`48513`) | **$8.41 USD ($8.157 net)** (`510`) | **$15.00 USD** (`TURKTELECOM_TR_004_USD`) | 🔴 *(0 Catalog Offers)* |
| **400.00 TRY** (Standard Top-Up) | **4.111 OMR ($10.689 USD)** (`54780`) | **$11.21 USD ($10.874 net)** (`510`) | — | 🔴 *(0 Catalog Offers)* |
| **500.00 TRY** (Standard Top-Up) | **5.138 OMR ($13.359 USD)** (`54782`) | **$14.02 USD ($13.599 net)** (`510`) | — | 🔴 *(0 Catalog Offers)* |
| **750.00 TRY** (Standard Top-Up) | **7.707 OMR ($20.038 USD)** (`54784`) | **$21.03 USD ($20.399 net)** (`510`) | — | 🔴 *(0 Catalog Offers)* |
| **1000.00 TRY** (Standard Top-Up) | **10.276 OMR ($26.718 USD)** (`66784`) | — | — | 🔴 *(0 Catalog Offers)* |
| **1500.00 TRY** (Standard Top-Up) | **15.414 OMR ($40.076 USD)** (`66785`) | — | — | 🔴 *(0 Catalog Offers)* |
| **2000.00 TRY** (Standard Top-Up) | **20.552 OMR ($53.435 USD)** (`66786`) | — | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `48513` (Türk Telekom Rails 300 TRY) to `+905050000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240792690`, Wholesale Cost: `3.071 OMR` (~$7.985 USD), Delivered: `300 TRY`
* **Result:** **Primary Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Failover
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `510` (Türk Telekom Rails 300 TRY) to `+905050000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178411`, Delivered: `300 TRY`, Net Wholesale Cost: `$8.1577 USD`
* **Result:** **Secondary Direct Failover** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Failover
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `TURKTELECOM_TR_004_USD` (Türk Telekom Rails 300 TRY) to `+905050000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Transaction Reference:** `test_tr_zen_1787386165740_turktelecom_tr_004_usd`, Wholesale Cost: `$15.00 USD`
* **Result:** **Tertiary Direct Failover** (`priority: 30`).

---

## 4. KeepSIMs Production Routing Decision

1. **Host Network Compatibility:** Pttcell lines run on Türk Telekom (TT Mobil) core network infrastructure and accept standard Türk Telekom airtime top-ups.
2. **Primary Direct Route:** **DT One** (`operatorId: 46` via Türk Telekom rails, `priority: 10`, `is_primary: true`).
3. **Secondary Direct Failover:** **Reloadly** (`operatorId: 510`, `priority: 20`).
4. **Tertiary Direct Failover:** **Zendit** (`brand: TurkTelekom`, `priority: 30`).
5. **BTK Regulatory Compliance:** Line validity follows host Türk Telekom 184-day active period + 92-day grace period. Automated mini-refill triggers on **Day 150–165**.
