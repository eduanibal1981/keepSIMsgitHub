# KeepSIMs — Current India (IN) Provider Routing Matrix

> **Country:** India (`IN` / `+91` / `IND`)  
> **Currency Settlement:** `OMR` (DT One / Ding) & `USD` (Zendit / Reloadly)  
> **Local Currency:** Indian Rupee (`INR` / `₹`)  
> **Regulatory Framework:** Telecom Regulatory Authority of India (TRAI) 90-Day Non-Usage Rule (BSNL: 180 Days) + 15-Day Reactivation Grace  
> **Last Verified & Updated:** 2026-08-22  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Reliance Jio** | MNO (National Leader) | 🟢 **DT One** (`2808`)<br>• Product: `18922` (349 INR 28d)<br>• Cost: **1.648 OMR ($4.28 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Zendit** (`Jio`)<br>• Offer: `JIO_IN_3-I-BUNDLE`<br>• Cost: **$3.08 USD** (239 INR)<br>• Delivery: Direct Bundle | 🟢 **Reloadly** (`786`)<br>• Operator: `786`<br>• Cost: Catalog Mapped<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`RJIN`)<br>*(Disabled: 0 UAT offers)* | [JioIN.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/IN/JioIN.md) |
| **Bharti Airtel** | MNO (National) | 🟢 **DT One** (`1371`)<br>• Product: `8141` (10 INR TT)<br>• Cost: **0.048 OMR ($0.12 USD)**<br>• Delivery: **Direct Micro-Recharge** | 🟢 **Zendit** (`Airtel`)<br>• Offer: `AIRTEL_IN_4.5-I-BUNDLE`<br>• Cost: **$4.51 USD** (349 INR)<br>• Delivery: Direct Bundle | 🟢 **Reloadly** (`200`)<br>• Operator: `200`<br>• Cost: Catalog Mapped<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`AIIN`)<br>*(Disabled: 0 UAT offers)* | [AirtelIN.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/IN/AirtelIN.md) |
| **Vodafone Idea (Vi)** | MNO (National) | 🟢 **DT One** (`2016`)<br>• Product: `28303` (10 INR TT)<br>• Cost: **0.048 OMR ($0.12 USD)**<br>• Delivery: **Direct Micro-Recharge** | 🟢 **Zendit** (`VodafoneIdea`)<br>• Offer: `VODAFONEIDEA_IN_4.5-I-BUNDLE`<br>• Cost: **$3.86 USD** (299 INR)<br>• Delivery: Direct Bundle | 🟢 **Reloadly** (`716`)<br>• Operator: `716`<br>• Cost: Catalog Mapped<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`VFIN`)<br>*(Disabled: 0 UAT offers)* | [ViIN.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/IN/ViIN.md) |
| **BSNL** | MNO (State-Owned) | 🟢 **DT One** (`1420`)<br>• Product: `11087` (10 INR TT)<br>• Cost: **0.048 OMR ($0.12 USD)**<br>• Delivery: **Direct Micro-Recharge** | 🟢 **Zendit** (`BSNL`)<br>• Offer: `BSNL_IN_2.7-I-BUNDLE`<br>• Cost: **$2.57 USD** (199 INR)<br>• Delivery: Direct Bundle | 🟢 **Reloadly** (`193`)<br>• Operator: `193`<br>• Cost: Catalog Mapped<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`BLIN`)<br>*(Disabled: 0 UAT offers)* | [BsnlIN.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/IN/BsnlIN.md) |
| **MTNL** | MNO (Delhi & Mumbai) | 🟢 **DT One** (`368`)<br>• Product: `13500` (10 INR TT)<br>• Cost: **0.048 OMR ($0.12 USD)**<br>• Delivery: **Exclusive Direct Route** | 🔴 **Zendit** (`MTNL`)<br>*(Disabled: 0 offers)* | 🔴 **Reloadly** (`194`)<br>*(Disabled: 503 Inactive)* | 🔴 **DingConnect** (`MNIN`)<br>*(Disabled: 0 UAT offers)* | [MtnlIN.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/IN/MtnlIN.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Customer Care / IVR | Notes |
| :--- | :---: | :---: | :---: | :--- |
| **Reliance Jio** | MNO (Pure 4G/5G) | Dial `1299` (SMS) or `*333#` | `198` / `199` / `+919888898888` | Mandatory Service / Data packs required for active service |
| **Bharti Airtel** | MNO (National) | `*121#` or `*123#` | `121` / `198` / `+919810198101` | Micro-talktime (₹10) or unlimited service validity packs |
| **Vodafone Idea (Vi)** | MNO (National) | `*199#` or `*111#` | `199` / `198` / `+919820098200` | 83 DT One SKU options covering all regional circles |
| **BSNL** | MNO (State-Owned) | `*123#` or `*124#` | `1503` / `1800-180-1503` | Extended 180-day inactivity threshold |
| **MTNL** | MNO (Metro) | `*444#` or `*123#` | `1500` / `1800-22-1500` | Operational in Delhi NCR & Mumbai metro circles |

---

## 3. Key Operating Principles & TRAI Regulatory Rules

1. **TRAI 90-Day Inactivity Mandate:**
   - Under the Telecom Regulatory Authority of India (TRAI) directives, a prepaid mobile connection with continuous non-usage (no voice calls, SMS, data, or recharge) for **90 consecutive days** is flagged for deactivation.
   - If the main account balance is $\ge$ Rs. 20, operators may auto-deduct non-usage fees to maintain the line until balance drops below Rs. 20.
   - A **15-day grace period** applies following the 90 days before final number disconnection and return to the national numbering pool.
   - **BSNL Exception:** BSNL operates under an extended **180-day inactivity window**.

2. **KeepSIMs Automated Mini-Refill Strategy:**
   - Scheduled auto-refills trigger on **Day 80–85** (BSNL: Day 165–175) to refresh the inactivity timer and preserve the SIM number indefinitely.
   - For **Bharti Airtel**, **Vodafone Idea**, **BSNL**, and **MTNL**, micro-recharges at **₹10 INR (0.048 OMR / ~$0.12 USD)** via **DT One** provide the world's most economical line maintenance rail.
   - For **Reliance Jio**, validity service packs (e.g. ₹239–₹349 INR / $3.08–$4.28 USD) deliver full service renewal.

3. **Multi-Rail Failover Execution:**
   - **DT One** serves as the **Primary Rail (`priority: 10`, `is_primary: true`)** for all 5 Indian carriers due to its complete catalog coverage, ultra-low wholesale pricing (from 0.048 OMR), and 100% pre-prod transaction confirmation.
   - **Zendit** serves as the **Secondary Failover (`priority: 20`)** providing pre-packaged data/voice validity bundles.
   - **Reloadly** provides **Tertiary Sandbox Backup (`priority: 30`)**.
   - **DingConnect** is **Disabled (`priority: 40`, `is_enabled: false`)** due to 0 active inventory in the UAT environment.
