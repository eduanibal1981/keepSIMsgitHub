# Provider Comparison & Test Report: Orange Tunisia

> **Country:** Tunisia (`TN` / `+216` / `TUN`)  
> **Carrier:** Orange Tunisia (Orange Group & Investec — ~27% Mobile Market Share)  
> **Network Type:** MNO (~4.1M+ Mobile Subscribers / 4G+ & 5G Ready)  
> **Balance USSD:** Dial `*111#` or `*111*1#` (Main Airtime Balance & Expiration), `*124#` (Internet Passes & Pass Mix)  
> **Recharge USSD:** Dial `*100*<PIN>#` or `*111*2*<PIN>#`  
> **Forfait / Bundle Menu:** Dial `*124#` (Pass Internet, Pass Facebook, Pass Appels)  
> **Customer Care:** `1150` (From Mobile) / `+216 31 11 11 50` | **Self-Care App:** My Orange Tunisie  
> **Regulatory Policy (INTT Tunisia):** 90 to 180-day active validity from last recharge + 90-day grace/quarantine period before permanent disconnection & number recycling | Recharges subject to 19% Tunisian TVA (VAT) + telecom royalty tax  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `TUN` (ISO-3) | `TN` (ISO-2) | `TN` (ISO-2) | `TN` (ISO-2) |
| **Carrier / Operator Code** | `1530` ("Orange Tunisia") | `506` ("Orange Tunisia") | `Orange` | `ORTN` ("Orange Tunisia") |
| **Delivery Mechanism** | Direct Airtime Top-Up & Range | Direct Airtime Top-Up (Range) | Direct Airtime Top-Up (Fixed & Range) | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 31 Fixed SKUs (1.60 to 200 TND) + Range `54628` (10–102 TND) | Range ($4.35 to $79.05 USD / 11 to 200 TND) | 35 Fixed Offers (13.52 to 128.44 TND) + Range `ORANGE_TN_OPEN` (9.19–204.35 TND) | 0 Active Products in UAT (503 RateLimited) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Direct Route** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (TND) / Description | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`ORTN`) |
| :---: | :---: | :---: | :---: | :---: |
| **1.60 TND** (Min Micro Entry) | **0.256 OMR ($0.666 USD)** (`50404`) | — | — | 🔴 *(0 Offers)* |
| **2.00 TND** (Airtime) | **0.320 OMR ($0.832 USD)** (`50405`) | — | — | 🔴 *(0 Offers)* |
| **3.00 TND** (Airtime) | **0.480 OMR ($1.248 USD)** (`50406`) | — | — | 🔴 *(0 Offers)* |
| **4.00 TND** (Airtime) | **0.640 OMR ($1.664 USD)** (`50407`) | — | — | 🔴 *(0 Offers)* |
| **4.50 TND** (Airtime) | **0.720 OMR ($1.872 USD)** (`50408`) | — | — | 🔴 *(0 Offers)* |
| **5.00 TND** (Standard Top-Up) | **0.800 OMR ($2.080 USD)** (`50409`) | — | — | 🔴 *(0 Offers)* |
| **6.00 TND** (Airtime) | **0.960 OMR ($2.496 USD)** (`50410`) | — | — | 🔴 *(0 Offers)* |
| **6.50 TND** (Airtime) | **1.040 OMR ($2.704 USD)** (`50411`) | — | — | 🔴 *(0 Offers)* |
| **7.00 TND** (Airtime) | **1.120 OMR ($2.912 USD)** (`50412`) | — | — | 🔴 *(0 Offers)* |
| **7.50 TND** (Airtime) | **1.200 OMR ($3.120 USD)** (`50413`) | — | — | 🔴 *(0 Offers)* |
| **8.00 TND** (Airtime) | **1.280 OMR ($3.328 USD)** (`50414`) | — | — | 🔴 *(0 Offers)* |
| **8.50 TND** (Airtime) | **1.360 OMR ($3.536 USD)** (`50415`) | — | — | 🔴 *(0 Offers)* |
| **9.00 TND** (Airtime) | **1.440 OMR ($3.744 USD)** (`50416`) | — | — | 🔴 *(0 Offers)* |
| **9.50 TND** (Airtime) | **1.520 OMR ($3.952 USD)** (`50417`) | — | — | 🔴 *(0 Offers)* |
| **10.00 TND** (Airtime) | **1.567 OMR ($4.074 USD)** (`25628`) | — | — | 🔴 *(0 Offers)* |
| **11.00 TND** (Airtime) | — | **$3.915 USD** (Range `506`, 10% disc) | — | 🔴 *(0 Offers)* |
| **13.52 TND** (Airtime) | — | — | **$4.77 USD** (`ORANGE_TN_001_W`) | 🔴 *(0 Offers)* |
| **15.00 TND** (Airtime) | **2.350 OMR ($6.110 USD)** (`4259`) | **$5.340 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **16.90 TND** (Airtime) | — | — | **$5.97 USD** (`ORANGE_TN_002_W`) | 🔴 *(0 Offers)* |
| **20.00 TND** (Airtime) | **3.133 OMR ($8.146 USD)** (`35767`) | **$7.120 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **20.28 TND** (Airtime) | — | — | **$7.16 USD** (`ORANGE_TN_003_W`) | 🔴 *(0 Offers)* |
| **23.66 TND** (Airtime) | — | — | **$8.35 USD** (`ORANGE_TN_004_W`) | 🔴 *(0 Offers)* |
| **25.00 TND** (Airtime) | **3.916 OMR ($10.182 USD)** (`35769`) | **$8.900 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **30.00 TND** (Airtime) | **4.699 OMR ($12.217 USD)** (`4260`) | **$10.680 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **40.00 TND** (Airtime) | **6.265 OMR ($16.289 USD)** (`36169`) | **$14.240 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **50.00 TND** (Airtime) | **7.831 OMR ($20.361 USD)** (`36173`) | **$17.800 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **60.00 TND** (Airtime) | **9.397 OMR ($24.432 USD)** (`7361`) | **$21.360 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **70.00 TND** (Airtime) | **10.963 OMR ($28.504 USD)** (`35789`) | **$24.920 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **75.00 TND** (Airtime) | **11.746 OMR ($30.540 USD)** (`36177`) | **$26.700 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **90.00 TND** (Airtime) | **14.095 OMR ($36.647 USD)** (`19268`) | **$32.040 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **100.00 TND** (Airtime) | **15.661 OMR ($40.719 USD)** (`38456`) | **$35.600 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **125.00 TND** (Airtime) | **19.576 OMR ($50.898 USD)** (`38457`) | **$44.500 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **150.00 TND** (Airtime) | **23.491 OMR ($61.077 USD)** (`40007`) | **$53.400 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **164.00 TND** (Airtime) | **25.683 OMR ($66.776 USD)** (`42518`) | — | — | 🔴 *(0 Offers)* |
| **175.00 TND** (Airtime) | **27.406 OMR ($71.256 USD)** (`40008`) | **$62.300 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **200.00 TND** (Max Airtime) | **31.321 OMR ($81.435 USD)** (`40009`) | **$71.145 USD** (Range `506`) | — | 🔴 *(0 Offers)* |
| **Range (10–102 TND)** | **1.567–15.974 OMR** (`54628`) | — | — | 🔴 *(0 Offers)* |
| **Range (9.19–204.35 TND)**| — | — | **$3.25–$72.18 USD** (`ORANGE_TN_OPEN`) | 🔴 *(0 Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `50404` (Orange Tunisia 1.6 TND Airtime) to `+21650000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793459`, Wholesale Cost: `0.259 OMR` (~$0.673 USD), Delivered: `1.60 TND` (Net after tax: 1.40 TND)
* **Test Request 2:** Product `50409` (Orange Tunisia 5 TND Airtime) to `+21650000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793461`, Wholesale Cost: `0.807 OMR` (~$2.098 USD), Delivered: `5.00 TND` (Net after tax: 4.40 TND)
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `506` (Orange Tunisia Range, $5.00 USD requested) to `+21650000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
  * **Delivered Artifact:** Transaction ID `178480`, Requested: `$5.00 USD`, Delivered: `12.65 TND`, Wholesale Cost: `$4.50 USD` (10% discount)
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Zendit (Test Environment) — 🟢 Tertiary Direct Route
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `ORANGE_TN_001_W` (Orange Tunisia 13.52 TND Topup) to `+21650000101`
  * **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
  * **Delivered Artifact:** Transaction ID `zen_tun_1787439190026_ORANGE_TN_001_W`
* **Result:** **Tertiary Direct Route** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `ORTN` ("Orange Tunisia")
* **Catalog Status:** Returns `503 RateLimited / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1530` — delivers direct micro-recharges starting at **1.60 TND** for **0.259 OMR** (~$0.673 USD), 31 fixed denominations up to 200 TND, and range `54628` (10–102 TND) with instant pre-prod confirmation, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **Reloadly** (`operatorId: 506` — flexible range from $4.35 to $79.05 USD / 11–200 TND with attractive 10% discount, `priority: 20`).
3. **Tertiary Direct Route:** **Zendit** (`brand: Orange` — 35 fixed offers + open range `ORANGE_TN_OPEN`, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`ORTN`, `priority: 40`) due to 0 active UAT catalog inventory.
5. **INTT Tunisia Regulatory Compliance & Mini-Refill Strategy:**
   - Orange Tunisia prepaid lines require a qualifying recharge at least once every **90 to 180 days** to preserve line active status.
   - Upon expiry, the line enters a **90-day grace/quarantine period** with incoming calls and SMS only.
   - If no recharge occurs before the end of the grace period, the SIM is permanently disconnected, remaining credit is forfeited, and the number is recycled.
   - **KeepSIMs Automated Action:** Schedules automated mini-refills on **Day 60–80** (delivering 1.60 TND for `0.259 OMR` / ~$0.673 USD via DT One) to maintain uninterrupted line life.
