# Protection without modes and the return-country wizard

Executor implementation brief · 13 September 2026

## 1. Outcome and scope

Keep every enabled protection feature working regardless of where the user is. A secondary Egyptian line must remain protected while its owner is in Egypt, Oman, or anywhere else. Replace the Travelling Soon switch with a persistent return-trip wizard. Make SIM insurance the fourth and final row inside the Protection grouped list.

The user explicitly selected **whichever connectivity option is supported**: an eSIM package, a carrier data bundle for the existing line, or both when available.

This brief is based on the current working-tree implementation, including uncommitted changes, at Git HEAD `ac5bf17`. The console file has a substantial uncommitted redesign. Preserve that work and the concurrent eSIM, pricing, wallet, and recovery changes. This was a source review, not a run of the latest app or a verification of deployed database state. The executor must reconcile local migrations with the target environment before implementation and release.

Product requirements:

1. Remove Home/Travel modes as protection controls throughout the app.
2. Keep individual notification, keep-alive refill, custom refill, and insurance choices explicit.
3. Keep SIM insurance visible as the last Protection row, including when disabled or unavailable.
4. Replace Travelling Soon with **Back to Egypt Wizard** for Egyptian lines; use **Back to {country} Wizard** for other line countries.
5. Ask for arrival date, assess existing connectivity, and offer supported data products if needed.
6. Premium receives the best configured price or an eligible included package; Standard receives a smaller configured benefit; Free pays the full published retail price.

Removing modes does **not** mean automatically enabling every paid feature. Existing opt-ins, spending limits, entitlements, manual pauses, and payment authorizations remain meaningful.

## 2. Findings in the current implementation

Paths below are relative to the repository root. Line numbers describe the reviewed snapshot and will move during implementation.

| Area | Evidence | Consequence |
|---|---|---|
| New layout | `lib/features/sim_lines/presentation/screens/sim_line_detail_screen.dart`, around 166–239 | Compact identity is fixed; a single scrolling body contains health, travel, auxiliary cards, protection, actions, and activity. Keep this structure. |
| Mode UI remains | Same file: `_buildCompactIdentityCard`, `_showMoreOptionsMenu` | Identity still shows Home/Travel; overflow still exposes “keep protected at home.” Remove both mode concepts. |
| Travel card is a placeholder | Same file: `_travelPrepArmed`, `_buildTravellingCard`, around 895–1025 | A screen-local boolean shows “Pre-trip Protection Armed.” No arrival date, persistent trip, readiness check, or checkout exists in that card. Its schedule-adaptation copy overstates its actual behaviour. |
| Insurance is separate and conditional | Same file around 218; `widgets/sim_insurance_card.dart:42` | Insurance sits before Protection and returns an empty widget when `protectionPaused` is true. Moving it alone will not meet always-visible behaviour. |
| Local lines start paused | `presentation/controllers/sim_lines_controller.dart`, `addSimLine`, around 142–172 | Creation derives `protectionPaused` from the user's location. Fix creation as well as updates. |
| Location alters protection | `lib/features/geo/controller/geo_controller.dart`, `_syncLineModes`; `domain/line_mode_resolver.dart:65` | Returning to a line's country can pause it unless an exception flag is enabled. The resolver can also overwrite a prior pause on a later location change. |
| Resume alters schedules | `sim_lines_controller.dart`, `applyProtectionPause`, around 619 onward | Resume enables all loaded schedules and moves dates to now plus frequency. Do not reuse this blindly for migration or manual resume. |
| Other mode surfaces exist | `lib/features/geo/ui/geo_screen.dart`, notification preferences, `supabase/functions/detect-country/index.ts` | Global Travel Mode, freeze/resume prompts, and welcome-home text must be changed together. |
| Status presentation needs correction | Protection rows use schedule status alone; absent Auto-notify displays a fabricated 153-day interval and Paused. `domain/sim_line_health.dart:17` returns 100 for paused protection. | Use actual configuration and eligibility; a manual pause is not evidence that the SIM is healthy. |
| Insurance backend already exists | `rescue_policy_provider.dart`, `line_rescue_policy.dart`, `set_line_rescue_policy`, `run_auto_rescue` | Reuse opt-in limits, warning/grace period, rescue history, and wallet handling. `max_usd = 0` means off. |
| Existing eSIM inventory exists | `user_esims_controller.dart`, `data/repositories/esim_go_repository_impl.dart`, `domain/entities/user_esim.dart` | Can inspect account purchases, remaining data, expiry, and sync time. The client entity does not contain country coverage or activation policy, so inventory alone cannot establish readiness for Egypt. |
| Capability is only a boolean | `lib/core/services/esim_capability_service.dart`; Android/iOS channel implementations | False currently also represents errors and unsupported platforms. Hardware support is not proof that the user owns an installed, usable eSIM. |
| Carrier data offers exist | `widgets/manual_refill_bottom_sheet.dart`, especially category/filter code around 731 and 955 | Existing `serviceType == 'data'` offers are a starting point for physical-SIM data bundles. Availability still depends on the actual carrier/provider catalogue. |
| Tier pricing exists locally | September 10 migrations defining `resolve_account_commerce_benefit`, `resolve_esim_offer_price`, `compare_esim_offers`, `request_esim_purchase` | Reuse canonical server-side pricing. These local migration files are untracked in the reviewed snapshot; their presence does not prove deployment. |
| Pricing is not a free-package entitlement | `20260910022000_p4_halo_effect_calling_and_esim.sql` and `20260910022500_p4_update_request_esim_purchase_tier_pricing.sql` | Existing logic adds fees to supplier cost and contains fallback percentages. It does not implement a funded Premium free data allowance. |

