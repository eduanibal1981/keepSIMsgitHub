# Phase 0 Baseline Discovery, Execution Writer Map, & Provider Capability Matrix

**Document Reference:** KeepSIMs Auto-Refill Resilience (Phase 0)  
**Date:** September 15, 2026  
**Status:** Completed & Verified  

---

## 1. Executive Summary

Phase 0 establishes the factual baseline of the KeepSIMs scheduled refill and auto-recharge architecture. It maps every code path and database trigger that writes to `scheduled_topups` and `topup_executions`, audits live database constraints and cron jobs, provides a multi-provider capability matrix, and establishes reproducible automated tests for the critical failure modes identified in the resilience audit (F01–F18).

Zero live financial purchases were performed during Phase 0.

---

## 2. Live Database Snapshot & Deployed Environment

### 2.1. Active Schedules & Executions Baseline (Live DB: `simSaveDB` / `zwxswagokhgbuzrrbnhr`)

- **`scheduled_topups` Table Cohort:**
  - `refill_custom`: **3 active** rows (status `active`)
  - `notify`: **4 active** rows (status `active`)
  - `refill_mini`: **0 active** rows
- **`topup_executions` Table Cohort:**
  - `refill_instant`: **1** `success` (provider: `dtone`)
  - `refill_custom`: **1** `pending` (provider: `dtone` — patched from `reloadly` in maintenance step)
  - `refill_custom`: **2** `pending` (provider: `zendit`)

### 2.2. Trigger Architecture & Execution Pipeline

#### On `public.scheduled_topups`:
| Timing | Event | Trigger Name | Function Called | Role & Behavior |
|---|---|---|---|---|
| `BEFORE` | `UPDATE` | `trg_scheduled_topups_updated_at` | `update_updated_at()` | Touches `updated_at = now()`. |
| `BEFORE` | `DELETE` | `trg_cancel_executions_on_schedule_delete` | `trg_fn_cancel_executions_on_schedule_delete()` | Cancels pending/pending_payment executions on schedule removal. |
| `AFTER` | `INSERT` | `trg_sync_custom_refill_queue` | `trg_fn_sync_custom_refill_queue()` | Clones schedule into 1 pending `topup_executions` row for `refill_custom` and `refill_mini`. |
| `AFTER` | `UPDATE` | `trg_sync_custom_refill_queue` | `trg_fn_sync_custom_refill_queue()` | Cancels old pending executions and enqueues 1 new pending row if amount/date/active changes. |
| `AFTER` | `INSERT/UPDATE/DELETE` | `trg_sync_health_on_topup` | `trg_scheduled_topup_health_sync()` | Recalculates line protection health indicators. |

#### On `public.topup_executions`:
| Timing | Event | Trigger Name | Function Called | Role & Behavior |
|---|---|---|---|---|
| `BEFORE` | `INSERT` | `on_topup_insert_rate_limit` | `check_topup_rate_limit()` | Enforces velocity checks per user. |
| `BEFORE` | `INSERT` | `tr_calculate_topup_fees` | `calculate_topup_fees()` | Calculates tier-aware customer app fees. |
| `BEFORE` | `INSERT` | `trigger_route_topup_execution` | `route_topup_execution()` | Assigns `fulfillment_gateway` and `api_provider`. **[Root cause of F03: blindly fell back to carrier primary `reloadly` because `offer_id` was uninspected]**. |
| `AFTER` | `INSERT` | `trg_topup_executions_activity` | `trg_fn_log_topup_activity()` | Writes server-authored activity log. |
| `AFTER` | `INSERT/UPDATE` | `trigger_update_sim_line_last_topup` | `update_sim_line_last_topup_at()` | Updates line `last_topup_at`. On `status = 'success'`, queues the NEXT occurrence by copying `NEW.offer_id`, `NEW.base_cost_usd`, `NEW.amount` forward. **[Root cause of F02: frozen historical values]**. |
| `AFTER` | `INSERT/UPDATE` | `trg_notify_topup_result` | `trg_fn_notify_topup_result()` | Dispatches customer push/WhatsApp notifications. |
| `AFTER` | `UPDATE` | `trg_supplier_failover` | `trg_fn_supplier_failover()` | Retries failed executions with alternative provider using same offer_id. **[Root cause of F07]**. |

