import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_alert_target_screen.dart';
import 'package:keep_sims/features/notifications/domain/notification_event_catalog.dart';
import 'package:keep_sims/features/notifications/presentation/services/notification_navigation_service.dart';

class _Auth extends AuthController {
  @override
  FutureOr<UserProfile?> build() => const UserProfile(id: 'owner');
}

class _Profiles extends UserEsimsController {
  @override
  FutureOr<List<UserEsim>> build() => [
    UserEsim.fromRecord({
      'id': 'other-profile',
      'user_id': 'other',
      'order_id': 'order',
      'bundle_name': 'Private profile',
      'provider': 'esimaccess',
      'status': 'active',
      'iccid': '8900000000000000001',
      'lpa_string': 'LPA:1\$fixture.invalid\$private',
      'issuance_verified': true,
    }),
  ];
}

void main() {
  test(
    'every eSIM event is recognized and renders without recharge promises or identifiers',
    () {
      for (final event in NotificationEventType.values.where(
        (e) => e.wireName.startsWith('esim_'),
      )) {
        expect(NotificationEventType.fromWireName(event.wireName), event);
        final rendered = NotificationEventCatalog.render(
          eventType: event,
          data: {'iccid': 'private-iccid'},
        );
        expect(rendered.body, contains('KeepSIMs'));
        expect(rendered.body, isNot(contains('private-iccid')));
        expect(rendered.body, isNot(contains('Recharge now')));
        expect(rendered.channelId, NotificationChannels.updates);
        expect(
          NotificationEventCatalog.resolveCategory(event),
          event == NotificationEventType.esimLowData
              ? 'esim_low_data'
              : 'esim_updates',
        );
      }
    },
  );
  test('profile and order targets resolve only allowlisted ID paths', () {
    for (final kind in ['profiles', 'orders']) {
      expect(
        NotificationNavigationService.resolveDestination(
          NotificationTapPayload(
            target: {'route': '/esim/$kind/:id', 'id': 'fixture-id'},
          ),
        ),
        '/esim/$kind/fixture-id',
      );
      for (final id in [
        '../wallet',
        'id?owner=other',
        'https://evil.invalid',
        'id/other',
      ]) {
        expect(
          NotificationNavigationService.resolveDestination(
            NotificationTapPayload(
              target: {'route': '/esim/$kind/:id', 'id': id},
            ),
          ),
          '/notifications',
        );
      }
    }
    expect(
      NotificationNavigationService.resolveDestination(
        NotificationTapPayload(
          target: {'route': 'https://evil.invalid/:id', 'id': 'fixture'},
        ),
      ),
      '/notifications',
    );
  });
  testWidgets(
    'a cached profile from another account never reveals installation details',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_Auth.new),
            userEsimsControllerProvider.overrideWith(_Profiles.new),
          ],
          child: const MaterialApp(
            home: EsimAlertTargetScreen(id: 'other-profile'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('This eSIM is unavailable for this account.'),
        findsOneWidget,
      );
      expect(find.text('Private profile'), findsNothing);
      expect(find.text('Installation details'), findsNothing);
    },
  );
}
