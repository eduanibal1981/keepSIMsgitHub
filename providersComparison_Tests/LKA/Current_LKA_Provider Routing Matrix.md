# KeepSIMs — Current Sri Lanka (LK) Provider Routing Matrix

> **Country:** Sri Lanka (`LK` / `+94` / `LKA`)  
> **Currency Settlement:** `OMR` (DT One / Ding) & `USD` (Reloadly / Zendit)  
> **Local Currency:** Sri Lankan Rupee (`LKR` / `₨` / `Rs`)  
> **Regulatory Framework:** Telecommunications Regulatory Commission of Sri Lanka (TRCSL) Standard 180-Day Inactivity Rule + 90-Day Grace Period (Total 270 Days before number recycling) + 18% VAT + 2.5% Social Security Contribution Levy (SSCL) + Telecommunications Levy (TL)  
> **Last Verified & Updated:** 2026-08-23  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Dialog Axiata** (Axiata Group) | MNO (National Market Leader / ~57% Share) | 🟢 **DT One** (`360`)<br>• Range: **50–10000 LKR** (`11294`)<br>• Cost: **0.066 OMR ($0.171 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Reloadly** (`472` / `1180`)<br>• Fixed: **$0.38–$11.40 USD**<br>• Data: **$0.45–$8.70 USD**<br>• Delivery: Direct Recharge | 🟢 **Zendit** (`Dialog`)<br>• Offer: `DIALOG_LK_001`<br>• Cost: **$6.50 USD** (1551 LKR)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`DGLK`)<br>*(Disabled: 0 UAT offers)* | [DialogLKA.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/LKA/DialogLKA.md) |
| **Mobitel Sri Lanka** (SLT-Mobitel) | MNO (National Operator / ~26% Share) | 🟢 **DT One** (`409`)<br>• Range: **20–10000 LKR** (`11296`)<br>• Cost: **0.028 OMR ($0.072 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Reloadly** (`471`)<br>• Range: **100–3000 LKR** ($0.37 USD)<br>• Cost: **$0.37–$11.11 USD**<br>• Delivery: Direct Recharge | 🟢 **Zendit** (`Mobitel`)<br>• Offer: `MOBITEL_LK_5-I`<br>• Cost: **$5.60 USD** (772 LKR)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`MSLK`)<br>*(Disabled: 0 UAT offers)* | [MobitelLKA.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/LKA/MobitelLKA.md) |
| **Hutchison Sri Lanka** (Hutch / CK Hutchison) | MNO (~17% Share / Merged with Etisalat SL) | 🟢 **DT One** (`1609`)<br>• Range: **50–3000 LKR** (`11295`)<br>• Cost: **0.068 OMR ($0.177 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Reloadly** (`475` / `1181`)<br>• Range: **100–3000 LKR** ($0.63 USD)<br>• Data: **$0.30–$3.00 USD**<br>• Delivery: Direct Recharge | 🟢 **Zendit** (`Hutch`)<br>• Offer: `HUTCH_LK_5-I`<br>• Cost: **$5.50 USD** (792 LKR)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`HSLK`)<br>*(Disabled: 0 UAT offers)* | [HutchLKA.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/LKA/HutchLKA.md) |
| **Airtel Sri Lanka** (Merged into Dialog Rails) | MNO Sub-Brand (~3M+ Migrated Users) | 🟢 **DT One** (`360`)<br>• Range: **50–10000 LKR** (`11294`)<br>• Cost: **0.066 OMR ($0.171 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Reloadly** (`472`)<br>• Fixed: **$0.38–$11.40 USD**<br>• Cost: **$0.38 USD** (100 LKR)<br>• Delivery: Direct Recharge | 🟢 **Zendit** (`Dialog`)<br>• Offer: `DIALOG_LK_001`<br>• Cost: **$6.50 USD** (1551 LKR)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`DGLK`)<br>*(Disabled: 0 UAT offers)* | [AirtelLKA.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/LKA/AirtelLKA.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Recharge USSD Format | Customer Care / Helpline |
| :--- | :---: | :---: | :---: | :--- |
| **Dialog Axiata** | MNO (Market Leader) | `#456#` (Balance) / `#123#` (Portal) / `#678#` (Data) | `*123*<14-digit PIN>#` / MyDialog | `1777` / `+94777678678` |
| **Mobitel Sri Lanka** | MNO (SLT-Mobitel) | `#141#` (Balance) / `*141*1*1#` (Data) / `#888#` | `*102*<14-digit PIN>#` / SelfCare | `1717` / `+94712755777` |
| **Hutchison Sri Lanka** | MNO (CK Hutchison) | `*344#` (Main Portal) / `*131#` (Data) | `*102*<16-digit PIN>#` / Hutch App | `1788` / `+94785785785` |
| **Airtel Sri Lanka** | MNO Sub-Brand (Dialog Rails) | `*550#` (Legacy) / `#456#` (Dialog Menu) | `*555*<PIN>#` / `*123*<PIN>#` | `1755` / `+94755555555` |

---

## 3. Key Operating Principles & TRCSL Regulatory Rules

1. **TRCSL Sri Lanka Inactivity & Line Recycling Rules:**
   - Under the Telecommunications Regulatory Commission of Sri Lanka (TRCSL) guidelines, a prepaid SIM card remains valid for **180 consecutive days (6 months)** without recharge or revenue-generating usage.
   - Following 180 days of dormancy, the operator places the line in a **90-day Grace Period** (incoming calls and incoming SMS allowed, outgoing services suspended).
   - If no qualifying recharge occurs within the cumulative **270-day window** (180 days active + 90 days grace), ownership is permanently terminated and the MSISDN is returned to the TRCSL national number pool for recycling.

2. **Taxation & Duty on Telecom Services:**
   - Airtime and data recharges in Sri Lanka are subject to statutory government taxes:
     * **18% Value Added Tax (VAT)**
     * **2.5% Social Security Contribution Levy (SSCL)**
     * **Telecommunications Levy (TL)**
   - Effective taxation ranges between 21.5% to 42% on tariff consumption, but nominal airtime recharges via KeepSIMs deliver 100% face value into the main account, immediately refreshing the TRCSL validity calendar.

3. **KeepSIMs Automated Mini-Refill Strategy:**
   - Scheduled automated mini-recharges trigger on **Day 90–120** (well before the 180-day inactivity threshold).
   - Delivering a **20–50 LKR micro-refill** (costing **$0.07–$0.18 USD via DT One**) permanently resets the TRCSL 180-day countdown clock at ultra-low cost, preserving the user's phone number and WhatsApp/banking OTP access indefinitely.

4. **Multi-Rail Failover Execution:**
   - **DT One** serves as **Primary Direct Rail (`priority: 10`, `is_primary: true`)** for all 4 operators (Dialog, Mobitel, Hutch, Airtel) with open-range micro-denominations (from 20/50 LKR), instant pre-prod confirmation, and lowest wholesale base rates ($0.07–$0.18 USD).
   - **Reloadly** serves as **Secondary Direct Rail (`priority: 20`)** with flexible range top-ups ($0.37–$0.63 USD) and standalone 1.2GB–100GB data bundles ($0.30–$8.70 USD).
   - **Zendit** serves as robust **Tertiary Failover (`priority: 30`)** across all 4 operators.
   - **DingConnect** is **Disabled (`priority: 40`, `is_enabled: false`)** due to 0 active inventory in UAT.
