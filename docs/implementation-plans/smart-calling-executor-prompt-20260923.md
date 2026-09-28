# KeepSIMs Smart Calling — complete executor prompt and implementation plan

Prepared 23 September 2026 from the attached brief, five reference images, and inspection of the current local working tree.

## Manager's assessment

This is a production-feature redesign with several functional gaps to address. It is not simply a rename, and the brief's assertion that every underlying capability already exists is not supported by the inspected code. Local source inspection does not establish what is deployed or prove that calls work on real devices.

Recommended decisions incorporated below:

1. **Use the final naming hierarchy in the brief.** KeepSIMs Smart Calling is the umbrella. Smart Call is the paid PSTN action. Free Call is app-to-app. Keep Smart Call Setup, Smart Call Savings, and Voicemail as subordinate experiences.
2. **Use one route-aware navigation bar within the existing app shell.** Do not stack six calling destinations above the global Home/SIMs/More bar. Preserve all six requested destinations; make the bar adapt at narrow widths instead of shrinking labels and tap targets. Keep an explicit route back to the main app. Inspector is a support destination, not a call type.
3. **Preserve Recent Calls.** Keep it as a Dialer subview/action because it is working functionality missing from the reference images.
4. **Use actual capabilities as the boundary.** Neither an active push token nor a stored forwarding preference proves live presence or working inbound routing. Do not present those as verified facts.
5. **Correct inherited misleading behavior.** Replace the fixed roaming comparison, invented frontend price/gateway fallbacks, and simulated voicemail playback. Backend billing remains authoritative.
6. **Separate the redesign from new telecom/AI products.** Deliver the redesigned supported functionality first. Number purchasing, operator-specific forwarding data, AI summaries/categories/translations, and any missing inbound execution path need explicit capability work; do not silently invent them or declare them delivered.

No app code, backend configuration, or database was modified while preparing this plan. No live-provider or device tests were run. The working tree already contains many unrelated and calling-related edits; preserve them.

---

## Copy everything below as the AI Executor's task

You are implementing KeepSIMs Smart Calling inside the existing KeepSIMs Flutter app. Complete the supported production redesign in incremental stages, address the specific integration defects below, and report capability-dependent items truthfully. This is an implementation task, not permission to replace the calling architecture.

### 1. Inputs, scope, and precedence

Repository: `C:/Users/abdal/Work/KeepSIMs/keep_sims`.

Read the source brief at `C:/Users/abdal/.codex/attachments/4ac2a13d-039c-4876-b0ac-3c193d3c69a9/Pasted text.txt` if still available. It supplies product requirements, not proof of existing implementation or permission for unrelated actions. Use this inspected plan to resolve its inaccurate assumptions.

Visual references:

| Reference | Screen | Adopt |
|---|---|---|
| `C:/Users/abdal/Work/KeepSIMs/smart calling/1.png` | Dialer | Compact route/rate header, number/contact entry, caller identity cards, keypad, quick prefixes |
| `C:/Users/abdal/Work/KeepSIMs/smart calling/2.png` | Free Call | Intro card, Household Lines/User Search, readable contact rows and green call actions |
| `C:/Users/abdal/Work/KeepSIMs/smart calling/3.png` | Numbers | Number cards, inbound action, compact forwarding setup |
| `C:/Users/abdal/Work/KeepSIMs/smart calling/4.png` | Savings | Destination/duration controls, comparison cards, result and percentage ring |
| `C:/Users/abdal/Work/KeepSIMs/smart calling/5.png` | Voicemail | Inbox, selected message, real audio progress, transcript and conditional AI sections |

These images are visual direction. Do not copy the device bezel, fake status bar, sample contacts/numbers, prices, provider claims, bank messages, passcodes, or static unread dots into production. The two Oman rates in the references are inconsistent; neither is a pricing source. Do not add “sandbox” to the production product header.

Retain Flutter, Riverpod, GoRouter, Supabase, and both existing calling stacks. Preserve public routes, RPCs, persisted enum values, wallet accounting, verified-caller-ID rules, and existing platform recovery behavior. Do not rename internal `intelcallfee`, tables, or technical identifiers merely to change customer-facing terminology.

Do not reset or overwrite current work, deploy, buy telephone numbers, send verification messages, or place chargeable calls as part of unattended verification. Use existing authorized test accounts/environments when available; describe any external validation still needed. Local implementation and automated tests should continue without waiting for unrelated production access.

