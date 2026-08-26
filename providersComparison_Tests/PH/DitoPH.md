# Provider Comparison & Test Report: DITO Telecommunity Philippines

> **Country:** Philippines (`PH` / `+63` / `PHL`)  
> **Carrier:** DITO Telecommunity Corporation (`DITO` / 3rd Telco MNO)  
> **Network Type:** MNO (Next-Gen Pure 4G/5G All-VoLTE Network)  
> **Balance USSD / SMS:** Dial `*185#` (USSD Menu) or check via DITO App  
> **Customer Care:** `185` (DITO Mobile) / `(02) 8888-3486` / `+63288883486`  
> **Regulatory Policy (NTC/DICT):** 1-Year (365 Days) Load Validity | 90 Days Low/Zero-Balance Disconnection Threshold  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Zendit** (`zendit`) | **Reloadly** (`reloadly`) | **DT One** (`dtone`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `PH` (ISO-2) | `PH` (ISO-2) | `PHL` (ISO-3) | `PH` (ISO-2) |
| **Carrier / Operator Code** | `Dito` | `1182` ("Dito Philippines") / `1183` (Bundles) | Unsupported in Pre-Prod | `DWPH` ("Dito Philippines") |
| **Delivery Mechanism** | Digital Airtime & Data Packs | Direct Airtime & Bundles (Sandbox Disabled) | Unsupported | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`USD`** | **`USD`** | **`OMR`** | **`OMR`** |
| **Catalog Format** | 4 Fixed Offers (200–1000 PHP) | Fixed (99–999 PHP) | 0 Products | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🔴 **Secondary Failover** (`is_enabled: false`, `priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (PHP) | Zendit Wholesale (`USD`) / Offer ID | Reloadly Wholesale (`USD`) / Op ID | DT One Wholesale (`OMR` / `USD`) | DingConnect Direct (`DWPH`) |
| :---: | :---: | :---: | :---: | :---: |
| **99.00 PHP** (DITO Data Pack) | — | $1.81 USD (`1183` 99 PHP) | 🔴 *(Unsupported)* | 🔴 *(0 Catalog Offers)* |
| **199.00 PHP** (DITO 25GB) | — | $3.64 USD (`1183` 199 PHP) | 🔴 *(Unsupported)* | 🔴 *(0 Catalog Offers)* |
| **200.00 PHP** (Main Airtime) | **$4.52 USD** (`DITO_PH_001`) | — | 🔴 *(Unsupported)* | 🔴 *(0 Catalog Offers)* |
| **299.00 PHP** (DITO 28-Day) | — | $5.48 USD (`1183` 299 PHP) | 🔴 *(Unsupported)* | 🔴 *(0 Catalog Offers)* |
| **300.00 PHP** (Main Airtime) | **$6.67 USD** (`DITO_PH_002`) | — | 🔴 *(Unsupported)* | 🔴 *(0 Catalog Offers)* |
| **499.00 PHP** (DITO 55GB) | — | $9.14 USD (`1183` 499 PHP) | 🔴 *(Unsupported)* | 🔴 *(0 Catalog Offers)* |
| **500.00 PHP** (Main Airtime) | **$11.08 USD** (`DITO_PH_003`) | — | 🔴 *(Unsupported)* | 🔴 *(0 Catalog Offers)* |
| **999.00 PHP** (DITO 120GB) | — | $18.30 USD (`1183` 999 PHP) | 🔴 *(Unsupported)* | 🔴 *(0 Catalog Offers)* |
| **1000.00 PHP** (Main Airtime) | **$22.15 USD** (`DITO_PH_004`) | — | 🔴 *(Unsupported)* | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `DITO_PH_001` (200 PHP / $4.52 USD) to `+639910000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED` (Confirmed)
* **Transaction Reference:** `test_ph_zen_dito_1787360733692`
* **Result:** **Exclusive Active Primary Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API)
* **Operator Mapping:** Operator `1182` ("Dito Philippines") & `1183` ("Dito Philippines Bundles")
* **Status:** `409 Conflict` $\rightarrow$ `OPERATOR_UNAVAILABLE_OR_CURRENTLY_INACTIVE` in sandbox.
* **Result:** **Disabled in Sandbox** (`is_enabled: false`, `priority: 20`). Ready for production mapping.

### 3. DT One (Pre-Production API)
* **Status:** 0 products cataloged in pre-production environment.
* **Result:** **Unsupported Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment)
* **Provider Code:** `DWPH` ("Dito Philippines")
* **Catalog Status:** Returns `ResultCode: 3` (0 active inventory in UAT).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **Zendit** (`brand: Dito` — 4 core airtime offers from 200 PHP / $4.52 USD, live transaction simulation accepted, `priority: 10`, `is_primary: true`).
2. **Secondary Failover (Production):** **Reloadly** (`operatorId: 1182` / `1183` — ready for activation in production once operator flag is enabled, `priority: 20`).
3. **Disabled Providers:** **DT One** (`priority: 30`) and **DingConnect** (`DWPH`, `priority: 40`).
4. **NTC / DICT & DITO Regulatory Rules:**
   - DITO adheres to the NTC 1-year load validity requirement for purchased load amounts.
   - **Crucial DITO Caveat:** DITO enforces an aggressive **90-day deactivation policy** if the main balance remains below **PHP 1.00** with no active promo/data package.
   - KeepSIMs configures automated refills on **Day 80–85** for DITO SIMs to prevent premature line disconnection and permanent mobile number forfeitures.
