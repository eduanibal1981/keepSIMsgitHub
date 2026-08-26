# KeepSIMs — Current Bangladesh (BD) Provider Routing Matrix

> **Country:** Bangladesh (`BD` / `+880` / `BGD`)  
> **Currency Settlement:** `OMR` (DT One / Ding) & `USD` (Reloadly / Zendit)  
> **Local Currency:** Bangladeshi Taka (`BDT` / `৳`)  
> **Regulatory Framework:** Bangladesh Telecommunication Regulatory Commission (BTRC) Standard 365-Day Inactivity Rule + 90-Day Grace/Notice Period (Total 450 Days before number recycling) + 15% VAT + 20% Supplementary Duty (SD) + 1% Surcharge  
> **Last Verified & Updated:** 2026-08-23  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Grameenphone** (Telenor Group) | MNO (National Market Leader / ~43% Share) | 🟢 **DT One** (`249`)<br>• Range: **20–1000 BDT** (`11747`)<br>• Cost: **0.078 OMR ($0.203 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Reloadly** (`26` / `834`)<br>• Range: **20–5000 BDT** ($0.18 USD)<br>• Cost: **$0.18–$44.98 USD**<br>• Delivery: Direct Recharge | 🟢 **Zendit** (`GrameenPhone`)<br>• Offer: `GRAMEENPHONE_BD_OPEN`<br>• Cost: **$0.27 USD** (21.25 BDT)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`GEBD`)<br>*(Disabled: 0 UAT offers)* | [GrameenphoneBGD.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/BGD/GrameenphoneBGD.md) |
| **Robi Axiata** (Axiata Group / Airtel) | MNO (National #2 / ~30% Share) | 🟢 **DT One** (`1446`)<br>• Range: **20–1000 BDT** (`11748`)<br>• Cost: **0.078 OMR ($0.203 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Reloadly** (`25` / `835`)<br>• Range: **20–5000 BDT** ($0.18 USD)<br>• Cost: **$0.18–$44.98 USD**<br>• Delivery: Direct Recharge | 🟢 **Zendit** (`Robi`)<br>• Offer: `ROBI_BD_OPEN`<br>• Cost: **$0.24 USD** (20 BDT)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`RLBD`)<br>*(Disabled: 0 UAT offers)* | [RobiBGD.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/BGD/RobiBGD.md) |
| **Banglalink** (VEON Subsidiary) | MNO (National #3 / ~23% Share) | 🟢 **DT One** (`1447`)<br>• Range: **20–1000 BDT** (`11745`)<br>• Cost: **0.078 OMR ($0.203 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Zendit** (`Banglalink`)<br>• Offer: `BANGLALINK_BD_OPEN`<br>• Cost: **$0.24 USD** (20 BDT)<br>• Delivery: Direct Top-Up | 🟢 **Reloadly** (`24` / `28`)<br>• Range: **20–5000 BDT** ($0.18 USD)<br>• Cost: **$0.18–$44.98 USD**<br>• Delivery: Direct Recharge | 🔴 **DingConnect** (`BGBD`)<br>*(Disabled: 0 UAT offers)* | [BanglalinkBGD.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/BGD/BanglalinkBGD.md) |
| **Teletalk Bangladesh** (State-Owned Operator) | MNO (National Gov Carrier / Prefix `+88015`) | 🟢 **DT One** (`1448`)<br>• Range: **10–1000 BDT** (`11749`)<br>• Cost: **0.039 OMR ($0.101 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Reloadly** (`27`)<br>• Range: **20–5000 BDT** (2% discount)<br>• Cost: **$0.176 USD net**<br>• Delivery: Direct Recharge | 🟢 **Zendit** (`TeleTalk`)<br>• Offer: `TELETALK_BD_OPEN`<br>• Cost: **$0.22 USD** (20 BDT)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`TQBD`)<br>*(Disabled: 0 UAT offers)* | [TeletalkBGD.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/BGD/TeletalkBGD.md) |
| **Airtel Bangladesh** (Robi Axiata Network) | Sub-Brand / MNO Rails (Prefix `+88016`) | 🟢 **DT One** (`1449`)<br>• Range: **20–1000 BDT** (`11744`)<br>• Cost: **0.078 OMR ($0.203 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Reloadly** (`28` / `832`)<br>• Range: **20–5000 BDT** ($0.18 USD)<br>• Cost: **$0.18–$44.98 USD**<br>• Delivery: Direct Recharge | 🟢 **Zendit** (`Airtel`)<br>• Offer: `AIRTEL_BD_OPEN`<br>• Cost: **$0.26 USD** (20 BDT)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`AXBD`)<br>*(Disabled: 0 UAT offers)* | [AirtelBGD.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/BGD/AirtelBGD.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Recharge USSD Format | Customer Care / Helpline |
| :--- | :---: | :---: | :---: | :--- |
| **Grameenphone** | MNO (Market Leader) | `*566#` (Main Balance) / `*121*1*2#` (Data) | `*555*<16-digit PIN>#` / MyGP | `121` / `+8801701000121` |
| **Robi Axiata** | MNO (#2 Operator) | `*222#` (Main Balance) / `*3#` (Data) | `*123*<16-digit PIN>#` / My Robi | `121` / `+8801819400400` |
| **Banglalink** | MNO (#3 Operator) | `*124#` (Main Balance) / `*5000*500#` (Data) | `*123*<16-digit PIN>#` / My Banglalink | `121` / `+8801911304121` |
| **Teletalk Bangladesh** | MNO (State-Owned) | `*152#` (Main Balance) / `*152*1#` (Data) | `*151*<16-digit PIN>#` / MyTeletalk | `121` / `+8801500121121` |
| **Airtel Bangladesh** | Sub-Brand (Robi Rails) | `*778#` (Main Balance) / `*3#` (Data) | `*123*<16-digit PIN>#` / My Airtel BD | `121` / `+8801678600786` |

---

## 3. Key Operating Principles & BTRC Regulatory Rules

1. **BTRC Bangladesh Inactivity & Line Recycling Rules:**
   - Under the Bangladesh Telecommunication Regulatory Commission (BTRC) directive, a prepaid SIM card remains valid without disconnection for **365 consecutive days (12 months)** of zero revenue-generating activity (calls, SMS, data, or recharge).
   - Following 365 days of dormancy, the operator places the line in a **90-day Notice & Grace Period** (Total: **450 days** or 15 months).
   - If no recharge or re-activation occurs during the 450-day window, the ownership is permanently extinguished, the MSISDN is recycled, and it is re-issued to the open market.

2. **Taxation & Duty on Airtime:**
   - Recharge values in Bangladesh are subject to government statutory deductions:
     * **15% Value Added Tax (VAT)**
     * **20% Supplementary Duty (SD)**
     * **1% Surcharge**
   - The effective tax rate on talk-time tariff consumption is ~33.25%, but airtime recharges via KeepSIMs deliver 100% nominal value into the main account, extending the line validity calendar regardless of tax deductions.

3. **KeepSIMs Automated Mini-Refill Strategy:**
   - Scheduled automated mini-recharges trigger on **Day 180–300** (well before the 365-day inactivity window expires).
   - Delivering a **10–20 BDT micro-refill** (costing **$0.10–$0.20 USD via DT One**) resets the BTRC 365-day countdown clock at minimal cost.

4. **Multi-Rail Failover Execution:**
   - **DT One** serves as **Primary Direct Rail (`priority: 10`, `is_primary: true`)** for all 5 operators (Grameenphone, Robi, Banglalink, Teletalk, Airtel) with open-range micro-denominations (from 10/20 BDT), instant pre-prod confirmation, and lowest wholesale base rates.
   - **Reloadly** serves as **Secondary Direct Rail (`priority: 20`)** with flexible range top-ups and curated data bundles.
   - **Zendit** serves as robust **Secondary/Tertiary Failover (`priority: 20/30`)** across all 5 operators.
   - **DingConnect** is **Disabled (`priority: 40`, `is_enabled: false`)** due to 0 active inventory in UAT.