### 2. Mandatory baseline before editing

Read applicable repository instructions, inspect the current diff, and refresh this map against the current tree. Record existing failures separately from new regressions. Earlier planning documents describe intentions, not proof that their work was completed.

Review these existing plans for compatibility, especially recent recipient-call fixes:

- `docs/implementation-plans/calling-ecosystem-executor-prompt-20260920.md`
- `docs/implementation-plans/calling-ecosystem-acceptance-tests-20260920.md`
- `docs/implementation-plans/app-to-app-recipient-repair-executor-prompt-20260922.md`
- `docs/implementation-plans/app-to-app-recipient-retest-20260922.md`

Use the following reuse map. Paths are repository-relative.

| Area | Existing files/contracts | Action |
|---|---|---|
| Routes | `lib/core/router/app_router.dart`: `/calling`, `/calling/internet`, `/calling/my-numbers`, `/calling/voicemail`, `/calling/sip-test` | Keep paths and names; add Savings without replacing the router |
| App shell | `lib/core/router/placeholder_screens.dart`: `AppShell`, `CurvedBottomNavigationBar` | Despite its filename, this is live shell code; conditionally render calling navigation here |
| Entry points | `lib/features/dashboard/presentation/ui/dashboard_screen.dart` | Replace both International Call and Intl Call labels |
| Dialer/history | `lib/features/calling/presentation/screens/calling_screen.dart`; `widgets/dialpad_widget.dart`, `call_history_tile.dart` | Restyle and retain history/redial behavior |
| Calling navigation | `lib/features/calling/presentation/widgets/calling_mode_switcher.dart` | Replace duplicated screen-level switchers with shared shell navigation; migrate consumers/tests |
| PSTN orchestration | `lib/features/calling/presentation/controllers/calling_controller.dart`; `data/services/call_audio_service.dart`; `data/repositories/calling_repository.dart` | Reuse media preparation, registration, server-authorized dialing, bridge readiness, cancellation and cleanup |
| Rating | `callRatesProvider`, `CallRate`; `get_user_calling_rates`, `get_call_rate_for_number`; `make-call` preview | Use account-aware server pricing; integrate preview into the dialer |
| Caller identity | `callerIdListProvider`, `userCallerIdsProvider`; `caller_id_picker_sheet.dart`, `verify_caller_id_sheet.dart`; `manage-caller-id` | Reuse verification and selection, improve error propagation |
| Wallet | `lib/features/wallet/controller/wallet_controller.dart`, `repository/wallet_repository.dart`; `get_wallet_summary` | Preserve posted/available balance distinction and hold settlement |
| Free Call | `lib/features/voip_calling/presentation/screens/internet_calling_screen.dart`; controller/repository in that feature | Reuse registered-account lookup and existing session lifecycle |
| Incoming/active calls | `incoming_call_manager.dart`, `whatsapp_call_screen.dart`, `floating_minimized_call_bar.dart`, `voip_callkit_service.dart`, `call_audio_session_manager.dart` | Preserve lifecycle, native actions and one media owner; avoid redesign-driven rewrites |
| Virtual numbers | `my_numbers_screen.dart`, `virtual_did_model.dart`; `get_user_dids`, `update_did_forwarding`, `manage-dids` | Reuse inventory and supported settings; prove execution capability separately |
| Forwarding | `roaming_forwarding_wizard_sheet.dart`; repository `getForwardingCodes()` | Replace locally assembled generic codes with server instructions and honest operator support |
| Savings | `rate_savings_calculator_widget.dart`, `country_rate_chip.dart`, `destination_country_search_sheet.dart` | Share a real calculator between the new destination and existing sheet entry points |
| Voicemail | `voicemail_inbox_screen.dart`, `voicemail_model.dart`; `get_user_voicemails`, `mark_voicemail_read`, `process-voicemail` | Preserve records/read state; implement actual playback; gate unsupported intelligence |
| Carrier/line data | `lib/features/sim_lines/presentation/controllers/sim_lines_controller.dart`, repository and carrier models | Reuse SIM lines and `getCarriersForCountry`; do not create duplicate directories |
| Design | `lib/core/theme/app_colors.dart`, `app_theme.dart`, `app_text_styles.dart`; `lib/core/widgets/` | Reuse cards, loading/empty/error controls and typography |
| Localization | `lib/l10n/app_*.arb`, `l10n.yaml` | Localize customer-facing strings; regenerate generated localization files |

