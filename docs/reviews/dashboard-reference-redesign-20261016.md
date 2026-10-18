# Dashboard reference redesign — 16 October 2026

Image cleanup, 16 October 2026: the captures below were removed from the repository because they are not app assets. Filenames are retained as historical capture identifiers; widget-test captures can be regenerated locally.

Implemented the supplied dashboard picture in Flutter and installed the Android debug build on `emulator-5554`, retaining existing app data. The installed dashboard was visually inspected and its process confirmed running.

## Result

- Initial avatar, compact greeting, wallet and bell header. The avatar menu retains language selection and location information; unread notification count is available in the bell tooltip.
- Compact SIM protection summary, existing SIM illustration, dynamic count and Manage SIMs/Add SIMs action.
- Explore KeepSIMs: Smart Call and Second Number side by side, with Worldwide eSIMs across the full width below. Each entire card opens its existing destination. Large text/narrow layouts stack the calling cards.
- Your SIM lines: full-width pages, existing addition-order numbering and custom nicknames, subdued plan badge and overflow menu. Upgrade moved into the menu for eligible plans. Auto-Notify, premium-gated Auto-Refill, Set up and Recharge retain their existing actions. Controls have independent minimum 44 dp targets. Card borders are neutral; protection status retains its schedule-driven semantics.
- Teal dashboard switches and outlined setup/recharge controls. Shared glass widgets and global theme colors were not modified.
- Flat Home / Smart Call / More navigation replaces the floating active circle. More still opens the existing drawer. Duplicate dashboard Quick Actions were removed; Smart Call/eSIM are in Explore, wallet remains in the header, and support/referrals remain in More. Campaigns and recent activity remain below the SIM section.

All displayed names, counts and numbers use application data. The image's name/count/phone values were not hardcoded into production UI.

## Actual screenshots

- Installed Android: before (`../../output/dashboard-reference-20261016/emulator-before.png`), after (`../../output/dashboard-reference-20261016/emulator-after.png`).
- Production dashboard and navigation shell with mocked data: light (`../../output/dashboard-reference-20261016/implemented-light.png`), dark (`../../output/dashboard-reference-20261016/implemented-dark.png`), Arabic / 320 dp / 2× text (`../../output/dashboard-reference-20261016/implemented-arabic-320-2x.png`).

The Android after capture includes the full SIM card and bottom navigation at the emulator's current viewport. Smaller viewports and larger text scroll naturally; content is not forced into a fixed screen height. Widget captures use a 390×844 reference viewport and local font fixtures, so platform font metrics and OS chrome can differ from the installed screen. These PNGs are Flutter captures, not generated design proposals.

## Verification

- **70 dashboard tests pass** across the three dashboard test files. The SIM matrix exercises **144 combinations** of viewport width, text scale, locale, theme, tier and configured state. Whole-dashboard cases cover 320/360/390 dp, scales 1/1.3/2, English/Arabic, light/dark reference captures, empty state, feature/header/Manage/Add routing, avatar language/location access and opening More.
- Existing SIM behavior tests pass: detail/menu navigation, Notify configuration and toggling, standard-tier premium gate, premium configuration/custom-schedule precedence, Recharge sheet dispatch, confirmation/owner verification before deletion, addition-order numbering and custom names.
- **Two existing Smart Call integration checks pass** for empty-number review and production history/legacy/back navigation after the shell change. A later focused run also rechecked captures, paused state and feature routing.
- Scoped analysis of dashboard widgets/screen, navigation shell and dashboard tests: **no issues**. Dart formatting and scoped `git diff --check`: pass.
- Android debug build, `adb install -r`, launch and process check: **pass**. No signed release/iOS build was rerun for this presentation change.

Interaction-test mutations and sheet dispatch use mocks; no actual call, refill, schedule change or SIM deletion was used for verification. New copy has English/Arabic translations; other existing locales use generated English fallback for the added messages. Existing unrelated auth, calling and platform work was preserved.

Commands used:

```sh
DASHBOARD_INTER_FONT=/tmp/ks-dashboard-inter.ttf flutter test test/features/dashboard
flutter analyze lib/features/dashboard/presentation/ui/dashboard_screen.dart lib/features/dashboard/presentation/widgets/dashboard_feature_cards.dart lib/features/dashboard/presentation/widgets/dashboard_sim_line_card.dart lib/features/dashboard/presentation/widgets/dashboard_sim_line_carousel.dart lib/features/dashboard/presentation/widgets/sim_protection_hero_card.dart lib/core/router/placeholder_screens.dart test/features/dashboard
flutter build apk --debug
```

The optional Inter path selects a local font for the offline widget harness. Without it, the harness uses Flutter's Roboto fixture; Arabic uses an available local fallback. Font assets were not added to the product.

## Changed files for this task

| File | Purpose |
| --- | --- |
| `lib/features/dashboard/presentation/ui/dashboard_screen.dart` | Header/menu, section headings, spacing, removal of duplicate quick actions. |
| `lib/features/dashboard/presentation/widgets/dashboard_feature_cards.dart` | Two-plus-one service arrangement and distinct native icons. |
| `lib/features/dashboard/presentation/widgets/sim_protection_hero_card.dart` | Compact hero spacing, copy and existing illustration sizing. |
| `lib/features/dashboard/presentation/widgets/dashboard_sim_line_card.dart` | Neutral/teal styling, menu Upgrade, local toggle and updated sizing. |
| `lib/features/dashboard/presentation/widgets/dashboard_sim_line_carousel.dart` | Full-width pages; existing creation-order numbering retained. |
| `lib/core/router/placeholder_screens.dart` | Flat accessible navigation, retained route/drawer behavior. |
| `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` | Dashboard copy; generated localization Dart refreshed. |
| `test/features/dashboard/dashboard_reference_design_test.dart` | New whole-dashboard, route, accessibility-layout and capture coverage. |
| `test/features/dashboard/dashboard_sim_card_actions_test.dart` | Existing callback checks updated for menu Upgrade and local switches. |
| `test/features/dashboard/dashboard_sim_card_compact_test.dart` | Existing layout checks updated for new styling and offline SVG fixture loading. |
| `output/dashboard-reference-20261016/` | Native and widget captures. |
| `docs/reviews/dashboard-reference-redesign-20261016.md` | This report. |

The earlier compact-card verification is historical; this redesign supersedes its visual styling and carousel width. No backend/schema/financial implementation, commit or push was part of this task.
