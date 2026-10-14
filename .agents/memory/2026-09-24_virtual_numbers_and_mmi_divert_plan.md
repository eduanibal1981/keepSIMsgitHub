# Implementation Plan: Virtual Numbers Purchase & Smart Call Divert Setup

Implement end-to-end Virtual Number purchasing (Telnyx wholesale pricing + `intelcallfee` tier fee from `app_fee_rules`) and redesign the **KeepSIMs Smart Calling (Numbers & Smart Call Setup)** screen to match the user's provided specification with verified real-carrier MMI call diversion codes across all 22 supported countries.

---

## User Review Required

> [!IMPORTANT]
> **Virtual Number Purchase & Billing Model**:
> 1. **Telnyx Wholesale Base Cost**: Queried live via Telnyx Available Numbers API (`cost_information.monthly_cost`, typically \$1.00/mo for US/UK/Canada).
> 2. **KeepSIMs App Fee**: Computed strictly using the active `intelcallfee` row from `public.app_fee_rules`:
>    - **Free Tier**: 15% service fee (e.g., +\$0.15 on a \$1.00 base $\rightarrow$ **\$1.15/mo**)
>    - **Standard Tier**: 7% service fee (e.g., +\$0.07 on a \$1.00 base $\rightarrow$ **\$1.07/mo**)
>    - **Premium Tier**: 3% service fee (e.g., +\$0.03 on a \$1.00 base $\rightarrow$ **\$1.03/mo**)
> 3. **Payment Method**: Deducted atomically from the user's KeepSIMs wallet (`wallets` table). If the balance is insufficient, the UI prompts the user to top up with their needed amount before completing purchase.
> 4. **Auto-Renewal**: Numbers are provisioned for 30 days and renew automatically from wallet balance every month unless released by the user.

> [!NOTE]
> **MMI Code Standards & Exceptions Across 22 Countries**:
> - 21 of the 22 supported countries (Saudi Arabia, UAE, Oman, Kuwait, Bahrain, Qatar, Egypt, Jordan, Iraq, Lebanon, Morocco, Algeria, Tunisia, Pakistan, Bangladesh, Philippines, Sri Lanka, Nepal, Germany, Turkey, Syria) follow the standard 3GPP GSM Supplementary Service MMI codes:
>   - **Unconditional Forwarding**: `**21*<VirtualNumber>#` (Cancel: `##21#`, Status: `*#21#`)
>   - **When Busy**: `**67*<VirtualNumber>#` (Cancel: `##67#`)
>   - **When Unanswered (No Reply)**: `**61*<VirtualNumber>#` (Cancel: `##61#`)
>   - **When Unreachable / Flight Mode**: `**62*<VirtualNumber>#` (Cancel: `##62#`)
>   - **Cancel All Call Forwarding**: `##002#`
> - **India Exception (Reliance Jio)**: Reliance Jio operates on pure VoLTE and uses proprietary star codes instead of standard GSM `#` hashes:
>   - **Unconditional Forwarding**: `*401*<VirtualNumber>` (Cancel: `*402`)
>   - **When Busy**: `*405*<VirtualNumber>` (Cancel: `*406`)
>   - **When Unanswered**: `*403*<VirtualNumber>` (Cancel: `*404`)
>   - **When Unreachable**: `*409*<VirtualNumber>` (Cancel: `*410`)
>   - **Cancel All**: `*413`
>   - *(Note: Airtel, Vi, and BSNL in India use standard GSM `**21*`)*.

---

## Proposed Changes

### 1. Database & Migrations

#### [NEW] [20260924040000_carrier_call_forwarding_rules.sql](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/migrations/20260924040000_carrier_call_forwarding_rules.sql)
- Creates `public.carrier_call_forwarding_rules` table:
  ```sql
  CREATE TABLE public.carrier_call_forwarding_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    carrier_id UUID REFERENCES public.carriers(id) ON DELETE CASCADE,
    country_code TEXT NOT NULL,
    cfu_format TEXT NOT NULL DEFAULT '**21*{number}#',
    cfu_cancel TEXT NOT NULL DEFAULT '##21#',
    cfu_status TEXT NOT NULL DEFAULT '*#21#',
    cfb_format TEXT NOT NULL DEFAULT '**67*{number}#',
    cfb_cancel TEXT NOT NULL DEFAULT '##67#',
    cfnry_format TEXT NOT NULL DEFAULT '**61*{number}#',
    cfnry_cancel TEXT NOT NULL DEFAULT '##61#',
    cfnrc_format TEXT NOT NULL DEFAULT '**62*{number}#',
    cfnrc_cancel TEXT NOT NULL DEFAULT '##62#',
    cancel_all TEXT NOT NULL DEFAULT '##002#',
    special_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(carrier_id)
  );
  ```
- Seeds verified real MMI records for all active carriers across all 22 supported countries (Saudi Arabia STC, Mobily, Zain; UAE Etisalat, du; Oman Omantel, Ooredoo, Vodafone; India Jio, Airtel, Vi; Egypt Vodafone, Orange, Etisalat, WE; Germany Deutsche Telekom, Vodafone, O2; etc.).
- Adds security definer RPC `get_carrier_divert_rule(p_carrier_id UUID, p_country_code TEXT)` and `list_supported_carriers_with_divert()`.

---

### 2. Backend & Supabase Edge Functions

#### [MODIFY] [manage-dids/index.ts](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/functions/manage-dids/index.ts)
- Add action: `search_available_numbers`:
  - Accepts `country_code` (e.g. `'US'`, `'GB'`, `'CA'`), `limit`, `features` (voice/sms).
  - Fetches Telnyx available numbers via `https://api.telnyx.com/v2/available_phone_numbers`.
  - Queries `app_fee_rules` for `appfees_item = 'intelcallfee'` and the user's tier.
  - Computes and returns pricing per number: wholesale Telnyx price, KeepSIMs fee, and total monthly price.
