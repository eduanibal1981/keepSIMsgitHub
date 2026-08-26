# Provider Comparison & Test Report: Umniah Jordan

> **Country:** Jordan (`JO` / `+962` / `JOR`)  
> **Carrier:** Umniah (Umniah Mobile Company / Beyon Group / Batelco)  
> **Network Type:** MNO (3rd National Mobile Network Operator)  
> **Balance USSD / SMS:** Dial `*136#` or `*100#` (Balance & validity enquiry) | **Recharge USSD:** Dial `*133*<PIN>#` or call `1331` or via Umniah App  
> **Customer Care:** `1333` (from Umniah) / `+962 78 800 1333` (International / Local)  
> **Regulatory Policy (TRC Jordan):** 90 Days Inactivity Lifecycle | Ranged airtime recharges extend line validity 30 to 90 days | 90 Days Suspension Grace Period before line cancellation & number recycling  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **DT One** (`dtone`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `JO` (ISO-2) | `JOR` (ISO-3) | `JO` (ISO-2) | `JO` (ISO-2) |
| **Carrier / Operator Code** | `1150` ("Umniah Jordan RTR") | `690` ("Umniah Jordan") | `Umniah` ("Umniah") | `Umniah` |
| **Delivery Mechanism** | Direct Airtime Top-Up (`RANGE`) | Digital PIN Voucher (`FIXED_VALUE_PIN`) | Direct Top-Up (0 Inventory in JO) | Direct Top-Up (0 Inventory in JO) |
| **Settlement Currency** | **`USD`** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`OMR`** |
| **Catalog Format** | Open Range (1–35 JOD / $4.88–$170.88 USD) | 7 Fixed PIN Vouchers (6.85–13.85 JOD) | 0 Active Products in JO | 0 Active Products in JO |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct Top-Up** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary PIN Failover** (`priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (JOD) | Reloadly Wholesale (`USD`) / Op ID 1150 | DT One Wholesale (`OMR` / `USD`) / Product ID | Zendit Direct (`Umniah`) | DingConnect (`Umniah`) |
| :---: | :---: | :---: | :---: | :---: |
| **1.00 JOD (Direct Top-Up)** | **$4.88 USD** (`rl_1150_range`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **2.00 JOD (Direct Top-Up)** | **$9.76 USD** (`rl_1150_range`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **3.00 JOD (Direct Top-Up)** | **$14.65 USD** (`rl_1150_range`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **5.00 JOD (Direct Top-Up)** | **$24.41 USD** (`rl_1150_range`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **6.85 JOD (PIN Voucher)** | — | **6.641 OMR ($17.27 USD)** (`58457` PIN, 30d) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **7.85 JOD (PIN Voucher)** | — | **7.901 OMR ($20.54 USD)** (`58458` PIN) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **8.85 JOD (PIN Voucher)** | — | **8.517 OMR ($22.14 USD)** (`58459` PIN) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **9.85 JOD (PIN Voucher)** | — | **9.397 OMR ($24.43 USD)** (`58460` PIN) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **10.00 JOD (Direct Top-Up)**| **$48.82 USD** (`rl_1150_range`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **10.85 JOD (PIN Voucher)** | — | **10.340 OMR ($26.88 USD)** (`58461` PIN) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **12.85 JOD (PIN Voucher)** | — | **12.178 OMR ($31.66 USD)** (`58462` PIN) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **13.85 JOD (PIN Voucher)** | — | **13.112 OMR ($34.09 USD)** (`58463` PIN) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **20.00 JOD (Direct Top-Up)**| **$97.65 USD** (`rl_1150_range`) | — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |
| **35.00 JOD (Direct Top-Up)**| **$170.88 USD** (`rl_1150_range`)| — | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `1150` (Umniah Jordan RTR — Ranged Top-Up, $4.88 USD $\rightarrow$ delivered 1 JOD direct airtime) to `+962780000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178443`, Net Cost: `$4.88 USD`, Delivered: `1.00 JOD`, Direct Airtime Top-Up
* **Result:** **Primary Direct Top-Up Route** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `58457` (Umniah 6.85 JOD PIN Voucher) to `+962780000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793405`, Wholesale Cost: `6.641 OMR` (~$17.27 USD), Validity: `30 Days`, PIN Instructions: `Dial *133* enter scratch card number (14 digits) # or call 1331`
* **Result:** **Secondary PIN Failover** (`priority: 20`).

### 3. Zendit (Test Environment)
* **Catalog Status:** 0 active offers for brand `Umniah` in Jordan.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 30`).

### 4. DingConnect (UAT Environment)
* **Catalog Status:** 0 active telecom provider entries for Umniah in Jordan.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **Reloadly** (`operatorId: 1150` — verified ranged direct airtime top-up delivery with ultra-flexible entry point of **1 JOD ($4.88 USD)**, `priority: 10`, `is_primary: true`).
2. **Secondary Failover:** **DT One** (`operatorId: 690` — 7 fixed digital PIN vouchers from 6.85 JOD at 6.641 OMR wholesale, `priority: 20`).
3. **Disabled Providers:** **Zendit** & **DingConnect** (`priority: 30` and `priority: 40`, `is_enabled: false` due to 0 catalog inventory).
4. **TRC Jordan Regulatory Compliance:**
   - Umniah prepaid accounts operate on a **90-day activity lifecycle**.
   - Direct airtime recharges extend line validity by **30 to 90 days**.
   - If no qualifying transaction occurs within 90 days, the line enters a **90-day grace/suspension period** (incoming-only calls/SMS) before permanent cancellation and recycling.
   - KeepSIMs schedules automated mini-refills on **Day 80–85** with a **1 JOD ($4.88 USD)** direct top-up via Reloadly to maintain active line validity seamlessly at minimal cost.
