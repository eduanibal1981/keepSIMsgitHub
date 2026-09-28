import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/presentation/widgets/calling_mode_switcher.dart';
import 'package:keep_sims/features/household/data/models/household_member_model.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/voip_calling/data/models/voip_call_session_model.dart';
import 'package:keep_sims/features/voip_calling/data/repositories/voip_calling_repository.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';
import 'package:keep_sims/features/voip_calling/presentation/screens/internet_calling_screen.dart';

void main() {
  testWidgets('InternetCallingScreen renders WhatsApp-style voice calling tabs and headers', (tester) async {
    const mockSimLine = SimLine(
      id: 'test-sim-1',
      userId: 'test-user',
      phoneNumber: '+96891234567',
      nickname: 'Personal eSIM',
      avatarIcon: 'esim',
      countryId: 'OM',
      status: 'active',
      planType: 'free',
      protectionTier: 'standard',
      isAutoDetected: false,
      isHomeMode: false,
      protectionPaused: false,
      requiresProtectionAtHome: false,
      isCarrierVerified: true,
      carrierStatus: 'verified',
      detectedOperatorName: 'Omantel',
      healthScore: 100,
      verificationStatus: 'verified',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voipCallingRepositoryProvider.overrideWithValue(
            _FakeVoipCallingRepository(),
          ),
          simLinesControllerProvider.overrideWith(
            () => _FakeSimLinesController([mockSimLine]),
          ),
          householdControllerProvider.overrideWith(
            () => _FakeHouseholdController(),
          ),
          voipCallHistoryProvider.overrideWith(
            (ref) async => <VoipCallSession>[],
          ),
        ],
        child: const MaterialApp(
          home: InternetCallingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Badges
    expect(find.text('KeepSIMs Free Call'), findsOneWidget);
    expect(find.text('WhatsApp-Style Internet Audio (App-to-App)'), findsOneWidget);
    expect(find.text('100% FREE'), findsOneWidget);

    // Verify search bar
    expect(find.text('Search name or number (+968...)'), findsOneWidget);

    // Verify invite link banner
    expect(find.text('Share Free Call Link'), findsOneWidget);

    // Verify WhatsApp-style tabs
    expect(find.text('Recent Calls'), findsOneWidget);
    expect(find.text('Family & Contacts'), findsOneWidget);

    // Verify empty state for recent calls
    expect(find.text('No Recent Free Calls'), findsOneWidget);

    // Verify duplicate CallingModeSwitcher is NOT present
    expect(find.byType(CallingModeSwitcher), findsNothing);
  });
}

class _FakeVoipCallingRepository extends Fake implements VoipCallingRepository {
  @override
  String? get currentUserId => 'test-user';

  @override
  String? get currentUserPhone => '+96899999999';

  @override
  Future<List<VoipCallSession>> getCallHistory({int limit = 50}) async => [];

  @override
  Future<ContactLookupResult?> lookupContactByPhone(String phone) async => null;
}

class _FakeSimLinesController extends SimLinesController {
  final List<SimLine> initialLines;
  _FakeSimLinesController(this.initialLines);

  @override
  Future<List<SimLine>> build() async => initialLines;
}

class _FakeHouseholdController extends HouseholdController {
  @override
  Future<HouseholdState> build() async {
    return const HouseholdState(
      members: <HouseholdMember>[],
      invitations: <HouseholdMember>[],
      memberships: <HouseholdMember>[],
    );
  }
}
