# Provider Comparison & Test Report: Virgin Mobile (United Arab Emirates)

> **Country:** United Arab Emirates (`AE` / `+971` / `ARE`)  
> **Carrier:** Virgin Mobile UAE  
> **Network Type:** MVNO (Operated by EITC / du Network)  
> **Balance Check:** Virgin Mobile UAE App / `*135#` | **Recharge USSD:** `*233*<PIN>#` or `*611` | **Customer Care:** In-App Chat / `04 381 2222`  
> **Test Date:** 2026-08-21  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **Reloadly** (`reloadly`) | **DT One** (`dtone`) | **DingConnect** (`ding`) | **Zendit** (`zendit`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `AE` (ISO-2) | `ARE` (ISO-3) | `AE` (ISO-2) | `AE` (ISO-2) |
| **Carrier / Operator Code** | `1155` ("Virgin Mobile PIN United Arab Emirates") | `3392` ("Virgin Mobile United Arab Emirates") | `VMAE` ("Virgin Mobile UAE") | `Virgin Mobile` |
| **Delivery Mechanism** | Digital PIN Voucher | Digital PIN Voucher | Digital PIN Voucher | Direct Top-Up |
| **Settlement Currency** | **`USD`** | **`OMR`** (Major Units) | **`OMR`** (Major Units) | `USD` |
| **Product Count** | 5 Fixed PIN Tiers (20–200 AED) | 5 Products (20–200 AED PIN) | 10 PIN SKUs | 0 Offers |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary PIN Route** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary PIN Failover** (`priority: 20`) | 🟢 **Tertiary PIN Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (AED) | Reloadly PIN Wholesale (`USD`) / Op 1155 | DT One Wholesale (`OMR`) / Product ID | DingConnect PIN (`VMAE`) | Zendit Wholesale (`USD`) |
| :---: | :---: | :---: | :---: | :---: |
| **20.00 AED** | **$6.10 USD** (Net $5.978) (`rl_1155_6.1`) | 2.555 OMR ($6.64 USD) (`30009`) | 2.16 OMR ($5.62 USD) (`VMAEE2705`) | 🔴 *(0 Offers)* |
| **50.00 AED** | **$15.25 USD** (Net $14.945) (`rl_1155_15.25`)| 6.387 OMR ($16.61 USD) (`30010`) | 5.40 OMR ($14.04 USD) (`VMAEE2706`) | 🔴 *(0 Offers)* |
| **100.00 AED** | **$30.45 USD** (Net $29.841) (`rl_1155_30.45`)| 12.774 OMR ($33.22 USD) (`30011`) | 10.80 OMR ($28.09 USD) (`VMAEE2707`) | 🔴 *(0 Offers)* |
| **150.00 AED** | **$45.65 USD** (Net $44.737) (`rl_1155_45.65`)| 19.161 OMR ($49.83 USD) (`30012`) | 16.20 OMR ($42.13 USD) (`VMAEE2708`) | 🔴 *(0 Offers)* |
| **200.00 AED** | **$60.90 USD** (Net $59.682) (`rl_1155_60.9`) | 25.548 OMR ($66.44 USD) (`30013`) | 21.60 OMR ($56.18 USD) (`VMAEE2709`) | 🔴 *(0 Offers)* |

---

## 3. Live Test & Simulation Results

### 1. Reloadly (Sandbox API)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `1155`, Amount `$6.10 USD` (20 AED PIN) to `971581234567`
* **Status:** `200 OK` $\rightarrow$ `SUCCESSFUL`
* **Delivered Artifact:** Transaction ID `178323`, Delivered PIN Code: `773709732892062`, Serial: `552684`, Instructions: `"Dial *233* and PIN #"`.
* **Result:** **Primary Active PIN Route** (`priority: 10`, `is_primary: true`).

### 2. DT One (Pre-Production API)
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `30009` (20 AED PIN) to `+971580000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240790348`, Wholesale: `2.555 OMR`
* **Result:** **Secondary PIN Failover** (`priority: 20`).

### 3. DingConnect (UAT Environment)
* **Catalog Status:** Provider `VMAE` active in UAE catalog (`ValidationRegex: ^9710?(?:5)([0-9]{8})$`).
* **Result:** **Tertiary PIN Failover** (`priority: 30`).

### 4. Zendit (Test Environment)
* **Status:** 0 active offers for Virgin Mobile in UAE.
* **Result:** **Disabled in Supabase** (`is_enabled: false`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary PIN Route:** **Reloadly** (`rl_1155_6.1` - 20 AED PIN / $6.10 USD retail, $5.978 net wholesale, `priority: 10`, `is_primary: true`).
2. **Secondary PIN Failover:** **DT One** (`30009` - 20 AED PIN / 2.555 OMR, `priority: 20`).
3. **Tertiary PIN Failover:** **DingConnect** (`VMAE`, `priority: 30`).
4. **Disabled Provider:** **Zendit** (`is_enabled: false` in `carrier_provider_map` due to 0 offers).
5. **UAE TDRA Regulatory Compliance:**
   - Virgin Mobile UAE prepaid lines require qualifying activity every **90 days**.
   - A 20 AED recharge voucher satisfies the activity requirement and extends the validity window.
   - KeepSIMs schedules automated mini-refills at **Day 80–85**.
