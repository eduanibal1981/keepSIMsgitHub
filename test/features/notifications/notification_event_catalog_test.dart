import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/notifications/domain/notification_event_catalog.dart';

void main() {
  group('NotificationEventCatalog - Line Identity Masking', () {
    test('formats with nickname and last 4 digits', () {
      final line = NotificationEventCatalog.formatLineIdentity(
        nickname: 'My Travel SIM',
        rawPhoneNumber: '+968 9123 4567',
        language: 'en',
      );
      expect(line, 'My Travel SIM · 4567');
    });

    test('falls back to "Line ending {last4}" in English when nickname is null or empty', () {
      final line1 = NotificationEventCatalog.formatLineIdentity(
        nickname: null,
        rawPhoneNumber: '+1 (555) 234-5678',
        language: 'en',
      );
      expect(line1, 'Line ending 5678');

      final line2 = NotificationEventCatalog.formatLineIdentity(
        nickname: '   ',
        rawPhoneNumber: '+1 (555) 234-5678',
        language: 'en',
      );
      expect(line2, 'Line ending 5678');
    });

    test('falls back to Arabic line ending when language is Arabic', () {
      final line = NotificationEventCatalog.formatLineIdentity(
        nickname: null,
        rawPhoneNumber: '96891234567',
        language: 'ar',
      );
      expect(line, 'المنتهي بـ 4567');
    });

    test('truncates long nicknames gracefully without breaking code points', () {
      final line = NotificationEventCatalog.formatLineIdentity(
        nickname: 'This is an extremely long nickname for my line',
        rawPhoneNumber: '1234567890',
        language: 'en',
      );
      expect(line.startsWith('This is an extremely lon · 7890'), isTrue);
    });
  });

  group('NotificationEventCatalog - Event Templates & Rendering', () {
    final testDate = DateTime.utc(2026, 10, 15, 12, 0);

    test('renders line_added in EN and AR with quiet priority and confirmations channel', () {
      final en = NotificationEventCatalog.render(
        eventType: NotificationEventType.lineAdded,
        data: {
          'nickname': 'Personal',
          'phone_number': '+96891234567',
          'date': testDate,
        },
        language: 'en',
      );

      expect(en.title, '✅ Number added');
      expect(en.body, contains('Personal · 4567. Next recharge reminder:'));
      expect(en.channelId, NotificationChannels.confirmations);
      expect(en.priority, NotificationPriority.quiet);
      expect(en.largeIcon, NotificationEventCatalog.iconSuccess);

      final ar = NotificationEventCatalog.render(
        eventType: NotificationEventType.lineAdded,
        data: {
          'nickname': 'شخصي',
          'phone_number': '+96891234567',
          'date': testDate,
        },
        language: 'ar',
      );

      expect(ar.title, '✅ تمت إضافة الرقم');
      expect(ar.body, contains('الرقم شخصي · 4567. تذكير الشحن القادم:'));
      expect(ar.channelId, NotificationChannels.confirmations);
      expect(ar.priority, NotificationPriority.quiet);
    });

    test('renders auto_recharge_scheduled with quiet priority', () {
      final rendered = NotificationEventCatalog.render(
        eventType: NotificationEventType.autoRechargeScheduled,
        data: {
          'phone_number': '1234567890',
          'date': testDate,
        },
        language: 'en',
      );

      expect(rendered.title, '✅ Auto-recharge scheduled');
      expect(rendered.body, contains('Line ending 7890. Next automatic recharge:'));
      expect(rendered.channelId, NotificationChannels.confirmations);
      expect(rendered.priority, NotificationPriority.quiet);
    });

    test('renders line_setup_incomplete with warning icon and updates channel', () {
      final rendered = NotificationEventCatalog.render(
        eventType: NotificationEventType.lineSetupIncomplete,
        data: {
          'nickname': 'Work',
          'phone_number': '99887766',
        },
        language: 'en',
      );

      expect(rendered.title, '⚠️ Finish setting up your number');
      expect(rendered.body, 'Work · 7766 was added. Open KeepSIMs to finish setting up reminders.');
      expect(rendered.channelId, NotificationChannels.updates);
      expect(rendered.priority, NotificationPriority.normal);
      expect(rendered.largeIcon, NotificationEventCatalog.iconWarning);
    });

    test('renders recharge_date_missing as a normal setup reminder', () {
      final rendered = NotificationEventCatalog.render(
        eventType: NotificationEventType.rechargeDateMissing,
        data: {
          'nickname': 'Work',
          'phone_number': '99887766',
        },
        language: 'en',
      );

      expect(rendered.title, '⚠️ Add your last recharge date');
      expect(rendered.body, contains('Work · 7766'));
      expect(rendered.channelId, NotificationChannels.updates);
      expect(rendered.priority, NotificationPriority.normal);
      expect(rendered.largeIcon, NotificationEventCatalog.iconWarning);
    });

    test('renders recharge_succeeded with amount and currency', () {
      final rendered = NotificationEventCatalog.render(
        eventType: NotificationEventType.rechargeSucceeded,
        data: {
          'nickname': 'Travel',
          'phone_number': '123456',
          'amount': '15.00',
          'currency': 'USD',
        },
        language: 'en',
      );

      expect(rendered.title, '✅ Recharge successful');
      expect(rendered.body, 'Travel · 3456 was recharged with 15.00 USD.');
      expect(rendered.channelId, NotificationChannels.updates);
      expect(rendered.priority, NotificationPriority.normal);
    });

    test('renders recharge_due_today with urgent priority and urgent channel', () {
      final rendered = NotificationEventCatalog.render(
        eventType: NotificationEventType.rechargeDueToday,
        data: {
          'phone_number': '5551234',
        },
        language: 'en',
      );

      expect(rendered.title, '⚠️ Recharge due today');
      expect(rendered.channelId, NotificationChannels.urgent);
      expect(rendered.priority, NotificationPriority.urgent);
      expect(rendered.largeIcon, NotificationEventCatalog.iconWarning);
    });

    test('renders recharge_failed with error icon and urgent priority', () {
      final rendered = NotificationEventCatalog.render(
        eventType: NotificationEventType.rechargeFailed,
        data: {
          'nickname': 'Main',
          'phone_number': '9876543210',
        },
        language: 'en',
      );

      expect(rendered.title, '❌ Recharge failed');
      expect(rendered.channelId, NotificationChannels.urgent);
      expect(rendered.priority, NotificationPriority.urgent);
      expect(rendered.largeIcon, NotificationEventCatalog.iconError);
    });

    test('category resolution maps properly to existing categories', () {
      expect(NotificationEventCatalog.resolveCategory(NotificationEventType.lineAdded), 'system');
      expect(NotificationEventCatalog.resolveCategory(NotificationEventType.autoRechargeScheduled), 'system');
      expect(NotificationEventCatalog.resolveCategory(NotificationEventType.lineSetupIncomplete), 'system');
      expect(NotificationEventCatalog.resolveCategory(NotificationEventType.rechargeDateMissing), 'system');
      expect(NotificationEventCatalog.resolveCategory(NotificationEventType.rechargeSucceeded), 'top_up_success');
      expect(NotificationEventCatalog.resolveCategory(NotificationEventType.rechargeReminder), 'top_up_reminder');
      expect(NotificationEventCatalog.resolveCategory(NotificationEventType.rechargeDueToday), 'top_up_reminder');
      expect(NotificationEventCatalog.resolveCategory(NotificationEventType.rechargeFailed), 'top_up_failed');
      expect(NotificationEventCatalog.resolveCategory(NotificationEventType.walletLow), 'wallet_low');
      expect(NotificationEventCatalog.resolveCategory(NotificationEventType.rechargeBlockedFunds), 'wallet_depleted');
      expect(NotificationEventCatalog.resolveCategory(NotificationEventType.lineCritical), 'line_critical');
    });
  });
}
