# KeepSIMs Database Documentation & Architecture Reference

**System:** KeepSIMs Platform (Supabase PostgreSQL Database)  
**Version:** Production Schema (Migrations G1–J8)  
**Last Updated:** August 2026  

---

## 1. Overview & Architecture

The KeepSIMs database is built on **Supabase PostgreSQL** and powers automated SIM card line preservation, eSIM procurement, international roaming comparison, multi-provider top-up execution, and household balance management.

### Key Architectural Principles
1. **Security & Role-Based Access Control (RLS):** All tables have Row Level Security (RLS) enabled. Sensitive tables (e.g., `wallets`, `device_money_events`, `admin_audit_log`, wholesale supplier caches) are strictly locked down (deny-all to client roles, accessible only via security-definer RPCs or `service_role`).
2. **Financial Integrity & Double-Entry Ledger:** All wallet operations go through transactional RPCs (`credit_wallet_for_deposit`, `credit_wallet_for_refund`, `debit_wallet_for_topup`). Client direct writes to `wallets` or `wallet_transactions` are revoked.
3. **Multi-Carrier & Multi-Supplier Routing:** Telecom carriers are mapped to multiple fulfillment suppliers (`zendit`, `ding`, `dtone`, `reloadly`, direct scripts) via `carrier_provider_map` and `supplier_policy`, allowing best-price selection and failover.
4. **Risk & Anti-Fraud Engine:** Device risk scoring (`assess_device_risk`, `guard_money_action`) tracks device footprints, velocity limits, and money events to prevent abuse.

---

## 2. Table Specifications & Schema Directory

---

### Domain 1: User Accounts & Profiles

#### 1. `public.profiles`
* **Role & Purpose:** Holds user profile information, authentication link (`auth.users`), app metadata claims (`is_power_user`, `is_suspended`), and subscription tier.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Links to `auth.users.id`.
  - `email` (`text`, NOT NULL): User's primary email address.
  - `full_name` (`text`, NULLABLE): User's display name.
  - `phone` (`text`, NULLABLE): Contact phone number.
  - `avatar_url` (`text`, NULLABLE): Profile image URL.
  - `subscription_tier` (`text`, DEFAULT `'standard'`): Subscription tier (`standard` or `premium`).
  - `is_power_user` (`boolean`, DEFAULT `false`): Admin privileges flag (protected from client modification by trigger & REVOKE).
  - `is_suspended` (`boolean`, DEFAULT `false`): Account suspension flag.
  - `referral_code` (`text`, UNIQUE): User's unique referral code for the Refer-and-Earn system.
  - `referred_by` (`uuid`, NULLABLE): `profiles.id` of the user who referred them.
  - `created_at` (`timestamptz`, DEFAULT `now()`): Profile creation timestamp.
  - `updated_at` (`timestamptz`, DEFAULT `now()`): Last profile update timestamp.

#### 2. `public.user_preferences`
* **Role & Purpose:** Stores user interface settings, notification defaults, and currency display preferences.
* **Columns:**
  - `user_id` (`uuid`, PRIMARY KEY): FK to `profiles.id`.
  - `display_currency` (`text`, DEFAULT `'USD'`): Preferred display currency (ISO 4217 code).
  - `language_code` (`text`, DEFAULT `'en'`): Preferred app language.
  - `theme_mode` (`text`, DEFAULT `'system'`): Visual theme preference (`light`, `dark`, `system`).
  - `created_at` (`timestamptz`, DEFAULT `now()`): Creation timestamp.
  - `updated_at` (`timestamptz`, DEFAULT `now()`): Modification timestamp.

#### 3. `public.user_consents`
* **Role & Purpose:** Tracks GDPR / privacy legal consent acknowledgments (Terms of Service, Privacy Policy).
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Unique consent record ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `terms_version` (`text`, NOT NULL): Version of terms agreed to.
  - `privacy_policy_version` (`text`, NOT NULL): Version of privacy policy agreed to.
  - `agreed_at` (`timestamptz`, DEFAULT `now()`): Timestamp of agreement.
  - `ip_address` (`text`, NULLABLE): IP address at the time of agreement.

#### 4. `public.account_deletions`
* **Role & Purpose:** State machine tracking user account deletion requests, grace period freezes, wallet draining, and GDPR purging.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Record ID.
  - `user_id` (`uuid`, NULLABLE): FK to `profiles.id` (set NULL once auth is purged).
  - `email_hash` (`text`, NOT NULL): Anonymized hash of user email for audit logs.
  - `status` (`text`, DEFAULT `'requested'`): State (`requested`, `frozen`, `drained`, `purged`).
  - `wallet_balance_at_request` (`numeric`, DEFAULT `0.00`): Wallet balance when deletion requested.
  - `dust_forfeited` (`boolean`, DEFAULT `false`): True if user forfeited remaining micro-balances.
  - `reason` (`text`, NULLABLE): Deletion reason provided by user.
  - `actor_id` (`uuid`, NULLABLE): Admin ID if admin-initiated.
  - `requested_at` (`timestamptz`, DEFAULT `now()`): Request timestamp.
  - `scheduled_purge_at` (`timestamptz`, NOT NULL): Timestamp when hard purge executes.
  - `frozen_at` / `drained_at` / `purged_at` / `auth_deleted_at` (`timestamptz`): Lifecycle milestone timestamps.

---

### Domain 2: SIM Line Management & Protection

#### 5. `public.sim_lines`
* **Role & Purpose:** The core entity representing a user's physical or electronic SIM card line registered for auto-refill protection.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Line ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `phone_number` (`text`, NOT NULL): Full international phone number (E.164 format).
  - `carrier_id` (`uuid`, NOT NULL): FK to `carriers.id`.
  - `iccid` (`text`, NULLABLE): SIM card ICCID number (19-20 digits).
  - `nickname` (`text`, NULLABLE): User-assigned label (e.g., "Mom's Saudi Line").
  - `status` (`text`, DEFAULT `'active'`): Status (`active`, `paused`, `expired`, `pending_verification`).
  - `last_topup_at` (`timestamptz`, NULLABLE): Date/time of the last top-up refill.
  - `next_scheduled_topup` (`timestamptz`, NULLABLE): Next planned automated refill date.
  - `health_score` (`integer`, DEFAULT `100`): Computed line health (0-100) based on refill proximity.
  - `auto_refill_enabled` (`boolean`, DEFAULT `true`): Auto-refill toggle for standard/premium protection.
  - `created_at` (`timestamptz`, DEFAULT `now()`): Registration date.
  - `updated_at` (`timestamptz`, DEFAULT `now()`): Last modified date.

