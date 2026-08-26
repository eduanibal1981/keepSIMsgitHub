# Provider Comparison & Test Report: Zain Iraq

> **Country:** Iraq (`IQ` / `+964` / `IRQ`)  
> **Carrier:** Zain Iraq (Zain Group)  
> **Network Type:** MNO (Southern & Central Iraq Market Leader, HQ: Baghdad)  
> **Balance USSD:** `*100#` or `*200#` | **Recharge USSD:** `*101*<16_digit_PIN>#` or call `216` | **Customer Care:** `107` (from mobile) / `07802999107` / `+9647802999107`  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Zendit** (`zendit`) | **Reloadly** (`reloadly`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `IRQ` (ISO-3) | `IQ` (ISO-2) | `IQ` (ISO-2) | `IQ` (ISO-2) |
| **Carrier / Operator Code** | `3817` ("Zain Iraq") | `Zain` | — *(Not Mapped)* | `ZAIQ` |
| **Delivery Mechanism** | **Digital PIN Voucher** | Direct Airtime (0 Catalog Offers) | 0 Catalog Offers | 0 Catalog Offers |
| **Settlement Currency** | **`OMR`** (Major Units) | **`USD`** | **`USD`** | **`OMR`** (Major Units) |
| **Catalog Format** | 2 Fixed PIN Vouchers (5,000 & 15,000 IQD) | 0 Active Offers | 0 Active Offers | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Provider** (`is_primary: true`, `priority: 10`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (IQD) | DT One Wholesale (`OMR`) / Product ID | Zendit Direct (`USD`) | Reloadly Direct (`USD`) | DingConnect Direct (`ZAIQ`) |
| :---: | :---: | :---: | :---: | :---: |
| **5,000 IQD** | **2.050 OMR ($5.33 USD)** (PIN `38999`, 90D) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **15,000 IQD** | **5.923 OMR ($15.40 USD)** (PIN `39001`, 90D) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test 1 Request (5,000 IQD PIN):** Product `38999` (5,000 IQD PIN Voucher) to `+9647800000101`
* **Status:** `201 Created` $\rightarrow$ `status: CONFIRMED`
* **Transaction ID:** `2240793499`, Wholesale: `2.049 OMR` (~$5.33 USD).
* **Delivered PIN Info:** Usage instructions: *"Press \*101# enter the 16 digits secret code then press # then ok OR dial the free number 216"*, Validity: `90 DAY`.
* **Test 2 Request (15,000 IQD PIN):** Product `39001` (15,000 IQD PIN Voucher) to `+9647800000101`
* **Status:** `201 Created` $\rightarrow$ `status: CONFIRMED`
* **Transaction ID:** `2240793500`, Wholesale: `5.920 OMR` (~$15.40 USD).
* **Result:** **Primary Active Provider & PIN Fulfillment Rail** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Test Environment)
* **Catalog Status:** 0 active offers in catalog for brand `Zain` in Iraq (`IQ`).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 20`).

### 3. Reloadly (Sandbox API)
* **Catalog Status:** No active operator for Zain in Iraq in Reloadly sandbox catalog.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment)
* **Catalog Status:** 0 active products in UAT for Zain Iraq.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Provider:** **DT One** (`operatorId: 3817` - Product `38999` 5,000 IQD PIN voucher at 2.050 OMR / ~$5.33 USD granting 90 days validity, `priority: 10`, `is_primary: true`).
2. **Disabled Providers:** **Zendit** (`priority: 20`), **Reloadly** (`priority: 30`), **DingConnect** (`priority: 40`) due to 0 catalog inventory.
3. **Iraq CMC Regulatory Compliance:**
   - Zain Iraq prepaid lines grant **90 days of active validity** upon recharging with a 5,000 IQD or 15,000 IQD card/voucher.
   - After the 90-day active window expires, lines enter a **60-day grace quarantine period** (incoming calls only).
   - Permanent disconnection and number forfeiture occur if no recharge is applied within the 60-day grace window (total 150 days from recharge).
   - KeepSIMs automated mini-refill worker delivers a 5,000 IQD voucher on **Day 80–85** to refresh validity seamlessly.
