# KeepSIMs eSIM Access integration — implement one step at a time

Date: 28 October 2026, Asia/Muscat. Status: ESIM-01 and ESIM-02 implemented/tested locally; ESIM-02 database/Edge/VM runtime deployed and verified after approval; app UI tested locally. Fresh VM/source checks now succeed; catalogue account access is live verified; paid provider acceptance remains UNKNOWN. ESIM-03 implementation and backend runtime are deployed/verified; ESIM-04 runtime is deployed/verified with real callback registration pending the provider authentication contract. Customer/Admin app changes are tested locally; no binaries were published. ESIM-05–14 remain planned.

This plan covers the useful standard-API capabilities discussed with the owner. It does not purchase Android direct installation, the Android SDK, or carrier-name customization. Standard API integration has no published setup/monthly platform fee; packages, recharges, development, infrastructure and any chargeable notification services still cost money. KeepSIMs controls its app branding. See [S1], [S2], [S3].

The workspaces are `keep_sims` (customer/database), `keep_sims_admin` (admin) and `backend-sync-wt` (authoritative Node backend), siblings beneath `/Users/thehonest/Work/KeepSIMs`. Keep this programming plan with the customer repository. Existing unrelated edits in all three repositories must be preserved.

## How to use this plan

Implement the numbered steps in order. Every step has a usable outcome, explicit dependencies and acceptance checks. A step can be implemented and reviewed separately; dependency completion is mandatory before enabling its behavior. Read-only improvements can ship before money-changing features. Do not implement all fourteen steps in one change.

Use this request in a later conversation, changing the step ID:

> Implement ESIM-01 from `docs/implementation-plans/esimaccess-integration-plan-20261028.md`. Read the project rules and current code first. Work only on that step and necessary unmet prerequisites; report any prerequisite before expanding scope. Preserve unrelated edits. Add focused meaningful tests, update this plan's progress record with evidence, and distinguish local implementation from deployed verification. Do not submit chargeable provider actions as part of routine tests. If deployment is included in my request, synchronize the affected GitHub repositories and actual VM using the project deployment rules and verify runtime behavior.

If an earlier step is only locally tested, a dependent change can be prepared locally, but must not be enabled in a runtime that lacks its prerequisites. Proposed names in this document are design suggestions, not claims that a table, RPC or configuration key already exists.

## Delivery checklist and dependencies

| ID | Deliverable | Depends on | Initial state |
| --- | --- | --- | --- |
| ESIM-01 | Baseline, provider contract and release gates | None | Tested locally; live metadata checked; VM/account UNKNOWN |
| ESIM-02 | Correct catalogue and transparent plan details | 01 | Runtime deployed/verified; app UI tested locally |
| ESIM-03 | Stable profile identity, lifecycle and usage | 01, 02 | Implemented/tested; backend deployed, paid acceptance pending |
| ESIM-04 | Provider event inbox and reconciliation | 03 | Runtime deployed/tested; provider callback registration blocked by URL-only configuration |
| ESIM-05 | Useful data, expiry and order alerts | 04 | Planned |
| ESIM-06 | Installation links, guides and recovery | 03 | Planned |
| ESIM-07 | Compatible recharge discovery and quotes | 02, 03 | Planned |
| ESIM-08 | Safe manual fixed-bundle recharge | 04, 07 | Planned |
| ESIM-09 | Selectable Day Pass duration and extensions | 08 | Planned |
| ESIM-10 | Eligible unused-profile cancellation/refunds | 04, 08 | Planned |
| ESIM-11 | Suspend/resume and admin support tools | 04, 06 | Planned |
| ESIM-12 | Optional capped automatic recharge | 05, 08, 09, 11 | Planned |
| ESIM-13 | Family/traveller labels and group ordering | 06, 08, 10 | Planned |
| ESIM-14 | Final acceptance and operational handover | All implemented steps | Planned |

Recommended release milestones: A = 01–03 (trustworthy catalogue/profiles); B = 04–06 (alerts/install support); C = 07–09 (manual recharge and daily plans); D = 10–11 (customer/admin controls); E = 12–14 (automation/groups/full acceptance). Each milestone may contain several small deployments.

## Current evidence and limitations

The following observations are from local source inspected for this plan, not a fresh live VM or database audit:

