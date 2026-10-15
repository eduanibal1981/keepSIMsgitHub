import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/fx/fx_provider.dart';
import 'package:keep_sims/features/calling/data/models/caller_id_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/controllers/smart_call_dialer_controller.dart';
import 'package:keep_sims/features/calling/presentation/widgets/call_review_sheet.dart';
import 'call_review_controller_test.dart' show ReviewRepository, quote;

class _UsdDisplay extends FxController {
  @override
  Future<FxContext> build() async => const FxContext();
}

void main() {
  late ReviewRepository repository;
  late ProviderContainer container;
  late CallerIdListResult currentIds;
  const ids = CallerIdListResult(
    defaultGatewayNumber: '+17543180369',
    isGatewayActive: true,
    activeCallerId: '+17543180369',
    callerIds: [
      CallerIdModel(
        id: 'verified-choice',
        phoneNumber: '+96891234567',
        label: 'Personal',
        isVerified: true,
      ),
      CallerIdModel(
        id: 'unverified',
        phoneNumber: '+96892312854',
        label: 'Pending',
      ),
    ],
  );
  setUp(() {
    repository = ReviewRepository();
    currentIds = ids;
    container = ProviderContainer(
      overrides: [
        callingRepositoryProvider.overrideWithValue(repository),
        callerIdListProvider.overrideWith((ref) async => currentIds),
        fxControllerProvider.overrideWith(_UsdDisplay.new),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> mount(
    WidgetTester tester,
    String raw, {
    String? suggestion,
    bool arabic = false,
    double scale = 1,
  }) async {
    container.read(smartCallDialerProvider.notifier).setNumber(raw);
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
          home: Scaffold(
            body: CallReviewSheet(suggestedCountryIso: suggestion),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  FilledButton callButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('review-call-button')));

  testWidgets(
    'country suggestion does not quote or enable Call before confirmation',
    (tester) async {
      await mount(tester, '01012345678', suggestion: 'EG');
      expect(repository.requests, isEmpty);
      expect(callButton(tester).onPressed, isNull);
      expect(find.text('Use Egypt (+20)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-destination-country')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repository.requests.single.number, '+201012345678');
      expect(callButton(tester).onPressed, isNotNull);
      expect(find.text(r'$0.095/min'), findsOneWidget);
      expect(find.text('Connection fee'), findsNothing);
    },
  );

  testWidgets(
    'only verified identities are selectable, even when gateway is saved default',
    (tester) async {
      await mount(tester, '+201012345678');
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(find.text('Pending'), findsNothing);
      repository.respond = () async =>
          quote(identity: '+96891234567', gateway: false);
      await tester.tap(find.text('+96891234567'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repository.requests.last.id, 'verified-choice');
      expect(repository.requests.last.gateway, isFalse);
      expect(find.text('My verified number'), findsOneWidget);
      expect(callButton(tester).onPressed, isNotNull);
    },
  );

  testWidgets(
    'reopening review retains an explicitly selected verified identity',
    (tester) async {
      container
          .read(smartCallDialerProvider.notifier)
          .selectIdentity(
            isGateway: false,
            callerIdId: 'verified-choice',
            phoneNumber: '+96891234567',
          );
      repository.respond = () async =>
          quote(identity: '+96891234567', gateway: false);
      await mount(tester, '+201012345678');
      expect(repository.requests.last.id, 'verified-choice');
      expect(repository.requests.last.gateway, isFalse);
      expect(callButton(tester).onPressed, isNotNull);
    },
  );

  testWidgets(
    'explicit gateway selection is retained over a saved personal default',
    (tester) async {
      currentIds = const CallerIdListResult(
        defaultGatewayNumber: '+17543180369',
        isGatewayActive: false,
        activeCallerId: '+96891234567',
        callerIds: [
          CallerIdModel(
            id: 'saved-personal',
            phoneNumber: '+96891234567',
            isVerified: true,
            isDefault: true,
          ),
        ],
      );
      container
          .read(smartCallDialerProvider.notifier)
          .selectIdentity(isGateway: true);
      await mount(tester, '+201012345678');
      expect(repository.requests.last.gateway, isTrue);
      expect(repository.requests.last.id, isNull);
      expect(find.text('KeepSIMs number'), findsOneWidget);
    },
  );

  testWidgets(
    'fees and billing interval are shown; low balance disables calling',
    (tester) async {
      repository.respond = () async =>
          quote(fee: .02, increment: 60, balance: 0);
      await mount(tester, '+201012345678');
      expect(find.text('Connection fee'), findsOneWidget);
      expect(find.text(r'$0.020'), findsOneWidget);
      expect(find.text('Billed every 60 seconds'), findsOneWidget);
      expect(find.text('Insufficient balance for this call.'), findsOneWidget);
      expect(find.text('Add funds'), findsOneWidget);
      expect(callButton(tester).onPressed, isNull);
    },
  );

  testWidgets('quote error supports Retry and cannot show an old price', (
    tester,
  ) async {
    repository.respond = () async => throw Exception('private details');
    await mount(tester, '+201012345678');
    expect(callButton(tester).onPressed, isNull);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text(r'$0.095/min'), findsNothing);
    repository.respond = () async => quote();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(callButton(tester).onPressed, isNotNull);
  });

  testWidgets('small Arabic layout supports enlarged text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(
      tester,
      '01012345678',
      suggestion: 'EG',
      arabic: true,
      scale: 1.6,
    );
    expect(find.text('مراجعة المكالمة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('review-call-button')));
    expect(tester.takeException(), isNull);
  });
}