## 3. Final Protection Console structure

Keep the compact fixed title/identity and existing bottom navigation. The single scrolling body should contain:

1. Any genuinely actionable risk alert.
2. Health, last recharge, and network verification overview.
3. Compact **Back to {country} Wizard** entry card.
4. Existing applicable forecast/live-activity content, kept compact.
5. **Protection**, one grouped list in this exact order:
   - Auto-notify
   - Keep-alive refill
   - Custom auto-refill
   - **SIM insurance**
6. Quick actions.
7. Security activity.
8. Manage SIM.

Remove the Home/Travel badge. The identity may show the canonical line tier in its place. Do not confuse the bottom navigation's **Home** destination or a country's “home country” metadata with the removed protection modes.

The wizard card uses a button/chevron, never an on/off switch. Suggested initial copy:

> Back to Egypt Wizard
> Set your arrival date and prepare your mobile data.
> Start

After saving a trip, show one concise summary such as “Arriving 20 September · Data needed” with **Continue**. Other states include **Review**, **Processing**, **Data ready**, and **Check connection**. Cancellation returns the card to its initial state. A saved trip must survive app restart.

Do not condition this entry point on a Home/Travel flag or successful location detection. The user must be able to plan before arrival and use it after arrival. A passive country-arrival suggestion may link to it; it must not launch checkout, activate protection, or buy anything automatically.

## 4. Replace location-based protection with explicit choices

### 4.1 Rules

Separate these facts:

- Line identity and origin country.
- User's best-effort current country, for relevant suggestions.
- User's configuration of each protection feature.
- Manual line-wide protection pause, if used.
- Eligibility and operational blockers: entitlement, verification, wallet funds, provider availability, account suspension, and line lifecycle.

Location must not write schedule enabled flags, protection pause flags, recharge history, renewal dates, insurance limits, or payment records.

Retain an explicit **Pause protection / Resume protection** action under Manage SIM. Explain which automated actions it affects. Keep individual feature switches/settings available. Pausing protection should not represent carrier deactivation; avoid treating a resume as fresh proof that a carrier line is active or verified.

