# Compact dashboard SIM card — verification

Image cleanup, 16 October 2026: the captures below were removed from the repository because they are not app assets. Filenames are retained as historical capture identifiers; widget-test captures can be regenerated locally.

Date: 16 October 2026. Status: implemented, focused verification passed, Android emulator updated.

## Result

The default English card and carousel at a 390 dp viewport measure **227 dp**, previously **275 dp**: **48 dp / 17.5% shorter**. The dashboard's 16 dp horizontal padding, 0.9 viewport fraction and 6 dp page padding produce a 310.2 dp card. Recharge ends 13 dp above the outside bottom edge: 12 dp padding plus the 1 dp border.

Removed the dedicated status/menu row. The status dot, nickname, plan badge, Upgrade and overflow now occupy the identity header, with the complete LTR number below the nickname. Nicknames may ellipsize and retain their full tooltip/semantics. The dot has English/Arabic protection status semantics and a tooltip; its active state still uses the original schedule/protection-tier logic, separately from the health border color.

Automation rows have independent minimum 44 dp controls. Upgrade and overflow also have separate 44 dp targets. Narrow headers wrap their badge/action group; large automation labels move above their controls. Text sizes are retained. The parent carousel measures every line using the same text styles, locale, width and text scaler as the card, then reserves the tallest page. Individual shorter cards keep their own measured border height. The carousel owns a stable page controller and retains its position and indicators across width/text-scale changes.

Configuration, confirmation and owner verification before Delete, Upgrade, Notify, premium-gated Refill, custom-over-mini refill precedence and ManualRefillBottomSheet dispatch retain the existing callbacks. Provider subscriptions, health calculations and tier distinctions remain unchanged.

## Actual screenshots

These are Flutter captures, separate from the AI-generated design proposal.

| Source | Before | After |
| --- | --- | --- |
| Installed Android dashboard, same emulator viewport, first SIM page and default text scale | Before (`../../output/dashboard-sim-card-compact/emulator-before.png`) | After (`../../output/dashboard-sim-card-compact/emulator-after.png`) |
| Production card/carousel with mocked providers, 390 dp / 1× / light | Before card (`../../output/dashboard-sim-card-compact/before-card-light.png`) | After card (`../../output/dashboard-sim-card-compact/after-card-light.png`) |
| Production card/carousel with mocked providers, 390 dp / 1× / dark | Before card (`../../output/dashboard-sim-card-compact/before-card-dark.png`) | After card (`../../output/dashboard-sim-card-compact/after-card-dark.png`) |

Additional captures: Arabic RTL / 320 dp / 2× / dark (`../../output/dashboard-sim-card-compact/after-arabic-320-2x-dark.png`), reference full fixture light (`../../output/dashboard-sim-card-compact/after-light.png`), reference full fixture dark (`../../output/dashboard-sim-card-compact/after-dark.png`).

Reference before images rendered the saved pre-edit card in its original 275 dp PageView. The current reference fixture renders the actual production carousel. Both used the same viewport, fixture, theme and Inter font. Installed-device captures show the full signed-in dashboard before and after the update. The Android app process was confirmed running after installation.

## Checks and measured limits

- **61/62 focused tests pass:** 46 dashboard tests plus 16 existing health/entitlement tests. The 36 layout matrix tests exercise **144 combinations** of viewport (320/360/390 dp), scale (1/1.3/2), English/Arabic, light/dark, Standard/Premium and configured/unconfigured schedules. A separate test covers paused schedules, inactive switches and protection status independent of the health border. Stress fixtures use a long nickname and a 15-digit international number.
- Interaction tests use mocked schedule/deletion controllers and biometric outcomes. They verify card/menu navigation; Notify configuration; Upgrade and standard-tier Refill gates; premium Refill configuration; taps outside the visible switch but within its 44 dp region; custom refill precedence; independent Recharge dispatch; and cancelled/unverified/verified deletion. Bottom sheet dispatch is captured without mounting or executing provider/payment flows.
- The mixed-page test verifies swiping, indicators and page-controller retention after simultaneous width/text-scale changes. Single-card reference captures have no page dots.
- Scoped analysis of all changed dashboard source/tests: **no issues**. Dart formatting and `git diff --check`: pass.
- Android debug APK: build passed, `adb install -r` passed, launch passed on `emulator-5554`; existing app data retained. Native before/after screens were visually inspected.

