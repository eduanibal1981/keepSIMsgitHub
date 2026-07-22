# 7 — Full Funnel

Five stages. The funnel's defining feature is a cliff in the middle: **the first wallet deposit**. Everything upstream exists to walk people to that cliff with enough trust to step over it; everything downstream exists to multiply the value of those who did. The economic engine woven through every stage is **multi-line attach** (unit-economics: single line ≈ $2.60/yr; family manager ≈ $10.50; SME ≈ $40).

## Stage map

| Stage | Goal | Primary mechanism | Exit event | Stage KPI |
|---|---|---|---|---|
| Awareness | "My number can silently die — and it's my key" | Community seeding, creators, radio, pre-departure | Landing-page view / profile visit | Reach in target communities, LP views |
| Consideration | "This app watches it for me" | LP, ASO, SEO, community proof | App install → registration | Install→registration rate |
| Conversion | Line added → **first wallet deposit** → first refill/plan | Onboarding flow + deposit-trust design | `first_deposit_succeeded` | LP→deposit, install→first payment |
| Retention | Line stays protected; habits form | Alerts, scheduled refills, status emails | Scheduled refill enabled / Premium renewal | 30-day retention, repeat top-up |
| Referral | Users recruit their own community | Wallet-credit referral program [V17] | Referred registration → deposit | Referral CAC ≤ $1.50 |

## Awareness

Lead with the identity stake per origin (creative-brief §1 table — UPI/GCash/bKash/Raast/OTP), never with app features. Family angle is secondary and warm. Channel depth lives in section 8; the funnel rule here: awareness content must always name **one concrete consequence** (an OTP that never arrives) and **one concrete relief** (a status screen that says Active). No fear mechanics, no "you may have already lost it" (tone rules, creative-brief §5).

Multi-line thread: awareness creative for personas 1–4 shows *two* lines on the dashboard in every screenshot — the user's own and a parent's. Plant the multi-line norm before it is ever pitched.

## Consideration

One landing page per promise (Guide §7): SIM-protection page per corridor cluster, multi-line/family page, SME page. Match language to origin community (creative-brief §7). The page's job is not the install — it is *belief that monitoring works*, because that belief is what survives to the deposit screen. Show the status dashboard early; price appears before any store link ($2.50/yr framing: "less than one coffee, for the year").

## Conversion — and the first-deposit cliff, named explicitly

Sequence: register → add first line (free, instant value: status visible) → **deposit cliff** → first refill or plan purchase.

The cliff is where an anonymous app asks a cautious person for money into a wallet they've never used. Treat it as the primary CRO surface (section 10):

1. **Ask small.** Suggested first deposit = enough for one refill cycle on their carrier, not a round $20. A Pakistani-SIM user should see a first-deposit suggestion near their actual annual need.
2. **14-day refund as headline, not footnote** (creative-brief §6): "Try it. Unused balance refundable for 14 days." — exact wording, never "money-back guarantee."
3. **Price transparency before payment** (PRD): show the refill price and the 0% wallet gateway fee vs the card/PayPal fee delta [V7 caveat: no "0% fees" in app-store copy].
4. **Consent capture at the cliff** doubles as chargeback armor (12-compliance): the checkbox is a trust signal, not just a legal one.
5. **Deposit failure ≠ funnel exit:** payment-method failures in Saudi/Qatar/Kuwait are a known risk [V9]. Instrument `deposit_failed` by gateway and market from day one; a high failure rate there is a payments problem wearing a marketing costume.

Premium conversion runs only in PK / BD / EG-Vodafone/Etisalat lanes (creative-brief §3), quoting the real yearly price. Everyone else converts to Standard + scheduled.

**Multi-line thread:** the post-first-refill success screen is the single best multi-line moment in the product — "Your line is protected. Whose number matters next? Add your mother's line in 20 seconds." This prompt is a launch requirement, not a backlog item; it is where a $2.60 customer becomes a $10.50 customer at zero CAC.

## Retention

- Alert hygiene: line-critical and top-up success/failure alerts on by default; promo off by default (trust preservation, and PDPL/DPDP consent cleanliness).
- The habit to build is *checking status monthly*, not topping up — automation should make top-ups boring. "Protected" push once per cycle: "All 3 lines active. Nothing needed."
- Scheduled-refill enablement is the retention event that predicts year-2 renewal; every Standard user gets one nudge sequence toward it (day 7, day 30).
- Renewal: base fee is annual — renewal comms lead with the year of uninterrupted status history ("342 days protected") as the sunk-value proof.
- Refund-window watch: 14-day refund rate on deposits is a retention *input* — a rising rate means upstream copy is over-promising (section 11 metric).

## Referral

Referral is not a growth hack here; per unit-economics it is the **primary affordable acquisition channel** (target CAC ≤ $1.50 vs $2.60 ceiling).

- Incentive: wallet credit to the referrer (and optionally the referee's first deposit bonus) — credit is issued by KeepSIMs, never moved between users, preserving non-transferability [V17 legal token open; mechanics may not ship until closed].
- Trigger moments: post-first-successful-refill; post-"all lines active" push; Ramadan/Eid/home-leave seasonal moments.
- Segment order: Filipino OFWs first (highest referral propensity, persona 3), then blue-collar PK/BD communities (dorm/camp density makes one referrer worth dozens), then Indian professionals.
- Multi-line thread: the referral card's default framing is family — "Who keeps your parents' numbers alive?" — so referred users arrive pre-framed for multi-line.
- The `referrals` table exists and is empty: the program is buildable but unbuilt. Section 13 sequences it in the first 30 days behind V17.

## Funnel math the manager watches weekly

Install → registration → line added → **first deposit** → first refill, plus multi-line attach rate and referral share of new registrations. The deposit step will be the worst number on the board; that is expected and is the point of measuring it. Targets are set after two weeks of baseline, not invented now.