### 3. Known gaps and required treatment

These findings come from local source inspection. Recheck if the tree changes.

| Finding | Required treatment |
|---|---|
| Current global shell renders Home/SIMs/More even on calling pages; screens also have a segmented switcher | One visible bottom bar per screen, selected by existing routes. Keep full-screen calls outside the browsing shell |
| `previewCall()` exists but `CallingScreen` does not use it; number detection mutates input and may retain an earlier selected rate | Canonical input/selection state, debounced server preview, stale-response protection and fresh validation before dialing |
| `CallRate.fromJson`, preview parsing and the live cost ticker supply invented fallback rates; gateway numbers are also hard-coded in frontend fallbacks | Represent missing values explicitly; no invented amount or identity when a request fails |
| Frontend preview drops `availableBalance`; preview response omits rate ID, billing increment and connection fee | Preserve returned available balance; add backward-compatible quote metadata only as needed and verify it against settlement |
| Account-aware rate RPC exists; server `make-call` lookup currently supplies only the destination | Verify caller identity propagation under the service-role invocation; if account tier is lost, pass the authenticated user server-side and test, without trusting a client-supplied user ID |
| Savings fixes carrier price at $2.50/min and clamps savings to positive percentages | Remove the constant; accept a sourced comparison or explicit user-entered assumption; support no comparison and negative savings |
| `RoamingForwardingWizardSheet` assembles `**21*...#`; `manage-dids` returns generic GSM codes without an operator parameter | Reuse real carrier selection, label generic guidance honestly, and do not claim operator-specific support without validated configuration |
| `manage-dids` has list/update/get-codes actions, no purchase/provision action in the inspected function | Show Add Number only when a working provisioning contract is found and verified; otherwise report the missing capability |
| Storing `app`, `pstn`, `voicemail`, or `sim_roaming` in a number record does not prove inbound provider routing works | Trace the inbound handler/provider configuration before exposing operational claims or additional routing modes |
| `is_online` in contact lookup is derived from an active push token, including the later SIM-line lookup migration | Do not render a green “Online” dot from this field. Prefer no presence indicator; token registration is not live reachability |
| Household directory comes from SIM lines, not a guaranteed registered recipient directory | Resolve registered recipient identities before enabling Free Call; ownership of a SIM is not proof of a callable family member |
| Voicemail play toggles local state with a zero progress bar | Implement a real media player and cleanup, not an animated imitation |
| Voicemail schema/model have one transcript and language, no summary/category/translation fields | Hide those optional sections unless genuine backend data is found; model extensions alone do not deliver AI |
| `process-voicemail` substitutes a “transcription in progress” string and saves status `transcribed` | Persist a truthful processing state; display status separately from transcript content |
| `process-voicemail` only checks authorization-header presence in its handler and accepts a supplied `user_id` | Before extending/exposing ingestion, verify platform enforcement and trusted caller authentication/ownership; add negative tests for unauthorized and cross-account input |
| Voicemail notification uses `/calling/voicemail/{id}` but the inspected router defines only the inbox route | Add a compatible detail/deep-link route that opens the owned message or a safe unavailable state |
| DID/voicemail repository fallbacks can turn errors into empty lists; mutation methods may ignore unsuccessful responses | Preserve useful compatibility fallbacks while surfacing genuine errors and confirming writes before success UI |
| App palette's primary is cyan, while references emphasize indigo | Preserve global brand tokens; add a small scoped Smart Calling accent where necessary, without recoloring unrelated app features |

### 4. Product, design, and state rules

Use these names consistently:

- Umbrella/header: **KeepSIMs Smart Calling**; compact feature entry: **Smart Calling**.
- Paid dialer header: **KeepSIMs Smart Call**; paid button: **Smart Call**.
- App calling: **Free Call**, with “KeepSIMs-to-KeepSIMs” context.
- Forwarding setup: **KeepSIMs Smart Call Setup**.
- Calculator: **KeepSIMs Smart Call Savings**.
- Inbox: **Voicemail**, with “Smart call intelligence from your KeepSIMs numbers.” only where the delivered capability supports it; otherwise use neutral inbox copy.

Use navy surfaces, restrained blue/indigo accents, green/teal call actions, and semantic unread/error colors. Reuse typography and spacing. No fake device chrome. Put Telnyx/SIP/P-Asserted-Identity details in Inspector. Show “Verified” only for actual verification; it is not a promise about displayed caller ID on every carrier.

