# Phase 0 — Baseline, Schema Drift Audit & Event Contract

**Project:** KeepSIMs  
**Date:** 2026-09-26  
**Status:** Completed & Verified against Live Database (`zwxswagokhgbuzrrbnhr`)

---

## 1. Migration Drift & Live Database Audit

| Migration File | In `schema_migrations`? | Live Database Status | Reconciliation Decision |
|---|---|---|---|
| `20260817000000_i7_carrier_activity_semantics.sql` | ✅ Yes | Applied & active | Keep as-is. |
| `20260817030000_i7d_forecast_uses_deactivation_cadence.sql` | ✅ Yes | Applied & active | Keep as-is. |
| `20260818010000_i8b_carrier_advice_notifications.sql` | ✅ Yes | Applied & active | Keep as-is. |
| `20260916080000_fix_forecast_anchor_null_recharge.sql` | ❌ No | Function code active | Forward migration will record or wrap cleanly without failing. |
| `20260917021500_missing_recharge_date_reminders.sql` | ❌ No | **Not in live DB** (`emit_missing_recharge_date_reminders` missing) | Incorporate into forward migration safely. |
| `20260926100000_whatsapp_country_routing.sql` | ❌ No | **Objects exist in live DB** (tables, 24 routes, 1 profile) | Mark or guard with `IF NOT EXISTS` so it can be re-run safely. |

---

## 2. Live Baseline Telemetry

- **SIM Lines:**
  - Total Active Lines: **2**
  - Active Lines with `last_topup_at`: **0**
  - Active Lines without `last_topup_at`: **2** (neither is currently eligible for an exact 48-hour countdown).
- **Carrier Rules:**
  - Total Carrier Rules: **105** (105 distinct carriers)
  - `recharge_ok`: **92**
  - `min_denomination`: **11**
  - `usage_required`: **2**
  - Carrier rule columns verified: `inactivity_limit_days`, `grace_period_days`, `activity_requirement`, `validity_qualifying_topup_amount`, `minimum_topup_amount`, `rule_source_url`, `last_verified_at`.
- **Notification Deliveries (30-day baseline):**
  - `push_onesignal`: 252 (currently recorded as `"delivered"` upon HTTP 200 acceptance)
  - `push_fcm`: 17 (recorded as `"delivered"` upon FCM accept)
  - `push`: 183 (`skipped` — no devices registered)
  - `telegram`: 193 (`skipped` — chat ID not configured)
  - `email`: 192 (`skipped` — quota protection or free plan), 1 (`delivered`)
  - `whatsapp`: 10 (`skipped` — unentitled or unconfigured), 1 (`delivered`)
- **WhatsApp Country Routing:**
  - Configured Routes: **24** (2 Baileys VPS for Egypt & Oman; 22 Disabled fail-closed)
  - Provider Profiles: **1** (Primary Baileys VPS)
  - Message Attempts logged: **0**

---

## 3. Readers and Writers Inventory

| System Component | Writers | Readers | Current Defect / Drift |
|---|---|---|---|
| `public.notifications` | `trg_fn_dispatch_notification`, `process_due_notifications`, ad-hoc admin tests | Customer App (`NotificationsScreen`), Admin App | Pre-populates `delivered_via` before dispatch is attempted; no retry queue. |
| `public.notification_deliveries` | Edge Function `dispatch-alert` (`logDelivery`) | Admin `ChannelsScreen`, `admin_notification_health` RPC | Records provider HTTP acceptance (`200 OK`) as `"delivered"` rather than `"accepted_by_provider"`. |
| `public.whatsapp_message_attempts` | `whatsapp_router.ts` | Admin WhatsApp monitor | Ignores insert conflict; returns early only for `sent`/`delivered`; worker queue returns before dispatch. |
| `public.sim_lines` | Customer App, Admin App | `compute_usage_forecasts`, Alert Clock calculation | `last_topup_at` is null for all current active lines; requires graceful fallback state. |
| Push Tokens (`device_push_tokens`) | Customer App (`ForegroundPushService`) | Edge Function `dispatch-alert` | Fallback from OneSignal to FCM works, but lacks explicit tracking of provider outcome distinction. |
| Telegram Binding | `server_tg.js` via `bind_telegram_bot` | Customer App, Edge Function `dispatch-alert` | Deep link `/start bind_<user_id>` lacks nonce, expiration, or ownership verification (vulnerable to ID spoofing). |
| Quiet Hours & Weekly Digest | Customer App (`user_preferences`) | None (Unenforced server-side) | Edge function and crons currently ignore quiet hours and digest flags entirely. |

---

## 4. Universal Event Contract Table

All systems (Customer App, Triggers, Edge Functions, Workers, Admin UI) must adhere to this unified specification:

| Event Type (`event_type`) | Category (`category`) | Severity / Priority | Minimum Entitlement | Allowed Outbound Channels | In-App Quiet Hours | Deduplication Key Pattern | Intended Deep Link |
|---|---|---|---|---|---|---|---|
| `line_deactivation_imminent` *(New)* | `line_critical` | **Critical / Urgent** | Free, Standard, Premium | Push, WhatsApp, Telegram, Email *(entitlement-gated)* | **Bypasses in-app quiet hours** (respects OS DND) | `deactivation_48h:<sim_line_id>:<activity_cycle_token>` | `/sim-lines/detail/:id` |
| `line_critical` | `line_critical` | **Critical / Urgent** | Free, Standard, Premium | Push, WhatsApp, Telegram, Email | **Bypasses in-app quiet hours** | `line_critical:<sim_line_id>:<epoch_day>` | `/sim-lines/detail/:id` |
| `recharge_failed` | `top_up_failed` | **Urgent** | Standard, Premium | Push, WhatsApp, Telegram, Email | Respects quiet hours | `recharge_failed:<exec_id>` | `/sim-lines/detail/:id` |
| `recharge_due_today` | `top_up_reminder` | **Normal** | Free, Standard, Premium | Push, Telegram (WhatsApp if Entitled) | Respects quiet hours | `recharge_due:<sim_line_id>:<epoch_day>` | `/sim-lines/detail/:id` |
| `recharge_reminder` | `top_up_reminder` | **Normal** | Free, Standard, Premium | Push, Telegram | Respects quiet hours | `recharge_remind:<sim_line_id>:<epoch_week>` | `/sim-lines/detail/:id` |
| `recharge_date_missing` | `system` | **Low** | Free, Standard, Premium | Push | Respects quiet hours | `missing-recharge:<sim_line_id>:<cadence_bucket>` | `/sim-lines/detail/:id` |
| `wallet_low` | `wallet_low` | **Normal** | Standard, Premium | Push, Telegram | Respects quiet hours | `wallet_low:<user_id>:<epoch_day>` | `/wallet` |
| `wallet_depleted` | `wallet_depleted` | **Urgent** | Standard, Premium | Push, WhatsApp, Telegram, Email | Respects quiet hours | `wallet_depleted:<user_id>:<epoch_day>` | `/wallet` |
| `recharge_succeeded` | `top_up_success` | **Quiet / Confirmation** | Free, Standard, Premium | Push, Telegram | Respects quiet hours | `recharge_ok:<exec_id>` | `/sim-lines/detail/:id` |
| `line_added` | `system` | **Quiet / Confirmation** | Free, Standard, Premium | Push | Respects quiet hours | `line_added:<sim_line_id>` | `/sim-lines/detail/:id` |
