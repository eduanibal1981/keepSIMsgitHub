# Unit Economics — Acquisition Model

**Inputs (from production DB unless noted):** Standard base fee **$2.50/line/yr** (conflict resolved 2026-07-19 — owner reset `system_configs` to $2.50; PRD, brief, and DB now agree). App fee on refills: **3%**. Premium margin: **5% ≈ $0.324/refill**. Gateway fees: wallet 0%, PayPal 3.4% + $0.49, Stripe (card) 4.5% + $0.30. Assumption: gateway fees are passed to the user per PRD pricing formula; if KeepSIMs absorbs deposit fees, subtract ~$0.80 per new customer from every figure below [VERIFY: who bears the deposit gateway fee].

Refill cadence = 365 ÷ inactivity window (conservative — never plan on grace periods).

## First-year gross contribution per line

| Corridor | Refills/yr | Typical refill (USD) | Standard contribution: base + refills × 3% | Premium contribution: base + refills × $0.324 |
|---|---|---|---|---|
| India | 2 | 3.10 | **$2.69** | blocked (04) |
| Pakistan | 2 | 0.85 | **$2.55** | **$3.15** |
| Bangladesh | 3 | 0.91 | **$2.58** | **$3.47** |
| Philippines | 3 | 5.21–8.28 | **$2.97–3.25** | blocked (04) |
| Sri Lanka | 3 | 5.29 | **$2.98** | blocked (04) |
| Egypt (Voda/Etis) | 4 | 0.54 | **$2.56** | **$3.80** |

Multipliers that actually matter: **multi-line family manager (avg 4 lines): ~$10.50–13/yr. SME (15+ lines): ~$40+/yr.** The single-line customer is a ~$2.60/yr business.

## Maximum allowable CAC at 6-month payback

Base fee and Premium prepay land on day one, so 6-month collections ≈ base + roughly half the refill margin:

| Segment | Max CAC |
|---|---|
| Single-line Standard (any corridor) | **≈ $2.60** |
| Single-line Premium (PK/BD/EG-partial) | **≈ $2.90–3.30** |
| Multi-line family (4 lines) | **≈ $10.50** |
| SME (15 lines) | **≈ $40** |

## Does paid social clear the bar? — No.

GCC CPIs on Meta/TikTok run $1.50–4.00 even for well-targeted diaspora Android audiences; install → first-payment conversion for a wallet-funded utility realistically lands at 5–15%. That puts **cost per paying customer at $10–50 against a $2.60 ceiling**. Paid social misses the bar by 4–20× in every single-line corridor, including both Tier 1 volume corridors. Premium's higher ceiling ($3.30) does not change the verdict. Multi-line and B2B clear higher bars but cannot be reliably cold-targeted on social.

**This is not a nuance. Cold paid acquisition is structurally unaffordable for this product at current pricing.**

## The budget logic — RULE FOR SESSION 2 (apply, do not re-derive)

Primary engine: **community, referral, partnership, organic.** Paid media exists only for retargeting warm traffic, Premium upsell to the installed base, and creative testing.

Total budget: **under $5,000/month** (owner-confirmed). Allocation rule:

| Share | Use | Constraint |
|---|---|---|
| 45% | Community seeding and micro-creators: WhatsApp/Facebook diaspora groups, Kerala/Tamil/Filipino/Egyptian associations, OFW organizations, diaspora radio, pre-departure channels in origin countries | Content and creator fees, not media buys |
| 20% | Referral incentives (wallet credit, never cash — see 12-compliance) | Target referral CAC ≤ $1.50 |
| 20% | Retargeting warm traffic only: site visitors, installers without a line, line-added without payment | Never cold audiences |
| 15% | Creative testing in Bahrain and Oman (low CPM), promoting origin-SIM corridors | Winners graduate to organic/community distribution, not to cold scaling |

Partnerships (exchange houses, remittance apps, hypermarkets, telecom resellers) are negotiated on rev-share or flat placement — funded outside this media budget where possible.

Kill rule: any paid activity whose measured cost per first payment exceeds 2× the segment's max CAC for two consecutive weeks is stopped, no exceptions. North-star metric stays **cost per protected active line** (per the Advertising Manager Guide).

## What would change the verdict

Any of: Premium repriced ≥ $9.99/yr with bundled value, base fee raised, multi-line attach at signup > 2 lines average, or India production catalog enabling a true mini-refill Premium. Until one of these is real and measured, Session 2 must not write a paid-media-led plan.
