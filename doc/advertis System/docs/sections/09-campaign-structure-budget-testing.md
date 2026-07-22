# 9 — Campaign Structure, Budget Allocation, Testing

Everything here operates inside two fixed rails from unit-economics: total spend **< $5,000/month**, and the **kill rule** — any paid activity whose measured cost per first payment exceeds 2× the segment's max CAC for two consecutive weeks stops, no exceptions, no "one more week."

## Monthly budget (at $5,000 reference; scale proportionally if less)

| Envelope | $/mo | Contents |
|---|---|---|
| Community & creators (45%) | $2,250 | Admin partnerships (cap $150/group), micro-creators ($100–300 each, 4–6/mo), radio test (quarterly), seeding content production |
| Referral incentives (20%) | $1,000 | Wallet-credit pool [V17 gate]; unused rolls over — it is demand-driven, not spend-to-zero |
| Warm retargeting (20%) | $1,000 | Meta primary; Google brand+intent search inside this envelope |
| BH/OM creative tests (15%) | $750 | Meta primary, TikTok secondary; Snapchat only if envelope unspent |

Rollover rule: underspend rolls forward within its own envelope for one month, then returns to community. Never reallocate *into* paid from community — the asymmetry is deliberate.

## Campaign architecture

Naming convention (enforced — reporting depends on it):
`[envelope]_[persona]_[corridor]_[language]_[plan]_[objective]`
e.g. `RTG_p3_PH-UAE_tl_std_deposit` or `TEST_p2_PK-BH_ur_prem_hook-A`.

### Retargeting envelope (always-on)

Three audiences, three jobs, strict exclusions of each downstream state:

1. **Visitors, no install** (LP pixel, 14-day window) → objective: install. Creative: status-dashboard proof.
2. **Installed, no line added** (7/30-day) → objective: line added. Creative: "20 seconds to see your line's status."
3. **Line added, no deposit/schedule** (7/30-day) → objective: first deposit. Creative: 14-day-refund headline (creative-brief §6) + small-ask deposit framing. This audience gets ~half the retargeting budget — it sits on the cliff.

Premium retargeting variant only for PK/BD/EG-Voda-Etisalat line-holders (server audience export — needs event schema live, section 11). Always exclude depositors from acquisition-objective ads (Guide §12).

### Test envelope (BH/OM lab)

Structured experiments, one variable each, two-week cells:

- Round 1: hook — identity-stake ("OTP that never came") vs family-warm vs price-anchor ($2.50/yr).
- Round 2: language A/B within corridor (English vs Malayalam for India-corridor; English vs Tagalog for PH).
- Round 3: deposit-trust framing — refund-headline vs price-transparency-headline.
- Decision threshold: ≥ 2,000 impressions/cell and ≥ 50 clicks before judging; winners feed §A community assets. Never scale a test cell in place.

### Community envelope (not campaigns, but tracked like them)

Each group/creator engagement gets the naming convention and a promo code or referral-style link so §11 can compute per-source cost per line added. No trackable link → no renewal of that partnership.

## Testing discipline

- One variable per test. Hooks before formats, formats before colors.
- Weekly review, biweekly decision; nothing is judged in under two weeks (small budgets need patience for significance).
- A "winner" must beat control on **cost per line added**, not CTR. CTR winners that lose on line-adds are seeding-bait, not ads.
- Log every test in a running sheet: hypothesis, cell, spend, result, decision. The Opus-drafted weekly checklist (section 14) references this sheet.

## The kill rule, operationalized

| Segment | Max CAC (unit-economics) | Kill threshold (2×, per first payment) |
|---|---|---|
| Single-line Standard | $2.60 | $5.20 |
| Premium PK/BD/EG-partial | $2.90–3.30 | $5.80–6.60 |
| Multi-line family | $10.50 | $21.00 |
| SME | $40 | $80 |

Measured weekly per campaign from the §11 dashboard. Two consecutive weeks over threshold → paused same day, budget returns to its envelope. If attribution isn't live yet [flags.md], the kill rule cannot run — which is why section 13 puts tracking in week one, before any paid spend.

## What the manager does NOT do

No new channels mid-month; no cold audiences "just to test"; no raising the deposit ask to juice revenue per payer (it deepens the cliff); no spending the referral pool on media. Escalation path for any exception: flags.md → founder decision, in writing.