- Add action: `purchase_number`:
  - Accepts `phone_number`, `country_code`, `country_name`.
  - Validates user identity and checks wallet balance against total price (wholesale + app fee).
  - Atomically debits user's wallet via service-role `debit_wallet_for_topup` / `wallet_transactions` with reference and audit logs.
  - Submits Telnyx order: `POST https://api.telnyx.com/v2/number_orders`.
  - Links ordered number to KeepSIMs Call Control Application (`TELNYX_CALL_CONTROL_APP_ID`).
  - Inserts active number row into `public.virtual_did_numbers` with `monthly_fee_usd` and 30-day renewal cycle.
  - Returns provisioned number record.

---

### 3. Flutter App — Calling & Numbers Feature

#### [MODIFY] [calling_repository.dart](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/calling/data/repositories/calling_repository.dart)
- Add `searchAvailableNumbers({required String countryCode, int limit = 20})`.
- Add `purchaseVirtualNumber({required String phoneNumber, required String countryCode, required String countryName})`.
- Add `getCarrierDivertRules({String? carrierId, String? countryCode})`.
- Add `getCarriersList()`.

#### [NEW] [buy_virtual_number_sheet.dart](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/calling/presentation/widgets/buy_virtual_number_sheet.dart)
- Country selector with flags (United States 🇺🇸, United Kingdom 🇬🇧, Canada 🇨🇦, Germany 🇩🇪, etc.).
- Available numbers list with real-time phone number formatting and capability badges (Voice, SMS).
- Transparent price breakdown display:
  - Wholesale Provider: \$1.00/mo
  - KeepSIMs Service Fee (`intelcallfee` 15% / 7% / 3%): +\$0.15/mo
  - Total Monthly Subscription: \$1.15/mo
- Real-time wallet balance verification.
- "Purchase with Wallet" action with loading feedback and instant provisioning.

#### [MODIFY] [my_numbers_screen.dart](file:///c:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/calling/presentation/screens/my_numbers_screen.dart)
- Redesign screen to strictly match **Image 2**:
  - **Header & Provisioned Numbers Card**:
    - Top bar: `KeepSIMs` with `Smart Calling` badge, subtitle `Zero-Roaming Cloud Calling & DID Sandbox`.
    - Section header: `Provisioned Virtual Numbers` with `+ Add Number` button on the right.
    - Each provisioned number card:
      - Country Flag & Label (e.g. 🇺🇸 US Cloud Gateway, 🇬🇧 London Virtual DID).
      - `ACTIVE` pill.
      - Phone number formatted with spacing: `+1 (754) 318-0369`.
      - Inbound Action dropdown: `Ring In-App`, `Direct to Voicemail`, `Forward to External Phone`.
      - Context menu (`...`) for details/management.
  - **KeepSIMs Smart Call Setup Card**:
    - Header: Phone-divert icon, Title `KeepSIMs Smart Call Setup`, `Zero-Roaming` badge with airplane icon.
    - Description: *"Divert calls from your physical SIM to your KeepSIMs virtual number before traveling. Incoming calls will ring inside this app with \$0 roaming fees."*
    - **Step 1**:
      - Number badge `1`.
      - Title `Home Operator` — *"Select your current mobile operator."*
      - Searchable dropdown populated with real carriers from supported countries (e.g. STC Saudi, Mobily, Zain KSA, Etisalat (e&), du, Omantel, Ooredoo, Jio, Airtel, etc.).
      - Auto-selects user's registered SIM carrier if available.
    - **Step 2**:
      - Number badge `2`.
      - Title `Dial this MMI code on your domestic SIM` — *"Enter the code below on your phone's dialer."*
      - "Copy Code" button with copy action and haptic feedback.
      - Code box displaying the carrier's real MMI format: `**21*+17543180369#` (or Jio: `*401*+17543180369`).
      - Dialer launcher button to open native phone dialer with code.
    - **Cancellation instruction**: Deactivation code (`##21#` or Jio `*402`) clearly displayed.
    - **"How it works" summary card**:
      - Lightbulb icon.
      - 3 bullet points with green checkmarks:
        1. Calls to your home number route to KeepSIMs cloud.
        2. The app rings over Wi-Fi or travel eSIM data.
        3. You avoid roaming fees and keep your number reachable.

---

## Verification Plan

### Automated Tests
1. **Edge Function Syntax & Tests**:
   - Run syntax check and unit test for `manage-dids` edge function actions (`search_available_numbers`, `purchase_number`).
2. **Flutter Unit & Widget Tests**:
   - Update `test/features/calling/my_numbers_screen_test.dart` to verify:
     - `+ Add Number` button renders and triggers purchase flow.
     - Carrier selector displays real carriers and generates corresponding MMI codes (e.g. `**21*` for STC vs `*401*` for Jio).
     - Number purchase dialog validates wallet balance and computes `intelcallfee` markup.
   - Run tests:
     ```powershell
     flutter test test/features/calling/my_numbers_screen_test.dart
     ```

### Manual Verification
1. Open the Flutter app on emulator/device, navigate to Numbers tab.
2. Verify visual fidelity against **Image 2** (layout, badges, colors, typography).
3. Test selecting different carriers in Step 1 (e.g., STC Saudi $\rightarrow$ `**21*<number>#`, Jio India $\rightarrow$ `*401*<number>`).
4. Test clicking `+ Add Number`, browsing available US/UK numbers, checking fee breakdown (Telnyx wholesale + tier fee), and completing purchase.
