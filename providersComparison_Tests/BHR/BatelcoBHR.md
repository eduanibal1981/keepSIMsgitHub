# Provider Comparison & Test Report: Batelco (Bahrain Telecommunications Company)

> **Country:** Bahrain (`BH` / `+973` / `BHR`)  
> **Carrier:** Bahrain Telecommunications Company (`Batelco`)  
> **Network Type:** MNO (National Incumbent Operator)  
> **Balance USSD / SMS:** Dial `*122#` (Balance & account deactivation date enquiry) | **Recharge USSD:** Dial `*125*<PIN>#` or call `111` | **Account App:** Batelco App  
> **Customer Care:** `196` (Local) / `+973 1788 1111` (International)  
> **Regulatory Policy (TRA Bahrain):** 90 Days Inactivity Lifecycle | Recharge vouchers grant 90 to 365 days line validity | 90 Days Suspension Grace Period before permanent deactivation and number recycling | 10% VAT applies on prepaid services  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **DT One** (`dtone`) | **DingConnect** (`ding`) | **Zendit** (`zendit`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `BH` (ISO-2) | `BHR` (ISO-3) | `BH` (ISO-2) | `BH` (ISO-2) |
| **Carrier / Operator Code** | `22` ("Batelco PIN Bahrain") | `1828` ("Batelco PIN Bahrain") | `BVBH` ("Batelco Bahrain") | `Batelco` |
| **Delivery Mechanism** | Digital PIN Voucher (`pin: true`) | Digital PIN Voucher (`FIXED_VALUE_PIN_PURCHASE`) | Direct Top-Up / PIN (Mapped) | Direct Top-Up (0 Inventory in BH) |
| **Settlement Currency** | **`USD`** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`OMR`** | **`USD`** |
| **Catalog Format** | 8 Fixed Amounts ($3.05–$91.35 USD) | 10 Fixed PIN Products (2.25–30.25 BHD) | Provider Mapped (`BVBH`) | 0 Active Products in BH |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary PIN Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary PIN Failover** (`priority: 20`) | 🟢 **Tertiary Route** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (BHD) | Reloadly Wholesale (`USD`) / Op ID 22 | DT One Wholesale (`OMR` / `USD`) / Product ID | DingConnect Direct (`BVBH`) | Zendit Direct (`Batelco`) |
| :---: | :---: | :---: | :---: | :---: |
| **2.25 BHD PIN** | — | **2.866 OMR ($7.45 USD)** (`56728`) | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **3.05 USD PIN (~1.15 BHD)** | **$2.989 USD** (2% discount on $3.05) | — | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **3.25 BHD PIN** | — | **4.142 OMR ($10.77 USD)** (`56729`) | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **4.25 BHD PIN** | — | **5.416 OMR ($14.08 USD)** (`56730`) | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **5.25 BHD PIN** | — | **6.691 OMR ($17.39 USD)** (`56731`) | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **6.10 USD PIN (~2.30 BHD)** | **$5.978 USD** (2% discount on $6.10) | — | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **6.25 BHD PIN** | — | **7.965 OMR ($20.71 USD)** (`56732`) | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **7.25 BHD PIN** | — | **9.240 OMR ($24.02 USD)** (`56733`) | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **8.25 BHD PIN** | — | **10.514 OMR ($27.34 USD)** (`56734`) | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **9.15 USD PIN (~3.45 BHD)** | **$8.967 USD** (2% discount on $9.15) | — | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **10.25 BHD PIN** | — | **13.063 OMR ($33.96 USD)** (`56735`) | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **12.20 USD PIN (~4.60 BHD)** | **$11.956 USD** (2% discount on $12.20) | — | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **15.25 USD PIN (~5.75 BHD)** | **$14.945 USD** (2% discount on $15.25) | — | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **20.25 BHD PIN** | — | **25.806 OMR ($67.10 USD)** (`56737`) | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **30.25 BHD PIN** | — | **38.550 OMR ($100.23 USD)** (`56738`) | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **30.45 USD PIN** | **$29.841 USD** (2% discount on $30.45) | — | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **60.90 USD PIN** | **$59.682 USD** (2% discount on $60.90) | — | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |
| **91.35 USD PIN** | **$89.523 USD** (2% discount on $91.35) | — | 🟢 Mapped (`BVBH`) | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `22` ($3.05 USD $\rightarrow$ delivered 1.15 BHD PIN) to `+97339000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178437`, Net Cost: `$2.989 USD` (2% discount applied), Delivered PIN Code: `773709732564404`, Serial: `581994`
* **Result:** **Primary PIN Route** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `56728` (Batelco 2.25 BHD PIN) to `+97339000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240793389`, Wholesale Cost: `2.866 OMR` (~$7.45 USD), Line Validity Granted: `365 Days`
* **USSD Instructions Returned:** `"To refill your account: *125*PIN# Send Or call 111 and follow voice instructions", "For balance enquiry and account deactivation date: *122# Send", "For assistance, please call Batelco on 196", "IVR: 111"`
* **Result:** **Secondary PIN Failover** (`priority: 20`).

### 3. DingConnect (UAT Environment)
* **Provider Code:** `BVBH` ("Batelco Bahrain")
* **Validation Regex:** `^973[0-9]{7,8}$|^0000000000$`
* **Result:** **Tertiary Route** (`priority: 30`).

### 4. Zendit (Test Environment)
* **Catalog Status:** 0 active offers for brand `Batelco` in Bahrain.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 40`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **Reloadly** (`operatorId: 22` — verified digital PIN voucher delivery at lowest entry point $2.989 USD net cost for 1.15 BHD PIN voucher, `priority: 10`, `is_primary: true`).
2. **Secondary Failover:** **DT One** (`operatorId: 1828` — deep catalog of 10 fixed PIN products from 2.25 BHD to 30.25 BHD providing up to 365 days validity at 2.866 OMR wholesale, `priority: 20`).
3. **Tertiary Route:** **DingConnect** (`providerCode: BVBH`, `priority: 30`).
4. **Disabled Provider:** **Zendit** (`brand: Batelco`, `priority: 40`, `is_enabled: false`).
5. **TRA Bahrain Regulatory Compliance:**
   - Batelco prepaid SIM cards operate on a **90-day activity lifecycle**.
   - Recharging via Batelco recharge PIN vouchers extends active line validity by **90 to 365 days** (Product 56728 grants 365 days).
   - If no qualifying transaction occurs within the active validity window, the line enters a **90-day grace/suspension period** (incoming-only) before permanent deactivation and number recycling.
   - KeepSIMs schedules automated mini-refills on **Day 80–85** or every 90 days, delivering a $3.05 USD / 1.15 BHD or 2.25 BHD PIN voucher to refresh the line validity counter indefinitely.
