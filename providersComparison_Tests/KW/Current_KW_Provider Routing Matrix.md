# KeepSIMs — Current Kuwait (KW) Provider Routing Matrix

> **Country:** Kuwait (`KW` / `+965` / `KWT`)  
> **Currency Settlement:** `OMR` (Fixed Peg: $1\text{ OMR} = 2.6008\text{ USD}$) & `USD`  
> **Regulatory Activity Window:** CITRA Kuwait 90-Day Inactivity & Denomination Validity Rule  
> **Last Verified & Updated:** 2026-08-23  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Disabled Providers | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :--- | :---: |
| **Zain Kuwait** | MNO | 🟢 **DT One** (`1812`)<br>• Product: `24347` / `12248` (1.5 KWD)<br>• Cost: **2.359 OMR ($6.13 USD)**<br>• Delivery: **Direct Airtime** | 🟢 **Reloadly** (`268`)<br>• SKU: Fixed $5.70 Tier (~1.48 KWD)<br>• Cost: **$5.53 USD** ($5.70 - 3%)<br>• Delivery: Direct Airtime | 🔴 **Zendit** (`Zain`)<br>*(Disabled: 0 offers in KW)* | 🔴 **DingConnect** (`ZAKW`)<br>*(Disabled: 0 UAT inventory)* | **Zendit**, **DingConnect** | [ZainKW.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/KW/ZainKW.md) |
| **Ooredoo Kuwait** | MNO | 🟢 **DT One** (`1811`)<br>• Product: `24345` / `15206` (1.5 KWD)<br>• Cost: **2.353 OMR ($6.12 USD)**<br>• Delivery: **Direct Airtime** | 🟢 **Reloadly** (`1166`)<br>• SKU: Range ($5.70 USD / ~1.48 KWD)<br>• Cost: **$5.70 USD**<br>• Delivery: Direct Airtime | 🔴 **Zendit** (`Ooredoo`)<br>*(Disabled: 0 offers in KW)* | 🔴 **DingConnect** (`WTKW`)<br>*(Disabled: 0 UAT inventory)* | **Zendit**, **DingConnect** | [OoredooKW.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/KW/OoredooKW.md) |
| **STC Kuwait** | MNO | 🟢 **DT One** (`1813`)<br>• Product: `24346` / `12222` (1.5 KWD)<br>• Cost: **2.344 OMR ($6.10 USD)**<br>• Delivery: **Direct Airtime** | 🟢 **Reloadly** (`267`)<br>• SKU: Range ($7.60 USD / ~1.90 KWD)<br>• Cost: **$7.37 USD** ($7.60 - 3%)<br>• Delivery: Direct Airtime | 🔴 **Zendit** (`STC`)<br>*(Disabled: 0 offers in KW)* | 🔴 **DingConnect** (`VIKW`)<br>*(Disabled: 0 UAT inventory)* | **Zendit**, **DingConnect** | [StcKW.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/KW/StcKW.md) |
| **Virgin Mobile Kuwait** | MVNO | 🟢 **DT One** (`1813` via STC)<br>• Product: `24346` (1.5 KWD)<br>• Cost: **2.344 OMR ($6.10 USD)**<br>• Delivery: **Direct / STC Host** | 🟢 **Reloadly** (`267` via STC)<br>• SKU: Range ($7.60 USD)<br>• Cost: **$7.37 USD**<br>• Delivery: Direct / STC Host | 🔴 **Zendit** (`Virgin Mobile`)<br>*(Disabled: 0 offers in KW)* | 🔴 **DingConnect** (`VIKW`)<br>*(Disabled: 0 UAT inventory)* | **Zendit**, **DingConnect** | [VirginKW.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/KW/VirginKW.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Host Network | Balance Check USSD | Manual Recharge USSD | Customer Care / IVR |
| :--- | :--- | :---: | :---: | :---: |
| **Zain Kuwait** | Zain | `*142#` or `*107#` | `*141*<PIN>#` | `107` / `+965 97107107` |
| **Ooredoo Kuwait** | Ooredoo | `*121#` or `*555#` | `*111*<PIN>#` | `121` / `+965 1805555` |
| **STC Kuwait** | STC | `*555#` or `*100#` | `*500*<PIN>#` | `102` / `+965 55102102` |
| **Virgin Mobile Kuwait**| STC | `*102#` or App | `*500*<PIN>#` or App | `1789` / `+965 51001789` |

---

## 3. Key Operating Principles

1. **DT One Primary for Kuwait Direct Airtime:**
   - DT One provides open-range and granular micro-recharge fixed products starting at **1.50 KWD** (~2.344–2.361 OMR / ~$6.10–$6.14 USD) across all Kuwaiti operators.
   - Delivers verified instant API fulfillment directly into the subscriber's line.
   - Assigned `priority: 10`, `is_primary: true`.

2. **Reloadly Secondary Failover:**
   - Reloadly offers active direct top-up routes for all 3 Kuwaiti networks (Zain `268`, Ooredoo `1166`, STC `267`).
   - Entry amounts start from $5.70 USD with automatic 3% commission discount.
   - Assigned `priority: 20`, `is_primary: false`.

3. **Disabled Providers (Zero Inventory / UAT Outage):**
   - **Zendit:** 0 active offers in country `KW` catalog (`is_enabled: false`, `priority: 30`).
   - **DingConnect:** Catalog returns 503 / 0 active products in UAT (`is_enabled: false`, `priority: 40`).

4. **CITRA Kuwait Regulatory Framework Compliance:**
   - Kuwait CITRA rules bind line validity to recharge denomination (1.5 KWD = 7–14 days, 3–5 KWD = 30 days, 10 KWD = 90–180 days, 25 KWD = 365 days).
   - Upon balance expiry, lines enter a 90-day grace period. After 180 total days of inactivity, the number is quarantined and permanently recycled.
   - KeepSIMs schedules automated mini-refills on **Day 60–80** to continuously extend line validity and guarantee the user's SIM number remains active without risk of churn.
