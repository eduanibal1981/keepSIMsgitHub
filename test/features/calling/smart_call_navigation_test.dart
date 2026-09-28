import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/calling/presentation/widgets/smart_call_navigation.dart';

void main() {
  group('SmartCallNavigation', () {
    test('correctly maps URL routes to destination indices', () {
      expect(SmartCallNavigation.getSelectedIndex('/calling'), 0);
      expect(SmartCallNavigation.getSelectedIndex('/calling/internet'), 1);
      expect(SmartCallNavigation.getSelectedIndex('/calling/my-numbers'), 2);
      expect(SmartCallNavigation.getSelectedIndex('/calling/savings'), 3);
      expect(SmartCallNavigation.getSelectedIndex('/calling/voicemail'), 4);
      expect(SmartCallNavigation.getSelectedIndex('/calling/voicemail/msg-123'), 4);
      expect(SmartCallNavigation.getSelectedIndex('/calling/sip-test'), 5);
      // Fallback
      expect(SmartCallNavigation.getSelectedIndex('/other'), 0);
    });

    test('correctly returns routes for indices', () {
      expect(SmartCallNavigation.getRouteForIndex(0), AppRoutes.calling);
      expect(SmartCallNavigation.getRouteForIndex(1), AppRoutes.internetCalling);
      expect(SmartCallNavigation.getRouteForIndex(2), AppRoutes.myNumbers);
      expect(SmartCallNavigation.getRouteForIndex(3), AppRoutes.callingSavings);
      expect(SmartCallNavigation.getRouteForIndex(4), AppRoutes.voicemail);
      expect(SmartCallNavigation.getRouteForIndex(5), AppRoutes.sipDiagnostics);
    });

    testWidgets('renders all 6 navigation destinations', (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.calling,
        routes: [
          GoRoute(
            path: AppRoutes.calling,
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Dialer Page')),
              bottomNavigationBar: SmartCallNavigation(),
            ),
          ),
          GoRoute(
            path: AppRoutes.internetCalling,
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Free Call Page')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dialer'), findsOneWidget);
      expect(find.text('Free Call'), findsOneWidget);
      expect(find.text('Numbers'), findsOneWidget);
      expect(find.text('Savings'), findsOneWidget);
      expect(find.text('Voicemail'), findsOneWidget);
      expect(find.text('Inspector'), findsOneWidget);

      // Tap on Free Call
      await tester.tap(find.text('Free Call'));
      await tester.pumpAndSettle();

      expect(find.text('Free Call Page'), findsOneWidget);
    });
  });
}