| Source | Observation | Consequence |
| --- | --- | --- |
| `backend-sync-wt/providers/esimaccess.js` | Catalogue, order, polling and usage methods exist; recharge/lifecycle actions are absent. | Extend the existing adapter; do not create another supplier integration. |
| Same adapter | Daily recognition uses text/string heuristics, treats detected daily offers as unlimited, and guesses a FUP rate when absent. | Correct classification before selling configurable daily plans. |
| `backend-sync-wt/worker_esim_fulfillment.js` | Issuance parser does not retain the stable supplier profile reference; missing issuance can produce fabricated identifiers; initial expiry uses purchase time plus cached days. | Fix identity, issuance proof and validity before exposing more actions. |
| Same worker | Usage defaults to four-hour polling, requests by ICCID, saves remaining allowance without replacing the stored total from that response, and polls only locally active profiles. | Improve freshness, totals and lifecycle reconciliation. |
| Same worker | The catch path attempts a wallet refund for general fulfillment errors. | Transport errors must be separated from definitive supplier failure before extending money paths. |
| `keep_sims/lib/features/esim/domain/repositories/esim_repository.dart` | No existing-profile recharge operation. | Add quote/recharge contracts and controllers. |
| `keep_sims/lib/features/esim/presentation/screens/esim_screen.dart` | “Buy Again” navigates to general plans. | Keep new-profile purchase separate from recharge. |
| `user_esim.dart`, repository implementation and baseline schema | Client names for activation/order/timestamps differ from worker/baseline names. | Verify the deployed projection before declaring a bug; add one deliberate compatibility mapper. |
| `keep_sims/supabase/migrations/20261027203028_esim_supplier_visibility.sql` | Fresh checkout checks active supplier and offer; order quantity is limited to three in this captured implementation. | Preserve supplier gating; group ordering needs a coordinated limit change. |
| `backend-sync-wt/supplier_reconciliation.js` | Existing reconciliation claims are for refill executions. | Do not assume this already recovers eSIM orders or top-ups. |
| `keep_sims_admin/lib/core/admin/admin_api.dart` | Existing audited supplier-list/update/sync API boundary. | Extend this admin pattern for new eSIM controls. |

The existing `docs/reviews/esim-supplier-visibility-20261028.md` reports earlier live catalogue verification. It does not certify eSIM purchasing, cancellation, installation or recharge. Do not reuse historical test counts as current evidence. Most project data is demo/mock; use isolated fixtures and the real offer catalogue where relevant, rather than spending time cleaning demo records.

## Product and engineering decisions

- All additions begin with `provider=esimaccess` capability checks. Unsupported suppliers receive explicit unavailable states; no default-to-another-provider behavior. An installed profile cannot be silently moved between suppliers for a cheaper recharge.
- Keep number-preservation airtime refills and travel-eSIM recharges distinct in the UI and domain. They may share verified financial primitives, but have different eligibility and fulfillment rules. Existing DT One Pre-production credentials/catalogue behavior is outside this change.
- Customer-visible names stay KeepSIMs. Real network names and required technical installation details remain accurate. Hide wholesale prices, supplier credentials and internal debug messages from customer responses.
- Treat profile installation, bundle entitlement, order execution and wallet settlement as separate states. Purchasing does not prove installation; empty usage does not prove depletion; losing connectivity does not prove expiry.
- Store authoritative data in bytes and money in exact decimal/integer units. Document conversion to existing MB fields and use one display convention across comparison, checkout and usage. Store UTC timestamps; localize display. Never invent allowance, expiry, FUP speed or issuance identifiers.
- Keep provider secrets, operation claims, quotes, eligibility and wallet changes on the trusted backend. Flutter follows domain → repository → controller → UI, using the existing eSIM pattern.
- Use additive database changes and explicit RLS/grants; expose minimal retail projections and owner-controlled activation details. Reuse `assert_admin()` and trusted app-metadata roles for admin actions. Logs redact ICCIDs, EIDs, activation codes and provider secrets.
- Separate the new-action switch from settlement/reconciliation. Disabling new sales or recharge must not strand already-submitted work. Customer recharge, automatic recharge and admin operations get separate switches.
- There is no provider sandbox [S4]. Routine tests use isolated fixtures and no external side effects. Any paid live acceptance must name the account/profile, permitted operations and spending ceiling in the implementation request; do not assume a cancellation makes a purchase test risk-free.

## ESIM-01 — Baseline, contract and release gates

**Outcome:** a verified map of what exists, what is deployed and which supplier capabilities are usable before extending it.

**Work:**

1. Read `.agents/AGENTS.md`, relevant `.codex` rules and this plan. Capture current branch/revision and relevant dirty files in each repository without overwriting them.
2. Inspect the current deployed schema, grants, retail/owner projections, wallet/hold functions, queue states, Edge Function configuration and VM worker version using read-only checks. Compare them with local definitions.
3. Inventory existing profile/order ownership, order-to-ledger references, issuance proof, secrets source and credentials rotation. Do not dump live activation material or account credentials into evidence.
4. Create a small redacted provider-contract fixture set and capability matrix: discovery, issuance, usage, fixed recharge, daily extension, cancel, suspend/resume, installation options, batch limits and event verification. Use existing read-only access where available; mark unavailable observations UNKNOWN.
5. Verify provider request authentication and documented response types, pagination, throttling and error classification. Request signing does not establish how incoming webhooks authenticate. Confirm action recovery and duplicate-request behavior rather than assuming a transaction ID alone makes retries safe.
6. Define feature flags and a release manifest. Block new money actions until exact outcome lookup or operator reconciliation is defined. Record existing eSIM safety defects as prerequisites, including fabricated issuance and timeout/refund handling.

**Acceptance:** a redacted evidence map; no purchase/wallet mutations; explicit UNKNOWN items; capability refusals tested for unsupported providers; a written remediation checklist for ESIM-03/04/08. No feature is declared live from a migration filename alone.

**Main surfaces:** all three workspaces; provider adapter; current checkout RPC and financial primitives; deployment source manifest.

## ESIM-02 — Correct catalogue and transparent details

**Outcome:** plan cards and checkout accurately explain what the customer buys.

**Work:**