#### 6. `public.line_activity_log`
* **Role & Purpose:** Immutable audit trail of events happening on a SIM line (refills, status updates, rule checks, warnings).
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Event ID.
  - `sim_line_id` (`uuid`, NOT NULL): FK to `sim_lines.id`.
  - `event_type` (`text`, NOT NULL): Event category (`topup_success`, `topup_failed`, `rescue_warn`, `rule_update`).
  - `description` (`text`, NOT NULL): Human-readable event detail.
  - `metadata` (`jsonb`, DEFAULT `'{}'`): Contextual payload (provider responses, transaction IDs).
  - `created_at` (`timestamptz`, DEFAULT `now()`): Timestamp.

#### 7. `public.sim_line_usage_forecast`
* **Role & Purpose:** Predictive depletion model predicting when a line will deactivate based on carrier rules and activity history.
* **Columns:**
  - `sim_line_id` (`uuid`, PRIMARY KEY): FK to `sim_lines.id`.
  - `predicted_deactivation_date` (`date`, NOT NULL): Calculated risk date.
  - `suggested_refill_date` (`date`, NOT NULL): Recommended refill date before deactivation.
  - `confidence_score` (`numeric`, NOT NULL): Model confidence rating (0.0 to 1.0).
  - `computed_at` (`timestamptz`, DEFAULT `now()`): Calculation timestamp.

#### 8. `public.sim_line_rescue_policy`
* **Role & Purpose:** Holds "SIM Insurance / Auto-Rescue" configuration per line. Prevents SIM loss if standard refills fail.
* **Columns:**
  - `sim_line_id` (`uuid`, PRIMARY KEY): FK to `sim_lines.id`.
  - `max_usd` (`numeric`, DEFAULT `0.00`): Max emergency refill budget ($0 = disabled).
  - `lead_days` (`integer`, DEFAULT `2`): Days before deactivation to trigger auto-rescue.
  - `warn_lead_days` (`integer`, DEFAULT `3`): Days before deactivation to warn user.
  - `last_warned_at` (`timestamptz`, NULLABLE): Last warning timestamp.
  - `created_at` / `updated_at` (`timestamptz`): Audit timestamps.

---

### Domain 3: Financial Ledger, Wallets & Payment Processing

#### 9. `public.wallets`
* **Role & Purpose:** User balance repository. Client direct updates are revoked; updated only via security-definer financial RPCs.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Wallet ID.
  - `user_id` (`uuid`, UNIQUE, NOT NULL): FK to `profiles.id`.
  - `balance` (`numeric`, DEFAULT `0.00`): Current available USD balance.
  - `total_deposited` (`numeric`, DEFAULT `0.00`): Lifetime aggregate USD deposits.
  - `total_spent` (`numeric`, DEFAULT `0.00`): Lifetime aggregate USD spent.
  - `currency` (`text`, DEFAULT `'USD'`): Primary wallet currency.
  - `created_at` / `updated_at` (`timestamptz`): Audit timestamps.

#### 10. `public.wallet_transactions`
* **Role & Purpose:** Immutable double-entry financial ledger for all wallet credits, debits, refills, refunds, and gifts.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Transaction ID.
  - `wallet_id` (`uuid`, NOT NULL): FK to `wallets.id`.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `amount` (`numeric`, NOT NULL): Signed amount (positive for credits, negative for debits).
  - `transaction_type` (`text`, NOT NULL): Ledger type (`deposit`, `topup_debit`, `refund`, `gift_credit`, `plan_fee`, `admin_adjustment`).
  - `description` (`text`, NOT NULL): Description of transaction.
  - `reference_id` (`text`, NULLABLE): Idempotency & order reference (e.g. PayPal Order ID, Exec ID).
  - `sim_line_id` (`uuid`, NULLABLE): FK to `sim_lines.id` if associated with a line.
  - `metadata` (`jsonb`, DEFAULT `'{}'`): Arbitrary payment metadata.
  - `created_at` (`timestamptz`, DEFAULT `now()`): Transaction creation timestamp.

#### 11. `public.payment_methods`
* **Role & Purpose:** Saved payment methods (e.g., PayPal Billing Agreements, Tokens) for automated charges.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Method ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `provider` (`text`, NOT NULL): Payment provider (`paypal`, `stripe`).
  - `token` (`text`, NOT NULL): Secure vault token.
  - `is_default` (`boolean`, DEFAULT `false`): Default payment method flag.
  - `created_at` (`timestamptz`, DEFAULT `now()`): Creation date.

#### 12. `public.paypal_orders`
* **Role & Purpose:** Log of PayPal payment orders created for wallet deposits or plan purchases.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): PayPal Order ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `amount_usd` (`numeric`, NOT NULL): Deposit/purchase net amount.
  - `paypal_fee_usd` (`numeric`, NOT NULL): Computed PayPal fee.
  - `total_charge_usd` (`numeric`, NOT NULL): Gross charge billed to PayPal.
  - `status` (`text`, DEFAULT `'CREATED'`): Status (`CREATED`, `APPROVED`, `COMPLETED`, `FAILED`, `REFUNDED`).
  - `reference_id` (`text`, NULLABLE): Custom client reference.
  - `raw_response` (`jsonb`, NULLABLE): Raw payload from PayPal API.
  - `created_at` / `updated_at` (`timestamptz`): Timestamps.

#### 13. `public.plan_payments`
* **Role & Purpose:** Tracks paid subscription plan fees (Standard / Premium) for entitlement verification.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Plan payment ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `sim_line_id` (`uuid`, NULLABLE): FK to `sim_lines.id`.
  - `plan_tier` (`text`, NOT NULL): Plan level (`standard`, `premium`).
  - `amount_paid_usd` (`numeric`, NOT NULL): Amount charged.
  - `valid_from` (`timestamptz`, NOT NULL): Coverage start date.
  - `valid_until` (`timestamptz`, NOT NULL): Coverage expiration date.
  - `reference_id` (`text`, UNIQUE): Transaction reference.
  - `created_at` (`timestamptz`, DEFAULT `now()`): Creation date.

---

### Domain 4: Refill Execution Engine & Provider Offers

#### 14. `public.scheduled_topups`
* **Role & Purpose:** Defines the recurring refill schedule for a SIM line.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Schedule ID.
  - `sim_line_id` (`uuid`, NOT NULL): FK to `sim_lines.id`.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `amount` (`numeric`, NOT NULL): Target top-up value in USD.
  - `interval_days` (`integer`, NOT NULL): Days between scheduled executions.
  - `next_execution_date` (`timestamptz`, NOT NULL): Next trigger time.
  - `is_active` (`boolean`, DEFAULT `true`): Active status.
  - `offer_id` (`text`, NULLABLE): Specific provider offer ID pinned to schedule.
  - `created_at` / `updated_at` (`timestamptz`): Timestamps.

