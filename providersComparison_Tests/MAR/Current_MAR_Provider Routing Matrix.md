# KeepSIMs — Current Morocco (MA) Provider Routing Matrix

> **Country:** Morocco (`MA` / `+212` / `MAR`)  
> **Currency Settlement:** `OMR` (DT One / Ding) & `USD` (Reloadly / Zendit)  
> **Local Currency:** Moroccan Dirham (`MAD` / `DH` / `د.م.`)  
> **Regulatory Framework:** Agence Nationale de Réglementation des Télécommunications (ANRT) Standard 90 to 180-Day Active Validity Rule + 90-Day Grace/Suspension Period (Total 180 to 270 Days before number recycling) + 20% TVA (VAT)  
> **Last Verified & Updated:** 2026-08-23  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 40`) | Priority 4: Quaternary (`priority: 50`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Maroc Telecom** (IAM / Jawal) | MNO (Incumbent Leader / ~50% Share) | 🟢 **DT One** (`1533`)<br>• Fixed: **5–300 MAD** (`4073`+)<br>• Cost: **0.242 OMR ($0.629 USD)**<br>• Delivery: **Direct Recharge & Pass *3 Data** | 🟢 **Reloadly** (`311` / `310`)<br>• Fixed: **5–300 MAD** ($0.63 USD)<br>• Cost: **$0.63–$37.50 USD**<br>• Delivery: Direct Airtime & Data | 🔴 **DingConnect** (`MOMA` / `0MMA`)<br>*(Disabled: 0 UAT offers)* | 🔴 **Zendit** (`MarocTelecom`)<br>*(Disabled: 0 Sandbox offers)* | [MarocTelecomMAR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/MAR/MarocTelecomMAR.md) |
| **Orange Morocco** (formerly Méditel) | MNO (National #2 / ~33% Share) | 🟢 **DT One** (`387`)<br>• Fixed: **6–330 MAD** (`50285`+)<br>• Cost: **0.302 OMR ($0.785 USD)**<br>• Delivery: **Direct Recharge & Social** | 🟢 **Reloadly** (`313` / `690` / `309`)<br>• Range: **36.86–330 MAD** ($4.38 USD)<br>• Cost: **$4.16–$37.26 USD**<br>• Delivery: Direct Airtime, Bundles & Data | 🔴 **DingConnect** (`ORMA`)<br>*(Disabled: 0 UAT offers)* | 🔴 **Zendit** (`Orange`)<br>*(Disabled: 0 Sandbox offers)* | [OrangeMAR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/MAR/OrangeMAR.md) |
| **Inwi** (Wana Corporate / Tic Tac) | MNO (National #3 / ~17% Share) | 🟢 **DT One** (`1711`)<br>• Fixed: **5–300 MAD** (`16801`+)<br>• Cost: **0.245 OMR ($0.637 USD)**<br>• Delivery: **Direct Recharge & Pass *3 Data** | 🟢 **Reloadly** (`312` / `308` / `688`)<br>• Fixed: **5–200 MAD** ($0.60 USD)<br>• Cost: **$0.570–$22.182 USD**<br>• Delivery: Direct Airtime & Data | 🔴 **DingConnect** (`INMA` / `I0MA`)<br>*(Disabled: 0 UAT offers)* | 🔴 **Zendit** (`Inwi`)<br>*(Disabled: 0 Sandbox offers)* | [InwiMAR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/MAR/InwiMAR.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Recharge USSD Format | Customer Care / Helpline | Self-Care App |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **Maroc Telecom** | MNO (Market Leader) | `#580#` (Airtime) / `#554#` (Passes) | `*444*<PIN>#` or `*555*<PIN>*3#` (Pass *3) | `888` / `+212537719000` | Mon Espace MT |
| **Orange Morocco** | MNO (#2 Operator) | `#554#` (Balance & Validity) | `*120*<PIN>#` or `*120*<PIN>*3#` (Pass *3) | `121` / `+212663121121` | Orange et moi / Max It |
| **Inwi** | MNO (#3 Operator) | `*120*30#` or `*120*1#` (Balance & Validity) | `*120*20*<PIN>#` or `*120*20*<PIN>*3#` (Pass *3) | `220` / `+212529000220` | My Inwi |

---

## 3. Key Operating Principles & ANRT Morocco Regulatory Rules

1. **ANRT Morocco Inactivity & SIM Lifecycle Framework:**
   - Under the Agence Nationale de Réglementation des Télécommunications (ANRT) guidelines, prepaid SIM cards in Morocco have an active validity window of **90 to 180 days** from the date of the last qualifying recharge or billable transaction.
   - Upon expiry of the active validity window, the SIM enters a **90-day grace/suspension period** (the subscriber can receive incoming calls and SMS, but outgoing communication is barred).
   - If no qualifying top-up occurs before the 90-day grace period expires (total dormancy: **180 to 270 days**), the SIM card is permanently terminated, remaining balance forfeited, and the mobile number returned to the national numbering pool for reassignment.

2. **Telecommunications Taxation & Pricing Structure:**
   - Moroccan telecom recharges are subject to statutory **20% Value Added Tax (TVA)** included in standard retail face value.
   - All nominal top-ups delivered through KeepSIMs credit 100% of the purchased face value directly into the prepaid wallet balance.

3. **Pass / Recharge Differentiation in Morocco:**
   - **Pass *3 (Internet):** Mobile data recharge codes activated by appending `*3` to the scratch code or selecting the direct data product.
   - **Pass *1 (Calls):** National and international minutes bundle.
   - **Pass *6 (Social Media):** Unlimited/high-quota access to WhatsApp, Facebook, Instagram, TikTok, Twitter.
   - **Pass *22 (Multiple Bonus):** Maroc Telecom promotional airtime multiplier (13x to 22x face value).

4. **KeepSIMs Automated Mini-Refill Strategy:**
   - Scheduled automated mini-recharges trigger on **Day 60–80** (well before the 90/180-day inactivity deadline).
   - Delivering a **5–6 MAD micro-refill** (costing **0.242–0.302 OMR / ~$0.63–$0.79 USD via DT One**) resets the ANRT active validity countdown clock at minimum cost.

5. **Multi-Rail Failover Execution:**
   - **DT One** serves as **Primary Direct Rail (`priority: 10`, `is_primary: true`)** for all 3 operators (Maroc Telecom, Orange Morocco, Inwi) with granular fixed denominations starting from 5/6 MAD, verified instant pre-prod confirmation, and lowest wholesale rates.
   - **Reloadly** serves as **Secondary Direct Rail (`priority: 20`)** across all 3 operators with airtime and dedicated data/bundle catalog entries.
   - **DingConnect** is **Disabled (`priority: 40`, `is_enabled: false`)** due to 0 active inventory in UAT.
   - **Zendit** is **Disabled (`priority: 50`, `is_enabled: false`)** due to 0 sandbox offers for Morocco.
