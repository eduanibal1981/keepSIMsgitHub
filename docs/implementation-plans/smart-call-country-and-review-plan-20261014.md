# Smart Call: country resolution and compact call review

Date: 2026-10-14 (Asia/Muscat)
Status: Implemented locally after user approval. Android debug build and emulator launch verified; no paid call placed.
Recommended design: **Quick sheet** — a compact call review over the Smart Call dashboard when a number is already present. Keep a manual dialer for entry from an empty field. The alternative **Simple page** presents the same information on a dedicated screen.

## Product outcome

After picking or entering a number, the user sees the destination in full international format, the caller ID the recipient will see, the current customer call rate, and one Call button. A number without a country code requires a country choice. Calls cannot proceed with an unresolved destination or an obsolete/unavailable quote.

Flow: select contact or type → tap Call a phone number → review → resolve country if needed → choose caller ID if desired → Call → existing active call screen.

No second keypad, Recent Calls tab, savings calculator, route jargon, or wallet summary appears in this review. Retain access to history on the dashboard. Edit opens the existing number editor/keypad with the current number. During an active call, retain the existing DTMF keypad and call controls.

## Evidence from current source

CONFIRMED:

- The system picker returns the selected phone number as a string; the app does not receive its contact name or a reliable country.
- Dashboard `_openDialer` passes the raw number into `CallingScreen` using a query parameter.
- `SmartCallDialerState.formattedDestination` removes one leading zero and prepends `selectedRate.phonePrefix` for national input; without a rate it adds `+` to any digits. Neither step establishes the destination's actual country.
- `_detectRatePrefix` matches rate prefixes even when input has no explicit international prefix. `_hasInitializedDefaultCountry` selects an Oman/Egypt/first-rate fallback.
- A preview response replaces `selectedRate`; `CallingRepository.previewCall` constructs that rate with `phonePrefix: '+'`. A price result can therefore alter the prefix used by later destination formatting.
- The request counter increments when preview execution begins. An older response can arrive while newer input is still waiting in the debounce window and update the current state.
- `_startCall` combines local gateway selection with the saved gateway default and chooses a default verified caller ID rather than consistently submitting the selected ID. Displayed and submitted identities must be aligned in the new flow.
- The server preview already returns eligibility, effective caller ID, customer rate, connection fee, billing increment, and available balance.
- Current `PhoneNumberValidator` mainly validates mobile formats for a small set of countries. It is unsuitable as the sole parser for international mobile and landline calling.

INFERRED: these paths explain the local-number and destination/rate mismatch shown in the screenshots. No paid call was placed to reproduce the behavior.
UNKNOWN: exact live quote and connection fee for the pictured destination. Mockup amounts are illustrative.

## Destination rules

1. Keep raw input separate from the canonical destination. Add explicit state for selected destination country (ISO), normalized E.164 number, country confirmation, and validation error. A rate row is never the source of a dialing country code.
2. For valid `+` international numbers, use a maintained numbering-plan parser, preserve their country code, and skip the country prompt. Display formatted international output while submitting canonical E.164. Normalization must be idempotent.
3. For national numbers, show **Country for this number**. Suggest the last explicitly chosen country or the profile home country, but require confirmation for a newly selected national number. Country belongs to the destination, not the caller ID, SIM, device language, physical location, or current tariff.
4. Do not globally force all contacts into the same country: a user in Oman can have both Egyptian and Omani local contacts. Suggestions never silently authorize dialing. For initial delivery, keep explicit confirmation in the current session; per-contact persistence can be a later feature with user-scoped storage and invalidation.
5. Use country metadata to remove a trunk prefix only where appropriate. Preserve significant leading zeros where needed, such as Italian landlines. Do not implement universal `substring(1)`.
6. Handle spaces, punctuation, Arabic and Eastern Arabic numerals, valid mobile and landline ranges, and shared calling codes. For `00`/`011` international access prefixes, parse only with an explicit dialing-origin region or ask the user to enter `+`; they are not universally interchangeable with `+`.
7. Reject unresolved, malformed, incomplete, emergency, short-code, and USSD inputs for this international calling flow. Treat extensions separately; do not merge extension digits into the destination. Format validity does not prove the number is assigned or reachable.
8. Preserve the original system contact and its phone number. All formatting applies to the app's call draft only. No contacts permission expansion or bulk contact upload is needed.

