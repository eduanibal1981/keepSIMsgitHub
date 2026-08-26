# KeepSIMs — Current Qatar (QA) Provider Routing Matrix

> **Country:** Qatar (`QA` / `+974` / `QAT`)  
> **Currency Settlement:** `USD` (Reloadly / Zendit) & `OMR` (DT One / DingConnect)  
> **Local Currency:** Qatari Riyal (`QAR` / `ر.ق` — Pegged: 1 USD = 3.64 QAR)  
> **Regulatory Framework:** Communications Regulatory Authority (CRA) Qatar Inactivity Mandates (Ooredoo Hala: 120-Day Limit + 60-Day Grace; Vodafone Qatar: 180-Day Line Validity + 180-Day Grace)  
> **Last Verified & Updated:** 2026-08-23  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Ooredoo Qatar** (Hala / Shahry) | MNO (Incumbent Market Leader / ~70% Share) | 🟢 **Reloadly** (`396`)<br>• Denom: **100–200 QAR**<br>• Cost: **$39.76–$79.52 USD** (1% disc)<br>• Delivery: **Direct Top-Up** | 🟢 **DT One** (`511`)<br>• Denom: **80–150 QAR** (`33349`/`1738`)<br>• Cost: **10.252–19.221 OMR**<br>• Delivery: Data PIN Voucher | 🔴 **Zendit** (`Ooredoo`)<br>*(Disabled: 0 catalog offers)* | 🔴 **DingConnect** (`OOQA`)<br>*(Disabled: 0 UAT offers)* | [OoredooQAT.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/QAT/OoredooQAT.md) |
| **Vodafone Qatar** (Prepaid / Flex / Combo) | MNO (#2 National Operator / ~30% Share) | 🟢 **DT One** (`2722`)<br>• Denom: **10–300 QAR** (`17355`–`17362`)<br>• Cost: **1.288–38.664 OMR** (~$3.35+ USD)<br>• Delivery: **Digital PIN Voucher** | 🟢 **Reloadly** (`395`)<br>• Denom: **$3.60–$35.60 USD**<br>• Cost: **$3.564–$35.244 USD** (1% disc)<br>• Delivery: Digital PIN Voucher | 🔴 **Zendit** (`Vodafone`)<br>*(Disabled: 0 catalog offers)* | 🔴 **DingConnect** (`VFQA`)<br>*(Disabled: 0 UAT offers)* | [VodafoneQAT.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/QAT/VodafoneQAT.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Recharge USSD Format | Customer Care / Helpline |
| :--- | :---: | :---: | :---: | :--- |
| **Ooredoo Qatar** | MNO (Market Leader) | `*129#` (Main Balance) / `*129*1#` (Data) / SMS `Balance` to `121` | `*127*<14-digit PIN>#` / Ooredoo App | `111` / `+97444200700` / `170` |
| **Vodafone Qatar** | MNO (#2 Operator) | `*129#` (Main Balance) / `*100#` (Data Menu) / My Vodafone App | `*127*<PIN>#` / `*233*<PIN>#` / Dial `111` | `111` / `+97470000111` / `8007111` |

---

## 3. Key Operating Principles & CRA Qatar Regulatory Rules

1. **Ooredoo Hala Inactivity & Line Lifecycle:**
   - Ooredoo Hala credit validity ranges from 30 to 90 days depending on denomination.
   - Upon balance expiry, the line enters a **60-day Grace Period** (incoming calls and SMS remain active).
   - If no qualifying recharge is executed within **120 days** of credit expiry, the line is permanently deactivated and recycled by CRA.
   - KeepSIMs executes scheduled refills on **Day 30–60** via Reloadly Direct Top-Up (100 QAR) or DT One Data PIN (80 QAR) to maintain active status.

2. **Vodafone Qatar Inactivity & Line Lifecycle:**
   - Vodafone Qatar recharges provide 30-day balance usage with **180-day overall line validity**.
   - If no recharge occurs for **180 consecutive days**, the SIM is suspended.
   - A **180-day grace and reactivation period** is provided before permanent disconnection and number recycling.
   - KeepSIMs executes scheduled micro-refills on **Day 90–150** (delivering 10 QAR PIN via DT One for ~1.288 OMR / $3.35 USD) to reset the 180-day clock at minimum cost.

3. **Multi-Rail Failover Execution:**
   - **Ooredoo Qatar:** Routed primarily via **Reloadly** (`priority: 10`, `is_primary: true`) for direct account top-ups; backed up by **DT One** (`priority: 20`) for data PIN vouchers.
   - **Vodafone Qatar:** Routed primarily via **DT One** (`priority: 10`, `is_primary: true`) for lowest entry digital airtime PINs starting at 10 QAR (1.288 OMR / ~$3.35 USD); backed up by **Reloadly** (`priority: 20`) for API payload PIN delivery.
   - **Zendit & DingConnect:** Disabled (`priority: 30/40`, `is_enabled: false`) due to 0 active catalog offers in QA.