[Full matrix measurements](../../output/dashboard-sim-card-compact/layout-measurements.json) record actual card dimensions. Across the stress fixtures:

| Viewport | 1× height | 1.3× height | 2× height |
| --- | --- | --- | --- |
| 320 dp | 227–299 dp | 305 dp | 458–497 dp |
| 360 dp | 227–299 dp | 238–305 dp | 366–458 dp |
| 390 dp | 227 dp | 238–305 dp | 366–458 dp |

The 227 dp target applies to the reference size; narrow and large-text content intentionally grows. Long numbers can wrap while preserving all digits and LTR order. Headless Arabic captures load a local Arabic fallback font; native Android chooses its platform fallback. Font metrics can therefore differ by platform, and the sizing code measures the current fonts. Native acceptance here covers default English; other combinations were widget-tested. iOS and the whole application suite were not rerun for this dashboard-only change. Historical unrelated failures are recorded in ACTIVE_HANDOFF.md.

Reproduce the focused checks:

```sh
flutter test test/features/dashboard test/features/sim_lines/domain/sim_line_health_test.dart test/features/sim_lines/line_entitlement_test.dart
flutter analyze lib/features/dashboard/presentation/widgets/dashboard_sim_line_card.dart lib/features/dashboard/presentation/widgets/dashboard_sim_line_carousel.dart lib/features/dashboard/presentation/ui/dashboard_screen.dart test/features/dashboard
```

Tests are offline and use the Flutter SDK's Roboto fixture unless `DASHBOARD_INTER_FONT` specifies a local Inter font. Recorded screenshots/matrix used the app's Inter Regular font downloaded to `/tmp/ks-dashboard-inter.ttf` from the URL requested by the installed google_fonts package. Set `DASHBOARD_INTER_FONT` for equivalent typography. `DASHBOARD_ARABIC_FONT` can specify a local Arabic font; otherwise the harness checks local macOS/Linux font paths. No downloaded/system font was added to application assets.

## Changed files

| File | Change |
| --- | --- |
| `lib/features/dashboard/presentation/widgets/dashboard_sim_line_card.dart` | Compact/adaptive composition, measured layout, status accessibility and independent hit regions; retained action callbacks. |
| `lib/features/dashboard/presentation/widgets/dashboard_sim_line_carousel.dart` | New local carousel owns sizing, stable page state and existing indicator appearance. |
| `lib/features/dashboard/presentation/ui/dashboard_screen.dart` | Replaces the fixed 275 dp carousel with the adaptive widget. |
| `test/features/dashboard/dashboard_sim_card_compact_test.dart` | Layout matrix, actual captures/dimensions and page retention check. |
| `test/features/dashboard/dashboard_sim_card_actions_test.dart` | Mocked routing, sheet dispatch, toggles, premium gates and deletion verification. |
| `docs/implementation-plans/dashboard-sim-card-compact-plan-20261016.md` | Records completion and links to results. |
| `docs/reviews/dashboard-sim-card-compact-verification-20261016.md` | This report. |
| `output/dashboard-sim-card-compact/` | Actual before/after PNGs and matrix JSON, alongside the preserved generated proposal/prompt. |

The admin app has no copied customer dashboard card. No backend/schema/shared theme/financial implementation was changed. Earlier unrelated calling/navigation/assets/handoff edits were preserved. No real refill, schedule mutation, call or SIM deletion was performed. No commit or push was made.

## Numbered SIM labels follow-up — 16 October 2026

Dashboard default names now display `SIM 1`, `SIM 2`, etc. Null/blank nicknames and the generic `SIM Line`/localized default use the number; custom nicknames remain. The dashboard orders a copy of the supplied lines by creation date, oldest first, rather than inheriting the shared provider's nickname ordering. Equal dates use ID order. Legacy records missing a creation date precede dated lines and use stable ID order; their original addition order cannot be recovered from the missing value. Labels are ranks among existing dashboard lines, so deleting a line compacts the sequence. No database nickname or shared list ordering changes.

Nine relevant dashboard checks pass after this follow-up, including addition order, a newly added fifth SIM, preserved custom names, page retention and the six existing action tests. Scoped source/test analysis is clean. Android debug build, install with retained data, and launch passed. The compact-layout screenshots above record the preceding layout change; the numbered-label emulator capture is stored separately as `emulator-numbered.png`.
