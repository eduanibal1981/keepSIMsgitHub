# Provider Comparison & Test Report: Red Bull Mobile KSA (Saudi Arabia)

> **Country:** Saudi Arabia (`SA` / `+966` / `SAU`)  
> **Carrier:** Red Bull Mobile KSA (Future Networks Telecom / Host: Zain KSA)  
> **Network Type:** MVNO  
> **Balance USSD:** `*588#` | **Recharge USSD:** `*1588*<PIN>#` | **IVR / Care:** `950`  
> **Test Date:** 2026-08-20  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `SAU` (ISO-3) | `SA` (ISO-2) | `SA` (ISO-2) | `SA` (ISO-2) |
| **Carrier / Operator Code** | `Red Bull` | `Red Bull` | `Red Bull` | `3HSA` ("Red Bull KSA") |
| **Delivery Mechanism** | **Unsupported** in SA | **Unsupported** in SA | **Unsupported** *(0 offers)* | Direct Airtime & PIN Voucher |
| **Settlement Currency** | `OMR` | `USD` | `USD` | **`OMR`** (Major Units) |
| **Product Count** | **0 Offers** | **0 Offers** | **0 Offers** | 20 SKUs (Vouchers, Mazaji & Data) |
| **DB Status in `carrier_provider_map`** | 🔴 **Disabled** | 🔴 **Disabled** | 🔴 **Disabled** | 🟢 **Exclusive Primary** (`is_primary: true`, `priority: 10`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (SAR) | DT One Wholesale (`OMR`) | Reloadly Cost (`USD`) | Zendit Wholesale (`USD`) | DingConnect Wholesale (`OMR`) / SKU |
| :---: | :---: | :---: | :---: | :---: |
| **E-voucher 15 SAR (17.25 SAR)** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **2.28 OMR** (`3HSASA63028`) |
| **E-voucher 50 SAR (57.50 SAR)** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **7.60 OMR** (`3HSASA93064`) |
| **E-voucher 80 SAR (92.00 SAR)** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **12.15 OMR** (`3HSA75959`) |
| **E-voucher 100 SAR (115.00 SAR)**| — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **15.19 OMR** (`3HSASA51034`) |
| **E-voucher 200 SAR (230.00 SAR)**| — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **30.38 OMR** (`3HSASA58778`) |
| **8GB + 8GB Data (69.00 SAR)** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **9.12 OMR** (`3HSA16073`) |
| **Mazaji Flex 65 (74.75 SAR)** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **9.88 OMR** (`3HSA77130`) |
| **Mazaji 80 (92.00 SAR)** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **12.15 OMR** (`3HSA17836`) |
| **20GB + 20GB Data (97.75 SAR)** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **12.91 OMR** (`3HSA37187`) |
| **Mazaji 120 (138.00 SAR)** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **18.23 OMR** (`3HSA80913`) |
| **Mazaji 130 (149.50 SAR)** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **19.75 OMR** (`3HSA82390`) |
| **MBB 100GB Data (149.50 SAR)** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **19.75 OMR** (`3HSA90064`) |
| **Mazaji 160 (184.00 SAR)** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **24.30 OMR** (`3HSA24653`) |
| **80GB + 80GB Data (241.50 SAR)**| — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **31.89 OMR** (`3HSA24114`) |
| **100GB Data (253.00 SAR)** | — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **33.41 OMR** (`3HSA72502`) |
| **Mazaji Flex 300 (345.00 SAR)**| — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **45.56 OMR** (`3HSA34550`) |
| **Unlimited Data 30D (373.75 SAR)**| — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **49.36 OMR** (`3HSA19341`) |
| **250GB + 100GB Data (552.00 SAR)**| — *(Unsupported)* | — *(Unsupported)* | — *(Unsupported)* | **72.89 OMR** (`3HSA32694`) |

---

## 3. Live Test & Simulation Results

### 1. DingConnect (UAT Environment)
* **Dry-Run Test (`ValidateOnly: true`):** SKU `3HSASA63028` (15 SAR E-voucher) $\rightarrow$ `ResultCode: 1` (`ProcessingState: Complete`)
* **Live Simulation:** SKU `3HSASA63028` with UAT number `966000000000` $\rightarrow$ `ResultCode: 1`, `TransferRef: 860880446`, Delivered PIN: `001926404580`

### 2. DT One, Reloadly, & Zendit
* **Result:** No catalog inventory available across DT One, Reloadly, or Zendit for Red Bull in Saudi Arabia. Disabled in `carrier_provider_map`.

---

## 4. KeepSIMs Production Routing Decision

1. **Exclusive Primary Provider:** **DingConnect** (`3HSA` / `3HSASA63028` - 15 SAR E-voucher / 2.28 OMR).
2. **Disabled Providers:** **DT One**, **Reloadly**, and **Zendit** (`is_enabled: false`) due to absence of catalog offers.
3. **CST Rule Compliance:** 15 SAR recharge satisfies the 90-day qualifying activity window under CITC/CST regulations.
