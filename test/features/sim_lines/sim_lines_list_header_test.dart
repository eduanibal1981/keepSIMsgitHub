import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/presentation/models/sim_lines_list_filter.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/sim_lines_list_header.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

Widget createHeaderHarness({
  required TextEditingController searchController,
  SimLinesListFilter selectedFilter = SimLinesListFilter.all,
  bool filtersExpanded = true,
  bool scheduleFiltersEnabled = true,
  ValueChanged<String>? onSearchChanged,
  VoidCallback? onClearSearch,
  VoidCallback? onToggleFilters,
  ValueChanged<SimLinesListFilter>? onFilterChanged,
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Scaffold(
      body: SimLinesListHeader(
        searchController: searchController,
        selectedFilter: selectedFilter,
        filtersExpanded: filtersExpanded,
        scheduleFiltersEnabled: scheduleFiltersEnabled,
        onSearchChanged: onSearchChanged ?? (_) {},
        onClearSearch: onClearSearch ?? () {},
        onToggleFilters: onToggleFilters ?? () {},
        onFilterChanged: onFilterChanged ?? (_) {},
      ),
    ),
  );
}

void main() {
  group('SimLinesListHeader widget tests', () {
    testWidgets('1. Search hint and filter button render', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        createHeaderHarness(searchController: controller),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search name or number'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    testWidgets('2. Search callback receives typed text', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String receivedText = '';

      await tester.pumpWidget(
        createHeaderHarness(
          searchController: controller,
          onSearchChanged: (val) => receivedText = val,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Vodafone');
      await tester.pump();

      expect(receivedText, 'Vodafone');
      expect(controller.text, 'Vodafone');
    });

    testWidgets(
      '3. Clear button clears the controller and invokes onClearSearch',
      (tester) async {
        final controller = TextEditingController(text: 'My Query');
        addTearDown(controller.dispose);
        bool cleared = false;

        await tester.pumpWidget(
          createHeaderHarness(
            searchController: controller,
            onClearSearch: () => cleared = true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.clear_rounded));
        await tester.pump();

        expect(controller.text, isEmpty);
        expect(cleared, isTrue);
        expect(find.byIcon(Icons.clear_rounded), findsNothing);
      },
    );

    testWidgets('4. Filter button invokes the expand/collapse callback', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      bool toggled = false;

      await tester.pumpWidget(
        createHeaderHarness(
          searchController: controller,
          onToggleFilters: () => toggled = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();

      expect(toggled, isTrue);
    });

    testWidgets('5. All four chips appear when expanded', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        createHeaderHarness(
          searchController: controller,
          filtersExpanded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsNWidgets(4));
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Alert soon'), findsOneWidget);
      expect(find.text('Auto-Refill'), findsOneWidget);
    });

    testWidgets('6. Selecting a chip invokes the correct enum value', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      SimLinesListFilter? selected;

      await tester.pumpWidget(
        createHeaderHarness(
          searchController: controller,
          filtersExpanded: true,
          onFilterChanged: (f) => selected = f,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Active'));
      await tester.pump();
      expect(selected, SimLinesListFilter.active);

      await tester.tap(find.text('Alert soon'));
      await tester.pump();
      expect(selected, SimLinesListFilter.alertSoon);

      await tester.tap(find.text('Auto-Refill'));
      await tester.pump();
      expect(selected, SimLinesListFilter.autoRefill);
    });

    testWidgets(
      '7. Schedule-dependent chips are disabled when scheduleFiltersEnabled is false',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          createHeaderHarness(
            searchController: controller,
            filtersExpanded: true,
            scheduleFiltersEnabled: false,
          ),
        );
        await tester.pumpAndSettle();

        final alertSoonChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Alert soon'),
        );
        final autoRefillChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Auto-Refill'),
        );
        final activeChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Active'),
        );
        final allChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'All'),
        );

        expect(alertSoonChip.onSelected, isNull);
        expect(autoRefillChip.onSelected, isNull);
        expect(activeChip.onSelected, isNotNull);
        expect(allChip.onSelected, isNotNull);
      },
    );

    testWidgets('8. Non-All filter displays a badge; All does not', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      // When filter is "all", no badge
      await tester.pumpWidget(
        createHeaderHarness(
          searchController: controller,
          selectedFilter: SimLinesListFilter.all,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1'), findsNothing);

      // When filter is not "all", badge "1" is visible
      await tester.pumpWidget(
        createHeaderHarness(
          searchController: controller,
          selectedFilter: SimLinesListFilter.active,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('9. No overflow at 320 logical-pixel width', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        createHeaderHarness(
          searchController: controller,
          filtersExpanded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    testWidgets('10. Arabic locale renders without overflow', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        createHeaderHarness(
          searchController: controller,
          filtersExpanded: true,
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ابحث بالاسم أو الرقم'), findsOneWidget);
      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('تنبيه قريباً'), findsOneWidget);
    });

    testWidgets('11. Dark theme renders without error or overflow', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        createHeaderHarness(
          searchController: controller,
          filtersExpanded: true,
          theme: ThemeData.dark(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });
  });
}
