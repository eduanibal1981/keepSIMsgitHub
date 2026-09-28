import 'package:flutter/material.dart';
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
}