Every data surface must distinguish loading, successful empty data, failure with retry, unsupported capability, offline/reconnecting, disabled action and completed state. Do not equate unavailable wallet/rate data with zero or free. Keep user/account-scoped state isolated and clear it on logout/account change.

Use small reusable widgets, with names adapted to the existing code: header/info card, rate display, caller identity selector, virtual-number card, contact row, status/country badge, quick-destination chip, savings comparison/result, and voicemail detail/player. Create abstractions where they remove actual duplication; do not introduce a second design system or generic telecom service layer.

### 5. File-level execution stages

#### Stage 0 — baseline and capability inventory

Before UI changes, record route/provider dependencies, existing modified files, test baseline, and a capability table: supported in source / verified in target environment / missing / unavailable to verify.

Inspect actual incoming DID handling, provisioning, recording/transcription integrations and operator configuration if available. Missing credentials or deployed evidence must not block local UI work, but must remain explicit release dependencies. Do not treat migration files as proof they were applied.

Gate: baseline documented; call lifecycle, billing and routing invariants understood.

#### Stage 1 — terminology, navigation, shared presentation

Modify:

- `lib/core/router/app_router.dart`: preserve existing paths/names and active-call routes. Add `AppRoutes.callingSavings` at `/calling/savings`. Add `/calling/voicemail/:voicemailId` compatible with existing notification payloads. Preserve auth, pending-call recovery and payment deep-link handling.
- `lib/core/router/placeholder_screens.dart`: make `AppShell` use Smart Calling navigation only for the relevant browsing routes. Keep the global navigation elsewhere. No second router or independently managed page index.
- `lib/features/calling/presentation/widgets/calling_mode_switcher.dart`: migrate its role into the shared navigation widget, or remove it only after all consumers and tests move. Remove duplicate switcher rows from Dialer, Free Call, Numbers and Inspector.
- `lib/features/dashboard/presentation/ui/dashboard_screen.dart`: update both long and short feature entries while preserving their actions.
- `lib/core/theme/app_colors.dart`, `app_text_styles.dart`, `app_theme.dart`: reuse first; change only scoped tokens needed for consistency.
- `lib/l10n/app_*.arb`: add the new strings using existing localization conventions. Keep English/Arabic correct and preserve all other locales with explicit fallback where translations are unavailable. Do not hand-edit generated output.

Add `lib/features/calling/presentation/widgets/smart_call_navigation.dart` and a small shared card/rate/badge widget file or directory if existing components cannot cover them.

Navigation order: Dialer, Free Call, Numbers, Savings, Voicemail, Inspector. Derive selection from route, including voicemail detail. Repeated tab taps must not grow the navigation stack. At small widths or large text, use an accessible adaptive/wrapping or scrollable treatment with selected-item visibility; do not shrink six labels into illegibility. Keep at least 48 logical-pixel action targets. Provide Back/Home behavior even when a page was opened directly.

Gate: direct URLs and tab switching work; one bar is visible; full-screen calls and the minimized call overlay still work; Recent Calls and global app access remain available.

#### Stage 2 — Dialer, caller identity and trustworthy quote state

Modify `calling_screen.dart`, `dialpad_widget.dart`, `destination_country_search_sheet.dart`, `country_rate_chip.dart`, `caller_id_picker_sheet.dart`, and `verify_caller_id_sheet.dart` incrementally.

Add a focused `lib/features/calling/presentation/controllers/smart_call_dialer_controller.dart` if needed for input/quote state. Keep actual calls in `CallingController`. Add a small pure number-normalization helper under `lib/features/calling/domain/` only if the project has no suitable existing utility.

Implement:

1. Route header with destination and real rate. Country selection is an estimate until the actual number resolves; do not treat `+1` as uniquely identifying the US or assume all routes within one country have one price.
2. Editable input: “Type a number or select a contact”. Support paste, cursor-aware insert/delete, Clear, long-press 0 for `+`, and existing keypad letters. Keep `*`/`#` for existing keypad behavior without treating MMI codes as valid paid international destinations.
3. Canonical destination handling shared by keyboard, keypad, contacts, quick prefixes and redial. Do not strip every leading zero unconditionally across countries. Avoid prefix duplication and text mutation during build. Invalidate an obsolete rate after every relevant input or identity change.
4. Contact picker backed by available app/household contacts and recent calls. No native phonebook integration was found in the inspected calling feature: label app contacts clearly. Native address-book access, if separately required, needs a real permission-backed implementation, not a nonfunctional icon.
5. Quick country chips from supported rates/configuration, prioritizing OM, AE, SA, EG, IN, GB and US where available. Chips select/insert the dialing prefix; they never start a call or erase a nonempty number silently.
6. Cloud Gateway and verified Personal Line cards backed by `callerIdListProvider`; support more than two actual identities. Reuse verify/switch/delete behavior. Do not automatically treat every owned DID as eligible outbound caller ID.
7. Wallet display from the existing controller with explicit unavailable/loading states. Preserve top-up access. Call eligibility uses server available balance after holds, not just displayed posted balance.