An enabled feature can be **Active**, **Paused by you**, **Needs setup**, **Upgrade required**, **Waiting for funds**, or **Unavailable**, depending on actual state. Do not display Active simply because a schedule row exists. Missing schedules show **Not set up**, not Paused or a guessed frequency. Show actual carrier/schedule intervals only.

For new lines, no location-derived pause. Create only the schedules already included and authorized in that line's setup flow. Insurance remains off until explicitly enabled.

### 4.2 Client changes

- Remove mode badge and the `requiresProtectionAtHome` menu control.
- Remove `_syncLineModes` as a protection writer and retire `applyGeoLineMode` / `setRequiresProtectionAtHome` from active UI paths.
- Remove the Global Travel Mode protection switch and location-driven freeze/resume suggestions from the Geo screen and related preferences.
- Keep useful country detection and roaming comparison. Update their descriptions so they no longer instruct users to enable Travel Mode or imply that movement changes renewals.
- Replace `_travelPrepArmed` and all “armed/adapt schedules” copy with the real wizard state.
- Audit dashboard cards, SIM lists, home-screen widgets, notification text, health displays, and schedule sheets for remaining mode dependencies.
- Keep risk/health presentation grounded in known recharge and carrier facts. Show a separate manual-pause indicator; do not produce a perfect health score just because automation is paused. Unknown recharge history stays unknown.
- Apply household/ownership rules to each editable control. In the current redesign several grouped-row callbacks are unconditional; the new UI must not expose a working mutation to a viewer.

### 4.3 Backend and compatibility

Do this before releasing the new UI, so an older client cannot immediately reapply location-based pauses.

1. Inventory all writers/readers of `is_home_mode`, `requires_protection_at_home`, `protection_paused`, `travel_mode_enabled`, schedule status, and `is_active`, including offline synchronization.
2. Disable the existing `GEO_LINE_MODE_SYNC_ENABLED` behaviour and remove it from the new client. A client feature flag is not sufficient protection against already-running or older clients.
3. Introduce a server-authoritative explicit pause operation with ownership checks and an audit record. Reuse `protection_paused` as the compatibility projection if practical, but persist pause provenance and per-feature user intent separately. Suggested reasons: `manual`, `legacy_location`, `legacy_unknown`; operational blocks should remain distinct.
4. Route new manual pause/resume writes through that operation. Prevent direct legacy writes from changing automation intent, using column grants/write sanitization and a documented minimum-compatible-client strategy. Test the existing full-object `updateSimLine` serializer: revoking one column must not break harmless nickname edits.
5. Audit `claim_due_executions`, mini/custom queue triggers, notification processing, `run_auto_rescue`, and their worker entry points. Enforce explicit pause, ownership, entitlement, and operational rules at the server boundary. Remove any geographic eligibility condition. Keep real lifecycle and money guards.
6. Recheck pause/cancellation at the execution claim boundary. Define the behaviour of already-submitted provider transactions: reconcile them to their true outcome; do not claim that a pause can undo a provider purchase already underway.
7. Do not remove legacy columns immediately. Retire them only after old clients, offline queues, serializers, and all readers have been handled.

### 4.4 Existing-line migration

Never run a blanket `protection_paused = false` plus “activate all schedules” update.

Produce a dry-run report classifying each line and schedule:

| Existing state | Migration behaviour |
|---|---|
| Enabled and not paused | Keep enabled; preserve next due date and all limits. |
| Proven location-only pause with prior enabled intent | Restore only the previously enabled features using recorded evidence; preserve explicitly disabled siblings. Record migration provenance. |
| Explicit manual pause or feature disabled by user | Preserve it. |
| Pause origin or prior feature intent cannot be established | Keep current spending state, mark review required, and show a one-time “Review paused protection” flow listing the affected features and next charges. |
| Expired entitlement, suspended account, deleted/inactive line, or failed setup | Preserve the relevant block. Mode removal does not bypass it. |

`is_home_mode = true` alone does not establish why a schedule was paused. Current models do not record a sufficient pause history, so ambiguous cases are expected.

