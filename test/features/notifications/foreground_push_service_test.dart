import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:keep_sims/features/notifications/presentation/services/foreground_push_service.dart';
import 'package:keep_sims/features/notifications/presentation/services/notification_navigation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.keep_sims/notifications');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('foreground FCM confirmation displays once, preserving its quiet channel', () async {
    final service = ForegroundPushService();
    const message = RemoteMessage(
      messageId: 'fcm-1',
      data: {'notification_id': 'event-1', 'event_type': 'line_added'},
      notification: RemoteNotification(title: 'Line added', body: 'Saved',
        android: AndroidNotification(channelId: 'ks_confirmations_v1')),
    );
    await service.show(message);
    await service.show(message);
    final displays = calls.where((call) => call.method == 'showForeground');
    expect(displays.length, 1);
    expect(displays.single.arguments['channel_id'], 'ks_confirmations_v1');
    expect(displays.single.arguments['data']['notification_id'], 'event-1');
    service.dispose();
  });

  test('OneSignal payloads and data-only messages never get another renderer', () async {
    final service = ForegroundPushService();
    await service.show(const RemoteMessage(messageId: 'os-1', data: {'custom': '{}'},
        notification: RemoteNotification(title: 'OneSignal')));
    await service.show(const RemoteMessage(messageId: 'data-only'));
    expect(calls, isEmpty);
    service.dispose();
  });

  test('FCM JSON target preserves the destination after tapping', () {
    final payload = NotificationTapPayload.fromMap({
      'target': '{"route":"/wallet"}',
    });
    expect(NotificationNavigationService.resolveDestination(payload), '/wallet');
    expect(NotificationTapPayload.fromMap({'target': 'invalid json'}).target, isNull);
  });

  test('backlog cleanup marks removed OneSignal cards dismissed to prevent restoration', () async {
    const oneSignalChannel = MethodChannel('OneSignal#notifications');
    final removed = <int>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'trimBacklog') return [101, 102];
      return null;
    });
    messenger.setMockMethodCallHandler(oneSignalChannel, (call) async {
      if (call.method == 'OneSignal#removeNotification') {
        removed.add(call.arguments['notificationId'] as int);
      }
      return null;
    });
    final service = ForegroundPushService();
    await service.trimBacklog();
    expect(removed, [101, 102]);
    service.dispose();
    messenger.setMockMethodCallHandler(oneSignalChannel, null);
  });

  test('overflow clears restoration cache before displaying OneSignal exactly once', () async {
    const oneSignalChannel = MethodChannel('OneSignal#notifications');
    final events = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      events.add(call.method);
      return List.generate(25, (index) => index);
    });
    messenger.setMockMethodCallHandler(oneSignalChannel, (call) async {
      events.add(call.method);
      return null;
    });
    final service = ForegroundPushService();
    service.showOneSignal(OSNotificationWillDisplayEvent({
      'notification': {'notificationId': 'os-test', 'additionalData': {'event_type': 'line_added'}},
    }));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events, ['OneSignal#preventDefault', 'trimBacklog', 'OneSignal#clearAll', 'OneSignal#displayNotification']);
    service.dispose();
    messenger.setMockMethodCallHandler(oneSignalChannel, null);
  });
}
