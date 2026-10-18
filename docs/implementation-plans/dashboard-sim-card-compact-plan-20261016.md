# Dashboard SIM card: compact layout executor handoff

Image cleanup, 16 October 2026: the captures below were removed from the repository because they are not app assets. Filenames are retained as historical capture identifiers; widget-test captures can be regenerated locally.

Date: 16 October 2026  
Status: IMPLEMENTED AND VERIFIED — 16 October 2026. Android debug build installed and launched on the existing emulator with app data retained.

Execution results: the 390 dp English reference card/carousel measures **227 dp**, down from **275 dp** (48 dp / 17.5%). The status dot, tier, Upgrade and menu share the identity header; controls retain independent 44 dp targets. Narrow or enlarged content increases the measured height. **62 focused checks pass** and scoped analysis reports no issues. See [the implementation verification](../reviews/dashboard-sim-card-compact-verification-20261016.md) for changed files, measurements, screenshots, and validation scope.

Actual installed-dashboard captures: before (`../../output/dashboard-sim-card-compact/emulator-before.png`) · after (`../../output/dashboard-sim-card-compact/emulator-after.png`). The generated comparison below remains design direction only.

## Requested outcome

Make the dashboard SIM cards shorter by removing their dedicated top status/menu row and excess space below Recharge Now. Preserve the recognizable design, readable text, and existing actions.

Use the comparison picture (`../../output/dashboard-sim-card-compact/compact-card-proposal.png`) as visual direction. It was generated with the built-in image tool; it is a concept rather than a pixel-perfect Flutter rendering. The exact generation prompt is saved beside it in `generation-prompt.txt`.

Aim for approximately **225 logical pixels high instead of 275** on a roughly 310 dp card at default English text size: a target saving of 50 dp / 18%. Allow additional height where actual content requires it. The screenshot's pixel dimensions are not Flutter layout measurements.

## Confirmed current implementation

- `lib/features/dashboard/presentation/widgets/dashboard_sim_line_card.dart` contains `DashboardSimLineCard`.
- Its `GlassCard` padding is currently horizontal 18 / vertical 14.
- Its first child is a separate status/overflow row, followed by an 8 dp gap.
- That overflow menu contains Configuration and Delete. Deletion includes a confirmation dialog and `destructiveActionGuardProvider` verification.
- The next header row contains the nickname, plan badge and conditional Upgrade chip. The phone number follows.
- The remaining content is a divider, Auto-Notify, Auto-Refill and Recharge Now.
- `lib/features/dashboard/presentation/ui/dashboard_screen.dart`, `_buildHealthSection`, wraps the cards in a `SizedBox(height: 275)` containing a `PageView.builder`. The tight height constraint explains why changing inner padding alone would leave extra space.
- The page controller uses `viewportFraction: 0.9`; each card also has 6 dp horizontal outer padding.
- `GlassCard` and `GlassToggleSwitch` are shared widgets. This request concerns dashboard composition.

## Preflight

Read `.agents/skills/keepsims-memory/SKILL.md`, `.agents/AGENTS.md`, `.codex/AI_AGENT_GUIDE.md`, and relevant current project status before editing code. Reinspect the current implementation and working-tree status.

There are existing unrelated changes, especially in calling/navigation and documentation. Preserve them. Check whether the customer card has a copied counterpart in the admin app before deciding scope; the requested UI is the customer dashboard.

## Recommended design and spacing

Remove the dedicated status/menu row and its following spacer. Integrate its useful elements into the identity header:

- Keep a small status dot beside the SIM nickname.
- Retain the plan badge, Upgrade when applicable, and the overflow menu in the header.
- Keep the complete international phone number directly below the nickname.
- Preserve the existing card radius, typography hierarchy, light/dark palette, divider, switch appearance and amber recharge button.
- Reduce card padding to about **16 dp horizontal and 12 dp vertical**.
- Use about **8 dp before and after the 1 dp divider**.
- Give the two automation controls compact rows with about **44 dp usable height each**, without an extra empty row between them.
- Keep Recharge Now at least **44 dp high**, with about **8 dp before it** and **12 dp between its bottom and the card edge**.
- Preserve approximately 44 dp independent hit regions for actions; visible chips and switches may remain smaller. Do not shrink font sizes to achieve the target.

