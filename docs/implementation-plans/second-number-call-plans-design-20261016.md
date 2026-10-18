# Second Number and Call Plans — design proposal

Date: 2026-10-16. Scope: apply the customer-facing Second Number wording and prepare a call-plan design. The user chose KeepSIMs bundles using Telnyx, then requested design only while destinations and pricing remain undecided.

## Product language

- Service name: **Second Number** / **الرقم الثاني**.
- Acquisition: **Get Second Number**. Management: **My Second Numbers**.
- Home subtitle: **Calls & call forwarding**.
- Calling stays under **Smart Call**. Voicemail retains its descriptive name.
- Shared outbound caller ID is labeled **KeepSIMs Caller ID**; it is not presented as a customer's purchased second number.
- Customer number checkout uses **Monthly Number Fee** and **KeepSIMs Service Fee**. Provider identifiers, APIs, models and pricing calculations retain their existing contracts.
- Do not promise free incoming calls, free SMS, zero fees or universal SMS support based on the competitor screenshots.

## Proposed store flow — not implemented in the Flutter app

The existing Second Number entry can open a store with two tabs: **Second Number** and **Call Plans**. Default to Second Number when entering from the home shortcut. The design preview opens Call Plans so the new concept is immediately visible.

**Second Number:** explain a separate number for incoming calls and SIM call forwarding, select country, browse actual inventory, review the authoritative monthly number price, and activate through the existing purchase flow. Supported features must come from the selected inventory item. Number rental and outgoing call allowances are separate products.

**Call Plans:** show destination, included minutes, period, approved retail price, and See details. Use 250 minutes per monthly period as the initial design example. UK, Germany and Australia are illustrative destinations from the reference, not approved coverage. Show no savings badges until a valid comparison is defined.

**Plan details:** show included destination prefixes/networks, allowance, exact validity dates, billing increment, renewal behavior, unused-minute rules, exclusions and the total price before payment. Special-rate, premium and emergency destinations are excluded from the proposed bundles. A country code alone must not qualify every destination within that country.

**Active plan:** show minutes remaining, minutes used, precise expiration time and Manage plan. Preview data (185 of 250 minutes remaining) is explicitly a sample.

**Before a call:** review identifies either the eligible bundle and its remaining allowance, or wallet pricing. Do not require the existing one-minute wallet minimum for a fully covered bundle call. Excluded destinations and exhausted/expired plans use wallet calling only after an explicit cost review. Do not silently charge the wallet mid-call.

**At allowance exhaustion:** stop the bundle-funded call at its authorized duration, with a short grace/safety margin defined against provider behavior. Offer a new wallet-funded call through the existing review flow. Proposed first release uses manual renewal, no rollover, and one calendar month from activation; these are design defaults, not approved commercial terms.

## Telnyx relationship and price validation

KeepSIMs owns the retail bundle and minute accounting. Telnyx continues carrying the underlying calls. The [Telnyx Voice API rate card](https://telnyx.com/pricing/voice-api) publishes usage pricing with Voice API and destination-dependent SIP charges; optional services have separate charges. This does not establish an all-inclusive wholesale bundle cost.

Before approving each retail plan, validate the actual account rate deck, eligible destination prefixes and network types, both call legs, WebRTC/SIP/API fees, provider billing increments, number rental if included, taxes, payment fees and target margin. At the screenshot's illustrative $6.49 for 250 minutes, revenue is $0.02596 per included minute before those costs and margin. The screenshot price is not a KeepSIMs offer.

## Current source findings

- `lib/features/calling/data/repositories/calling_repository.dart` calls `make-call` for preview and dialing.
- `supabase/functions/make-call/index.ts` currently previews per-minute wallet rates, enforces a wallet minimum, creates `app_to_phone_webrtc` call records and reserves wallet funds under `call_budget`.
- `supabase/functions/telnyx-cdr/call-media.ts` manages provider call legs; `supabase/functions/telnyx-cdr/index.ts` handles call events.
- `supabase/migrations/20260921010000_calling_phase_b_billing.sql` defines wallet-hold settlement and `finish_media_call` finalization. Local source is evidence of implementation, not deployed-state verification.
- No minute-bundle entitlement, purchase or allowance settlement was added in this design task. No database, Edge Function, supplier or pricing deployment was performed.

## Implementation contract for a later phase

1. **Catalogue:** versioned server-owned offers with destination-prefix eligibility and exclusions, allowance seconds, price/currency, validity, renewal mode, billing increment, enabled status and effective dates. Customer responses expose retail data. Admin manages pricing and publication through authorized backend operations.
2. **Purchase:** authenticated atomic wallet debit plus ledger entry and entitlement creation using a stable idempotency key. Resolve price and terms server-side; store the purchased offer version. Handle retry/refund without double debit or duplicate entitlement.
3. **Allowance:** track purchased seconds, reserved seconds and consumed seconds separately. Reserve before provider dialing under a call-specific key. Concurrent calls cannot spend the same seconds. Limit calls to the reserved duration with provider-enforced timeout and reconciliation for ambiguous termination.
4. **Settlement:** verify provider signatures, settle authoritative answered duration exactly once, release unused reservations and finalize both call legs. Unanswered/failed calls consume no talk allowance under the proposed terms. Store provider cost separately from customer wallet charges and minute usage.
5. **Expiry and renewal:** server-clock decisions, clear UTC timestamps with local display, calls bounded at plan expiry, no silent auto-renewal or unexpected overage debit. A manual renewal is an explicit new purchase.
6. **Access and verification:** owner-scoped reads; no client writes to balances, entitlements or allowance. Test duplicate purchase requests, parallel calls, duplicate/out-of-order events, non-answer, exact exhaustion, expiry during a call, premium prefixes, missed webhooks, refund and wallet fallback. Verify current deployed contracts before migration design.

## Decisions still open

Approved countries and network prefixes; retail prices and margins; calendar month versus fixed-day validity; customer billing increments; multiple concurrent/overlapping plans; renewal and refund terms. None of these is inferred from the competitor's published cards.

## Verification

- Regenerated Flutter localizations from the English/Arabic source files; other locales retain the existing English fallback.
- Focused Flutter analysis of the changed screens, widgets and localization output: no issues.
- Existing `smart_call_dashboard_review_test.dart`: all five tests passed.
- Inspected the interactive preview at normal and 320px browser widths; verified service tabs, plan details, disabled purchase action and country selection. No browser console errors were reported.
- Whitespace check passed for the touched application files. Existing unrelated workspace changes were preserved.
