# Provider Comparison & Test Report: Vodafone Oman

> **Country:** Oman (`OM` / `+968` / `OMN`)  
> **Carrier:** Vodafone Oman (Oman Future Telecommunications / Vodafone Partner Market)  
> **Network Type:** MNO (3rd National Carrier, 100% Cloud-Native 5G)  
> **Balance USSD / SMS:** Vodafone App / Dial `*777#` | **Recharge USSD:** `*777*<PIN>#` / In-App  
> **Customer Care:** `1771` (In Oman) / `+96877101771` (International)  
> **Regulatory Policy (TRA Oman):** Active validity refreshed through digital subscriptions, flexi-packs, or refills (90–180 Days active cycle) + 30 Days Grace Period  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DingConnect** (`ding`) | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `OM` (ISO-2) | `OMN` (ISO-3) | `OM` (ISO-2) | `OM` (ISO-2) |
| **Carrier / Operator Code** | `VFOM` ("Vodafone Oman") | `Vodafone` | `Vodafone` | `Vodafone` |
| **Delivery Mechanism** | Direct Top-Up (UAT Mapped) | Unsupported in Pre-Prod | Unsupported in Sandbox | Unsupported in Catalog |
| **Settlement Currency** | **`OMR`** | **`OMR`** | **`USD`** | **`USD`** |
| **Catalog Format** | Direct Top-Up via `VFOM` | 0 Active Products | 0 Active Products | 0 Active Products |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Mapped Route** (`is_primary: true`, `priority: 10`) | 🔴 **Disabled** (`priority: 20`) | 🔴 **Disabled** (`priority: 30`) | 🔴 **Disabled** (`priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (OMR) | DingConnect Direct (`VFOM`) | DT One Wholesale (`OMN`) | Reloadly Wholesale (`OM`) | Zendit Direct (`OM`) |
| :---: | :---: | :---: | :---: | :---: |
| **1.00–20.00 OMR** | 🟢 Mapped (`VFOM`) | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DingConnect (UAT Environment)
* **Provider Code:** `VFOM` ("Vodafone Oman")
* **Validation Regex:** `^968[0-9]{8}$|^0000000000$`
* **Status:** Verified mapped in DingConnect international catalog (`RegionCodes: ["OM"]`, `PaymentTypes: ["Prepaid"]`).
* **Result:** **Primary Mapped Route** (`priority: 10`, `is_primary: true`).

### 2. DT One / Reloadly / Zendit
* **Status:** Currently not cataloged in DT One pre-prod, Reloadly sandbox, or Zendit OM catalog.
* **Result:** **Disabled Providers** (`is_enabled: false`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Route:** **DingConnect** (`providerCode: VFOM` — provider mapping registered for Vodafone Oman subscribers, `priority: 10`, `is_primary: true`).
2. **Secondary / Digital Direct Refills:** Vodafone Oman operates as an app-centric next-generation telecom. In-app digital subscription payments and direct voucher integrations are prioritized.
3. **TRA Oman Regulatory Compliance:**
   - Vodafone Oman prepaid accounts maintain active validity refreshed through recurring monthly plans or top-up credits.
   - If inactive, lines enter a **30-day suspension period** before permanent disconnection and number recycling.
   - KeepSIMs monitors the active validity cycle and executes scheduled refills before the 90/180-day threshold.