#### 15. `public.topup_executions`
* **Role & Purpose:** Queue and execution records for individual refill attempts. State machine: `pending` -> `claimed` -> `processing` -> `completed` / `failed`.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Execution ID.
  - `sim_line_id` (`uuid`, NOT NULL): FK to `sim_lines.id`.
  - `scheduled_topup_id` (`uuid`, NULLABLE): Associated schedule ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `amount` (`numeric`, NOT NULL): Refill amount.
  - `status` (`text`, DEFAULT `'pending'`): State machine status.
  - `execution_type` (`text`, DEFAULT `'scheduled'`): Type (`scheduled`, `instant`, `offline`, `rescue`, `manual`).
  - `api_provider` (`text`, NULLABLE): Supplier handling refill (`zendit`, `ding`, `dtone`, `reloadly`, `script`).
  - `provider_tx_id` (`text`, NULLABLE): Supplier reference transaction ID.
  - `retry_count` (`integer`, DEFAULT `0`): Execution retry counter.
  - `error_message` (`text`, NULLABLE): Failure log snippet.
  - `claimed_at` / `executed_at` / `completed_at` (`timestamptz`): Timing markers.

#### 16. `public.provider_offers_cache`
* **Role & Purpose:** Cached wholesale top-up offers fetched from telecom aggregators.
* **Columns:**
  - `id` (`text`, PRIMARY KEY): Unique offer key (e.g., `zendit_sa_stc_50`).
  - `provider` (`text`, NOT NULL): API aggregator code.
  - `carrier_id` (`uuid`, NULLABLE): FK to `carriers.id`.
  - `offer_name` (`text`, NOT NULL): Title of package.
  - `price_type` (`text`, NOT NULL): `fixed` or `range`.
  - `wholesale_price_usd` (`numeric`, NOT NULL): Direct supplier wholesale cost.
  - `retail_price_usd` (`numeric`, NOT NULL): Calculated retail price for user.
  - `send_value` (`numeric`, NOT NULL): Denomination credited to SIM card in local currency.
  - `send_currency` (`text`, NOT NULL): Local currency code (e.g., `SAR`).
  - `is_active` (`boolean`, DEFAULT `true`): Active offer flag.
  - `refreshed_at` (`timestamptz`, DEFAULT `now()`): Cache refresh timestamp.

#### 17. `public.offer_price_history`
* **Role & Purpose:** Append-only log of price changes in provider & eSIM offers (written by triggers). Deny-all RLS.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Log ID.
  - `offer_id` (`text`, NOT NULL): Offer reference ID.
  - `provider` (`text`, NOT NULL): Supplier code.
  - `price_usd` (`numeric`, NOT NULL): Recorded price point.
  - `recorded_at` (`timestamptz`, DEFAULT `now()`): Recording timestamp.

#### 18. `public.offer_price_watches`
* **Role & Purpose:** Per-user price watch registrations to notify users when top-up/eSIM prices drop.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Watch ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `sim_line_id` (`uuid`, NULLABLE): Linked SIM line.
  - `country_code` (`text`, NULLABLE): Destination country code.
  - `origin` (`text`, DEFAULT `'user'`): Creation origin (`user` or `auto`).
  - `target_price_usd` (`numeric`, NULLABLE): User target price.
  - `last_best_usd` (`numeric`, NOT NULL): Last observed lowest retail price.
  - `created_at` / `updated_at` (`timestamptz`): Audit timestamps.

#### 19. `public.refill_scripts`
* **Role & Purpose:** Defines automated scripts for carriers requiring direct web/gateway interactions.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Script ID.
  - `carrier_id` (`uuid`, NOT NULL): FK to `carriers.id`.
  - `name` (`text`, NOT NULL): Script title.
  - `script_kind` (`text`, NOT NULL): Automation engine type.
  - `fixed_amount_usd` (`numeric`, NULLABLE): Fixed price amount.
  - `is_enabled` (`boolean`, DEFAULT `false`): Enable flag.
  - `max_daily_executions` (`integer`, DEFAULT `50`): Daily quota guard.
  - `runner_id` (`text`, NULLABLE): Identified execution worker instance.
  - `last_heartbeat_at` (`timestamptz`, NULLABLE): Worker heartbeat timestamp.

#### 20. `public.supplier_policy`
* **Role & Purpose:** Dynamic supplier selection policies, risk premiums, and global kill-switches.
* **Columns:**
  - `provider` (`text`, PRIMARY KEY): Supplier identifier (`zendit`, `ding`, `dtone`, `reloadly`).
  - `is_globally_enabled` (`boolean`, DEFAULT `true`): Operator kill-switch.
  - `risk_premium_percent` (`numeric`, DEFAULT `0.00`): Artificial penalty percentage for routing score.
  - `flat_penalty_usd` (`numeric`, DEFAULT `0.00`): Flat penalty fee for routing score.
  - `success_count` / `failure_count` (`integer`, DEFAULT `0`): Historical performance metrics.
  - `last_failure_at` (`timestamptz`, NULLABLE): Time of latest failure.

---

### Domain 5: Telephony Carriers, Rules & Routing

#### 21. `public.countries`
* **Role & Purpose:** Master country database with ISO codes, dialing codes, and fallback server configurations.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Country ID.
  - `name` (`text`, NOT NULL): Country name.
  - `iso_code` (`text`, UNIQUE, NOT NULL): 2-letter ISO code (e.g., `SA`, `EG`, `US`).
  - `dialing_code` (`text`, NOT NULL): Telephony prefix (e.g., `+966`).
  - `flag_emoji` (`text`, NULLABLE): Flag representation.
  - `currency_code` (`text`, NOT NULL): National currency code.
  - `is_supported` (`boolean`, DEFAULT `true`): Operational flag.

#### 22. `public.carriers`
* **Role & Purpose:** Master list of mobile network operators (MNOs) globally.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Carrier ID.
  - `country_id` (`uuid`, NOT NULL): FK to `countries.id`.
  - `name` (`text`, NOT NULL): MNO name (e.g., `STC`, `Mobily`, `Vodafone`).
  - `logo_url` (`text`, NULLABLE): Carrier branding logo.
  - `default_refill_amount` (`numeric`, DEFAULT `5.00`): System default top-up amount.
  - `fulfillment_gateway` (`text`, DEFAULT `'API'`): Fulfillment mode (`API`, `MANUAL`, `SCRIPT`).
  - `is_supported` (`boolean`, DEFAULT `true`): Active flag.

#### 23. `public.carrier_rules`
* **Role & Purpose:** Telecom expiration rules, inactivity windows, and activity requirements for line safety.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Rule ID.
  - `carrier_id` (`uuid`, UNIQUE, NOT NULL): FK to `carriers.id`.
  - `inactivity_limit_days` (`integer`, NOT NULL): Days before MNO deactivates SIM (drives refill cadence).
  - `grace_period_days` (`integer`, DEFAULT `0`): Additional post-deactivation grace window.
  - `minimum_topup_amount` (`numeric`, NOT NULL): Min top-up amount accepted by MNO.
  - `activity_requirement` (`text`, DEFAULT `'recharge_ok'`): Requirement (`recharge_ok`, `min_denomination`, `usage_required`).
  - `validity_qualifying_topup_amount` (`numeric`, NULLABLE): Threshold for `min_denomination`.
  - `rule_source_url` (`text`, NULLABLE): Reference link to MNO policy document.

