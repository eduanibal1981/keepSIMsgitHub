# KeepSIMs — Current Pakistan (PK) Provider Routing Matrix

> **Country:** Pakistan (`PK` / `+92` / `PAK`)  
> **Currency Settlement:** `OMR` (DT One / Ding) & `USD` (Zendit / Reloadly)  
> **Local Currency:** Pakistani Rupee (`PKR` / `₨`)  
> **Regulatory Framework:** Pakistan Telecommunication Authority (PTA) Standard 180-Day Inactivity Rule + 30-Day Suspension Grace Period  
> **Last Verified & Updated:** 2026-08-22  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Jazz** (Mobilink / Warid) | MNO (National Leader) | 🟢 **DT One** (`400`)<br>• Product: `3760` (100 PKR)<br>• Cost: **0.168 OMR ($0.44 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Reloadly** (`354`)<br>• Range: 200–10000 PKR<br>• Cost: **$0.78 USD** (200 PKR net)<br>• Delivery: Direct Top-Up | 🟢 **Zendit** (`Jazz`)<br>• Offer: `JAZZ_PK_OPEN`<br>• Cost: **$0.38 USD** (98 PKR min)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`MBPK`)<br>*(Disabled: 0 UAT offers)* | [JazzPK.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/PK/JazzPK.md) |
| **Telenor Pakistan** | MNO (National) | 🟢 **DT One** (`655`)<br>• Product: `3378` (100 PKR)<br>• Cost: **0.168 OMR ($0.44 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Reloadly** (`353`)<br>• Range: 100–5000 PKR<br>• Cost: **$0.39 USD** (100 PKR net)<br>• Delivery: Direct Top-Up | 🟢 **Zendit** (`Telenor`)<br>• Offer: `TELENOR_PK_OPEN`<br>• Cost: **$0.30 USD** (78 PKR min)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`TPPK`)<br>*(Disabled: 0 UAT offers)* | [TelenorPK.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/PK/TelenorPK.md) |
| **Zong** (CMPak / China Mobile) | MNO (Pure 4G Pioneer) | 🟢 **DT One** (`1515`)<br>• Product: `3923` (100 PKR)<br>• Cost: **0.168 OMR ($0.44 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Reloadly** (`352`)<br>• Range: 100–10000 PKR<br>• Cost: **$0.39 USD** (100 PKR net)<br>• Delivery: Direct Top-Up | 🟢 **Zendit** (`Zong`)<br>• Offer: `ZONG_PK_OPEN`<br>• Cost: **$0.30 USD** (78 PKR min)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`ZNPK`)<br>*(Disabled: 0 UAT offers)* | [ZongPK.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/PK/ZongPK.md) |
| **Ufone** (PTCL Group) | MNO (National) | 🟢 **DT One** (`486`)<br>• Product: `2788` (100 PKR)<br>• Cost: **0.168 OMR ($0.44 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Reloadly** (`355`)<br>• Range: 100–10000 PKR<br>• Cost: **$0.39 USD** (100 PKR net)<br>• Delivery: Direct Top-Up | 🟢 **Zendit** (`Ufone`)<br>• Offer: `UFONE_PK_OPEN`<br>• Cost: **$0.37 USD** (99 PKR min)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`UFPK`)<br>*(Disabled: 0 UAT offers)* | [UfonePK.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/PK/UfonePK.md) |
| **Onic Pakistan** | Digital MVNO (Ufone Host) | 🟢 **DT One** (`486`)<br>• Via Ufone Rails (100 PKR)<br>• Cost: **0.168 OMR ($0.44 USD)**<br>• Delivery: **Direct via Ufone** | 🟢 **Reloadly** (`355`)<br>• Via Ufone Rails (100 PKR)<br>• Cost: **$0.39 USD** (100 PKR net)<br>• Delivery: Direct via Ufone | 🟢 **Zendit** (`Ufone`)<br>• Via Ufone Rails<br>• Cost: **$0.37 USD** (99 PKR min)<br>• Delivery: Direct via Ufone | 🔴 **DingConnect** (`UFPK`)<br>*(Disabled: 0 UAT offers)* | [OnicPK.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/PK/OnicPK.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Recharge USSD Format | Customer Care / Helpline |
| :--- | :---: | :---: | :---: | :--- |
| **Jazz** (Mobilink / Warid) | MNO (National Leader) | `*111#` (0.24 PKR fee) / Jazz World App | `*123*<14-digit PIN>#` | `111` / `042-111-300-300` / `+923000000111` |
| **Telenor Pakistan** | MNO (National) | `*444#` (0.24 PKR fee) / My Telenor App | `*555*<14-digit PIN>#` | `345` / `042-111-345-100` / `+923451111345` |
| **Zong** (CMPak) | MNO (Pure 4G Pioneer) | `*222#` (0.24 PKR fee) / My Zong App | `*101*<14-digit PIN>#` | `310` / `051-111-222-111` / `+923101111310` |
| **Ufone** (PTCL Group) | MNO (National) | `*124#` (0.24 PKR fee) / My Ufone App | `*333*<14-digit PIN>#` | `333` / `051-111-333-100` / `+923331111333` |
| **Onic Pakistan** | Digital MVNO (Ufone Core) | Onic Mobile App / onic.pk | Digital in-app reload / Ufone rails | `hello@onic.pk` / Onic In-App Support |

---

## 3. Key Operating Principles & PTA Regulatory Rules

1. **PTA 180-Day Inactivity Mandate:**
   - Under Pakistan Telecommunication Authority (PTA) regulations, all prepaid SIM cards remain active for **180 days** from the date of the last qualifying paid event or recharge.
   - If no qualifying transaction occurs within 180 days, the line enters a **30-day grace/suspension period** (Days 180–210), where outgoing services are barred.
   - If unrefilled after 210 days total, the SIM card is permanently disconnected, credit forfeited, and the MSISDN returned to the PTA national pool for reissuance after biometric clearance.

2. **Pakistani Tax Structure on Mobile Top-Ups:**
   - The Federal Board of Revenue (FBR) and provincial revenue authorities levy a 15% Advance Income Tax (AIT / WHT) and 19.5% Sales Tax (FED/GST) on mobile services.
   - When a 100 PKR top-up is delivered, the customer receives approximately **86.96 PKR** in main balance after 15% WHT deduction, which fully resets the 180-day PTA validity counter.

3. **KeepSIMs Automated Mini-Refill Strategy:**
   - Scheduled automated mini-recharges trigger on **Day 150–165** (before the 180-day suspension threshold).
   - Delivering a 100 PKR top-up (~0.168 OMR / ~$0.44 USD via DT One) or smaller micro-packs (40 PKR Weekly SMS on Jazz at 0.068 OMR / ~$0.18 USD, 60 PKR on Zong/Ufone at ~0.10 OMR / ~$0.26 USD) maintains continuous active two-way service indefinitely.

4. **Multi-Rail Failover Execution:**
   - **DT One** serves as the **Primary Rail (`priority: 10`, `is_primary: true`)** for all Pakistan carriers due to its catalog of 180–220 products per carrier, low wholesale pricing (0.168 OMR for 100 PKR), and 100% pre-prod transaction confirmation (`201 Created`).
   - **Reloadly** serves as the **Secondary Failover (`priority: 20`)**, providing flexible open-range airtime (100–10,000 PKR) with a 5% discount.
   - **Zendit** provides **Tertiary Failover (`priority: 30`)**, supporting open-range top-ups and standardized bundles.
   - **DingConnect** is **Disabled (`priority: 40`, `is_enabled: false`)** due to 0 active inventory in UAT.