Retain real `last_topup_at`, successful execution history, and carrier validity anchors. Do not reset dates to now plus frequency or manufacture a recharge. Recalculate due dates through the canonical schedule rules using the last real qualifying event.

For already-overdue restored schedules, present/reconcile the next due action once and apply the existing catch-up policy, limits, and authorization. If there is no defined catch-up policy, use the review flow instead of launching a burst of historical purchases. Deduplicate pending executions and warning notifications.

Snapshot affected rows and migration classifications for recovery. Rollback must not blindly undo later user choices, resurrect cancelled purchases, or repeat charges.

## 5. SIM insurance as the last Protection row

Extract the existing insurance content into a details sheet and expose a compact summary row. Reuse `rescuePolicyForLineProvider`, `RescuePolicyController`, `set_line_rescue_policy`, and the established rescue engine.

Always render the row. Visibility is independent of location, tier, whether a policy exists, and manual pause. Availability and edit permission can vary, but the row must explain why.

| State | Row example |
|---|---|
| No policy or zero limit | SIM insurance · Off |
| Enabled and eligible | SIM insurance · On · Up to $5 per rescue |
| Manual line pause | SIM insurance · Paused by you |
| Warning pending | SIM insurance · Action needed |
| Insufficient wallet/limit too low | SIM insurance · Needs attention |
| Carrier unsupported or forecast missing | SIM insurance · Unavailable / Waiting for information |
| Loading or retrieval failure | Stable row with loading or retry state; do not mislabel as Off |

The sheet must show the warning/grace period, maximum total user charge, current status, and rescue history. Allow eligible owners to set a limit or turn insurance off. Match eligibility and access to the backend; do not invent a Premium-only restriction.

Removing or disabling insurance must not imply that all other auto-refills stop. Replace the current broad success copy with “SIM insurance off. Your other refill schedules are unchanged.”

Check pricing against the actual current minimum qualifying top-up, not a guessed dollar fallback. The limit must cover the final relevant charge and currency conversion, if any. Reuse server configuration for grace timing and conditions so UI explanations match the rescue engine.

Normal refill and rescue must share a per-line execution/reconciliation guard: a just-completed qualifying refill should clear the need for rescue, and concurrent jobs must not both buy the same keep-alive event. A separate travel eSIM purchase is not a recharge of the protected physical line.

## 6. Back to {country} Wizard

### Step 1 — Arrival

- Resolve country from the selected SIM's `countryId`, not the account's home country or current IP country.
- For Egypt, title is exactly **Back to Egypt Wizard**; localize the country placeholder for every supported country.
- Ask **When will you arrive in Egypt?** with a date picker. Include **Already arrived** and let the user specify the actual arrival date.
- Optionally ask stay duration or departure date to improve package matching; do not make an irrelevant extra question mandatory.
- Store the arrival as a destination-local calendar date. Store an explicit destination timezone when scheduling reminders; do not let phone timezone changes shift the chosen date.
- Handle invalid dates, timezones, and dates outside provider validity windows. A past date entered through Already arrived is valid; packages that already expired are not.
- If the line country cannot be resolved, ask for correction rather than silently using the first supported country. The current detail screen uses such a fallback and should be corrected here.

### Step 2 — Existing connectivity

Display a short check, then return an evidence-based result. Evaluate separately:

1. **Device support:** supported, unsupported, or unknown, with evidence source.
2. **Known account eSIM:** purchased/issued, installation confirmed or unknown, provider status, destination coverage, remaining data, expiry, activation deadline, and freshness.
3. **Existing local SIM data:** current bundle if the provider can verify it, or explicit user confirmation if it cannot.

An eSIM is usable only when its coverage includes the destination and its data/activation/validity conditions fit the intended arrival. Merely having a QR code, an order, or an eSIM-capable phone is insufficient. Treat an issued but uninstalled package as **Installation needed**; an expired/depleted/non-covering package as **Data needed**; stale or unavailable status as **Could not verify**.

