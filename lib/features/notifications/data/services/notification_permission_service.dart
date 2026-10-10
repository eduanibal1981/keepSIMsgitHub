import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationPermissionAccess {
  const NotificationPermissionAccess({
    required this.supported,
    this.granted = false,
    this.canRequest = false,
  });

  final bool supported;
  final bool granted;
  final bool canRequest;
}

abstract interface class NotificationPermissionService {
  Future<NotificationPermissionAccess> status();
  Future<void> request();
  Future<bool> openSettings();
}

class PlatformNotificationPermissionService
    implements NotificationPermissionService {
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<NotificationPermissionAccess> status() async {
    if (!_supported) {
      return const NotificationPermissionAccess(supported: false);
    }
    final bool granted;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final permission = await OneSignal.Notifications.permissionNative();
      granted =
          permission == OSNotificationPermission.authorized ||
          permission == OSNotificationPermission.provisional ||
          permission == OSNotificationPermission.ephemeral;
    } else {
      granted = (await Permission.notification.status).isGranted;
    }
    return NotificationPermissionAccess(
      supported: true,
      granted: granted,
      canRequest: !granted && await OneSignal.Notifications.canRequest(),
    );
  }

  @override
  Future<void> request() async {
    if (_supported) {
      await OneSignal.Notifications.requestPermission(false);
    }
  }

  @override
  Future<bool> openSettings() async => _supported && await openAppSettings();
}
