# C9b — eSIM Purchase, Delivery & Management: Hand-off Brief

**Written 2026-07-22, repo @ `6a5469b` + UNCOMMITTED C9a working tree, live DB
`zwxswagokhgbuzrrbnhr` verified same day.**
Plan section: `doc/PRODUCTION_PLAN.md` § C9 (C9a implementation record is there).
Predecessor brief: `doc/C9_ESIM_HANDOFF.md` — its design recommendations §4–§7 ARE the
C9b spec; this brief supersedes it only where C9a reality diverged. C9b is the LAST
Phase-C item; after it, Phase D.

## ⚠️ Two gaps to close BEFORE any C9b feature work

1. **C9a is NOT committed.** The entire C9a change set sits uncommitted on `main`
   (deleted `esim_go_api_client.dart`, new migration/tests/worker, l10n ×9, pubspec
   minus flutter_dotenv…). First action of the session: review `git status`, commit
   `feat(esim): C9a security cutover, server catalog & browse/compare UX`, push.
   Do NOT mix C9a and C9b into one commit — the per-phase history is a house rule.
2. **`esim_offers_cache` is EMPTY (0 rows, verified live).** The worker
   (`servers/worker_esim_catalog.js`) and its `ecosystem.config.js` entry
   (`worker-esim-catalog`) exist ONLY in this repo — they were never deployed to the
   VM, and `ESIM_GO_API_KEY` was never added to VM `servers/.env` (the worker
   warn-skips without it). Consequence: the live C9a browse UI renders an empty
   catalogue, and the C9b purchase RPC would have nothing to price. Deploy sequence:
   `gcloud compute scp` (ABSOLUTE paths, one file per call) `worker_esim_catalog.js`
   → VM `servers/`, user (or agent via VM SSH) adds `ESIM_GO_API_KEY` to VM
   `servers/.env`, `pm2 start ecosystem.config.js --only worker-esim-catalog` +
   `pm2 save`, verify `select count(*) from esim_offers_cache` > 0. **Only after the
   VM holds the key does the owner rotate it** in the eSIM Go dashboard (it shipped
   in APKs — rotation is already on the A2 list) and updates VM `.env` again.

## Verified C9a state you inherit (live DB + repo, 2026-07-22)

- **Key eviction is real**: zero hits for `ESIM_GO_API_KEY`/`dotenv` under `lib/` +
  `pubspec.yaml`; `.env` asset deleted; `esim_go_api_client.dart` deleted. Client
  reads ONLY the `esim_offers` view via `EsimGoRepositoryImpl.getPlans()`.
- **Schema live** (migration `20260726000000_c9a_esim_catalog.sql`, applied AND
  saved locally):
  - `esim_offers_cache` — PK `(provider, bundle_name)`, cols: description,
    `countries text[]` (union of plan+roaming, upper-cased ISO-2),
    `roaming_enabled text[]`, `data_amount_mb bigint`, `duration_days int`,
    `wholesale_price_usd numeric(10,4)`, `image_url`, `is_active`, `updated_at`.
    RLS on, **no policies** — service_role only, wholesale never leaks.
  - `esim_offers` view — SECURITY DEFINER (`security_invoker=false`), exposes
    `id = provider || '_' || bundle_name` + `retail_price_usd =
    round(wholesale × (1 + ESIM_MARKUP_PERCENT/100), 2)`; granted to
    authenticated AND anon; only `is_active` rows.
  - `system_configs.ESIM_MARKUP_PERCENT` = '30' (NB: this table's columns are
    `config_key`/`config_value`, not key/value).
  - **Notification canon is now 14** — `esim_low_data` added to BOTH category
    CHECKs + `seed_default_alert_settings()` + backfilled for existing profiles.
    C9b does NOT need to touch the canon; just insert `notifications` rows with
    `category='esim_low_data'` and the C1 trigger dispatches.
- **Worker facts** (`servers/worker_esim_catalog.js`): env `ESIM_GO_BASE_URL`
  defaults to **`https://api.esim-go.com/v2.4`** (the old client used v2.2 —
  fulfillment must confirm which version the orders endpoint should use),
  `ESIM_CATALOG_REFRESH_MS` default 6h, `esimCatalogRow()` is the single
  row-shaper, 3 `node --test` tests in `servers/test/esim_catalog_test.js` (pass).
- **Client browse UX** (C9a, live): destination-first country picker with flags +
  search preselected from `profiles.last_country`→`home_country_code`,
  Local/Regional/Global tabs, quick filters (≥5 GB, ≥15 days, unlimited), sort
  (price / $-per-GB / data), "Best Value" badge on cheapest $/GB, detail sheet
  with activation-policy copy, purchase gated on `esimCapabilityServiceProvider`
  (real EuiccManager / CTCellularPlanSupportsEsim detection).
  `EsimRepository.validatePlanPurchase()` is a `return true` stub — C9b replaces it.
  Note: `getPlans()` fetches the whole view and filters device-side — acceptable at
  current catalogue size; move the country filter into the query (`countries cs
  {ISO}` or an RPC) only if the catalogue grows past a few thousand rows.
