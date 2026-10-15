import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/calling/presentation/screens/smart_call_dashboard_screen.dart';
import 'package:keep_sims/features/calling/presentation/controllers/smart_call_dialer_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/features/wallet/model/wallet_model.dart';
import 'package:keep_sims/features/voip_calling/data/repositories/voip_calling_repository.dart';
import 'package:keep_sims/features/voip_calling/data/services/free_call_invitation_service.dart';
import 'package:keep_sims/features/voip_calling/data/models/voip_call_session_model.dart';
import 'package:keep_sims/features/voip_calling/domain/free_call_history_group.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/free_call_review_controller.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';
import 'package:keep_sims/features/voip_calling/presentation/widgets/free_call_review_sheet.dart';

const number = '+201012345678';
const found = FreeRecipientResolution(
  FreeRecipientStatus.found,
  ContactLookupResult(
    userId: 'peer',
    fullName: 'Sara',
    phone: number,
    isOnline: false,
  ),
);

class ReviewRepo extends Fake implements VoipCallingRepository {
  String? account = 'caller';
  final requests = <({String? phone, String? userId})>[];
  Future<FreeRecipientResolution> Function(String? phone, String? userId)
  response = (p, u) async => found;
  @override
  String? get currentUserId => account;
  @override
  Future<FreeRecipientResolution> resolveFreeCallRecipient({
    String? phone,
    String? userId,
  }) {
    requests.add((phone: phone, userId: userId));
    return response(phone, userId);
  }
}

class _Auth extends AuthController {
  @override
  Future<UserProfile?> build() async =>
      const UserProfile(id: 'caller', fullName: 'My profile');
}

class _Active extends VoipCallingController {
  @override
  VoipActiveCallState build() => const VoipActiveCallState();
}

class _Wallet extends WalletController {
  @override
  Future<WalletState> build() async => const WalletState(
    wallet: Wallet(id: 'w', userId: 'caller', balance: 45, currency: 'USD'),
    transactions: [],
  );
}