A useful normal-size height budget is: 24 padding + 44 identity header + 17 divider/gaps + 88 automation rows + 8 gap + 44 recharge = **225 dp**. This is a starting budget, not a hard maximum. Measure the actual themed text.

Use a flexible two-line identity area with the noninteractive plan badge near the name and a trailing action area for Upgrade and overflow. The action hit regions must remain separate from each other and from the phone number/card tap region. Long nicknames may ellipsize; expose the full name through semantics/tooltip. Keep the phone number legible and explicitly LTR inside RTL layouts.

The status dot must keep its existing `hasProtectionActive` meaning, rather than taking its color from `glowColor`. The card border uses separate health logic. Add a localized tooltip/semantic status so color is not the only way to identify active/inactive protection. For inactive protection, retain a short visible inline status label if needed for clarity; allow height to grow instead of adding the removed standalone row back.

## Implementation sequence

1. **Edit the dashboard card locally.** Recompose the identity/header and spacing in `dashboard_sim_line_card.dart`. Move the existing overflow menu and callbacks rather than recreating their behavior. Extract private local builders only where this makes the layout readable.
2. **Fix the parent constraint.** Update the carousel sizing in `dashboard_screen.dart` together with the card. A smaller child inside the existing 275 dp carousel does not complete the task. Give the carousel a compact normal-size height and an appropriate content-aware/width-and-text-scale-aware larger height when needed. Choose the simplest local sizing method that fits measured content in every required state.
3. **Handle narrow/translated layouts.** Check the actual card width after the 0.9 viewport fraction and outer padding. If the identity, tier and actions cannot fit, wrap the badge/action group into an additional header line and increase the carousel height accordingly. Keep all page cards within the chosen height, including mixed Standard/Premium and Configure/switch pages. Retain the current page position and indicator behavior when sizing changes.
4. **Preserve interaction behavior.** Card tap still opens the SIM details. Overflow Configuration, confirmation-gated deletion, Upgrade, Auto-Notify, Auto-Refill and Recharge Now must keep their existing callbacks and conditional behavior. A control tap must not also trigger the parent card tap.
5. **Verify visually and behaviorally.** Capture the actual Flutter dashboard before/after at the same viewport and text scale. Record the measured card/carousel height and whether the 225 dp target was achieved.

Keep the existing provider subscriptions, health computation, tier/plan distinctions, schedule precedence and premium gates intact. Recharge must still open `ManualRefillBottomSheet`. This presentation task needs no backend, schema, shared theme, or financial-flow changes.

## Acceptance and checks

- The complete card border is visible; there is no standalone status/menu row.
- On the normal-size reference layout, the card and its carousel are around 225 dp high, with about 12 dp below Recharge Now.
- Narrow layouts and larger text grow as needed, without clipping, overlap or unreadable numbers.
- Check phone viewport widths 320, 360 and 390 dp, text scales 1.0, 1.3 and 2.0, light/dark themes, and English/Arabic with RTL.
- Check a long nickname/phone number, Standard with Upgrade, Premium without Upgrade, active/inactive schedules, notification Configure versus switch, and refill Configure versus switch.
- Check single-card and multiple-card states, swipe/page dots, and mixed card states. Prevent hit-target overlaps or the parent card navigation swallowing a control tap.
- Run formatting and analysis for affected Dart files plus relevant existing tests. Add only focused tests for meaningful risks: small-width/large-text overflow, independent control navigation, and retained callback/gating behavior using mocked providers. Use fixtures and mocked actions; do not create live refills, schedule changes or delete a real SIM as a UI test.
- Return the final changed-file list, real before/after screenshots, measured sizing, verification results, and any remaining layout limitations. Distinguish generated concept imagery from actual app screenshots.

## Copyable executor instruction

Implement the compact customer-dashboard SIM card described in this document and its reference image. Remove the dedicated status/menu row, integrate status and menu into the identity header, tighten spacing, and reduce the parent carousel height from its current 275 dp toward 225 dp at the normal reference size. Preserve all existing actions, providers, protection logic, financial flows and destructive-action verification. Support narrow screens, larger text and RTL by allowing extra height. Inspect current repository instructions and dirty files first, keep the change localized to dashboard layout, and deliver actual Flutter screenshots with measured dimensions and focused verification.

