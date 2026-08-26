# KeepSIMs — Current Philippines (PH) Provider Routing Matrix

> **Country:** Philippines (`PH` / `+63` / `PHL`)  
> **Currency Settlement:** `OMR` (DT One / Ding) & `USD` (Zendit / Reloadly)  
> **Local Currency:** Philippine Peso (`PHP` / `₱`)  
> **Regulatory Framework:** National Telecommunications Commission (NTC) / DICT 1-Year (365 Days) Prepaid Load Validity Rule (MC 05-12-2017 / RA 10929) + 90–180 Days Zero-Balance Deactivation Window  
> **Last Verified & Updated:** 2026-08-22  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Globe Telecom** | MNO (National) | 🟢 **DT One** (`246`)<br>• Product: `12824` (10 PHP)<br>• Cost: **0.076 OMR ($0.198 USD)**<br>• Delivery: **Direct Micro-Recharge** | 🟢 **Reloadly** (`371`)<br>• Operator: `371`<br>• Cost: **$0.18 USD** (10 PHP)<br>• Delivery: Direct Top-Up | 🟢 **Zendit** (`Globe`)<br>• Offer: `GLOBE_PH_8_FEE`<br>• Cost: **$7.76 USD** (400 PHP)<br>• Delivery: Direct Recharge | 🔴 **DingConnect** (`GBPH`)<br>*(Disabled: 0 UAT offers)* | [GlobePH.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/PH/GlobePH.md) |
| **Smart Communications** | MNO (National) | 🟢 **DT One** (`570`)<br>• Product: `22752` (5 PHP) / `7684` (10 PHP)<br>• Cost: **0.037–0.074 OMR ($0.10–$0.19 USD)**<br>• Delivery: **Direct Micro-Recharge** | 🟢 **Reloadly** (`372`)<br>• Operator: `372`<br>• Cost: **$0.27 USD** (14.74 PHP)<br>• Delivery: Direct Range | 🟢 **Zendit** (`Smart`)<br>• Offer: `SMART_PH_6_FEE`<br>• Cost: **$6.20 USD** (300 PHP)<br>• Delivery: Direct Recharge | 🔴 **DingConnect** (`SMPH`)<br>*(Disabled: 0 UAT offers)* | [SmartPH.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/PH/SmartPH.md) |
| **DITO Telecommunity** | MNO (3rd Telco) | 🟢 **Zendit** (`Dito`)<br>• Offer: `DITO_PH_001`<br>• Cost: **$4.52 USD** (200 PHP)<br>• Delivery: **Exclusive Active Route** | 🔴 **Reloadly** (`1182`)<br>*(Disabled in sandbox: 409)* | 🔴 **DT One**<br>*(0 catalog products)* | 🔴 **DingConnect** (`DWPH`)<br>*(Disabled: 0 UAT offers)* | [DitoPH.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/PH/DitoPH.md) |
| **TM (Touch Mobile)** | MNO Sub-Brand (Globe) | 🟢 **DT One** (`3128`)<br>• Product: `23309` (10 PHP)<br>• Cost: **0.076 OMR ($0.198 USD)**<br>• Delivery: **Direct Micro-Recharge** | 🟢 **Reloadly** (`723`)<br>• Operator: `723`<br>• Cost: **$0.18 USD** (10 PHP)<br>• Delivery: Direct Top-Up | 🟢 **Zendit** (`TouchMobile`)<br>• Offer: `TOUCHMOBILE_PH_001`<br>• Cost: **$3.39 USD** (150 PHP)<br>• Delivery: Direct Recharge | 🔴 **DingConnect** (`TMPH`)<br>*(Disabled: 0 UAT offers)* | [TM_PH.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/PH/TM_PH.md) |
| **TNT (Talk 'N Text)** | MNO Sub-Brand (Smart) | 🟢 **DT One** (`2897`)<br>• Product: `18948` (5 PHP) / `18936` (10 PHP)<br>• Cost: **0.037–0.074 OMR ($0.10–$0.19 USD)**<br>• Delivery: **Direct Micro-Recharge** | 🟢 **Reloadly** (`378`)<br>• Operator: `378`<br>• Cost: **$0.18 USD** (10 PHP)<br>• Delivery: Direct / PIN | 🟢 **Zendit** (`TNT`)<br>• Offer: `TNT_PH_001`<br>• Cost: **$5.42 USD** (318 PHP)<br>• Delivery: Direct Recharge | 🔴 **DingConnect** (`STPH`)<br>*(Disabled: 0 UAT offers)* | [TNT_PH.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/PH/TNT_PH.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Customer Care / IVR | Notes |
| :--- | :---: | :---: | :---: | :--- |
| **Globe Telecom** | MNO (National) | `*143#` or text `BAL` to `222` | `211` / `(02) 7730-1000` | 22 DT One products covering micro-load and GoSURF/GoUNLI |
| **Smart Communications** | MNO (National) | `*123#` or text `BAL` to `214` | `*888` / `(02) 8888-1111` | 38 DT One products covering micro-load and GIGA Video/Stories |
| **DITO Telecommunity** | MNO (Pure VoLTE) | `*185#` or via DITO App | `185` / `(02) 8888-3486` | Strict 90-day inactivity threshold on balance < 1 PHP |
| **TM (Touch Mobile)** | MNO Sub-Brand (Globe) | `*143#` or text `BAL` to `222` | `808` / `(02) 7730-1500` | 18 DT One products from 10 PHP |
| **TNT (Talk 'N Text)** | MNO Sub-Brand (Smart) | `*123#` or text `BAL` to `214` | `*888` / `(02) 8888-1111` | 39 DT One products covering 5–1000 PHP and SURFSAYA |

---

## 3. Key Operating Principles & NTC/DICT Regulatory Rules

1. **NTC-DICT 1-Year Prepaid Load Validity Mandate:**
   - Under **Republic Act No. 10929** and **NTC-DICT Memorandum Circular No. 05-12-2017**, all prepaid load credits purchased (regardless of denomination, even micro-recharges of 5 or 10 PHP) carry a minimum validity of **one (1) year (365 days)** from the top-up date.

2. **Zero-Balance Inactivity & SIM Card Deactivation Rules:**
   - **Globe Telecom & TM (Touch Mobile):** Once the balance reaches zero, the subscriber has a **120-day grace period** (4 months) of consecutive zero balance without reloading before the SIM card is permanently deactivated and the mobile number returned to the national numbering pool.
   - **Smart Communications & TNT (Talk 'N Text):** Once the balance drops to zero, subscribers have a **180-day grace period** (6 months) to reload before disconnection.
   - **DITO Telecommunity:** DITO enforces a strict **90-day non-usage limit** if the main balance remains below **PHP 1.00** without an active data/promo package.

3. **KeepSIMs Automated Mini-Refill Strategy:**
   - For **Globe Telecom** and **TM (Touch Mobile)**: Auto-refill of **10 PHP (0.076 OMR / ~$0.198 USD)** triggers on **Day 100–110** of zero-balance or before load expiration.
   - For **Smart Communications** and **TNT (Talk 'N Text)**: Auto-refill of **5–10 PHP (0.037–0.074 OMR / ~$0.10–$0.19 USD)** triggers on **Day 150–165** of zero-balance.
   - For **DITO Telecommunity**: Auto-refill triggers on **Day 80–85** using Zendit ($4.52 USD / 200 PHP) to keep the SIM card active.

4. **Multi-Rail Failover Execution:**
   - **DT One** serves as the **Primary Rail (`priority: 10`, `is_primary: true`)** for Globe, Smart, TM, and TNT due to its unmatched catalog depth (18–39 SKUs per operator), rock-bottom micro-load pricing (5–10 PHP), and 100% pre-prod transaction confirmation.
   - **Zendit** serves as the **Primary Rail (`priority: 10`, `is_primary: true`)** for DITO Telecommunity, and **Tertiary Failover (`priority: 30`)** for Globe, Smart, TM, and TNT.
   - **Reloadly** provides **Secondary Direct Failover (`priority: 20`)** for Globe, Smart, TM, and TNT with verified real-time delivery.
   - **DingConnect** is **Disabled (`priority: 40`, `is_enabled: false`)** due to 0 active inventory in the UAT environment.
