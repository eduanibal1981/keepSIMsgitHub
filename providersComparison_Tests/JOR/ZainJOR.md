# Provider Comparison & Test Report: Zain Jordan

> **Country:** Jordan (`JO` / `+962` / `JOR`)  
> **Carrier:** Zain Jordan (Mobile Telecommunications Company Jordan / Zain Group)  
> **Network Type:** MNO (Market Leader in Mobile & 5G Telecom)  
> **Balance USSD / SMS:** Dial `*116#` or `*121#` (Balance & validity enquiry) | **Recharge USSD:** Dial `*114*<PIN>#` or via Zain App / Zain Cash  
> **Customer Care:** `1234` (from Zain) / `+962 79 000 1234` (International / Local)  
> **Regulatory Policy (TRC Jordan):** 90 Days Inactivity Lifecycle | Direct airtime recharges extend line validity 30 to 180 days | 90 Days Suspension Grace Period before line cancellation & number recycling | Total telecom tax (16% GST + 26% Special Tax on mobile subscriptions)  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) | **Reloadly** (`reloadly`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `JOR` (ISO-3) | `JO` (ISO-2) | `JO` (ISO-2) | `JO` (ISO-2) |
| **Carrier / Operator Code** | `2093` ("Zain Jordan") | `Zain` ("Zain") | `ZJJO` ("Zain Jordan") | `666` ("Zain Jordan") |
| **Delivery Mechanism** | Direct Airtime & Digital PIN | Direct Airtime Top-Up & Data Bundles | Direct Airtime Top-Up (Mapped) | Direct Airtime Top-Up |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`OMR`** | **`USD`** |
| **Catalog Format** | 29 SKUs (Direct 0.5–36 JOD, PINs, Data) | 18 SKUs (Direct 1–60 JOD, Bundles, Data) | Provider Mapped (`ZJJO`) | 5 Fixed Amounts (5–36 JOD) |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Top-Up** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🟢 **Tertiary Route** (`priority: 30`) | 🔴 **Disabled (High Cost)** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (JOD) | DT One Wholesale (`OMR` / `USD`) / ID | Zendit Wholesale (`USD`) / Offer ID | Reloadly Wholesale (`USD`) / Op ID 666 | DingConnect (`ZJJO`) |
| :---: | :---: | :---: | :---: | :---: |
| **0.50 JOD (Micro Airtime)** | **0.510 OMR ($1.33 USD)** (`39869` Direct) | — | — | 🟢 Mapped (`ZJJO`) |
| **0.50 JOD (PIN Voucher)** | **0.669 OMR ($1.74 USD)** (`28623` PIN) | — | — | 🟢 Mapped (`ZJJO`) |
| **1.00 JOD (Airtime Top-Up)** | **1.020 OMR ($2.65 USD)** (`39870` Direct) | **$2.99 USD** (`ZAIN_JORDAN_1_JOD_FEE`) | — | 🟢 Mapped (`ZJJO`) |
| **1.00 JOD (PIN Voucher)** | **1.203 OMR ($3.13 USD)** (`22564` PIN) | — | — | 🟢 Mapped (`ZJJO`) |
| **3.00 JOD (Airtime Top-Up)** | **3.059 OMR ($7.95 USD)** (`39871` Direct) | **$8.30 USD** (`ZAIN_JORDAN_3_JOD_FEE`) | — | 🟢 Mapped (`ZJJO`) |
| **3.00 JOD (PIN Voucher)** | **3.340 OMR ($8.68 USD)** (`22565` PIN) | — | — | 🟢 Mapped (`ZJJO`) |
| **3.25 JOD (PIN Voucher)** | **6.405 OMR ($16.65 USD)** (`62266` PIN) | — | — | 🟢 Mapped (`ZJJO`) |
| **3.75 JOD (PIN Voucher)** | **7.324 OMR ($19.04 USD)** (`62265` PIN) | — | — | 🟢 Mapped (`ZJJO`) |
| **4.00 JOD (PIN Voucher)** | **7.810 OMR ($20.31 USD)** (`62264` PIN) | — | — | 🟢 Mapped (`ZJJO`) |
| **4.50 JOD (PIN Voucher)** | **8.627 OMR ($22.43 USD)** (`62263` PIN) | — | — | 🟢 Mapped (`ZJJO`) |
| **5.00 JOD (Airtime Top-Up)** | **5.097 OMR ($13.25 USD)** (`14630` Direct) | **$12.66 USD** (`ZAIN_JORDAN_5_JOD_FEE`) | $26.95 USD (`rl_666_27.78`) | 🟢 Mapped (`ZJJO`) |
| **5.00 JOD (PIN Voucher)** | **5.654 OMR ($14.70 USD)** (`22566` PIN) | — | — | 🟢 Mapped (`ZJJO`) |
| **5.50 JOD (PIN Voucher)** | **10.340 OMR ($26.88 USD)** (`62262` PIN) | — | — | 🟢 Mapped (`ZJJO`) |
| **6.00 JOD (Airtime Top-Up)** | **6.117 OMR ($15.90 USD)** (`39872` Direct) | — | — | 🟢 Mapped (`ZJJO`) |
| **6.00 JOD (Bundle: Bila Hdoud +)** | **5.542 OMR ($14.41 USD)** (`40508` Mix) | **$13.53 USD** (`ZAIN_JORDAN_BUNDLE_01`) | — | 🟢 Mapped (`ZJJO`) |
| **6.00 JOD (PIN Voucher)** | **11.327 OMR ($29.45 USD)** (`62261` PIN) | — | — | 🟢 Mapped (`ZJJO`) |
| **7.00 JOD (Bundle: Mohafazat +)** | **6.466 OMR ($16.81 USD)** (`40509` Mix) | **$16.05 USD** (`ZAIN_JORDAN_BUNDLE_02`) | — | 🟢 Mapped (`ZJJO`) |
| **8.00 JOD (Bundle: Mish Tabi3i +)**| **7.389 OMR ($19.21 USD)** (`40510` Mix) | **$18.03 USD** (`ZAIN_JORDAN_BUNDLE_03`) | — | 🟢 Mapped (`ZJJO`) |
| **8.00 JOD (Data: 40 GB)** | **6.431 OMR ($16.72 USD)** (`40513` Data) | **$15.56 USD** (`ZAIN_JORDAN_DATA_01`) | — | 🟢 Mapped (`ZJJO`) |
| **9.00 JOD (Airtime Top-Up)** | **9.175 OMR ($23.86 USD)** (`14631` Direct) | **$22.78 USD** (`ZAIN_JORDAN_9_JOD_FEE`) | $48.50 USD (`rl_666_50.00`) | 🟢 Mapped (`ZJJO`) |
| **11.00 JOD (Bundle: Turbo +)** | **10.160 OMR ($26.42 USD)** (`40511` Mix) | **$25.23 USD** (`ZAIN_JORDAN_BUNDLE_04`) | — | 🟢 Mapped (`ZJJO`) |
| **11.00 JOD (Data: 100 GB)** | **8.843 OMR ($22.99 USD)** (`40514` Data) | **$21.97 USD** (`ZAIN_JORDAN_DATA_02`) | — | 🟢 Mapped (`ZJJO`) |
| **12.00 JOD (Airtime Top-Up)** | **12.233 OMR ($31.81 USD)** (`14632` Direct) | **$30.37 USD** (`ZAIN_JORDAN_12_JOD_FEE`)| $64.67 USD (`rl_666_66.67`) | 🟢 Mapped (`ZJJO`) |
| **12.00 JOD (PIN Voucher)** | **12.876 OMR ($33.48 USD)** (`28622` PIN) | — | — | 🟢 Mapped (`ZJJO`) |
| **15.00 JOD (Bundle: Nitro +)** | **13.854 OMR ($36.02 USD)** (`40512` Mix) | **$34.42 USD** (`ZAIN_JORDAN_BUNDLE_05`) | — | 🟢 Mapped (`ZJJO`) |
| **16.00 JOD (Data: 250 GB)** | **12.862 OMR ($33.44 USD)** (`40515` Data) | **$31.95 USD** (`ZAIN_JORDAN_DATA_03`) | — | 🟢 Mapped (`ZJJO`) |
| **19.00 JOD (Data: 400 GB)** | **15.274 OMR ($39.71 USD)** (`40516` Data) | **$37.94 USD** (`ZAIN_JORDAN_DATA_04`) | — | 🟢 Mapped (`ZJJO`) |
| **20.00 JOD (Airtime Top-Up)** | **20.388 OMR ($53.01 USD)** (`14633` Direct) | **$50.63 USD** (`ZAIN_JORDAN_20_JOD_FEE`)| $107.78 USD (`rl_666_111.11`)| 🟢 Mapped (`ZJJO`) |
| **29.00 JOD (Airtime Top-Up)** | — | **$77.86 USD** (`ZAIN_JORDAN_29_JOD_FEE`)| — | 🟢 Mapped (`ZJJO`) |
| **36.00 JOD (Airtime Top-Up)** | **36.697 OMR ($95.41 USD)** (`14634` Direct) | **$91.14 USD** (`ZAIN_JORDAN_36_JOD_FEE`)| $194.00 USD (`rl_666_200.00`)| 🟢 Mapped (`ZJJO`) |
| **60.00 JOD (Airtime Top-Up)** | — | **$161.18 USD** (`ZAIN_JORDAN_60_JOD_FEE`)| — | 🟢 Mapped (`ZJJO`) |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `39869` (Zain Jordan 0.5 JOD Airtime Direct) to `+962790000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793403`, Wholesale Cost: `0.510 OMR` (~$1.33 USD), Delivered: `0.5 JOD` Direct Airtime
* **Result:** **Primary Direct Top-Up Route** (`priority: 10`, `is_primary: true`).

### 2. Zendit (Production Sandbox API)
* **API Endpoint:** `POST /topups/purchases`
* **Test Request:** Offer `ZAIN_JORDAN_1_JOD_FEE` (1 JOD Airtime Top-Up) to `+962790000101`
* **Status:** `200 OK` $\rightarrow$ Status: `ACCEPTED`
* **Delivered Artifact:** Transaction ID `zen_jo_test_1787438128932_ZAIN_JORDAN_1_JOD_FEE`, Wholesale Cost: `$2.99 USD`, Retail: `$3.50 USD`
* **Result:** **Secondary Direct Airtime Failover** (`priority: 20`).

### 3. DingConnect (UAT Environment)
* **Provider Code:** `ZJJO` ("Zain Jordan")
* **Validation Regex:** `^962[0-9]{9}$|^0000000000$`
* **Result:** **Tertiary Route** (`priority: 30`).

### 4. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `666` (Zain Jordan 5 JOD Fixed Amount) to `+962790000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL` (Tx ID `178444`, $26.95 USD net cost for 5 JOD)
* **Result:** **Disabled / High Cost Backup** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 2093` — ultra-low micro-recharge entry point of **0.5 JOD (0.510 OMR / ~$1.33 USD)** direct airtime, Product `39869`, `priority: 10`, `is_primary: true`).
2. **Secondary Failover:** **Zendit** (`brand: Zain` — comprehensive direct catalog including 1 JOD for $2.99 USD and rich bundle/data options, `priority: 20`).
3. **Tertiary Route:** **DingConnect** (`providerCode: ZJJO`, `priority: 30`).
4. **Disabled Provider:** **Reloadly** (`operatorId: 666` — disabled due to heavily distorted FX/commission rates charging \$27.78 USD for 5 JOD airtime, `priority: 40`, `is_enabled: false`).
5. **TRC Jordan Regulatory Compliance:**
   - Zain Jordan prepaid SIM cards operate on a **90-day activity lifecycle**.
   - Direct airtime recharges extend line validity by **30 to 180 days** depending on denomination.
   - If no qualifying transaction occurs within 90 days, the line enters a **90-day grace/suspension period** (incoming-only calls/SMS) before permanent cancellation and recycling.
   - KeepSIMs schedules automated mini-refills on **Day 80–85** with a **0.5 JOD (0.510 OMR / ~$1.33 USD)** direct top-up via DT One to maintain active line validity seamlessly at minimal cost.
