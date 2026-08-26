# KeepSIMs — Current United Arab Emirates (AE) Provider Routing Matrix

> **Country:** United Arab Emirates (`AE` / `+971` / `ARE`)  
> **Currency Settlement:** `USD` & `OMR` (Fixed Peg: $1\text{ OMR} = 2.6008\text{ USD}$)  
> **Regulatory Activity Window:** UAE TDRA 90-Day Inactivity Rule  
> **Last Verified & Updated:** 2026-08-21  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Disabled Providers | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :--- | :---: |
| **e& (Etisalat)** | MNO | 🟢 **Reloadly** (`1100`)<br>• SKU: `rl_1100_3.11` (10 AED)<br>• Cost: **$3.11 USD** ($3.02 net)<br>• Delivery: **Direct Airtime** | 🟢 **Zendit** (`Etisalat`)<br>• Offer: `ETISALAT_AE_10_AED` (10 AED)<br>• Cost: **$3.27 USD** ($3.08 net)<br>• Delivery: Direct Airtime | 🟢 **DT One** (`2097`)<br>• Product: `13199` (10 AED Direct / PIN)<br>• Cost: **1.278 OMR ($3.32 USD)**<br>• Delivery: Direct / PIN | 🟢 **DingConnect** (`ETAE`)<br>• SKU: `ETAEE7322` (10 AED)<br>• Cost: **1.08 OMR ($2.81 USD)**<br>• Delivery: Direct Top-Up | — | [EtisalatUAE.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/AE/EtisalatUAE.md) |
| **du (EITC)** | MNO | 🟢 **Reloadly** (`529`)<br>• SKU: `rl_529_2.72` (10 AED)<br>• Cost: **$2.72 USD** ($2.67 net)<br>• Delivery: **Direct Airtime** | 🟢 **Zendit** (`du`)<br>• Offer: `DU_AE_10_AED` (10 AED)<br>• Cost: **$3.27 USD** ($3.08 net)<br>• Delivery: Direct Airtime | 🟢 **DT One** (`2098`)<br>• Product: `13207` (10 AED Direct / PIN)<br>• Cost: **1.278 OMR ($3.32 USD)**<br>• Delivery: Direct / PIN | 🟢 **DingConnect** (`DUAE`)<br>• SKU: `DUAE5117` (10 AED)<br>• Cost: **1.08 OMR ($2.81 USD)**<br>• Delivery: Direct Top-Up | — | [DuUAE.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/AE/DuUAE.md) |
| **Virgin Mobile UAE** | MVNO | 🟢 **Reloadly** (`1155`)<br>• SKU: `rl_1155_6.1` (20 AED PIN)<br>• Cost: **$6.10 USD** ($5.98 net)<br>• Delivery: **Digital PIN Voucher** | 🟢 **DT One** (`3392`)<br>• Product: `30009` (20 AED PIN)<br>• Cost: **2.555 OMR ($6.64 USD)**<br>• Delivery: Digital PIN Voucher | 🟢 **DingConnect** (`VMAE`)<br>• SKU: `VMAEE2705` (20 AED PIN)<br>• Cost: **2.16 OMR ($5.62 USD)**<br>• Delivery: Digital PIN Voucher | — | 🔴 **Zendit** (`Virgin Mobile`)<br>*(Disabled: 0 offers in AE)* | [VirginUAE.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/AE/VirginUAE.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Host Network | Balance Check USSD | Manual Recharge USSD | Customer Care / IVR |
| :--- | :--- | :---: | :---: | :---: |
| **e& (Etisalat)** | e& | `*121#` or `*140#` | `*120*<PIN>#` | `101` / `800 101` |
| **du (EITC)** | du | `*135#` | `*135*<PIN>#` or `*131*<PIN>#` | `155` / `800 155` |
| **Virgin Mobile UAE** | du (EITC) | App-first / `*135#` | `*233*<PIN>#` or `*611` | In-App / `04 381 2222` |
| **Swyp UAE** | e& | Swyp App / `*121#` | Etisalat Recharge / App | `800 7997` |

---

## 3. Key Operating Principles

1. **Reloadly Primary for UAE Direct Airtime & PIN:**
   - **du (`529`):** $2.72 USD for 10 AED direct airtime top-up.
   - **e& (`1100`):** $3.11 USD for 10 AED direct airtime top-up.
   - **Virgin Mobile (`1155`):** $6.10 USD for 20 AED digital PIN voucher.
   - Delivered with 100% automated API fulfillment.

2. **Zendit Secondary Failover for Direct Airtime:**
   - **du (`DU_AE_10_AED`)** and **e& (`ETISALAT_AE_10_AED`)** at $3.27 USD.
   - Serves as Priority 2 direct failover rail.

3. **Multi-Tier Automated Failover:**
   - When an auto-refill execution runs, KeepSIMs attempts Priority 1 (`Reloadly`) first.
   - If an upstream error occurs, the backend worker cascades to Priority 2 (`Zendit`) then Priority 3 (`DT One`).

4. **UAE TDRA 90-Day Rule Compliance:**
   - UAE telecommunications regulations enforce a 90-day inactivity suspension.
   - KeepSIMs schedules the automated mini-recharge on **Day 80–85** to ensure uninterrupted SIM line life.
