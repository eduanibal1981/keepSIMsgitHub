# KeepSIMs — Current Oman (OM) Provider Routing Matrix

> **Country:** Oman (`OM` / `+968` / `OMN`)  
> **Currency Settlement:** `OMR` (DT One / Ding) & `USD` (Reloadly / Zendit)  
> **Local Currency:** Omani Rial (`OMR` / `ر.ع.`)  
> **Regulatory Framework:** Telecommunications Regulatory Authority (TRA) Oman — 150–180 Days Prepaid Line Validity Rule + 30 Days Suspension Grace Period  
> **Last Verified & Updated:** 2026-08-22  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Omantel** | MNO (Incumbent) | 🟢 **Reloadly** (`348`)<br>• Operator: `348`<br>• Cost: **$2.955 USD** (1 OMR PIN)<br>• Delivery: **Digital PIN Voucher** | 🟢 **DT One** (`2695`)<br>• Product: `17091` (1 OMR)<br>• Cost: **1.240 OMR ($3.224 USD)**<br>• Delivery: PIN & Hayyak Packs | 🟢 **DingConnect** (`OMOM`)<br>• Provider: `OMOM`<br>• Delivery: Direct / PIN | 🔴 **Zendit** (`Omantel`)<br>*(Disabled: 0 catalog offers)* | [OmantelOM.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/OM/OmantelOM.md) |
| **Ooredoo Oman** | MNO (National) | 🟢 **Reloadly** (`1168`)<br>• Operator: `1168`<br>• Cost: **$2.95 USD** (1.14 OMR)<br>• Delivery: **Direct Airtime Top-Up** | 🟢 **DT One** (`2883`)<br>• Product: `18802` (1 OMR)<br>• Cost: **1.228 OMR ($3.193 USD)**<br>• Delivery: Digital PIN Voucher | 🟢 **DingConnect** (`OOOM`)<br>• Provider: `OOOM`<br>• Delivery: Direct Top-Up | 🔴 **Zendit** (`Ooredoo`)<br>*(Disabled: 0 catalog offers)* | [OoredooOM.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/OM/OoredooOM.md) |
| **Vodafone Oman** | MNO (3rd Telco / 5G) | 🟢 **DingConnect** (`VFOM`)<br>• Provider: `VFOM`<br>• Delivery: **Primary Mapped Route** | 🔴 **DT One**<br>*(0 catalog products)* | 🔴 **Reloadly**<br>*(0 catalog products)* | 🔴 **Zendit**<br>*(0 catalog products)* | [VodafoneOM.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/OM/VodafoneOM.md) |
| **FRiENDi Mobile Oman** | MVNO (Host: Omantel) | 🟢 **DT One / Reloadly**<br>• Serviced via Omantel Host Rails<br>• Cost: **1.240 OMR / $2.955 USD**<br>• Delivery: **Digital PIN Voucher** | 🟢 **Reloadly** (`348`)<br>• Delivery: PIN Failover | 🟢 **DingConnect** (`OMOM`)<br>• Delivery: Direct / PIN | 🔴 **Zendit**<br>*(0 catalog offers)* | [FriendiOM.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/OM/FriendiOM.md) |
| **Renna Mobile** | MVNO (Host: Omantel) | 🟢 **DT One** (`2697`)<br>• Product: `42651` (0.3 OMR)<br>• Cost: **0.370 OMR ($0.962 USD)**<br>• Delivery: **Micro-PIN Recharge** | 🟢 **Reloadly** (`349`)<br>• Operator: `349`<br>• Cost: **$1.478 USD** (0.58 OMR)<br>• Delivery: Digital PIN Voucher | 🔴 **DingConnect**<br>*(0 catalog products)* | 🔴 **Zendit**<br>*(0 catalog offers)* | [RennaOM.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/OM/RennaOM.md) |
| **Red Bull Mobile Oman** | MVNO / Digital Brand | 🟢 **DT One** (`3444`)<br>• Product: `42652` (0.3 OMR)<br>• Cost: **0.369 OMR ($0.959 USD)**<br>• Delivery: **Exclusive Micro-PIN Route** | 🔴 **Reloadly**<br>*(0 catalog products)* | 🔴 **DingConnect**<br>*(0 catalog products)* | 🔴 **Zendit**<br>*(0 catalog offers)* | [RedBullOM.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/OM/RedBullOM.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Recharge USSD | Customer Care / IVR | Notes |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Omantel** | MNO (Incumbent) | `*100#` | `*101*<PIN>#` | `1234` / `+96824241234` | 8 DT One products (1–10 OMR + Hayyak) & 4 Reloadly PINs |
| **Ooredoo Oman** | MNO (National) | `*141#` / `*102#` | `*115*<PIN>#` | `1500` / `+96895011500` | Reloadly direct top-up ($2.95–$29.50) & 4 DT One PINs |
| **Vodafone Oman** | MNO (Cloud 5G) | `*777#` / App | `*777*<PIN>#` / In-App | `1771` / `+96877101771` | App-first subscription ecosystem; DingConnect mapped |
| **FRiENDi Mobile Oman** | MVNO (Host: Omantel) | `*139#` | `*138*<PIN>#` | `98400000` / `1600` | Omantel cross-compatible infrastructure |
| **Renna Mobile** | MVNO (Host: Omantel) | `*181*2#` | `*180*<PIN>#` | `1240` / `180` (IVR) | 8 DT One PINs (from 0.3 OMR / $0.96 USD) & 6 Reloadly PINs |
| **Red Bull Mobile Oman** | MVNO (Host: Omantel) | `*600*11#` | `*600*<PIN>#` | `1234` / `1233` (IVR) | 6 DT One PINs (from 0.3 OMR / $0.96 USD) |

---

## 3. Key Operating Principles & TRA Oman Regulatory Rules

1. **TRA Oman Prepaid Line Validity Rules:**
   - **Omantel (Hayyak):** Prepaid SIM cards maintain an active validity of **180 days** from the date of the last qualifying paid event (recharge, paid call, SMS, or data usage).
   - **Ooredoo Oman:** Prepaid SIM cards carry **150 active days** from the last recharge date.
   - **MVNOs (Renna, Red Bull, FRiENDi):** All recharge vouchers (including 0.3 OMR / 0.5 OMR micro-vouchers) provide **180 days active line validity**.

2. **Suspension & Grace Period:**
   - Following the active validity period (150–180 days), all operators enforce a mandatory **30-day grace/suspension period** (incoming calls/SMS only).
   - If no recharge occurs during the 30-day grace period, the SIM card is permanently cancelled, credit forfeited, and the phone number recycled into the public numbering pool.

3. **KeepSIMs Automated Mini-Refill Strategy:**
   - For **Ooredoo Oman**: Automated direct top-up of **$2.95 USD (1.14 OMR)** via Reloadly scheduled on **Day 135–145** resets the 150-day timer safely.
   - For **Omantel & FRiENDi**: Automated 1 OMR PIN voucher ($2.955 USD) scheduled on **Day 140–150** resets the 180-day validity counter.
   - For **Renna Mobile & Red Bull Mobile**: Ultra-low-cost micro-refill of **0.3 OMR (~$0.96 USD)** via DT One scheduled on **Day 140–150** preserves the line for 180 days at under $1.00 USD.
