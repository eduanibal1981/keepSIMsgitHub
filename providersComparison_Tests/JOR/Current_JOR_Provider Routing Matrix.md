# KeepSIMs — Current Jordan (JOR) Provider Routing Matrix

> **Country:** Jordan (`JO` / `+962` / `JOR`)  
> **Currency Settlement:** `OMR` (DT One / DingConnect) & `USD` (Reloadly / Zendit)  
> **Local Currency:** Jordanian Dinar (`JOD` / `د.أ`)  
> **Regulatory Framework:** Telecommunications Regulatory Commission (TRC) Jordan — 90-Day Inactivity Lifecycle + 65 to 90-Day Suspension Grace Period | Telecommunications Taxation: 16% General Sales Tax + 26% Special Tax on mobile subscriptions  
> **Last Verified & Updated:** 2026-08-23  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Zain Jordan** | MNO (Market Leader) | 🟢 **DT One** (`2093`)<br>• Product: `39869` (0.5 JOD)<br>• Cost: **0.510 OMR ($1.33 USD)**<br>• Delivery: **Direct Airtime (29 SKUs)** | 🟢 **Zendit** (`Zain`)<br>• Offer: `ZAIN_JORDAN_1_JOD_FEE`<br>• Cost: **$2.99 USD** (1 JOD)<br>• Delivery: Direct Top-Up (18 SKUs) | 🟢 **DingConnect** (`ZJJO`)<br>• Provider: `ZJJO`<br>• Delivery: Direct Top-Up | 🔴 **Reloadly** (`666`)<br>*(Disabled: High cost / $27.78 USD for 5 JOD)* | [ZainJOR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/JOR/ZainJOR.md) |
| **Orange Jordan** | MNO (Incumbent) | 🟢 **DT One** (`3122`)<br>• Product: `58694` (1 JOD)<br>• Cost: **1.034 OMR ($2.69 USD)**<br>• Delivery: **Digital PIN (365d)** | 🟢 **Zendit** (`Orange`)<br>• Offer: `ORANGE_JORDAN_3_JOD_FEE`<br>• Cost: **$8.73 USD** (3 JOD)<br>• Delivery: Direct Top-Up (4 SKUs) | 🟢 **DingConnect** (`ORJO`)<br>• Provider: `ORJO`<br>• Delivery: Direct Top-Up | 🔴 **Reloadly** (`0`)<br>*(Disabled: 0 sandbox operators)* | [OrangeJOR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/JOR/OrangeJOR.md) |
| **Umniah** | MNO (3rd Telco) | 🟢 **Reloadly** (`1150`)<br>• Operator: `1150` (Umniah RTR)<br>• Cost: **$4.88 USD** (1 JOD)<br>• Delivery: **Direct Airtime (Range)** | 🟢 **DT One** (`690`)<br>• Product: `58457` (6.85 JOD)<br>• Cost: **6.641 OMR ($17.27 USD)**<br>• Delivery: Digital PIN (7 SKUs) | 🔴 **Zendit** (`Umniah`)<br>*(Disabled: 0 catalog offers)* | 🔴 **DingConnect** (`Umniah`)<br>*(Disabled: 0 catalog offers)* | [UmniahJOR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/JOR/UmniahJOR.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Recharge USSD | Customer Care / IVR | Notes |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Zain Jordan** | MNO (Market Leader) | `*116#` / `*121#` | `*114*<PIN>#` / Zain App | `1234` / `+962 79 000 1234` | Ultra-low 0.5 JOD ($1.33 USD) micro-recharge via DT One & 18 Zendit direct offers |
| **Orange Jordan** | MNO (Incumbent) | `*155#` / `*150#` | `*150*<PIN>#` / Orange App | `1777` / `+962 77 770 0177` | 1 JOD PIN ($2.69 USD) via DT One grants 365-day voucher validity |
| **Umniah** | MNO (3rd Telco) | `*136#` / `*100#` | `*133*<PIN>#` / Call `1331` | `1333` / `+962 78 800 1333` | 1 JOD ($4.88 USD) flexible ranged direct topup via Reloadly & 7 DT One PIN products |

---

## 3. Key Operating Principles & TRC Jordan Regulatory Rules

1. **TRC Jordan Prepaid Line Validity Rules:**
   - **Zain Jordan:** Prepaid accounts operate on a **90-day inactivity lifecycle**. Direct airtime refills extend line validity by **30 to 180 days** depending on voucher face value.
   - **Orange Jordan:** Prepaid lines enforce a **90-day activity window**. DT One 1 JOD PIN voucher (Product `58694`) grants **365 days of voucher validity**.
   - **Umniah:** Prepaid lines require activity every **90 days**. Ranged direct airtime recharges extend line validity by **30 to 90 days**.
   - **Taxation:** Telecommunications in Jordan are subject to **16% General Sales Tax (GST) + 26% Special Tax** on mobile subscriptions / prepaid airtime.

2. **Suspension & Grace Period:**
   - After the active validity period expires without qualifying recharge or paid activity, operators enforce a **65 to 90-day grace/suspension period** (incoming-only calls and SMS).
   - If no recharge occurs during the suspension window, the SIM card is permanently disconnected, remaining balance forfeited, and the mobile phone number returned to the TRC Jordan national number pool for recycling.

3. **KeepSIMs Automated Mini-Refill Strategy:**
   - For **Zain Jordan**: Automated direct airtime top-up of **0.5 JOD (0.510 OMR / ~$1.33 USD)** via DT One scheduled on **Day 80–85** resets the inactivity timer seamlessly at minimal cost.
   - For **Orange Jordan**: Automated digital PIN voucher of **1 JOD PIN (1.034 OMR / ~$2.69 USD)** via DT One scheduled on **Day 80–85** secures line validity for up to 365 days.
   - For **Umniah**: Automated ranged direct airtime top-up of **1 JOD ($4.88 USD)** via Reloadly scheduled on **Day 80–85** preserves line connectivity.
