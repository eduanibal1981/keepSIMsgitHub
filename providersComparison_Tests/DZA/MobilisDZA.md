# Provider Comparison & Test Report: Mobilis (ATM Mobilis)

> **Country:** Algeria (`DZ` / `+213` / `DZA`)  
> **Carrier:** Mobilis (ATM Mobilis / Algérie Télécom — State-Owned Incumbent Market Leader)  
> **Network Type:** MNO (~43% Market Share / ~20M+ Subscribers / Prepaid Brands: **PixX, Mobitas, Gosto, Win**)  
> **Balance USSD:** Dial `*222#` (Main Airtime Balance), `*600#` (PixX Plan & Data Balance), `*111#` (Self-Care Portal)  
> **Recharge USSD:** Dial `*111*<PIN>#` or `*222*<PIN>#` (Direct Voucher Refill)  
> **Customer Care:** `666` (From Mobilis) / `+213 23 92 13 13` / `0660 600 666` | **Self-Care App:** MobiSpace  
> **Regulatory Policy (ARPCE Algeria):** 60 to 90-day active validity from last recharge + 90-day grace/suspension period before permanent disconnection & number recycling | Recharges include 19% Algerian TVA (VAT) in retail pricing  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Zendit** (`zendit`) | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DZ` (ISO-2) | `DZA` (ISO-3) | `DZ` (ISO-2) | `DZ` (ISO-2) |
| **Carrier / Operator Code** | `MOBILIS` | `4` ("Mobilis Algeria") | `6` ("Mobilis Algeria") | `MDDZ` ("Mobilis Algeria") |
| **Delivery Mechanism** | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`OMR`** |
| **Catalog Format** | 10 Fixed Offers (`MOBILIS_DZ_01` to `MOBILIS_DZ_10` / 100 to 2000 DZD) | 10 Fixed Products (`14299` to `14307`, `14488` / 100 to 2000 DZD) | 10 Fixed Amounts (100 to 2000 DZD / $0.97 to $19.37 USD) | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Direct Route** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (DZD) / Description | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | DingConnect Direct (`MDDZ`) |
| :---: | :---: | :---: | :---: | :---: |
| **100.00 DZD** (Min Entry Airtime) | **$0.71 USD** (`MOBILIS_DZ_01`) | **0.296 OMR ($0.770 USD)** (`14299`) | **$0.97 USD** ($0.9215 net) (`6`) | 🔴 *(0 Offers)* |
| **200.00 DZD** (Standard Airtime) | **$1.41 USD** (`MOBILIS_DZ_02`) | **0.591 OMR ($1.537 USD)** (`14300`) | **$1.94 USD** ($1.843 net) (`6`) | 🔴 *(0 Offers)* |
| **300.00 DZD** (Standard Airtime) | **$2.13 USD** (`MOBILIS_DZ_03`) | **0.886 OMR ($2.304 USD)** (`14301`) | **$2.91 USD** ($2.764 net) (`6`) | 🔴 *(0 Offers)* |
| **375.00 DZD** (Promo Refill) | **$2.65 USD** (`MOBILIS_DZ_05`) | **1.107 OMR ($2.878 USD)** (`14488`) | **$3.63 USD** ($3.448 net) (`6`) | 🔴 *(0 Offers)* |
| **400.00 DZD** (Standard Airtime) | **$2.83 USD** (`MOBILIS_DZ_06`) | **1.181 OMR ($3.071 USD)** (`14302`) | **$3.87 USD** ($3.676 net) (`6`) | 🔴 *(0 Offers)* |
| **500.00 DZD** (Standard Airtime) | **$3.54 USD** (`MOBILIS_DZ_07`) | **1.476 OMR ($3.838 USD)** (`14303`) | **$4.84 USD** ($4.598 net) (`6`) | 🔴 *(0 Offers)* |
| **750.00 DZD** (Standard Airtime) | **$5.31 USD** (`MOBILIS_DZ_08`) | **2.214 OMR ($5.756 USD)** (`14304`) | **$7.26 USD** ($6.897 net) (`6`) | 🔴 *(0 Offers)* |
| **1,000.00 DZD** (PixX / Standard) | **$7.08 USD** (`MOBILIS_DZ_09`) | **2.952 OMR ($7.675 USD)** (`14305`) | **$9.68 USD** ($9.196 net) (`6`) | 🔴 *(0 Offers)* |
| **1,500.00 DZD** (Standard Airtime) | **$10.62 USD** (`MOBILIS_DZ_10`)| **4.428 OMR ($11.513 USD)** (`14306`) | **$14.53 USD** ($13.80 net) (`6`) | 🔴 *(0 Offers)* |
| **2,000.00 DZD** (Max Airtime) | **$14.17 USD** (`MOBILIS_DZ_04`)| **5.904 OMR ($15.350 USD)** (`14307`) | **$19.37 USD** ($18.40 net) (`6`) | 🔴 *(0 Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Zendit (Sandbox API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `MOBILIS_DZ_01` (100 DZD Airtime, $0.71 USD wholesale) to `+213660000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Delivered Artifact:** Transaction ID `zen_dz_test_1787439216175_mobilis`, Wholesale Cost: `$0.71 USD`, Delivered: `100.65 DZD nominal`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `14299` (Mobilis Algeria 100 DZD Airtime) to `+213660000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793465`, Wholesale Cost: `0.296 OMR` (~$0.770 USD), Delivered: `100 DZD nominal`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Reloadly (Sandbox API) — 🟢 Tertiary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `6` (Mobilis Algeria, $0.97 USD fixed) to `+213660000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178486`, Delivered: `100 DZD`, Wholesale Cost: `$0.9215 USD` (5% discount applied from $0.97 USD)
* **Result:** **Tertiary Direct Route** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `MDDZ` ("Mobilis Algeria")
* **Catalog Status:** Returns `503 RateLimited / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **Zendit** (`brand: MOBILIS`, offer `MOBILIS_DZ_01` — delivers 100 DZD for **$0.71 USD** wholesale, providing the lowest entry price and micro-refill cost, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **DT One** (`operatorId: 4` — delivers 100 DZD for `0.296 OMR` / ~$0.770 USD up to 2000 DZD with instant pre-prod confirmation, `priority: 20`).
3. **Tertiary Direct Route:** **Reloadly** (`operatorId: 6` — reliable tertiary direct failover across 10 fixed denomination tiers from $0.9215 USD net, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`MDDZ`, `priority: 40`) due to 0 active UAT inventory.
5. **ARPCE Algeria Regulatory Compliance & Mini-Refill Strategy:**
   - Mobilis prepaid lines maintain active validity for **60 to 90 days** from the last top-up event.
   - When the active window expires, the line enters a **90-day grace/suspension period** (receiving incoming calls/SMS only).
   - If no recharge occurs before the grace period elapses, the SIM card is permanently terminated, remaining balance is forfeited, and the number is recycled.
   - **KeepSIMs Automated Action:** Schedules automated mini-refills on **Day 50–75** (delivering 100 DZD for **$0.71 USD** via Zendit or `0.296 OMR` via DT One) to perpetually protect Algerian Mobilis SIMs from disconnection.
