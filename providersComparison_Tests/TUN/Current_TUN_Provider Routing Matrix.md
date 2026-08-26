# Tunisia (TN / +216) Master Provider Routing Matrix

> **Country:** Tunisia (`TN` / `+216` / `TUN`)  
> **Currency:** Tunisian Dinar (`TND` / د.ت)  
> **National Telecom Regulator:** Instance Nationale des Télécommunications (INTT)  
> **Prepaid Regulatory Rule:** 90–180 days active validity from last recharge + 90-day grace/quarantine window before permanent deactivation & recycling  
> **Fiscal Policy:** 19% TVA (VAT) + 100–400 millimes telecom royalty tax included in or added to prepaid recharges  
> **Last Verification Date:** 2026-08-23  

---

## 1. Executive Master Routing Matrix

| Carrier Name | KeepSIMs Canonical ID | Primary Route (`priority: 10`) | Secondary Route (`priority: 20`) | Tertiary Route (`priority: 30`) | Disabled Provider (`priority: 40`) | Minimum Entry Refill (USD) | INTT Mini-Refill Schedule |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Ooredoo Tunisia** | `27a7a925-1af0-4697-b39e-f0a12a8c131b` | **DT One** (`1532`) | **Reloadly** (`508`) | **Zendit** (`Ooredoo`) | 🔴 **DingConnect** (`TUTN`) | **$0.85 USD** (2.00 TND) | Day 60–80 (2 TND via DT One) |
| **Tunisie Telecom** | `2ae782fb-66db-4471-b773-bfee4a5d7707` | **DT One** (`678`) | **Reloadly** (`507`) | **Zendit** (`TunisieTelecom`) | 🔴 **DingConnect** (`TWTN`) | **$2.22 USD** (5.40 TND) | Day 60–80 (5.4 TND via DT One) |
| **Orange Tunisia** | `e6f8679a-7232-4981-9e39-abcae5009f6f` | **DT One** (`1530`) | **Reloadly** (`506`) | **Zendit** (`Orange`) | 🔴 **DingConnect** (`ORTN`) | **$0.67 USD** (1.60 TND) | Day 60–80 (1.6 TND via DT One) |

---

## 2. Detailed Carrier Provider Map (`carrier_provider_map`)

| Carrier | Provider | Country Code | Carrier Code | Carrier Label | Priority | Enabled | Primary | Route Role & Notes |
| :--- | :--- | :---: | :---: | :--- | :---: | :---: | :---: | :--- |
| **Ooredoo Tunisia** | `dtone` | `TUN` | `1532` | Ooredoo Tunisia | 10 | 🟢 True | 🟢 True | **Primary Direct:** 2.00 TND micro entry @ 0.325 OMR (~$0.845 USD), 33 fixed SKUs + Open Range `11905` (2–150 TND) |
| **Ooredoo Tunisia** | `reloadly` | `TN` | `508` | Ooredoo Tunisia | 20 | 🟢 True | ⚪ False | **Secondary Direct:** Range $0.93–$70.09 USD (2–150 TND) with 5% discount |
| **Ooredoo Tunisia** | `zendit` | `TN` | `Ooredoo` | Ooredoo Tunisia | 30 | 🟢 True | ⚪ False | **Tertiary Direct:** 7 Fixed offers (5 to 75 TND) from $1.89 USD wholesale |
| **Ooredoo Tunisia** | `ding` | `TN` | `TUTN` | Ooredoo (Tunisiana) Tunisia | 40 | 🔴 False | ⚪ False | **Disabled:** 0 active products in UAT catalog (503 RateLimited) |
| **Tunisie Telecom** | `dtone` | `TUN` | `678` | Tunisie Telecom Tunisia | 10 | 🟢 True | 🟢 True | **Primary Direct:** 5.40 TND @ 0.852 OMR (~$2.215 USD), 10.80 TND @ 1.703 OMR, 21.60 TND @ 3.405 OMR |
| **Tunisie Telecom** | `reloadly` | `TN` | `507` | Tunisie Telecom Tunisia | 20 | 🟢 True | ⚪ False | **Secondary Direct:** Fixed 5.4, 10.8, 21.6 TND with 2% discount |
| **Tunisie Telecom** | `zendit` | `TN` | `TunisieTelecom` | Tunisie Telecom | 30 | 🟢 True | ⚪ False | **Tertiary Direct:** 3 Fixed offers (5.4, 10.8, 21.6 TND) from $2.09 USD wholesale |
| **Tunisie Telecom** | `ding` | `TN` | `TWTN` | Tunisie Telecom Tunisia | 40 | 🔴 False | ⚪ False | **Disabled:** 0 active products in UAT catalog (503 RateLimited) |
| **Orange Tunisia** | `dtone` | `TUN` | `1530` | Orange Tunisia | 10 | 🟢 True | 🟢 True | **Primary Direct:** 1.60 TND micro entry @ 0.259 OMR (~$0.673 USD), 31 fixed SKUs + Range `54628` (10–102 TND) |
| **Orange Tunisia** | `reloadly` | `TN` | `506` | Orange Tunisia | 20 | 🟢 True | ⚪ False | **Secondary Direct:** Range $4.35–$79.05 USD (11–200 TND) with 10% discount |
| **Orange Tunisia** | `zendit` | `TN` | `Orange` | Orange Tunisia | 30 | 🟢 True | ⚪ False | **Tertiary Direct:** 35 Fixed offers + Open Range `ORANGE_TN_OPEN` (9.19–204.35 TND) |
| **Orange Tunisia** | `ding` | `TN` | `ORTN` | Orange Tunisia | 40 | 🔴 False | ⚪ False | **Disabled:** 0 active products in UAT catalog (503 RateLimited) |

---

## 3. KeepSIMs Operational Recommendations

1. **Routing Hierarchy:**
   - **Primary Route:** **DT One** is established as the primary direct fulfillment route across all 3 Tunisian carriers. It delivers the lowest entry point micro-recharges (1.60 TND for Orange Tunisia, 2.00 TND for Ooredoo Tunisia, 5.40 TND for Tunisie Telecom) and verified sub-second pre-prod execution.
   - **Secondary Route:** **Reloadly** acts as the high-availability secondary direct route with flexible range support and discount tiers (5% on Ooredoo, 10% on Orange, 2% on Tunisie Telecom).
   - **Tertiary Route:** **Zendit** serves as an operational third direct failover with live fixed and open range offers.
   - **DingConnect:** Disabled across all Tunisian carriers due to empty UAT catalog inventory (503 RateLimited).

2. **INTT Regulatory Compliance & SIM Preservation:**
   - All Tunisian prepaid SIMs require recharge activity within **90 to 180 days** to prevent account suspension and entry into the 90-day quarantine period.
   - KeepSIMs automated health-check daemon schedules mini-recharges on **Day 60–80** before the expiration threshold, keeping the SIM in active status indefinitely at minimum cost.
