# 04 — Corridors and Coverage

**Data source:** live production database (simSaveDB) pulled 2026-07-19: `carriers` (50), `carrier_rules` (49), `zendit_offers_cache` (780), `countries` (21). This file supersedes the tiering assumptions in the strategy brief wherever they conflict — decision confirmed by owner: **data wins**.

## Two axes, never collapsed

- **Residence market** = where the customer lives = where ad money is spent: Saudi Arabia, UAE, Qatar, Kuwait, Bahrain, Oman.
- **Origin market** = where the SIM is = the promise in the ad: the corridors below.

An ad targeting Qatar residents about their Pakistani SIM is a Pakistan-corridor ad. Qatar having no local carrier coverage in the catalog is irrelevant to it and must never block it.

## Headline findings (these override the brief)

1. **KeepSIMs runs on Zendit only.** Every one of the 50 carriers is `api_provider = zendit`. Reloadly and DoctorSIM fields are empty across the entire database. Any plan language implying multi-aggregator sourcing is false today.
2. **Lebanon, Nepal, Iraq, and Syria have zero coverage** — no carrier rows, no rules, no cached offers. The brief's "Tier 1 — value: Lebanon (confirmed via Zendit)" and "Syria live in-product via DoctorSIM" are both contradicted by the data. All four are demoted to **Tier 3: not live — no advertising of any kind, paid or organic**, until coverage exists. Re-entry checklist below.
3. **Premium auto-mini-refill is economically viable in exactly two-and-a-half corridors: Pakistan, Bangladesh, and Egypt (Vodafone/Etisalat only).** Everywhere else the minimum purchasable denomination exceeds the keep-alive amount, which breaks the "mini" promise. This list is a hard creative constraint — carried verbatim into creative-brief.md.
4. **India's catalog looks like sandbox residue** — 1–2 offers per carrier, Jio minimum $17, Airtel $9, with `carrier_rules` notes reading "pinned from Zendit sandbox catalog." Verdicts below use current data as instructed, with [VERIFY] on every sandbox-tainted row. If the production catalog restores small Indian denominations, India's Premium verdict flips — re-run this file before scaling India creative.
5. **Owner update 2026-07-19:** the Zendit account is confirmed test-only; **DTone is being added as a production aggregator**. DTone's pricelist shows India top-ups from 10 INR (~$0.12 cost) across Airtel, BSNL, MTNL, Vi, and Jio — enough to flip India to mini-refill-viable **once DTone is live in the production DB** (V19/V20 in the verification register). Until then, every verdict in this file stands unchanged: creative may not anticipate DTone coverage. When V19 closes, re-run this file, unit-economics, and creative-brief §3 before any India Premium asset ships.

## Revised corridor tiers

| Tier | Corridor (origin → residence) | Plan to lead with | Why |
|---|---|---|---|
| 1 — volume | India → UAE, India → Saudi | **Standard + scheduled refills** | Largest diaspora; 180-day inactivity + 60-day grace = 2 refills/yr; Premium blocked pending catalog verification |
| 1 — volume | Philippines → UAE, → Saudi, → Qatar | **Standard + scheduled + multi-line** | Big, organized diaspora; min denomination $4.52–7.37 kills the mini pitch |
| 1 — Premium proof | Pakistan → Saudi, → UAE | **Premium auto-mini-refill** | Min denominations $0.32–0.94, keep-alive $0.50, 180-day window: the best Premium economics in the portfolio |
| 1 — Premium proof | Bangladesh → Saudi, → UAE | **Premium auto-mini-refill** | Min $0.11–0.54 vs $0.50 keep-alive; 120-day window |
| 2 | Egypt → Saudi, → Kuwait, → UAE | **Premium on Vodafone/Etisalat; Standard on Orange/WE** | Carrier-split corridor — creative must not promise Premium generically |
| 2 | Sri Lanka → Kuwait, → Qatar, → UAE | **Standard + scheduled** | Min $4.60–5.60 vs $1 keep-alive; 3 refills/yr |
| 3 — not live | Lebanon, Nepal, Iraq, Syria (any residence) | **None. No paid, no organic promises** | Zero coverage in production data |

Bahrain and Oman remain **low-CPM creative test beds** — target residents there about their *origin* SIMs (India, Pakistan, Philippines…). This works because the promise is the origin SIM; it never depends on local Bahraini/Omani carrier coverage.

Jordan, Turkey, Germany, UK, US exist in the database but are `is_supported = false` (Jordan has live offers but is switched off). Out of scope for this plan; do not advertise.

## Aggregator coverage matrix

