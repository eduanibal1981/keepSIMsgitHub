# KeepSIMs — Advertising Console

A TypeScript admin app over `doc/advertis System/docs/`. It answers one question the plan
documents can only answer by cross-reading seven files: **for each country, what is done,
what may run today, and what do I still need before I publish?**

```bash
npm --prefix tools/ad-console install
```

```bash
npm --prefix tools/ad-console run dev
```

Opens on <http://localhost:5180>. `npm run build` produces a static `dist/`; `npm run typecheck`
runs the compiler alone.

## The six screens

| Screen | What it is for |
|---|---|
| **Overview** | Country × capability matrix — the single screen showing what is done per country. Plus the open tokens ranked by how much they hold back, the budget rule, and flags F1–F8. |
| **Countries** | Drill into one corridor: what may run today, what is held and on what, the approved promises you may tell users, the per-corridor prohibitions, carrier data, and the pre-publish data checklist. Exports a markdown brief per country. |
| **Verification** | V1–V20 with the section-13 gate table. Close a token (with evidence) and every corridor verdict recomputes. |
| **Functionality** | The supporting work the plan depends on — attribution capture, event schema, protected-line view, consent capture, price card, deposit tests. Tick items off; the attribution item opens the paid-media gate. |
| **Plan library** | The plan as a file tree with per-document status: fixed / done / seeded / not written yet. |
| **Compliance** | Commercial structure, banned terms, prohibited claims, tone rules, per-corridor prohibitions, platform and data-protection notes. |

## Language

The button at the far end of the top bar toggles **English ⇄ العربية**. Arabic switches the
document to RTL and translates everything — UI, country content, tokens, gates, personas,
flags, compliance lists, and the exported markdown briefs.

The console's Arabic is Modern Standard, because it is an internal tool. That is *not* the
rule for creative: consumer-facing Arabic is Egyptian dialect only, and MSA is banned for
social creative (creative-brief §7). The compliance screen says so on the page when Arabic
is active, so nobody copies console phrasing into an ad.

## How the verdicts are computed

`src/domain/readiness.ts` is the engine. It takes a corridor, the current token closures and
a locale bundle, and returns a verdict per capability:

- **clear** — may ship today, inside the stated limits
- **blocked** — a gate is shut; it clears when the gate does
- **forbidden** — policy says no, and no token in the register changes that

The gates in `src/data/gates.ts` are a direct transcription of the section-13 gate table.
The distinction that matters: Philippines Premium is *forbidden* (min denomination exceeds
keep-alive, so the "mini" promise breaks — only a catalog change reopens it), while India
Premium is *blocked* (waiting on V19/DTone plus a re-run of 04). The app will not let those
two collapse into the same colour.

Closing V11 in the Verification screen, for example, flips Pakistan and Egypt Premium to
clear, leaves India blocked on V19, and leaves the Philippines forbidden.

## Rules the app enforces

- **Only evidence closes a token.** The close button is disabled until you type an evidence
  note; the note, date and operator are recorded. Closing a token here does not close it in
  `verification-register.md` — record it there too.
- **Token identifiers are never translated.** V1–V20, F1–F8 and gate ids appear verbatim in
  both languages, because the register requires them reproduced exactly.
- **Banned terms keep their English.** The Arabic compliance table shows the Arabic gloss
  beside the canonical English term, so a reviewer can catch a translation that
  back-translates into a banned meaning — itself a violation.

## Data provenance

Everything in `src/data/` is transcribed from the plan documents, and each record carries a
`source` field naming its file — click any path in the UI to copy it. The console is
read-only over those documents: it never writes to them.

Two things it records locally, in your browser only: token closures and work-item status.
Export them with **Export state** if they need to reach anyone else.

The starting statuses in **Functionality** are what the documents assert as of the last
planning session. They are not a verification against the codebase — confirm before ticking.

## Known data caveat carried through

All fulfilment figures come from a Zendit account the owner describes as test-only (flags
F8), and all 49 `carrier_rules` rows have `last_verified_at` null or sandbox-dated (V3/V4).
Keep-alive amounts shown in the carrier tables are operational estimates, marked internal —
they must never be quoted to a user as a carrier threshold.
