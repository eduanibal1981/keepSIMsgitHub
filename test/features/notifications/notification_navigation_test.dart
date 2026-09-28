import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/notifications/presentation/services/notification_navigation_service.dart';

void main() {
  group('NotificationNavigationService - resolveDestination', () {
    test('routes directly to sim-lines detail when simLineId is present', () {
      final payload = NotificationTapPayload(
        simLineId: 'line-abc-123',
      );
      expect(
        NotificationNavigationService.resolveDestination(payload),
        '/sim-lines/detail/line-abc-123',
      );
    });

    test('translates legacy /sim_lines/:id actionUrl to /sim-lines/detail/:id', () {
      final payload = NotificationTapPayload(
        actionUrl: '/sim_lines/legacy-uuid-456',
      );
      expect(
        NotificationNavigationService.resolveDestination(payload),
        '/sim-lines/detail/legacy-uuid-456',
      );
    });

    test('preserves canonical /sim-lines/detail/:id in actionUrl', () {
      final payload = NotificationTapPayload(
        actionUrl: '/sim-lines/detail/canonical-id-789',
      );
      expect(
        NotificationNavigationService.resolveDestination(payload),
        '/sim-lines/detail/canonical-id-789',
      );
    });

    test('interpolates structured target route with id', () {
      final payload = NotificationTapPayload(
        target: {
          'route': '/sim-lines/detail/:id',
          'id': 'structured-line-001',
        },
      );
      expect(
        NotificationNavigationService.resolveDestination(payload),
        '/sim-lines/detail/structured-line-001',
      );
    });

    test('routes to allowlisted core app routes', () {
      expect(
        NotificationNavigationService.resolveDestination(
          NotificationTapPayload(actionUrl: '/wallet'),
        ),
        '/wallet',
      );

      expect(
        NotificationNavigationService.resolveDestination(
          NotificationTapPayload(actionUrl: '/notifications'),
        ),
        '/notifications',
      );

      expect(
        NotificationNavigationService.resolveDestination(
          NotificationTapPayload(actionUrl: '/settings'),
        ),
        '/settings',
      );
    });

    test('safely falls back to /notifications for malicious, foreign, or unallowlisted URLs', () {
      final foreignPayload = NotificationTapPayload(
        actionUrl: 'https://malicious-phishing.com/steal-creds',
      );
      expect(
        NotificationNavigationService.resolveDestination(foreignPayload),
        '/notifications',
      );

      final javascriptPayload = NotificationTapPayload(
        actionUrl: 'javascript:alert(1)',
      );
      expect(
        NotificationNavigationService.resolveDestination(javascriptPayload),
        '/notifications',
      );

      final emptyPayload = NotificationTapPayload();
      expect(
        NotificationNavigationService.resolveDestination(emptyPayload),
        '/notifications',
      );
    });
  });
}