- **Zero purchase surface yet**: no `esim_orders`/`user_esims` tables (verified),
  no eSIM ledger type in `wallet_transactions_type_check`, no fulfillment worker.
- **a1 fixture wallet baseline: 37.81** (verified live this session). C9a left it
  untouched; C9b's one real purchase test WILL move it — reconcile the ledger
  exactly and update the baseline in memory + this doc afterwards.
- Verification at hand-off (re-run by the hand-off author 2026-07-22, post-restart):
  Node 3/3, SQL suite passed, `flutter test` 55/55, `flutter analyze` 0
  errors/warnings (**info baseline now 164**, was 143 pre-C8), debug APK builds.

## C9b scope (plan § C9 remainder + owner's ask)

Wallet purchase RPC → order pipeline → LPA/QR delivery → "My eSIMs" manager →
usage polling + low-data alerts. The owner's explicit product bar: *"like the
professional apps"* (Airalo/Holafly/Saily) — best price per destination was C9a;
C9b is a **trustworthy checkout and a genuinely useful management surface**.

### 1. Purchase pipeline — clone the C3b lockdown verbatim (client never states a price)

- Migration `20260727000000_c9b_esim_purchase.sql`:
  - `esim_orders`: id uuid PK, user_id, provider, bundle_name, quantity (default 1,
    cap small e.g. ≤3), `wholesale_price_usd` + `retail_price_usd` + markup snapshot
    (price at order time — the view is live, orders must be immutable),
    status CHECK (`pending`,`processing`,`completed`,`failed`,`refunded`),
    provider_order_ref, error, created/updated. RLS read-own; NO client writes.
  - `user_esims`: id, user_id, order_id FK, iccid, smdp_address, matching_id,
    **lpa_string** (`LPA:1$<smdp>$<matching_id>` — store it assembled), bundle_name,
    provider, status CHECK (`installed` is client-reported later; start
    `active`/`expired`/`depleted`), purchased_at, expires_at, data_total_mb,
    data_remaining_mb, last_usage_check, low_data_notified boolean (dedupe flag,
    reset on data increase). RLS read-own; service_role writes.
  - Ledger: add `esim_purchase_debit` to `wallet_transactions_type_check`; partial
    unique index on `reference_id` for that type (`esim_<order_id>`), adopt-on-retry
    — clone the `debit_wallet_for_topup` shape into `debit_wallet_for_esim` (or
    generalize; don't widen the topup index).
  - `request_esim_purchase(p_offer_id text, p_quantity int default 1)` — SECURITY
    DEFINER, authenticated, self-scoped: resolve the offer from
    **`esim_offers_cache`** (not the view — need wholesale AND retail server-side),
    reject `updated_at` older than 24h (stale cache fails safe, like
    `request_instant_refill`), reject inactive/unknown offers, compute retail from
    the config row, check + debit the wallet idempotently, insert the order
    `pending`, return order id. Wallet-insufficient → typed error the client maps
    to the existing deposit flow.
- **`servers/worker_esim_fulfillment.js`** (pm2 + ecosystem entry + `pm2 save`):
  claim `pending` orders (FOR UPDATE SKIP LOCKED claim RPC or service-role update,
  mirror `claim_instant_executions`), POST eSIM Go `/orders`
  (`type:'transaction'`, idempotent per order id — confirm v2.2 vs v2.4 endpoint),
  parse the returned eSIM(s) → insert `user_esims` rows, mark `completed`, insert a
  `notifications` row (category `system` or `top_up_success`-analog — use
  `system`; do NOT invent a new category) so the user gets a push "your eSIM is
  ready". On failure: refund via `credit_wallet_for_refund` (ref
  `esim_refund_<order_id>`, idempotent), status `failed`, `system_alerts` row
  (kind e.g. `esim_fulfillment_failed`) → power users. Shared transforms + rules in
  a `servers/esim_fulfillment` module with `node --test` coverage, like
  `offer_validation.js`.

### 2. Delivery — the moment users judge the app

- Post-purchase screen + "My eSIMs" detail: **QR rendered client-side from
  `lpa_string`** (`qr_flutter`; no server round-trip, works offline once synced),
  copyable SM-DP+ address and activation code as separate fields, and platform
  install instructions (iOS Settings path / Android Settings path); on Android 9+
  offer the LPA string for direct intent install if trivial, else skip.
- Realtime order status: subscribe to the user's `esim_orders` row (the
  `topupExecutionsLiveProvider` pattern) — checkout sheet shows
  pending → processing → completed/failed live; failure surfaces the refund
  explicitly ("You were not charged — refunded to wallet").
- **Checkout sheet transparency** (professional-app bar): plan name, coverage
  summary, data/validity, retail price, wallet balance before/after, activation
  policy line, single confirm CTA. No hidden fees — retail already includes markup.

### 3. "My eSIMs" management surface