#### 24. `public.carrier_provider_map`
* **Role & Purpose:** Mappings between KeepSIMs carriers and supplier specific codes (`zen_carrier`, `ding_carrier`, etc.).
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Mapping ID.
  - `carrier_id` (`uuid`, NOT NULL): FK to `carriers.id`.
  - `provider` (`text`, NOT NULL): Supplier code (`zendit`, `ding`, `dtone`).
  - `provider_country_code` (`text`, NOT NULL): Supplier country code.
  - `provider_carrier_code` (`text`, NOT NULL): Supplier carrier code.
  - `is_enabled` (`boolean`, DEFAULT `false`): Enables supplier for this carrier.
  - `priority` (`integer`, DEFAULT `100`): Routing priority rank.

#### 25. `public.carrier_roaming_rates`
* **Role & Purpose:** Roaming tariffs MNOs charge their own users abroad. Used by the "Roam-or-eSIM" savings calculator.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Rate ID.
  - `carrier_id` (`uuid`, NOT NULL): Home MNO ID (`carriers.id`).
  - `destination_country_code` (`text`, NOT NULL): Target country code (or `*` for global).
  - `product_name` (`text`, NOT NULL): MNO roaming package name.
  - `bundle_data_mb` (`bigint`, NULLABLE): MB allowance.
  - `bundle_days` (`integer`, NULLABLE): Validity duration.
  - `local_price` (`numeric`, NULLABLE): Price in local currency.
  - `bundle_price_usd` (`numeric`, GENERATED): Automatically converted USD cost.

#### 26. `public.carrier_self_service`
* **Role & Purpose:** Official self-service links and USSD dial codes for MNOs where manual top-up is needed.
* **Columns:**
  - `carrier_id` (`uuid`, PRIMARY KEY): FK to `carriers.id`.
  - `app_name` (`text`, NULLABLE): Official app name.
  - `android_url` / `ios_url` / `web_topup_url` (`text`, NULLABLE): Verification-gated official links.
  - `ussd_code` (`text`, NULLABLE): Balance check USSD code (e.g., `*166#`).
  - `verified_at` (`timestamptz`, NULLABLE): Verification timestamp.

#### 27. `public.carrier_ussd_suggestions`
* **Role & Purpose:** Catalog of recommended USSD dial codes for balance inquiry or package activation.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Suggestion ID.
  - `carrier_id` (`uuid`, NULLABLE): FK to `carriers.id`.
  - `plan_name` (`text`, NOT NULL): Package name.
  - `cost` (`numeric`, NOT NULL): Cost.
  - `ussd_code` (`text`, NOT NULL): Dial string.

---

### Domain 6: eSIM Store & Digital Profiles

#### 28. `public.esim_offers_cache`
* **Role & Purpose:** Wholesale catalog of global data eSIM packages from suppliers (e.g., Maya, eSIM Go). Deny-all to clients.
* **Columns:**
  - `id` (`text`, PRIMARY KEY): Offer code.
  - `supplier_code` (`text`, NOT NULL): eSIM supplier.
  - `title` / `description` (`text`): Package descriptions.
  - `countries` (`text[]`, NOT NULL): Array of covered country ISO codes.
  - `data_amount_mb` (`bigint`, NOT NULL): Data volume in MB (0 = unlimited).
  - `duration_days` (`integer`, NOT NULL): Validity period.
  - `wholesale_price_usd` (`numeric`, NOT NULL): Supplier cost.
  - `retail_price_usd` (`numeric`, NOT NULL): Retail selling price.

#### 29. `public.esim_orders`
* **Role & Purpose:** Log of eSIM purchase transactions and provisioning status.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Order ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `offer_id` (`text`, NOT NULL): eSIM offer ID.
  - `amount_usd` (`numeric`, NOT NULL): Total order cost.
  - `status` (`text`, DEFAULT `'pending'`): State (`pending`, `completed`, `failed`, `refunded`).
  - `iccid` (`text`, NULLABLE): Provisioned eSIM ICCID.
  - `activation_code` (`text`, NULLABLE): LPA activation code string (e.g., `LPA:1$...`).
  - `qr_code_url` (`text`, NULLABLE): QR code image rendering URL.

#### 30. `public.user_esims`
* **Role & Purpose:** Active eSIM profiles owned by users, with data usage tracking.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): User eSIM record ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `iccid` (`text`, UNIQUE, NOT NULL): Card ICCID.
  - `title` (`text`, NOT NULL): Package title.
  - `data_remaining_mb` (`bigint`, NULLABLE): Remaining MB balance.
  - `expires_at` (`timestamptz`, NULLABLE): Plan expiration timestamp.
  - `created_at` (`timestamptz`, DEFAULT `now()`): Activation timestamp.

#### 31. `public.esim_usage_samples`
* **Role & Purpose:** Daily snapshots of `user_esims.data_remaining_mb` for burn-rate forecasting.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Sample ID.
  - `user_esim_id` (`uuid`, NOT NULL): FK to `user_esims.id`.
  - `data_remaining_mb` (`bigint`, NOT NULL): Recorded MB balance.
  - `sampled_at` (`timestamptz`, DEFAULT `now()`): Sampling timestamp.

---

### Domain 7: Household Management & Allowances

#### 32. `public.household_members`
* **Role & Purpose:** Family sharing groups where an owner delegates wallet balance spending limits to members.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Membership ID.
  - `owner_id` (`uuid`, NOT NULL): FK to `profiles.id` (Head of household).
  - `member_id` (`uuid`, NULLABLE): FK to `profiles.id` (Claimed family member).
  - `member_email` (`text`, NOT NULL): Invited email.
  - `role` (`text`, DEFAULT `'viewer'`): Privilege level (`manager` or `viewer`).
  - `monthly_cap_usd` (`numeric`, DEFAULT `0.00`): Monthly wallet spending limit.
  - `per_txn_cap_usd` (`numeric`, NULLABLE): Single transaction limit.
  - `invite_status` (`text`, DEFAULT `'pending'`): Status (`pending`, `accepted`, `declined`).

#### 33. `public.premium_entitlement_grandfather`
* **Role & Purpose:** Legacy SIM lines exempt from premium payment checks. Service role only.
* **Columns:**
  - `sim_line_id` (`uuid`, PRIMARY KEY): Exempt `sim_lines.id`.
  - `reason` (`text`, NOT NULL): Grandfathering justification.
  - `created_at` (`timestamptz`, DEFAULT `now()`): Grant timestamp.

---