Modify `calling_repository.dart`, `call_rate_model.dart` and `calling_controller.dart` narrowly:

- Use `previewCall()` for number-specific quote/policy. Debounce valid input, reject stale async results, refresh on caller identity/account changes, and refresh before call start. Preview failures must prevent a stale quote from enabling the call.
- Parse `availableBalance` and authoritative tariff metadata. Keep pricing precision for calculations; format rates to sufficient decimals and currency to the established app convention. Never derive billing from the rounded display string.
- Eliminate fallback amounts such as 0.15/0.08 and hard-coded gateway identities when source data is missing. Backend-configured gateway defaults are a separate provider policy; do not delete them blindly.
- Expose mutation failure; invalidate caller-ID state only after confirmed success. Keep the last confirmed selection if saving fails.
- Preserve media sequencing: microphone permission → prepare media → register/connect → server dial → app media readiness → provider bridge confirmation. A preview alone does not prove media is ready. Keep duplicate-call prevention and cancellation/late-event protections.
- Pass the confirmed quote into live cost estimation and label that estimate; final cost/duration comes from the server call record. Do not replace wallet debits with frontend arithmetic.

If required, extend `supabase/functions/make-call/index.ts` preview response additively with rate ID, billing increment, connection fee, currency and applicable billing-policy metadata. Verify account-tier identity propagation server-side. Keep all existing actions and fields, caller-ID policies, holds and idempotency. Do not alter billing economics to fit the screenshots.

Retain `active_call_screen.dart`, Recent Calls, DTMF, mute, speaker, end, failures and retry/gateway suggestions. Update user-facing terminology where appropriate without rewriting audio services.

Gate: normalized destination, selected identity, preview and dial request agree; unsupported/missing-price/insufficient-balance cases cannot masquerade as ready; unchanged media and caller-ID tests pass.

#### Stage 3 — Free Call integration

Modify `lib/features/voip_calling/presentation/screens/internet_calling_screen.dart`; reuse its existing repository/controller and `simLinesControllerProvider`.

- Add the Smart Calling info card: “Call other KeepSIMs users over Wi-Fi or travel eSIM mobile data with no Smart Call wallet deduction.” Do not imply mobile data is free. Mention secure WebRTC only after checking the actual transport; never invent an end-to-end encryption guarantee.
- Implement Household Lines and User Search as local browsing tabs, preserving current search behavior. Show real counts, loading, errors and empty states.
- Reuse `lookup_voip_contact_by_phone`. Guard against stale search responses, disabled/self matches and unavailable recipients. A household SIM row first resolves a KeepSIMs account; it does not directly become a PSTN call when Free Call is tapped.
- Use actual avatars/country/line metadata; render an eSIM or Physical SIM badge only when known. Omit live presence dots unless a fresh presence source exists.
- If a recipient is not registered, explain that result and offer a separate, explicitly paid Smart Call route with the number prefilled and a new quote. Never auto-convert Free Call to a chargeable call.
- Preserve incoming call behavior, foreground/native answer/decline, cold acceptance, two-way audio, minimize/restore, offline local end, account recovery and zero app-call wallet deductions.

If lookup failures currently collapse to “not registered”, adjust `voip_calling_repository.dart` narrowly to distinguish network/service errors. Do not modify the WebRTC protocol solely for the redesign.

Gate: existing recipient recovery tests remain green; registered and unregistered flows are distinct; no fabricated online state or unintended paid calls.

#### Stage 4 — Numbers and Smart Call Setup

Modify `my_numbers_screen.dart`, `virtual_did_model.dart`, `roaming_forwarding_wizard_sheet.dart` and the corresponding methods in `calling_repository.dart`.

