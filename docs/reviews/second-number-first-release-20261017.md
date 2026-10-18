# Second Number first release — implementation and release gates

Date: 17 October 2026. Status: **implemented locally; not deployed or commercially enabled**.

The user accepted the revised one-provider first release and selected the Number first layout. The requested initial supply-validation countries are the United States and United Kingdom. The earlier executor attachment was assessment material; its deployment instructions and WhatsApp guarantees were not adopted.

## Implemented

- A Number first customer overview with dedicated number cards, verified capability badges, unread counts, billing periods, renewal/release controls, private-notification wording, and number-specific inbox links. English and Arabic text, RTL layouts, narrow screens, and theme-derived colors are supported. Existing SIM diversion setup remains available for legacy calling numbers; it is separate from incoming SMS.
- A receive-only live SMS inbox. Opening a message marks that message read. Users can view the full message and copy a single extracted code candidate. Ambiguous numeric messages do not receive a suggested code. Sender identity is not presented as verified. Resuming the app reloads the stream.
- Telnyx inventory and durable, expiring, owner-bound quotes using current carrier rental/setup costs, published `intelcallfee` rules, and an approved retail floor. The fixed `$1.00` purchase path was removed. Checkout sends only the stored quote identity and explicit renewal choice. Recurrence is labeled **every 30 days**.
- Atomic wallet reservation before the carrier POST. The quote is also the stable order/idempotency identity. An ambiguous request remains reserved and is reconciled by `customer_reference`; the code does not send another order simply because a response was lost. Explicit carrier rejection releases the original hold. Activation requires the exact successful order, exact number, regulatory completion, active carrier resource, and confirmed messaging-profile binding. Capture, ledger insertion and funding provenance occur transactionally using the coordinated funding contract.
- A dedicated incoming-SMS router for signed Telnyx and Twilio callbacks. Known rented numbers, including released/suspended numbers, never fall through to refill commands. Only an explicitly registered refill destination can reach that handler. Routing/persistence errors cause retryable responses. Message rows are owner-readable and client writes are revoked; marking read uses a narrow RPC.
- Generic notifications that contain no message body or OTP. No raw SMS provider payload is stored in the inbox table. Privileged ingestion and billing RPCs have explicit service-only ACLs and body checks.
- Managed-number renewal warnings, one charge per billing anchor, grace recovery after funding, release claims/backoff, and upstream confirmation before the database marks a number released. Carrier identifiers are retained for audit. Failed legacy-number release can look up its existing resource without assuming an identifier.
- A service-authenticated `second-number-lifecycle` Edge Function and a separate scheduler-install script. The worker source under `../backend-sync-wt` was not changed; this release uses the Edge lifecycle path instead of adding a second billing worker.
- `admin_set_second_number_policy(jsonb)` for audited, administrator-checked US/UK pilot publication, plus administrator-only `manage-dids` action `validate_pilot` for read-only account inventory probes. That probe returns capability/cost observations without returning provider credentials or phone numbers.

## Important boundaries

This release sells **incoming SMS**, not new incoming voice service. Carrier voice capabilities are not advertised as an implemented app feature. Existing calling remains separate. Multi-provider purchasing, full incoming-call media bridging, automated voice-OTP capture, outbound SMS, and WhatsApp registration guarantees are not included.

Country policies start empty and disabled. No country, fictitious retail price, or usage allowance is automatically published. Usage text and the subscription floor must be approved together with actual provider costs. This implementation does not levy a hidden per-message fee or claim unlimited messaging. The initial inbox loads the latest 100 messages per number; older-message pagination is a follow-up before offering extended archival history.

Per-user regulatory document onboarding is not implemented in this SMS pilot. Policies can declare only a validated `not_required` identity status. A global policy cannot mark all customers as already approved. If the provider requires end-user identity/address documents for a US or UK number type, keep that inventory disabled until the document workflow is implemented and verified.