### Domain 8: Device Registry, Risk Engine & Anti-Fraud

#### 34. `public.user_devices`
* **Role & Purpose:** Device fingerprint registry tracking app installs per account. Deny-all to clients.
* **Columns:**
  - `device_id` (`text`, PRIMARY KEY): Normalized device fingerprint hash.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `label` (`text`, NULLABLE): User label (e.g. "Abdal's Pixel 8").
  - `platform` (`text`, NULLABLE): OS platform (`android`, `ios`, `web`).
  - `app_version` (`text`, NULLABLE): App version string.
  - `trust_state` (`text`, DEFAULT `'trusted'`): Risk status (`trusted`, `blocked`, `flagged`).
  - `first_seen_at` / `last_seen_at` (`timestamptz`): Observation window markers.

#### 35. `public.device_money_events`
* **Role & Purpose:** Velocity log recording every financial action attempt with machine risk score and decision.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Event ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `device_id` (`text`, NULLABLE): FK to `user_devices.device_id`.
  - `action` (`text`, NOT NULL): Action code (`topup`, `deposit`, `esim_buy`, `transfer`).
  - `amount_usd` (`numeric`, NULLABLE): Dollar value.
  - `assessed_decision` (`text`, NOT NULL): Model output (`allow`, `challenge`, `deny`).
  - `enforced` (`boolean`, DEFAULT `false`): True if policy actively blocked transaction.
  - `reason` (`text`, NULLABLE): Decision code.
  - `score` (`integer`, NULLABLE): Computed risk score (0-100).
  - `created_at` (`timestamptz`, DEFAULT `now()`): Creation time.

#### 36. `public.device_risk_allowlist`
* **Role & Purpose:** Explicit per-user fraud exemptions assigned by security team.
* **Columns:**
  - `user_id` (`uuid`, PRIMARY KEY): FK to `profiles.id`.
  - `reason` (`text`, NOT NULL): Defense justification.
  - `expires_at` (`timestamptz`, NULLABLE): Expiration timestamp (NULL = permanent).

#### 37. `public.rate_limit_buckets`
* **Role & Purpose:** Token-bucket state table backing server-side rate limits (`consume_rate_limit`).
* **Columns:**
  - `bucket` (`text`, NOT NULL): Namespace identifier.
  - `key` (`text`, NOT NULL): Bucket key (e.g. IP or User ID).
  - `tokens` (`numeric`, NOT NULL): Current available token count.
  - `last_refill_at` (`timestamptz`, NOT NULL): Last refill timestamp.
  - PRIMARY KEY (`bucket`, `key`).

#### 38. `public.security_logs`
* **Role & Purpose:** System-wide security event log (failed logins, suspicious RPC calls, unauthorized attempts).
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Log ID.
  - `user_id` (`uuid`, NULLABLE): FK to `profiles.id`.
  - `event` (`text`, NOT NULL): Event classification.
  - `ip_address` (`text`, NULLABLE): Origin IP address.
  - `user_agent` (`text`, NULLABLE): Client user-agent string.
  - `details` (`jsonb`, DEFAULT `'{}'`): Supplemental data.
  - `created_at` (`timestamptz`, DEFAULT `now()`): Event timestamp.

---

### Domain 9: Notifications & Alert Subsystem

#### 39. `public.notifications`
* **Role & Purpose:** User in-app notifications inbox.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Notification ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `title` (`text`, NOT NULL): Notification header.
  - `body` (`text`, NOT NULL): Notification body message.
  - `category` (`text`, NOT NULL): Category (`topup_status`, `wallet_credit`, `security`, `promo`).
  - `is_read` (`boolean`, DEFAULT `false`): Read status flag.
  - `metadata` (`jsonb`, DEFAULT `'{}'`): Navigation links or payload.
  - `created_at` (`timestamptz`, DEFAULT `now()`): Creation date.

#### 40. `public.notification_deliveries`
* **Role & Purpose:** Delivery queue and dispatch log across external channels (Push, Email, WhatsApp, Telegram).
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Delivery ID.
  - `notification_id` (`uuid`, NULLABLE): FK to `notifications.id`.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `channel` (`text`, NOT NULL): Channel (`push`, `email`, `whatsapp`, `telegram`).
  - `status` (`text`, DEFAULT `'pending'`): Delivery state (`pending`, `sent`, `failed`, `skipped`).
  - `provider_tx_id` (`text`, NULLABLE): External provider message ID.
  - `sent_at` (`timestamptz`, NULLABLE): Sent timestamp.

#### 41. `public.alert_settings`
* **Role & Purpose:** User channel preferences per alert category.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Record ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `category` (`text`, NOT NULL): Alert category.
  - `is_enabled` (`boolean`, DEFAULT `true`): Overall category toggle.
  - `channels` (`text[]`, DEFAULT `ARRAY['push', 'email']`): Active notification delivery channels.

#### 42. `public.notification_channels`
* **Role & Purpose:** Outbound channel routing catalog and configuration credentials.
* **Columns:**
  - `channel_key` (`text`, PRIMARY KEY): Channel key (`push`, `email`, `whatsapp_official`, `telegram_bot`).
  - `is_globally_enabled` (`boolean`, DEFAULT `true`): Operator master switch.
  - `provider` (`text`, NOT NULL): Delivery vendor (e.g. `onesignal`, `resend`, `twilio`).

#### 43. `public.notification_channel_catalog`
* **Role & Purpose:** Operator channel administration view and usage monitoring.
* **Columns:** Same as `notification_channels` with added administration metadata and quota limits.

#### 44. `public.device_push_tokens`
* **Role & Purpose:** Push notification tokens (OneSignal Player IDs, FCM Tokens) registered per device.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Record ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `device_id` (`text`, NOT NULL): FK to `user_devices.device_id`.
  - `onesignal_player_id` (`text`, NULLABLE): OneSignal identifier.
  - `fcm_token` (`text`, NULLABLE): Firebase Cloud Messaging token.

#### 45. `public.system_alerts`
* **Role & Purpose:** System administrator incident alerts (worker down, supplier outage, rate limit spike).
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Incident ID.
  - `alert_type` (`text`, NOT NULL): Type code.
  - `severity` (`text`, DEFAULT `'warning'`): Level (`info`, `warning`, `critical`).
  - `message` (`text`, NOT NULL): Incident payload.
  - `resolved` (`boolean`, DEFAULT `false`): Resolution marker.

---

### Domain 10: Offline SMS & Telephony Gateway

#### 46. `public.offline_refill_settings`
* **Role & Purpose:** Global configuration for SMS/WhatsApp zero-data offline refill feature.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Setting ID.
  - `gateway_number` (`text`, NOT NULL): Inbound phone number.
  - `is_enabled` (`boolean`, DEFAULT `true`): Master status.

