# Provider Comparison & Test Report: AsiaCell Iraq

> **Country:** Iraq (`IQ` / `+964` / `IRQ`)  
> **Carrier:** AsiaCell (Ooredoo Affiliate)  
> **Network Type:** MNO (Nationwide Market Leader, HQ: Sulaymaniyah)  
> **Balance USSD:** `*133#` or `*211#` | **Recharge USSD:** `*133*<14_digit_PIN>#` or call `333` | **Customer Care:** `111` (from mobile) / `07701110000` / `+9647701110000`  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Zendit** (`zendit`) | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `IQ` (ISO-2) | `IRQ` (ISO-3) | `IQ` (ISO-2) | `IQ` (ISO-2) |
| **Carrier / Operator Code** | `AsiaCell` | `42` ("Asia Cell Telecom Iraq") | `246` ("Asia Cell Telecom Iraq") | `ACIQ` ("Asia Cell Telecom Iraq") |
| **Delivery Mechanism** | **Direct Airtime Top-Up** | Direct Airtime & PIN Voucher | Direct Airtime Top-Up | Direct Airtime (0 UAT inventory) |
| **Settlement Currency** | **`USD`** | **`OMR`** (Major Units) | **`USD`** | **`OMR`** (Major Units) |
| **Catalog Format** | 4 Fixed Tiers (5,000–100,000 IQD) | 4 Direct + 1 PIN Voucher | 4 Fixed Tiers (5,000–100,000 IQD) | 0 Active Products in UAT (Rate Limited) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Failover** (`priority: 20`) | 🟢 **Tertiary Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (IQD) | Zendit Wholesale (`USD`) / Offer ID | DT One Wholesale (`OMR`) / Product ID | Reloadly Wholesale (`USD`) / Op 246 | DingConnect Direct (`ACIQ`) |
| :---: | :---: | :---: | :---: | :---: |
| **3,000 IQD** | — | **1.235 OMR ($3.21 USD)** (PIN `39018`) | — | 🔴 *(0 Catalog Offers)* |
| **5,000 IQD** | **$4.18 USD** ($6.50 retail / `ASIACELL_IQ_001`) | **1.848 OMR ($4.81 USD)** (Direct `4042`, 45D) | **$7.03 USD** ($6.82 net, Op `246`) | 🔴 *(0 Catalog Offers)* |
| **10,000 IQD** | **$8.35 USD** ($12.00 retail / `ASIACELL_IQ_002`) | **3.695 OMR ($9.61 USD)** (Direct `4043`, 100D) | **$14.07 USD** ($13.65 net, Op `246`) | 🔴 *(0 Catalog Offers)* |
| **25,000 IQD** | **$20.89 USD** ($29.50 retail / `ASIACELL_IQ_003`) | **9.238 OMR ($24.03 USD)** (Direct `4044`, 360D) | **$35.17 USD** ($34.11 net, Op `246`) | 🔴 *(0 Catalog Offers)* |
| **100,000 IQD** | **$83.55 USD** ($118.50 retail / `ASIACELL_IQ_004`) | **36.950 OMR ($96.10 USD)** (Direct `4045`, 360D) | **$140.68 USD** ($136.46 net, Op `246`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Zendit (Test Environment)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `ASIACELL_IQ_001` (5,000 IQD Direct Top-Up) to `+9647700000101`
* **Status:** `200 OK` $\rightarrow$ `status: ACCEPTED`
* **Transaction ID:** `zen_iq_test_1787439679454_asiacell_iq_001`
* **Delivered Yield:** `5,000 IQD`, Wholesale Cost: `$4.18 USD` (35.69% margin discount).
* **Result:** **Primary Active Direct Route** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test 1 Request (Direct):** Product `4042` (5,000 IQD Direct Airtime, 45D validity) to `+9647700000101`
* **Status:** `201 Created` $\rightarrow$ `status: CONFIRMED`
* **Transaction ID:** `2240793497`, Wholesale: `1.847 OMR` (~$4.81 USD).
* **Test 2 Request (Micro PIN):** Product `39018` (3,000 IQD Digital PIN Voucher) to `+9647700000101`
* **Status:** `201 Created` $\rightarrow$ `status: CONFIRMED`
* **Transaction ID:** `2240793498`, Wholesale: `1.234 OMR` (~$3.21 USD).
* **Result:** **Secondary Direct Airtime & Micro PIN Failover** (`priority: 20`).

### 3. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `246`, Amount `$7.03 USD` (5,000 IQD) to `9647700000101`
* **Status:** `200 OK` $\rightarrow$ `SUCCESSFUL`
* **Transaction ID:** `178500`, Delivered: `5,000 IQD`, Cost: `$6.8191 USD` (Discount: 3%).
* **Result:** **Tertiary Failover** (`priority: 30`).

### 4. DingConnect (UAT Environment)
* **Catalog Status:** Provider `ACIQ` mapped in catalog, but returns 0 active products in UAT (Rate Limited).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Top-Up:** **Zendit** (`offerId: ASIACELL_IQ_001` - 5,000 IQD at **$4.18 USD** wholesale net cost, `priority: 10`, `is_primary: true`).
2. **Secondary Direct & Micro PIN Failover:** **DT One** (`operatorId: 42` - Product `4042` direct top-up at 1.848 OMR / ~$4.81 USD & Product `39018` 3,000 IQD micro-PIN at 1.235 OMR / ~$3.21 USD, `priority: 20`).
3. **Tertiary Direct Failover:** **Reloadly** (`operatorId: 246` - 5,000 IQD tier at $6.82 USD net, `priority: 30`).
4. **Disabled Provider:** **DingConnect** (`ACIQ`, `priority: 40`, `is_enabled: false`).
5. **Iraq CMC Regulatory Compliance:**
   - CMC mandates tiered validity based on denomination: 5,000 IQD grants **45 days** of full service, 10,000 IQD grants **100 days**, and 25,000+ IQD grants **360 days**.
   - Expired lines enter a **60-day grace quarantine window** (incoming calls only) before permanent termination and number recycling.
   - KeepSIMs schedules automated mini-refills on **Day 35–40** to guarantee uninterrupted line preservation.