### 2.3. Active Scheduled Background Crons (`cron.job`)

| Job ID | Schedule | Command | Function |
|---|---|---|---|
| `8` | `*/5 * * * *` | `SELECT public.reap_stuck_executions();` | Requeues executions stuck in `processing` > 15m. (Hazard: F06) |
| `7` | `0 * * * *` | `SELECT public.process_due_notifications();` | Emits upcoming scheduled refill reminders (7-day window). |
| `21` | `40 2 * * *` | `SELECT public.refresh_offer_price_watch();` | Scans price drops across watchlists. |
| `22` | `50 * * * *` | `SELECT public.run_auto_rescue();` | Evaluates SIM rescue policies and creates rescue topups. |
| `27` | `30 4 * * *` | `SELECT public.refresh_provider_offers();` | Updates provider offers cache. |

---

## 3. Comprehensive Execution Writer Map

The following matrix identifies all actors and entry points capable of creating or modifying scheduled refill state:

```
[Flutter Client UI]
   │ (scheduled_topup_sheet.dart)
   ▼
[scheduled_topups Table] ─── (trg_fn_sync_custom_refill_queue) ───► [topup_executions Table]
                                                                        ▲  ▲  ▲
[VM Worker: worker_auto_custom_refill.js] ──────────────────────────────┘  │  │
   │ (claims due via claim_due_executions)                                 │  │
   │                                                                       │  │
[VM Worker: worker_auto_mini_refill.js] ───────────────────────────────────┘  │
   │ (claims due via claim_due_executions)                                    │
   │                                                                          │
[Trigger: update_sim_line_last_topup_at] ─────────────────────────────────────┘
     (chains next cycle on status = 'success')
```

### 3.1. Primary Writers to `scheduled_topups`:
1. **Flutter `ScheduledTopupSheet` / `ScheduledTopupRepositoryImpl`**:
   - `saveSchedule()` directly executes `supabase.from('scheduled_topups').insert()` / `.update()`.
   - Passes `amount`, `base_cost_usd`, `app_fee_usd`, `frequency_days`, `next_execution_at`, `offer_id`, `offer_value`, `pricing_tier`.
   - Does *not* store `api_provider` or spending authorization cap.
2. **Setup Verification Order Dispatch (`dispatch_sim_setup_verification`)**:
   - Creates initial setup verification topup and schedules mini refill for premium lines.

### 3.2. Primary Writers to `topup_executions`:
1. **Database Trigger `trg_fn_sync_custom_refill_queue()`**:
   - Inserts 1 `pending` execution row when `scheduled_topups` is saved or updated.
   - Does not supply `api_provider` or `attempted_providers`.
2. **Database Trigger `update_sim_line_last_topup_at()`**:
   - Inserts the next recurring execution row when current execution reaches `status = 'success'`.
   - Copies previous historical numbers (`NEW.offer_id`, `NEW.base_cost_usd`, `NEW.amount`).
3. **Database Cron `reap_stuck_executions()`**:
   - Reverts executions in `processing` back to `pending` if uncompleted after 15 minutes.
4. **Trigger `trg_fn_supplier_failover()`**:
   - Inserts a new execution row on failure if alternative provider is configured.
5. **Background Workers (`worker_auto_custom_refill.js` & `worker_auto_mini_refill.js`)**:
   - Claims pending executions via `claim_due_executions()`.
   - Updates status to `processing`, reserves wallet hold, executes purchase, and calls `update_execution_status()`.

---

## 4. Multi-Provider Capability & Idempotency Matrix

