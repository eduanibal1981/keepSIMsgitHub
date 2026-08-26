# Provider Comparison & Test Report: Ooredoo Algeria (Wataniya Télécom Algérie)

> **Country:** Algeria (`DZ` / `+213` / `DZA`)  
> **Carrier:** Ooredoo Algeria (Wataniya Télécom Algérie / Nedjma — Major High-Speed MNO)  
> **Network Type:** MNO (~25% Market Share / ~13M+ Mobile Subscribers / Prepaid Brands: **MAXY, Haya!, Dima, Sahla**)  
> **Balance USSD:** Dial `*200#` (Main Airtime Balance), `*151#` (MAXY & Haya Data Bundles), `*555#` (Services & Options)  
> **Recharge USSD:** Dial `*115*<PIN>#` or `*200*<PIN>#` (Direct Voucher Refill)  
> **Customer Care:** `333` (From Ooredoo) / `+213 554 500 507` / `0550 000 333` | **Self-Care App:** My Ooredoo Algeria  
> **Regulatory Policy (ARPCE Algeria):** 60 to 90-day active validity from last recharge + 90-day grace/suspension period before permanent disconnection & number recycling | Recharges include 19% Algerian TVA (VAT) in retail pricing  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Zendit** (`zendit`) | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DZ` (ISO-2) | `DZA` (ISO-3) | `DZ` (ISO-2) | `DZ` (ISO-2) |
| **Carrier / Operator Code** | `OOREDOO` | `2075` ("Ooredoo Algeria") | `7` ("Ooredoo Algeria") | `OODZ` ("Ooredoo Algeria") |
| **Delivery Mechanism** | Direct Airtime Top-Up | Direct Airtime Top-Up & MAXY / Data Bundles | Direct Airtime Top-Up | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`OMR`** |
| **Catalog Format** | 10 Fixed Offers (`OOREDOO_DZ_01` to `OOREDOO_DZ_10` / 100 to 2000 DZD) | 15 Products (10 Airtime 100-2000 DZD + 5 MAXY & Data Bundles) | 10 Fixed Amounts (100 to 2000 DZD / $0.97 to $19.37 USD) | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct & Bundle Route** (`priority: 20`) | 🟢 **Tertiary Direct Route** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (DZD) / Description | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | DingConnect Direct (`OODZ`) |
| :---: | :---: | :---: | :---: | :---: |
| **100.00 DZD** (Min Entry Airtime) | **$0.73 USD** (`OOREDOO_DZ_01`) | **0.296 OMR ($0.770 USD)** (`14317`) | **$0.97 USD** ($0.9215 net) (`7`) | 🔴 *(0 Offers)* |
| **100.00 DZD** (700 MB + YT 1 Day) | — | **0.307 OMR ($0.798 USD)** (`56642`) | — | 🔴 *(0 Offers)* |
| **200.00 DZD** (Standard Airtime) | **$1.46 USD** (`OOREDOO_DZ_02`) | **0.591 OMR ($1.537 USD)** (`14318`) | **$1.94 USD** ($1.843 net) (`7`) | 🔴 *(0 Offers)* |
| **300.00 DZD** (Standard Airtime) | **$2.19 USD** (`OOREDOO_DZ_03`) | **0.886 OMR ($2.304 USD)** (`14319`) | **$2.91 USD** ($2.764 net) (`7`) | 🔴 *(0 Offers)* |
| **300.00 DZD** (3 GB Data 3 Days) | — | **0.886 OMR ($2.304 USD)** (`56643`) | — | 🔴 *(0 Offers)* |
| **375.00 DZD** (Promo Refill) | **$2.73 USD** (`OOREDOO_DZ_05`) | **1.107 OMR ($2.878 USD)** (`14489`) | **$3.63 USD** ($3.448 net) (`7`) | 🔴 *(0 Offers)* |
| **400.00 DZD** (Standard Airtime) | **$2.92 USD** (`OOREDOO_DZ_06`) | **1.181 OMR ($3.071 USD)** (`14320`) | **$3.87 USD** ($3.676 net) (`7`) | 🔴 *(0 Offers)* |
| **500.00 DZD** (Standard Airtime) | **$3.65 USD** (`OOREDOO_DZ_07`) | **1.476 OMR ($3.838 USD)** (`14321`) | **$4.84 USD** ($4.598 net) (`7`) | 🔴 *(0 Offers)* |
| **500.00 DZD** (6 GB Data 30 Days) | — | **1.476 OMR ($3.838 USD)** (`56644`) | — | 🔴 *(0 Offers)* |
| **750.00 DZD** (Standard Airtime) | **$5.48 USD** (`OOREDOO_DZ_08`) | **2.214 OMR ($5.756 USD)** (`14322`) | **$7.26 USD** ($6.897 net) (`7`) | 🔴 *(0 Offers)* |
| **1,000.00 DZD** (MAXY / Standard) | **$7.30 USD** (`OOREDOO_DZ_09`) | **2.952 OMR ($7.675 USD)** (`14323`) | **$9.68 USD** ($9.196 net) (`7`) | 🔴 *(0 Offers)* |
| **1,000.00 DZD** (MAXY Internet 1000)| — | **2.952 OMR ($7.675 USD)** (`2304`) | — | 🔴 *(0 Offers)* |
| **1,500.00 DZD** (Standard Airtime) | **$10.62 USD** (`OOREDOO_DZ_10`)| **4.428 OMR ($11.513 USD)** (`14324`) | **$14.53 USD** ($13.80 net) (`7`) | 🔴 *(0 Offers)* |
| **1,500.00 DZD** (40 GB Data 30 Days)| — | **4.428 OMR ($11.513 USD)** (`56656`) | — | 🔴 *(0 Offers)* |
| **2,000.00 DZD** (Max Airtime) | **$14.60 USD** (`OOREDOO_DZ_04`)| **5.904 OMR ($15.350 USD)** (`14325`) | **$19.37 USD** ($18.40 net) (`7`) | 🔴 *(0 Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Zendit (Sandbox API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `OOREDOO_DZ_01` (100 DZD Airtime, $0.73 USD wholesale) to `+213550000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Delivered Artifact:** Transaction ID `zen_dz_test_1787439220073_ooredoo`, Wholesale Cost: `$0.73 USD`, Delivered: `100.65 DZD nominal`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API) — 🟢 Secondary Direct & Bundle Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request 1:** Product `14317` (Ooredoo Algeria 100 DZD Airtime) to `+213550000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793468`, Wholesale Cost: `0.296 OMR` (~$0.770 USD), Delivered: `100 DZD nominal`
* **Test Request 2:** Product `56642` (Ooredoo 700 MB 1 Day, 100 DZD) to `+213550000101`
  * **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
  * **Delivered Artifact:** Transaction ID `2240793469`, Wholesale Cost: `0.307 OMR` (~$0.798 USD), Delivered: `700 MB + Unlimited YouTube`
