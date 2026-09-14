# Firsty emergency connectivity: executor handoff

Prepared 11 September 2026. This document is an implementation plan, not evidence of live cellular service or an approved Firsty partnership.

## Objective and decision

Build and test a KeepSIMs recovery experience for a user whose main physical SIM has no usable data or prepaid credit. The user should be able to regain enough connectivity to open KeepSIMs and recharge their existing line, and, where general data is enabled, receive WhatsApp messages and use a bank or official carrier app.

Proceed now with an isolated sandbox implementation. Separately validate real cellular connectivity with a real Firsty eSIM. Production availability requires Firsty to approve the relevant product, coverage, funding and operational terms.

Recommended design: sponsored access to KeepSIMs as the recovery entry point, with a separately funded, limited general-data session for other apps. This is a proposed architecture; Firsty must confirm that these products can be combined on the same profile and that a general-data package can be requested while only sponsored access remains.

Firsty advertises access to an approved app without an active data bundle. Its public page does not establish that KeepSIMs, WhatsApp, an arbitrary bank and every carrier app are all covered by one agreement. The page mentions a sandbox, but do not equate that with the public CLI's mock-only environment. [Firsty App Whitelisting](https://www.firsty.app/en/business/products/app-whitelisting)

Firsty also offers ad-, loyalty- and partner-funded connectivity. Funding, quotas, speeds and eligibility for KeepSIMs must come from the partner agreement, not consumer pricing or marketing examples. [Firsty Free Telecom](https://www.firsty.app/business/products/free-telecom)

## What has already been verified

- Firsty CLI 0.1.2 is installed globally on this workstation.
- Sandbox initialization returned authenticated=true and verified=true.
- Region and package catalog calls succeeded.
- A mock eSIM and mock global 1 GB package were ordered; usage returned 1,024 MB remaining.
- These results prove command/API workflow only. They do not produce usable mobile data. Do not present their activation code as an installable live eSIM.
- The CLI is sandbox-only. A live integration uses Firsty's documented HTTP API with separately issued credentials. [CLI setup guide](https://developers.firsty.app/agents.md)

## Preconditions and limits

1. The Firsty eSIM must be installed and prepared while connectivity is available. Cache recovery instructions before the user goes offline. The consumer installation guide requires Wi-Fi; follow the partner's device-specific instructions for the pilot. [Firsty help](https://intercom.help/firstyapp/en/articles/10503784-what-is-firsty-free)
2. The handset must support the required eSIM/dual-SIM combination, accept the provider, and have coverage from a supported network. No signal, airplane mode, an absent profile, and an exhausted bundle are different failures.
3. Do not promise automatic switching. Build user-guided data-line selection first. Apple documents one cellular data network at a time and user selection of the data line. Confirm any automated provisioning/switching against platform entitlements and Firsty's supported integration. [Apple Dual SIM guide](https://support.apple.com/en-us/109317)
4. An offline app cannot request its first package over an unavailable Internet connection. Acceptable recovery paths are: an already usable allowance, a network-provided bootstrap path, or approved sponsored access reaching KeepSIMs and its backend. Otherwise show that Wi-Fi or another working connection is needed.
5. Firsty data does not itself add money to the physical SIM or KeepSIMs wallet. Recharging still requires a funded wallet, payment, or an explicitly funded benefit. Do not introduce user debt in this pilot.
6. Treat bank and carrier app compatibility as a test outcome. Include authentication, redirects and payment challenges. Internet access alone must not be reported as successful login or recharge. Preserve the original SIM for SMS where supported; do not promise SMS OTP delivery if that line is suspended or otherwise unavailable.
7. Consumer Firsty Free is an optional connectivity experiment, not the partner product. Its current help page restricts signup by phone-number country and usage by destination, and says earned data expires after seven days. Oman is absent from the published signup-country list. Verify eligibility rather than assuming local testers qualify. [Firsty Free eligibility](https://intercom.help/firstyapp/en/articles/10503784-what-is-firsty-free)

## Repository integration points

Inspect current code before editing. The working tree already contains unrelated changes, including eSIM pricing and account-benefit work. Preserve them; old handoff documents contain historical state and must not override current code or this task's scope.

- Flutter/Riverpod client; Supabase backend; existing Node workers.
- `lib/core/services/connectivity_service.dart`: currently reduces interface presence to online/offline and starts as online. A cellular interface does not establish usable Internet access.
- `lib/core/services/esim_capability_service.dart`: reuse capability checks, adding unknown/unsupported handling where needed.
- `lib/features/esim/data/repositories/esim_provider_factory.dart`: currently selects `EsimGoRepositoryImpl`.
- `lib/features/esim/domain/repositories/esim_repository.dart`: existing catalog, purchase and eSIM ownership contract.
- `lib/features/esim/presentation/screens/esim_delivery_screen.dart`: inspect for reusable delivery guidance.
- `lib/features/offline_recharge/`: existing offline UI, local pending requests and reconciliation. Extend the recovery entry point without duplicating refill execution.
- `lib/core/services/local_cache_service.dart`: inspect for non-sensitive offline snapshots; use secure storage where appropriate.
- `servers/worker_esim_fulfillment.js`, `servers/worker_esim_catalog.js`: inspect provider and reconciliation patterns before choosing worker versus Edge Function placement.
- `supabase/functions/health/index.ts`: currently combines backend health with fulfillment-worker health. Do not use its aggregate success/failure as the sole Internet-reachability signal.

## Phase 0 — Establish the pilot contract

Create a capability matrix with evidence and unknowns. Record the test country, local network, handset/model/OS, original SIM carrier, intended bank app and carrier app, and funding cap. Unknown markets and budgets block live spend, but do not block local/sandbox development.

Prepare these questions for the owner to send to Firsty; do not send outreach automatically:

- Can you provide a real test eSIM with zero-rated KeepSIMs access and zero general-data balance? Is that separate from the public CLI sandbox?
- Which exact countries/operators support this, including domestic use and long-term residency? Does the user need Firsty's eSIM, or is access possible on their existing carrier SIM under a specific arrangement?
- Can that profile reach our authentication and recharge backend at zero balance, then receive a partner-funded general-data package? What is the activation delay and failure behavior?
- How is traffic classified and approved? Provide requirements for domains, shared hosting, redirects, DNS, TLS, CDNs and third-party dependencies.
- What dependencies can be sponsored for auth, App Check, checkout, 3-D Secure, bank redirects and push? Which are excluded?
- What are the per-profile fees, minimum commitments, data costs, validity/inactivity rules, limits and budget controls? Can data remain dormant until needed?
- What bootstrap path works when there is no allowance? If ads are used, how do the ad and reward requests work from zero balance?
- What installation methods, SDKs, platform entitlements, profile state events and supported switching flows are available?

Deliver `doc/FIRSTY_PILOT_CAPABILITIES.md`. Label each entry confirmed, proposed or unknown. Never invent a whitelisting endpoint.

## Phase 1 — Connectivity state and offline recovery UI

Implement a recovery-specific model that tracks separately:

- Network interface availability.
- KeepSIMs endpoint reachability: unknown, reachable, unreachable, service error.
- Backend-authorized entitlement: none, sponsored access, general-data allowance, expired or unknown.
- Provisioning state: not prepared, pending installation, installation reported, verified or failed.

Use a small uncached HTTPS probe to an approved KeepSIMs endpoint, check the expected response, bound timeouts and retries, and probe on foreground/resume and relevant network changes. Distinguish received HTTP errors from transport failure. A failed arbitrary Internet probe must not prevent access to a working zero-rated KeepSIMs backend. Do not infer the active SIM, balance exhaustion or access to all other apps from this probe.

Audit existing consumers of the online/offline boolean before changing it. Prefer an additive service if changing shared behavior would disrupt current flows. Cancel listeners and pending work correctly.

Add a cached “Get connected” screen reachable without login refresh or remote configuration. Include preparation status, offline installation/switching instructions, Retry connection, and the existing offline refill options. Account-specific cached information must be isolated per account and cleared on logout.

Use accurate status text: “KeepSIMs is reachable”, “Select your backup eSIM for mobile data”, “Setup requires a connection”, or “Sandbox demonstration”. Never mark installation complete from an order response or mark a recharge successful from a button tap.

Cache essential assets and fonts. Recovery must not depend on ads, analytics, video, remote images or push delivery. Login and money actions still require their normal server authorization.

Deliverable: a local demo of prepared/unprepared, connected/restricted/unreachable and expired-session flows.

## Phase 2 — Firsty sandbox adapter and lifecycle

Build a server-side provider adapter with explicit mock, Firsty sandbox and disabled-live configurations. Keep existing eSIM sales routing intact. Use a separate recovery service if the retail repository contract would force sponsored connectivity into a wallet purchase.

- Keep Firsty client secrets and bearer tokens in backend secrets; never in Flutter, logs or source control. [Supabase secrets](https://supabase.com/docs/guides/functions/secrets)
- Verify Firsty's current OpenAPI contract before implementing operations; use opaque provider identifiers and supported idempotency keys. The reference documents OAuth client credentials, idempotency and signed webhooks. [Firsty API reference](https://developers.firsty.app/api-reference)
- Use the CLI for development smoke tests only. Do not shell out to it from the mobile app or depend on its implicit last-ordered-eSIM state for multi-user requests.
- Persist explicit user/profile/package mappings, environment, request id, lifecycle state, timestamps and failure details. Minimize storage of activation material and restrict its delivery to the owner.
- Enforce ownership in backend operations and database policies. Test cross-user access. No client-writable provider references, sponsorship grants or fulfillment states.
- Make provisioning and allowance requests idempotent, including concurrent taps, retry after timeout and app restart. Reconcile an unknown provider result before creating another order. Retain local deduplication beyond any provider idempotency expiry.
- Treat purchase, installation, enablement, attachment and actual traffic as distinct evidence. Simulate unavailable events explicitly. Verify webhook signatures and deduplicate events only when integrating a documented webhook environment.
- Keep sandbox records separate from live records. Sandbox flows must never debit real wallets or execute real carrier recharges.

Suggested internal operations: get recovery status, prepare backup profile, request a recovery allowance, refresh fulfillment status. These are KeepSIMs API design names, not claims about Firsty's endpoint names.

Use Firsty CLI `--help` and the setup guide for smoke commands. Reuse existing initialization; select plans from the current catalog rather than hardcoding the mock plan previously used.

Deliverable: authenticated sandbox flow through KeepSIMs, with redacted evidence and automated lifecycle/ownership tests. Do not call it a cellular proof of concept.

## Phase 3 — Recharge and sponsorship behavior

When KeepSIMs is reachable, reuse the existing authoritative refill path and wallet controls. Reconcile an existing pending offline request before allowing an equivalent new request; recovery must not execute a refill twice.

For the proposed general-data benefit, enforce eligibility, per-user limits, total partner spend limits and a kill switch on the server. Keep allowances and their exact sizes configurable pending Firsty's commercial terms. Zero wallet balance must not prevent access to free recovery guidance; it must not silently authorize a paid refill.

Inventory every client-side request in cold launch, session refresh, wallet load, checkout and refill completion. Record domain, purpose, redirects, whether essential, and behavior when blocked. Include Supabase auth/functions/data, actual payment providers, App Check and required assets. Backend-to-provider calls are server traffic and are a separate dependency.

If bank/carrier checkout cannot work on the approved domain set, require general data for that path or offer a tested supported alternative. Do not proxy arbitrary websites through KeepSIMs to evade the sponsored traffic policy.

Deliverable: dependency inventory and a complete sandbox recharge journey under simulated restricted access. A simulated network allowlist tests app resilience; it does not prove Firsty's network enforcement.

## Phase 4 — Real-phone proof

This phase requires real credentials/profile access and an owner-approved spending cap. Until supplied, finish all sandbox work and report the specific live prerequisites as pending.

First conduct a basic transport trial using a real permitted Firsty allowance. An eligible consumer plan can help test whether the device and apps function over Firsty's data network, but cannot prove partner zero-rating. Then perform a separate Firsty-enabled partner trial with zero general-data balance.

1. While on Wi-Fi, install and verify the real profile and cache recovery instructions. Record network, device, OS and service terms.
2. Turn Wi-Fi off. Keep the original SIM active for relevant voice/SMS tests but use a controlled no-data/no-credit condition. Disabling the primary SIM alone is a preliminary test, not proof of exhaustion behavior.
3. Verify the original data path cannot reach the test endpoint. Select the Firsty data line using documented device instructions; record how the active path was verified.
4. With zero general-data allowance, test cold-start KeepSIMs, session refresh, wallet display, and one permitted recharge path. This is the decisive app-whitelisting test.
5. If contracted, request sponsored general data through that restricted connection. Record request-to-usable-data latency and provider state.
6. With general data, test WhatsApp receipt, bank login and the named official carrier app. Use tester-owned accounts; the owner conducts sensitive authentication and approves any actual payment. Record each app's outcome separately.
7. Test full exhaustion/expiry again with Wi-Fi off. Prove that recovery remains reachable and another permitted recovery request can be made. A preloaded allowance alone does not pass this test.
8. Confirm the physical line's actual recharge result separately from Internet restoration. Test return to the normal data line and app restart.

Also cover unsupported/locked devices, missing/deleted profile, no cellular coverage, captive Wi-Fi, zero wallet balance, expired auth, blocked checkout dependency, slow connection, provider timeout and duplicate requests. Test both supported Android and iPhone devices before making a cross-platform claim.

## Acceptance and handoff

- Sandbox: deterministic recovery UI; successful mock provisioning/status; no real charges; no secret exposure; ownership and idempotency tests pass.
- Regression: existing eSIM retail purchases, wallet/refill controls and offline request reconciliation remain correct.
- Basic live trial: real data reaches the named apps on a documented Firsty connection. This does not establish sponsored access.
- Partner trial: KeepSIMs cold-start and recovery work with no general allowance, then the agreed general-data benefit works from that state. Repeat after expiry/exhaustion.
- Record pass/fail/not tested per device, network, product and app, with timestamps and redacted evidence. Missing partner prerequisites are “not tested”, never “passed”.

Deliver a reviewable implementation, focused Flutter/backend/database tests, the capability matrix, dependency inventory, and `doc/FIRSTY_PILOT_TEST_RESULTS.md`. Run analysis and relevant existing suites; report failures and unrelated baseline failures separately. Do not modify production data, publish the feature, buy live service or contact Firsty as part of the sandbox implementation.

Start with Phases 0–3. Complete all work that does not depend on Firsty's live service. Enable production only after the owner reviews the real-phone results and approves the commercial terms.