- Show real country, DID, status and routing preference. Use a supplied label if a verified field exists; otherwise use a neutral country/Virtual Number label. Never fill in “US Cloud Gateway” or “London” just because an example shows it.
- Preserve supported settings, renewal/fee information where already available, and refresh after successful changes. Do not invent ACTIVE status or fees when data is incomplete.
- Map `app` to Ring In-App, `pstn` to Forward, and `voicemail` to Voicemail only after verifying execution support. Preserve legitimate legacy `sim_roaming` settings through a supported settings path; do not drop persisted values during the redesign.
- Add Number must link to actual provisioning if discovered. If none exists, omit the purchase action and record provisioning as unavailable, rather than presenting a button that inserts a fake number.
- Consolidate forwarding into one setup section with an explicit selected destination DID. Keep activation and cancellation instructions; cancel-on-return is existing functionality absent from the mockup and must survive.
- Reuse real home-SIM/country/carrier data and `getCarriersForCountry` for Home Operator. Carrier inventory is not forwarding support metadata. Use `getForwardingCodes()` as the current source for generic instructions.
- For an unsupported/unverified operator, say “Confirm forwarding support and charges with your operator”; clearly label generic GSM guidance if shown. Do not make a carrier selector imply the code is customized when it is not.
- Copy Code copies the exact selected code. Open Dialer is platform-capability dependent, preserves `*`/`#` escaping, and must not silently activate forwarding or select a domestic SIM on the user's behalf. Explain the user's need to choose the home SIM on dual-SIM devices.
- Explain home-carrier forwarding charges separately from KeepSIMs inbound/data charges. Do not claim $0 roaming fees or guaranteed reachability. Copying/opening a code does not establish forwarding is active; provide a test-call checklist or unverified setup state.

Only extend `manage-dids/index.ts` if the verified capability requires it: validate ownership, destination, supported mode and successful row update. Keep existing requests compatible. Operator-specific templates require validated operator configuration and a source, not a hard-coded STC example.

Gate: real inventory/errors render correctly; routing changes persist or report failure; codes use the selected owned number; activation and cancellation stay accessible; unverified inbound operation is not advertised as working.

#### Stage 5 — Savings

Add `lib/features/calling/presentation/screens/smart_call_savings_screen.dart`. Refactor `rate_savings_calculator_widget.dart` so its existing `show()` entry point and the new screen share controls and calculations. Reuse `destination_country_search_sheet.dart` and real account rates. Add `lib/features/calling/domain/smart_call_cost_calculator.dart` for tested calculation logic if no suitable helper exists.

- Keep the destination, numeric duration input and slider synchronized. Support the reference's 1–30 minute range while retaining the existing ability to calculate up to 60 minutes.
- Use the actual tariff and billing policy. The inspected `finish_media_call` in `20260921010000_calling_phase_b_billing.sql` rounds answered elapsed time upward to whole seconds and computes `ROUND(seconds * rate / 60, 4)`. The later rate RPC shown in `20260910031500_p4_calling_rate_precision_and_draft_fallback.sql` returns a zero connection fee. Other model fields suggest increments; verify which deployed policy applies before claiming “per-second” or adding charges.
- For the verified current policy, match that seconds-based calculation. If the actual deployed tariff uses an increment/minimum/connection fee, consume those authoritative terms and test them. Do not silently change settlement or infer charging solely from a model default.
- Use existing decimal/money conventions or a small fixed-precision representation suitable for four-decimal charges; avoid premature cents rounding. Round only for presentation and the specified settlement step.
- Replace the $2.50 comparison. Prefer a maintained comparison dataset with carrier, plan, route, currency, source and effective date. If unavailable, allow a user-entered rate labeled “Your roaming estimate”. Otherwise show KeepSIMs cost and “Add a roaming rate to compare”. No fabricated default comparison.
- Calculate delta = comparison cost − KeepSIMs cost. Percentage = delta / comparison cost × 100 only when comparison cost is positive. Explain zero, equal, negative and missing comparison cases; do not clamp negative savings into a positive claim.
- Use the circular indicator for positive comparable savings, with semantic text containing the same percentage. Show a neutral/equal or higher-cost result when appropriate. Reject negative/invalid user inputs. Compare like currencies and call durations; disclose any supplied fees/rounding assumptions.
- Do not copy claims about credits never expiring, expiring roaming bundles, flagfall or minute penalties unless backed by the applicable product terms/data.

Gate: calculation tests agree with the verified backend policy; missing-rate and no-comparison states work; no hard-coded production roaming rate remains.

