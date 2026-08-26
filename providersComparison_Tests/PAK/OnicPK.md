# Provider Comparison & Test Report: Onic Pakistan (Digital MVNO / PTCL Sub-Brand)

> **Country:** Pakistan (`PK` / `+92` / `PAK`)  
> **Carrier:** Onic Pakistan (`Onic` / `PTCL Group Digital Brand`)  
> **Network Type:** Digital MVNO / Sub-Brand (Host Network: Ufone / PTCL Group)  
> **Account App:** Onic App | **Portal:** onic.pk  
> **Customer Care:** `hello@onic.pk` / Onic In-App Support  
> **Regulatory Policy (PTA Pakistan):** 180 Days Active Line Validity from last qualifying transaction/recharge | 30 Days Suspension Grace Period | 15% Advance Income Tax (AIT/WHT)  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `PAK` (ISO-3) | `PK` (ISO-2) | `PK` (ISO-2) | `PK` (ISO-2) |
| **Carrier / Operator Code** | `486` (via Ufone Host Rails) | `355` (via Ufone Host Rails) | `Ufone` (Host Rails) | `UFPK` (via Ufone Host Rails) |
| **Delivery Mechanism** | Direct Airtime Top-Up via Ufone | Direct Airtime Top-Up via Ufone | Direct Top-Up via Ufone | Direct Top-Up (0 Inventory in UAT) |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 210 Products via Ufone (60–10000 PKR) | Open Range (100–10000 PKR) | 49 Offers via Ufone | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Primary Direct via Ufone** (`is_primary: true`, `priority: 10`) | 🟢 **Secondary Direct Failover** (`priority: 20`) | 🟢 **Tertiary Direct Failover** (`priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Infrastructure & Delivery Architecture

* **Digital MVNO Architecture:** Onic launched in 2023 as PTCL Group's digital-first sub-brand, operating on the Ufone core network (MNC: 410-01).
* **Top-Up Compatibility:** Because Onic shares the Ufone Home Location Register (HLR) and Intelligent Network (IN) billing core, direct airtime refills and balance recharges sent to Onic MSISDNs (`+92 33x`) are processed and credited through Ufone wholesale top-up rails.
* **In-App Digital Bundles:** Onic users can also subscribe to digital plans directly in the Onic mobile app using main balance credited via KeepSIMs automated mini-refills.

---

## 3. Denomination & Wholesale Price Comparison

| Face Value (PKR) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct (`UFPK`) |
| :---: | :---: | :---: | :---: | :---: |
| **60.00 PKR** (Daily Shoq Pack) | **0.103 OMR ($0.268 USD)** (`63162`) | — | — | 🔴 *(0 Catalog Offers)* |
| **100.00 PKR** (Airtime Load) | **0.168 OMR ($0.437 USD)** (`2788`) | **$0.41 USD ($0.3895 net)** (`355`) | — | 🔴 *(0 Catalog Offers)* |
| **150.00 PKR** (Airtime Load) | **0.252 OMR ($0.655 USD)** (`2789`) | **$0.62 USD ($0.589 net)** (`355`) | — | 🔴 *(0 Catalog Offers)* |
| **200.00 PKR** (Airtime Load) | **0.336 OMR ($0.874 USD)** (`2790`) | **$0.82 USD ($0.779 net)** (`355`) | — | 🔴 *(0 Catalog Offers)* |
| **500.00 PKR** (Airtime Load) | **0.840 OMR ($2.184 USD)** (`2792`) | **$2.06 USD ($1.957 net)** (`355`) | **$1.89 USD** (`UFONE_PK_OPEN`) | 🔴 *(0 Catalog Offers)* |
| **1000.00 PKR** (Airtime Load) | **1.680 OMR ($4.368 USD)** (`2793`) | **$4.12 USD ($3.913 net)** (`355`) | **$3.78 USD** (`UFONE_PK_OPEN`) | 🔴 *(0 Catalog Offers)* |

---

## 4. Live Test & Simulation Results

* **DT One Ufone Rails Test:** Product `2788` (100 PKR) confirmed (`Tx 2240792666`, Status: `CREATED`).
* **Reloadly Ufone Rails Test:** Operator `355` confirmed (`Tx 178402`, Status: `SUCCESSFUL`, delivered 99.53 PKR at $0.3895 USD net).
* **Zendit Ufone Rails Test:** Offer `UFONE_PK_001` confirmed (`test_pk_zen_ufone_1787385065363`, Status: `ACCEPTED`).

---

## 5. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 486` via Ufone rails — 100 PKR at 0.168 OMR wholesale, `priority: 10`, `is_primary: true`).
2. **Secondary Direct Failover:** **Reloadly** (`operatorId: 355` via Ufone rails — open range 100–10,000 PKR, `priority: 20`).
3. **Tertiary Direct Failover:** **Zendit** (`brand: Ufone` via Ufone rails, `priority: 30`).
4. **PTA Pakistan Regulatory Compliance:**
   - Onic Pakistan SIM cards adhere to PTA's standard **180-day inactivity policy**.
   - KeepSIMs schedules automated mini-refills on **Day 150–165** (using a 100 PKR direct top-up / ~$0.44 USD via DT One) to reset the 180-day PTA validity counter and safeguard the Onic digital line indefinitely.