#### 47. `public.offline_refill_events`
* **Role & Purpose:** Transaction log for refills initiated via SMS/WhatsApp without active mobile data.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Event ID.
  - `sender_phone` (`text`, NOT NULL): Sender phone number.
  - `amount_usd` (`numeric`, NOT NULL): Top-up requested value.
  - `status` (`text`, DEFAULT `'pending'`): Status.

#### 48. `public.offline_command_log`
* **Role & Purpose:** Log of all incoming SMS commands (`BAL`, `REFILL`, `HELP`) and sent replies. Deny-all RLS.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Log ID.
  - `provider` (`text`, NOT NULL): Telephony provider (`twilio`, `meta`).
  - `provider_msg_id` (`text`, NOT NULL): Provider unique message ID for idempotency.
  - `sender_phone` (`text`, NOT NULL): Sender phone number.
  - `command_type` (`text`, NOT NULL): Classification (`balance`, `refill`, `help`, `stop`).
  - `reply_text` (`text`, NOT NULL): Exact response SMS body sent back.

#### 49. `public.offline_refill_endpoints`
* **Role & Purpose:** List of country-specific contact numbers displayed to users in the app for zero-data refills.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Endpoint ID.
  - `channel` (`text`, NOT NULL): `sms` or `whatsapp`.
  - `phone_number` (`text`, NOT NULL): Telephony number.
  - `country_code` (`text`, NOT NULL): ISO country code.
  - `is_primary` (`boolean`, DEFAULT `false`): Primary number for country.

---

### Domain 11: Admin Control Plane, Auditing & System Configs

#### 50. `public.system_configs`
* **Role & Purpose:** Key-value store for runtime application settings, markup percentages, and operational parameters.
* **Columns:**
  - `config_key` (`text`, PRIMARY KEY): Unique setting key (e.g. `ESIM_MARKUP_PERCENT`, `APP_CHECK_ENFORCE`).
  - `config_value` (`text`, NOT NULL): Current string value.
  - `updated_at` (`timestamptz`, DEFAULT `now()`): Last modified timestamp.

#### 51. `public.system_config_meta`
* **Role & Purpose:** Metadata registry documenting types, validation bounds, and descriptions for `system_configs`.
* **Columns:**
  - `config_key` (`text`, PRIMARY KEY): Matching key in `system_configs`.
  - `value_type` (`text`, NOT NULL): Type (`numeric`, `boolean`, `string`, `enum`).
  - `min_value` / `max_value` (`numeric`, NULLABLE): Numeric validation bounds.
  - `enum_options` (`text[]`, NULLABLE): Valid enum strings.
  - `description` (`text`, NOT NULL): Technical documentation of the key's function.

#### 52. `public.admin_audit_log`
* **Role & Purpose:** Immutable administrative audit log recording every mutation performed in the Admin Console.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Log ID.
  - `actor_id` (`uuid`, NULLABLE): Admin User ID extracted from JWT.
  - `actor_email` (`text`, NULLABLE): Admin email address.
  - `action` (`text`, NOT NULL): Mutation action name.
  - `target_type` (`text`, NOT NULL): Entity affected (`carrier`, `user`, `config`, `ticket`).
  - `target_id` (`text`, NULLABLE): Primary key of affected entity.
  - `before_value` / `after_value` (`jsonb`, NULLABLE): Diff state before and after change.
  - `created_at` (`timestamptz`, DEFAULT `now()`): Audit record creation time.

#### 53. `public.admin_emails`
* **Role & Purpose:** Log and queue for outbound support/system emails composed by admins.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Email record ID.
  - `from_address` / `to_addresses` (`text`, NOT NULL): Email routing header fields.
  - `subject` / `body_text` (`text`, NOT NULL): Content fields.
  - `status` (`text`, DEFAULT `'queued'`): State (`queued`, `sent`, `failed`).

#### 54. `public.fx_rates`
* **Role & Purpose:** Curated display-only foreign exchange currency rates. Updated periodically via background engine.
* **Columns:**
  - `currency_code` (`text`, PRIMARY KEY): ISO currency code (e.g. `EUR`, `SAR`, `GBP`).
  - `usd_to_local` (`numeric`, NOT NULL): Conversion rate multiplier ($1 USD = X Local).
  - `updated_at` (`timestamptz`, DEFAULT `now()`): Rate refresh timestamp.

#### 55. `public.support_tickets`
* **Role & Purpose:** Customer support ticketing system.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Ticket ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `subject` (`text`, NOT NULL): Ticket title.
  - `category` (`text`, NOT NULL): Category (`refill_issue`, `billing`, `esim`, `other`).
  - `status` (`text`, DEFAULT `'open'`): Status (`open`, `in_progress`, `resolved`, `closed`).
  - `priority` (`text`, DEFAULT `'normal'`): Priority (`low`, `normal`, `high`, `urgent`).
  - `sim_line_id` (`uuid`, NULLABLE): Associated SIM line.

#### 56. `public.ticket_messages`
* **Role & Purpose:** Conversation thread messages attached to support tickets.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Message ID.
  - `ticket_id` (`uuid`, NOT NULL): FK to `support_tickets.id`.
  - `sender_id` (`uuid`, NOT NULL): Sender User ID.
  - `message` (`text`, NOT NULL): Text message body.
  - `is_admin_reply` (`boolean`, DEFAULT `false`): Flag for admin responses.

#### 57. `public.test_cases`
* **Role & Purpose:** E2E automated testing sandbox definitions and test suite data.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Test case ID.
  - `name` (`text`, NOT NULL): Test scenario title.
  - `payload` (`jsonb`, NOT NULL): Test inputs and mock expectations.

---

### Domain 12: Referrals, Marketing, Campaigns & Affiliates

#### 58. `public.referrals`
* **Role & Purpose:** Refer-and-Earn referral tracking between advocates and referred users.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Referral ID.
  - `referrer_id` (`uuid`, NOT NULL): Advocate `profiles.id`.
  - `referred_id` (`uuid`, NOT NULL): New user `profiles.id`.
  - `status` (`text`, DEFAULT `'pending'`): Status (`pending`, `completed`, `rewarded`).

#### 59. `public.referral_points`
* **Role & Purpose:** Point ledger for advocate rewards earned from referrals.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Ledger ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `points` (`integer`, NOT NULL): Signed point delta.

#### 60. `public.referral_redemptions`
* **Role & Purpose:** Log of referral points converted into wallet credits.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Redemption ID.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `points_redeemed` (`integer`, NOT NULL): Points converted.
  - `credit_amount_usd` (`numeric`, NOT NULL): Wallet USD credited.

#### 61. `public.retired_referral_codes`
* **Role & Purpose:** Prevent reuse of referral codes after account deletions or code updates.
* **Columns:**
  - `code` (`text`, PRIMARY KEY): Retired referral string.
  - `retired_at` (`timestamptz`, DEFAULT `now()`): Retirement date.