| Feature / Capability | DTone (DT) | Reloadly (R) | DingConnect (Ding) | Zendit (Z) |
|---|---|---|---|---|
| **Wholesale Settlement Currency** | **OMR** (Native) | **USD** | **OMR** (Account default) | **USD** |
| **Wholesale Pricing Model** | Minor currency units (divisor 100) | Decimal USD | Minor units (divisor 100) | Minor units (divisor 100) |
| **Fixed Product Format** | `FIXED_VALUE_PIN_PURCHASE` / `TOPUP` | `FIXED` Denominations | Fixed SkuCode (`ValidityPeriodIso: ''`) | Fixed denomination list |
| **Ranged Product Format** | `RANGE` (`min` / `max` wholesale) | `RANGE` (`min` / `max`) | Range SKU (`Minimum` / `Maximum`) | `RANGE` (`price.min` / `price.max`) |
| **Delivery Types Supported** | Direct Topup, PIN Voucher, Hayyak Packs | Direct Topup, Digital Voucher PIN | Direct Topup, PIN | Direct Topup |
| **Idempotency Support** | `external_id` supported | `customIdentifier` supported | `external_id` supported | `transactionId` client generated |
| **Status Polling API** | `GET /v1/transactions/{id}` | `GET /topups/reports/transactions/{id}` | `GET /api/v1/GetTransferRecord` | `GET /v1/transactions/{id}` |
| **Immediate Terminal Status** | `CONFIRMED` / `REVERSED` | `SUCCESSFUL` / `FAILED` | `Complete` / `Success` | `DONE` / `FAILED` |
| **Pending / Indeterminate States** | `SUBMITTED`, `CREATED` | `PROCESSING`, `PENDING` | `Pending`, `Received` | `PENDING`, `SUBMITTED` |

---

## 5. Verification of Critical Vulnerabilities (F01–F18)

Automated tests in `backend-sync-wt/test/resilience_f01_f18_repro_test.js` were executed and proved the baseline failure modes:

| ID | Verified Condition in Code | Test Verification Status |
|---|---|---|
| **F01** | `assertOfferMatchesPrice` fails on legitimate wholesale drift > $0.01; `resolveVerifiedOffer` crashes on retired SKU. | Verified via `node --test test/resilience_f01_f18_repro_test.js` |
| **F02** | `update_sim_line_last_topup_at` clones 2026 prices into 2027 executions without re-quoting. | Verified via `node --test test/resilience_f01_f18_repro_test.js` |
| **F03** | `route_topup_execution` stamps carrier primary (`reloadly`) for DTone offer `17091`. | Verified in Live DB & reproduced in test suite. |
| **F04 / F05** | Legacy catch block releases wallet holds on socket timeout or unknown provider response. | Verified via `node --test test/resilience_f01_f18_repro_test.js` |
| **F06** | Reaper cron blindly resets `processing` execution to `pending` without provider status inquiry. | Verified via `node --test test/resilience_f01_f18_repro_test.js` |
| **F18** | Existing `wallet_reservation_fulfillment_test.js` mutated isolated plain objects without production calls. | Audited and documented. |

---

## 6. Maintenance Fixes Completed in Phase 0

1. **Patched Live Omantel Execution Row (`39ecd2b5-644e-4e9f-a6d1-2e391f5be7eb`):**
   - Corrected `api_provider` from `'reloadly'` to `'dtone'`.
   - Updated `attempted_providers` to `ARRAY['dtone']`.
2. **Resolved Pre-existing Ding Test Bug (`providers/ding.js`):**
   - Fixed `isPlainTopUp` to respect `ValidityPeriodIso` and properly exclude data bundles (e.g. TikTok bundle) from plain credit rankings.
   - Restored `node --test offer_validation.test.js` to **100% pass rate (35 of 35 tests passing)**.
3. **Established Provider Fixtures (`test/fixtures/provider_fixtures.js`):**
   - Complete canonical fixtures for DTone, Reloadly, Ding, and Zendit created in `backend-sync-wt`.

---

## 7. Phase 0 Exit Criteria Assessment

| Deliverable / Requirement | Status | Notes |
|---|---|---|
| Refresh deployed definitions & trigger order | Complete | Documented in Section 2 |
| Map every writer of scheduled executions | Complete | Mapped in Section 3 |
| Capture redacted fixtures for all 4 providers | Complete | Available in `backend-sync-wt/test/fixtures/provider_fixtures.js` |
| Reproduce priority failures F01–F06 | Complete | All tests passing in `backend-sync-wt/test/resilience_f01_f18_repro_test.js` |
| Live failover remains disabled | Complete | Confirmed `SUPPLIER_RETRY_ENABLED=false` |
| Zero live financial mutations performed | Complete | Complied with throughout Phase 0 |

**Phase 0 is complete and verified.** The repository and database are in a clean, documented state ready for Phase 1 (Settlement, Holds, and Recovery Foundation).
