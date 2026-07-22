# Verification Register

Rules for every session and every asset:
- Never state a carrier's inactivity threshold, grace period, or reactivation rule as fact. Write `[VERIFY: <question> — source: <carrier> official policy]`.
- Never claim KeepSIMs supports a country or carrier beyond what 04 shows live. Write `[VERIFY: coverage confirmed via <aggregator> for <country>/<carrier>]`.
- Session 2 reproduces open tokens verbatim; it never closes one.

| # | Token | Owner | Evidence that closes it |
|---|---|---|---|
| V1 | [VERIFY: production Zendit catalog for India — are small denominations (₹10–99 equiv.) available? Cache shows sandbox-pinned rows: Jio $17 min, Airtel $9 min] | Product/eng (abdalla) | Production API pull of `/offers` for IN; refreshed `zendit_offers_cache`; if small denoms exist, re-run 04 India verdict |
| V2 | [VERIFY: all sandbox-pinned carrier_rules rows (notes contain "pinned from Zendit sandbox catalog"): VODAFONEIDEA_IN_7_FEE, ZONG_PK_OPEN, ETISALAT_EG_001, plus US/TR rows)] | Product/eng | Same production pull; `last_verified_at` updated |
| V3 | [VERIFY: every carrier inactivity_limit_days / grace_period_days in carrier_rules — all 49 rows have `last_verified_at` null or sandbox-dated — source: each carrier's published prepaid policy] | Ops | Archived link/screenshot of carrier policy per row; date-stamped |
| V4 | [VERIFY: keep-alive amount per carrier — does the minimum reactivating top-up equal `recommended_topup_amount`? — source: carrier policy] | Ops | Same as V3; also one live test top-up per Tier 1 carrier |
| V5 | [VERIFY: coverage via any aggregator for Lebanon, Nepal, Iraq, Syria] | Founder/BD | Signed aggregator scope + carriers/rules/offers rows live in production DB (04 re-entry checklist) |
| V6 | [VERIFY: app-store live regions — exact Apple + Google storefronts] | Founder | App Store Connect / Play Console screenshots; ad geo-targeting limited to this list |
| V7 | [VERIFY: Apple/Google IAP treatment of (a) wallet deposits (b) Premium purchase (c) base fee] | Counsel + founder | Written counsel opinion or App Review correspondence; until closed, no "0% fees" in store copy and margin model carries the risk note |
| V8 | [VERIFY: who bears deposit gateway fees (PayPal 3.4%+$0.49 / Stripe 4.5%+$0.30) — user or KeepSIMs?] | Product | Pricing engine config + checkout screenshot; unit-economics adjusts if absorbed |
| V9 | [VERIFY: PayPal and Stripe consumer availability/acceptance in Saudi Arabia, Qatar, Kuwait — PayPal consumer coverage there is historically limited] | Founder | Successful live deposit from each market or gateway documentation; if blocked, add local method (mada, STC Pay, etc.) before advertising that market |
| V10 | ~~BASE_SERVICE_FEE_USD conflict~~ **CLOSED 2026-07-19**: owner reset system_configs to $2.50; PRD and DB now agree | Founder | Done |
| V11 | [VERIFY: Premium plan retail price per corridor — derived, not yet a published price] | Founder | Published price card; unit-economics Premium rows re-checked |
| V12 | [VERIFY: Egypt Vodafone rule row — 86-day validity, 0-day grace, no keep-alive amount — anomalous vs other EG carriers] | Ops | Carrier policy source; corrected row |
| V13 | [VERIFY: Syria SST (State Sponsor of Terrorism) designation status — source: U.S. State Department] | Counsel | Current designation list citation; 12-compliance updated |
| V14 | [VERIFY: financial-services ad category rulings for actual KeepSIMs creative on Meta, TikTok, Snapchat, Google] | Marketing | Platform pre-review outcomes per platform |
| V15 | [VERIFY: in-app locale support — which of the creative-brief languages the app ships] | Product | Build locale list; language matrix trimmed or expectation-set |
| V16 | [VERIFY: B2B invoicing, VAT compliance, volume pricing exist before any SME promise ships] | Founder | Working invoice flow or removal of B2B claims from launch assets |
| V17 | [VERIFY: referral program mechanics + wallet-credit incentive legality under wallet non-transferability rule (credit issued by KeepSIMs, not transferred between users)] | Counsel + product | Counsel note + implemented referral flow (referrals table currently empty) |
| V18 | [VERIFY: Saudi-Zain, Saudi-Mobily, Kuwait (3 carriers), Oman (2 carriers) — configured but zero offers; fulfillable or not?] | Product/eng | Production catalog pull; 04 residence-market table updated |
| V19 | [VERIFY: DTone integration live — owner confirmed 2026-07-19 that Zendit is a test account and DTone (+ possibly others) will be added; DT Shop pricelist shows India 10 INR top-ups at ~$0.12 cost, which would flip India's Premium verdict] | Product/eng (abdalla) | dt_country/dt_carrier mapped in `carriers`, DTone offers cached, DTone wallet funded (currently 0.000 OMR), one live test top-up per Indian carrier; then re-run 04 and unit-economics for India |
| V20 | [VERIFY: DTone pricelist export (CSV) for all 10 origin markets — interim evidence ahead of full integration; includes MTNL India, absent from current carriers table] | Founder | CSV uploaded and matrix in 04 rebuilt with DTone column |

## Prohibited claims — blanket, never closeable by this register

Universal carrier support · guaranteed successful refill · guaranteed prevention of deactivation · carrier affiliation or endorsement · operation in any region not live in 04 · describing KeepSIMs as transmitting money · describing the wallet as transferable or cash-out-able.

## Status of Session 1 conflicts (resolved by owner, 2026-07-19)

- Aggregator reality: **Zendit only** — brief's Reloadly/DoctorSIM references void until V5-class evidence exists.
- Lebanon/Nepal/Iraq/Syria: **demoted to Tier 3 not-live** (data wins).
- Catalog: current data authoritative with sandbox rows flagged (V1/V2).
- Budget: **under $5k/month**, allocation rule in unit-economics §budget logic.
