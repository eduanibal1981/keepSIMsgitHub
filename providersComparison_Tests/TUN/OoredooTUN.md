# Provider Comparison & Test Report: Ooredoo Tunisia

> **Country:** Tunisia (`TN` / `+216` / `TUN`)  
> **Carrier:** Ooredoo Tunisia (formerly Tunisiana — Private Market Leader, ~42% Mobile Market Share)  
> **Network Type:** MNO (~5.3M+ Mobile Subscribers / Ooredoo Group)  
> **Balance USSD:** Dial `*100#` (Main Account Balance & Expiration), `*100*1#` (Detailed Balance), `*124#` (Internet & Forfait Balance)  
> **Recharge USSD:** Dial `*101*<PIN>#` or `*100*2*<PIN>#`  
> **Forfait / Bundle Menu:** Dial `*124#` (Internet 4G Passes & Combo Bundles)  
> **Customer Care:** `1111` (From Ooredoo) / `+216 22 11 11 11` | **Self-Care App:** My Ooredoo Tunisie  
> **Regulatory Policy (INTT Tunisia):** 90 to 180-day active validity from last recharge + 90-day grace/quarantine period before permanent disconnection & number recycling | Recharges subject to 19% Tunisian TVA (VAT) + telecom royalty tax  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `TUN` (ISO-3) | `TN` (ISO-2) | `TN` (ISO-2) | `TN` (ISO-2) |
| **Carrier / Operator Code** | `1532` ("Ooredoo Tunisia") | `508` ("Ooredoo Tunisia") | `Ooredoo` | `TUTN` ("Ooredoo (Tunisiana) Tunisia") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Range | Direct Airtime Top-Up (Range) | Direct Airtime Top-Up (Fixed) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 33 Fixed SKUs (2 to 60 TND) + Range `11905` (2–150 TND) | Range ($0.93 to $70.09 USD / 2 to 150 TND) | 7 Fixed Offers (5, 13, 15, 23, 42, 60, 75 TND) | 0 Active Products in UAT (503 RateLimited) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Direct Route** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (TND) / Description | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`TUTN`) |
| :---: | :---: | :---: | :---: | :---: |
| **2.00 TND** (Min Micro Entry) | **0.325 OMR ($0.845 USD)** (`6095`) | **$0.95 USD** (Range `508`, 5% discount) | — | 🔴 *(0 Offers)* |
| **3.00 TND** (Airtime) | **0.487 OMR ($1.266 USD)** (`6096`) | **$1.425 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **4.00 TND** (Airtime) | **0.649 OMR ($1.687 USD)** (`6097`) | **$1.90 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **5.00 TND** (Standard Top-Up) | **0.811 OMR ($2.109 USD)** (`4054`) | **$2.375 USD** (Range `508`) | **$1.89 USD** (`OOREDOO_TN_001_W`) | 🔴 *(0 Offers)* |
| **6.00 TND** (Airtime) | **0.974 OMR ($2.532 USD)** (`6098`) | **$2.85 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **7.00 TND** (Airtime) | **1.136 OMR ($2.954 USD)** (`6099`) | **$3.325 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **8.00 TND** (Airtime) | **1.298 OMR ($3.375 USD)** (`6100`) | **$3.80 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **9.00 TND** (Airtime) | **1.460 OMR ($3.796 USD)** (`6101`) | **$4.275 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **10.00 TND** (Standard Top-Up) | **1.622 OMR ($4.217 USD)** (`4055`) | **$4.75 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **11.00 TND** (Airtime) | **1.785 OMR ($4.641 USD)** (`6102`) | **$5.225 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **12.00 TND** (Airtime) | **1.947 OMR ($5.062 USD)** (`6103`) | **$5.70 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **13.00 TND** (Airtime) | **2.109 OMR ($5.483 USD)** (`6104`) | **$6.175 USD** (Range `508`) | **$4.73 USD** (`OOREDOO_TN_002_W`) | 🔴 *(0 Offers)* |
| **14.00 TND** (Airtime) | **2.271 OMR ($5.905 USD)** (`6105`) | **$6.65 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **15.00 TND** (Airtime) | **2.433 OMR ($6.326 USD)** (`6106`) | **$7.125 USD** (Range `508`) | **$5.69 USD** (`OOREDOO_TN_003_W`) | 🔴 *(0 Offers)* |
| **16.00 TND** (Airtime) | **2.596 OMR ($6.750 USD)** (`6107`) | **$7.60 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **17.00 TND** (Airtime) | **2.758 OMR ($7.171 USD)** (`6108`) | **$8.075 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **18.00 TND** (Airtime) | **2.920 OMR ($7.592 USD)** (`6109`) | **$8.55 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **19.00 TND** (Airtime) | **3.082 OMR ($8.013 USD)** (`6110`) | **$9.025 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **20.00 TND** (Standard Top-Up) | **3.244 OMR ($8.434 USD)** (`4056`) | **$9.50 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **21.00 TND** (Airtime) | **3.407 OMR ($8.858 USD)** (`6111`) | **$9.975 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **22.00 TND** (Airtime) | **3.569 OMR ($9.279 USD)** (`6112`) | **$10.45 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **23.00 TND** (Airtime) | **3.731 OMR ($9.701 USD)** (`6113`) | **$10.925 USD** (Range `508`) | **$8.69 USD** (`OOREDOO_TN_004_W`) | 🔴 *(0 Offers)* |
| **24.00 TND** (Airtime) | **3.893 OMR ($10.122 USD)** (`6114`) | **$11.40 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **25.00 TND** (Airtime) | **4.055 OMR ($10.543 USD)** (`6115`) | **$11.875 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **26.00 TND** (Airtime) | **4.218 OMR ($10.967 USD)** (`6116`) | **$12.35 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **27.00 TND** (Airtime) | **4.380 OMR ($11.388 USD)** (`6117`) | **$12.825 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **28.00 TND** (Airtime) | **4.542 OMR ($11.809 USD)** (`6118`) | **$13.30 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **29.00 TND** (Airtime) | **4.704 OMR ($12.230 USD)** (`6119`) | **$13.775 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **30.00 TND** (Airtime) | **4.866 OMR ($12.652 USD)** (`6120`) | **$14.25 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **31.00 TND** (Airtime) | **5.029 OMR ($13.075 USD)** (`37235`) | **$14.725 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **40.00 TND** (Airtime) | **6.488 OMR ($16.869 USD)** (`6121`) | **$19.00 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **42.00 TND** (Airtime) | — | — | **$15.86 USD** (`OOREDOO_TN_005_W`) | 🔴 *(0 Offers)* |
| **50.00 TND** (Airtime) | **8.110 OMR ($21.086 USD)** (`6122`) | **$23.75 USD** (Range `508`) | — | 🔴 *(0 Offers)* |
| **60.00 TND** (Airtime) | **9.732 OMR ($25.303 USD)** (`6123`) | **$28.50 USD** (Range `508`) | **$22.66 USD** (`OOREDOO_TN_006_W`) | 🔴 *(0 Offers)* |
| **75.00 TND** (Max Fixed) | — | **$35.625 USD** (Range `508`) | **$28.30 USD** (`OOREDOO_TN_007_W`) | 🔴 *(0 Offers)* |
| **Open Range (2–150 TND)** | **0.325–24.330 OMR** (`11905`) | **$0.93–$70.09 USD** (`508`) | — | 🔴 *(0 Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `6095` (Ooredoo Tunisia 2 TND Airtime) to `+21620000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793454`, Wholesale Cost: `0.325 OMR` (~$0.845 USD), Delivered: `2.00 TND` (Net after tax: 1.70 TND)
* **Test Request 2:** Product `4054` (Ooredoo Tunisia 5 TND Airtime) to `+21620000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793455`, Wholesale Cost: `0.811 OMR` (~$2.109 USD), Delivered: `5.00 TND` (Net after tax: 4.40 TND)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `508` (Ooredoo Tunisia Range, $1.00 USD requested) to `+21620000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178477`, Requested: `$1.00 USD`, Delivered: `2.14 TND`, Wholesale Cost: `$0.95 USD` (5% discount)
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Route
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `OOREDOO_TN_001_W` (Ooredoo 5 TND Topup) to `+21620000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
  * **Delivered Artifact:** Transaction ID `zen_tun_1787439186151_OOREDOO_TN_001_W`
* **Result:** **Tertiary Direct Route** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `TUTN` ("Ooredoo (Tunisiana) Tunisia")
* **Catalog Status:** Returns `503 RateLimited / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1532` — provides direct micro-recharges starting at **2.00 TND** for **0.325 OMR** (~$0.845 USD) and full open range `11905` up to 150 TND with instant pre-prod confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 508` — flexible range from $0.93 to $70.09 USD / 2–150 TND with 5% discount, `priority: 20`).
3. **Tertiary Direct Route:** **Zendit** (`brand: Ooredoo` — 7 fixed denominations from 5 TND @ $1.89 USD wholesale, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`TUTN`, `priority: 40`) due to 0 active UAT catalog inventory.
5. **INTT Tunisia Regulatory Compliance & Mini-Refill Strategy:**
   - Ooredoo Tunisia prepaid lines have an active validity period of **90 to 180 days** from the date of the last qualifying recharge.
   - Upon expiration, the SIM enters a **90-day grace/quarantine window** (incoming calls/SMS only).
   - If no recharge occurs before the end of the grace period, the SIM is permanently terminated, remaining balance is forfeited, and the number is recycled into the national pool.
   - **KeepSIMs Automated Action:** Schedules automated mini-refills on **Day 60–80** (delivering 2 TND for `0.325 OMR` / ~$0.845 USD via DT One) to seamlessly extend the 180-day INTT active window.
