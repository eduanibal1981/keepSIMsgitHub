# C9 — eSIM Management: Hand-off Brief

**Written 2026-07-22, repo @ `6a5469b` (main), live DB `zwxswagokhgbuzrrbnhr` verified same day.**
Plan section: `doc/PRODUCTION_PLAN.md` § C9. Order: C1–C8 are ALL DONE; C9 is the last
Phase-C item. The plan itself says "big — split if needed": **split it — C9a (security
fix + catalog + browse/compare) then C9b (purchase + delivery + My eSIMs + alerts).**

## Owner context

The plan's C9 scope: browse-by-destination, purchase against the wallet, QR/activation
delivery, "My eSIMs" with data remaining + expiry, low-data alerts via C1, key moved
server-side. **But an older owner note conflicts**: the 2026-07-17 pricing session
recorded charge-scenario 7 as *"eSIM = affiliate, free for now → C9"*. The owner's
latest direction (2026-07-22, this hand-off) is the full merchant model — professional
plan comparison (best price for the country the user is in / travelling to) plus a real
management system. Treat merchant-model as the working assumption, **confirm at session
start** and record the superseded affiliate note in the plan.

## Verified current state (live DB + repo, 2026-07-22)

- **🔴 SECURITY — `ESIM_GO_API_KEY` ships inside every APK.** `.env` (whose only key
  is `ESIM_GO_API_KEY`) is a bundled Flutter asset (`pubspec.yaml:84`), loaded at
  `main.dart:35`, read at `esim_go_api_client.dart:13`. Flutter assets are extractable
  from any built APK with a zip tool. The key authorizes **orders** (`createOrder`
  hits `api.esim-go.com/v2.2/orders` — a `type:'transaction'` body spends the owner's
  eSIM Go balance), not just catalogue reads. **The key must be rotated** (it has
  shipped in debug builds) **and must never return to the client** — add rotation to
  the A2 list. This is C9's equivalent of C3's faucet; fix it first.
- **The plan's "facade" premise is HALF wrong.** `esim_screen.dart` Add/Transfer CTAs
  are indeed "coming soon" (`:81,:96`), but **Browse Plans is LIVE in release**:
  `/esim/plans` → `esim_plans_screen.dart` → `EsimPlansController` →
  `EsimGoRepositoryImpl` → direct device-to-eSIM-Go catalogue calls. A full scaffold
  already exists under `lib/features/esim/` (freezed DTOs in `esim_go_models.dart`,
  `EsimRepository` interface, `esimRepositoryProvider` factory anticipating multiple
  providers, `getPlans` + `validatePlanPurchase`). Reuse the domain/DTO layer; replace
  the transport.
- **Current browse UX is a dev stub**: raw "Country ISO Code" `TextField` defaulting
  to `'US'`, fetches the ENTIRE eSIM Go catalogue per query and filters device-side,
  shows raw `MB / Days / $wholesale` rows — it displays **wholesale prices with zero
  markup** to end users. No purchase button anywhere (`validatePlanPurchase` has no
  call site).
- **Zero DB surface**: no table matching `%esim%` exists (verified).
  `wallet_transactions_type_check` has no eSIM type (current list: deposit,
  topup_debit, refund, referral_credit, welcome_home_debit, auto_fund,
  plan_fee_debit). No RPCs, no workers.
- **Notification canon is now 13 categories** (`support` was added in C7 — the C2
  "settled 12" note is stale by one). No category fits low-data alerts. Adding
  `esim_low_data` means updating BOTH `notifications_category_check` and
  `alert_settings_category_check` in sync + the `trg_profiles_seed_alert_settings`
  seeding trigger + backfill + settings-screen category list. The canon is
  owner-settled, so **extending it needs explicit sign-off**.
- **Device capability detection is REAL and done**: platform channel
  `com.keep_sims/esim` has native handlers on both platforms
  (`MainActivity.kt:10` EuiccManager, `AppDelegate.swift:26`
  CTCellularPlanSupportsEsim), cached via `esimCapabilityServiceProvider`,
  safe-false on emulators/desktop. Gate purchase behind it (still allow browse).
- **C8 tie-in is ready and waiting**: `profiles.last_country` exists and the
  `geo_fence_triggered` notification already deep-links to `/esim`. C9 should
  preselect the browse destination from it — that's the "best price for the country
  he is in" ask, nearly free.
