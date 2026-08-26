# KeepSIMs — Current Egypt (EG) Provider Routing Matrix

> **Country:** Egypt (`EG` / `+20` / `EGY`)  
> **Currency Settlement:** `USD` & `OMR` (Fixed Peg: $1\text{ OMR} = 2.6008\text{ USD}$)  
> **Local Currency:** Egyptian Pound (`EGP`)  
> **Regulatory Framework:** Egypt NTRA 90-Day Activity Rule (90 Days Active + 90 Days Suspension Quarantine)  
> **Last Verified & Updated:** 2026-08-21  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Disabled Providers | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :--- | :---: |
| **Vodafone Egypt** | MNO | 🟢 **Reloadly** (`119`)<br>• Amount: **$0.25 USD** ($0.238 net)<br>• Yield: ~8.82 EGP<br>• Delivery: **Direct Airtime** | 🟢 **Zendit** (`Vodafone`)<br>• Offer: `VODAFONE_EG_OPEN`<br>• Cost: **$0.25 USD** ($0.20 net)<br>• Delivery: Direct Airtime | 🟢 **DT One** (`716`)<br>• Product: `3912` (10 EGP)<br>• Cost: **0.095 OMR ($0.25 USD)**<br>• Delivery: Direct Airtime | 🔴 **DingConnect** (`VFEG`)<br>*(Disabled: 0 UAT offers)* | — | [VodafoneEG.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/EG/VodafoneEG.md) |
| **Orange Egypt** | MNO | 🟢 **DT One** (`190`)<br>• Product: `3913` (10 EGP)<br>• Cost: **0.092 OMR ($0.24 USD)**<br>• Delivery: **Direct Airtime (Micro)** | 🟢 **Reloadly** (`118`)<br>• Range: **$3.95 USD** ($3.83 net)<br>• Yield: ~170 EGP<br>• Delivery: Direct Airtime | 🟢 **Zendit** (`Orange`)<br>• Offer: `ORANGE_EG_OPEN`<br>• Cost: **$3.95 USD** ($3.67 net)<br>• Delivery: Direct Airtime | 🔴 **DingConnect** (`OREG`)<br>*(Disabled: 0 UAT offers)* | — | [OrangeEG.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/EG/OrangeEG.md) |
| **Etisalat Egypt** | MNO | 🟢 **Reloadly** (`120`)<br>• SKU: `rl_120_0.17` (5.10 EGP)<br>• Cost: **$0.17 USD** ($0.162 net)<br>• Delivery: **Direct Airtime** | 🟢 **Zendit** (`Etisalat`)<br>• Offer: `ETISALAT_EG_001` (5 EGP)<br>• Cost: **$0.25 USD** ($0.13 net)<br>• Delivery: Direct Airtime | 🟢 **DT One** (`1451`)<br>• Product: `3570` (10 EGP)<br>• Cost: **0.090 OMR ($0.23 USD)**<br>• Delivery: Direct Airtime | 🔴 **DingConnect** (`ETEG`)<br>*(Disabled: 0 UAT offers)* | — | [EtisalatEG.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/EG/EtisalatEG.md) |
| **WE (Telecom Egypt)** | MNO | 🟢 **Zendit** (`WETelecom`)<br>• Offer: `WETELECOM_EG_01` (100 EGP)<br>• Cost: **$2.63 USD** ($2.33 net)<br>• Delivery: **Direct Airtime** | 🟢 **DT One** (`2982`)<br>• Product: `66945` (100 EGP)<br>• Cost: **0.995 OMR ($2.59 USD)**<br>• Delivery: Direct Airtime | 🟢 **Reloadly** (`1216`)<br>• Range: **$2.93 USD** ($2.78 net)<br>• Yield: ~88 EGP<br>• Delivery: Direct Airtime | 🔴 **DingConnect** (`39EG`)<br>*(Disabled: 0 UAT offers)* | — | [WeEG.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/EG/WeEG.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Operator Type | Balance Check USSD | Manual Recharge USSD | Customer Care / IVR |
| :--- | :---: | :---: | :---: | :---: |
| **Vodafone Egypt** | MNO | `*868*1#` or `*60#` | `*858*<PIN>#` | `888` / `16888` / `+20101888888` |
| **Orange Egypt** | MNO | `*100*3#` or `#100#` | `*102*<PIN>#` | `110` / `16110` / `+201223202020` |
| **Etisalat Egypt (e&)** | MNO | `*888#` or `*555#` | `*556*<PIN>#` | `333` / `01111234333` |
| **WE (Telecom Egypt)** | MNO | `*550#` | `*555*<PIN>#` | `111` / `19777` / `+201555000111` |

---

## 3. Key Operating Principles & NTRA Regulatory Rules

1. **NTRA 90-Day Inactivity Mandate:**
   - The National Telecommunications Regulatory Authority (NTRA) requires a qualifying paid activity (recharge, paid outgoing call, SMS, or data session) at least once every **90 days**.
   - Failure to record activity triggers a 90-day quarantine/suspension phase (Days 91–180), during which outgoing service is barred.
   - Permanent termination and number recycling take effect after Day 180.

2. **KeepSIMs Automated Mini-Refill Strategy:**
   - Scheduled auto-refills trigger on **Day 80–85** to refresh the 90-day timer safely prior to suspension.
   - For **Vodafone Egypt**, **Etisalat Egypt**, and **Orange Egypt**, micro-refills between **$0.17 and $0.25 USD** are sufficient to keep the SIM card alive indefinitely.
   - For **WE (Telecom Egypt)**, the 100 EGP tier ($2.33–$2.59 USD) is utilized for maximum reliability.

3. **Multi-Rail Failover Execution:**
   - KeepSIMs workers route to Priority 1 first. If an upstream error or network timeout occurs, the request automatically cascades to Priority 2 and Priority 3.
   - DingConnect is currently disabled for Egypt due to 0 available inventory in UAT.