Example: `010 1234 5678` + confirmed **Egypt (+20)** → `+201012345678`. `+966…` retains its existing international prefix. An eight-digit local number prompts for a country rather than automatically becoming a US destination.

Use Google's maintained numbering-plan behavior as the reference. During implementation select a supported, pinned Dart parser/port with equivalent mobile and landline coverage, metadata freshness, and Android/iOS/web compatibility. Do not hand-write another country/prefix table.
Reference: https://github.com/google/libphonenumber/blob/master/FAQ.md

## Review screen

- Header: **Review call** and Close/Back.
- Destination: full international number, country, and small **Edit** action. If a contact name becomes available through the existing selected-contact contract later, show it above the number; name retrieval is not required for this delivery.
- Missing-country state: preserve the original number, show the country picker and normalized preview, and label the confirmation **Use Egypt (+20)** (dynamic). The Call button stays disabled. Confirm in this review; do not add a separate confirmation page.
- Caller ID: one row labeled **Caller ID**, with **KeepSIMs number** or the selected verified personal number and **Change**. The value shown must be the server preview's effective caller ID. Use backend identity data; no fabricated fallback phone numbers.
- Caller picker: gateway plus the user's verified personal caller IDs. Keep verification as a separate explicit action; an unverified identity cannot be selected for a call. Selection is local to the call draft unless the user separately chooses to save a default.
- Rate: one prominent customer price in the app's supported display currency per minute. Use the existing currency contract; do not introduce an independent conversion here. USD is the current billing source. Explain billing interval with a small line derived from the actual quote. No second per-second numeric ticker.
- Fees: show a connection fee only if nonzero. Show minimum/increment information when relevant to the quote. Simplicity must not conceal material charges.
- Main action: **Call**. Disable while missing country, validating, loading quote, quote unavailable, backend ineligible, identity loading, or call submission in progress.
- Recoverable states: **Checking rate…**, **Rate unavailable — Retry**, inline number error, or the backend eligibility reason with its relevant action (Add funds, Change caller ID, etc.). Never display a stale tariff as a confirmed price or zero as free.
- Route fallback: if the backend recommends gateway, explicitly offer **Use KeepSIMs number**, refresh the quote and caller ID, and allow Call only after the updated review is visible.
- Keep adequate tap targets, safe-area padding, Arabic/RTL layout, dark/light themes, dynamic text, keyboard avoidance, and screen-reader labels. The sheet must be scrollable when text or the keyboard expands it.

## Implementation sequence

### 1. Separate destination and quote state

Affected layer: calling domain/model and dialer controller.

Create a small destination value/parser abstraction under the existing calling domain layer. Reuse the countries catalogue's ISO and dialing-code data for the picker, and the maintained parser for number interpretation. Replace tariff-driven destination formatting. Remove the hardcoded default-rate choice from country resolution.

Keep resolved destination, selected identity, and price preview independent. Increment the draft revision immediately on every number, country, identity, or eligibility-affecting change and when clearing/disposal occurs. Capture destination and identity with each request; apply a response only if the entire revision still matches. Provide explicit nullable clearing for selected personal caller ID when switching to gateway.

### 2. Add the shared call review

Add a reusable `call_review_sheet.dart` and a destination-country picker using the existing project UI patterns. All contact, paste, manual-entry, and redial entry points use the same draft/resolver. `SmartCallDashboardScreen` opens the review when a number exists. Empty input opens the manual dialer. Existing `CallingScreen` can use the same review after number entry; retain its keypad for entry/editing.

Country selection must list countries independently of active tariff rows. A country may have no callable route; that is shown by preview eligibility rather than hidden or guessed.

### 3. Align caller ID, rate, and call submission

Centralize call preparation in the controller/repository. Obtain preview through the existing `make-call` action `preview`; quote by normalized destination and exact selected caller ID. Show the server's effective identity. Remove the logic that silently forces a saved gateway default or substitutes another default verified line for a user's selected line.

On Call, snapshot the reviewed draft and ensure its quote is current; revalidate if needed. If a fresh preview materially changes identity or price, show the new review before dialing. The server remains authoritative for eligibility, price, identity ownership/verification, available balance, and route policy at call creation. Lock submission against repeat taps and preserve existing media-session idempotency. Request microphone access only at Call.