- `esim_api_response.json` at repo root is a captured live catalogue sample — useful
  for DTO shape reference (bundles carry `countries[]`, `roamingEnabled[]`,
  `imageUrl` country art from eSIM Go's CMS) without burning API calls.
- All `esim_screen.dart` / `esim_plans_screen.dart` strings are hardcoded English —
  no ARB keys exist for the feature.

## Design recommendations (professional-grade — how Airalo/Holafly/Saily do it)

1. **C9a step 1 — evict the key, mirror the Zendit architecture exactly.** New
   `esim_offers_cache` table (RLS: NO direct authenticated SELECT — see markup point)
   refreshed by a new VM pm2 worker `worker_esim_catalog` (catalogues change rarely —
   every 6h is plenty; reuse `servers/` conventions, `node --test` tests, transform
   fn as the single row-shaper like `offerCacheRow`). `ESIM_GO_API_KEY` moves to VM
   `servers/.env` beside the Zendit key. Client's `EsimGoApiClient` + `flutter_dotenv`
   + the `.env` asset are **deleted** (nothing else uses dotenv — verified single
   key); `EsimGoRepositoryImpl` re-pointed at Supabase. Rotate the key after cutover.
2. **Never show wholesale — retail is computed server-side, DB-tunable.** Store
   wholesale cost in the cache; expose retail to clients via a **view** (or computed
   column) applying `system_configs.ESIM_MARKUP_PERCENT` (new key, owner sets the
   number — this is the house rule: prices change in the DB, never in an app
   release). Clients can only read the retail view; leaking wholesale leaks margin.
3. **Comparison UX — destination-first, best-value-forward** (the owner's explicit
   ask; this is the whole product):
   - Country picker with flags + search (not a raw ISO field); **preselect from
     `profiles.last_country`**, fall back to `home_country_code`.
   - Tabs: **Local / Regional / Global** (eSIM Go bundles declare multi-country
     coverage via `countries[]`/`roamingEnabled[]` — a Europe bundle must appear
     under "France" too, the current filter already handles this).
   - Plan cards: data, validity, retail price, **price-per-GB**, and a computed
     **"Best value" badge** on the cheapest per-GB plan that covers the destination;
     sort control (price ↑ / per-GB ↑ / data ↓) and quick filters (≥5GB, ≥15 days,
     unlimited).
   - Detail sheet: full coverage list, network/speed info if present, activation
     policy copy ("validity starts on install/first use"), and the buy button
     (C9b) gated on `esimCapabilityServiceProvider`.
4. **C9b — purchase pipeline copies the refill lockdown pattern verbatim** (C3b
   lessons are law: client never states a price):
   - `request_esim_purchase(p_offer_id, p_quantity)` — SECURITY DEFINER, authenticated,
     prices **from the cache** (reject stale >24h), debits the wallet via a new
     idempotent debit (ledger type `esim_purchase_debit` added to the CHECK, partial
     unique index on `reference_id` = `esim_<order_id>`, adopt-on-retry — clone the
     `debit_wallet_for_topup` shape), inserts an `esim_orders` row (status
     `pending`). Client INSERT on `esim_orders` is never granted.
   - New VM worker `worker_esim_fulfillment` claims pending orders, calls eSIM Go
     `/v2.2/orders` (`type:'transaction'`, idempotent per order id), writes the
     resulting eSIM(s) into `user_esims`, marks `completed`; on failure → refund via
     `credit_wallet_for_refund` + `system_alerts` (existing kinds pattern) + status
     `failed`. Wallet-insufficient → reject at RPC, offer the existing deposit flow.
   - `user_esims`: iccid, smdp_address + matching_id (**store the LPA string**
     `LPA:1$<smdp>$<matching_id>`), bundle name, status, purchased/expires,
     data_total_mb, data_remaining_mb, last_usage_check. RLS read-own only;
     service_role writes.
5. **Delivery & management ("My eSIMs")**: QR rendered client-side from the LPA
   string (`qr_flutter` — no server image round-trip, works offline after purchase),
   copyable SM-DP+ / activation-code fields for manual entry, install instructions
   per platform. "My eSIMs" replaces the coming-soon "Installed Profiles" section:
   per-eSIM card with data-remaining progress bar, expiry countdown, pull-to-refresh
   usage. Usage: extend `worker_esim_fulfillment` (or the catalog worker) to poll
   eSIM Go usage for ACTIVE eSIMs a few times a day; under
   `ESIM_LOW_DATA_THRESHOLD_PERCENT` (system_configs, suggest 20% remaining) insert
   ONE `esim_low_data` notification (dedupe flag on the row, reset on top-up).
6. **Keep eSIMs OUT of `sim_lines`** — that table drags scheduled_topups, protection,
   carrier_rules and worker semantics an eSIM doesn't have. Separate `user_esims` +
   a dashboard section/card surfacing them alongside physical lines (the plan's
   "surface alongside" item) is cleaner than an `is_esim` flag threaded through the
   whole refill machine.
7. **Provider abstraction already exists — keep it honest.** `esimRepositoryProvider`
   stays the seam; Zendit also sells eSIMs through the API the project already
   integrates, making it the natural E2-style second provider/failover later. Don't
   build multi-provider now; just don't bake "eSIM Go" into table/column names
   (use `provider` columns like `zen_carrier` did).

## Confirm with owner at session start (blocking)

1. **Business model**: wallet-purchase merchant model with markup (recommended, per
   plan § C9) vs the old "affiliate, free for now" note — and the initial
   `ESIM_MARKUP_PERCENT` value (reference: consumer eSIM retail commonly runs
   30–100% over wholesale; pick a number, it's one DB row to change).
2. **eSIM Go account reality**: is the current key production (real money)? Does the
   account have balance? eSIM Go has no true sandbox for orders — `type:'validate'`
   is the free dry-run; agree what a "live e2e test" means (validate-only, or one
   real cheapest-bundle purchase ~$2 as the proof, like B3's $1.23 PayPal capture).
3. **Rotate `ESIM_GO_API_KEY`** (it shipped in APKs) — owner does this in the eSIM Go
   dashboard after the VM cutover; new key goes only to VM `servers/.env`.
4. **`esim_low_data` category** extends the settled notification canon (13 → 14,
   both CHECKs + seeding + settings UI) — sign-off required.
5. **Split**: C9a now (security + catalog + browse/compare), C9b next session
   (purchase + delivery + My eSIMs + alerts) — confirm.

## Session conventions (house rules — do not deviate)

- Migrations `supabase/migrations/20260726000000_c9a_esim_catalog.sql` (C9b:
  `20260727000000_c9b_esim_purchase.sql`) — round manual timestamps,
  `timestamp_phase_description` naming; apply via MCP `apply_migration` AND save the
  local file **the same session** (eb832ec lesson).
- Live SQL tests `supabase/tests/c9a_esim_tests.sql` (…c9b…), BEGIN..ROLLBACK via MCP
  `execute_sql`. Smoke over PostgREST as the a1 fixture
  (`a1-wallet-test@example.com` / `A1TestPass!2026`). **C9a must leave the wallet
  unchanged at 37.81**; C9b's live purchase test moves it — reconcile the ledger
  exactly and update the baseline in memory + this doc.
- VM workers live in `servers/` (node_modules resolution), tests via
  `node --test` (no framework), pm2 managed + `pm2 save`; `gcloud compute scp` needs
  ABSOLUTE paths, one file per call; push backend via the git-bundle workflow (VM →
  bundle → workstation temp clone → push). Node on VM = v22.
- `get_advisors` after migrations: target 0 net-new (authenticated SECURITY DEFINER
  self-scoped is the accepted known pattern).
- `flutter analyze` — record the baseline BEFORE changes (last known 143 infos
  pre-C8; re-measure). All Flutter tests pass (55 at C8). Debug APK builds.
- ARB keys in all 9 locales (en, ar, es, hi, tr, bn, ne, si, ur). Use the Edit tool
  for non-Latin files — PowerShell 5.1 Get/Set-Content mojibakes UTF-8.
- Don't blanket `dart format` touched files (repo isn't format-clean; it buries diffs).
- Commit `feat(esim): …`, push to `main`.
- Update `doc/PRODUCTION_PLAN.md` § C9 with an implementation record in the style of
  the C5/C6/C8 records, including recorded deviations (superseded affiliate note,
  key rotation, category canon extension).

## Execution prompt for the implementing agent

See the fenced prompt handed alongside this brief (chat), or reconstruct from the
sections above — the brief is the source of truth.