1. Retain normalized top-up support, activation trigger, unused activation deadline, plan type, daily allowance behavior, supplied FUP text, network list, APN/help metadata where supplied, package identity and source-update time. Preserve original provider values privately for diagnosis with a defined retention policy.
2. Use provider values rather than name heuristics wherever available. Distinguish total-data bundles, daily allowance with slowing, daily cut-off and daily unlimited. Missing values display “Not provided,” not invented values.
3. Preserve both stable product alias and current supplier product identifier in catalogue/order snapshots. Do not rename existing keys or merge historical purchases based only on matching descriptions. Keep BASE discovery separate from compatible TOPUP discovery.
4. Update the authoritative worker and the existing Edge catalogue-sync path consistently, or explicitly retire the redundant writer after tracing all callers. Prevent the old writer from erasing enriched fields.
5. Extend retail projections, comparison/detail models, filters and checkout. Show exact destination coverage, supported networks, activation conditions and recharge capability. Keep wholesale metadata private and existing supplier visibility/pricing rules intact.

**Acceptance:** fixed/daily/cut-off/unknown fixtures classify correctly; no unsupported unlimited claims; compatible units/prices across screens; inactive suppliers remain excluded; unknown/null values do not crash; older clients continue reading valid projections.

**Main surfaces:** both catalogue normalizers, `esim_offers_cache`/retail RPCs, customer plan/compare entities and checkout, admin supplier diagnostics.

## ESIM-03 — Stable profile identity, lifecycle and usage

**Outcome:** My eSIMs shows genuine profiles, accurate lifecycle and trustworthy usage freshness.

**Work:**

1. Retain the supplier profile reference and original issuance/order binding. Use an internal UUID plus supplier/account/profile identity for ownership and uniqueness; review global ICCID uniqueness and existing upsert behavior before changing constraints. Never overwrite another user's profile because an ICCID matches.
2. Fix the client/worker/schema mapper after verifying the deployed view. Preserve existing activation credentials securely and return no guessed activation code or fallback server address when required fields are absent.
3. Remove fabricated ICCID/matching-ID success records. Missing issuance remains pending/reconciling or support-required, with existing funds protected. A partial batch records only evidenced profiles.
4. Keep raw provider state plus normalized profile, installation and bundle states. Derive customer labels deliberately. Do not force existing profiles into new states or erase evidence during backfill.
5. Replace purchase-date expiry calculation with provider-confirmed activation/expiry. Before activation, show the appropriate activation deadline and validity trigger [S6]. For unresolved older profiles, show unknown until reconciled.
6. Refresh both total and used/remaining allowance, provider observation time and local check time. Do not regress newer observations with stale responses. A failed refresh retains last-known data with a stale label.
7. Schedule eligible issued, active, suspended and unresolved/depleted profiles appropriately; terminal states receive bounded final checks. Avoid a loop that permanently abandons a profile after a guessed zero balance. A customer refresh reads saved state and requests a throttled backend refresh; never calls the supplier from Flutter.

**Acceptance:** issuance without proof cannot complete; provider-ID collision cannot cross ownership; purchase is not labelled installed; activation-based expiry is correct; zero/unknown/failed usage are distinct; updated totals persist; old-to-new responses do not regress state; no N+1 request storm on app refresh.

**Main surfaces:** fulfillment worker, provider usage/parser, `user_esims`/owner projection, UserEsim mapper/controller/cards, SQL constraints and access tests.

## ESIM-04 — Provider events and reconciliation

**Outcome:** supplier changes arrive reliably, and missed events or timeouts have a recovery path.

**Work:**

1. Add one trusted event ingress integrated with the existing backend/Edge architecture. Support the documented order, profile, usage and validity event families [S7], and newly observed types only after contract validation.
2. Establish actual incoming authentication. If cryptographic verification is unavailable, treat callbacks only as refresh hints behind a protected, rate-limited ingress; verify consequential changes by authenticated supplier queries. Never translate an untrusted event directly into money settlement, ownership transfer or issuance success.
3. Persist an event inbox with a deduplication key, receipt time, supplier reference, processing status and minimized payload. Acknowledge durably accepted events promptly; process them with retry/backoff and dead-letter visibility.
4. Correlate each event to its supplier/account/profile and original operation. Handle unknown profiles, duplicates, out-of-order delivery and events arriving before issuance materialization.
5. Add eSIM-specific reconciliation using the existing queue/lease patterns. Read-only lookup adopts submitted operations before any possible reissue. Use the verified lookup contract; if exact outcome cannot be proved, retain the pending state and escalate to an operator.
6. Coordinate event processing and periodic polling under an account-wide supplier limiter. Keep recovery active when new purchases are disabled. A reported API limit is eight requests/second [S4]; configure a conservative shared limit rather than eight per worker.

**Acceptance:** forged callbacks cause no state/financial action; repeated events cause one effective change; older events cannot undo newer truth; restart after event persistence recovers; provider success before local persistence is adopted; unavailable lookup retains uncertainty; no expiry-only fund release.

**Main surfaces:** new eSIM ingress/inbox processor, fulfillment/reconciliation workers, database execution records, worker fleet telemetry and admin evidence views.

## ESIM-05 — Actionable alerts

**Outcome:** users learn when installation is ready, allowance is low, or validity is ending.

**Work:**

