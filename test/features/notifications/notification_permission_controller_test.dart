import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/notifications/data/services/notification_permission_service.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_permission_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer containerFor(_PermissionService service) {
    final container = ProviderContainer(
      overrides: [
        notificationPermissionServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('checking access never asks for permission or opens settings', () async {
    final service = _PermissionService();
    final container = containerFor(service);
    final access = await container.read(
      notificationPermissionControllerProvider.future,
    );
    expect(access.granted, isFalse);
    expect(service.requests, 0);
    expect(service.settingsOpened, 0);
  });

  test(
    'explicit enable reflects the permission granted by the device',
    () async {
      final service = _PermissionService()..grantOnRequest = true;
      final container = containerFor(service);
      await container.read(notificationPermissionControllerProvider.future);
      expect(
        await container
            .read(notificationPermissionControllerProvider.notifier)
            .enable(),
        isTrue,
      );
      expect(service.requests, 1);
      expect(
        container.read(notificationPermissionControllerProvider).value?.granted,
        isTrue,
      );
    },
  );

  test('denial remains off and does not open settings automatically', () async {
    final service = _PermissionService();
    final container = containerFor(service);
    await container.read(notificationPermissionControllerProvider.future);
    expect(
      await container
          .read(notificationPermissionControllerProvider.notifier)
          .enable(),
      isFalse,
    );
    expect(service.requests, 1);
    expect(service.settingsOpened, 0);
    expect(
      container.read(notificationPermissionControllerProvider).value?.granted,
      isFalse,
    );
  });

  test('blocked access opens settings only after an explicit action', () async {
    final service = _PermissionService()..canRequest = false;
    final container = containerFor(service);
    await container.read(notificationPermissionControllerProvider.future);
    expect(service.settingsOpened, 0);
    expect(
      await container
          .read(notificationPermissionControllerProvider.notifier)
          .enable(),
      isFalse,
    );
    expect(service.requests, 0);
    expect(service.settingsOpened, 1);
    service.granted = true;
    await container
        .read(notificationPermissionControllerProvider.notifier)
        .refresh();
    expect(
      container.read(notificationPermissionControllerProvider).value?.granted,
      isTrue,
    );
  });

  test(
    'already granted or unsupported access never triggers a prompt',
    () async {
      for (final supported in [false, true]) {
        final service = _PermissionService()
          ..supported = supported
          ..granted = supported;
        final container = containerFor(service);
        await container.read(notificationPermissionControllerProvider.future);
        expect(
          await container
              .read(notificationPermissionControllerProvider.notifier)
              .enable(),
          supported,
        );
        expect(service.requests, 0);
        expect(service.settingsOpened, 0);
      }
    },
  );

  test(
    'a failed settings launch keeps access off and can be retried',
    () async {
      final service = _PermissionService()
        ..canRequest = false
        ..settingsAvailable = false;
      final container = containerFor(service);
      await container.read(notificationPermissionControllerProvider.future);
      final controller = container.read(
        notificationPermissionControllerProvider.notifier,
      );
      await expectLater(controller.enable(), throwsStateError);
      expect(
        container.read(notificationPermissionControllerProvider).value?.granted,
        isFalse,
      );
      service.settingsAvailable = true;
      await controller.enable();
      expect(service.settingsOpened, 2);
    },
  );

  test('concurrent enable actions share one system request', () async {
    final pending = Completer<void>();
    final service = _PermissionService()
      ..pendingRequest = pending
      ..grantOnRequest = true;
    final container = containerFor(service);
    await container.read(notificationPermissionControllerProvider.future);
    final controller = container.read(
      notificationPermissionControllerProvider.notifier,
    );
    final first = controller.enable();
    final second = controller.enable();
    await Future<void>.delayed(Duration.zero);
    expect(service.requests, 1);
    pending.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
  });

  test(
    'platform service checks Android access and requests through OneSignal',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const permissions = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      const notifications = MethodChannel('OneSignal#notifications');
      final calls = <String>[];
      var granted = false;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(permissions, (call) async {
        calls.add(call.method);
        if (call.method == 'checkPermissionStatus') return granted ? 1 : 0;
        return true;
      });
      messenger.setMockMethodCallHandler(notifications, (call) async {
        calls.add(call.method);
        if (call.method == 'OneSignal#canRequest') return true;
        if (call.method == 'OneSignal#requestPermission') {
          expect(call.arguments, {'fallbackToSettings': false});
          granted = true;
          return true;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(permissions, null);
        messenger.setMockMethodCallHandler(notifications, null);
      });
      final service = PlatformNotificationPermissionService();
      expect((await service.status()).canRequest, isTrue);
      expect(calls, isNot(contains('OneSignal#requestPermission')));
      await service.request();
      expect((await service.status()).granted, isTrue);
      expect(await service.openSettings(), isTrue);
    },
  );

  test(
    'platform service recognizes iOS permission and provisional access',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('OneSignal#notifications');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var nativePermission = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'OneSignal#permissionNative') {
          return nativePermission;
        }
        if (call.method == 'OneSignal#canRequest') return nativePermission == 0;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final service = PlatformNotificationPermissionService();
      expect((await service.status()).canRequest, isTrue);
      nativePermission = 1;
      expect((await service.status()).canRequest, isFalse);
      for (final allowed in [2, 3, 4]) {
        nativePermission = allowed;
        expect((await service.status()).granted, isTrue);
      }
    },
  );
}

class _PermissionService implements NotificationPermissionService {
  bool supported = true;
  bool granted = false;
  bool canRequest = true;
  bool grantOnRequest = false;
  bool settingsAvailable = true;
  int requests = 0;
  int settingsOpened = 0;
  Completer<void>? pendingRequest;

  @override
  Future<NotificationPermissionAccess> status() async =>
      NotificationPermissionAccess(
        supported: supported,
        granted: granted,
        canRequest: canRequest,
      );

  @override
  Future<void> request() async {
    requests++;
    await pendingRequest?.future;
    granted = grantOnRequest;
    canRequest = false;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return settingsAvailable;
  }
}