Legacy numbers are not silently enrolled in new recurring billing. `lifecycle_managed=false` is the migration default, and existing capability fields remain unknown/false until validated. Their renewal settings show a review state. New purchases explicitly set managed lifecycle. Any legacy enrollment needs confirmed provider identity, accepted billing terms, and a scoped operational change; populating a provider ID alone must not begin billing.

Released numbers cannot be repurchased/reassigned by this implementation. Retained DID identities, assignment timestamps and provider occurrence times prevent stale messages from being attributed to a different rental. Recording retention and arbitrary historical-number deletion are not introduced.

## Key source files

- `supabase/migrations/20261017024520_second_number_inbox_and_lifecycle.sql` — generated with the installed CLI; schema, policies, quote/purchase settlement, inbox routing, managed renewals and releases.
- `supabase/functions/_shared/second-number.ts` — provider/quote adapter, reconciliation, pilot validation and release runner.
- `supabase/functions/manage-dids/index.ts`, `sms-webhook/index.ts`, `second-number-lifecycle/index.ts` — authenticated entry points.
- `lib/features/calling/contract/second_number_contract.dart` — client contract.
- `lib/features/calling/data/models/second_number_models.dart` and generated companions — immutable message/order types.
- `lib/features/calling/presentation/controllers/second_number_controller.dart` — providers and actions.
- `lib/features/calling/presentation/screens/second_number_overview.dart`, `second_number_sms_screen.dart` — customer management/inbox.
- `lib/features/calling/presentation/widgets/buy_virtual_number_sheet.dart` — quote review and pending-order flow.
- `supabase/verification/install_second_number_scheduler.sql` — separately reviewed operational installation; not automatically applied.

## Verification

- Calling feature tests: **102 passed**, including the replacement Number first/inbox/release/error/Arabic tests.
- Focused Flutter analysis of the calling implementation, router and new screen tests: **no issues**.
- Backend/security tests covering the new adapter, signed SMS routing, existing endpoint authentication and secret handling: **50 passed**.
- Focused existing credential-rotation tests for DID search and SMS callbacks: **4 passed**.
- Isolated PGlite tests use the captured production financial tables/functions/ACLs plus the pending coordinated wallet migrations and actual legacy DID table definition. They cover reservation/capture, funding consistency, deduplication, privacy, negative access, renewals, grace recovery and release. No production data was modified by these tests.
- Native PostgreSQL: **13 scenarios passed**, including two independent service-role sessions racing to buy the same quote, legacy billing isolation, and exact catalog/grant checks. The temporary PostgreSQL process and directory were removed after the run.
- Real customer activation, real SMS delivery, provider configuration, background calling, store builds and a production rollout were not claimed.

An exploratory run of the complete older credential-consumer test file also encountered unrelated PayPal/voice fixture failures. This task updated its DID/SMS fixtures for destination routing and published policies, and verified those targeted cases. It does not certify the unrelated credential-consumer fixtures or the project's broader financial release gates.

## US/UK validation result

**Account-specific stock, eligibility and pricing remain unverified.** A read-only inventory probe was attempted through the connected database, keeping the credential inside the server. The database role denied execution of `get_internal_secret`; no credential was returned and no provider number was ordered. The credential boundary was not relaxed or bypassed.

After the matching Edge deployment, an authorized admin can invoke `manage-dids` with `{"action":"validate_pilot"}`. This performs GET inventory probes for US local SMS and UK mobile SMS. Confirm end-user eligibility with the provider separately, test the messaging profile, and obtain actual controlled SMS delivery evidence. Inventory success alone does not establish delivery from banks or other verification services.

The implementation follows Telnyx's documented [number-order correlation/filtering](https://developers.telnyx.com/api-reference/phone-number-orders/list-number-orders) and [number-order creation](https://developers.telnyx.com/api-reference/phone-number-orders/create-a-number-order) contracts. Provider-response fixtures are local test inputs; they are not live account observations.

## Coordinated release sequence

