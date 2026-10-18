# Second Number: feasibility review and suggested UI

Reviewed: 17 October 2026  
Source: `/Users/thehonest/Downloads/second_number_ai_executor_prompt.md`  
Scope: assessment and design proposal. The source document's executor instructions were reviewed as content; they were not executed. No provider orders, migrations, production changes, or application changes were made for this review.

## Verdict

**Good product direction; achievable with a revised specification. The supplied prompt is not ready for autonomous production execution.**

KeepSIMs can offer dedicated rented numbers, incoming SMS, an in-app inbox, code-copy shortcuts, incoming calls, voicemail, and subscription management using its existing Flutter/Supabase/worker architecture. Some numbers will receive third-party verification messages, subject to the sender, provider, number classification, routing, and country.

The promise that mobile-range DIDs or voicemail will guarantee WhatsApp verification is unsupported. WhatsApp explicitly lists VoIP numbers among unsupported registration numbers; landlines have a separate exception for the WhatsApp Business app. A provider's `mobile` inventory label is not evidence that WhatsApp accepts that specific number. Receiving ordinary SMS also does not establish that bank or platform verification will work. See [WhatsApp registration requirements](https://faq.whatsapp.com/684051319521343/?cms_platform=iphone&locale=en_US) and [Twilio's inbound short-code limitations](https://help.twilio.com/articles/223181668-Can-Twilio-numbers-receive-SMS-from-a-short-code).

If reliable WhatsApp registration is the primary commercial requirement, investigate a carrier-backed mobile subscription or voice/SMS-capable SIM/eSIM offering, with written provider confirmation and controlled acceptance tests. A data-only travel eSIM is not sufficient. Even a carrier mobile offering cannot promise acceptance by every third-party service. WhatsApp's [SIM/eSIM guidance](https://faq.whatsapp.com/1068436057886812/?cms_platform=web) describes registration using the number associated with the SIM/eSIM.

## What the request gets right

- Uses established telecom providers and extends existing number management rather than introducing a disconnected product.
- Identifies real missing pieces: SMS storage, destination routing, messaging configuration, subscription lifecycle, and inbox UI.
- Includes provider signature validation, retry deduplication, real-time updates, and wallet recovery as requirements.
- Connects incoming-message notifications to the correct number and inbox.
- Asks for database, webhook, and Flutter checks, although the proposed tests need broader failure coverage.

## Evidence from the current local source

These observations concern the working checkout on the review date. They are not a live database or deployed-service audit.

| Area | Finding |
| --- | --- |
| `supabase/functions/manage-dids/index.ts` | Number search requests voice, purchase uses a fixed `$1.00` wholesale amount, the carrier order precedes the wallet debit, and a debit failure is logged while provisioning continues. SMS-profile assignment is absent from this purchase flow. |
| `supabase/functions/sms-webhook/index.ts` | Validates Twilio requests and calls `handle_inbound_command`; it does not first route by the destination rented number. |
| `supabase/functions/telnyx-cdr/index.ts` | An incoming event without a matching call record is acknowledged as unmatched. A complete incoming-DID path is needed. |
| `supabase/functions/_shared/webhook-auth.ts` | Shared Twilio/Telnyx verification already exists, including missing-secret rejection and Telnyx timestamp validation. Preserve and reuse these helpers. Older roadmap statements about fail-open behavior are stale relative to this checkout. |
| `supabase/functions/process-voicemail/index.ts` | Has service-only authorization, target checks, and recording deduplication. It stores supplied transcription text; it does not implement the proposed speech-to-text pipeline. |
| Existing product design | The 16 October Second Number design already establishes customer wording and separates number rental from Call Plans. Extend that design rather than replacing it. |
| Worker ownership | `.agents/AGENTS.md` identifies `../backend-sync-wt` as the authoritative worker source. The prompt's instruction to implement solely under this app's `servers/` directory conflicts with that ownership. |

## Changes required before implementation

### 1. Replace the WhatsApp guarantee with capability evidence

Remove `whatsapp_compatible DEFAULT TRUE`, the enabled-by-default “WhatsApp & OTP Compatible” filter, and badges claiming “WhatsApp Call-Me Ready.” Default unknown capabilities to unknown, not supported. Do not relabel existing local numbers as mobile during migration.

Store provider-reported number type separately from independent carrier classification and service acceptance evidence. If compatibility observations are retained, include the service, product (consumer app, Business app, or Business Platform), provider, country, test date, and outcome. Historical tests must not become a future delivery guarantee.

Twilio's WhatsApp integration documentation concerns the **WhatsApp Business Platform**, which is a distinct product with sender registration and business onboarding. It does not prove a rented number can register an ordinary consumer WhatsApp account. See [Twilio's product distinction](https://www.twilio.com/docs/whatsapp/api).

### 2. Make availability and identity requirements provider-driven

The country matrix is a hypothesis, not a validated inventory contract. Countries do not automatically offer purchasable mobile numbers with both SMS and voice. Germany appears in the UI list but has no corresponding entry in the proposed mobile-country routing matrix. North American numbering geography does not establish whether a particular number is a cellular subscription or VoIP.

Resolve inventory capabilities, stock, local address requirements, regulatory documents, and approval state from current provider responses. Implement actual collection/submission/review of identity requirements, not only `kyc_status` and `requirement_group_id` fields. Twilio explicitly advises against hardcoding regulations in its [Regulatory Compliance API documentation](https://www.twilio.com/docs/phone-numbers/regulatory/api).

### 3. Design a recoverable purchase transaction

A balance check followed by a carrier API call is not atomic across systems. Immediate refund-on-error is insufficient when a request times out but the provider actually bought the number.

Use a durable purchase record and stable idempotency key: server quote → atomic wallet reservation → provider order → confirmed configuration → wallet capture → activation. Reconcile uncertain provider results before refunding or retrying. Use provider idempotency where supported; otherwise recover by the stored order correlation. If configuration or persistence fails, retain a recoverable order and apply a defined release/refund policy. Do not silently substitute another number or provider.

Client-supplied wholesale prices and number capabilities must never authorize charges. Resolve amounts server-side from an expiring quote. Include setup fees, currency, taxes where applicable, and the purchased terms version.

### 4. Complete the commercial model

Rental markup alone does not fund unlimited use. Define charging or included allowances for incoming SMS segments, inbound voice, forwarded call legs, recording, transcription, storage, and support. Telnyx publishes separate [incoming messaging charges](https://telnyx.com/pricing/messaging); exact account rates must be validated before publishing retail prices.

Decide whether the customer buys a fixed 30-day period or a calendar month and display that exact term. Repeated 30-day charges must not be described as monthly without an explicit commercial decision. Preserve the provider billing anchor and handle price changes, delayed orders, and cancellation terms.

### 5. Complete renewal and release recovery

The proposed renewal function only selects active rows. It does not define how a suspended number is recovered after a top-up. Its returned release list is also not durable when invoked through a scheduled SQL statement.

Use one authoritative lifecycle state machine, billing-period idempotency keys, and a durable release/reconciliation outbox. Model provisioning, active, grace, suspended, release pending, released, and failure states; keep identity review separate. Assign one owner to charge decisions and one claimed job to each upstream operation. Add pre-renewal warnings, balance recovery, bounded retry/backoff, and provider confirmation before declaring release complete. Define precisely what remains available during grace or suspension.

Deleting `provider_sid` is not sufficient release evidence and removes useful audit data. Retain provider identifiers and release receipts in an access-controlled audit record.

### 6. Build the full incoming-call path

A push notification makes a device aware of a call; it does not bridge provider audio to that device. Specify SDK/SIP/WebRTC registration, short-lived credentials, PSTN-to-app media bridging, background-call delivery, device selection, timeout ownership, hangup races, and both-leg settlement.

The proposed Twilio branch sends app-mode calls directly to voicemail rather than ringing the app. Its `<Record>` example omits explicit recording and transcription callbacks. Twilio documents that transcription without `transcribeCallback` does not asynchronously notify the app, and that an omitted `action` can re-request the same webhook and loop. See [Twilio Record behavior](https://www.twilio.com/docs/voice/twiml/record).

The Telnyx instructions place incoming handling inside the no-call-record branch. Once the initial event creates a record, subsequent events will match it and bypass that location. Route every subsequent event through a dedicated inbound-call state machine. Use an inbound call type rather than reusing `two_way_callback`, and implement the 18-second timeout durably.

Voicemail can miss automated speech while the greeting plays; speech recognition can mishear digits. Some verification systems require live interaction. Offer recording/transcription as best-effort voicemail, with original audio and an “Unconfirmed code” label where appropriate. Do not claim that it bypasses third-party restrictions.

### 7. Restrict message writes and protect verification content

The proposed UPDATE RLS policy checks row ownership but does not restrict updated columns. With table-wide UPDATE privileges, users could modify message bodies, provider identifiers, or DID references. Prefer a narrow mark-read RPC with explicit ownership/suspension checks, or column-level permissions for `is_read` only. Supabase describes the distinction in its [column-level security documentation](https://supabase.com/docs/guides/database/postgres/column-level-security).

Restrict ingestion and renewal RPCs to trusted backend callers. Specify function grants and safe search paths, input limits, ownership consistency, and negative authorization tests. Hide raw provider payloads and internal billing data from customer API responses. Allow alphanumeric sender IDs and shortcode senders rather than forcing every sender into E.164.

Default push text to “New message on your second number.” Keep OTPs and message bodies out of lock-screen notifications, analytics, and ordinary logs. Let the user explicitly enable sensitive previews. Define message/recording retention, deletion, protected audio access, recording disclosures, and transcription processing policy. Treat an extracted code as a convenience candidate; multiple numbers in a message must not silently become an authoritative OTP.

### 8. Isolate rented-number traffic from refill commands

“No DID match” must not automatically authorize offline recharge routing. Require the destination to match a registered refill endpoint, and distinguish unknown, released, suspended, and temporarily unavailable DID records. A database failure should produce a retryable response, not fall through to a different business operation.

Store the rental/assignment identity and provider occurrence time with events. A delayed message from a previous rental must not be delivered to a new owner when a number is recycled. Define a quarantine/reassignment policy and test late events explicitly.

### 9. Add real acceptance tests

Retain the proposed deduplication and widget tests, then add parallel purchases, double taps, insufficient funds after concurrent reservations, carrier timeouts, delayed activation, messaging-profile failure, duplicate/out-of-order callbacks, renewal races, top-up recovery during grace, release failure, expired quotes, forged/missing signatures, cross-user reads/writes, and notification privacy.

A synthetic WhatsApp text in SQL tests only extraction and routing. It does not prove WhatsApp registration or bank OTP delivery. Real acceptance testing needs authorized test accounts and rented test numbers for each offered provider/country/number type, plus foreground/background call tests on physical iOS and Android devices.

## Recommended delivery sequence

1. **Validate supply and economics.** Confirm actual account inventory, line classifications, country eligibility, identity requirements, callback setup, and retail terms. Run a small controlled delivery pilot. This is the first go/no-go gate.
2. **Release one-provider number rental and incoming SMS.** Include safe purchases, private owner-scoped inbox, notifications, renewal/grace/release, operational recovery, and the UI states below. Launch only validated countries. Default to receive-only SMS unless sending is separately specified and priced.
3. **Add incoming voice and voicemail.** Ship a real media bridge, background ringing, forwarding limits, recording/transcription callbacks, usage accounting, and device acceptance tests.
4. **Add the second provider.** Reuse an adapter contract but avoid doubling provisioning, compliance, and billing complexity before the first flow is proven. Service acceptance claims remain evidence-based and qualified.

This is a multi-week integration and verification effort, not a safe one-shot seven-phase execution. Country approvals and provider access can dominate elapsed time; a reliable estimate needs the supply pilot and a current deployed-contract baseline.

## Suggested UI specification

Use existing KeepSIMs customer wording: **Get Second Number**, **My Second Numbers**, **Monthly Number Fee**, **KeepSIMs Service Fee**, and the existing **Smart Call** area. Preserve the current cyan/teal accent, green success, amber action states, Inter typography, light/dark support, and English/Arabic layouts. Provider names, DID jargon, wholesale costs, and internal fee-rule identifiers belong in operational tools, not ordinary customer checkout.

### Recommended layout: number first

Inside Smart Call, open **My Second Numbers** with a clear **Get Second Number** action. Each number card shows country, full number, verified SMS/call capabilities, service status, unread count, renewal date/amount, and auto-renew state. The primary card action is **Open inbox**. Call delivery and subscription settings are secondary. Keep SIM call-diversion setup in its existing separate section; do not imply that call forwarding also forwards SMS.

Within a selected number, use **Messages · Calls · Voicemail**, with a persistent number header. Incoming messages appear as sender threads. The detail view shows full text, received time, number identity, a selectable code and **Copy code** action, and a clear sender-not-verified treatment. No composer appears in a receive-only release. Foreground streaming must recover missed messages after reconnecting.

### Alternative layout: inbox first

If message receipt becomes the dominant usage, open a consolidated inbox with an **All numbers** selector and visible per-message destination labels. Keep **My numbers** and **Get Second Number** readily accessible. The same number details and checkout flow apply. The preview includes both layouts for comparison; the number-first layout is the recommended initial release.

### Acquisition and checkout

Country → actual available numbers → identity requirements, if any → review → activation progress → active number. Show **SMS** and **Calls** badges only from verified inventory data. Do not use green WhatsApp badges or infer capabilities from a country flag.

Checkout shows the Monthly Number Fee, KeepSIMs Service Fee, setup fee, currency, recurring period, next renewal, usage charging, identity status, wallet balance, total due, and cancellation terms. Label unapproved prices as illustrative in design previews. If approved pricing or coverage is unavailable, disable the real purchase action rather than inventing an offer.

Place concise service wording near the number details and checkout: **“Verification codes depend on the sending service. Some services do not accept virtual numbers.”** A WhatsApp help disclosure can link to official registration requirements; it must not instruct users that changing verification channel guarantees success.

### Required non-happy states

| State | Customer treatment |
| --- | --- |
| No numbers | Brief benefit statement and Get Second Number action. |
| No stock / no eligible country | Explain availability and allow another selection. |
| Identity review | Required documents, submission status, and next action; no active badge. |
| Provisioning | “Setting up your number”; safe retry/status refresh without another purchase. |
| Insufficient balance | Amount needed and Top up wallet; quote refresh before payment. |
| Renewal due / grace | Exact amount and release deadline, Top up action, and accurate service availability. |
| Service suspended | Plain reason, recovery action, and what is still accessible. |
| Release pending | Progress until provider confirmation; retain prior messages according to policy. |
| Release confirmation | Exact number, release timing, loss of access, and third-party account recovery reminder. |
| Inbox offline / empty | Distinguish no messages from connection loss; show last sync and retry. |
| Transcription processing / failed | Audio playback and honest status; no fabricated transcript or code. |

### Design acceptance

Verify 320px layouts, long international numbers, text scaling, dark/light contrast, screen-reader labels, 44px touch targets, Arabic RTL, clipboard feedback, number-specific deep links, masked notification previews, and readable renewal deadlines. Never rely only on color to show state.

## Decision

Proceed with the **second-number and incoming-inbox product**, after correcting the purchase/lifecycle/security contracts and validating supply. Remove guaranteed WhatsApp/bank verification from the acceptance criteria and marketing. If WhatsApp registration is the core promise, validate a suitable carrier-mobile supply model before investing in the full build.

## Preview verification

The accompanying interactive design was checked in a local browser for both layout options, number selection and sample activation, message opening and code-action feedback, voicemail navigation, privacy preferences, call-delivery selection, release persistence, renewal-due dates, and 320px home/checkout layouts. Light and dark screens were visually inspected. These are design-preview checks, not evidence of real number provisioning, payment, SMS delivery, WhatsApp registration, or background calling.
