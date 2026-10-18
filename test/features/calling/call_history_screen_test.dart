import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/fx/fx_provider.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/calling/data/models/call_record_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/controllers/smart_call_dialer_controller.dart';
import 'package:keep_sims/features/calling/presentation/screens/call_history_screen.dart';
import 'package:keep_sims/features/calling/presentation/widgets/call_history_tile.dart';
import 'package:keep_sims/features/calling/presentation/widgets/call_review_sheet.dart';

import 'call_review_controller_test.dart' show ReviewRepository;

class _Auth extends AuthController {
  @override
  Future<UserProfile?> build() async =>
      const UserProfile(id: 'caller', homeCountryCode: 'EG');
}

class _UsdDisplay extends FxController {
  @override
  Future<FxContext> build() async => const FxContext();
}

CallRecord record({String number = '+201012345678'}) => CallRecord(
  id: 'record',
  userId: 'caller',
  callerNumber: '+96891234567',
  destinationNumber: number,
  destinationCountryCode: 'EG',
  destinationCountryName: 'Egypt',
  status: 'completed',
  startedAt: DateTime.utc(2026, 10, 15, 10),
  durationSeconds: 65,
  ratePerMinute: 9,
  totalCost: .32,
);

void main() {
  late ProviderContainer container;
  late ReviewRepository repository;
  late Stream<List<CallRecord>> Function() history;

  setUp(() {
    repository = ReviewRepository();
    history = () => Stream.value([record()]);
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_Auth.new),
        fxControllerProvider.overrideWith(_UsdDisplay.new),
        callingRepositoryProvider.overrideWithValue(repository),
        callHistoryStreamProvider.overrideWith((ref) => history()),
        callerIdListProvider.overrideWith(
          (ref) async => const CallerIdListResult(
            defaultGatewayNumber: '+17543180369',
            isGatewayActive: true,
            activeCallerId: '+17543180369',
            callerIds: [],
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> mount(
    WidgetTester tester, {
    bool settle = true,
    bool dark = false,
    bool arabic = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          locale: Locale(arabic ? 'ar' : 'en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const CallHistoryScreen(),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets(
    'redial opens fresh review without reusing historical price or caller ID',
    (tester) async {
      await mount(tester);
      expect(find.text('Recent calls'), findsOneWidget);
      expect(find.text('01:05'), findsOneWidget);
      expect(find.text(r'-$0.32'), findsOneWidget);
      expect(find.text('Dialer'), findsNothing);
      expect(repository.requests, isEmpty);
      await tester.tap(find.byTooltip('Call again'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(CallReviewSheet), findsOneWidget);
      expect(repository.requests.last.number, '+201012345678');
      expect(repository.requests.last.gateway, isTrue);
      expect(find.text('+17543180369'), findsOneWidget);
      expect(find.text(r'$0.095/min'), findsOneWidget);
      expect(find.text(r'$9.000/min'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('review-call-button')))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(CallReviewSheet), findsNothing);
      expect(find.byType(CallHistoryTile), findsOneWidget);
    },
  );

  testWidgets('national history still requires a new country confirmation', (
    tester,
  ) async {
    history = () => Stream.value([record(number: '01012345678')]);
    container.read(smartCallDialerProvider.notifier).selectCountry('OM');
    await mount(tester);
    await tester.tap(find.byTooltip('Call again'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('confirm-destination-country')),
      findsOneWidget,
    );
    expect(container.read(smartCallDialerProvider).selectedCountryIso, isNull);
    expect(repository.requests, isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('review-call-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('loading, empty and subsequent history updates stay on history', (
    tester,
  ) async {
    final updates = StreamController<List<CallRecord>>.broadcast();
    addTearDown(() {
      unawaited(updates.close());
    });
    history = () => updates.stream;
    await mount(tester, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    updates.add([]);
    await tester.pumpAndSettle();
    expect(find.text('No recent calls'), findsOneWidget);
    updates.add([record()]);
    await tester.pumpAndSettle();
    expect(find.byType(CallHistoryTile), findsOneWidget);
    expect(find.text('No recent calls'), findsNothing);
  });

  testWidgets('history error offers retry without exposing error details', (
    tester,
  ) async {
    history = () => Stream.error(StateError('private backend details'));
    await mount(tester);
    expect(find.text('Could not load recent calls.'), findsOneWidget);
    expect(find.textContaining('private backend'), findsNothing);
    history = () => Stream.value([]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No recent calls'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'Arabic history supports enlarged text on a small ${dark ? 'dark' : 'light'} screen',
      (tester) async {
        await mount(tester, dark: dark, arabic: true, scale: 1.6);
        expect(find.text('المكالمات الأخيرة'), findsOneWidget);
        expect(find.byTooltip('اتصل مرة أخرى'), findsOneWidget);
        expect(find.byType(CallHistoryTile), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
