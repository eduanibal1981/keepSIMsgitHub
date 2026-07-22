# 12 — Compliance and Claims

## Commercial structure — FIXED, reproduce exactly

1. **KeepSIMs acts as principal.** It buys airtime from its aggregator (currently Zendit only — see 04) and resells it as its own product. It is **not** an agent transmitting user funds to a carrier and must never be described as one, in any language, in any market.
2. **The wallet is non-transferable prepaid credit**, redeemable only for KeepSIMs services. It is never cashed out, assigned, or transferred between users.
3. **User-to-user balance transfer is not offered** and must never be implied in creative, feature lists, screenshots, app-store copy, FAQ, or roadmap language.
4. **Refund policy:** wallet balance not yet used for a refill is refundable within 14 days of deposit. After 14 days, or once used, non-refundable.

## Banned and preferred terms

Once structured as principal-reseller, the fastest way to lose that position is your own marketing copy — a regulator reads the ad, not the terms of service. This list is reproduced verbatim in creative-brief.md and applies to every language in the matrix, including translations that back-translate into a banned meaning.

| BANNED — never use | PREFERRED — use instead |
|---|---|
| "send money" | "top up" |
| "transfer" (of money/credit) | "refill" |
| "remittance" | "prepaid credit" |
| "wallet-to-wallet" | "account balance" |
| "e-wallet" | "fund your account" |
| "stored value" | "prepaid credit" |

Also banned by extension: "cash out," "withdraw," "pay anyone," "money for your family," and any imagery of cash changing hands. "Top up a relative's number" is permitted (it is airtime delivery to a line, not funds to a person) — but pair it with "airtime, not money" framing wherever family creative runs.

## Syria — current position (not historical)

Product reality first: **Syria has zero coverage in the production database** (see 04). The brief's claim that the corridor is "live in-product via DoctorSIM" is contradicted by the data; there is no DoctorSIM integration at all. So the operative position is simply: **not supported, not advertised, no promise of support.**

Legal posture, stated so nobody repeats stale framing: U.S. sanctions on Syria were removed effective 1 July 2025; the Syrian Sanctions Regulations were struck from the CFR in August 2025; the Caesar Act was repealed in December 2025. The EU lifted almost all sectoral economic sanctions in May 2025 (delisting telecoms entities among others) and the UK lifted comparable measures. **Syria is not country-embargoed.** What remains is party-based — Assad-linked persons and entities, Makhlouf-family designations, human-rights and HTS-related listings — so counterparty screening obligations persist for any future aggregator or carrier relationship. Syria's State Sponsor of Terrorism designation: [VERIFY: current SST status — source: U.S. State Department]. Do not write pre-2025 embargo framing into any document.

If coverage lands later, hold Syria from paid acquisition anyway for commercial reasons — merchant-of-record acceptable-use restrictions and slow banking de-risking — and use the Tier 3 re-entry checklist in 04. Organic/community only, no paid creative.

## Wallet characterization — UAE and Saudi Arabia

What keeps KeepSIMs outside e-money/stored-value licensing (UAE Central Bank Stored Value Facilities framework; SAMA payments licensing):

- Principal-reseller structure: deposits are prepayment for KeepSIMs' own product, not funds held for transmission.
- Non-transferability: no P2P movement, no cash-out, single redeemer (KeepSIMs itself).
- Closed-loop redemption: credit buys only KeepSIMs services.

What would break the position: adding user-to-user transfer, cash-out, redemption at third parties, or marketing that describes the wallet as a money account. **The 14-day refund window is the one factor pulling back toward the e-money definition** (limited redeemability into fiat) — flag for payments-counsel review in both markets before launch; do not silently extend the window or add refund-to-different-instrument options.

Residual optics: "top up a relative's number abroad" resembles cross-border remittance to a lay regulator even though it is airtime delivery. Mitigation: banned-terms discipline, "airtime, not money" framing, and receipts that name the carrier product delivered.

## Chargeback exposure

Card schemes do not defer to "non-refundable" terms. Required at build, not later:

- **Pre-purchase consent capture:** explicit checkbox/acknowledgment of the 14-day refund rule and instant-delivery nature of refills, logged with timestamp, at first deposit and first refill.
- **Receipting:** every deposit and refill emails/app-logs a receipt naming amount, line, carrier, and delivery status.
- **Delivery evidence:** archive aggregator delivery confirmations (transaction ID, carrier response) per refill; atomic-refund records for failures. This is the representment file.
- Descriptor: card statement text must say KEEPSIMS clearly to cut "unrecognized charge" disputes.

## App-store treatment of wallet deposits

Open, material risk: whether Apple and Google class wallet deposits as IAP subject to 15–30% commission. If yes, the "0% gateway fees" wallet positioning and the entire margin model in unit-economics break. [VERIFY: written position or counsel opinion on IAP applicability for (a) wallet deposits, (b) Premium plan purchase, (c) Standard base fee — Apple App Review Guidelines 3.1.1 vs physical-goods/services carve-out 3.1.5(a); Google Play Payments policy equivalent.] Airtime delivered to a physical SIM is a strong "consumed outside the app" argument, but neither store applies it predictably. Until closed: do not put "0% fees" in app-store listing copy, and route Premium/deposit flows per counsel guidance.

## Ad platform category classification

Wallet + prepaid credit language will likely trip **financial-services ad classification**:

- **Meta:** may require Financial Products & Services special ad category acknowledgment; expect stricter targeting limits if flagged.
- **TikTok:** financial services policies require pre-approval/registration for money-adjacent products in several GCC markets.
- **Snapchat:** financial services policy — disclosure requirements.
- **Google:** "Financial products and services" verification program may apply to wallet framing; airtime top-up alone usually escapes it — another reason banned-terms discipline matters.

Action: submit one representative creative per platform for policy pre-review before the calendar depends on it. [VERIFY: per-platform ruling for KeepSIMs' actual creative.]

## Data protection

- **Saudi PDPL:** consent-based processing, breach notification, cross-border transfer conditions; marketing consent must be explicit and withdrawable.
- **UAE PDPL (Federal Decree-Law 45/2021):** similar consent + purpose limitation; note free-zone regimes (DIFC/ADGM) if entities sit there.
- **India DPDP Act 2023:** applies to processing Indian users' data; consent notices in plain language; significant penalties.
- **Philippines Data Privacy Act:** NPC registration thresholds; marketing consent rules.
- Practical rule for Session 2: every lead-gen or retargeting tactic must name its lawful basis and consent capture point. Phone numbers of *other people* (family lines added by a user) are personal data the user supplies — cover in privacy notice.

## GCC advertising and telecom-marketing rules

- SMS/WhatsApp marketing in Saudi and UAE requires prior opt-in and sender registration (CST in Saudi, TDRA in UAE); no cold WhatsApp blasts — community seeding must be admin-invited content, not unsolicited messaging.
- Arabic-language availability of key terms (price, refund) is expected for consumer contracts in Saudi.
- No carrier logos, names-as-endorsement, or "official partner" implications anywhere (Guide §11 reaffirmed).
- Qatar/Kuwait/Bahrain/Oman: lighter but present e-commerce disclosure rules — price clarity before payment suffices if the landing flow already complies with the Guide's §7 structure.

## Prohibited claims (all markets, all languages)

Universal carrier support; guaranteed successful refill; guaranteed prevention of deactivation; carrier affiliation or endorsement; operation in any unverified region; any statement of a carrier's inactivity threshold, grace period, or reactivation rule as fact (must carry [VERIFY] until sourced); "0% fees" without the gateway-fee qualifier and IAP resolution.