1. Reuse the existing notification catalogue, preferences and delivery infrastructure. Add ready-to-install, activated, low-data, near-expiry, expired and operation-result events with authenticated deep links.
2. Normalize provider thresholds and local reminders into one deduplicated policy. Keep thresholds configurable; use a per-profile/bundle-cycle key so recharge can start a new alert cycle. Persist deliveries and distinguish queued/sent/failed.
3. Respect user preferences, timezone and existing quiet-hour rules. Show informative states if notification permission is denied. Near-expiry actions explain recharge eligibility rather than promise renewal.
4. Make alerts useful: open the owned profile or its valid recharge choices. Before ESIM-08 is enabled, low-data alerts must not offer a nonfunctional recharge button.
5. Start with existing in-app/push channels. SMS-to-eSIM is an optional later channel: first confirm account eligibility, pricing, sender behavior, consent and active-profile restrictions [S12]. Do not call it free messaging or ordinary OTP service.

**Acceptance:** duplicate event plus polling produces one alert per threshold/cycle; correct deep link/owner; opted-out users are respected; recharge resets appropriate thresholds once; stale data does not produce a false precise balance; disabled channels fail visibly without duplicate fallbacks.

## ESIM-06 — Installation and recovery

**Outcome:** easy installation on the current device, with clear fallback and recovery.

**Work:**

1. Add Apple installation links using the official currently supported mechanism and OS checks [S8]. Keep QR/manual entry for Android and unsupported Apple cases; retain offline rendering of already-owned QR data.
2. Keep all activation data behind owner/authorized-manager access. Generate links safely without logging credentials or sending them to analytics. Validate the host and encode the activation payload correctly.
3. Add concise platform-specific instructions for cellular-data selection, roaming/APN where required, compatibility/carrier-lock checks and retaining the primary SIM for calls. Use provider/device facts, not a universal compatibility promise.
4. Show the plan-specific activation trigger before installation. Explain that “offline QR display” does not mean installation itself works without internet access.
5. Add a recovery/help flow using observed profile state. Offer same-device reinstallation only when eligible; explain the documented transfer restriction [S9]. Sharing an installation code is not device transfer or family data sharing.
6. Keep expensive Android provisioning/SDK/SPN integrations absent. An owner-editable SIM label is only a label, not paid carrier-name customization.

**Acceptance:** install link works on a supported real Apple test device; QR/manual fallback remains usable; expired/missing payload is handled; old installs do not prompt repeated installation; no credential leakage through logs/analytics; recovery copy matches provider eligibility. If no suitable device is available, label native acceptance unverified.

## ESIM-07 — Compatible recharge discovery and quotes

**Outcome:** users can see what their existing eSIM can accept before any recharge money is spent.

**Work:**

1. Add a backend read operation that checks ownership, supplier capability, current profile/bundle state, concurrent unresolved actions and compatible offers. Expired/unsupported profiles explain why recharge is unavailable [S5].
2. Read the profile's compatible TOPUP list; do not substitute the general destination catalogue. Cache by supplier/account/profile and short TTL; invalidate after relevant profile or catalogue changes.
3. Create an expiring server quote bound to user/payer, exact profile, package identity, action, duration where applicable, retail total, currency, supplier/account context, expiry and a single-use acceptance key. Keep wholesale figures internal.
4. Reuse verified retail fee rules and wallet availability semantics. A failed balance lookup is unknown, not zero or permission to spend posted-but-reserved money. Do not introduce a second funding fee for wallet-funded spend.
5. Add “Recharge” next to installation details. Keep “Buy a new eSIM” separate. Show whether the offer adds allowance, adds validity, or both. Unknown post-recharge expiry is shown as provisional until supplier confirmation.
6. Keep quote/discovery available behind a read-only flag; acceptance remains disabled until ESIM-08.

**Acceptance:** unrelated users cannot query/quote the profile; incompatible offers are rejected server-side; changed package/price requires a new quote; insufficient/unknown available balance is honest; disabled supplier cannot create a new accepted action; no supplier purchase occurs during browsing.

## ESIM-08 — Safe manual fixed-bundle recharge

**Outcome:** one approved recharge updates the same installed profile and creates one correct financial result.

**Work:**

1. Implement eSIM operation records for new purchases and recharges, or adapt the verified existing engine without duplicating the financial authority. Persist actor, owner, payer, profile, immutable quote, action, stable supplier submission reference, claim lease and recovery state.
2. Use one wallet reservation/capture/release model supported by the project's audited primitives. A legacy already-debited order needs its own migration/recovery path; never reserve/debit it again. Extend transaction/action allowlists and reconciliation reports deliberately.
3. Recheck quote freshness, profile eligibility, available funds and unresolved sibling actions atomically. Serialize mutating operations per profile and payer as required. Duplicate taps/client retries adopt the same action; concurrent different actions cannot bypass the lock.
4. Submit through the existing adapter with a persisted reference. Verify provider duplicate behavior and exact recovery method from ESIM-01. A transport timeout, ambiguous response or allocation delay stays reconciling; do not auto-refund or issue a second purchase.
5. Capture once after evidenced service delivery. Release a reservation only after definitive failure/no submission. For a confirmed failure of a legacy debit, refund the original payer once from actual recorded ledger amounts. Local database/save errors after supplier success are recovered, not treated as failed delivery.
6. Update allowance/expiry from supplier confirmation, keeping the same internal profile and installation credentials. Add a customer receipt, recharge history and support-visible operation timeline. Do not infer final success solely from an approximate change in usage totals.
7. Repair the existing new-profile fulfillment timeout/refund/fabricated-issuance paths so both old and new purchase types follow the same safety invariants before enabling additional spend.

