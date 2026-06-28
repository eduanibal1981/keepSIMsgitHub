import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/notifications/data/models/notification_model.dart';
import 'package:keep_sims/features/notifications/data/repositories/notifications_repository_impl.dart';

part 'notifications_controller.g.dart';

@riverpod
class NotificationsController extends _$NotificationsController {
  @override
  FutureOr<List<AppNotification>> build() async {
    final authState = ref.watch(authControllerProvider);
    if (authState.value == null) {
      return const [];
    }
    final repo = ref.watch(notificationsRepositoryProvider);
    return repo.getNotifications();
  }

  /// Refreshes/reloads notifications from Supabase.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(notificationsRepositoryProvider);
      return repo.getNotifications();
    });
  }

  /// Marks a specific notification as read.
  Future<void> markAsRead(String id) async {
    final repo = ref.read(notificationsRepositoryProvider);

    // Snappy optimistic UI update
    state = state.whenData((list) {
      return list.map((item) {
        if (item.id == id) {
          return item.copyWith(isRead: true);
        }
        return item;
      }).toList();
    });

    try {
      await repo.markAsRead(id);
    } catch (_) {
      // Revert or refresh on failure
      await refresh();
    }
  }

  /// Marks all notifications as read.
  Future<void> markAllAsRead() async {
    final repo = ref.read(notificationsRepositoryProvider);

    // Snappy optimistic UI update
    state = state.whenData((list) {
      return list.map((item) => item.copyWith(isRead: true)).toList();
    });

    try {
      await repo.markAllAsRead();
    } catch (_) {
      await refresh();
    }
  }

  /// Deletes a specific notification.
  Future<void> deleteNotification(String id) async {
    final repo = ref.read(notificationsRepositoryProvider);

    // Snappy optimistic UI update
    state = state.whenData((list) {
      return list.where((item) => item.id != id).toList();
    });

    try {
      await repo.deleteNotification(id);
    } catch (_) {
      await refresh();
    }
  }

  /// Clears all notifications for the active user.
  Future<void> clearAll() async {
    final repo = ref.read(notificationsRepositoryProvider);

    // Snappy optimistic UI update
    state = const AsyncData([]);

    try {
      await repo.clearAllNotifications();
    } catch (_) {
      await refresh();
    }
  }

  /// Triggers a simulated mock notification insertion.
  Future<void> simulateMockNotification({
    required String category,
    required String title,
    required String body,
    String? simLineId,
    int delayMinutes = 0,
  }) async {
    final repo = ref.read(notificationsRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repo.simulateNotification(
        category,
        title,
        body,
        simLineId: simLineId,
        delayMinutes: delayMinutes,
      );
      return repo.getNotifications();
    });
  }
}

/// Helper provider to get unread notification count.
@riverpod
int unreadNotificationsCount(Ref ref) {
  final listAsync = ref.watch(notificationsControllerProvider);
  return listAsync.maybeWhen(
    data: (list) => list.where((item) => !item.isRead).length,
    orElse: () => 0,
  );
}