- Replaces the coming-soon "Installed Profiles" section of `esim_screen.dart`:
  per-eSIM card = flag/art (`image_url`), bundle name, **data-remaining progress
  bar** (`data_remaining_mb / data_total_mb`), expiry countdown, status chip;
  detail view = QR + codes + usage + "Buy again" CTA (deep-link back to the C9a
  detail sheet for the same bundle). Expired/depleted collapse into an "Archive"
  group — don't delete history.
- Pull-to-refresh triggers a usage re-check (see §4) via a small
  `refresh_esim_usage(p_esim_id)` service path OR simply re-reads the row —
  simplest honest version: rows update on the worker's schedule; pull-to-refresh
  re-fetches the row and shows `last_usage_check` ("Updated 2h ago"). Do NOT let
  the client call eSIM Go.
- Dashboard: a compact eSIM card alongside physical lines (plan's "surface
  alongside" item). **Keep eSIMs OUT of `sim_lines`** — settled in the C9 brief.

### 4. Usage polling + low-data alerts

- Extend `worker_esim_fulfillment` (or a timer in the same process — one pm2 entry)
  to poll eSIM Go usage for `active` `user_esims` every few hours
  (`ESIM_USAGE_POLL_MS` env, default 4–6h): update `data_remaining_mb`,
  `last_usage_check`; flip status to `depleted`/`expired` when warranted.
- Threshold: `system_configs.ESIM_LOW_DATA_THRESHOLD_PERCENT` (seed '20'). When
  remaining % falls under it AND `low_data_notified=false` → insert ONE
  `notifications` row (`category='esim_low_data'`, deep-link `/esim`), set the
  flag; reset the flag if remaining increases (top-up/rebuy). C1 dispatcher does
  the rest — no Edge Function work needed.

### 5. Professional-grade extras (do if time allows, in this order)

1. **"Buy again / top up" from a low-data or expiry notification** — deep-link
   straight to the same bundle's detail sheet (highest-conversion path in
   competitor apps).
2. Compare tray: select up to 3 plans → side-by-side sheet (price, $/GB, validity,
   coverage count). Cheap to build on the C9a cards; skip if time is tight.
3. Order history list under My eSIMs (reads `esim_orders`, incl. refunded — trust).

## Confirm with owner at session start (blocking)

1. **Real-money test**: eSIM Go has no order sandbox. Agree the e2e proof — one
   real cheapest-bundle purchase (~$2–3, like B3's $1.23 capture) or
   `type:'validate'` dry-run only. The brief assumes ONE real purchase as the
   proof; it moves the a1 wallet baseline.
2. **Key + deploy**: agent can scp the worker, but the owner must put
   `ESIM_GO_API_KEY` into VM `servers/.env` (and rotate after cutover) — confirm
   they're available to do it at session start, else the whole session blocks.
3. Quantity cap per order (suggest 3) and refund policy copy for failed orders.
4. v2.2 vs v2.4 orders endpoint — verify against current eSIM Go docs before the
   first transaction call.

## Session conventions (house rules — do not deviate)

- Commit uncommitted C9a FIRST (`feat(esim): …`), then C9b work, separate commit.
- Migration `supabase/migrations/20260727000000_c9b_esim_purchase.sql` — round
  manual timestamp, apply via MCP `apply_migration` AND save the local file the
  same session (eb832ec lesson).
- Live SQL tests `supabase/tests/c9b_esim_tests.sql`, BEGIN..ROLLBACK via MCP
  `execute_sql`; smoke over PostgREST as the a1 fixture
  (`a1-wallet-test@example.com` / `A1TestPass!2026`); assert: direct INSERT on
  `esim_orders`/`user_esims` → 403, stale-cache rejection, idempotent debit
  (double-call = one debit), refund path, unknown/inactive offer rejection,
  low-data dedupe (one notification, flag reset).
- **Wallet baseline 37.81** — the live purchase test moves it; reconcile the
  ledger exactly (debit + any refund) and update memory + this doc's baseline.
- VM: workers in `servers/`, `node --test`, pm2 + `pm2 save`; `gcloud compute scp`
  ABSOLUTE paths, one file per call; backend push via git-bundle workflow. Node 22.
- `get_advisors` after migrations: 0 net-new (authenticated SECURITY DEFINER
  self-scoped = accepted pattern).
- `flutter analyze` 0 errors (info baseline **164** at hand-off); all Flutter
  tests pass (55 at hand-off); debug APK builds.
- ARB keys in all 9 locales (en, ar, es, hi, tr, bn, ne, si, ur); Edit tool for
  non-Latin files (PowerShell 5.1 mojibake). No blanket `dart format`.
- Update `doc/PRODUCTION_PLAN.md` § C9 with a C9b implementation record in the
  C5/C6/C8 style (deviations included) and flip C9 to ✅ DONE.

## Execution prompt for the implementing agent

See the fenced prompt handed alongside this brief (chat); this brief is the source
of truth if they diverge.
