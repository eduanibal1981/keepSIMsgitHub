# Provider Comparison & Test Report: Zain Bahrain

> **Country:** Bahrain (`BH` / `+973` / `BHR`)  
> **Carrier:** Zain Bahrain B.S.C. (`Zain Bahrain` / Zain Group)  
> **Network Type:** MNO (National Mobile Network Operator)  
> **Balance USSD / SMS:** Dial `*142#` (Balance & validity enquiry) | **Recharge USSD:** Dial `*141*<PIN>#` or via Zain App | **Account App:** Zain Bahrain App  
> **Customer Care:** `107` (Local) / `+973 3779 7995` / `+973 3600 7107` (International)  
> **Regulatory Policy (TRA Bahrain):** 90 Days Inactivity Lifecycle | Direct airtime recharges extend line validity 60 to 100 days | 90 Days Suspension Grace Period before line cancellation | 10% VAT applies on prepaid services  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **DT One** (`dtone`) | **DingConnect** (`ding`) | **Zendit** (`zendit`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `BH` (ISO-2) | `BHR` (ISO-3) | `BH` (ISO-2) | `BH` (ISO-2) |
| **Carrier / Operator Code** | `1165` ("Zain Bahrain") | `1829` ("Zain Bahrain") | `ZABH` ("Zain Bahrain") | `Zain` |
| **Delivery Mechanism** | Direct Airtime Top-Up (`pin: false`) | Direct Airtime Top-Up (`FIXED_VALUE_RECHARGE`) | Direct Airtime Top-Up (Mapped) | Direct Top-Up (0 Inventory in BH) |
| **Settlement Currency** | **`USD`** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`OMR`** | **`USD`** |
| **Catalog Format** | 10 Fixed Amounts ($1.55–$76.10 USD) | 20 Fixed Airtime Products (1.00–40.50 BHD) | Provider Mapped (`ZABH`) | 0 Active Products in BH |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Top-Up** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🟢 **Tertiary Route** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (BHD) | Reloadly Wholesale (`USD`) / Op ID 1165 | DT One Wholesale (`OMR` / `USD`) / Product ID | DingConnect Direct (`ZABH`) | Zendit Direct (`Zain`) |
| :---: | :---: | :---: | :---: | :---: |
| **0.58 BHD (~$1.55 USD)** | **$1.55 USD** (`rl_1165_1.55`) | — | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **1.00 BHD** | — | **1.274 OMR ($3.31 USD)** (`58111`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **1.15 BHD (~$3.05 USD)** | **$3.05 USD** (`rl_1165_3.05`) | — | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **1.50 BHD** | — | **1.912 OMR ($4.97 USD)** (`58112`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **2.00 BHD** | — | **2.549 OMR ($6.63 USD)** (`58113`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **2.30 BHD (~$6.10 USD)** | **$6.10 USD** (`rl_1165_6.1`) | — | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **2.50 BHD** | — | **3.186 OMR ($8.28 USD)** (`58114`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **3.00 BHD** | — | **3.824 OMR ($9.94 USD)** (`58115`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **3.50 BHD** | — | **4.461 OMR ($11.60 USD)** (`58116`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **4.00 BHD** | — | **5.098 OMR ($13.25 USD)** (`58117`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **4.50 BHD** | — | **5.735 OMR ($14.91 USD)** (`58118`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **4.60 BHD (~$12.20 USD)** | **$12.20 USD** (`rl_1165_12.2`) | — | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **5.50 BHD** | — | **7.009 OMR ($18.22 USD)** (`58119`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **5.75 BHD (~$15.25 USD)** | **$15.25 USD** (`rl_1165_15.25`) | — | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **6.50 BHD** | — | **8.284 OMR ($21.54 USD)** (`58120`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **7.50 BHD** | — | **9.558 OMR ($24.85 USD)** (`58121`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **8.00 BHD** | — | **10.195 OMR ($26.51 USD)** (`58122`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **8.50 BHD** | — | **10.832 OMR ($28.16 USD)** (`58123`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **9.00 BHD** | — | **11.470 OMR ($29.82 USD)** (`58124`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **9.20 BHD (~$24.40 USD)** | **$24.40 USD** (`rl_1165_24.4`) | — | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **9.50 BHD** | — | **12.107 OMR ($31.48 USD)** (`58125`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **10.00 BHD** | — | **12.744 OMR ($33.13 USD)** (`58126`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **10.50 BHD** | — | **13.381 OMR ($34.79 USD)** (`58127`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **11.50 BHD** | — | **14.656 OMR ($38.11 USD)** (`58128`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **11.50 BHD (~$30.45 USD)** | **$30.45 USD** (`rl_1165_30.45`) | — | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **30.50 BHD** | — | **38.868 OMR ($101.06 USD)** (`58129`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |
| **40.50 BHD** | — | **51.612 OMR ($134.19 USD)** (`58130`) | 🟢 Mapped (`ZABH`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `1165` ($1.55 USD $\rightarrow$ delivered 0.58 BHD direct airtime) to `+97336000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178439`, Net Cost: `$1.55 USD`, Delivered: `0.58 BHD`, Direct Airtime Top-Up
* **Result:** **Primary Direct Top-Up Route** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `58111` (Zain Bahrain 1 BHD Airtime) to `+97336000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793390`, Wholesale Cost: `1.274 OMR` (~$3.31 USD)
* **Result:** **Secondary Direct Airtime Failover** (`priority: 20`).

### 3. DingConnect (UAT Environment)
* **Provider Code:** `ZABH` ("Zain Bahrain")
* **Validation Regex:** `^973[0-9]{7,8}$`
* **Customer Care:** `+00973 37797995`
* **Result:** **Tertiary Route** (`priority: 30`).

### 4. Zendit (Test Environment)
* **Catalog Status:** 0 active offers for brand `Zain` in Bahrain.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **Reloadly** (`operatorId: 1165` — verified direct airtime top-up delivery with ultra-low micro-recharge entry point of $1.55 USD, `priority: 10`, `is_primary: true`).
2. **Secondary Failover:** **DT One** (`operatorId: 1829` — massive catalog of 20 fixed direct recharge products from 1.00 BHD at 1.274 OMR wholesale, `priority: 20`).
3. **Tertiary Route:** **DingConnect** (`providerCode: ZABH`, `priority: 30`).
4. **Disabled Provider:** **Zendit** (`brand: Zain`, `priority: 40`, `is_enabled: false`).
5. **TRA Bahrain Regulatory Compliance:**
   - Zain Bahrain prepaid accounts operate on a **90-day activity lifecycle**.
   - Direct airtime refills extend line validity by **60 to 100 days**.
   - If no qualifying transaction occurs within 90 days, the line enters a **90-day grace/suspension period** (incoming-only calls/SMS) before permanent cancellation and recycling.
   - KeepSIMs schedules automated mini-refills on **Day 80–85** with a **$1.55 USD (0.58 BHD)** direct top-up via Reloadly to maintain active line validity seamlessly at minimal cost.
