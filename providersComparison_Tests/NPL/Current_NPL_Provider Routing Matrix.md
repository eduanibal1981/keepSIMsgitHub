# KeepSIMs — Current Nepal (NP) Provider Routing Matrix

> **Country:** Nepal (`NP` / `+977` / `NPL`)  
> **Currency Settlement:** `OMR` (DT One / Ding) & `USD` (Reloadly / Zendit)  
> **Local Currency:** Nepalese Rupee (`NPR` / `रू`)  
> **Regulatory Framework:** Nepal Telecommunications Authority (NTA) Directive + Carrier Inactivity Lifecycles (Ncell 180-Day Rule + 90-Day Grace Period; NTC Tiered Validity from 10 NPR/5-Day up to 500 NPR/360-Day & 1000 NPR/730-Day) + 10% Telecommunication Service Charge (TSC) + 13% VAT  
> **Last Verified & Updated:** 2026-08-23  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Ncell** (Axiata / Spectrlite UK) | MNO (Private Market Leader / ~47% Share) | 🟢 **DT One** (`1442`)<br>• Range: **50–3000 NPR** (`11938`)<br>• Cost: **0.093–0.154 OMR ($0.24–$0.40 USD)**<br>• Delivery: **Direct Recharge & Data** | 🟢 **Reloadly** (`328` / `1121`)<br>• Range: **50–5000 NPR** ($0.38 USD)<br>• Cost: **$0.2185–$37.72 USD**<br>• Delivery: Direct Airtime & Data | 🟢 **Zendit** (`Ncell`)<br>• Offers: `NCELL_NP_6-I` to `24-I`<br>• Cost: **$5.60–$22.30 USD**<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`NCNP`)<br>*(Disabled: 0 UAT offers)* | [NcellNPL.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/NPL/NcellNPL.md) |
| **Nepal Telecom** (NTC / Namaste) | MNO (National State Incumbent / ~50% Share) | 🟢 **DT One** (`1443`)<br>• Range: **10–10000 NPR** (`11939`)<br>• Cost: **0.031–1.531 OMR ($0.08–$3.98 USD)**<br>• Delivery: **Direct Recharge & Micro-Rail** | 🟢 **Reloadly** (`326` / `1123`)<br>• Range: **50–20000 NPR** ($0.38 USD)<br>• Cost: **$0.1615–$150.86 USD**<br>• Delivery: Direct Airtime & Data | 🟢 **Zendit** (`NTCGSM`)<br>• Offers: `NTCGSM_NP_2.5-I` to `12-I`<br>• Cost: **$2.00–$9.60 USD**<br>• Delivery: Direct Top-Up | 🔴 **DingConnect** (`NENP`)<br>*(Disabled: 0 UAT offers)* | [NtcNPL.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/NPL/NtcNPL.md) |
| **Smart Cell** (Smart Telecom Pvt Ltd) | Former MNO (License Revoked by NTA) | 🔴 **DT One**<br>*(Not Listed / Decommissioned)* | 🔴 **Reloadly** (`805`)<br>*(Disabled: Decommissioned in Nepal)* | 🔴 **Zendit**<br>*(Not Listed)* | 🔴 **DingConnect**<br>*(Not Listed)* | [SmartCellNPL.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/NPL/SmartCellNPL.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Mobile Network Code / Prefixes | Balance Check USSD / Method | Recharge USSD Format | Customer Care / Helpline |
| :--- | :--- | :--- | :--- | :--- |
| **Ncell** | `980`, `981`, `982`, `970` | `*901#` or `*101#` (Balance & Validity) / `*901#` (Data) | `*902*<16-digit PIN>#` or `*102*<PIN>#` / Ncell App | `9005` (Ncell) / `9805554444` / `+9779805554444` |
| **Nepal Telecom (NTC)** | `984`, `985` (Postpaid), `986`, `974`, `976`, `975` | `*400#` (Direct Balance & Expiry Date) / `*1415#` (Offers) | `*412*<14-digit PIN>#` / Namaste App | `1498` (NTC Mobile) / `197` / `+97714221197` |
| **Smart Cell** *(Decommissioned)* | `961`, `962`, `988` *(Legacy)* | `*102#` *(Legacy)* | `*122*<PIN>#` *(Legacy)* | *(Non-operational)* |

---

## 3. Key Operating Principles & NTA Regulatory Rules

1. **NTA Nepal Dormancy & SIM Card Lifecycle Regulations:**
   - **Ncell Policy:** Under NTA directives, Ncell prepaid SIMs require revenue-generating activity (recharge, call, SMS, data) within **180 days**. After 180 days of dormancy, the line enters a **90-day grace period** (total **270 days**). If inactive through Day 270, the MSISDN is permanently terminated and recycled into the public number pool.
   - **Nepal Telecom (NTC) Policy:** NTC operates on a strict **denomination-based validity schedule**:
     * **10 NPR (0.031 OMR / $0.08 USD via DT One `6972`):** Adds **5 days** validity.
     * **20 NPR (0.062 OMR / $0.16 USD via DT One `6973`):** Adds **10 days** validity.
     * **50 NPR (0.154 OMR / $0.40 USD via DT One `6976`):** Adds **30 days** validity.
     * **100 NPR (0.307 OMR / $0.80 USD via DT One `4569`):** Adds **60 days** validity.
     * **200 NPR (0.613 OMR / $1.59 USD via DT One `4570`):** Adds **140 days** validity.
     * **500 NPR (1.531 OMR / $3.98 USD via DT One `4571`):** Adds **360 days (1 full year!)** validity.
     * **1000 NPR (3.062 OMR / $7.96 USD via DT One `4574`):** Adds **730 days (2 full years!)** validity.
     * When validity expires, NTC lines enter **30 days One-Way Barred** $\rightarrow$ **30 days Two-Way Barred** $\rightarrow$ **60 days Frozen/Grace** before MSISDN recycling.

2. **Taxation & Government Deductions on Top-Ups:**
   - Airtime recharges in Nepal are subject to statutory government charges:
     * **10% Telecommunication Service Charge (TSC)** (administered under the Nepal Finance Act).
     * **13% Value Added Tax (VAT)**.
   - KeepSIMs digital recharges deliver nominal face value to the core balance, guaranteeing full validity extension on both operators.

3. **KeepSIMs Automated Mini-Refill Strategies:**
   - **For Ncell Users:** KeepSIMs schedules automated mini-refills on **Day 90–120** (delivering a **30–50 NPR micro-pack / $0.24–$0.40 USD via DT One**) to perpetually reset the 180-day dormancy clock.
   - **For Nepal Telecom (NTC) Users:** KeepSIMs provides two distinct modes:
     * **Annual Preservation Mode:** Delivers a **500 NPR refill ($3.98 USD via DT One)** once every **350 days**, locking in 360 days of continuous active validity for just ~$0.33/month.
     * **Quarterly Micro-Refill Mode:** Delivers a **50 NPR refill ($0.40 USD via DT One)** every **60–90 days**.

4. **Multi-Rail Failover Execution:**
   - **DT One** serves as **Primary Direct Rail (`priority: 10`, `is_primary: true`)** for both active operators (Ncell ID `1442`, NTC ID `1443`) with verified micro-entry amounts (from 10 NPR / $0.08 USD for NTC, 30 NPR / $0.24 USD for Ncell) and instant pre-prod execution.
   - **Reloadly** serves as **Secondary Direct Rail (`priority: 20`)** with flexible open-range airtime from $0.38 USD and 33 curated data bundles.
   - **Zendit** serves as **Tertiary Failover (`priority: 30`)** for fixed top-up denominations.
   - **DingConnect** is **Disabled (`priority: 40`, `is_enabled: false`)** due to 0 active catalog SKUs in UAT.
   - **Smart Cell** is permanently set to **`is_supported: false`** and disabled across all provider maps following NTA's license revocation.