* **Result:** **Secondary Direct & Bundle Route** (`priority: 20`).

### 3. Reloadly (Sandbox API) — 🟢 Tertiary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `7` (Ooredoo Algeria 100 DZD, $0.97 USD fixed) to `+213550000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178490`, Delivered: `100 DZD`, Wholesale Cost: `$0.9215 USD` (5% discount applied from $0.97 USD)
* **Result:** **Tertiary Direct Route** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `OODZ` ("Ooredoo Algeria")
* **Catalog Status:** Returns `503 RateLimited / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **Zendit** (`brand: OOREDOO`, offer `OOREDOO_DZ_01` — delivers 100 DZD for **$0.73 USD** wholesale, providing the lowest entry price and direct delivery, `priority: 10`, `is_primary: true`).
2. **Secondary Direct & Data Route:** **DT One** (`operatorId: 2075` — delivers direct airtime from 100 DZD for `0.296 OMR` / ~$0.770 USD up to 2000 DZD, plus rich MAXY Internet and high-speed data bundles with instant pre-prod confirmation, `priority: 20`).
3. **Tertiary Direct Route:** **Reloadly** (`operatorId: 7` — reliable tertiary direct failover across 10 fixed denomination tiers from $0.9215 USD net, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`OODZ`, `priority: 40`) due to 0 active UAT inventory.
5. **ARPCE Algeria Regulatory Compliance & Mini-Refill Strategy:**
   - Ooredoo Algeria prepaid lines maintain active validity for **60 to 90 days** from the last top-up event.
   - When the active window expires, the line enters a **90-day grace/suspension period** (receiving incoming calls/SMS only).
   - If no recharge occurs before the grace period elapses, the SIM card is permanently terminated, remaining balance is forfeited, and the number is recycled.
   - **KeepSIMs Automated Action:** Schedules automated mini-refills on **Day 50–75** (delivering 100 DZD for **$0.73 USD** via Zendit or `0.296 OMR` via DT One) to perpetually protect Algerian Ooredoo SIMs from disconnection.