Review the existing backend validation and negative tests against canonical input. No billing-rule, wallet, provider, database, or worker redesign is intended. Any necessary server change is a separately identified change with its normal verification and deployment authorization.

### 4. Verify behavior and integration

Extend meaningful tests in the existing calling suites and add focused resolver/review tests:

- National number with missing country cannot request a quote or call.
- Egyptian trunk-zero normalization; Oman eight-digit number; Italian significant leading zero; landlines; Arabic digits; existing `+` preserved; idempotent repeated normalization.
- Access-prefix handling follows the explicit origin policy; multiple `+`, malformed and short/USSD numbers fail; extensions are not appended.
- Selecting a contact after a previous country's call does not silently inherit that country.
- A quote cannot mutate destination or its dialing code.
- Older responses during a debounce, after clearing, and after identity changes cannot restore a stale price or eligible state.
- Gateway and every selectable verified caller ID are displayed and submitted consistently; unverified IDs cannot be used; switching back to gateway clears the prior personal ID.
- Loading, failed quote, no route, insufficient funds, and policy restriction disable Call with the appropriate recovery.
- Connection fee and billing increment appear accurately; any price/identity change requires the updated review to be visible.
- Selecting/canceling the native picker preserves existing Android and iOS behavior, including contacts with multiple phone numbers. Edit/back returns without losing the draft. Empty manual dialer and in-call DTMF continue working.
- Android emulator and iOS simulator checks at small screen sizes, large text, Arabic/RTL, light and dark themes.

Run focused Flutter tests and analysis first; run broader calling suites and required checks after the implementation stabilizes. Do not place a real paid/provider call as part of automated preview validation. If backend source changes, verify live/source agreement and deploy only within explicit authorization.

## Working-file and scope constraints

Customer application is the affected UI. Backend is shared with admin, so any API contract change must be checked in both clients. Preserve current unrelated and in-progress edits in `calling_screen.dart`, `smart_call_dashboard_screen.dart`, Android `MainActivity.kt`, iOS `AppDelegate.swift`, and the new system contact picker service. Do not replace these files wholesale. The implementation preserves the existing native contact picker and adds country-aware destination state, a shared call review sheet, a country picker independent of tariffs, and quote/identity checks. Caller-ID loading failures now fail closed instead of fabricating a gateway number.

Acceptance: a selected number reaches one compact review, missing country never produces a guessed destination/price, caller ID and rate agree with the server and submitted call, and the user can edit the destination without repeating contact selection.

## Implementation evidence (2026-10-14)

- Pinned `phone_numbers_parser` 9.0.28 and `country_picker` 2.0.28; dependency lockfile retained. Country names/dialing codes use the maintained offline picker catalogue rather than the SIM-refill supported-country subset, so international destinations remain selectable independently of tariffs.
- National-number confirmation and edits remain within the review. Edit reveals a phone input/native keyboard without replacing the selected contact. Country/home hints are suggestions only. English and Arabic review labels and a searchable country picker are included.
- Quotes are invalidated immediately on draft changes, including clear/identity changes. Final Call rechecks the quote; price, fee, increment or effective identity changes return to review. Low balance and ineligible/missing/invalid quotes disable Call.
- Personal caller-ID selections are checked against the verified list; gateway selection clears the personal ID. Selection is local to the draft, not a write to the saved default. Permission prompts remain at explicit Call.
- Android debug app was installed and launched with the existing session retained. Native screen inspection was unavailable through the computer-use app binding; layout and interactions are verified with widget tests, including 320px Arabic layout at 1.6x text scale. iOS runtime and an actual paid connection remain unverified.
- Broader calling suite initially reported 77 pass / one failure: unchanged `my_numbers_screen_test.dart` expects the retired `KeepSIMs` header, while the unchanged screen displays `Virtual Numbers`. This assertion is outside this change. Focused checks and final counts are recorded in the task response.

Final verification: 43 focused checks pass; calling analysis is clean; Android final debug build/install/launch passed. The complete calling directory has 83 passing tests and the same unchanged My Numbers header failure. App-wide verification is recorded in `docs/reviews/smart-call-review-verification-20261014.md` (697 pass / 20 failures outside this flow; 89 analysis findings elsewhere).
