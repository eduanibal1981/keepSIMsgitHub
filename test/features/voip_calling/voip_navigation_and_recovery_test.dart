import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';

void main() {
  group('FilteringRouterConfig Delegation Tests', () {
    testWidgets('exposes rawRouter and delegates go, push, pop correctly', (tester) async {
      final goRouter = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/voip-call',
            builder: (context, state) => const Scaffold(body: Text('VoipCall')),
          ),
          GoRoute(
            path: '/voip-call/:callId',
            builder: (context, state) => Scaffold(
              body: Text('VoipCallWithId: ${state.pathParameters['callId']}'),
            ),
          ),
        ],
      );

      final filteringProvider = FilteringRouteInformationProvider(
        goRouter.routeInformationProvider,
      );
      final routerConfig = FilteringRouterConfig(goRouter, filteringProvider);

      await tester.pumpWidget(MaterialApp.router(routerConfig: routerConfig));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(routerConfig.rawRouter, equals(goRouter));
      expect(routerConfig.routeInformationParser, equals(goRouter.routeInformationParser));
      expect(routerConfig.routerDelegate, equals(goRouter.routerDelegate));
      expect(routerConfig.backButtonDispatcher, equals(goRouter.backButtonDispatcher));

      // Test navigation delegation via go
      routerConfig.go('/voip-call/test-call-456');
      await tester.pumpAndSettle();

      expect(find.text('VoipCallWithId: test-call-456'), findsOneWidget);
      expect(
        goRouter.routerDelegate.currentConfiguration.uri.path,
        equals('/voip-call/test-call-456'),
      );

      // Test navigation delegation via push (do not await since push resolves on pop)
      routerConfig.push('/voip-call');
      await tester.pumpAndSettle();

      expect(find.text('VoipCall'), findsOneWidget);

      // Test pop
      routerConfig.pop();
      await tester.pumpAndSettle();

      expect(find.text('VoipCallWithId: test-call-456'), findsOneWidget);
    });
  });

  group('AppRoutes VoIP Routes Definition', () {
    test('voipCall path is properly formatted', () {
      expect(AppRoutes.voipCall, equals('/voip-call'));
    });
  });

  group('Cold Start VoIP Fast Direct Launch Tests', () {
    test('initialAcceptedCallProvider returns null by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(initialAcceptedCallProvider), isNull);
    });

    test('initialAcceptedCallProvider provides call data when overridden at launch', () {
      final container = ProviderContainer(
        overrides: [
          initialAcceptedCallProvider.overrideWithValue({
            'callId': 'test-call-123',
            'callerName': 'Bob',
            'callerAvatar': '',
            'callerPhone': '+1234567890',
          }),
        ],
      );
      addTearDown(container.dispose);

      final call = container.read(initialAcceptedCallProvider);
      expect(call, isNotNull);
      expect(call!['callId'], equals('test-call-123'));
      expect(call['callerName'], equals('Bob'));
    });

    testWidgets('Cold start with accepted call routes directly to /voip-call/:id bypassing splash and home', (tester) async {
      final callData = {
        'callId': 'direct-call-999',
        'callerName': 'John Doe',
        'callerAvatar': '',
        'callerPhone': '+15559999',
      };

      final hasInitialAcceptedCall =
          callData['callId'] != null && callData['callId']!.isNotEmpty;
      final initialLocation = hasInitialAcceptedCall
          ? '${AppRoutes.voipCall}/${callData['callId']}'
          : AppRoutes.splash;

      final goRouter = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: AppRoutes.splash,
            builder: (context, state) => const Scaffold(body: Text('SplashScreen')),
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const Scaffold(body: Text('HomeScreen')),
          ),
          GoRoute(
            path: '${AppRoutes.voipCall}/:callId',
            builder: (context, state) => Scaffold(
              body: Text('VoIP Call Screen: ${state.pathParameters['callId']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: goRouter));
      await tester.pumpAndSettle();

      // Ensure SplashScreen and HomeScreen were never built or displayed
      expect(find.text('SplashScreen'), findsNothing);
      expect(find.text('HomeScreen'), findsNothing);
      // Ensure VoIP Call Screen is immediately rendered
      expect(find.text('VoIP Call Screen: direct-call-999'), findsOneWidget);
    });
  });
}