1. Resolve and release the existing wallet/funding security work under its own documented gates. The new migration explicitly checks for the funding-integrity contract. Do not use a bulk migration push: this repository has unrelated pending migrations and known source/runtime drift.
2. Review and apply only the Second Number migration after that dependency. Run `supabase/tests/second_number_contract_tests.sql`, security advisors, and the negative authorization tests against the target environment.
3. Deploy the matching `manage-dids`, `sms-webhook`, and `second-number-lifecycle` sources with the checked-in `verify_jwt` settings. The callback requires provider signatures; internal lifecycle calls require the exact service credential. Do not ship only the Flutter client while its RPCs are absent.
4. Confirm the public signing key, the messaging profile's callback URL, and credential availability through the approved server secret path. Run the admin-only US/UK validation action and the supply/compliance/delivery pilot. Provider purchases require a separately scoped controlled test, not a broad customer rollout.
5. Approve actual retail floors, setup fees, currency and 30-day terms, incoming-SMS cost exposure, retention policy, and provider eligibility. Then publish the validated policy through the admin RPC. Do not enable countries that require unsupported per-user identity onboarding.
6. Store the existing lifecycle service credential in Vault under `second_number_lifecycle_service_key` through an authorized secret-management operation, without copying it into source or public configuration. Review/run the scheduler installation script. It registers a five-minute job and the scheduled-job registry entry.
7. Inspect both pg_cron runs **and** the corresponding `pg_net` HTTP response/Edge logs. A successful enqueue is not proof that the Edge operation succeeded. Monitor orders pending beyond their expected provisioning window, retrying releases, held funds awaiting reconciliation, grace deadlines, and observed provider costs. An unmatched carrier order requires investigation, not an automatic second POST or speculative refund.
8. Roll out the client to a controlled cohort only after the coordinated backend passes. Exercise refresh/reconnect, duplicate purchase taps, insufficient available funds, provider timeouts, identity restrictions, renewal recovery and upstream release. Keep country policies disabled if the pilot or operating checks fail.

No live migration, deployment, cron registration, credential change, customer wallet mutation, provider order, or release was performed by this task.

## Client compatibility correction (17 October)

The emulator initially showed a transient loading error because the local client requested the undeployed `get_second_numbers` and `get_pending_second_number_orders` RPCs. Live catalog inspection confirmed both are absent; API logs at 03:13 UTC showed repeated 404 responses for those exact requests. The deployed `manage-dids` is version 3 and does not implement `get_countries`. The existing `get_user_dids()` RPC is available to authenticated users and filters by `auth.uid()`.

The client now uses `get_user_dids()` only when the new list RPC returns the specific missing-function/schema-cache error `PGRST202`. The optional pending-order list is empty for that same missing-function condition. Permission, authentication, internal database and connectivity errors remain visible. Legacy capability and managed-billing defaults stay unverified/off; the fallback does not enroll numbers in SMS or new recurring billing.

The overview loads published coverage before enabling acquisition. The old Edge Function's exact unsupported `get_countries` response, or an empty published country list, produces the US/UK validation message and disables acquisition. Repository inventory and purchase methods also check published coverage before sending their actions, so the older purchasing endpoint cannot be reached through this release's checkout. Actual network/server failures retain a retry state. Pending-list errors now include an explanation instead of an isolated refresh link. Pull-to-refresh contains errors in the rendered provider state.

This is a local compatibility fix; it does not deploy or enable the SMS service. The coordinated financial, provider-validation and deployment gates above still apply.

Compatibility verification: **117 calling tests passed**, including missing-RPC fallback, retained authorization failures, disabled purchase/inventory paths on the old Edge version, enabled quoted checkout, validation-state rendering, and explained pending-order errors. Focused Flutter analysis reported no issues.

Applied the client correction to the running Android emulator using Flutter attach and a hot restart. Visual inspection confirmed that My Second Numbers now loads its empty validation state, displays the US/UK coverage/pricing message, and disables acquisition without the previous error or isolated refresh link. The backend service itself remains undeployed. The connected database inspection role cannot execute the customer RPC; authenticated runtime verification came from the emulator instead.
