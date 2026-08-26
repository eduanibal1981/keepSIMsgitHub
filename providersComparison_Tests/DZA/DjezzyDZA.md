# Provider Comparison & Test Report: Djezzy (Optimum Telecom Algeria)

> **Country:** Algeria (`DZ` / `+213` / `DZA`)  
> **Carrier:** Djezzy (Optimum Telecom Algeria / FNI — Major National Operator)  
> **Network Type:** MNO (~32% Market Share / ~15M+ Mobile Subscribers / Prepaid Brands: **Hayla, Djezzy Special, Hadra, Play**)  
> **Balance USSD:** Dial `*710#` (Main Airtime Balance), `*707#` (Special/Hayla Offers), `*720#` (Data & Internet Menu)  
> **Recharge USSD:** Dial `*700*<PIN>#` or `*710*<PIN>#` (Direct Voucher Refill)  
> **Customer Care:** `777` (From Djezzy) / `+213 770 850 005` / `0770 850 000` | **Self-Care App:** Djezzy App  
> **Regulatory Policy (ARPCE Algeria):** 60 to 90-day active validity from last recharge + 90-day grace/suspension period before permanent disconnection & number recycling | Recharges include 19% Algerian TVA (VAT) in retail pricing  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Zendit** (`zendit`) | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DZ` (ISO-2) | `DZA` (ISO-3) | `DZ` (ISO-2) | `DZ` (ISO-2) |
| **Carrier / Operator Code** | `DJEZZY` | `2074` ("Djezzy Algeria") | `8` ("Djezzy Algeria") | `DJDZ` ("Djezzy Algeria") |
| **Delivery Mechanism** | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Airtime Top-Up | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`OMR`** |
| **Catalog Format** | 10 Fixed Offers (`DJEZZY_DZ_01` to `DJEZZY_DZ_10` / 100 to 2000 DZD) | 10 Fixed Products (`14308` to `14316`, `14487` / 100 to 2000 DZD) | 4 Fixed Amounts (500 to 2000 DZD / $4.84 to $19.37 USD) | 0 Active Products in UAT (503 response) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Route** (`priority: 20`) | 🟢 **Tertiary Direct Route** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (DZD) / Description | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD`) / Op ID | DingConnect Direct (`DJDZ`) |
| :---: | :---: | :---: | :---: | :---: |
| **100.00 DZD** (Min Entry Airtime) | **$0.71 USD** (`DJEZZY_DZ_01`) | **0.296 OMR ($0.770 USD)** (`14308`) | — | 🔴 *(0 Offers)* |
| **200.00 DZD** (Standard Airtime) | **$1.41 USD** (`DJEZZY_DZ_02`) | **0.591 OMR ($1.537 USD)** (`14309`) | — | 🔴 *(0 Offers)* |
| **300.00 DZD** (Standard Airtime) | **$2.13 USD** (`DJEZZY_DZ_03`) | **0.886 OMR ($2.304 USD)** (`14310`) | — | 🔴 *(0 Offers)* |
| **375.00 DZD** (Promo Refill) | **$2.65 USD** (`DJEZZY_DZ_05`) | **1.107 OMR ($2.878 USD)** (`14487`) | — | 🔴 *(0 Offers)* |
| **400.00 DZD** (Standard Airtime) | **$2.83 USD** (`DJEZZY_DZ_06`) | **1.181 OMR ($3.071 USD)** (`14311`) | — | 🔴 *(0 Offers)* |
| **500.00 DZD** (Standard Airtime) | **$3.54 USD** (`DJEZZY_DZ_07`) | **1.476 OMR ($3.838 USD)** (`14312`) | **$4.84 USD** ($4.598 net) (`8`) | 🔴 *(0 Offers)* |
| **750.00 DZD** (Standard Airtime) | **$5.31 USD** (`DJEZZY_DZ_08`) | **2.214 OMR ($5.756 USD)** (`14313`) | — | 🔴 *(0 Offers)* |
| **1,000.00 DZD** (Hayla / Standard) | **$7.08 USD** (`DJEZZY_DZ_09`) | **2.952 OMR ($7.675 USD)** (`14314`) | **$9.68 USD** ($9.196 net) (`8`) | 🔴 *(0 Offers)* |
| **1,500.00 DZD** (Standard Airtime) | **$10.62 USD** (`DJEZZY_DZ_10`)| **4.428 OMR ($11.513 USD)** (`14315`) | **$14.53 USD** ($13.80 net) (`8`) | 🔴 *(0 Offers)* |
| **2,000.00 DZD** (Max Airtime) | **$14.17 USD** (`DJEZZY_DZ_04`)| **5.904 OMR ($15.350 USD)** (`14316`) | **$19.37 USD** ($18.40 net) (`8`) | 🔴 *(0 Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Zendit (Sandbox API) — 🟢 Primary Direct Route
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `DJEZZY_DZ_01` (100 DZD Airtime, $0.71 USD wholesale) to `+213770000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Delivered Artifact:** Transaction ID `zen_dz_test_1787439218319_djezzy`, Wholesale Cost: `$0.71 USD`, Delivered: `100.65 DZD nominal`
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API) — 🟢 Secondary Direct Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `14308` (Djezzy Algeria 100 DZD Airtime) to `+213770000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793467`, Wholesale Cost: `0.296 OMR` (~$0.770 USD), Delivered: `100 DZD nominal`
* **Result:** **Secondary Direct Route** (`priority: 20`).

### 3. Reloadly (Sandbox API) — 🟢 Tertiary Direct Route
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `8` (Djezzy Algeria 500 DZD, $4.84 USD fixed) to `+213770000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178488`, Delivered: `500 DZD`, Wholesale Cost: `$4.598 USD` (5% discount applied from $4.84 USD)
* **Result:** **Tertiary Direct Route** (`priority: 30`).

### 4. DingConnect (UAT Environment) — 🔴 Disabled Route
* **Provider Code:** `DJDZ` ("Djezzy Algeria")
* **Catalog Status:** Returns `503 RateLimited / 0 active products` in UAT.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **Zendit** (`brand: DJEZZY`, offer `DJEZZY_DZ_01` — delivers 100 DZD for **$0.71 USD** wholesale, offering full coverage from 100 to 2000 DZD, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Route:** **DT One** (`operatorId: 2074` — delivers 100 DZD for `0.296 OMR` / ~$0.770 USD up to 2000 DZD with instant pre-prod confirmation, `priority: 20`).
3. **Tertiary Direct Route:** **Reloadly** (`operatorId: 8` — secondary fallback starting at 500 DZD from $4.598 USD net, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`DJDZ`, `priority: 40`) due to 0 active UAT inventory.
5. **ARPCE Algeria Regulatory Compliance & Mini-Refill Strategy:**
   - Djezzy prepaid lines maintain active validity for **60 to 90 days** from the last top-up event.
   - When the active window expires, the line enters a **90-day grace/suspension period** (receiving incoming calls/SMS only).
   - If no recharge occurs before the grace period elapses, the SIM card is permanently terminated, remaining balance is forfeited, and the number is recycled.
   - **KeepSIMs Automated Action:** Schedules automated mini-refills on **Day 50–75** (delivering 100 DZD for **$0.71 USD** via Zendit or `0.296 OMR` via DT One) to perpetually protect Algerian Djezzy SIMs from disconnection.
