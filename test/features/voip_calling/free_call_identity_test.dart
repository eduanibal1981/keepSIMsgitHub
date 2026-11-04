import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/voip_calling/domain/free_call_identity.dart';
import 'package:keep_sims/features/voip_calling/domain/free_call_history_group.dart';
import 'package:keep_sims/features/voip_calling/data/models/voip_call_session_model.dart';
import 'package:keep_sims/features/voip_calling/data/repositories/voip_calling_repository.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/free_call_review_controller.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';
import 'package:keep_sims/features/voip_calling/presentation/screens/internet_calling_screen.dart';

const publicId = 'KEG-7M4Q9D2F';
const found = FreeRecipientResolution(
  FreeRecipientStatus.found,
  ContactLookupResult(
    userId: 'peer',
    fullName: 'Sara',
    publicId: publicId,
    phone: '',
    isOnline: false,
  ),
);

class _Repo extends Fake implements VoipCallingRepository {
  final requests = <FreeCallIdentifier>[];
  final phoneRequests = <String?>[];
  final changes = <String>[];
  Future<FreeRecipientResolution> Function() response = () async => found;
  bool byEmail = false;
  @override
  String? get currentUserId => 'caller';
  @override
  Future<FreeCallIdentity> getIdentity() async => FreeCallIdentity(
    publicId: 'KXX-8F3Q7M2A',
    emailVerified: true,
    discoverByEmail: byEmail,
  );
  @override
  Future<void> setDiscovery({required bool byId, required bool byEmail}) async {
    this.byEmail = byEmail;
    changes.add('email:$byEmail');
  }

  @override
  Future<FreeRecipientResolution> resolveIdentifier(
    FreeCallIdentifier identifier,
  ) {
    requests.add(identifier);
    return response();
  }

  @override
  Future<FreeRecipientResolution> resolveFreeCallRecipient({
    String? phone,
    String? userId,
  }) {
    phoneRequests.add(phone);
    return response();
  }
}

class _Auth extends AuthController {
  @override
  Future<UserProfile?> build() async => const UserProfile(id: 'caller');
}

class _Lines extends SimLinesController {
  @override
  Future<List<SimLine>> build() async => [];
}

class _Household extends HouseholdController {
  @override
  Future<HouseholdState> build() async =>
      const HouseholdState(members: [], invitations: [], memberships: []);
}

class _Calling extends VoipCallingController {
  @override
  VoipActiveCallState build() => const VoipActiveCallState();
}

VoipCallSession history(
  String peer, {
  String? name,
  String? phone,
  String? id,
  String? email,
}) => VoipCallSession(
  id: peer,
  callerId: 'caller',
  calleeId: peer,
  startedAt: DateTime(2026, 11, 1),
  status: 'missed',
  isOutgoing: true,
  peerName: name,
  peerPhone: phone,
  peerPublicId: id,
  peerEmail: email,
);