class Invites extends FreeCallInvitationService {
  final requests = <({FreeCallInviteChannel channel, String number})>[];
  bool available = true;
  @override
  Future<bool> compose(
    FreeCallInviteChannel channel,
    String number, {
    bool arabic = false,
  }) async {
    requests.add((channel: channel, number: number));
    return available;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReviewRepo repo;
  late Invites invites;
  late ProviderContainer container;
  late Future<PermissionStatus> Function() permission;
  setUp(() {
    repo = ReviewRepo();
    invites = Invites();
    permission = () async => PermissionStatus.denied;
    container = ProviderContainer(
      overrides: [
        freeCallAccountProvider.overrideWith((ref) => repo.account),
        authControllerProvider.overrideWith(_Auth.new),
        voipCallingRepositoryProvider.overrideWithValue(repo),
        freeCallInvitationServiceProvider.overrideWithValue(invites),
        voipCallingControllerProvider.overrideWith(_Active.new),
        freeCallMicrophoneProvider.overrideWithValue(() => permission()),
        walletControllerProvider.overrideWith(_Wallet.new),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
  }

  void keep(FreeCallSelection selection) {
    container.listen(freeCallReviewProvider(selection), (_, _) {});
  }

  test(
    'national number waits for country and resolves canonical digits',
    () async {
      const selection = FreeCallSelection(rawNumber: '٠١٠١٢٣٤٥٦٧٨');
      keep(selection);
      await settle();
      expect(repo.requests, isEmpty);
      final controller = container.read(
        freeCallReviewProvider(selection).notifier,
      );
      await controller.confirmCountry('EG');
      expect(repo.requests.single.phone, number);
      expect(container.read(freeCallReviewProvider(selection)).canCall, isTrue);
    },
  );
  test('known account uses authorized ID lookup instead of phone', () async {
    const selection = FreeCallSelection(knownUserId: 'peer');
    keep(selection);
    await settle();
    expect(repo.requests.single, (phone: null, userId: 'peer'));
  });
  test(
    'an edit immediately clears recipient and discards old response',
    () async {
      final pending = Completer<FreeRecipientResolution>();
      repo.response = (p, u) => pending.future;
      const selection = FreeCallSelection(rawNumber: number);
      keep(selection);
      await settle();
      final controller = container.read(
        freeCallReviewProvider(selection).notifier,
      );
      controller.setNumber('+96891234567');
      expect(
        container.read(freeCallReviewProvider(selection)).canCall,
        isFalse,
      );
      pending.complete(found);
      await settle();
      expect(
        container.read(freeCallReviewProvider(selection)).recipient,
        isNull,
      );
    },
  );
  test('clearing cancels lookup eligibility', () async {
    const selection = FreeCallSelection(rawNumber: number);
    keep(selection);
    await settle();
    container.read(freeCallReviewProvider(selection).notifier).setNumber('');
    expect(container.read(freeCallReviewProvider(selection)).canCall, isFalse);
    expect(
      container.read(freeCallReviewProvider(selection)).canInvite,
      isFalse,
    );
  });
  test('account switching rejects old callback', () async {
    final pending = Completer<FreeRecipientResolution>();
    repo.response = (p, u) => pending.future;
    const selection = FreeCallSelection(rawNumber: number);
    keep(selection);
    await settle();
    repo.account = 'different';
    pending.complete(found);
    await settle();
    expect(container.read(freeCallReviewProvider(selection)).canCall, isFalse);
  });
  test('self result cannot call or invite', () async {
    repo.response = (p, u) async => const FreeRecipientResolution(
      FreeRecipientStatus.found,
      ContactLookupResult(
        userId: 'caller',
        fullName: 'Me',
        phone: number,
        isOnline: true,
      ),
    );
    const selection = FreeCallSelection(rawNumber: number);
    keep(selection);
    await settle();
    final state = container.read(freeCallReviewProvider(selection));
    expect(state.resolution?.status, FreeRecipientStatus.self);
    expect(state.canCall, isFalse);
    expect(state.canInvite, isFalse);
  });
  test('network failure stays distinct from no match', () async {
    repo.response = (p, u) async => throw StateError('offline');
    const selection = FreeCallSelection(rawNumber: number);
    keep(selection);
    await settle();
    final state = container.read(freeCallReviewProvider(selection));
    expect(state.failed, isTrue);
    expect(state.canInvite, isFalse);
  });
  test('changed recipient on final refresh needs a new tap', () async {
    const selection = FreeCallSelection(rawNumber: number);
    keep(selection);
    await settle();
    repo.response = (p, u) async => const FreeRecipientResolution(
      FreeRecipientStatus.found,
      ContactLookupResult(
        userId: 'new-peer',
        fullName: 'New recipient',
        phone: number,
        isOnline: false,
      ),
    );
    expect(
      await container
          .read(freeCallReviewProvider(selection).notifier)
          .prepareCall(),
      isNull,
    );
    expect(
      container.read(freeCallReviewProvider(selection)).recipient?.userId,
      'new-peer',
    );
  });
  test('unconfirmed and unavailable accounts never invite', () async {
    const selection = FreeCallSelection(rawNumber: number);
    keep(selection);
    await settle();
    for (final status in [
      FreeRecipientStatus.ambiguous,
      FreeRecipientStatus.unverified,
      FreeRecipientStatus.unavailable,
    ]) {
      repo.response = (p, u) async => FreeRecipientResolution(status);
      await container
          .read(freeCallReviewProvider(selection).notifier)
          .resolve();
      expect(
        container.read(freeCallReviewProvider(selection)).canInvite,
        isFalse,
      );
    }
  });
  test('malformed backend response and mismatched account fail safely', () {
    expect(
      () => FreeRecipientResolution.parse([], phone: number),
      throwsFormatException,
    );
    expect(
      () => FreeRecipientResolution.parse({
        'status': 'not_found',
        'phone': '+96891234567',
      }, phone: number),
      throwsFormatException,
    );
    expect(
      () => FreeRecipientResolution.parse({
        'status': 'found',
        'recipient': {'user_id': 'wrong'},
      }, userId: 'peer'),
      throwsFormatException,
    );
  });
  test(
    'grouping retains individual statuses, directions and separate peers',
    () {
      VoipCallSession call(
        String id,
        String peer,
        int day, {
        String status = 'missed',
        bool outgoing = true,
      }) => VoipCallSession(
        id: id,
        callerId: outgoing ? 'caller' : peer,
        calleeId: outgoing ? peer : 'caller',
        isOutgoing: outgoing,
        status: status,
        startedAt: DateTime(2026, 10, day, 12),
        peerName: 'Same name',
      );
      final groups = groupFreeCallHistory([
        call('a', 'one', 15),
        call('b', 'one', 15, status: 'declined', outgoing: false),
        call('c', 'two', 15),
        call('d', 'one', 14),
      ]);
      expect(groups.length, 3);
      expect(groups.first.calls.length, 2);
      expect(groups.first.allMissed, isFalse);
      expect(groups.expand((g) => g.calls).map((c) => c.id).toSet(), {
        'a',
        'b',
        'c',
        'd',
      });
    },
  );
  test(
    'SMS composition addresses exactly one confirmed number with no send API',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MethodCall? received;
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.keep_sims/invitations'),
        (call) async {
          received = call;
          return true;
        },
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('com.keep_sims/invitations'),
          null,
        ),
      );
      expect(
        await FreeCallInvitationService().compose(
          FreeCallInviteChannel.sms,
          number,
        ),
        isTrue,
      );
      expect(received?.method, 'composeSms');
      expect((received!.arguments as Map)['phone'], number);
      expect(
        (received!.arguments as Map)['body'],
        contains('Install the app and sign in'),
      );
    },
  );
  test(
    'WhatsApp opens an editable invitation for international digits',
    () async {
      Uri? opened;
      final service = FreeCallInvitationService(
        launcher: (uri) async {
          opened = uri;
          return true;
        },
      );
      expect(
        await service.compose(FreeCallInviteChannel.whatsapp, number),
        isTrue,
      );
      final uri = opened!;
      expect(uri.scheme, 'whatsapp');
      expect(uri.queryParameters['phone'], '201012345678');
      expect(
        uri.queryParameters['text'],
        contains('Install the app and sign in'),
      );
      expect(uri.toString(), isNot(contains('keepsims.com/app')));
    },
  );

  Future<void> mount(
    WidgetTester tester, {
    bool arabic = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(arabic ? 'ar' : 'en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: FreeCallReviewSheet(
              selection: FreeCallSelection(rawNumber: number),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'no match shows app requirement and two user-send invitation options',
    (tester) async {
      repo.response = (p, u) async =>
          const FreeRecipientResolution(FreeRecipientStatus.notFound);
      await mount(tester);
      expect(find.byKey(const Key('free-app-requirement')), findsOneWidget);
      expect(find.byKey(const Key('free-review-call')), findsNothing);
      await tester.tap(find.byKey(const Key('free-invite-whatsapp')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('free-invite-sms')));
      await tester.pumpAndSettle();
      expect(invites.requests.map((r) => r.channel), [
        FreeCallInviteChannel.whatsapp,
        FreeCallInviteChannel.sms,
      ]);
      expect(invites.requests.every((r) => r.number == number), isTrue);
    },
  );

  testWidgets(
    'dashboard carries the selected national number into the quick sheet',
    (tester) async {
      container.read(smartCallDialerProvider.notifier).setNumber('01012345678');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SmartCallDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Call free'));
      await tester.tap(find.text('Call free'));
      await tester.pumpAndSettle();
      expect(find.byType(FreeCallReviewSheet), findsOneWidget);
      expect(find.text('01012345678'), findsWidgets);
      expect(find.text('Choose country'), findsOneWidget);
      expect(repo.requests, isEmpty);
    },
  );

  Future<void> modal(
    WidgetTester tester,
    void Function(FreeCallReviewOutcome?) record,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  record(
                    await showModalBottomSheet<FreeCallReviewOutcome>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const FreeCallReviewSheet(
                        selection: FreeCallSelection(rawNumber: number),
                      ),
                    ),
                  );
                },
                child: const Text('Open review'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Call rechecks identity after permission and ignores duplicate taps',
    (tester) async {
      final microphone = Completer<PermissionStatus>();
      permission = () => microphone.future;
      FreeCallReviewOutcome? outcome;
      await modal(tester, (value) => outcome = value);
      await tester.tap(find.byKey(const Key('free-review-call')));
      await tester.tap(find.byKey(const Key('free-review-call')));
      microphone.complete(PermissionStatus.granted);
      await tester.pumpAndSettle();
      expect(repo.requests.length, 2);
      expect(outcome?.recipient?.userId, 'peer');
      expect(outcome?.callerId, 'caller');
      expect(find.byType(FreeCallReviewSheet), findsNothing);
    },
  );
  testWidgets(
    'paid fallback returns the same canonical number without starting a call',
    (tester) async {
      repo.response = (p, u) async =>
          const FreeRecipientResolution(FreeRecipientStatus.notFound);
      FreeCallReviewOutcome? outcome;
      await modal(tester, (value) => outcome = value);
      await tester.tap(find.text('See paid call rate'));
      await tester.pumpAndSettle();
      expect(outcome?.paidNumber, number);
      expect(outcome?.recipient, isNull);
      expect(invites.requests, isEmpty);
    },
  );
  testWidgets(
    'registered recipient with no online hint still allows a reviewed attempt',
    (tester) async {
      await mount(tester);
      expect(find.text('Sara'), findsOneWidget);
      expect(find.text('On KeepSIMs'), findsOneWidget);
      expect(find.byKey(const Key('free-review-call')), findsOneWidget);
      expect(find.byKey(const Key('free-invite-whatsapp')), findsNothing);
      expect(find.text('Online'), findsNothing);
      await tester.tap(find.byKey(const Key('free-review-call')));
      await tester.pumpAndSettle();
      expect(
        find.text('Allow microphone access to make this call.'),
        findsOneWidget,
      );
      expect(repo.requests.length, 1);
    },
  );
  testWidgets('lookup failure shows Retry without invitations', (tester) async {
    repo.response = (p, u) async => throw StateError('network');
    await mount(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byKey(const Key('free-invite-sms')), findsNothing);
    expect(find.textContaining('No KeepSIMs account found'), findsNothing);
  });
  testWidgets('missing channel offers explicit share fallback', (tester) async {
    repo.response = (p, u) async =>
        const FreeRecipientResolution(FreeRecipientStatus.notFound);
    invites.available = false;
    await mount(tester);
    await tester.tap(find.byKey(const Key('free-invite-whatsapp')));
    await tester.pumpAndSettle();
    expect(find.text('Share invitation'), findsOneWidget);
    expect(find.textContaining('WhatsApp is unavailable'), findsOneWidget);
  });
  testWidgets('Edit removes invitations and invalidates old recipient', (
    tester,
  ) async {
    repo.response = (p, u) async =>
        const FreeRecipientResolution(FreeRecipientStatus.notFound);
    await mount(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '01012345678');
    expect(find.byKey(const Key('free-invite-sms')), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Choose country'), findsOneWidget);
    expect(repo.requests.length, 1);
  });
  testWidgets('small Arabic large-text invitation layout does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo.response = (p, u) async =>
        const FreeRecipientResolution(FreeRecipientStatus.notFound);
    await mount(tester, arabic: true, scale: 1.6);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('free-invite-sms')));
    expect(find.text('دعوة عبر الرسائل النصية'), findsOneWidget);
  });
}
