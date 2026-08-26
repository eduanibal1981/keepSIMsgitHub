import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/household/data/models/household_member_model.dart';
import 'package:keep_sims/features/household/data/repositories/household_repository_impl.dart';
import 'package:keep_sims/features/household/domain/repositories/household_repository.dart';
import 'package:keep_sims/features/household/presentation/screens/household_screen.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

/// The invite dialog laid its two role cards out in a `Row` with
/// `CrossAxisAlignment.stretch`. A dialog's content scrolls, so that Row was
/// handed an unbounded height and `stretch` turned it into a tight infinite
/// constraint: layout threw, the `Dialog` never got a size, and pressing
/// "Invite member" dimmed the screen with nothing drawn on it.
class _EmptyHouseholdRepository implements HouseholdRepository {
  @override
  Future<List<HouseholdMember>> getHouseholdMembers() async => const [];

  @override
  Future<List<HouseholdMember>> getHouseholdInvitations() async => const [];

  @override
  Future<List<HouseholdMember>> getMyMemberships() async => const [];

  @override
  Future<HouseholdActionResult> inviteMember(String email, String role) async =>
      const HouseholdActionResult(success: true);

  @override
  Future<HouseholdActionResult> respondToInvite(
    String inviteId,
    bool accept,
  ) async => const HouseholdActionResult(success: true);

  @override
  Future<HouseholdActionResult> removeMember(String id) async =>
      const HouseholdActionResult(success: true);

  @override
  Future<HouseholdActionResult> leaveHousehold(String id) async =>
      const HouseholdActionResult(success: true);
}

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          householdRepositoryProvider.overrideWithValue(
            _EmptyHouseholdRepository(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HouseholdScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('invite dialog lays out and is visible', (tester) async {
    // The device this was reported on reports a 450x800 logical viewport.
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await pumpScreen(tester);

    // The empty-state button calls the dialog directly; the FAB awaits a
    // haptic first, which is noise for a layout test.
    await tester.tap(find.text('Invite member').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    // A dialog that throws during layout still mounts — only its size gives it
    // away, which is exactly what the user saw: barrier up, nothing on it.
    expect(tester.getSize(dialog).height, greaterThan(0));
    expect(find.text('Invite a family member'), findsOneWidget);
  });

  testWidgets('picking Manager re-lays out without throwing', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await pumpScreen(tester);

    await tester.tap(find.text('Invite member').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Choosing Manager inserts the spend warning, which regrows the dialog.
    await tester.tap(find.text('Manager'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AlertDialog)).height, greaterThan(0));
  });
}
