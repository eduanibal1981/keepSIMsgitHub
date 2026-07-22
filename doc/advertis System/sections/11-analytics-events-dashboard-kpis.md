# 11 — Analytics, Events, Dashboard, KPIs

## North star: Cost per Protected Active Line

**A line is "protected" when ALL of the following hold:**

1. The line is added and its status is not Expired (per `sim_lines` status), AND
2. a funded protection mechanism is active for it — either (a) a scheduled refill is enabled AND the wallet balance covers at least the next scheduled refill amount, or (b) an active Premium plan covers the line, AND
3. the mechanism has not failed its most recent execution without recovery (last `topup_execution` for the line is not in unrecovered-failure state).

A line that is merely added but unfunded is *monitored*, not protected — it must not count. This definition is computable entirely server-side from existing tables (`sim_lines`, `scheduled_topups`, `wallets`, `plan_payments`, `topup_executions`).

**Cost per Protected Active Line (monthly) = total acquisition spend (all four envelopes + partnership fees) ÷ newly protected lines in the month.** Report alongside: total protected lines (stock), and protected-line churn (lines that lost protected status).

## Event schema (engineer-ready)

Server-side events are the source of truth — the architecture is already server-authoritative (RLS, SECURITY DEFINER RPCs, webhook-verified payments), so emit these from backend/edge functions, not the client. Client-side duplicates only where a platform pixel needs them (marked ◐). All events carry base properties: `user_id`, `ts`, `platform` (ios/android/web), `country_residence`, `attribution_source` (see dependency below).

| # | Event | Trigger (server truth) | Key properties |
|---|---|---|---|
| 1 | `lp_view` ◐ (client/pixel only) | landing page render | `page_slug`, `corridor`, `language`, `utm_*` |
| 2 | `app_install` ◐ (store/MMP) | first open | store, campaign ref if available |
| 3 | `registration_completed` | profile row created | `referral_code_used` (nullable) |
| 4 | `line_added` | `sim_lines` insert | `origin_country`, `carrier`, `line_index` (1st, 2nd… — powers multi-line attach) |
| 5 | `deposit_started` ◐ | checkout initiated | `gateway`, `amount_usd`, `suggested_amount_shown` |
| 6 | `deposit_succeeded` | gateway webhook verified | `gateway`, `amount_usd`, `fee_usd`, `first_deposit` (bool) |
| 7 | `deposit_failed` | webhook/timeout | `gateway`, `failure_reason`, `country_residence` — **watch Saudi/Qatar/Kuwait [V9]** |
| 8 | `refill_succeeded` | `topup_executions` success | `origin_country`, `carrier`, `amount_usd`, `type` (instant/scheduled/premium_mini), `first_refill` (bool) |
| 9 | `refill_failed_refunded` | atomic refund path | same + `refund_confirmed` |
| 10 | `scheduled_refill_enabled` | `scheduled_topups` insert/activate | `origin_country`, `carrier` |
| 11 | `premium_purchased` | `plan_payments` verified | `origin_country`, `carrier`, `price_usd` — only ever PK/BD/EG-Voda/Etisalat until 04 changes |
| 12 | `line_protected` (derived) | first time a line meets the north-star definition | `days_from_registration`, `mechanism` (scheduled/premium) |
| 13 | `line_protection_lost` (derived) | definition stops holding | `reason` (unfunded/disabled/failed/expired) |
| 14 | `deposit_refund_requested` / `deposit_refunded` | refund flow | `days_since_deposit` (must be ≤14), `amount_usd` |
| 15 | `referral_registered` / `referral_converted` | referee registers / makes first deposit | `referrer_id`, `credit_issued_usd` [V17] |
| 16 | `alert_prefs_updated`, `notification_delivered` | existing tables | category toggles — retention diagnostics |

Derived events 12–13 are computed by a nightly job, not fired inline — keep the definition in one SQL view so "protected" can never drift between dashboard and ads.

## KPI set

**Acquisition costs:** cost per install · per registration · per line added · per wallet deposit · per first successful refill · per Premium purchase · **per protected active line (north star)** · referral CAC (target ≤ $1.50).
**Conversion rates:** install→registration · registration→line-added · line-added→first-deposit (the cliff — expect this to be the worst number; that's the point) · first-payment conversion overall.
**Value & health:** 30-day retention · repeat top-up rate · CAC vs first-year value by segment (ceilings: $2.60 / $2.90–3.30 / $10.50 / $40) · **multi-line attach rate** = users with ≥2 lines ÷ users with ≥1 line (the economic lever — report weekly, next to the north star) · **14-day refund rate on deposits** (rising rate = upstream over-promising; investigate copy before investigating product) · protected-line churn.

## Weekly dashboard layout (one screen, in this order)

1. **Header band:** Cost per Protected Active Line (this month vs last) · total protected lines · multi-line attach rate.
2. **Funnel bar:** installs → registrations → lines added → first deposits → first refills, with week-over-week deltas; the deposit-cliff step visually emphasized.
3. **Envelope table:** spend vs budget by envelope (45/20/20/15) · cost per line added per envelope · kill-rule status column (green/amber/**killed**) per active campaign.
4. **Corridor split:** lines added and protected lines by origin country; Premium purchases (should only ever show PK/BD/EG — anything else is a compliance alarm, not a win).
5. **Trust panel:** deposit failure rate by gateway × residence market [V9 watch] · 14-day refund rate · refill failure/refund rate.
6. **Referral panel:** referred registrations, conversions, credit issued, referral CAC vs $1.50.

Build in whatever BI the team has (a Supabase-backed Metabase/Looker Studio works); the layout is the requirement, the tool is not.

## Attribution — open dependency, flagged

Attributing a *downstream server event* (first deposit, first refill) back to a *click* is unsolved in the current stack: no MMP is integrated, and iOS ATT limits deterministic install attribution regardless.

- **Minimum viable attribution (build in week one, per section 13):** first-party, server-side — every LP link carries UTM + corridor code; registration stores `attribution_source` from install referrer (Android) / deferred link where available; referral codes and partner promo codes attribute community and partnership sources; BH/OM test cells read platform-reported CPI but convert on server events via UTM-linked registrations.
- **Accepted imprecision:** iOS paid attribution will be directional. Acceptable at this budget because paid is retargeting-scoped; community/referral/partner sources attribute cleanly via codes.
- **Hard statement for section 13:** if `attribution_source` capture is not live before spend starts, the kill rule and the north star are both unmeasurable — tracking setup is a week-one launch gate, not a parallel task. [Flagged in flags.md]
