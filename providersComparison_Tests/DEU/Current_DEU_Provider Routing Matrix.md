# KeepSIMs — Current Germany (DEU / DE) Provider Routing Matrix

> **Country:** Germany (`DE` / `DEU` / `+49`)  
> **Currency Settlement:** `OMR` (DT One / Ding) & `USD` (Reloadly / Zendit)  
> **Local Currency:** Euro (`EUR` / `€`)  
> **Regulatory Framework:** Federal Network Agency (*Bundesnetzagentur* - BNetzA) & German Telecommunications Act (§ 111 TKG Mandatory Identification / PostIdent/VideoIdent) | Standard 180–365 Day Active Validity Mandate + 30–60 Day Inbound Grace/Passive Period + 19% German VAT (*Mehrwertsteuer*)  
> **Last Verified & Updated:** 2026-08-23  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Deutsche Telekom** (MagentaMobil / T-Mobile) | MNO (National Leader / ~54M Subs) | 🟢 **DT One** (`602`)<br>• Denom: **5 EUR PIN / 10 EUR Direct**<br>• Cost: **2.781 OMR / 5.382 OMR**<br>• Delivery: **Direct Top-Up & PIN** | 🟢 **Reloadly** (`664` / `873`)<br>• Denom: **15 EUR PIN** ($17.65 USD)<br>• Cost: **$17.65 USD**<br>• Delivery: Digital PIN | 🟢 **Zendit** (`Telekom`)<br>• Offer: `TELEKOM_DE_001-ROW`<br>• Cost: **$16.84 USD** (15 EUR)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`TLDE` / `M4DE`)<br>*(Disabled: 0 UAT offers)* | [TelekomDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/TelekomDEU.md) |
| **Vodafone Germany** (Vodafone D2 / CallYa) | MNO (National #2 / ~31M Subs) | 🟢 **DT One** (`718`)<br>• Denom: **15 EUR** (`15313` / `23386`)<br>• Cost: **8.084 OMR / 8.047 OMR**<br>• Delivery: **Direct Top-Up & PIN** | 🟢 **Reloadly** (`875`)<br>• Denom: **15 EUR PIN** ($17.86 USD)<br>• Cost: **$17.86 USD**<br>• Delivery: Digital PIN | 🟢 **Zendit** (`Vodafone`)<br>• Offer: `VODAFONE_DE_001-ROW`<br>• Cost: **$18.59 USD** (15 EUR)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`VFDE` / `V6DE`)<br>*(Disabled: 0 UAT offers)* | [VodafoneDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/VodafoneDEU.md) |
| **O2 Telefónica Germany** (Telefónica O2) | MNO (National #3 / ~45M Subs) | 🟢 **DT One** (`451`)<br>• Denom: **15 EUR** (`15301` / `23408`)<br>• Cost: **8.149 OMR / 8.047 OMR**<br>• Delivery: **Direct Top-Up & PIN** | 🟢 **Reloadly** (`868`)<br>• Denom: **15 EUR PIN** ($17.86 USD)<br>• Cost: **$17.86 USD**<br>• Delivery: Digital PIN | 🟢 **Zendit** (`O2`)<br>• Offer: `O2_DE_001-ROW`<br>• Cost: **$18.75 USD** (15 EUR)<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`O2DE` / `O1DE`)<br>*(Disabled: 0 UAT offers)* | [O2TelefónicaDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/O2TelefónicaDEU.md) |
| **Congstar** (Telekom Sub-Brand) | Discount Sub-Brand (Host: Telekom) | 🟢 **Reloadly** (`850`)<br>• Denom: **5 EUR PIN** ($5.95 USD)<br>• Cost: **$5.8905 USD net**<br>• Delivery: **Digital PIN (Micro-Refill)** | 🟢 **Zendit** (`Congstar`)<br>• Offer: `CONGSTAR_DE_001-ROW`<br>• Cost: **$18.52 USD** (15 EUR)<br>• Delivery: Direct Top-Up | 🔴 **DT One** (`2139`)<br>*(Disabled: 0 pre-prod SKUs)* | 🔴 **DingConnect** (`C4DE` / `C7DE`)<br>*(Disabled: 0 UAT offers)* | [CongstarDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/CongstarDEU.md) |
| **Lebara Germany** (Lebara Play / Mobile) | International MVNO (Telefónica / Telekom) | 🟢 **Reloadly** (`855` / `857`)<br>• Denom: **9.99 EUR Bundle / 10 EUR PIN**<br>• Cost: **$11.53 USD net / $11.90 USD**<br>• Delivery: **Direct Bundle & PIN** | 🔴 **DT One** (`2728` / `6016`)<br>*(Disabled: 0 pre-prod SKUs)* | 🔴 **Zendit**<br>*(Disabled: 0 catalog offers)* | 🔴 **DingConnect** (`ESDE`)<br>*(Disabled: 0 UAT offers)* | [LebaraDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/LebaraDEU.md) |
| **Lycamobile Germany** | International MVNO (Host: Vodafone) | 🟢 **Reloadly** (`864` / `865`)<br>• Denom: **5 EUR PIN** ($5.92 USD)<br>• Cost: **$5.92 USD** (Starting 5 EUR)<br>• Delivery: **Digital PIN (Micro-Refill)** | 🔴 **DT One** (`2121`)<br>*(Disabled: 0 pre-prod SKUs)* | 🔴 **Zendit**<br>*(Disabled: 0 catalog offers)* | 🔴 **DingConnect** (`LYDE`)<br>*(Disabled: 0 UAT offers)* | [LycamobileDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/LycamobileDEU.md) |
| **Blau** (Blau Mobilfunk) | Discount Brand (Host: Telefónica) | 🟢 **Reloadly** (`849`)<br>• Denom: **15 EUR PIN** ($17.86 USD)<br>• Cost: **$17.5028 USD net**<br>• Delivery: **Digital PIN** | 🟢 **Zendit** (`Blau`)<br>• Offer: `BLAU_DE_001-ROW`<br>• Cost: **$18.99 USD** (15 EUR)<br>• Delivery: Direct Top-Up | 🔴 **DT One** (`2754`)<br>*(Disabled: 0 pre-prod SKUs)* | 🔴 **DingConnect** (`BSDE` / `B7DE`)<br>*(Disabled: 0 UAT offers)* | [BlauDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/BlauDEU.md) |
| **Ortel Mobile** | Ethnic MVNO (Host: Telefónica) | 🟢 **Reloadly** (`665`)<br>• Denom: **15 EUR PIN** ($17.86 USD)<br>• Cost: **$17.6814 USD net**<br>• Delivery: **Digital PIN** | 🟢 **Zendit** (`Ortel`)<br>• Offer: `ORTEL_DE_001-ROW`<br>• Cost: **$18.75 USD** (15 EUR)<br>• Delivery: Direct Top-Up | 🔴 **DT One** (`2146`)<br>*(Disabled: 0 pre-prod SKUs)* | 🔴 **DingConnect** (`OTDE` / `O3DE`)<br>*(Disabled: 0 UAT offers)* | [OrtelMobileDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/OrtelMobileDEU.md) |
| **Ay Yildiz** | Turkish-German Ethnic Brand (Telefónica) | 🟢 **Zendit** (`AyYildiz`)<br>• Offer: `AYYILDIZ_DE_001-ROW`<br>• Cost: **$18.73 USD** (15 EUR)<br>• Delivery: **Direct Top-Up** | 🔴 **DT One** (`2135`)<br>*(Disabled: 0 pre-prod SKUs)* | 🔴 **Reloadly**<br>*(Disabled: 0 catalog offers)* | 🔴 **DingConnect** (`AYDE` / `A9DE`)<br>*(Disabled: 0 UAT offers)* | [AyYildizDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/AyYildizDEU.md) |
| **Otelo** | Discount Subsidiary (Host: Vodafone) | 🟢 **Reloadly** (`867`)<br>• Denom: **9 EUR PIN** ($9.00 USD)<br>• Cost: **$9.00 USD** (Entry 9 EUR)<br>• Delivery: **Digital PIN (Micro-Refill)** | 🟢 **Zendit** (`OTELO`)<br>• Offer: `OTELO_DE_001-ROW`<br>• Cost: **$11.25 USD** (9 EUR)<br>• Delivery: Direct Top-Up | 🔴 **DT One** (`2148`)<br>*(Disabled: 0 pre-prod SKUs)* | 🔴 **DingConnect** (`OEDE` / `O4DE`)<br>*(Disabled: 0 UAT offers)* | [OteloDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/OteloDEU.md) |
| **Fonic** (Fonic Mobile) | Discount Brand (Host: Telefónica) | 🟢 **Reloadly** (`853`)<br>• Denom: **20 EUR PIN** ($23.81 USD)<br>• Cost: **$23.81 USD**<br>• Delivery: **Digital PIN** | 🔴 **DT One** (`2768`)<br>*(Disabled: 0 pre-prod SKUs)* | 🔴 **Zendit**<br>*(Disabled: 0 catalog offers)* | 🔴 **DingConnect** (`F1DE`)<br>*(Disabled: 0 UAT offers)* | [FonicDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/FonicDEU.md) |
| **Tchibo Mobil** | JV MVNO (Host: Telefónica) | 🟢 **Reloadly** (`872`)<br>• Denom: **20 EUR PIN** ($23.81 USD)<br>• Cost: **$23.81 USD**<br>• Delivery: **Digital PIN** | 🔴 **DingConnect** (`E825B8DE`)<br>*(Disabled: 0 UAT offers)* | 🔴 **DT One**<br>*(Disabled: 0 catalog offers)* | 🔴 **Zendit**<br>*(Disabled: 0 catalog offers)* | [TchiboMobilDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/TchiboMobilDEU.md) |
| **Klarmobil** | Freenet MVNO (Telekom / Vodafone) | 🟢 **Reloadly** (`854`)<br>• Denom: **15 EUR PIN** ($17.86 USD)<br>• Cost: **$17.86 USD**<br>• Delivery: **Digital PIN** | 🔴 **DT One** (`3117`)<br>*(Disabled: 0 pre-prod SKUs)* | 🔴 **Zendit**<br>*(Disabled: 0 catalog offers)* | 🔴 **DingConnect**<br>*(Disabled: 0 catalog offers)* | [KlarmobilDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/KlarmobilDEU.md) |
| **BILDmobil** | Media MVNO (Host: Vodafone) | 🟢 **Reloadly** (`848`)<br>• Denom: **10 EUR PIN** ($11.90 USD)<br>• Cost: **$11.781 USD net**<br>• Delivery: **Digital PIN** | 🔴 **DT One** (`3111`)<br>*(Disabled: 0 pre-prod SKUs)* | 🔴 **DingConnect** (`B6DE`)<br>*(Disabled: 0 UAT offers)* | 🔴 **Zendit**<br>*(Disabled: 0 catalog offers)* | [BILDmobilDEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/BILDmobilDEU.md) |
| **1&1 Telecom** (1&1 Drillisch) | 4th Network Operator | 🟢 **Via National Roaming / Online Portal**<br>• Direct Refill via 1&1 Control-Center / Bank Transfer<br>• Cost: Variable | 🔴 **DT One**<br>*(Disabled: 0 catalog offers)* | 🔴 **Reloadly**<br>*(Disabled: 0 catalog offers)* | 🔴 **Zendit**<br>*(Disabled: 0 catalog offers)* | [1und1DEU.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/DEU/1und1DEU.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Recharge USSD Format | Customer Care / Helpline |
| :--- | :---: | :---: | :---: | :--- |
| **Deutsche Telekom** | MNO (National Leader) | `*100#` (Instant balance) / MeinMagenta App | `*101*<16-digit PIN>#` / Dial `2000` | `2202` / `0800 33 02202` / `+49171882202` |
| **Vodafone Germany** | MNO (National #2) | `*100#` (CallYa Balance) / MeinVodafone App | `*100*<16-digit PIN>#` / Dial `22922` | `0172 229 0 229` / `+491722290229` |
| **O2 Telefónica Germany** | MNO (National #3) | `*101#` (Screen pop-up) / Mein O2 App | `*103*<16-digit PIN>#` / Dial `5667` | `0176 888 55 282` / `+4917688855282` |
| **Congstar** | Discount Sub-Brand (Telekom) | `*100#` / congstar App | `*101*<16-digit CashCode>#` / Dial `9577` | `0221 79 700 700` |
| **Lebara Germany** | MVNO (Telefónica / Telekom) | `*141#` / SMS `GUTHABEN` to `55255` | `*131*<16-digit PIN>#` / Dial `5588` | `5588` / `01806 532 272` |
| **Lycamobile Germany** | MVNO (Vodafone Network) | `*131#` (Screen pop-up) | `*131*<PIN>#` / Dial `321` | `322` / `069 945 199 322` |
| **Blau** | Discount Brand (Telefónica) | `*101#` / Mein Blau App | `*103*<16-digit PIN>#` / Dial `1155` | `0177 177 1160` |
| **Ortel Mobile** | Ethnic MVNO (Telefónica) | `*100#` / Ortel App | `*103*<16-digit PIN>#` / Dial `1155` | `1155` / `0177 177 1138` |
| **Ay Yildiz** | Ethnic Brand (Telefónica) | `*100#` / Mein Ay Yildiz App | `*100*<16-digit PIN>#` / Dial `1155` | `1155` / `0177 177 1177` |
| **Otelo** | Discount Subsidiary (Vodafone) | `*100#` / Mein Otelo App | `*100*<16-digit PIN>#` / Dial `12430` | `0172 124 300` |
| **Fonic** | Discount Brand (Telefónica) | `*101#` / Fonic App | `*103*<16-digit PIN>#` / Dial `5667` | `0176 888 6423` |
| **Tchibo Mobil** | JV MVNO (Telefónica) | `*101#` / Tchibo Mobil App | `*103*<16-digit PIN>#` / Dial `4055` | `040 55 55 55 40` |
| **Klarmobil** | Freenet MVNO (Telekom/Vodafone) | `*100#` / klarmobil App | `*101*<PIN>#` (Telekom) / `*100*<PIN>#` (VF) | `040 34 8585 300` |
| **BILDmobil** | MVNO (Vodafone) | `*100#` / BILDmobil Portal | `*100*<16-digit PIN>#` / Dial `2142` | `01805 88 00 88` |
| **1&1 Telecom** | 4th MNO Network | 1&1 Control-Center App / Portal | Web Recharge / Automatic Bank SEPA | `0721 96 00` |

---

## 3. Key Operating Principles & BNetzA Regulatory Rules

1. **BNetzA Germany Inactivity & Validity Windows:**
   - Under § 111 of the German Telecommunications Act (TKG) and Federal Network Agency (*Bundesnetzagentur*) standards:
     * Prepaid SIM cards remain active for **180 days (6 months)** to **365 days (1 year)** from the date of the last top-up or billable event.
     * If unrefilled within the active validity period, the line enters a **30 to 60-day passive / grace window** (*Passivphase* / *Eingehende Erreichbarkeit*): incoming calls and SMS continue, but outgoing traffic is blocked.
     * Following the grace period without recharge, the contract is terminated, remaining balance can be claimed back under German law, and the mobile number is released back into the BNetzA recycling pool.

2. **German Mobile Tax Structure:**
   - Standard 19% Value Added Tax (*Mehrwertsteuer* - MwSt) is included in all retail face-value denominations.
   - All prepaid SIM activations require mandatory identity verification (*Identitätsprüfung* via PostIdent, VideoIdent, or authorized retail branch).

3. **KeepSIMs Automated Mini-Refill Strategy:**
   - KeepSIMs schedules automated mini-refills on **Day 150–165** (well before the 180-day window expires).
   - On **Deutsche Telekom**, delivering a **5 EUR PIN** (2.781 OMR / ~$7.23 USD via DT One) or **10 EUR Direct Top-Up** (5.382 OMR / ~$13.99 USD via DT One) resets the 180-day active validity window.
   - On **Vodafone Germany**, delivering a **15 EUR Direct Top-Up** (8.084 OMR via DT One) or **15 EUR PIN** ($17.86 USD via Reloadly) resets the 180-day CallYa active timer.
   - On **O2 Germany**, delivering a **15 EUR Direct Top-Up** (8.149 OMR via DT One) or **15 EUR PIN** ($17.86 USD via Reloadly) resets the 180-day timer.
   - On **Congstar**, delivering a **5 EUR PIN** ($5.89 USD net via Reloadly) is the lowest cost micro-refill rail in Germany.
   - On **Lycamobile**, delivering a **5 EUR PIN** ($5.92 USD via Reloadly) provides an ultra-low entry point.
   - On **Otelo**, delivering a **9 EUR PIN** ($9.00 USD via Reloadly) extends validity for 180 days.

4. **Multi-Rail Provider Architecture:**
   - **DT One** is established as the **Primary Rail (`priority: 10`, `is_primary: true`)** for the top 3 German MNOs (Deutsche Telekom, Vodafone Germany, O2 Germany) supporting both Direct Top-Up and Digital PIN vouchers with 100% pre-production test confirmation.
   - **Reloadly** is established as the **Primary Micro-Refill Rail (`priority: 10`, `is_primary: true`)** for Germany's major MVNOs and sub-brands (Congstar 5 EUR, Lycamobile 5 EUR, Lebara 9.99 EUR, Otelo 9 EUR, Blau, Ortel, Fonic, Tchibo, Klarmobil, BILDmobil) and **Secondary Failover (`priority: 20`)** for MNOs.
   - **Zendit** provides reliable **Secondary/Tertiary Direct Top-Up Failover (`priority: 20/30`)** for 8 brands (Telekom, Vodafone, O2, Congstar, Blau, Ortel, Ay Yildiz, Otelo).
   - **DingConnect** is **Disabled (`priority: 40`, `is_enabled: false`)** due to 0 active inventory in UAT.