#### 62. `public.campaigns`
* **Role & Purpose:** Targeted marketing push & in-app promotional campaign manager.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Campaign ID.
  - `title` / `body` (`text`, NOT NULL): Promotional text.
  - `target_carrier_id` (`uuid`, NULLABLE): Optional target carrier filter.
  - `status` (`text`, DEFAULT `'draft'`): State (`draft`, `active`, `completed`).

#### 63. `public.campaign_deliveries`
* **Role & Purpose:** Delivery log tracking which users received or dismissed promo campaigns.
* **Columns:**
  - `campaign_id` (`uuid`, NOT NULL): FK to `campaigns.id`.
  - `user_id` (`uuid`, NOT NULL): FK to `profiles.id`.
  - `pushed_at` / `seen_at` / `dismissed_at` (`timestamptz`): Lifecycle timestamps.

#### 64. `public.affiliate_networks`
* **Role & Purpose:** Network integrations for affiliate travel eSIM offers (e.g. Impact, CJ, Awin).
* **Columns:**
  - `code` (`text`, PRIMARY KEY): Network code.
  - `name` (`text`, NOT NULL): Network display name.
  - `is_active` (`boolean`, DEFAULT `false`): Status.

#### 65. `public.affiliate_partners`
* **Role & Purpose:** Partner brands registered under affiliate networks (e.g., Airalo, Holafly).
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Partner ID.
  - `network_code` (`text`, NOT NULL): FK to `affiliate_networks.code`.
  - `display_name` (`text`, NOT NULL): Brand name.
  - `commission_percent` (`numeric`, NULLABLE): Commission rate.

#### 66. `public.affiliate_offers`
* **Role & Purpose:** Individual travel deals/packages listed by affiliate partners.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Offer ID.
  - `partner_id` (`uuid`, NOT NULL): FK to `affiliate_partners.id`.
  - `title` (`text`, NOT NULL): Deal title.
  - `price_usd` (`numeric`, NOT NULL): Deal price.
  - `landing_url` (`text`, NULLABLE): Outbound affiliate link.

#### 67. `public.affiliate_clicks`
* **Role & Purpose:** Outbound click tracker when users select external partner offers.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Click ID.
  - `user_id` (`uuid`, NULLABLE): User ID if logged in.
  - `partner_id` (`uuid`, NOT NULL): FK to `affiliate_partners.id`.
  - `target_url` (`text`, NOT NULL): Final redirect URL.

#### 68. `public.affiliate_conversions`
* **Role & Purpose:** Inbound postback log for completed affiliate conversions and commissions earned.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Conversion ID.
  - `network_code` (`text`, NOT NULL): FK to `affiliate_networks.code`.
  - `commission_usd` (`numeric`, NULLABLE): Earned revenue.

#### 69. `public.analytics_events`
* **Role & Purpose:** Application usage & telemetry analytics log.
* **Columns:**
  - `id` (`uuid`, PRIMARY KEY): Event ID.
  - `user_id` (`uuid`, NOT NULL): User ID.
  - `event_type` (`text`, NOT NULL): Analytics event code.
  - `details` (`jsonb`, DEFAULT `'{}'`): Payload.

#### 70. `public.esim_offers` (Database View)
* **Role & Purpose:** Client-facing sanitized view of `esim_offers_cache` that exposes retail prices while masking wholesale cost fields.

---

## 3. Database Functions, RPCs & Triggers Reference

---

### Category A: Financial Ledger & Wallet RPCs

* **`credit_wallet_for_deposit(p_user_id, p_amount, p_description, p_reference_id, p_metadata)`**
  - **Context:** SECURITY DEFINER (service_role / Edge Functions)
  - **Purpose:** Credits a user's wallet following a verified payment deposit (PayPal, Credit Card). Updates balance and records an immutable `deposit` row in `wallet_transactions`.

* **`credit_wallet_for_refund(p_user_id, p_amount, p_reference_id, p_description, p_sim_line_id, p_type)`**
  - **Context:** SECURITY DEFINER (service_role / Backend Workers)
  - **Purpose:** Credits wallet balance when a top-up or eSIM purchase fails. Locked down against client calls to prevent self-refunding exploits.

* **`debit_wallet_for_topup(p_user_id, p_sim_line_id, p_amount, p_description, p_reference_id, p_txn_type)`**
  - **Context:** SECURITY DEFINER (Backend Execution Engine)
  - **Purpose:** Atomically debits a user's wallet for a SIM top-up execution. Checks balance sufficiency and creates a `topup_debit` transaction entry.

* **`pay_plan_fee_from_wallet(p_reference_id, p_sim_line_id, p_device_id, p_plan, p_carrier_rule_id)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Deducts annual or monthly plan protection fees from the user's wallet and updates plan entitlement records.

* **`quote_plan_price(p_sim_line_id, p_plan, p_gateway, p_carrier_rule_id)`**
  - **Context:** SECURITY INVOKER
  - **Purpose:** Calculates the final price for plan subscription including gateway processing fees (e.g. PayPal fees).

* **`transfer_wallet_credit(p_recipient_email, p_amount, p_reference_id, p_note, p_device_id)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Allows peer-to-peer balance transfer between KeepSIMs users, updating both sender and recipient wallets atomically.

---

### Category B: SIM Refill Execution & Supplier Routing Engine

* **`pick_best_refill_offer(p_sim_line_id, p_target_usd)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Analyzes cached offers from all enabled suppliers (`zendit`, `ding`, `dtone`, `reloadly`) for a carrier, applies supplier policies/penalties, and selects the lowest retail price offer meeting the target dollar amount.

* **`choose_supplier_for_offer(p_sim_line_id, p_offer_id, p_exclude)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Dynamically determines supplier fallback order during refill retries if the primary supplier fails.

* **`claim_due_executions(p_execution_type, p_limit)`**
  - **Context:** SECURITY DEFINER (Worker Node process)
  - **Purpose:** Atomically claims pending refill execution tasks from the queue for worker processing using `FOR UPDATE SKIP LOCKED`.

* **`queue_premium_refill_executions(p_sim_line_id, p_scheduled_topup_id, p_plan_expires_at, p_start_at)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Generates and queues the full year's automated refill executions for a premium subscriber based on carrier inactivity cadence.

* **`run_auto_rescue(p_dry_run)`**
  - **Context:** SECURITY DEFINER (Cron Task)
  - **Purpose:** Scans all lines with active SIM Insurance (`sim_line_rescue_policy`). If a line is within `lead_days` of deactivation and standard refill failed, executes an emergency rescue top-up.

* **`set_line_rescue_policy(p_sim_line_id, p_max_usd, p_lead_days, p_warn_lead_days)`**
  - **Context:** SECURITY INVOKER
  - **Purpose:** Allows a user to configure or disarm SIM insurance settings on their line.

* **`reschedule_mini_refill(p_sim_line_id, p_new_date)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Adjusts the upcoming refill execution date for custom user schedules while verifying safety within carrier inactivity bounds.

