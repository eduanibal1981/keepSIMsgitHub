# KeepSIMs — Current Lebanon (LB) Provider Routing Matrix

> **Country:** Lebanon (`LB` / `+961` / `LBN`)  
> **Currency Settlement:** `OMR` (DT One / DingConnect) & `USD` (Zendit / Reloadly)  
> **Local Currency:** Lebanese Pound (`LBP` / `ل.ل`) / Official Sayrafa USD Tariff Standard  
> **Regulatory Framework:** Ministry of Telecommunications (MoT) Lebanon Inactivity & Validity Mandates (Denomination-scaled validity ladder: 13–370 Days; 12-Day Retention Receive-Only Window; 60-Day Suspension Grace Period before Number Disconnection & Recycling)  
> **Last Verified & Updated:** 2026-08-23  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Touch Lebanon** (MIC2 / Zain Group) | MNO (National Market Leader / ~53% Share) | 🟢 **DT One** (`2794`)<br>• Denom: **$3.79–$77.28 USD** (`44310`–`44317`)<br>• Cost: **2.116–40.970 OMR** (~$5.50–$106.52 USD)<br>• Delivery: **Direct Top-Up** | 🟢 **Zendit** (`Touch`)<br>• Denom: **6 Offers** (`TOUCH_LB_001_USD`–`006_USD`)<br>• Cost: **$6.00–$118.00 USD** ($3.79–$77.28 send)<br>• Delivery: Direct Top-Up | 🟢 **Reloadly** (`276`)<br>• Denom: **$25.40 USD**<br>• Cost: **$25.40 USD**<br>• Delivery: Digital PIN Voucher | 🔴 **DingConnect** (`TMLB`)<br>*(Disabled: 0 UAT offers)* | [TouchLBN.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/LBN/TouchLBN.md) |
| **Alfa Lebanon** (MIC1 / Orascom TMT) | MNO (Major National Operator / ~47% Share) | 🟢 **DT One** (`2793`)<br>• Denom: **$1.22–$77.28 USD** (`44471`–`44478`)<br>• Cost: **0.751–40.970 OMR** (~$1.95–$106.52 USD)<br>• Delivery: **Direct Top-Up (Micro-Refill)** | 🟢 **Zendit** (`Alfa`)<br>• Denom: **7 Offers** (`ALFA_LB_001`–`008`)<br>• Cost: **$2.50–$161.00 USD** ($1.22–$77.28 send)<br>• Delivery: Direct Top-Up | 🟢 **Reloadly** (`1017`)<br>• Denom: **$25.40 USD**<br>• Cost: **$25.40 USD**<br>• Delivery: Digital PIN Voucher | 🔴 **DingConnect** (`AALB`)<br>*(Disabled: 0 UAT offers)* | [AlfaLBN.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/LBN/AlfaLBN.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Recharge USSD Format | Customer Care / Helpline |
| :--- | :---: | :---: | :---: | :--- |
| **Touch Lebanon** | MNO (Zain Group) | `*220#` or `*111#` / SMS to `1144` / touch App | `*200*<14-digit PIN>#` or `*220*<PIN>#` / touch App | `111` / `+9613792111` / `1788` |
| **Alfa Lebanon** | MNO (Orascom TMT) | `*111#` or `*140#` / SMS to `1050` / Alfa App | `*141*<14-digit PIN>#` or Alfa App | `111` / `+9613391111` / `+9613030000` |

---

## 3. Key Operating Principles & MoT Lebanon Regulatory Rules

1. **Official Sayrafa USD Tariff Architecture:**
   - The Lebanese Ministry of Telecommunications (MoT) pegs mobile telecommunications top-up tariffs to official Sayrafa USD benchmark denominations.
   - Recharges grant active line validity scaling with the recharge value:
     * **$1.22 USD (Alfa):** Micro-refill balance boost.
     * **$3.03 USD (Alfa):** Extends active line validity by **13 days**.
     * **$3.79 USD (Touch):** Extends active line validity by **15 days**.
     * **$4.50 USD (Touch / Alfa):** Extends active line validity by **35 days** (Standard Monthly Extension).
     * **$7.58 USD (Touch / Alfa):** Extends active line validity by **35 days** (High Data / Voice balance).
     * **$15.15 USD (Touch / Alfa):** Extends active line validity by **65 days**.
     * **$22.73 USD (Touch / Alfa):** Extends active line validity by **95 days**.
     * **$77.28 USD (Touch / Alfa):** Extends active line validity by **365–370 days (1 Full Year)**.

2. **Inactivity, Retention & Line Suspension Lifecycle:**
   - When active line validity expires, the line enters an immediate **12-day Retention Period** (incoming calls and SMS are active; outgoing services are barred).
   - If unrefilled during retention, the SIM transitions into a **60-day Suspension Grace Period** where remaining credit is frozen.
   - If no qualifying top-up is completed by the end of the 60-day suspension window (total ~72 days without valid active recharge), the line is permanently disconnected, remaining balance is forfeited, and the mobile number is recycled into the MoT national pool.

3. **KeepSIMs Automated Maintenance Strategy:**
   - For **Alfa Lebanon**, KeepSIMs executes scheduled mini-refills every **25–30 days** using the lowest entry $1.22 micro-refill (0.751 OMR / ~$1.95 USD via DT One) or the $4.50 USD tier (2.487 OMR / ~$6.47 USD for 35 days validity).
   - For **Touch Lebanon**, KeepSIMs triggers scheduled refills every **25–30 days** using the $4.50 USD tier (2.487 OMR / ~$6.47 USD via DT One) for guaranteed 35-day active validity.

4. **Multi-Rail Failover Execution:**
   - **Primary Direct Route:** **DT One** (`priority: 10`, `is_primary: true`) across both carriers for direct account credit injection and micro-refills.
   - **Secondary Direct Route:** **Zendit** (`priority: 20`, `is_enabled: true`) across both carriers for multi-tier API top-up fallback.
   - **Tertiary PIN Failover:** **Reloadly** (`priority: 30`, `is_enabled: true`) across both carriers for $25.40 USD emergency voucher PIN delivery.
   - **Quaternary Route:** **DingConnect** (`priority: 40`, `is_enabled: false`) disabled due to 0 active UAT offers.
