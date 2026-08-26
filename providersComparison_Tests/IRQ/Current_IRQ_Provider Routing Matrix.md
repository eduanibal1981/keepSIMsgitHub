# KeepSIMs — Current Iraq (IQ) Provider Routing Matrix

> **Country:** Iraq (`IQ` / `+964` / `IRQ`)  
> **Currency Settlement:** `USD` & `OMR` (Fixed Peg: $1\text{ OMR} = 2.6008\text{ USD}$)  
> **Local Currency:** Iraqi Dinar (`IQD`)  
> **Regulatory Framework:** Communications and Media Commission (CMC Iraq) Tiered Validity (30–90 Days Active + 60 Days Grace Quarantine)  
> **Last Verified & Updated:** 2026-08-23  

---

## 1. Master Production Routing Matrix

| Telecom Carrier | Type | Priority 1: Primary (`priority: 10`) | Priority 2: Secondary (`priority: 20`) | Priority 3: Tertiary (`priority: 30`) | Priority 4: Quaternary (`priority: 40`) | Disabled Providers | Individual Report |
| :--- | :---: | :--- | :--- | :--- | :--- | :--- | :---: |
| **AsiaCell** | MNO | 🟢 **Zendit** (`AsiaCell`)<br>• Offer: `ASIACELL_IQ_001`<br>• Amount: 5,000 IQD<br>• Cost: **$4.18 USD Net**<br>• Delivery: **Direct Airtime** | 🟢 **DT One** (`42`)<br>• Product: `4042` (5k IQD Direct, 1.848 OMR)<br>• Product: `39018` (3k IQD PIN, 1.235 OMR)<br>• Delivery: **Direct & Micro PIN** | 🟢 **Reloadly** (`246`)<br>• Amount: 5,000 IQD<br>• Cost: **$6.82 USD Net**<br>• Delivery: Direct Airtime | 🔴 **DingConnect** (`ACIQ`)<br>*(Disabled: 0 UAT offers)* | — | [AsiaCellIRQ.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/IRQ/AsiaCellIRQ.md) |
| **Zain Iraq** | MNO | 🟢 **DT One** (`3817`)<br>• Product: `38999` (5,000 IQD)<br>• Cost: **2.050 OMR ($5.33 USD)**<br>• Validity: **90 Days**<br>• Delivery: **Digital PIN Voucher** | 🔴 **Zendit** (`Zain`)<br>*(Disabled: 0 offers)* | 🔴 **Reloadly**<br>*(Disabled: Not mapped)* | 🔴 **DingConnect** (`ZAIQ`)<br>*(Disabled: 0 offers)* | Zendit, Reloadly, DingConnect | [ZainIRQ.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/IRQ/ZainIRQ.md) |
| **Korek Telecom** | MNO | 🟢 **DT One** (`2096`)<br>• Product: `39011` (5,000 IQD)<br>• Cost: **2.050 OMR ($5.33 USD)**<br>• Validity: **40 Days**<br>• Delivery: **Digital PIN Voucher** | 🔴 **DingConnect** (`KKIQ`/`KRIQ`)<br>*(Disabled: 0 UAT offers)* | 🔴 **Zendit** (`Korek`)<br>*(Disabled: 0 offers)* | 🔴 **Reloadly**<br>*(Disabled: Not mapped)* | DingConnect, Zendit, Reloadly | [KorekIRQ.md](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/providersComparison_Tests/IRQ/KorekIRQ.md) |

---

## 2. Technical USSD & Service Reference

| Carrier Name | Operator Type | Balance Check USSD | Manual Recharge USSD | Customer Care / IVR |
| :--- | :---: | :---: | :---: | :---: |
| **AsiaCell** | MNO | `*133#` or `*211#` | `*133*<PIN>#` or call `333` | `111` / `07701110000` / `+9647701110000` |
| **Zain Iraq** | MNO | `*100#` or `*200#` | `*101*<PIN>#` or call `216` | `107` / `07802999107` / `+9647802999107` |
| **Korek Telecom** | MNO | `*211#` | `*221*<PIN>#` or call `321` / `221` | `411` / `07500000411` / `+9647500000411` |

---

## 3. Key Operating Principles & CMC Regulatory Rules

1. **CMC Iraq Validity Structure:**
   - Communications and Media Commission (CMC Iraq) enforces tiered line validity based on recharge amount:
     - **3,000–5,000 IQD:** Grants **40–45 days** (AsiaCell: 45 days, Korek: 40 days, Zain: 90 days).
     - **10,000–15,000 IQD:** Grants **90–100 days**.
     - **25,000+ IQD:** Grants **180–360 days**.
   - Upon validity expiry, lines enter a mandatory **60-day grace quarantine phase** where incoming calls and SMS are retained, but outgoing traffic is barred.
   - If no qualifying recharge is applied before the grace period ends, the SIM card is permanently terminated and the mobile number is recycled.

2. **KeepSIMs Automated Mini-Refill Strategy:**
   - Scheduled auto-refills trigger **5–10 days before validity expiration** (e.g. Day 35–40 for AsiaCell/Korek, Day 80–85 for Zain).
   - For **AsiaCell**, Zendit direct airtime (`ASIACELL_IQ_001` @ $4.18 USD) is the primary route, with DT One Product 4042 (1.848 OMR / ~$4.81 USD) and Product 39018 (3,000 IQD micro-PIN @ 1.235 OMR / ~$3.21 USD) serving as secondary failover.
   - For **Zain Iraq** and **Korek Telecom**, DT One digital PIN vouchers (5,000 IQD @ 2.050 OMR / ~$5.33 USD) provide reliable, direct-to-app voucher fulfillment and automated USSD push.

3. **Multi-Rail Failover Execution:**
   - KeepSIMs workers route to Priority 1 first. If an upstream error or network timeout occurs, the request automatically cascades to Priority 2 and Priority 3.
   - DingConnect is currently disabled for Iraq due to rate limiting / 0 active inventory in UAT.
