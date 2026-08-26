# Provider Comparison & Test Report: Vodafone Cyprus (Northern Cyprus / KKTC)

> **Country:** Turkey / Northern Cyprus (`TR` / `+90 542` / `+90 548` / `TUR`)  
> **Carrier:** Kuzey Kıbrıs Vodafone (`KKTC Vodafone` / `Vodafone Cyprus`)  
> **Network Type:** Regional Operator (Northern Cyprus MNO on Turkey Dialing Code +90)  
> **Balance USSD:** Dial `*123#` | **Recharge USSD:** Dial `*111*<PIN>#` | **Customer Care:** `542` / `+905428880542`  
> **Regulatory Policy:** 180 Days Active Line Validity from last top-up | 90 Days Passive Period before line disconnection  
> **Test Date:** 2026-08-22  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `TUR` (ISO-3) | `TR` (ISO-2) | `TR` (ISO-2) | `TR` (ISO-2) |
| **Carrier / Operator Code** | `1931` ("Vodafone Cyprus Turkey") | `511` ("Vodafone Cyprus Turkey") | `Vodafone` (Turkey) | Unsupported |
| **Delivery Mechanism** | Direct Airtime Top-Up | Direct Airtime Top-Up (0 Sandbox Denoms) | Regional Fallback | Unsupported |
| **Settlement Currency** | **`OMR`** (Wholesale peg: ~2.60 USD/OMR) | **`USD`** | **`USD`** | **`OMR`** |
| **Catalog Format** | 5 Fixed Products (12–100 TRY) | 0 Denominations in Sandbox | Fallback | 0 Active Products in UAT |
| **DB Status in `carrier_provider_map`** | 🟢 **Exclusive Primary Route** (`is_primary: true`, `priority: 10`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 20`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 30`) | 🔴 **Disabled** (`is_enabled: false`, `priority: 40`) |

---

## 2. Denomination & Wholesale Price Comparison

| Face Value (TRY) | DT One Wholesale (`OMR` / `USD`) / Product ID | Reloadly Wholesale (`USD` / Net) / Op ID | Zendit Wholesale (`USD`) / Offer ID | DingConnect Direct |
| :---: | :---: | :---: | :---: | :---: |
| **12.00 TRY** (Micro-Airtime) | **0.121 OMR ($0.315 USD)** (`11581`) | 🔴 *(0 Denoms in Sandbox)* | — | 🔴 *(0 Catalog Offers)* |
| **30.00 TRY** (Standard Airtime) | **0.303 OMR ($0.788 USD)** (`11585`) | 🔴 *(0 Denoms in Sandbox)* | — | 🔴 *(0 Catalog Offers)* |
| **40.00 TRY** (Standard Airtime) | **0.403 OMR ($1.048 USD)** (`26088`) | 🔴 *(0 Denoms in Sandbox)* | — | 🔴 *(0 Catalog Offers)* |
| **50.00 TRY** (Standard Airtime) | **0.504 OMR ($1.310 USD)** (`11588`) | 🔴 *(0 Denoms in Sandbox)* | — | 🔴 *(0 Catalog Offers)* |
| **100.00 TRY** (Standard Airtime) | **1.008 OMR ($2.621 USD)** (`11589`) | 🔴 *(0 Denoms in Sandbox)* | — | 🔴 *(0 Catalog Offers)* |

---

## 3. Live Test & Simulation Results

### 1. DT One (Pre-Production API) — 🟢 Exclusive Primary Route
* **API Endpoint:** `POST /async/transactions`
* **Test Request:** Product `11581` (Vodafone Cyprus 12 TRY) to `+905420000101`
* **Status:** `201 Created` $\rightarrow$ Status: `CONFIRMED`
* **Delivered Artifact:** Transaction ID `2240792691`, Wholesale Cost: `0.121 OMR` (~$0.315 USD), Delivered: `12 TRY`
* **Result:** **Exclusive Primary Route** (`priority: 10`, `is_primary: true`).

### 2. Reloadly (Sandbox API) — 🔴 Disabled Route
* **Operator ID:** `511` ("Vodafone Cyprus Turkey")
* **Catalog Status:** Returns 0 fixed amounts / 0 range in Sandbox.
* **Result:** **Disabled Route** (`is_enabled: false`, `priority: 20`).

---

## 4. KeepSIMs Production Routing Decision

1. **Primary Direct Route:** **DT One** (`operatorId: 1931` — ultra-low entry micro-recharge from 12 TRY at **0.121 OMR / ~$0.31 USD**, `priority: 10`, `is_primary: true`).
2. **Disabled Routes:** Reloadly (`511`), Zendit, and DingConnect are disabled due to lack of dedicated KKTC Vodafone inventory.
3. **Automated Maintenance Strategy:** Automated mini-recharges of 12 TRY (~$0.31 USD) every 150 days keep Northern Cyprus Vodafone SIMs active indefinitely at minimal operational cost.