**Acceptance:** unchanged installed profile after successful top-up; exactly one capture for duplicate taps; supplier success plus DB failure recovers once; response timeout causes no second spend; terminal failure releases/refunds exactly once; a known pre-submission refusal spends nothing; other users/managers cannot spend the owner's wallet without authority; disabling new actions leaves recovery running.

**Live acceptance:** only a separately scoped low-cost purchase/recharge on a specified test profile, with a named spending ceiling. Until performed, report contract-tested/local acceptance separately from real-provider acceptance.

## ESIM-09 — Daily plans and selectable duration

**Outcome:** travellers can choose supported daily-plan duration and extend an eligible existing daily plan.

**Work:**

1. Add a day selector only for supplier-capable products. Validate the accepted duration range from the current contract; quote and snapshot the full total server-side, including any current supplier duration pricing. Do not multiply a displayed one-day retail price or hard-code marketing discount tables.
2. Carry the selected duration through new purchase quote, order, worker request and receipt. Reuse ESIM-08 execution/recovery for both initial daily purchases and extensions.
3. For an extension, match the existing base plan/variant and current eligibility. Explain that this extends days and does not refill the current day's high-speed quota or undo throttling [S10].
4. Display daily allowance and known reset timing separately from total package usage. Unknown reset timing remains unknown. Remove misleading total-GB or price-per-GB comparisons for daily products.
5. Use current provider capability responses and the newer daily-plan announcement when older help copy conflicts. The stated recharge-count limit needs account confirmation; make the resulting limit/configuration explicit, not unlimited [S5].

**Acceptance:** invalid durations/variants refused server-side; displayed and captured totals match; fixed-plan price filters still work; daily cut-off versus slowing is accurate; extension preserves daily quota; repeated/timeout extensions adopt one action; supplier-confirmed expiry replaces any provisional display.

## ESIM-10 — Eligible unused-profile cancellation and refunds

**Outcome:** an eligible unused eSIM can be cancelled with a clear refund outcome and history.

**Work:**

1. Add eligibility/read-only explanation first. Check current supplier state and exclusions; zero usage alone does not prove unused or refundable. Refresh state immediately before submission and serialize cancellation against recharge/installation-related mutations.
2. Show the exact scope and proposed customer refund before confirmation: base order, attached paid recharges, refundable amount/currency, payer and destination. Separate supplier wholesale credit from customer retail wallet credit.
3. Execute cancellation through a persisted operation. An uncertain cancellation remains pending until reconciled. Installation/activation races require refreshed provider truth; activated profiles route to support [S11].
4. Where supplier cancellation includes attached recharges, settle each eligible local charge exactly once with a unique refund binding. Do not refund the whole profile repeatedly or refund more than the original unrefunded debit. Verify supported retail-fee and external-payment policies rather than invent them.
5. Refund the original payer through existing audited financial primitives. A cancelled profile cannot create new recharge/automation work. Preserve receipts, evidence and historical ownership.

**Acceptance:** unused eligible cancellation; used/ineligible refusal; duplicate refund request; ambiguous cancellation; cancellation racing with top-up; base-plus-recharge refund accounting; partial supplier credit; different payer/owner; no refund based solely on an unverified callback.

## ESIM-11 — Suspend/resume and admin support

**Outcome:** supported customers can control service, and administrators can diagnose stuck profiles without unsafe shortcuts.

**Work:**

1. Add explicit suspend/resume actions using provider capability checks, ownership and the same persisted operation/locking model. Keep “pause automatic recharge” separate from suspending network service.
2. State that suspension stops data service; make no promise that validity freezes unless the current provider contract confirms it. Show a pending state until the supplier confirms the requested change.
3. Add audited admin RPCs through `admin_api.dart`: redacted profile search, state/usage freshness, operation timeline, refresh request, unresolved-operation queue, event health and reasoned support escalation. Wholesale costs remain restricted to authorized administrators.
4. Reuse existing supplier switches and fleet monitoring. Add supported-action switches, supplier-account funding/credential health and stale-catalogue indicators where verifiable. A transient health read cannot silently disable or redirect existing work.
5. Do not expose revoke/permanent deletion as an ordinary customer action. Any future use needs its own scoped policy and evidence. Optional MCP diagnostics are an admin aid, not an app credential or autonomous purchasing path [S13].

**Acceptance:** authorized owner versus unrelated account versus admin; duplicate/pending suspend; resume after suspension; disabled automation while suspended; stale provider response; no hidden validity promise; redacted search/audit; recovery cannot resubmit an unknown charge.

## ESIM-12 — Optional capped automatic recharge

**Outcome:** an explicitly opted-in customer can authorize predictable, limited recharges.

**Work:**

