# Walkthrough: Virtual Numbers Purchase & Real-Carrier MMI Call Diversion Setup

We have implemented end-to-end Virtual Number purchasing (Telnyx wholesale pricing + `intelcallfee` markup from `app_fee_rules`) and redesigned the **KeepSIMs Smart Calling (Numbers & Smart Call Setup)** screen to match the user's provided specification (**Image 2**) with verified real-carrier MMI call diversion codes across all 22 supported countries.

---

## 1. What Was Implemented

### A. Database & Carrier Divert Rules Engine
- **Migration**: [20260924040000_carrier_call_forwarding_rules.sql](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/migrations/20260924040000_carrier_call_forwarding_rules.sql)
  - Created table `public.carrier_call_forwarding_rules` to store supplementary service MMI codes per carrier.
  - Seeded real data for all active carriers across all 22 supported countries:
    - **Saudi Arabia**: STC (`**21*{number}#`), Mobily (`**21*{number}#`), Zain KSA (`**21*{number}#`), Virgin, Friendi, Lebara, Salam, Red Bull.
    - **United Arab Emirates**: Etisalat / e& (`**21*{number}#`), du (`**21*{number}#`), Virgin Mobile UAE.
    - **Oman**: Omantel (`**21*{number}#`), Ooredoo (`**21*{number}#`), Vodafone Oman, FRiENDi, Renna, Red Bull.
    - **India**: 
      - **Reliance Jio** *(Carrier Exception)*: VoLTE star codes $\rightarrow$ `*401*{number}` (Cancel: `*402`, Check: `*401`, Cancel all: `*413`).
      - **Airtel, Vi, BSNL, MTNL**: Standard GSM codes $\rightarrow$ `**21*{number}#` (Cancel: `##21#`).
    - **Egypt**: Vodafone, Orange, Etisalat, WE.
    - **Kuwait, Bahrain, Qatar, Jordan, Iraq, Lebanon, Morocco, Algeria, Tunisia, Pakistan, Bangladesh, Philippines, Sri Lanka, Nepal, Germany, Turkey**.
  - Created Security Definer RPC `get_supported_carriers_divert()` to return joined carrier, country, flag emoji, and MMI formats.
  - Updated check constraint `wallet_transactions_type_check` to include `did_purchase_debit`.

---

### B. Supabase Edge Function (`manage-dids` Version 2 Deployed & Active)
- **File**: [manage-dids/index.ts](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/functions/manage-dids/index.ts)
  - **`search_available_numbers`**:
    - Queries Telnyx Available Numbers API (`/v2/available_phone_numbers`) in real time.
    - Reads the authoritative `intelcallfee` row from `public.app_fee_rules`.
    - Resolves caller tier (`free`: 15%, `standard`: 7%, `premium`: 3%).
    - Calculates transparent pricing per number:
      $$\text{app\_fee} = \text{round}(\text{wholesale} \times \frac{\text{tier\_percent}}{100}, 2)$$
      $$\text{total} = \text{wholesale} + \text{app\_fee}$$
  - **`purchase_number`**:
    - Verifies user's wallet balance $\ge$ total monthly fee.
    - Places number order via Telnyx API (`POST /v2/number_orders`).
    - Binds the newly ordered number to the KeepSIMs Call Control Application (`TELNYX_CALL_CONTROL_APP_ID`).
    - Atomically debits the user's wallet balance using `debit_wallet_for_topup` with `txn_type = 'did_purchase_debit'`.
    - Inserts the newly active DID into `public.virtual_did_numbers` with a 30-day renewal cycle.

---

### C. Flutter App Presentation & Purchase Flow
1. **Models**:
   - [CarrierDivertRule](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/calling/data/models/carrier_divert_model.dart): Holds MMI formatting and carrier metadata.
   - [AvailableVirtualNumber](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/calling/data/models/available_virtual_number_model.dart): Encapsulates live inventory numbers, capabilities, wholesale cost, and `intelcallfee` breakdown.
2. **Repository**:
   - Updated [calling_repository.dart](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/calling/data/repositories/calling_repository.dart) with `searchAvailableNumbers`, `purchaseVirtualNumber`, and `getCarrierDivertRules`.
3. **Purchase Modal ([BuyVirtualNumberSheet](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/calling/presentation/widgets/buy_virtual_number_sheet.dart))**:
   - Allows users to select country (US 🇺🇸, UK 🇬🇧, Canada 🇨🇦, Germany 🇩🇪, etc.) and filter by area code.
   - Displays available numbers with capabilities (`Voice + SMS`) and total monthly cost.
   - Checkout confirmation sheet showing transparent breakdown:
     - Telnyx Wholesale Monthly (e.g., \$1.00)
     - KeepSIMs Service Fee (`intelcallfee` badge: Free 15%, Standard 7%, Premium 3%)
     - Total Monthly Subscription (e.g., \$1.15/mo)
     - Wallet balance check with direct "Top Up" redirection if funds are insufficient.
     - Single-tap activation that updates the wallet and provisions the number immediately.
4. **Numbers & Setup Screen ([MyNumbersScreen](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/calling/presentation/screens/my_numbers_screen.dart))**:
   - Redesigned to strictly match **Image 2**:
     - **Header**: `KeepSIMs` with purple `Smart Calling` badge, subtitle `Zero-Roaming Cloud Calling & DID Sandbox`.
     - **Provisioned Virtual Numbers Card**:
       - Row with `+ Add Number` button on the right.
       - Number cards displaying Flag, Title (e.g., `US Cloud Gateway`, `London Virtual DID`), `ACTIVE` green badge, and formatted phone number (e.g. `+1 (754) 318-0369`).
       - `Inbound Action` dropdown menu (`Ring In-App`, `Voicemail`, `Forward Phone`).
       - Three-dots menu for quick actions (Copy number, select for smart setup).
     - **KeepSIMs Smart Call Setup Card**:
       - Rounded container with `Zero-Roaming` airplane badge.
       - **Step 1**: Home Operator selector with real carriers across supported countries (e.g. `STC Saudi`, `Jio`, `du`, `Etisalat (e&)`, etc.).
       - **Step 2**: Generated MMI code with `Copy Code` button and phone dialer launcher.
       - Carrier-specific logic: generates `**21*<number>#` for GSM operators and `*401*<number>` for Reliance Jio.
       - Deactivation note (`##21#` or `*402`).
       - **How it works** summary with 3 green checkmarks.

---

## 2. Verification & Validation Results

### Automated Tests
1. **Flutter Unit & Widget Tests**:
   - Ran `test/features/calling/my_numbers_screen_test.dart`:
     - Test 1: Verified header, numbers list, "+ Add Number" button, inbound action dropdown, and Smart Call Setup matching Image 2 $\rightarrow$ **PASSED**.
     - Test 2: Verified operator switching from STC Saudi (`**21*`) to Reliance Jio (`*401*` and cancel `*402`) $\rightarrow$ **PASSED**.
2. **Flutter Static Analysis**:
   - Ran `flutter analyze lib/features/calling test/features/calling` $\rightarrow$ **0 issues found**.
3. **Database Verification**:
   - Verified `get_supported_carriers_divert()` via Supabase SQL execution $\rightarrow$ Successfully returned carriers with country flags and MMI rules.
4. **Edge Function Verification**:
   - `manage-dids` deployed to `zwxswagokhgbuzrrbnhr` as version 2 with status **ACTIVE**.
