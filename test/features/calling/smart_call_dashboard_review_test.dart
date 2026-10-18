import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/fx/fx_provider.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/controllers/smart_call_dialer_controller.dart';
import 'package:keep_sims/features/calling/presentation/screens/smart_call_dashboard_screen.dart';
import 'package:keep_sims/features/calling/presentation/screens/call_history_screen.dart';
import 'package:keep_sims/features/calling/presentation/widgets/call_review_sheet.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/features/wallet/model/wallet_model.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

import 'call_review_controller_test.dart' show ReviewRepository;

class _Auth extends AuthController {
  @override
  Future<UserProfile?> build() async => const UserProfile(
    id: 'caller',
    fullName: 'Caller',
    homeCountryCode: 'EG',
    onboardingCompleted: true,
  );
}

class _Wallet extends WalletController {
  @override
  Future<WalletState> build() async => const WalletState(
    wallet: Wallet(
      id: 'wallet',
      userId: 'caller',
      balance: 45,
      currency: 'USD',
    ),
    transactions: [],
  );
}

class _UsdDisplay extends FxController {
  @override
  Future<FxContext> build() async => const FxContext();
}

void main() {
  late ReviewRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = ReviewRepository();
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_Auth.new),
        walletControllerProvider.overrideWith(_Wallet.new),
        fxControllerProvider.overrideWith(_UsdDisplay.new),
        callingRepositoryProvider.overrideWithValue(repository),
        callHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
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

  Future<void> openReview(WidgetTester tester) async {
    final action = find.byTooltip('Call with Dialer');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byType(CallReviewSheet), findsOneWidget);
    expect(find.text('Review call'), findsOneWidget);
    expect(find.text('Dialer'), findsNothing);
  }

  Future<void> mount(WidgetTester tester, String number) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);
    container.read(smartCallDialerProvider.notifier).setNumber(number);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SmartCallDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await openReview(tester);
  }

  FilledButton callButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('review-call-button')));

  testWidgets('empty dashboard opens review with inline number entry', (
    tester,
  ) async {
    await mount(tester, '');
    final input = find.byKey(const Key('review-number-input'));
    expect(tester.widget<TextField>(input).autofocus, isTrue);
    expect(callButton(tester).onPressed, isNull);
    expect(repository.requests, isEmpty);

    await tester.enterText(input, '01012345678');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Use Egypt (+20)'), findsOneWidget);
    expect(repository.requests, isEmpty);
    expect(callButton(tester).onPressed, isNull);

    await tester.ensureVisible(
      find.byKey(const Key('confirm-destination-country')),
    );
    await tester.tap(find.byKey(const Key('confirm-destination-country')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(repository.requests.last.number, '+201012345678');
    expect(find.text('KeepSIMs number'), findsOneWidget);
    expect(find.text('+17543180369'), findsOneWidget);
    expect(find.text(r'$0.095/min'), findsOneWidget);
    expect(callButton(tester).onPressed, isNotNull);
  });

  testWidgets('selected national number opens review and requires country', (
    tester,
  ) async {
    await mount(tester, '01012345678');
    expect(
      find.descendant(
        of: find.byType(CallReviewSheet),
        matching: find.text('01012345678'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('review-number-input')), findsNothing);
    expect(find.text('Use Egypt (+20)'), findsOneWidget);
    expect(callButton(tester).onPressed, isNull);
    expect(repository.requests, isEmpty);
  });

  testWidgets('international number opens compact caller ID and rate review', (
    tester,
  ) async {
    await mount(tester, '+201012345678');
    expect(find.byKey(const Key('review-number-input')), findsNothing);
    expect(find.byKey(const Key('confirm-destination-country')), findsNothing);
    expect(repository.requests.last.number, '+201012345678');
    expect(find.text('KeepSIMs number'), findsOneWidget);
    expect(find.text('+17543180369'), findsOneWidget);
    expect(find.text(r'$0.095/min'), findsOneWidget);
    expect(callButton(tester).onPressed, isNotNull);
  });

  testWidgets('clearing and closing review returns an empty draft safely', (
    tester,
  ) async {
    await mount(tester, '+201012345678');
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('review-number-input')), '');
    await tester.pumpAndSettle();
    expect(callButton(tester).onPressed, isNull);
    expect(find.text(r'$0.095/min'), findsNothing);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(CallReviewSheet), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );

    await openReview(tester);
    expect(find.byKey(const Key('review-number-input')), findsOneWidget);
    expect(callButton(tester).onPressed, isNull);
  });

  testWidgets(
    'dashboard history and legacy links use dedicated history with working back navigation',
    (tester) async {
      container.listen(authControllerProvider, (_, _) {});
      await container.read(authControllerProvider.future);
      container.listen(appRouterProvider, (_, _) {});
      final router = container.read(appGoRouterProvider);
      container.read(splashCompletedProvider.notifier).complete();
      router.go(AppRoutes.calling);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(appRouterProvider),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recent calls'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.callingHistory,
      );
      expect(find.byType(CallHistoryScreen), findsOneWidget);
      expect(find.text('Dialer'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.calling);
      expect(find.byType(SmartCallDashboardScreen), findsOneWidget);

      for (final legacy in ['/calling/dialer', '/calling/dialer?tab=recent']) {
        router.go(legacy);
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.callingHistory,
        );
        expect(find.byType(CallHistoryScreen), findsOneWidget);
        expect(find.text('Dialer'), findsNothing);
      }
    },
  );
}