1. Create consent bound to the exact profile/payer, compatible package or approved selection policy, maximum charge per action, monthly cumulative cap, trigger, minimum interval, consent version and optional end date. No enabled-by-default automation.
2. Separate fixed-bundle low-data triggers from daily-plan near-expiry extensions. Depleting today's daily allowance must not trigger a charge that cannot restore today's speed.
3. Evaluate fresh enough provider observations. Unknown/stale state requests a refresh and waits. Trigger before expiry with a configurable safety margin; eligibility is rechecked immediately before submission.
4. Reuse ESIM-08 execution, exact quotes, wallet reservations and recovery. Manual and automatic operations share the same profile lock. Count committed and unresolved exposure against caps so concurrent operations cannot overspend.
5. On increased prices, insufficient funds, expired eligibility, suspended/cancelled profile or withdrawn consent, stop new submissions and notify the customer. Never substitute a new package or new installed profile beyond the consent.
6. Make pause/disable easy. Revocation prevents future submission but does not pretend an already-submitted action was cancelled. Maintain receipts and an automation audit trail.

**Acceptance:** consent required; cap enforcement under concurrency; duplicate events; stale usage; manual/automatic race; no repeat loop; no charge above the authorized total; mid-flight consent revocation; low wallet; daily quota cannot spuriously cause a day extension; global disable preserves reconciliation.

## ESIM-13 — Travellers, family and group ordering

**Outcome:** a purchaser can organize separate travel profiles and buy a group without losing per-person fulfillment visibility.

**Work:**

1. Add private traveller/profile labels and a dashboard grouping. Start with purchaser ownership and existing supported quantities. Do not imply a pooled allowance, device transfer, separate mobile phone numbers or shared installed profile.
2. Build a server-quoted batch with an explicit per-profile price and total. Keep per-profile child fulfillment, recharge and refund records under one payer/batch. Provider acceptance of a batch does not prove every profile was issued.
3. Only after contract verification, coordinate the customer RPC, database quantity constraint, worker batch size, rate limiting and UI maximum to support a configured group size up to the verified supplier limit. Do not merely raise Flutter's selector above the current three-profile backend cap.
4. Handle partial delivery, delayed profiles, cancelled members and attributable refunds. Allocate supplier/profile references deterministically; retries adopt missing or existing issuance without buying duplicates.
5. If account-to-account management is added, use explicit invitation/acceptance and least-privilege roles. Receiving installation details is not permission to spend the owner's wallet. Reuse suitable household infrastructure only after mapping its eSIM authorization contract.
6. No automatic sending of QR codes to contacts. An explicit user sharing action must warn about activation-code sensitivity and avoid public links; any expiring link needs revocation, authorization and a defined retention policy.

**Acceptance:** one order with distinct profiles; configured limit enforced by the server; partial completion/refund; repeated batch request; profile identity collision; original-payer accounting; manager cannot exceed granted rights; no other user's activation material exposed; separate allowances shown correctly.

## ESIM-14 — Final acceptance and operational handover

**Outcome:** implemented features are reproducible, verifiably deployed where authorized, and supportable.

**Work:**

1. Run focused adapter/worker, SQL/RLS/financial and Flutter feature tests. Include legacy supplier-visibility, retail pricing and existing order/QR regression checks. Use isolated test identities/data; suppress unintended external notification/provider effects.
2. Exercise representative current offers relevant to intended markets, such as Oman, Egypt, regional travel and a daily product when actually available. Do not assume a particular network is supplied just because its country is listed.
3. For authorized live acceptance, verify profile installation and normal usage, one existing-profile recharge, a supported daily extension and an eligible cancellation only within the named scope/budget. Replay/timeouts/failures should mostly be tested with controlled fixtures rather than deliberately causing paid production faults.
4. When deploying, apply only reviewed scoped migrations and compatible functions/workers. Follow `.agents/AGENTS.md`: authoritative backend is `backend-sync-wt`; transfer changed runtime files directly to `/home/abdal/keepsims_backend/servers/` on the recorded VM, verify syntax, restart only affected PM2 processes and inspect health. Do not rely on a VM GitHub pull.
5. Record relevant GitHub commit IDs, changed-file fingerprints, applied migration IDs, function configuration, VM runtime file fingerprints and acceptance evidence. Inspect outgoing diffs and never include unrelated dirty files or secrets. A GitHub update and a VM update are separate verification items.
6. Roll out by operation type and test cohort. A rollback disables new actions while keeping compatible schema, historical evidence and settlement/reconciliation available. Do not downgrade past fields/constraints needed by outstanding jobs.
7. Finish short customer help and admin runbooks: unable to install, delayed usage, no recharge choices, unknown provider outcome, refund pending, pause automation, suspend versus expiry, partial group delivery, supplier outage and account funding alert.

**Acceptance:** customer and admin paths match backend permissions; provider secrets remain private; no unexplained capture/refund/hold imbalance; active unresolved jobs remain recoverable; verified runtime matches recorded source; outstanding device/provider acceptance is explicitly listed instead of labelled passed.

## Proposed persistent contracts

These are logical responsibilities. Reuse suitable existing tables/services; do not create duplicate sources of truth simply to match these names.

| Contract | Minimum responsibility |
| --- | --- |
| Catalogue capability projection | Accurate retail plan facts and enabled actions; no wholesale exposure. |
| Owned profile projection | Stable identity, owner, installation material access, lifecycle, allowance and freshness. |
| Purchase/recharge quote | Immutable priced intent with profile/action/payer binding, expiry and acceptance reference. |
| eSIM operation | Durable claim/submission/recovery, supplier reference, wallet linkage and terminal evidence. |
| Package/entitlement history | Distinguish original plan and subsequent charges/validity changes without replacing the installed profile. |
| Provider event inbox | Durable correlation, deduplication, retry and processing provenance. |
| Automatic-recharge consent | Explicit authorization and cumulative spending constraints, separate from execution. |
| Group order/member records | Parent payment intent with per-profile issuance/refund outcomes and optional accepted roles. |