---

### Category C: Device Security, Risk Engine & Anti-Fraud

* **`touch_user_device(p_device_id, p_platform, p_app_version)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Registers or updates a device fingerprint upon app launch and links it to the active account.

* **`assess_device_risk(p_user_id, p_device_id, p_action, p_amount_usd)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Evaluates device velocity, account count per device, and failed transaction patterns. Returns decision (`allow`, `challenge`, `deny`), risk score, and detailed reasons.

* **`guard_money_action(p_action, p_amount_usd, p_device_id, p_reference_id, p_user_id)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Gateway guard called before executing any financial transaction. Assesses device risk and enforces blocks if `APP_CHECK_ENFORCE` or risk policies are active.

* **`report_device_block(p_action, p_amount_usd, p_device_id)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Logs blocked money transaction attempts for admin security review.

* **`consume_rate_limit(p_bucket, p_key, p_capacity, p_refill_per_minute, p_now)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Implements token-bucket rate limiting for API calls and RPC execution protection.

---

### Category D: Household Spend Governance

* **`household_spend_check(p_owner_id, p_member_id, p_amount, p_exclude_execution_id)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Validates whether a household family member is permitted to spend $X from the head of household's wallet against monthly and per-transaction caps.

* **`household_spend_summary()`**
  - **Context:** SECURITY INVOKER
  - **Purpose:** Returns complete household budget utilization, showing each member's monthly cap, month-to-date spend, in-flight transactions, and remaining headroom.

* **`invite_household_member(p_email, p_role)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Sends an email invite to add a family member to the user's household wallet sharing group.

* **`respond_to_household_invite(p_invite_id, p_accept)`**
  - **Context:** SECURITY INVOKER
  - **Purpose:** Accepts or declines a pending household membership invitation.

* **`set_household_member_cap(p_member_row_id, p_monthly_cap_usd, p_per_txn_cap_usd)`**
  - **Context:** SECURITY INVOKER
  - **Purpose:** Allows head of household to update spending caps for a family member ($0 disables spending).

---

### Category E: Offline Telephony & SMS Command Gateway

* **`handle_inbound_command(p_provider, p_provider_msg_id, p_sender_phone, p_channel, p_body, p_raw)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Main entry point for inbound SMS/WhatsApp webhooks. Parses command (`BAL`, `REFILL`), verifies sender identity, triggers wallet refill/balance lookup, logs output, and returns SMS response text.

* **`classify_inbound_command(p_body)`**
  - **Context:** SECURITY INVOKER
  - **Purpose:** Natural language/keyword parser categorizing incoming text into `balance`, `refill`, `help`, or `stop`.

* **`build_balance_reply(p_user_id)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Formats a privacy-masked SMS response containing current wallet balance and the 3 lines closest to expiration.

* **`resolve_sender_user(p_sender_phone)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Maps incoming sender phone number to a user profile via `profiles.phone` or `sim_lines.phone_number`.

---

### Category F: eSIM Store & Roaming Savings Calculator

* **`compare_esim_offers(p_country_code, p_coverage, p_min_data_mb, p_min_days, p_max_price_usd, p_unlimited_only, p_speed_tiers, p_sort, p_limit, p_offset)`**
  - **Context:** SECURITY INVOKER
  - **Purpose:** High-performance search and filter function querying the `esim_offers` view to return retail data packages for travel destinations.

* **`request_esim_purchase(p_offer_id, p_quantity, p_device_id)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Debits user wallet and queues an eSIM purchase order for fulfillment via API suppliers.

* **`roam_or_esim_quote(p_country_code, p_days, p_data_mb, p_carrier_id)`**
  - **Context:** SECURITY INVOKER
  - **Purpose:** Powers the "Roam-or-eSIM" screen by comparing what the user's home carrier charges to roam in a destination versus buying a travel eSIM, computing exact dollar savings.

---

### Category G: System Triggers & Background Cron Jobs

* **`trg_fn_dispatch_notification()`**
  - **Trigger:** `AFTER INSERT ON notifications`
  - **Purpose:** Intercepts newly created in-app notifications and queues channel deliveries (`push`, `email`, `whatsapp`) based on user preferences.

* **`trg_fn_log_topup_activity()`**
  - **Trigger:** `AFTER UPDATE ON topup_executions`
  - **Purpose:** Automatically appends an entry to `line_activity_log` whenever a refill execution status changes.

* **`protect_is_power_user()`**
  - **Trigger:** `BEFORE UPDATE ON profiles`
  - **Purpose:** Security guard ensuring non-admin users cannot elevate their own `is_power_user` flag.

* **`refresh_fx_rates(p_rates, p_as_of, p_source)`**
  - **Context:** SECURITY DEFINER (Edge Function Cron)
  - **Purpose:** Updates currency exchange rates in `fx_rates` table.

* **`sync_auto_price_watches()`**
  - **Context:** SECURITY DEFINER (Nightly Cron)
  - **Purpose:** Synchronizes automatic price watches for all active user SIM lines so users get notified of price drops in their home countries.

* **`detect_offer_price_drops()`**
  - **Context:** SECURITY DEFINER (Cron Task)
  - **Purpose:** Scans `offer_price_history` against `offer_price_watches` and dispatches alerts when prices drop below watch thresholds.

---

### Category H: Admin Control Plane RPCs

* **`assert_admin()`**
  - **Context:** SECURITY INVOKER
  - **Purpose:** Security gate verifying that the calling user has `is_power_user = true`. Raises error `KS460` if authorization fails.

* **`admin_list_carriers()`, `admin_list_users()`, `admin_list_tickets()`, `admin_list_configs()`**
  - **Context:** SECURITY DEFINER (Gated by `assert_admin()`)
  - **Purpose:** Provides comprehensive admin dashboard data feeds with aggregated counts, active lines, and health metrics.

* **`admin_fail_refill(p_execution_id, p_reason, p_refund)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Allows admins to manually fail stuck executions and issue automated wallet refunds to affected users.

* **`admin_adjust_wallet(p_user_id, p_amount, p_reason)`**
  - **Context:** SECURITY DEFINER
  - **Purpose:** Admin goodwill wallet credit or correction. Capped by `ADMIN_WALLET_ADJUST_MAX_USD` and audited in `admin_audit_log`.

---

## 4. Verification & Consistency Summary

This documentation reflects the actual database schema as deployed in production:
- **Total Tables:** 75 tables across 12 business domains.
- **Security Posture:** 100% of tables have Row Level Security enabled. Financial ledger & risk tables strictly restrict client direct access.
- **Function Inventory:** Includes over 100 stored procedures, RPCs, triggers, and automated cron functions backing KeepSIMs operations.