Aggregator = Zendit throughout. `Min denom` = lowest purchasable retail price (cheapest of cached catalog vs pinned rule offer). `Keep-alive` = `recommended_topup_amount` from carrier_rules — operational estimate, **not carrier-verified**: [VERIFY: inactivity threshold, grace period, and minimum reactivating top-up — source: each carrier's official prepaid policy]. Mini-viable = min denom ≤ keep-alive.

### Origin markets (the ad promise)

| Origin | Carrier | Live? | Min denom (USD) | Keep-alive (USD) | Mini-refill viable? | Notes |
|---|---|---|---|---|---|---|
| India | Airtel | YES | 5.49 retail (cache min $9) | 0.50 | **NO** | [VERIFY: production catalog — cache appears sandbox] |
| India | BSNL | YES | 3.10 | 0.50 | **NO** | Cheapest Indian option |
| India | Jio | YES | 3.68 (cache min $17) | 0.50 | **NO** | [VERIFY: production catalog] |
| India | Vi | YES | 9.00 | 9.00 | **NO** | Sandbox-pinned [VERIFY] |
| Pakistan | Zong | YES | 0.32 | 0.50 | **YES** | Sandbox-pinned [VERIFY] |
| Pakistan | Ufone | YES | 0.85 retail (cache $0.40) | 0.50 | **YES** | |
| Pakistan | Telenor | YES | 0.87 retail (cache $0.33) | 0.50 | **YES** | |
| Pakistan | Jazz | YES | 1.34 retail (cache $0.40) | 0.50 | **YES** (via cache offers) | |
| Bangladesh | Teletalk | YES | 0.91 retail (cache $0.11) | 0.50 | **YES** | |
| Bangladesh | Banglalink | YES | 0.91 retail (cache $0.12) | 0.50 | **YES** | |
| Bangladesh | Robi | YES | 0.91 retail (cache $0.12) | 0.50 | **YES** | |
| Bangladesh | Grameenphone | YES | 0.84 retail (cache $0.27) | 0.50 | **YES** | |
| Philippines | DITO | YES | 5.21 | 1.00 | **NO** | |
| Philippines | Smart | YES | 7.00 | 1.00 | **NO** | |
| Philippines | Globe | YES | 8.28 | 1.00 | **NO** | |
| Sri Lanka | Hutch | YES | 5.29 | 1.00 | **NO** | |
| Sri Lanka | Mobitel | YES | 5.43 | 1.00 | **NO** | |
| Sri Lanka | Dialog | YES | 6.37 | 1.00 | **NO** | |
| Egypt | Vodafone | YES | 0.54 | ~0.25 | **YES** | 86-day validity, 0 grace [VERIFY: anomalous rule row] |
| Egypt | Etisalat | YES | 0.25 | 0.25 | **YES** | Sandbox-pinned [VERIFY] |
| Egypt | Orange | YES | 4.30 | 1.00 | **NO** | |
| Egypt | WE | YES | 2.85 | 1.00 | **NO** | |
| Nepal | — | **NO** | — | — | — | No coverage via any aggregator |
| Lebanon | — | **NO** | — | — | — | No coverage |
| Iraq | — | **NO** | — | — | — | No coverage |
| Syria | — | **NO** | — | — | — | No coverage; see 12-compliance for commercial posture |

### Residence markets (local-SIM coverage, relevant only to multi-line/local-line features)

| Market | Carriers with live offers | Gap |
|---|---|---|
| UAE | du, Etisalat (min ~$1.63) | Virgin Mobile: no offers |
| Saudi Arabia | STC (min $7.10) | Zain KSA, Mobily: carriers exist, **no offers** |
| Kuwait | none | 3 carriers configured, zero offers — local-SIM features unfulfillable |
| Oman | none | 2 carriers configured, zero offers |
| Qatar | none | No carriers at all |
| Bahrain | none | No carriers at all |

Implication: creative may not promise "manage your local GCC SIM" outside UAE (and STC-only in Saudi). Multi-line messaging must be framed around *home-country* lines.

## Hard constraint carried into creative-brief.md

**Premium auto-mini-refill may be advertised ONLY for: Pakistan (all four carriers), Bangladesh (all four carriers), Egypt (Vodafone and Etisalat only).**
Advertising in India, Philippines, Sri Lanka, and Egypt-Orange/WE corridors must lead with Standard, scheduled refills, and multi-line management. No exceptions until the verification register closes the relevant tokens.

## Tier 3 re-entry checklist (Lebanon, Nepal, Iraq, Syria)

1. Coverage contracted and live with a named aggregator; carrier rows + rules + offers present in production DB.
2. Test top-up executed end-to-end on each carrier; receipt archived.
3. `carrier_rules` populated with sourced inactivity/grace data, `last_verified_at` set.
4. Min denomination vs keep-alive computed → Premium verdict assigned.
5. For Syria additionally: merchant-of-record acceptable-use sign-off, counterparty screening process in place, and 12-compliance §Syria items closed.
6. Only then: organic/community first, paid after 60 days of clean fulfillment data.
