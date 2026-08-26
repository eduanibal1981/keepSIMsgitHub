# Provider Comparison & Test Report: Smart Cell (Smart Telecom)

> **Country:** Nepal (`NP` / `+977` / `NPL`)  
> **Carrier:** Smart Telecom Pvt. Ltd. (`Smart Cell` / `Smart Telecom`)  
> **Network Type:** Former MNO (3rd Mobile Operator / License Revoked by NTA)  
> **Prefixes:** `961`, `962`, `988` (`+977961xxxxxxx`, `+977962xxxxxxx`, `+977988xxxxxxx`)  
> **Balance USSD:** `*102#` (Legacy) | **Recharge USSD:** `*122*<PIN>#` (Legacy)  
> **Regulatory & Operational Status:** **DECOMMISSIONED / NON-OPERATIONAL**. In April 2023, the Nepal Telecommunications Authority (NTA) formally cancelled Smart Telecom's operating license due to non-payment of statutory dues and spectrum fees (~NPR 27 billion). The network assets were taken over by an NTA management committee and commercial mobile operations ceased.  
> **Test Date:** 2026-08-23  

---

## 1. Provider Identifier & Carrier Mapping

| Parameter | **DT One** (`dtone`) | **Reloadly** (`reloadly`) | **Zendit** (`zendit`) | **DingConnect** (`ding`) |
| :--- | :--- | :--- | :--- | :--- |
| **Country Code** | `NPL` (ISO-3) | `NP` (ISO-2) | `NP` (ISO-2) | `NP` (ISO-2) |
| **Carrier / Operator Code** | *(Not Listed / Decommissioned)* | `805` ("Smartcell Nepal") | *(Not Listed)* | *(Not Listed)* |
| **Delivery Mechanism** | N/A | Fixed Amounts (Sandbox Legacy) | N/A | N/A |
| **Settlement Currency** | N/A | `USD` | N/A | N/A |
| **Catalog Format** | Decommissioned | 7 Fixed Amounts ($0.08, $0.15, $0.38, $0.75, $1.51, $3.77, $7.54 USD) | Decommissioned | Decommissioned |
| **DB Status in `carrier_provider_map`** | 🔴 **Not Mapped** | 🔴 **Disabled** (`is_enabled: false`, `priority: 20`) | 🔴 **Not Mapped** | 🔴 **Not Mapped** |

---

## 2. Live Test & Simulation Results

### 1. Reloadly (Sandbox API) — 🔴 Disabled Route (Legacy Catalog Check)
* **API Endpoint:** `POST /topups`
* **Test Request:** Operator `805` (Smartcell Nepal, $0.08 USD requested) to `+9779610000101`
* **Status:** `200 OK` $\rightarrow$ Status: `SUCCESSFUL` (Sandbox simulated response)
* **Delivered Artifact:** Transaction ID `178473`, Delivered: `10 NPR`, Wholesale Cost: `$0.076 USD`
* **Result:** **Disabled Route** (`is_enabled: false`, `is_supported: false`).

---

## 3. KeepSIMs Production Routing Decision

1. **Operational Status:** **Decommissioned / Unsupported (`is_supported: false`)**.
2. **Routing:** All provider routes for Smart Cell are permanently set to `is_enabled: false`.
3. **Regulatory Context:** NTA revoked Smart Telecom's GSM mobile license in 2023. Mobile subscribers were migrated to Nepal Telecom and Ncell. KeepSIMs maintains the catalog record for historical reference and number classification.
