# 13 — 30/60/90-Day Launch Plan

Sequenced around the verification register. **Gate principle: nothing ships that depends on an unclosed V-token.** The gate table below is the authority; the calendar bends to it, never the reverse.

## Gate table — what cannot ship until which token closes

| Blocked activity | Blocking token(s) | Interim behaviour |
|---|---|---|
| ANY paid spend (kill rule + north star need attribution) | Attribution capture live (§11, flags F1) | Community/organic only |
| Paid ads on any platform | V14 platform pre-approval (per platform) | Submit representative creative day 1–5 |
| Ad geo-targeting list | V6 app-store live regions | No geo assumed live until screenshot evidence |
| "0% fees" in app-store copy; deposit flow certainty | V7 IAP treatment | Wallet claims per creative-brief §9 caveat |
| Conversion pushes in Saudi, Qatar, Kuwait | V9 payment-method availability | Awareness/community fine; deposit-dependent CTAs held; `deposit_failed` monitoring from day 1 |
| Premium creative anywhere (incl. PK/BD/EG-partial) | V11 published Premium price card | Premium messaging held until a real price is quotable |
| Premium creative for India | V19 DTone live + 04 re-run | Standard-only India creative |
| Referral program launch | V17 counsel note + built flow | Referral copy drafted, not live |
| Non-English creative at scale | V15 app locale list | Ship with app-language caveat line |
| SME/B2B promises | V16 invoicing/VAT capability | Founder outreach only, no public B2B claims |
| Any Nepal/Lebanon/Iraq/Syria asset | V5 + 04 re-entry checklist | Nothing. Not "coming soon" either |

## Days 1–30 — Foundation (spend: community envelope only until gates clear)

**Week 1 — tracking before anything (hard gate):**
- Implement §11 event schema server-side; `attribution_source` capture on registration; UTM/promo-code plumbing; protected-line SQL view + nightly job.
- Submit one representative creative per platform for policy review [V14]. Collect V6 evidence (store screenshots). Chase V7 (counsel), V9 (live test deposits from KSA/QA/KW), V11 (price card), V15 (locale list).
- Landing pages: SIM-protection page (English + one per Tier 1 corridor language as locales allow) and multi-line/family page, built to Guide §7 order with 14-day-refund line at the deposit explanation.
- Community mapping doc: 20 groups per corridor (section 8A). Begin admin outreach — value-first, no promotion yet.

**Weeks 2–4:**
- Seeding begins in mapped groups (2 assets/week/corridor from creative library).
- First 2–3 micro-creators briefed (Indian professional + OFW corridors first — Standard-only messaging, so no V11 dependency).
- Referral build proceeds behind V17; copy and card designs ready to flip on.
- If attribution live + V14 cleared: retargeting audiences start populating (no spend yet — pixels and audience definitions only).
- Baseline dashboard live by day 30 even with tiny numbers.

**Day-30 exit criteria:** events verified end-to-end on real transactions; ≥10 community placements live; LPs converting measurably; V14 outcomes known per platform; V9 verdict known per market.

## Days 31–60 — Ignition

- **Retargeting on** (20% envelope) — only for platforms with V14 cleared and only against populated warm audiences. Deposit-cliff audience gets ~half.
- **BH/OM test cells round 1** (15% envelope): hook test per section 9; two-week cells.
- **Referral launches** if V17 closed — OFW segment first; wallet-credit incentive live; referral CAC tracked from day one.
- Community expands: exchange-house/hypermarket pilot placements (2–3 locations, promo-coded); first radio test if budget allows.
- **Premium messaging begins ONLY if V11 closed:** PK/BD corridors, Urdu/Bengali community assets quoting the real yearly price. EG-Vodafone/Etisalat carrier-aware assets follow.
- Weekly kill-rule review starts the first week any paid runs.

**Day-60 exit criteria:** cost per line added known per envelope; deposit-cliff conversion baseline set; test round 1 winner identified; referral CAC first read; no kill-rule violations ignored.

## Days 61–90 — Optimize and compound

- Test round 2 (language A/B) and round 3 (deposit-trust framing); winners graduate to community assets and LP copy.
- Retargeting creative refreshed from test winners; Premium retargeting variant (PK/BD line-holders) if server audience export works.
- Referral extends to PK/BD blue-collar communities; family-framed cards to persona 1.
- Multi-line push: post-first-refill "add your mother's line" prompt measured; multi-line attach rate becomes a weekly headline number.
- SEO: first 6 articles live (English), Malayalam + Tagalog tracks started per seo-plan.md.
- **Day-90 review against unit-economics:** blended CAC vs $2.60/$10.50 ceilings by segment; envelope reallocation decision (within rails); Premium attach read in PK/BD; if V19 (DTone) closed during the quarter, re-run 04 + unit-economics and open India Premium creative only after both are updated.

## Standing rules across all 90 days

The kill rule runs from the first paid dollar. The north star is reported weekly from day 30 even while noisy. No date on this calendar overrides a gate. If a gate slips, the dependent activity slips — the document does not get reinterpreted to unblock it.
