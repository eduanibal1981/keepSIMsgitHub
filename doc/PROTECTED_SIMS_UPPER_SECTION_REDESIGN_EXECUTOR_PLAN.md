# Protected SIMs Upper Section Redesign — Executor Plan

## Objective

Replace only the upper section of the customer app's Protected SIMs page with the approved compact design:

- title plus a compact `Add SIM` action;
- compact tab labels with live counts;
- local search by SIM nickname or phone number;
- quick filters for `All`, `Active`, `Alert soon`, and `Auto-refill`;
- remove the oversized gradient `Protect Another SIM Line` card from the list.

Keep the existing SIM cards, navigation, add-SIM workflow, refresh behavior, empty states, long-press selection, bulk actions, realtime refresh, and backend contracts unchanged.

This is a Flutter customer-app presentation change. It requires no Supabase migration, RPC, Edge Function, worker, admin-app, or route change.

## Repository and safety instructions

Work in:

`C:\Users\abdal\Work\KeepSIMs\keep_sims`

Before editing:

1. Read `.agents/AGENTS.md` and `.codex/AI_AGENT_GUIDE.md` completely.
2. Run `git status --short` and preserve all unrelated work.
3. Do not reset, discard, overwrite, or reformat unrelated files.
4. The working tree is already dirty. In particular, the localization files and `sim_lines_controller.dart` currently contain user work. Merge only the necessary localization keys; do not replace those files from another branch or snapshot.
5. Do not modify generated Riverpod files for this task.
6. Do not hand-edit generated localization Dart files. Update ARB sources and run Flutter localization generation.

## Confirmed current implementation

Primary screen:

`lib/features/sim_lines/presentation/screens/sim_lines_list_screen.dart`

Relevant current behavior:

- The app bar title and refresh action are built around lines 382–471.
- The two tabs are currently `My SIM Cards` and `Family Shared SIMs` with vertically stacked icons.
- `_buildLinesList` inserts an extra first item for the owner's tab.
- `_buildAddHeaderCard` builds the large gradient banner around lines 639–689.
- `_checkLineLimitAndAdd` opens `/sim-lines/add` and performs the important post-return refreshes and delayed polling. Preserve that behavior.
- Owned/shared separation is already computed by comparing `line.userId` with the current user ID.
- `SimLineCard` already reads scheduled top-ups to display alert and protection information. Do not redesign it in this task.

Existing data sources are sufficient:

- `SimLine.nickname` and `SimLine.phoneNumber` support search.
- `SimLine.status` and `SimLine.protectionPaused` support the Active filter.
- An active `ScheduledTopup` with `scheduleType == 'notify'` supplies the next alert date.
- Active `refill_mini` and `refill_custom` schedules identify auto-refill protection.
- `scheduledTopupControllerProvider` already loads all schedules for the active user.

Existing route:

`/sim-lines/add`, registered as `simLineAdd` in `lib/core/router/app_router.dart`. Do not add or rename routes.

## Scope and files

### Modify

1. `lib/features/sim_lines/presentation/screens/sim_lines_list_screen.dart`
2. All source ARB files under `lib/l10n/`:
   - `app_en.arb`
   - `app_ar.arb`
   - `app_bn.arb`
   - `app_es.arb`
   - `app_hi.arb`
   - `app_ne.arb`
   - `app_si.arb`
   - `app_tr.arb`
   - `app_ur.arb`

### Add

1. `lib/features/sim_lines/presentation/models/sim_lines_list_filter.dart`
2. `lib/features/sim_lines/presentation/widgets/sim_lines_list_header.dart`
3. `test/features/sim_lines/sim_lines_list_filter_test.dart`
4. `test/features/sim_lines/sim_lines_list_header_test.dart`

### Regenerate

Run Flutter localization generation so these generated files reflect the new ARB keys:

- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_*.dart`

Do not change `sim_line_card.dart`, the controllers, repository, models, router, database, or backend unless compilation reveals a directly related issue. If that happens, stop and explain the need before broadening scope.

## Product behavior specification

### 1. Header row

Normal mode:

- Keep the page title from `AppLocalizations.protectedSims`.
- Add a compact primary button labeled from the existing `AppLocalizations.addSim`.
- Button icon: `Icons.add_rounded`.
- Button action: haptic light tick, then call the same add flow currently reached through `_buildAddHeaderCard`.
- Keep the refresh icon immediately after the add button.
- Refresh must keep invalidating `simLinesControllerProvider` and `householdControllerProvider`, with the existing haptic feedback.
- Use a minimum 48 dp touch target and a tooltip for the refresh action.

Selection mode:

- Preserve the existing close button, selected count title, and select-all/deselect action.
- Hide the Add SIM and refresh actions while selection mode is active.
- Do not change bulk-action semantics.

Responsive behavior:

- At normal phone widths, show the full `Add SIM` button.
- On narrow layouts (recommended cutoff: width below 380 logical pixels) or when the text scale makes the row overflow, render a filled add icon button with an `Add SIM` tooltip instead of clipping the page title.
- The title must be one line with ellipsis as a final fallback.
- Use directional padding so Arabic and Urdu render correctly in RTL.

Suggested visual tokens:

- app-bar toolbar height: 68–72 dp;
- add button height: 42–44 dp;
- add button radius: 12–14 dp;
- normal-mode horizontal inset: 16 dp;
- primary button background: light mode `AppColors.primary` or the existing primary gradient; dark mode use the existing theme-appropriate primary color;
- accessible foreground contrast in both themes.

### 2. Tabs with counts

Replace the current icon-above-text tabs with compact inline tab contents:

- first tab: person icon, localized `My SIMs`, count badge containing `myLines.length`;
- second tab: people icon, localized `Shared with me`, count badge containing `sharedLines.length`.

Rules:

- Counts always show total records in that tab, not the filtered result count. This keeps them stable while searching.
- Selected tab uses the existing primary color and 3 dp underline.
- Unselected tab uses the existing secondary text color.
- Count badge is a small rounded pill; selected uses a light primary tint, unselected uses a neutral surface tint.
- Keep each tab at least 48 dp high.
- Long translations must flex or ellipsize without a RenderFlex overflow.
- Switching tabs keeps the current search/filter settings, but clears selection mode and selected IDs as it does today.

### 3. Search and quick-filter area

Place a reusable `SimLinesListHeader` immediately below the TabBar and above the TabBarView/list content.

The widget is presentational only. It receives values and callbacks; it must not read Riverpod providers or perform navigation.

Recommended constructor contract:

```dart
class SimLinesListHeader extends StatelessWidget {
  const SimLinesListHeader({
    super.key,
    required this.searchController,
    required this.selectedFilter,
    required this.filtersExpanded,
    required this.scheduleFiltersEnabled,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onToggleFilters,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final SimLinesListFilter selectedFilter;
  final bool filtersExpanded;
  final bool scheduleFiltersEnabled;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onToggleFilters;
  final ValueChanged<SimLinesListFilter> onFilterChanged;
}
```

Search row:

- rounded search field with search icon;
- hint: localized `Search name or number`;
- 48 dp height;
- no autocorrect and no suggestions for phone-oriented search;
- search action on keyboard;
- clear icon appears only when query is non-empty;
- local filtering updates as the user types; no debounce or network request is needed;
- a 48 x 48 dp filter/tune button sits beside the field;
- tapping the filter button expands/collapses the quick-filter row;
- show a small numeric badge only when a non-`All` quick filter is selected. Do not hardcode the `2` visible in the concept image.

Quick-filter row:

- use `ChoiceChip`, because these are mutually exclusive filters;
- choices: `All`, `Active`, `Alert soon`, `Auto-refill`;
- `All` is selected by default;
- make the row horizontally scrollable so translations and small screens never overflow;
- selected chip uses the cyan/teal brand fill and high-contrast text;
- unselected chips use a light surface, thin border, and secondary text;
- preserve dark-mode equivalents;
- target height approximately 32–36 dp, with full accessible tap semantics;
- `Alert soon` and `Auto-refill` must be disabled while schedule data has no usable value. `All` and `Active` remain available.

Visibility:

- Show the search row whenever the current tab contains at least one unfiltered line.
- Hide the entire search/filter area for a truly empty tab so the existing empty state remains the focus.
- Hide the search/filter area during selection mode. Keep the current query/filter state and re-show it when selection mode ends.

### 4. Filter definitions

Create a pure presentation helper in `sim_lines_list_filter.dart`. Do not put filtering into the repository or controller; it is local display state and must not trigger backend reads.

Suggested API:

```dart
enum SimLinesListFilter { all, active, alertSoon, autoRefill }

List<SimLine> filterSimLines({
  required List<SimLine> lines,
  required List<ScheduledTopup> schedules,
  required String query,
  required SimLinesListFilter filter,
  DateTime? now,
})
```

Search matching:

- trim and lowercase the query;
- nickname match is case-insensitive;
- phone match works against both the displayed/raw number and a digits-only version;
- a query such as `109535` must match `+20 109 535 1020`;
- if nickname is null, search still works by phone number;
- do not search country/carrier in this version because those values are loaded independently per card and the approved hint promises only name or number.

Quick-filter rules:

- `all`: no extra predicate;
- `active`: `line.status.toLowerCase() == 'active' && !line.protectionPaused`;
- `alertSoon`: the line has an active schedule with `scheduleType == 'notify'` and `nextExecutionAt` is on or before `now + 30 days`. Include overdue alerts; do not require the date to be after `now`;
- `autoRefill`: the line has an active schedule whose type is `refill_mini` or `refill_custom`.

Use `ScheduledTopup.isActive` as the schedule activity source so the filter agrees with the protection chips already shown by `SimLineCard`.

Apply search and the selected quick filter together with logical AND. Preserve the controller's current deterministic line order; do not sort inside the filter helper.

Inject `now` only to make alert-soon tests deterministic; production callers omit it.

### 5. Screen state and integration

Add to `_SimLinesListScreenState`:

```dart
final TextEditingController _searchController = TextEditingController();
String _searchQuery = '';
SimLinesListFilter _selectedFilter = SimLinesListFilter.all;
bool _filtersExpanded = true;
```

Dispose `_searchController`.

In `build`:

1. Continue watching `simLinesControllerProvider`, countries, household state, and auth state.
2. Also watch `scheduledTopupControllerProvider` once at screen level.
3. Split the source list into owned and shared lists exactly as today.
4. Run both lists through `filterSimLines`.
5. Use the filtered list for rendering and for select-all/deselect behavior.
6. Continue using the original unfiltered list length for tab count badges and true-empty detection.
7. Do not mutate provider/controller state when search or filters change.

Refactor the body from a bare `Stack` containing `TabBarView` to:

```text
Column
├── search/filter header for the currently selected tab (when applicable)
└── Expanded
    └── Stack
        ├── TabBarView
        │   ├── owned results or owned empty/no-results state
        │   └── shared results or shared empty/no-results state
        └── existing bulk actions console
```

Because the selected tab index controls whether the header is visible, the TabController listener must still trigger a rebuild. Avoid clearing the search/filter values in that listener.

Schedule loading/error behavior:

- `All` and `Active` work even if schedules are loading or fail.
- Disable the two schedule-dependent chips unless `scheduledTopupControllerProvider` has a usable value.
- If a schedule-dependent filter is already selected and schedule data becomes unavailable during refresh, retain the last rendered list if Riverpod supplies a previous value. Do not flash a false `No matches` state merely because schedules are temporarily loading.

### 6. Remove the old banner without changing the add flow

In `_buildLinesList`:

- remove `lines.length + 1`;
- remove the `index == 0` branch;
- use `itemCount: lines.length`;
- use `final line = lines[index]`;
- pass `index` directly to `SimLineCard`.

Delete `_buildAddHeaderCard` completely.

Rename `_checkLineLimitAndAdd(BuildContext, int)` to a clearer no-count method such as `_openAddSim(BuildContext)`, because `myLinesCount` is not used. Preserve its complete implementation:

- push `/sim-lines/add`;
- invalidate SIM lines and schedules when the route returns;
- preserve the delayed 2.5-second and 5.5-second invalidations.

Update both callers:

- the new header Add SIM action;
- the existing owned empty-state button.

Do not reintroduce any account-level total-line cap. The database rule remains one free line per account, and the add form/database already enforce that business rule.

### 7. Empty and no-results states

Distinguish these cases:

1. Source list is empty: retain the existing owned/shared empty state and actions.
2. Source list is not empty but filtered list is empty: show a lightweight no-results state inside the tab.

No-results content:

- icon: `Icons.search_off_rounded`;
- title: localized `No matching SIMs`;
- description: localized `Try a different name, number, or filter.`;
- text button: localized `Clear search and filters`;
- clear action resets the controller text, `_searchQuery`, and filter to `all` in one `setState` call;
- do not show an Add SIM CTA in the no-results state because Add SIM is already in the header.

### 8. Localization

Reuse existing localization keys where semantics match:

- `protectedSims`
- `addSim`
- `active`
- `autoRefill`

Add these keys to every ARB source file:

- `mySims`
- `sharedWithMe`
- `searchNameOrNumber`
- `allFilter`
- `alertSoon`
- `showFilters`
- `hideFilters`
- `refreshSims`
- `noMatchingSims`
- `tryDifferentSimSearch`
- `clearSearchAndFilters`

English values:

```json
{
  "mySims": "My SIMs",
  "sharedWithMe": "Shared with me",
  "searchNameOrNumber": "Search name or number",
  "allFilter": "All",
  "alertSoon": "Alert soon",
  "showFilters": "Show filters",
  "hideFilters": "Hide filters",
  "refreshSims": "Refresh SIMs",
  "noMatchingSims": "No matching SIMs",
  "tryDifferentSimSearch": "Try a different name, number, or filter.",
  "clearSearchAndFilters": "Clear search and filters"
}
```

Use proper human translations in the other ARBs. Do not copy English into all locales as a placeholder. Run:

`flutter gen-l10n`

Then format affected Dart files. Verify the existing dirty localization additions remain present after regeneration.

## Detailed visual specification

The concept image is a visual target, not a source of business logic. Implement responsive Flutter widgets rather than fixed pixel positioning.

Light theme:

- background remains `AppColors.lightBg`;
- search field and unselected chips use white/light surfaces;
- outlines use `AppColors.lightBorder` at reduced opacity;
- primary content uses `AppColors.lightPrimary` or the approved cyan treatment;
- shadows should be subtle and limited to the Add button/filter button.

Dark theme:

- background remains `AppColors.darkBg`;
- controls use `AppColors.darkSurface`/`AppColors.darkCard`;
- outlines use `AppColors.darkBorder`;
- primary accents use `AppColors.primary`/`primaryLight` with accessible contrast.

Spacing:

- 16 dp page inset;
- 8 dp gap between search and filter button;
- 8 dp gap between chips;
- 10–12 dp vertical gap from search row to chip row;
- 12–16 dp gap below controls before the first card;
- retain the cards' existing own margins; do not create double 16 dp gaps.

Do not introduce a device frame, decorative illustration, marketing copy, new card design, or hardcoded mock data.

## Tests

### Pure filter tests

`test/features/sim_lines/sim_lines_list_filter_test.dart`

Cover at minimum:

1. Empty query plus `all` returns the same lines in the same order.
2. Nickname search is case-insensitive.
3. Phone search ignores spaces, `+`, hyphens, and parentheses.
4. Search and quick filter combine with AND.
5. Active includes only `status == active` and excludes `protectionPaused`.
6. Alert soon includes an active notify schedule within 30 days.
7. Alert soon includes an overdue active notify schedule.
8. Alert soon excludes a notify schedule after 30 days and an inactive schedule.
9. Auto-refill includes active `refill_mini` and `refill_custom`.
10. Auto-refill excludes `notify` and inactive refill schedules.
11. Filtering does not reorder the input list.

Use a fixed UTC `now` in date tests.

### Header widget tests

`test/features/sim_lines/sim_lines_list_header_test.dart`

Pump the widget inside `MaterialApp` with `AppLocalizations.localizationsDelegates` and `AppLocalizations.supportedLocales`.

Cover at minimum:

1. Search hint and filter button render.
2. Search callback receives typed text.
3. Clear button clears the controller and invokes `onClearSearch`.
4. Filter button invokes the expand/collapse callback.
5. All four chips appear when expanded.
6. Selecting a chip invokes the correct enum value.
7. Schedule-dependent chips are disabled when `scheduleFiltersEnabled` is false.
8. Non-All filter displays a badge; All does not.
9. No overflow at 320 logical-pixel width.
10. Arabic locale renders without overflow.

### Screen regression checks

If a full screen test can be added without creating a large mock-provider harness, also verify:

- old `Protect Another SIM Line` banner is absent;
- Add SIM action is present in normal mode;
- owner/shared count badges use unfiltered counts;
- no-results reset restores all lines;
- select-all targets only currently visible filtered lines.

Do not block this focused UI task on a broad integration-test rewrite.

## Verification commands

Run the narrowest checks first:

```powershell
flutter gen-l10n
dart format lib/features/sim_lines/presentation/screens/sim_lines_list_screen.dart lib/features/sim_lines/presentation/models/sim_lines_list_filter.dart lib/features/sim_lines/presentation/widgets/sim_lines_list_header.dart test/features/sim_lines/sim_lines_list_filter_test.dart test/features/sim_lines/sim_lines_list_header_test.dart
flutter test test/features/sim_lines/sim_lines_list_filter_test.dart
flutter test test/features/sim_lines/sim_lines_list_header_test.dart
flutter analyze lib/features/sim_lines test/features/sim_lines
```

If the Flutter SDK is locked by another IDE process, report the exact failed command and error. Do not claim checks passed if they did not run.

Manual verification on a phone-sized emulator/device:

1. Light mode, owner tab with several lines.
2. Dark mode.
3. Width around 320 dp; no overflow.
4. Text scaling at 1.3x and 2.0x; actions remain reachable.
5. Arabic RTL.
6. Search by mixed-case nickname.
7. Search a formatted phone number using digits only.
8. Each quick filter and reset.
9. Switch tabs while a search/filter is active.
10. Add SIM opens the existing form and returning refreshes the list.
11. Refresh action still works.
12. Pull-to-refresh still works.
13. Long-press selection and bulk actions still work.
14. True empty owner/shared tab still shows the existing empty state.
15. Filtered-empty state shows No matching SIMs and clears correctly.

## Acceptance criteria

- The oversized gradient add banner is completely removed from the non-empty owner list.
- A compact Add SIM action appears beside the title and opens the existing add route.
- Both tabs show correct, stable, unfiltered counts.
- Search filters the current tab by nickname or phone number without network calls.
- Quick filters use the definitions in this plan and combine with search.
- The filter badge reflects real non-default state and is never hardcoded.
- The page has distinct true-empty and no-results states.
- Existing cards and their actions are behaviorally unchanged.
- Selection mode, select-all, bulk actions, realtime refresh, manual refresh, pull-to-refresh, and post-add polling are preserved.
- Light, dark, narrow-screen, large-text, and RTL layouts have no overflow.
- New user-visible text is localized in every supported ARB.
- Focused tests and analysis pass, or any tooling blocker is reported accurately.
- No backend, route, database, controller, generated Riverpod, or unrelated working-tree changes are included.

## Executor completion report

When finished, report:

1. files changed/added;
2. concise behavior summary;
3. test/analyzer commands and their exact results;
4. any deviations from this plan and why;
5. confirmation that existing unrelated dirty changes were preserved;
6. screenshots for light mode, dark mode, narrow width, and Arabic RTL if emulator access is available.
