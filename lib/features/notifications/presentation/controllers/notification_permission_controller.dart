import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/notifications/data/services/notification_permission_service.dart';

final notificationPermissionServiceProvider =
    Provider<NotificationPermissionService>(
      (ref) => PlatformNotificationPermissionService(),
    );

final notificationPermissionControllerProvider =
    AsyncNotifierProvider<
      NotificationPermissionController,
      NotificationPermissionAccess
    >(NotificationPermissionController.new);

class NotificationPermissionController
    extends AsyncNotifier<NotificationPermissionAccess> {
  Future<bool>? _pendingEnable;

  @override
  Future<NotificationPermissionAccess> build() =>
      ref.watch(notificationPermissionServiceProvider).status();

  Future<bool> refresh() async {
    try {
      final access = await ref
          .read(notificationPermissionServiceProvider)
          .status();
      if (ref.mounted) state = AsyncData(access);
      return access.granted;
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> enable() =>
      _pendingEnable ??= _enable().whenComplete(() => _pendingEnable = null);

  Future<bool> _enable() async {
    final service = ref.read(notificationPermissionServiceProvider);
    final access = await service.status();
    if (!ref.mounted) return false;
    if (!access.supported || access.granted) {
      state = AsyncData(access);
      return access.granted;
    }
    if (access.canRequest) {
      await service.request();
    } else if (!await service.openSettings()) {
      throw StateError('Could not open notification settings.');
    }
    if (!ref.mounted) return false;
    return refresh();
  }

  Future<void> openSettings() async {
    if (!await ref.read(notificationPermissionServiceProvider).openSettings()) {
      throw StateError('Could not open notification settings.');
    }
    if (ref.mounted) await refresh();
  }
}
