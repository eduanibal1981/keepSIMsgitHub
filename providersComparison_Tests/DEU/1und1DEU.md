# Provider Comparison & Test Report: 1&1 Telecom Germany

> **Country:** Germany (`DE` / `+49` / `DEU`)  
> **Carrier:** 1&1 Mobilfunk GmbH (1&1 Drillisch / United Internet AG / 4th Mobile Network Operator in Germany)  
> **Network Type:** MNO (4th German Mobile Network + National Roaming via Telefónica & Vodafone)  
> **Balance / Account App:** 1&1 Control-Center App / Web: `https://control-center.1und1.de/`  
> **Recharge Method:** Online Top-Up via 1&1 Control Center / SEPA Direct Debit / Bank Transfer / Voucher Vending  
> **Customer Care:** Dial `0721 96 00` (Free from 1&1 mobile)  
> **Regulatory Policy (BNetzA Germany):** 180 Days Active Line Validity from last top-up/billable event | 60 Days Passive Grace Period before line termination | Mandatory ID verification (§ 111 TKG PostIdent/VideoIdent) | 19% VAT included  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `DEU` (ISO-3) | `DE` (ISO-2) | `DE` (ISO-2) | `DE` (ISO-2) |
| **Carrier / Operator Code** | Unsupported in Aggregators | Unsupported in Aggregators | Unsupported in Aggregators | Unsupported in Aggregators |
| **Delivery Mechanism** | Web Direct Debit / SEPA | Web Direct Debit / SEPA | Web Direct Debit / SEPA | Web Direct Debit / SEPA |
| **Settlement Currency** | **`EUR`** | **`EUR`** | **`EUR`** | **`EUR`** |
| **Catalog Format** | 0 Aggregator Offers | 0 Aggregator Offers | 0 Aggregator Offers | 0 Aggregator Offers |
| **DB Status in `carrier_provider_map`** | 🔴 **Disabled in Aggregators** | 🔴 **Disabled in Aggregators** | 🔴 **Disabled in Aggregators** | 🔴 **Disabled in Aggregators** |

---

## 2. Denomination & Technical Details

* **Direct Web / SEPA Rail:** 1&1 operates primarily on postpaid contracts and hybrid prepaid tariffs managed directly through the 1&1 Control-Center portal.
* **National Roaming:** In regions where 1&1 Open RAN coverage is rolling out, devices roam seamlessly onto Telefónica (O2) and Vodafone networks.
* **KeepSIMs Strategy:** Customers with 1&1 subscriptions maintain active lines through recurring bank mandates or manual online top-ups.

---

## 3. BNetzA Germany Regulatory Compliance

* 1&1 lines are subject to standard BNetzA regulatory policies requiring periodic account activity and mandatory ID verification under § 111 TKG.
* KeepSIMs monitors 1&1 SIM card validity and prompts users before inactivity milestones.