#### Stage 6 — Voicemail and actual playback

Modify `voicemail_inbox_screen.dart`, `voicemail_model.dart`, relevant repository methods, and add `lib/features/calling/presentation/controllers/voicemail_playback_controller.dart` plus a shared player/detail widget if useful.

- Use real caller/name, number, timestamp, duration and unread state. Infer country only from valid metadata/number parsing; allow Unknown. Refresh unread state after successful mark-read and keep the navigation badge derived from real unread records. If the inbox is limited to 50 rows, do not present its length as a total unread count.
- Implement search/filter only against supported fields and label whether it covers loaded results. Keep full transcripts readable and scrollable, not truncated to ten lines in the expanded view.
- Implement actual audio initialization/play/pause/seek/position/completion/failure. Inspect whether the existing `video_player` dependency and audio-session handling support the target voicemail format/platforms; reuse them if suitable, otherwise add one justified supported audio package. Only one voicemail may play at a time.
- Stop/pause and release playback on route disposal, account change, interruption and incoming/outgoing call activation. Coordinate with existing audio focus so voicemail cannot fight a live call. Do not acquire microphone access for voicemail playback.
- Display a real progress track; waveform visualization is optional and must derive from audio or be clearly decorative. Playback speed appears only if implemented and tested. Handle missing/expired media URLs with retry/refresh rather than a false playing state.
- Render the genuine transcript and language. Processing/failed messages get an honest status. Summary, category and translation toggles appear only when backed by genuine stored/provider results. One transcript plus `language` is not bilingual content. No client-invented “Bank Alert”, family classification, summary or Arabic translation.
- Deep-linking to a message must enforce user-scoped retrieval, mark/read correctly and handle deleted/unavailable messages. Do not infer account ownership from a route ID.

For `supabase/functions/process-voicemail/index.ts`, correct misleading status handling if included in this stage and verify trusted ingestion before enabling new writes. Never store placeholder status copy as a successful transcript. Avoid putting transcript/passcode contents in new diagnostic logs or notification previews; use a neutral voicemail notification unless an established user-controlled preview policy requires otherwise.

No AI schema extension is required for a truthful redesign. If a deployed summary/translation/category service is found, document its contract and map it additively. If none exists, keep these sections absent and list a separately scoped intelligence enhancement with provider, job lifecycle, storage, access control, retry and cost requirements. Do not claim Stage 6 delivered AI generation.

Gate: audio can actually be heard and controlled on a supported device, unread state is consistent, transcripts/statuses are truthful, and optional intelligence is never fabricated.

#### Stage 7 — integration, accessibility, regression checks and handoff

Run relevant baseline tests after each affected stage. Add meaningful tests for new behavior rather than tests that only repeat widget labels. At the end run the full required checks and report new failures separately from existing ones.

Minimum automated coverage:

| Area | Required cases |
|---|---|
| Router/shell | Each old route, new Savings, voicemail detail, direct entry/back, repeated tab taps, selected nav state, one bottom bar, pending native call and payment routes preserved |
| Dialer | Paste/edit/delete/prefix/contact/redial all produce one normalized destination; ambiguous prefixes; invalid/unsupported destinations; quote A arriving after quote B; caller-ID and account changes invalidate quote |
| Call gates | No quote, invalid caller identity, insufficient available balance despite higher posted balance, denied microphone, unavailable media; double taps create at most one call |
| Caller ID | Verification/switch failures, self-dial policy, Oman restricted route policy, explicit gateway fallback, no hard-coded identity on error |
| Pricing | 1, 59, 60, 61 and 720 seconds, high-precision rate, missing tariff, positive/equal/negative savings, zero comparison, invalid duration, actual increment/fee rules if supported |
| Free Call | Registered, unknown, self and failed lookup; stale search; SIM-line row resolution; explicit paid fallback; no app-call debit |
| Numbers | Loading/empty/error, actual status, unsupported modes, failed write, correct owned DID, generic vs supported operator instructions, cancellation and encoded dialer URL |
| Voicemail | Real controller transitions, only one playback, failed URL, seek/end/interruption/disposal, unread update failure, long transcript, absent optional fields, processing vs transcribed, detail access isolation |
| Layout | Widths 320/360/390/430 logical pixels, text scale 1.0/1.3/2.0, keyboard, safe areas, English/Arabic RTL, landscape if currently supported, light-theme legibility |

