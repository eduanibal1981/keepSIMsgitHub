# Provider Comparison & Test Report: Orange Jordan

> **Country:** Jordan (`JO` / `+962` / `JOR`)  
> **Carrier:** Orange Jordan (Jordan Telecom Group / Orange Middle East)  
> **Network Type:** MNO (National Telecom Operator / Fixed & Mobile)  
> **Balance USSD / SMS:** Dial `*155#` or `*150#` (Balance & validity enquiry) | **Recharge USSD:** Dial `*150*<PIN>#` or via Orange Max It App  
> **Customer Care:** `1777` (from Orange) / `+962 77 770 0177` (International / Local)  
> **Regulatory Policy (TRC Jordan):** 90 Days Inactivity Lifecycle | PIN recharges grant active validity up to 365 days | 65 Days Suspension Grace Period (5 days incoming-only, 60 days total suspension) before permanent line disconnection & number recycling  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) | **Reloadly** (`reloadly`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `JOR` (ISO-3) | `JO` (ISO-2) | `JO` (ISO-2) | `JO` (ISO-2) |
| **Carrier / Operator Code** | `3122` ("Orange Jordan") | `Orange` ("Orange") | `ORJO` ("Orange Jordan") | `0` (Unsupported in JO) |
| **Delivery Mechanism** | Digital PIN Voucher (`FIXED_VALUE_PIN`) | Direct Airtime Top-Up (`Mobile Top Up`) | Direct Airtime Top-Up (Mapped) | Unsupported |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`OMR`** | **`USD`** |
| **Catalog Format** | 16 Fixed PIN Vouchers (1.00–15.00 JOD) | 4 Fixed Direct Offers (3.00–12.00 JOD) | Provider Mapped (`ORJO`) | 0 Sandbox Operators |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary PIN Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🟢 **Tertiary Route** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (JOD) | DT One Wholesale (`OMR` / `USD`) / Product ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`ORJO`) | Reloadly (`0`) |
| :---: | :---: | :---: | :---: | :---: |
| **1.00 JOD (PIN Voucher)** | **1.034 OMR ($2.69 USD)** (`58694` PIN, 365d) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **1.00 JOD (Alt PIN)** | **1.203 OMR ($3.13 USD)** (`58702` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **2.00 JOD (PIN Voucher)** | **2.060 OMR ($5.36 USD)** (`58695` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **3.00 JOD (Direct Top-Up)**| — | **$8.73 USD** (`ORANGE_JORDAN_3_JOD_FEE`) | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **3.00 JOD (PIN Voucher)** | **3.027 OMR ($7.87 USD)** (`58696` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **3.00 JOD (Alt PIN)** | **3.513 OMR ($9.13 USD)** (`22560` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **5.00 JOD (Direct Top-Up)**| — | **$13.69 USD** (`ORANGE_JORDAN_5_JOD_FEE`) | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **5.00 JOD (PIN Voucher)** | **5.510 OMR ($14.33 USD)** (`28480` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **6.00 JOD (Direct Top-Up)**| — | **$16.33 USD** (`ORANGE_JORDAN_6_JOD_FEE`) | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **6.00 JOD (PIN Voucher)** | **6.578 OMR ($17.10 USD)** (`28620` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **6.50 JOD (PIN Voucher)** | **6.520 OMR ($16.95 USD)** (`58691` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **7.50 JOD (PIN Voucher)** | **7.463 OMR ($19.40 USD)** (`58692` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **8.00 JOD (PIN Voucher)** | **7.896 OMR ($20.53 USD)** (`58693` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **10.00 JOD (PIN Voucher)** | **9.648 OMR ($25.08 USD)** (`58697` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **11.00 JOD (PIN Voucher)** | **10.591 OMR ($27.54 USD)** (`58698` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **12.00 JOD (Direct Top-Up)**| — | **$32.57 USD** (`ORANGE_JORDAN_12_JOD_FEE`)| 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **12.00 JOD (PIN Voucher)** | **11.558 OMR ($30.05 USD)** (`58699` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **12.00 JOD (Alt PIN)** | **13.112 OMR ($34.09 USD)** (`22561` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **13.00 JOD (PIN Voucher)** | **12.448 OMR ($32.36 USD)** (`58700` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |
| **15.00 JOD (PIN Voucher)** | **14.464 OMR ($37.61 USD)** (`58701` PIN) | — | 🟢 Mapped (`ORJO`) | 🔴 *(Unsupported)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `58694` (Orange Jordan 1 JOD PIN Voucher) to `+962770000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793404`, Wholesale Cost: `1.034 OMR` (~$2.69 USD), Validity: `365 Days`, PIN Instructions: `Press *150* insert PIN and then # to refill`
* **Result:** **Primary PIN Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Production Sandbox API)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `ORANGE_JORDAN_3_JOD_FEE` (3 JOD Direct Airtime) to `+962770000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Delivered Artifact:** Transaction ID `zen_jo_test_1787438131171_ORANGE_JORDAN_3_JOD_FEE`, Wholesale Cost: `$8.73 USD`, Retail: `$9.75 USD`
* **Result:** **Secondary Direct Airtime Failover** (`priority: 20`).

### 3. DingConnect (UAT Environment)
* **Provider Code:** `ORJO` ("Orange Jordan")
* **Validation Regex:** `^962[0-9]{9}$|^0000000000$`
* **Result:** **Tertiary Route** (`priority: 30`).

### 4. Reloadly (Sandbox API)
* **Catalog Status:** 0 active sandbox operators for Orange in Jordan.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **DT One** (`operatorId: 3122` — 16 Digital PIN products featuring the ultra-efficient **1 JOD PIN (1.034 OMR / ~$2.69 USD)** with **365-day validity**, Product `58694`, `priority: 10`, `is_primary: true`).
2. **Secondary Failover:** **Zendit** (`brand: Orange` — 4 direct airtime top-up products from 3 JOD @ $8.73 USD, `priority: 20`).
3. **Tertiary Route:** **DingConnect** (`providerCode: ORJO`, `priority: 30`).
4. **Disabled Provider:** **Reloadly** (unsupported in Jordan catalog, `priority: 40`, `is_enabled: false`).
5. **TRC Jordan Regulatory Compliance:**
   - Orange Jordan prepaid lines enforce an activity validity window.
   - Missing the validity window triggers a 5-day incoming-only suspension followed by a 60-day complete suspension before terminal line disconnection.
   - Redeeming a **1 JOD PIN voucher via DT One (Product 58694)** grants up to **365 days of voucher validity**, securing line connectivity for an entire year at minimal cost.
