# KeepSIMs — Current Algeria (DZ) Provider Routing Matrix

> **Country:** Algeria (`DZ` / `+213` / `DZA`)  
> **Currency Settlement:** `USD` (Zendit / Reloadly) & `OMR` (DT One / Ding)  
> **Local Currency:** Algerian Dinar (`DZD` / `DA` / `د.ج`)  
> **Regulatory Framework:** Autorité de Régulation de la Poste et des Communications Électroniques (ARPCE) Standard 60 to 90-Day Active Validity Rule + 90-Day Grace/Suspension Period (Total 150 to 180 Days before number recycling) + 19% TVA (VAT)  
> **Last Verified & Updated:** 2026-08-23  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Mobilis** (ATM Mobilis / Algérie Télécom) | MNO (Incumbent Market Leader / ~43% Share) | 🟢 **Zendit** (`MOBILIS`)<br>• Fixed: **100–2000 DZD** (`MOBILIS_DZ_01`+)<br>• Cost: **$0.71 USD** (100 DZD)<br>• Delivery: **Direct Airtime Top-Up** | 🟢 **DT One** (`4`)<br>• Fixed: **100–2000 DZD** (`14299`+)<br>• Cost: **0.296 OMR ($0.770 USD)**<br>• Delivery: **Direct Airtime Top-Up** | 🟢 **Reloadly** (`6`)<br>• Fixed: **100–2000 DZD** ($0.97 USD)<br>• Cost: **$0.9215–$18.40 USD net**<br>• Delivery: **Direct Airtime Top-Up** | 🔴 **DingConnect** (`MDDZ`)<br>*(Disabled: 0 UAT offers)* | [MobilisDZA.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DZA/MobilisDZA.md) |
| **Djezzy** (Optimum Telecom Algeria / FNI) | MNO (National #2 / ~32% Share) | 🟢 **Zendit** (`DJEZZY`)<br>• Fixed: **100–2000 DZD** (`DJEZZY_DZ_01`+)<br>• Cost: **$0.71 USD** (100 DZD)<br>• Delivery: **Direct Airtime Top-Up** | 🟢 **DT One** (`2074`)<br>• Fixed: **100–2000 DZD** (`14308`+)<br>• Cost: **0.296 OMR ($0.770 USD)**<br>• Delivery: **Direct Airtime Top-Up** | 🟢 **Reloadly** (`8`)<br>• Fixed: **500–2000 DZD** ($4.84 USD)<br>• Cost: **$4.598–$18.40 USD net**<br>• Delivery: **Direct Airtime Top-Up** | 🔴 **DingConnect** (`DJDZ`)<br>*(Disabled: 0 UAT offers)* | [DjezzyDZA.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DZA/DjezzyDZA.md) |
| **Ooredoo Algeria** (Wataniya Télécom / Nedjma) | MNO (National #3 / ~25% Share) | 🟢 **Zendit** (`OOREDOO`)<br>• Fixed: **100–2000 DZD** (`OOREDOO_DZ_01`+)<br>• Cost: **$0.73 USD** (100 DZD)<br>• Delivery: **Direct Airtime Top-Up** | 🟢 **DT One** (`2075`)<br>• Fixed: **100–2000 DZD** (`14317`+)<br>• Cost: **0.296 OMR ($0.770 USD)**<br>• Delivery: **Direct Airtime & MAXY/Data Bundles** | 🟢 **Reloadly** (`7`)<br>• Fixed: **100–2000 DZD** ($0.97 USD)<br>• Cost: **$0.9215–$18.40 USD net**<br>• Delivery: **Direct Airtime Top-Up** | 🔴 **DingConnect** (`OODZ`)<br>*(Disabled: 0 UAT offers)* | [OoredooDZA.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DZA/OoredooDZA.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Recharge USSD Format | Customer Care / Helpline | Self-Care App |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **Mobilis** | MNO (Incumbent Market Leader) | `*222#` (Airtime) / `*600#` (PixX Bundles) | `*111*<PIN>#` or `*222*<PIN>#` | `666` / `+21323921313` | MobiSpace |
| **Djezzy** | MNO (#2 Operator) | `*710#` (Airtime) / `*707#` (Hayla/Special) | `*700*<PIN>#` or `*710*<PIN>#` | `777` / `+213770850005` | Djezzy App |
| **Ooredoo Algeria** | MNO (#3 Operator) | `*200#` (Airtime) / `*151#` (MAXY/Haya) | `*115*<PIN>#` or `*200*<PIN>#` | `333` / `+213554500507` | My Ooredoo Algeria |

---

## 3. Key Operating Principles & ARPCE Algeria Regulatory Rules

1. **ARPCE Algeria Inactivity & SIM Lifecycle Framework:**
   - Under the Autorité de Régulation de la Poste et des Communications Électroniques (ARPCE) regulations, prepaid mobile lines in Algeria maintain active validity for **60 to 90 days** from the date of the last qualifying recharge or billable event.
   - Upon expiry of the active validity window, the SIM enters a **90-day grace/suspension period** (the subscriber can receive incoming calls and SMS, but outgoing communication is barred).
   - If no qualifying top-up occurs before the 90-day grace period expires (total dormancy: **150 to 180 days**), the SIM card is permanently disconnected, remaining balance forfeited, and the mobile number recycled to the public numbering pool.

2. **Telecommunications Taxation & Pricing Structure:**
   - Algerian mobile recharges include a statutory **19% Value Added Tax (TVA)** included in standard retail face value.
   - All nominal top-ups delivered through KeepSIMs credit 100% of the purchased face value directly into the subscriber's main prepaid wallet balance.

3. **Prepaid Brand & Bundle Differentiation:**
   - **Mobilis:** Offers PixX (voice + data combo), Mobitas, Gosto, and Win packs.
   - **Djezzy:** Offers Hayla Maxi, Djezzy Special, Hadra, and Play daily/monthly bundles.
   - **Ooredoo Algeria:** Offers MAXY Internet, MAXY Hadra, Haya!, Dima, and Sahla bundles.

4. **KeepSIMs Automated Mini-Refill Strategy:**
   - Scheduled automated mini-recharges trigger on **Day 50–75** (well before the 60/90-day inactivity deadline).
   - Delivering a **100 DZD micro-refill** (costing **$0.71–$0.73 USD via Zendit** or **0.296 OMR / ~$0.770 USD via DT One**) resets the ARPCE active validity countdown clock at minimum cost.

5. **Multi-Rail Failover Execution:**
   - **Zendit** serves as **Primary Direct Rail (`priority: 10`, `is_primary: true`)** for all 3 operators (Mobilis, Djezzy, Ooredoo) delivering nominal airtime from 100 DZD for **$0.71–$0.73 USD**, offering the lowest entry price in USD.
   - **DT One** serves as **Secondary Direct & Bundle Rail (`priority: 20`)** across all 3 operators with instant pre-production transaction confirmation and rich MAXY / data bundle options.
   - **Reloadly** serves as **Tertiary Direct Rail (`priority: 30`)** across all 3 operators with sandbox-verified top-ups from $0.9215 USD net.
   - **DingConnect** is **Disabled (`priority: 40`, `is_enabled: false`)** due to 0 active inventory in UAT (503 response).