Candidate adapter methods: compatible top-ups, profile refresh, recharge, cancel, suspend and resume. Bind them to current documented operations during ESIM-01; do not assume method names imply endpoints exist. Candidate customer repository operations: request profile refresh, list compatible packages, request quote, accept quote, get operation history, request cancellation and set automation consent. Use typed refusals such as unsupported capability, stale quote, unavailable balance, expired profile and unresolved operation.

### Financial invariant for all money-changing steps

Reserve authorized funds → persist one submission intent → submit once → reconcile exact outcome → capture once on confirmed service, or release once on proved failure/no submission. Ambiguous outcomes remain reserved/pending; already-debited legacy actions use a separately verified refund path. Database transaction rollback does not undo a supplier purchase. Usage deltas are not a unique financial receipt. No operation may refund more than its actual attributable unrefunded charge, spend another payer's wallet, or convert an unknown supplier result into a new order.

## Per-step completion record

For each implementation append one compact evidence entry containing: step ID; implementation status; affected files and repositories; tests actually run and results; unresolved contract facts; schema/source revision; deployment state; provider/device acceptance state; feature-flag state; rollback action; next eligible step. Use PLANNED, IMPLEMENTED LOCALLY, TESTED LOCALLY, DEPLOYED or VERIFIED LIVE accurately. No implementation or deployment has been performed by creating this plan.

### ESIM-01 completion entry — 28 October 2026

- Status: IMPLEMENTED AND TESTED LOCALLY; fresh live metadata inspected; VM and direct provider-account acceptance UNKNOWN. No production release is claimed.
- Deliverables and findings: [ESIM-01 review](../reviews/esimaccess-baseline-20261028.md), [live evidence](../reviews/esimaccess-baseline-20261028/live-evidence.json), [provider matrix](../reviews/esimaccess-baseline-20261028/provider-contract.json), [release manifest](../reviews/esimaccess-baseline-20261028/release-manifest.json), and `tools/esimaccess-baseline/` checker, read-only SQL and synthetic fixtures.
- Validation: 13 focused baseline/adapter checks pass. Source fingerprints match the captured local files. The fixed-top-up readiness command refuses release with exit 2 as intended. No live provider action or wallet mutation occurred.
- Fresh evidence confirms 3,187 active cached eSIM Access offers; no owned eSIM Access profiles; profile/client activation-field mismatch; GitHub worker/local drift; and a deployed/local catalogue Edge source mismatch. Known issuance, validity and refund/recovery defects are assigned to ESIM-02/03/04/08 as appropriate.
- Access limits: VM SSH failed before connection under this Work session. A broad function-body query was rejected by automatic review and replaced with safe metadata/ACL/fingerprint inspection. Credential values were not read.
- Runtime/source: database function/Edge/GitHub/local fingerprints and repository revisions are in the evidence. No schema, runtime flag, Edge, VM or GitHub write was performed. Sixteen proposed new flags remain disabled in an offline manifest; it is not runtime enforcement.
- Rollback: no runtime rollback is needed. The checker/report can be removed or superseded without changing customer behavior; retain historical evidence if subsequent steps refer to it.
- Next eligible task: ESIM-02, correct catalogue and transparent plan details. All new write capabilities remain blocked until their missing prerequisites are verified.

## ESIM-02 progress — 28 October 2026

- Status: **DATABASE/EDGE/VM DEPLOYED AND LIVE VERIFIED after explicit user approval.** Customer/Admin app UI is tested locally; app binaries were outside the approved runtime deployment. See [review](../reviews/esimaccess-catalogue-20261028.md) and [live evidence](../reviews/esimaccess-catalogue-20261028/deployment-live.json).
- Delivered: explicit data-type classification; matching Node/Edge normalizers; BASE/TOPUP separation; alias/current IDs; private source facts with 30-day retention; retail facts/order snapshots; legacy-writer guard; v2 comparison/type filters; shared details/checkout formatting; guarded Admin diagnostics.
- Applied: `esim_catalogue_details` at `20261027232834`, followed by `esim_catalogue_runtime_compatibility` at `20261027233320`. Stored migration hashes match local SQL. Edge version 7 and all deployed source hashes are verified. Only the scoped catalogue worker was restarted; current PID 1056256. Pending fleet/credential-helper changes were excluded.
- Live acceptance found and resolved minimum-fee bounds and Vault-only VM credentials. Both Edge and the VM independently fetched/upserted 3,187 active offers. Source switches remain unchanged; only eSIM Access is visible. Counts: 1,731 total bundles, 1,456 daily slowing plans, no unsupported unlimited classifications; three activation facts remain explicitly unknown.
- Validation: 55 customer, 25 backend, 13 baseline and four existing Admin tests pass; six isolated PostgreSQL scenario groups and 12 legacy supplier-visibility checks pass. Actual authenticated/anon/Admin reads, price/filter parity, raw-table denials, Edge 403 authentication failures, daily retention and worker stability pass. No paid provider action or wallet mutation occurred.
- Remaining money/profile gates: ESIM-03 activation/identity/issuance/validity and ESIM-04/08 reconciliation/refund safety. No new money capability was enabled. Next implementation is ESIM-03 under its own scope and gates.