void main() {
  test(
    'only complete identifiers normalize; international parsing preserves the full country code',
    () {
      for (final raw in [
        'abd',
        '+20',
        'user@',
        'KEG-7M',
        '01012345678',
        'KEG-0I1LO234',
        '+20*123#',
      ]) {
        expect(FreeCallIdentifier.parse(raw), isNull, reason: raw);
      }
      expect(FreeCallIdentifier.parse(' keg 7m4q9d2f ')?.value, publicId);
      expect(
        FreeCallIdentifier.parse(' USER+tag@Example.COM ')?.value,
        'user+tag@example.com',
      );
      expect(
        FreeCallIdentifier.parse('+٢٠ ١٠١٢٣٤٥٦٧٨')?.value,
        '+201012345678',
      );
      expect(FreeCallIdentifier.parse('+968 9123 4567')?.value, '+96891234567');
    },
  );
  test(
    'recent filtering uses recorded names, phones, IDs and permitted emails, with no deduplication by display name',
    () {
      final calls = [
        history('one', name: 'Abdullah', phone: '+201012345678', id: publicId),
        history('two', name: 'Abdullah', email: 'sara@example.test'),
      ];
      expect(filterFreeCallHistory(calls, 'abd'), hasLength(2));
      expect(filterFreeCallHistory(calls, '+2010').single.peerId, 'one');
    expect(filterFreeCallHistory(calls, '+٢٠١٠').single.peerId, 'one');
      expect(filterFreeCallHistory(calls, 'keg7m').single.peerId, 'one');
      expect(filterFreeCallHistory(calls, 'sara@').single.peerId, 'two');
      expect(filterFreeCallHistory(calls, ''), calls);
      expect(groupFreeCallHistory(calls), hasLength(2));
    },
  );

  Future<void> mount(
    WidgetTester tester,
    _Repo repo, {
    List<VoipCallSession> calls = const [],
    bool arabic = false,
    double scale = 1,
    bool keyboard = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          freeCallAccountProvider.overrideWithValue('caller'),
          authControllerProvider.overrideWith(_Auth.new),
          voipCallingRepositoryProvider.overrideWithValue(repo),
          voipCallingControllerProvider.overrideWith(_Calling.new),
          simLinesControllerProvider.overrideWith(_Lines.new),
          householdControllerProvider.overrideWith(_Household.new),
          voipCallHistoryProvider.overrideWith((ref) async => calls),
        ],
        child: MaterialApp(
          locale: Locale(arabic ? 'ar' : 'en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: keyboard
                  ? const EdgeInsets.only(bottom: 280)
                  : EdgeInsets.zero,
            ),
            child: child!,
          ),
          home: const InternetCallingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'typing locally filters Recent and invalid submissions make zero global requests',
    (tester) async {
      final repo = _Repo();
      await mount(
        tester,
        repo,
        calls: [
          history('one', name: 'Abdullah'),
          history('two', name: 'Sara'),
        ],
      );
      await tester.enterText(find.byType(TextField), 'abd');
      await tester.pump();
      expect(find.text('Abdullah'), findsOneWidget);
      expect(find.text('Sara'), findsNothing);
      for (final partial in ['+20', 'user@', 'KEG-7M']) {
        await tester.enterText(find.byType(TextField), partial);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        expect(repo.requests, isEmpty);
        expect(repo.phoneRequests, isEmpty);
      }
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('Sara'), findsOneWidget);
    },
  );

  for (final input in [publicId, '+201012345678', 'sara@example.test']) {
    testWidgets(
      'submitted $input resolves once, waits, and confirms without calling or adding history',
      (tester) async {
        final repo = _Repo();
        final pending = Completer<FreeRecipientResolution>();
        repo.response = () => pending.future;
        await mount(tester, repo);
        await tester.enterText(find.byType(TextField), input);
        await tester.pump();
        expect(repo.requests, isEmpty);
        await tester.tap(find.byTooltip('Search'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(repo.requests, hasLength(1));
        expect(find.text('Checking KeepSIMs account…'), findsOneWidget);
        pending.complete(found);
        await tester.pumpAndSettle();
        expect(find.text('Sara'), findsOneWidget);
        expect(find.byKey(const Key('free-review-call')), findsOneWidget);
        expect(repo.requests, hasLength(1));
        expect(repo.phoneRequests, isEmpty);
        expect(find.text('No recent free calls'), findsOneWidget);
      },
    );
  }

  testWidgets('no match is generic and offers invitation sharing', (
    tester,
  ) async {
    final repo = _Repo();
    repo.response = () async =>
        const FreeRecipientResolution(FreeRecipientStatus.notFound);
    await mount(tester, repo);
    await tester.enterText(find.byType(TextField), publicId);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(
      find.text('No available KeepSIMs account found for this identifier.'),
      findsOneWidget,
    );
    expect(find.text('Share invitation'), findsOneWidget);
    expect(find.byKey(const Key('free-review-call')), findsNothing);
  });

  testWidgets(
    'ID copy uses the clipboard and privacy requires an explicit email opt-in',
    (tester) async {
      final repo = _Repo();
      final clipboard = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await mount(tester, repo);
      await tester.tap(find.byTooltip('Copy KeepSIMs ID'));
      await tester.pump();
      expect(clipboard, ['KXX-8F3Q7M2A']);
      await tester.tap(find.byTooltip('Free Call privacy'));
      await tester.pumpAndSettle();
      expect(repo.changes, isEmpty);
      await tester.tap(find.text('Find me by verified email'));
      await tester.pumpAndSettle();
      expect(repo.changes, ['email:true']);
    },
  );

  testWidgets(
    'small Arabic screen with keyboard and large text keeps tabs and has no overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, _Repo(), arabic: true, scale: 1.5, keyboard: true);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('الأخيرة'), findsOneWidget);
      expect(find.text('الأشخاص'), findsOneWidget);
    },
  );
}
