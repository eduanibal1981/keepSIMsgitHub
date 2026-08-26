# KeepSIMs — Current Turkey (TR) Provider Routing Matrix

> **Country:** Turkey (`TR` / `+90` / `TUR`)  
> **Currency Settlement:** `OMR` (DT One / Ding) & `USD` (Reloadly / Zendit)  
> **Local Currency:** Turkish Lira (`TRY` / `₺`)  
> **Regulatory Framework:** Information and Communication Technologies Authority (BTK) Standard 180/184-Day Inactivity Mandate + 90/365-Day Grace/Passive Period + Special Communication Tax (ÖİV 10%) & Monthly Wireless Usage Fee (*Telsiz Kullanım Ücreti*)  
> **Last Verified & Updated:** 2026-08-22  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Turkcell** (Turkcell İletişim Hizmetleri) | MNO (National Leader) | 🟢 **Reloadly** (`509` / `1177`)<br>• Denom: **65 TRY** ($1.82 USD)<br>• Cost: **$1.765 USD net**<br>• Delivery: **Direct Recharge** | 🟢 **DT One** (`679`)<br>• Denom: **200 TRY** (`67167`)<br>• Cost: **2.047 OMR ($5.32 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Zendit** (`Turkcell`)<br>• Offer: `TURKCELL_TR_10-I`<br>• Cost: **$10.00 USD** (200 TRY)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`TZTR`)<br>*(Disabled: 0 UAT offers)* | [TurkcellTR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/TR/TurkcellTR.md) |
| **Vodafone Turkey** (Vodafone Telekomünikasyon) | MNO (National #2) | 🟢 **Reloadly** (`1178` / `512`)<br>• Denom: **90 TRY** ($2.52 USD)<br>• Cost: **$2.444 USD net**<br>• Delivery: **Direct Bundle** | 🟢 **Zendit** (`Vodafone`)<br>• Offer: `VODAFONE_TR_001`<br>• Cost: **$5.00 USD** (100 TRY)<br>• Delivery: Direct Top-Up | 🟢 **DT One** (`662`)<br>• Denom: **250 TRY** (`50568`)<br>• Cost: **2.558 OMR ($6.65 USD)**<br>• Delivery: Direct Recharge | 🔴 **DingConnect** (`VFTR`)<br>*(Disabled: 0 UAT offers)* | [VodafoneTR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/TR/VodafoneTR.md) |
| **Türk Telekom** (TT Mobil / Avea) | MNO (Incumbent) | 🟢 **DT One** (`46`)<br>• Denom: **300 TRY** (`48513`)<br>• Cost: **3.071 OMR ($7.98 USD)**<br>• Delivery: **Direct Recharge** | 🟢 **Reloadly** (`510`)<br>• Denom: **300 TRY** ($8.41 USD)<br>• Cost: **$8.157 USD net**<br>• Delivery: Direct Recharge | 🟢 **Zendit** (`TurkTelekom`)<br>• Offer: `TURKTELECOM_TR_004_USD`<br>• Cost: **$15.00 USD** (300 TRY)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`AVTR`)<br>*(Disabled: 0 UAT offers)* | [TurkTelekomTR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/TR/TurkTelekomTR.md) |
| **Bimcell** (BİMcell) | MVNO (Host: Türk Telekom) | 🟢 **DT One** (`46`)<br>• Via Türk Telekom Rails (300 TRY)<br>• Cost: **3.071 OMR ($7.98 USD)**<br>• Delivery: **Direct via TT** | 🟢 **Reloadly** (`510`)<br>• Via Türk Telekom Rails<br>• Cost: **$8.157 USD net**<br>• Delivery: Direct via TT | 🟢 **Zendit** (`TurkTelekom`)<br>• Via Türk Telekom Rails<br>• Cost: **$15.00 USD** (300 TRY)<br>• Delivery: Direct via TT | 🔴 **DingConnect** (`AVTR`)<br>*(Disabled: 0 UAT offers)* | [BimcellTR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/TR/BimcellTR.md) |
| **Pttcell** | MVNO (Host: Türk Telekom) | 🟢 **DT One** (`46`)<br>• Via Türk Telekom Rails (300 TRY)<br>• Cost: **3.071 OMR ($7.98 USD)**<br>• Delivery: **Direct via TT** | 🟢 **Reloadly** (`510`)<br>• Via Türk Telekom Rails<br>• Cost: **$8.157 USD net**<br>• Delivery: Direct via TT | 🟢 **Zendit** (`TurkTelekom`)<br>• Via Türk Telekom Rails<br>• Cost: **$15.00 USD** (300 TRY)<br>• Delivery: Direct via TT | 🔴 **DingConnect** (`AVTR`)<br>*(Disabled: 0 UAT offers)* | [PttcellTR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/TR/PttcellTR.md) |
| **Vodafone Cyprus** (KKTC Vodafone) | Regional (+90 542 / +90 548) | 🟢 **DT One** (`1931`)<br>• Denom: **12 TRY** (`11581`)<br>• Cost: **0.121 OMR ($0.31 USD)**<br>• Delivery: **Direct Recharge** | 🔴 **Reloadly** (`511`)<br>*(Disabled: 0 Sandbox Denoms)* | 🔴 **Zendit**<br>*(Disabled: 0 Catalog Offers)* | 🔴 **DingConnect**<br>*(Disabled: Unsupported)* | [VodafoneCyprusTR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/TR/VodafoneCyprusTR.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Recharge USSD Format | Customer Care / Helpline |
| :--- | :---: | :---: | :---: | :--- |
| **Turkcell** | MNO (National Leader) | `*123#` (Screen Pop-up) / Turkcell App | `*122*<16-digit PIN>#` | `532` / `0532 532 00 00` / `+905325320000` |
| **Vodafone Turkey** | MNO (National #2) | `*123#` / SMS `OZET` to `7000` | `*111*<12-digit PIN>#` | `542` / `0542 542 00 00` / `+905425420000` |
| **Türk Telekom** (Avea) | MNO (Incumbent) | `*123#` / SMS `TL` to `9333` | `*9333#` / `*100#` | `500` / `444 1 500` / `+905005000500` |
| **Bimcell** (BİMcell) | MVNO (Türk Telekom Core) | `*123#` / SMS `TL` to `9333` | `*9333#` / bimcell.com.tr | `551` / `444 4 551` / `+905515510000` |
| **Pttcell** | MVNO (Türk Telekom Core) | `*123#` / SMS `TL` to `9333` | `*9333#` / pttcell.com.tr | `444 1 788` / `+904441788` |
| **Vodafone Cyprus** (KKTC) | Regional (Northern Cyprus) | `*123#` (Screen Pop-up) | `*111*<PIN>#` | `542` / `+905428880542` |

---

## 3. Key Operating Principles & BTK Regulatory Rules

1. **BTK Turkey Inactivity & Validity Windows:**
   - Under Information and Communication Technologies Authority (BTK) regulations, Turkish prepaid lines remain in an **Active Period (*Aktif Dönem*)** for **180 days (6 months)** (Turkcell & Vodafone) or **184 days (6 months)** (Türk Telekom / MVNOs) following any qualifying recharge.
   - If unrefilled within the active period, the line transitions into a **Passive Period (*Pasif / Yarı Aktif Dönem*)**:
     * **Turkcell:** 365-day (1 year) period where line is suspended for outgoing calls before permanent termination.
     * **Vodafone Turkey:** 90-day passive period (*Dondurma Süreci*) before permanent disconnection.
     * **Türk Telekom / Bimcell / Pttcell:** 92-day passive period (*Kısıtlı Süreç* / Days 185–276) before contract cancellation and number forfeiture.

2. **Turkish Mobile Tax Structure:**
   - Under Turkish Law No. 6802, a 10% Special Communication Tax (ÖİV - *Özel İletişim Vergisi*) applies to mobile top-ups.
   - The Turkish state also levies an annual Wireless Usage Fee (*Telsiz Kullanım Ücreti* - TKÜ), amortized monthly (~15–20 TRY/month) and deducted directly from the prepaid balance upon recharge.

3. **KeepSIMs Automated Mini-Refill Strategy:**
   - Scheduled automated mini-recharges trigger on **Day 150–165** (well before the 180-day / 184-day active period expires).
   - On **Turkcell**, delivering a 65 TRY airtime top-up ($1.76 USD via Reloadly) or 90 TRY bundle ($2.44 USD) resets the 180-day BTK active timer.
   - On **Vodafone Turkey**, delivering a 90 TRY bundle ($2.44 USD via Reloadly) or 100 TRY top-up ($5.00 USD via Zendit) resets the 180-day timer.
   - On **Türk Telekom / Bimcell / Pttcell**, delivering a 300 TRY top-up (3.071 OMR / ~$7.98 USD via DT One or $8.15 USD via Reloadly) resets the 184-day timer.
   - On **Vodafone Cyprus**, delivering a 12 TRY micro-top-up (0.121 OMR / ~$0.31 USD via DT One) resets line validity indefinitely.

4. **Multi-Rail Failover Execution:**
   - **Reloadly** serves as **Primary Micro-Refill Rail (`priority: 10`, `is_primary: true`)** for Turkcell and Vodafone Turkey due to unique low-entry denominations (65 TRY and 90 TRY).
   - **DT One** serves as **Primary Rail (`priority: 10`, `is_primary: true`)** for Türk Telekom, Bimcell, Pttcell, and Vodafone Cyprus with superior wholesale pricing (3.071 OMR for 300 TRY and 0.121 OMR for 12 TRY) and 100% pre-prod confirmation.
   - **Zendit** serves as robust **Secondary/Tertiary Failover (`priority: 20/30`)** for all 3 major operators.
   - **DingConnect** is **Disabled (`priority: 40`, `is_enabled: false`)** due to 0 active inventory in UAT.