Existing regression suites to retain/update:

- `test/features/calling/call_audio_controller_test.dart`
- `test/features/calling/caller_id_policy_test.dart`
- `test/features/calling/calling_mode_switcher_test.dart` — migrate assertions to the new shared navigation behavior.
- `test/features/calling/dtmf_keypad_test.dart`
- `test/features/calling/rate_savings_calculator_test.dart` — replace obsolete fixed-rate assumptions.
- `test/features/calling/roaming_forwarding_wizard_test.dart` — inject explicit forwarding instructions/capabilities.
- `test/features/voip_calling/voip_call_session_model_test.dart`
- `test/features/voip_calling/floating_minimized_call_bar_test.dart`
- `test/features/voip_calling/voip_navigation_and_recovery_test.dart`
- `test/call_media_backend.test.cjs`

Commands, adjusted only for the repository's installed tooling:

```text
flutter gen-l10n
dart format <changed Dart files>
flutter analyze
flutter test test/features/calling test/features/voip_calling
node --test test/call_media_backend.test.cjs
flutter test
flutter build apk --debug
```

`npm test` is a placeholder that deliberately fails in the inspected package.json; do not use it as the backend suite. Run code generation only if generated models/providers changed. If Edge Functions or SQL change, use the project's corresponding checks and isolated integration tests. Verify platform builds where toolchains exist; iOS/device limitations on Windows must be reported, not counted as passes.

Manually inspect screenshots of every redesigned screen and the large-text/RTL/narrow states. Verify safe-area spacing, scroll reachability, real contrast, focus order and screen-reader labels. Do not use color alone for availability, unread state or errors. Keep phone numbers/codes legible left-to-right inside Arabic layouts.

Authorized staging/device acceptance must cover paid call answer/two-way audio/end and authoritative debit, busy/no-answer/cancel, verified/gateway identity behavior, real DID inbound routing where claimed, voicemail capture/playback, and app-to-app foreground/background/cold-start acceptance with recipient hangup. Reuse the 22 September recipient retest guide instead of weakening its checks. Verify no charge for app-to-app calls and no live microphone/media after end.

If hardware/provider access is unavailable, finish the local stages and give a concrete unverified acceptance list. Build success and mocked tests cannot establish end-to-end telecom success.

### 6. Backend and schema change boundaries

Default: reuse existing contracts and schema. Necessary narrow fixes may include additive preview fields and account identity propagation, accurate mutation errors, truthful voicemail processing state, and trusted-ingestion validation. Keep changes backward-compatible with current clients and verify before rollout.

Do not edit old migration files to rewrite history. If a schema change becomes genuinely necessary, follow the project's migration workflow with a new reviewed migration and user-owned data policies. Do not expose service credentials or weaken RLS. Consult current official documentation before introducing new provider/Supabase APIs. Do not deploy schema/functions implicitly as a side effect of UI work.

New DID purchasing, a missing inbound delivery/recording pipeline, a new operator forwarding catalog, live presence and a new AI generation pipeline are separate capability implementations. For each missing capability, document the minimal contract, affected files, data requirements, operational dependency and acceptance test. Leave unavailable controls absent or explicit, and distinguish “redesign complete for supported features” from “full reference capabilities delivered”.

### 7. Completion and final report

Do not call the work complete merely because screens resemble the images. Confirm:

1. Customer-facing old feature labels are updated appropriately, including errors, tooltips, accessibility labels and active-call/history presentation. Preserve historical records and internal identifiers; do not rewrite ledger history for branding.
2. All five redesigned screens and Inspector navigation integrate with existing routes; Recent Calls and supported settings remain accessible.
3. Production data, rates, identities, wallet states, forwarding instructions and voicemail are genuine. No sample arrays, made-up prices, status dots or simulated media remain in these surfaces.
4. Three experiences are unmistakable: paid Smart Call, Free Call, and forwarded incoming calls.
5. Existing media, call state, billing, incoming/native actions and account protections remain compatible.
6. Layout and accessibility checks pass; automated checks have explicit results.
7. Missing backend capabilities and unverified real-device behavior are reported as gaps, never silently represented as delivered.

Return a concise implementation report with files changed; shared components added/reused; services retained; backend/API and schema changes (or “none”); assumptions; capability gaps; exact test/build results; device/provider evidence; and remaining release blockers. Include screenshots and a focused rollback description. Keep changes in logical, reviewable stages and preserve unrelated working-tree edits.