Join account inventory to order/product coverage and activation metadata. Persist an immutable coverage/terms snapshot for new orders; do not depend only on a catalogue row that might disappear. Where historical coverage is missing, fetch it from a supported provider or show uncertainty.

Refresh provider usage when supported, with a bounded timeout and a visible last-checked timestamp. Do not assume null expiry means unlimited validity or missing status means active; the current repository has optimistic fallbacks that must not decide readiness.

For eSIMs acquired outside KeepSIMs, offer **I already have data** / **I need data** / **I'm not sure**. Confirmation is recorded as user-reported, not verified telemetry. A failed or denied device check must not be interpreted as proof that the user has no eSIM.

Platform constraint: Apple's `supportsCellularPlan()` checks provisioning requirements and explicitly does not check whether an eSIM is installed. Android's active-subscription API returns only subscriptions visible to the caller and requires permission or carrier privileges. Use these as bounded signals, not a promise of universal installed-eSIM detection. See [Apple documentation](https://developer.apple.com/documentation/coretelephony/ctcellularplanprovisioning/supportscellularplan%28%29) and [Android documentation](https://developer.android.com/reference/android/telephony/SubscriptionManager).

Audit the current iOS `CTCellularPlanSupportsEsim()` call and channel initialization against the supported SDK and entitlements; only its call, not a local definition, was found in the reviewed iOS source. Validate on real Android and iOS devices. Do not replace it with another entitlement-dependent API and assume it works for every app. [Apple's provisioning API requirements](https://developer.apple.com/documentation/coretelephony/ctcellularplanprovisioning) explain this limitation.

### Step 3 — Supported data options

| Readiness/device result | Wizard behaviour |
|---|---|
| Suitable existing data is confirmed | Show coverage/expiry and continue to review. Offer optional “Compare more data”; do not force a purchase. |
| Known eSIM needs installation | Show installation instructions and readiness review. A new purchase is optional. |
| No suitable data; eSIM supported | Offer destination-compatible eSIMs and supported carrier data bundles. |
| eSIM unsupported | Offer compatible carrier data bundles for the selected line. |
| eSIM capability unknown | Show a compatibility check path plus supported carrier bundles. Do not label eSIM purchase as verified-compatible. |
| No supported products | Show “No supported data packages available” with retry/carrier guidance and allow saving the trip without purchasing. |

Use existing carrier offers where `serviceType == 'data'` and match carrier, country, line eligibility, and fulfilment provider. A generic airtime refill is not automatically a data bundle; show it only as a clearly labelled alternative if the carrier supports the required conversion/purchase flow.

When both product types are supported, show both with a short reason for the recommendation: price, existing-line convenience, data allowance, and useful validity. Do not hard-code an Egyptian carrier, invent package inventory, or route every user to the same eSIM provider.

Each offer must show destination, product type, provider/carrier, data allowance, speed/fair-use information when supplied, validity, activation trigger, installation/activation deadline, total payable, and tier benefit. Clarify whether the data goes onto the existing number or a separate eSIM.

### Step 4 — Review, payment, and fulfilment

- Show the selected line/destination, arrival date, package, activation timing, benefit, and final total.
- Arrival date does not imply scheduled automatic activation or a scheduled purchase. Explain whether validity starts on purchase, installation, first connection, or a supported future activation date.
- If buying now would expire too early, offer a suitable package or save the trip and offer an optional reminder. Do not promise delayed activation unless the selected provider supports it.
- Use **Pay {amount}**, **Claim included package**, or **Save trip without buying**, as appropriate.
- Revalidate the quote and entitlement server-side at confirmation. If the price or benefits change, show the revised total before charging.
- Reuse existing wallet/payment authentication, provider routing, order-status, delivery, and reconciliation flows. Return a typed purchase outcome to the wizard so it can resume after checkout.
- Keep trip progress separate from order progress. A queued order is **Processing**, not **Ready**. Track pending, successful, failed, refunded, and uncertain provider outcomes accurately.
- Prevent double submission across retries, app restarts, and devices using a server-side idempotency key. The reviewed `request_esim_purchase` interface does not currently accept one; implement the required extension or wrapper.
- Refresh the user's inventory and wizard readiness after successful delivery. Offer install/setup guidance and an optional arrival reminder.
- Saving, completing, editing, or cancelling a trip never pauses or resumes line protection.

## 7. Tier benefits, discounts, and included packages

### 7.1 Benefit source

Default to the existing account commerce model for wizard travel purchases: the highest currently valid tier from the purchaser's **owned** lines. This matches the local `resolve_account_commerce_benefit` approach for eSIMs. Resolve it on the server; do not use a raw badge, client `isPowerUser`, or a household member's paid line as proof of eligibility.

Ordinary protection subscriptions, keep-alive refills, and custom refills retain their existing line-specific entitlements and fee policy. If a carrier data bundle is offered through this wizard, apply the account travel benefit through an explicit product/pricing context; do not silently change all physical-line refill pricing.

| Purchasing account | Required outcome |
|---|---|
| Free | Full published retail price; no tier discount. |
| Standard | Configured lower total than Free for offers advertised with a Standard benefit. |
| Premium | Best configured price, or an included eligible package when an unused funded allowance is available. |

If configured totals are equal, do not claim a discount. Enforce the intended hierarchy when publishing benefit rules. Show savings against the same product's genuine Free retail total, not against supplier cost or an invented crossed-out price.

### 7.2 Server quote contract

Return a quote containing product/provider identity, destination and line compatibility, effective benefit tier, full retail amount, tier-adjusted amount, funded allowance applied, final user charge, currency, price-rule version, expiry, activation terms, and eligibility/refusal reasons. Use decimal/minor-unit money arithmetic.

The purchase uses the validated quote or recomputes and compares it. The client must not submit an authoritative tier, discount, subsidy, or payable amount. Allowance and wallet changes must be atomic with order creation and retries must return the same logical order.

### 7.3 Free Premium package

An included package requires a separate funded allowance or promotion. Reducing the KeepSIMs fee to zero still leaves supplier cost.

Provide configurable policy for eligible tier, countries/providers/products, data/validity limits, maximum funded value, reset period, redemption count, and campaign budget. A missing or unpublished rule means no included-package promise; the rest of the wizard remains usable.

Reserve the benefit once at order creation, finalize on the defined successful fulfilment event, and release on definitive failure/refund according to the policy. An uncertain provider response must be reconciled before allowing another redemption. Include zero-user-charge orders in the normal fulfilment and accounting flow without a fabricated wallet debit. Do not fall back to charging the user when a free allocation fails without a fresh price confirmation.

Use the published fee/benefit configuration as the single source. The current eSIM price resolver treats both missing and zero fees as a signal to substitute hard-coded percentages. Correct this for the new flow: a legitimate published zero fee is valid; missing pricing is not a free package. Ensure list, quote, checkout, and refund amounts agree.

Business values still to configure before commercial release: exact Standard/Premium savings, included package scope and budget, and allowance reset/redemption limits. Implement the configuration, validation, and draft states now; do not invent production prices or block non-pricing development waiting for them.

## 8. Proposed implementation boundaries

Keep the console thin. Suggested new feature folder: `lib/features/return_trip/` with:

- Models for trip plan, connectivity readiness, quote, and order linkage.
- A repository for save/resume/cancel, readiness, quotes, and purchase requests.
- A Riverpod wizard controller containing explicit step/progress state.
- A compact entry card and a dedicated full-screen wizard route, for example `/sim-lines/:id/return-trip`.
- Reusable offer cards and a review step that call existing checkout/fulfilment services.

Extract a reusable Protection row and insurance details sheet instead of growing the existing large detail-screen file further. Keep navigation and localized copy independent of business logic.

Suggested persistent records (reuse existing equivalents where they already exist):

| Record | Minimum purpose/data |
|---|---|
| Return trip | Owner, selected line, country snapshot, arrival local date, timezone, optional departure/duration, progress, readiness source/time, selected product reference, linked order, timestamps/version. |
| Readiness result | Supported/unsupported/unknown capability and evidence; existing-product suitability and freshness; user-reported override. Avoid copying activation secrets. |
| Benefit policy | Versioned, published rules and funded package limits. |
| Benefit redemption | Beneficiary, policy/window, reserved/consumed/released state, order, idempotency/uniqueness constraints. |
| Explicit protection intent/audit | Manual pause origin and each feature's prior enabled intent, sufficient to resume only what should run. |

For the first version, allow one active return-trip draft per owner and line; reopening resumes it. A new trip after completion gets a new identity. Editing a trip must not mutate an already-paid product or consume a fresh allowance accidentally.

Suggested server operations: save/cancel return trip, get connectivity readiness, quote supported return-trip offers, purchase/claim a quoted offer, and explicitly pause/resume protection. Names are proposals, not existing APIs. Extend existing commerce operations where this avoids duplicated engines.

Derive purchaser identity from authentication, check selected-line access and ownership at each operation, and keep wallet/benefit writes server-only. A household viewer may see permitted line status, but must not receive another person's trip details, eSIM QR/activation credentials, wallet, or tier benefits. For this version, create/claim wizard purchases in the owner's account; do not infer permission to charge a household owner's wallet.

Apply explicit grants and owner-scoped row policies to exposed trip and benefit records; test both allowed and denied access. Supabase requires both appropriate grants and row-level policies, not authentication alone. [Supabase RLS documentation](https://supabase.com/docs/guides/database/postgres/row-level-security).

Keep country detection informational. Update `detect-country` welcome copy to offer the relevant wizard instead of unfreezing lines. Match a suggestion to an owned line's origin country, not only `profiles.home_country_code`. Debounce repeat prompts and do not create duplicate trips for multiple lines in the same country. Unknown location, VPN results, or denied permissions must not block manual wizard entry.

## 9. Delivery sequence

| Phase | Deliverables | Exit condition |
|---|---|---|
| 0. Baseline | Inspect current diff, applicable instructions, deployed migrations/functions, pricing rules, carrier data inventory, and platform capabilities. Record existing test failures separately. | Agreed contracts and a concrete affected-file list; no unrelated executor work overwritten. |
| 1. Protection independence | Explicit pause semantics, new-line defaults, server guards, old-client strategy, location-writer removal, and migration dry run. | Enabled secondary-line protection works in its own country; manual/off choices survive movement and migration. |
| 2. Console and insurance | Remove mode UI, truthful statuses, last-row insurance and details sheet, permission checks, localized strings. | Compact layout preserved and insurance always discoverable. |
| 3. Persistent wizard | Dynamic country title, arrival step, save/resume/cancel, readiness checks and all fallback branches. | Wizard works across restart, unknown capability, existing data, and unsupported destinations. |
| 4. Data commerce | eSIM/carrier data adapters, authoritative tier quotes, existing checkout integration, included-package policy and redemption, idempotency. | Supported paid and included journeys reconcile correctly without double charges or claims. |
| 5. Validation and staged release | Regression tests, device/screenshots, migration rehearsal, operational counters, owner-configured commercial values. | Acceptance matrix passes; any unavailable provider/platform path is labelled accurately. |

Release protection independence and insurance ahead of the commercial wizard if pricing/provider configuration is pending. Keep the unfinished purchase path behind its own feature flag. Do not advertise an unavailable free benefit. Once released, disabling the wizard must not re-enable location-based protection changes.

## 10. Acceptance tests

### Protection and migration

1. An Egyptian secondary line with enabled keep-alive/custom refill stays eligible in Egypt and after moving abroad; opening/resuming the app does not change its schedule.
2. Adding a local line does not automatically pause protection or enable unselected paid features.
3. Unknown location, repeated detections, VPN country changes, and disabled geo suggestions never alter protection.
4. Manual line pause remains paused after travel; resume preserves a separately disabled schedule and real recharge/next-due history.
5. Migration restores only proven location-paused enabled features. Manual and ambiguous cases do not start spending. Re-running migration is idempotent.
6. Old-client writes and offline replay cannot reintroduce geographic pauses or overwrite a newer explicit choice.
7. Overdue schedules do not create duplicate historical purchases. Pause/claim/provider-response races reconcile correctly.
8. Ordinary scheduled refill and insurance rescue cannot both execute the same required keep-alive recharge concurrently.
9. Health does not become 100 because protection was paused; absent Auto-notify does not display a made-up interval.

### Insurance and layout

10. Insurance is exactly the fourth Protection row for Free, Standard, Premium, paused, loading, off, and unavailable states.
11. Limits, grace period, wallet constraints, warnings, disable action, and rescue history remain correct. Disabling insurance leaves other schedules unchanged.
12. Viewers cannot mutate protection or insurance through UI or direct API calls.
13. Small screens, large text, light/dark theme, Arabic RTL, and phone-number LTR display remain usable. There is one page scroll area and no content trapped behind the fixed bars.

### Wizard and data

14. Egyptian and non-Egyptian lines use their own country in the title and offers even when the account home country differs. Unknown line country never selects a random destination.
15. Arrival today, future arrival, Already arrived, timezone changes, date edits, draft resume, and cancellation work without protection side effects.
16. Covering eSIM with data, non-covering eSIM, expired/depleted eSIM, uninstalled order, stale usage, externally purchased data, and unknown capability each follow the correct branch.
17. An unsupported-eSIM device receives compatible carrier data offers; when both are supported the user can compare both; no products allows saving without payment.
18. A package that starts validity before arrival is clearly explained and is not falsely scheduled for arrival activation.

### Pricing, fulfilment, and permissions

19. Free, Standard, and Premium quotes follow published policy. An expired paid entitlement is re-evaluated and a household member's line does not lend benefits.
20. List, checkout, final charge, and refunds agree; published zero app fee remains zero; missing pricing never becomes a free package.
21. Premium allowance remaining/exhausted, provider exclusions, budget exhaustion, concurrent claims, repeated clicks, app restarts, and multiple devices do not produce double redemption.
22. Zero-charge included orders fulfil without a user debit. Failed or uncertain orders reconcile the allowance and wallet correctly without silently converting to paid orders.
23. Tampered tier/price/line/order identifiers and cross-account access are rejected server-side. Quote changes require fresh user confirmation.
24. Delivery updates trip readiness only after the appropriate provider/install evidence. A travel eSIM does not reset the protected physical SIM's recharge timer; a local data bundle affects validity only when the carrier's rules explicitly say it qualifies.

Extend the existing focused tests under `test/features/geo`, `test/features/sim_lines`, `test/features/scheduled_topups`, and `test/features/esim`; add wizard tests and database tests under `supabase/tests`. Run formatting, static analysis, affected unit/widget tests, database migration/authorization/concurrency checks, and relevant existing wallet/fulfilment regressions. Verify native capability on real iOS/Android devices and capture the console plus each main wizard branch. Distinguish tested sandbox fulfilment from any untested live provider behaviour.

## 11. Executor handoff requirements

Deliver the implementation with:

- A file/change summary and screenshots of the updated console and wizard.
- New migrations, a dry-run migration classification report, the old-client strategy, and rollback/recovery notes.
- Exact pricing/allowance configuration fields still awaiting business values; no invented production discounts.
- Test results, including existing unrelated failures and platform/provider limitations.
- Evidence that protection is independent of location, insurance is always the last Protection row, and both supported data-product paths are available.

Do not call the task complete after changing labels, moving the insurance widget, or building wizard screens alone. Completion includes persistent state, server protection rules, existing-line migration handling, truthful readiness detection, applicable tier pricing, and reconciled purchase/claim behaviour.
