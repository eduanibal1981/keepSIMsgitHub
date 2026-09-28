import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/features/wallet/model/wallet_model.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart';

void main() {
  const paidLine = SimLine(
    id: 'line-paid-1',
    userId: 'user-1',
    phoneNumber: '+201098971020',
    planType: 'standard',
    protectionTier: 'standard',
  );

  const freeLine = SimLine(
    id: 'line-free-1',
    userId: 'user-1',
    phoneNumber: '+201011223344',
    planType: 'free',
    protectionTier: 'basic',
  );

  final testChannels = [
    {
      'id': 'ch-1',
      'channel_type': 'push',
      'is_enabled': true,
      'config': <String, dynamic>{},
    },
    {
      'id': 'ch-2',
      'channel_type': 'email',
      'is_enabled': true,
      'config': <String, dynamic>{'email': ''},
    },
    {
      'id': 'ch-3',
      'channel_type': 'whatsapp',
      'is_enabled': true,
      'config': <String, dynamic>{'phone': '+96879761061'},
    },
    {
      'id': 'ch-4',
      'channel_type': 'telegram',
      'is_enabled': true,
      'config': <String, dynamic>{},
    },
  ];

  final testCatalog = <String, Map<String, dynamic>>{
    'push': {
      'channel_key': 'push',
      'is_globally_enabled': true,
      'min_tier': 'basic',
    },
    'email': {
      'channel_key': 'email',
      'is_globally_enabled': true,
      'min_tier': 'standard',
    },
    'whatsapp': {
      'channel_key': 'whatsapp',
      'is_globally_enabled': false, // Globally paused!
      'min_tier': 'premium',
    },
    'telegram': {
      'channel_key': 'telegram',
      'is_globally_enabled': true,
      'min_tier': 'basic', // Telegram is now basic!
    },
  };

  testWidgets('ScheduledTopupSheet accurately displays channel readiness badges on paid line',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationChannelsControllerProvider
              .overrideWith(() => _MockNotificationChannelsController(testChannels)),
          notificationChannelCatalogProvider
              .overrideWith((ref) => Future.value(testCatalog)),
          simLinesControllerProvider
              .overrideWith(() => _MockSimLinesController([paidLine])),
          walletControllerProvider.overrideWith(() => _MockWalletController()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ScheduledTopupSheet(
              simLineId: 'line-paid-1',
              simNickname: 'Paid Line',
              simLine: paidLine,
              configMode: 'notify',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Push Notifications should be ACTIVE
    expect(find.text('Push Notifications'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    // 2. Email Alerts has empty email -> NOT SET
    expect(find.text('Email Alerts'), findsOneWidget);
    expect(find.text('NOT SET'), findsOneWidget);
    expect(find.text('No email configured · Tap to setup'), findsOneWidget);

    // 3. WhatsApp Alerts is globally disabled -> PAUSED
    expect(find.text('WhatsApp Alerts'), findsOneWidget);
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('Temporarily paused across platform'), findsOneWidget);

    // 4. Telegram Bot has empty chat_id -> UNBOUND
    expect(find.text('Telegram Bot'), findsOneWidget);
    expect(find.text('UNBOUND'), findsOneWidget);
    expect(find.text('Telegram bot unbound · Tap to link'), findsOneWidget);
  });

  testWidgets('ScheduledTopupSheet allows Telegram on Free plan line without Upgrade badge',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationChannelsControllerProvider
              .overrideWith(() => _MockNotificationChannelsController(testChannels)),
          notificationChannelCatalogProvider
              .overrideWith((ref) => Future.value(testCatalog)),
          simLinesControllerProvider
              .overrideWith(() => _MockSimLinesController([freeLine])),
          walletControllerProvider.overrideWith(() => _MockWalletController()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ScheduledTopupSheet(
              simLineId: 'line-free-1',
              simNickname: 'Free Line',
              simLine: freeLine,
              configMode: 'notify',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Push is free & ACTIVE
    expect(find.text('Push Notifications'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    // Telegram is free & UNBOUND (not locked to Upgrade!)
    expect(find.text('Telegram Bot'), findsOneWidget);
    expect(find.text('UNBOUND'), findsOneWidget);
    expect(find.text('Telegram bot unbound · Tap to link'), findsOneWidget);

    // Email and WhatsApp are paid features -> show 'Upgrade'
    expect(find.text('Email Alerts'), findsOneWidget);
    expect(find.text('WhatsApp Alerts'), findsOneWidget);
    expect(find.text('Upgrade'), findsNWidgets(2));
  });
}

class _MockNotificationChannelsController
    extends NotificationChannelsController {
  final List<Map<String, dynamic>> channels;
  _MockNotificationChannelsController(this.channels);

  @override
  FutureOr<List<Map<String, dynamic>>> build() => channels;
}

class _MockSimLinesController extends SimLinesController {
  final List<SimLine> lines;
  _MockSimLinesController(this.lines);

  @override
  FutureOr<List<SimLine>> build() => lines;
}

class _MockWalletController extends WalletController {
  @override
  FutureOr<WalletState> build() {
    return const WalletState(
      wallet: Wallet(
        id: 'w-1',
        userId: 'user-1',
        balance: 20.0,
        currency: 'USD',
      ),
      transactions: [],
    );
  }
}
