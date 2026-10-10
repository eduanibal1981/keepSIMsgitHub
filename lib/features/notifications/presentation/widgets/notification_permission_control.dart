import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_permission_controller.dart';

class NotificationPermissionControl extends ConsumerStatefulWidget {
  const NotificationPermissionControl({super.key});

  @override
  ConsumerState<NotificationPermissionControl> createState() =>
      _NotificationPermissionControlState();
}

class _NotificationPermissionControlState
    extends ConsumerState<NotificationPermissionControl>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) {
      _refreshAccess();
    }
  }

  Future<void> _refreshAccess() async {
    try {
      await ref
          .read(notificationPermissionControllerProvider.notifier)
          .refresh();
    } catch (_) {
      // The provider exposes a retry state if the device cannot be checked.
    }
  }

  Future<void> _change({bool settings = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(
        notificationPermissionControllerProvider.notifier,
      );
      if (settings) {
        await controller.openSettings();
      } else {
        await controller.enable();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not update access. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(notificationPermissionControllerProvider);
    final success = context.isDarkMode
        ? AppColors.secondary
        : AppColors.lightSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.notifications_outlined,
              color: context.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      color: context.onSurfaceColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SIM reminders, refill updates, and incoming call alerts.',
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        permission.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              const Text('Could not check notification access.'),
              TextButton.icon(
                onPressed: () =>
                    ref.invalidate(notificationPermissionControllerProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
          data: (access) => Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    access.granted
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: access.granted
                        ? success
                        : context.colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    !access.supported
                        ? 'Unavailable'
                        : access.granted
                        ? 'Allowed'
                        : 'Not enabled',
                    key: const ValueKey('notification-permission-status'),
                    style: TextStyle(
                      color: access.granted
                          ? success
                          : context.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (access.supported)
                OutlinedButton.icon(
                  key: const ValueKey('notification-permission-action'),
                  onPressed: _busy
                      ? null
                      : () => _change(settings: access.granted),
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          access.granted || !access.canRequest
                              ? Icons.settings_outlined
                              : Icons.notifications_active_outlined,
                          size: 18,
                        ),
                  label: Text(
                    access.granted || !access.canRequest
                        ? 'Open settings'
                        : 'Enable',
                  ),
                ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: context.colorScheme.error, fontSize: 13),
            ),
          ),
      ],
    );
  }
}
