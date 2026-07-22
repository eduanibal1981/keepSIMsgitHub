# 00 — Inputs Required

> **STATUS UPDATE 2026-07-19 (read this first):** Items 1, 2, 3, 5, 8, 9, 13 were closed by pulling the production database directly (carriers, carrier_rules, zendit_offers_cache, system_configs, payment_gateways) — results in 04-corridors-and-coverage.md. Item 4 (budget): owner confirmed **under $5k/month**. Items 6, 7, 10, 11, 12, 14 remain open and now live as tokens V6, V7, V11/V15/V17, etc. in verification-register.md, which supersedes the tables below. The original text is kept for the record only.

Facts I cannot derive from the PRD or Advertising Manager Guide. Nothing downstream is trustworthy until the **Blocking** items are answered. Where an answer is missing at build time, the affected cell will carry a `[VERIFY]` token instead of a guess.

## ⚠ Attachment discrepancy — resolve first

The file uploaded as **"aggregator coverage exports" contains the Advertising Manager Guide, not coverage data.** No aggregator export was actually received. This blocks the entire coverage matrix in 04, the mini-refill viability analysis, and the Premium constraint list in creative-brief.md. Please re-upload the real exports (Reloadly, DoctorSIM, Zendit).

## Blocking — cannot build 04 / unit-economics without these

| # | Input | Why it's needed | Blocks |
|---|---|---|---|
| 1 | Per-aggregator coverage exports: origin country × carrier, live status, **minimum denomination** per product | Coverage matrix; decides where Premium auto-mini-refill is even possible | 04, creative-brief |
| 2 | Gross margin per refill, by corridor (or the app-fee % / margin table from `system_configs`) | First-year value model; max CAC derivation | unit-economics |
| 3 | Premium plan price — and whether it varies by corridor (it bundles prepaid mini-refills, so cost base differs per carrier) | ARPU model; Premium ad economics | unit-economics, creative-brief |
| 4 | Total monthly ad budget (and any per-market caps) | Budget logic Session 2 must apply | unit-economics, creative-brief |
| 5 | Keep-alive amount required per carrier, as currently operated (your `carrier_rules` data), even if unverified against carrier policy | Mini-refill viability column: min denomination vs keep-alive amount | 04, creative-brief |

## Blocking — compliance and platform posture

| # | Input | Why it's needed |
|---|---|---|
| 6 | App-store live regions: exact Apple App Store + Google Play storefronts where the app is published | Ad geo-targeting must not outrun store availability |
| 7 | Apple/Google treatment of wallet deposits: has anyone confirmed whether deposits are exempt from IAP (real-world-goods carve-out) or treated as IAP at 15–30%? Any App Review correspondence counts as evidence | Material risk to "0% gateway fees" claim and the whole margin model |
| 8 | Live payment gateways per residence market. PRD names only PayPal — PayPal consumer availability in Saudi Arabia and Qatar is limited. What do Saudi/Qatar/Kuwait users actually pay with today? | Conversion claims and funnel design per market |

## Needed before Session 2 (assumptions used meanwhile, flagged as such)

| # | Input | Fallback if unanswered |
|---|---|---|
| 9 | Aggregator roster confirmation: PRD's pricing engine references only a Zendit catalog; the brief states Reloadly + DoctorSIM + Zendit. Which are live in production vs contracted vs planned? | Treat all three as live per brief; flag in verification-register |
| 10 | Expected refills/user/year and Premium attach rate, if any real data exists | I will state modelled assumptions per segment and mark them |
| 11 | In-app language support (localization actually shipped) | Language matrix will note that ad language must not outrun app language; English/Arabic assumed minimum |
| 12 | Referral program: does one exist, and with what incentive? | Modelled as "recommended build," not as live |
| 13 | SME/B2B pricing: any volume tier beyond $2.50/line/yr? | B2B persona priced at standard rates |
| 14 | Launch timing per residence market | Assumed simultaneous GCC launch |

**Answer format that works fine:** short bullets, or just re-upload the exports and answer 2–8 inline. Then I build the remaining six files.
