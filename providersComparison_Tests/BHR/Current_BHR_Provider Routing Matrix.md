# KeepSIMs — Current Bahrain (BHR) Provider Routing Matrix

> **Country:** Bahrain (`BH` / `+973` / `BHR`)  
> **Currency Settlement:** `USD` (Reloadly / Zendit) & `OMR` (DT One / DingConnect)  
> **Local Currency:** Bahraini Dinar (`BHD` / `د.ب`)  
> **Regulatory Framework:** Telecommunications Regulatory Authority (TRA) Bahrain — 90-Day Inactivity Lifecycle + 90-Day Suspension Grace Period | 10% VAT standard on telecommunication services  
> **Last Verified & Updated:** 2026-08-23  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **Batelco** | MNO (Incumbent) | 🟢 **Reloadly** (`22`)<br>• Operator: `22`<br>• Cost: **$2.989 USD** (1.15 BHD PIN)<br>• Delivery: **Digital PIN Voucher** | 🟢 **DT One** (`1828`)<br>• Product: `56728` (2.25 BHD)<br>• Cost: **2.866 OMR ($7.45 USD)**<br>• Delivery: 10 Fixed PINs (365d) | 🟢 **DingConnect** (`BVBH`)<br>• Provider: `BVBH`<br>• Delivery: Direct / PIN | 🔴 **Zendit** (`Batelco`)<br>*(Disabled: 0 catalog offers)* | [BatelcoBHR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/BHR/BatelcoBHR.md) |
| **Zain Bahrain** | MNO (National) | 🟢 **Reloadly** (`1165`)<br>• Operator: `1165`<br>• Cost: **$1.55 USD** (0.58 BHD)<br>• Delivery: **Direct Airtime Top-Up** | 🟢 **DT One** (`1829`)<br>• Product: `58111` (1.00 BHD)<br>• Cost: **1.274 OMR ($3.31 USD)**<br>• Delivery: 20 Direct SKUs | 🟢 **DingConnect** (`ZABH`)<br>• Provider: `ZABH`<br>• Delivery: Direct Top-Up | 🔴 **Zendit** (`Zain`)<br>*(Disabled: 0 catalog offers)* | [ZainBHR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/BHR/ZainBHR.md) |
| **STC Bahrain** | MNO (3rd Telco) | 🔴 **DingConnect** (`STC`)<br>• Gateway: Local / API | 🔴 **Reloadly**<br>*(0 sandbox products)* | 🔴 **DT One**<br>*(0 pre-prod products)* | 🔴 **Zendit**<br>*(0 catalog offers)* | [StcBHR.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/BHR/StcBHR.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Network Type | Balance Check USSD / Method | Recharge USSD | Customer Care / IVR | Notes |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Batelco** | MNO (Incumbent) | `*122#` | `*125*<PIN>#` / Call `111` | `196` / `+973 1788 1111` | 8 Reloadly PIN amounts & 10 DT One PIN products (up to 365 days validity) |
| **Zain Bahrain** | MNO (National) | `*142#` | `*141*<PIN>#` / Zain App | `107` / `+973 3779 7995` | Ultra-low $1.55 USD micro-refill via Reloadly & 20 DT One direct airtime products |
| **STC Bahrain** | MNO (National) | `*124#` / `*142#` | `*123*<PIN>#` / stc pay BH | `124` / `+973 3312 4124` | 90-day inactivity lifecycle with recharge validity extension |

---

## 3. Key Operating Principles & TRA Bahrain Regulatory Rules

1. **TRA Bahrain Prepaid Line Validity Rules:**
   - **Batelco:** Prepaid SIM cards maintain an active validity of **90 to 365 days** depending on voucher face value (Product `56728` 2.25 BHD grants 365 days).
   - **Zain Bahrain:** Direct airtime recharges extend line validity by **60 to 100 days**.
   - **STC Bahrain:** Standard prepaid recharge vouchers grant **30 to 90 days** active validity.
   - **Taxation:** 10% standard VAT applies on telecommunications services in the Kingdom of Bahrain.

2. **Suspension & Grace Period:**
   - After the active validity period expires without qualifying recharge or paid activity, all operators enforce a **90-day grace/suspension period** (incoming-only calls and SMS).
   - If no recharge occurs during the 90-day grace period, the SIM is permanently cancelled, remaining balance forfeited, and the mobile number recycled back to the TRA Bahrain national numbering plan.

3. **KeepSIMs Automated Mini-Refill Strategy:**
   - For **Zain Bahrain**: Automated direct airtime top-up of **$1.55 USD (0.58 BHD)** via Reloadly scheduled on **Day 80–85** resets the inactivity timer seamlessly at ultra-low cost.
   - For **Batelco**: Automated digital PIN voucher of **$2.989 USD ($3.05 USD / ~1.15 BHD)** via Reloadly or **2.25 BHD (2.866 OMR)** via DT One scheduled on **Day 80–85** preserves line validity for up to 365 days.
   - For **STC Bahrain**: Automated refill scheduled before the 90-day threshold preserves line connectivity.
