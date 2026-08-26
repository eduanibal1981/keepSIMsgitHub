# Provider Comparison & Test Report: Korek Telecom (Iraq)

> **Country:** Iraq (`IQ` / `+964` / `IRQ`)  
> **Carrier:** Korek Telecom  
> **Network Type:** MNO (Kurdistan Regional & National Operator, HQ: Erbil)  
> **Balance USSD:** `*211#` | **Recharge USSD:** `*221*<14_digit_PIN>#` or call `321` / `221` | **Customer Care:** `411` (from mobile) / `07500000411` / `+9647500000411`  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **DingConnect** (`ding`) | **Zendit** (`zendit`) | **Reloadly** (`reloadly`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `IRQ` (ISO-3) | `IQ` (ISO-2) | `IQ` (ISO-2) | `IQ` (ISO-2) |
| **Carrier / Operator Code** | `2096` ("Korek Iraq") | `KKIQ` ("Korek Iraq") / `KRIQ` ("Korek Pins") | `Korek` | — *(Not Mapped)* |
| **Delivery Mechanism** | **Digital PIN Voucher** | Direct Airtime & PIN (0 UAT inventory) | 0 Catalog Offers | 0 Catalog Offers |
| **Settlement Currency** | **`OMR`** (Major Units) | **`OMR`** (Major Units) | **`USD`** | **`USD`** |
| **Catalog Format** | 1 Fixed PIN Voucher (5,000 IQD) | 0 Active Products in UAT (Rate Limited) | 0 Active Offers | 0 Active Offers |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Provider** (`is_primary: true`, `priority: 10`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (IQD) | DT One Wholesale (`OMR`) / Product ID | DingConnect Direct (`KKIQ` / `KRIQ`) | Zendit Direct (`USD`) | Reloadly Direct (`USD`) |
| :---: | :---: | :---: | :---: | :---: |
| **5,000 IQD** | **2.050 OMR ($5.33 USD)** (PIN `39011`, 40D) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `39011` (5,000 IQD PIN Voucher) to `+9647500000101`
* **Status:** `201 Created` $\rightarrow$ `status: CONFIRMED`
* **Transaction ID:** `2240793501`, Wholesale: `2.049 OMR` (~$5.33 USD).
* **Delivered PIN Info:** Usage instructions: *"Dial from your mobile phone: \*221\*the voucher number and # and press send OR Dial from your mobile phone 321 or 221"*, Validity: `40 DAY`.
* **Result:** **Primary Active Provider & PIN Fulfillment Rail** (`priority: 10`, `is_primary: true`).

### 2. DingConnect (UAT Environment)
* **Catalog Status:** Providers `KKIQ` and `KRIQ` registered in DingConnect Iraq directory, but return 0 active products in UAT (Rate Limited).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 20`).

### 3. Zendit (Test Environment)
* **Catalog Status:** 0 active offers in catalog for brand `Korek` in Iraq (`IQ`).
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. Reloadly (Sandbox API)
* **Catalog Status:** No active operator for Korek Telecom in Iraq in Reloadly sandbox catalog.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Provider:** **DT One** (`operatorId: 2096` - Product `39011` 5,000 IQD PIN voucher at 2.050 OMR / ~$5.33 USD granting 40 days validity, `priority: 10`, `is_primary: true`).
2. **Disabled Providers:** **DingConnect** (`priority: 20`), **Zendit** (`priority: 30`), **Reloadly** (`priority: 40`) due to 0 catalog inventory in test/UAT environments.
3. **Iraq CMC Regulatory Compliance:**
   - Korek Telecom prepaid 5,000 IQD refills grant **40 days of active line validity**.
   - After 40 days, lines enter a **60-day grace quarantine phase** (incoming calls only).
   - After the grace window, number is permanently disconnected and recycled.
   - KeepSIMs automated mini-refill worker triggers voucher delivery at **Day 30–35** to maintain uninterrupted service.