## Provider documentation and contract verification

Reviewed on 28 October 2026. Published help can conflict with newer announcements. Prefer verified current account behavior and API contracts, then newer specific announcements; record contradictions rather than guessing. Never invent an API sandbox, webhook signature, duplicate-request guarantee or refund entitlement.

- **[S1] Standard API/platform fees:** https://esimaccess.com/docs/do-i-need-to-sign-a-contract-and-a-moq-to-kickoff/
- **[S2] Branding agreement, Article 7:** https://esimaccess.com/docs/terms-of-service/
- **[S3] Optional paid Android/SDK/SPN extras:** https://esimaccess.com/docs/android-install-sdk-spn/
- **[S4] Current API reference:** https://docs.esimaccess.com/ — verify authentication, environment, limits, endpoint parameters, unique identifiers and response states when implementing. Read usage/profile behavior here rather than copying removed endpoints from older articles.
- **[S5] Recharge rules and limits:** https://esimaccess.com/docs/how-to-top-up-a-data-plan/ — lists expiry restrictions and recharge-count guidance; its older daily-plan exclusion conflicts with S10.
- **[S6] Activation and validity trigger:** https://esimaccess.com/docs/when-does-the-billing-period-validity-start-to-count/
- **[S7] Event notifications:** https://esimaccess.com/docs/what-webhook-notifications-do-you-send/
- **[S8] Installation options:** https://esimaccess.com/docs/what-are-the-available-esim-activation-methods/
- **[S9] Reinstallation and device restrictions:** https://esimaccess.com/faq/ and https://esimaccess.com/docs/can-users-reinstall-a-deleted-esim/
- **[S10] Newer daily-plan top-up announcement, 9 May 2026:** https://esimaccess.com/boost-unlimited-fup-plan-sales-with-top-up-feature/
- **[S11] Unused-profile cancellation:** https://esimaccess.com/docs/how-do-i-refund-an-unused-order/
- **[S12] Service SMS restrictions:** https://esimaccess.com/docs/i-got-an-sms-from-esimcarrier/
- **[S13] Optional administrative MCP diagnostics:** https://mcp.esimaccess.com/
- **[S14] Provider relationship/product boundaries:** https://www.redteamobile.com/esim-access/
- **[S15] Usage explanation, historical examples:** https://esimaccess.com/docs/can-i-check-data-usage/ — useful conceptually; confirm request paths against S4 before coding.

Remaining provider confirmations: exact recovery of an ambiguous recharge/cancellation; incoming event authentication/retry contract; depleted versus expired eligibility; account-specific recharge limit; current daily pricing; suspension effect on validity; SMS price/availability; and refundable scope/exclusions. None of these unknowns prevent preparing the read-only stages, but they gate the corresponding write capability.


### ESIM-03/04 progress — 28 October 2026

- ESIM-03: stable supplier/account/profile identity, evidence-only partial delivery,
  distinct lifecycle/install/bundle state, genuine expiry, byte usage/freshness and
  throttled owner refresh are implemented and tested. The database and scoped VM
  runtime are deployed. Customer/Admin UI changes are local, tested and unpublished.
- ESIM-04: protected refresh-hint ingress, private durable deduplication inbox,
  leases/retries/dead-letter visibility, exact-reference recovery and the shared
  account limiter are deployed and verified. Ambiguous submission never reissues
  or refunds automatically. Recovery remains active while new sales are disabled.
- Applied migrations: `20261028003236` / `20261028003243`. Event Edge v1 and
  catalogue Edge v8 match scoped artifacts. Fulfillment/catalogue VM hashes match
  the manifest; unrelated workers and pending fleet/Zendit changes were preserved.
- Validation: 133 focused cases (47 Node, 4 ingress, 19 isolated SQL scenario groups,
  63 Flutter), plus the 13 baseline tests. Analysis and artifact syntax/Deno checks
  pass. Live owner/non-owner/anon/Admin/service-boundary checks pass. Missing or
  invalid callback secrets return 403; a valid event plus duplicate produces one
  minimal inbox row and no order/profile/financial change. The synthetic row was
  removed precisely. Catalogue sync still returns all 3,187 active Access offers.
- Provider callback hookup remains incomplete: inspected the user's open account
  in Chrome with permission; the blank webhook form offers only URL, not a secret
  header/signature setting. Cancelled without modifying it. The ingress requires
  a dedicated secret header; registering a bare URL would fail. A verified provider
  callback authentication contract or reviewed authenticated relay is required.
- Paid issuance, real profile/usage and provider-delivered callback acceptance
  remain UNKNOWN: zero owned Access profiles/orders and no paid tests. Global
  ICCID reuse collisions remain support-required. ESIM-08 gates still apply;
  new purchases are blocked before debit, and no later money feature is enabled.

Evidence: `keep_sims/docs/reviews/esimaccess-profiles-events-20261028.md`
(workspace copy) / `docs/reviews/esimaccess-profiles-events-20261028.md`
(customer repository). Source manifest and reproducible release builder are linked there.
