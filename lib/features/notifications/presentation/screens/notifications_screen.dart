import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/notifications/data/models/notification_model.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:keep_sims/core/widgets/shimmer_loading.dart';
import 'package:keep_sims/core/widgets/empty_state.dart';
import 'package:keep_sims/core/widgets/error_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/notifications/domain/notification_event_catalog.dart';
import 'package:keep_sims/features/notifications/presentation/services/notification_navigation_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  // Tab Controller
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticHelper.lightTick();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsControllerProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Alerts',
              style: AppTextStyles.headlineLarge.copyWith(
                color: context.onSurfaceColor,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$unreadCount new',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Settings button
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            tooltip: 'Alert Preferences',
            onPressed: () async {
              await HapticHelper.lightTick();
              context.push('/notifications/settings');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFEAEEF1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (isDark ? AppColors.primary : AppColors.lightPrimary)
                      .withValues(alpha: 0.3),
                ),
              ),
              labelColor: context.onSurfaceColor,
              unselectedLabelColor: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
              labelStyle: AppTextStyles.titleMedium,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Unread'),
              ],
            ),
          ),

          // Notification feed lists
          Expanded(
            child: notificationsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return _buildEmptyState();
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNotificationList(context, list),
                    _buildNotificationList(
                      context,
                      list.where((n) => !n.isRead).toList(),
                    ),
                  ],
                );
              },
              loading: () => const NotificationsShimmer(),
              error: (err, _) => ErrorStateView(
                errorMessage: err.toString(),
                onRetry: () async {
                  await HapticHelper.mediumImpact();
                  ref.read(notificationsControllerProvider.notifier).refresh();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyStateView(
      icon: Icons.notifications_none_rounded,
      title: 'No notifications yet',
      description:
          'We will alert you when renewal tasks, wallet changes, or grace period warnings occur.',
    );
  }

  Widget _buildNotificationList(
    BuildContext context,
    List<AppNotification> list,
  ) {
    final isDark = context.isDarkMode;
    if (list.isEmpty) {
      return const EmptyStateView(
        icon: Icons.done_all_rounded,
        title: 'All caught up!',
        description: 'You have no unread notifications.',
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: list.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await HapticHelper.mediumImpact();
                    _confirmClearAll(context);
                  },
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.healthRed,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await HapticHelper.successFeedback();
                    ref
                        .read(notificationsControllerProvider.notifier)
                        .markAllAsRead();
                  },
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Mark All Read'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.primaryLight
                        : AppColors.lightPrimaryMid,
                  ),
                ),
              ],
            ),
          );
        }

        final item = list[index - 1];
        return _buildNotificationCard(context, item);
      },
    );
  }

  Widget _buildNotificationCard(BuildContext context, AppNotification item) {
    final isDark = context.isDarkMode;
    Color indicatorColor = AppColors.primary;
    IconData icon = Icons.notifications_rounded;

    final typedEvent = NotificationEventType.fromWireName(item.eventType);
    if (typedEvent != null) {
      switch (typedEvent) {
        case NotificationEventType.lineAdded:
        case NotificationEventType.autoRechargeScheduled:
        case NotificationEventType.rechargeSucceeded:
          indicatorColor = AppColors.success;
          icon = Icons.check_circle_rounded;
          break;
        case NotificationEventType.rechargeReminder:
          indicatorColor = AppColors.info;
          icon = Icons.notifications_active_rounded;
          break;
        case NotificationEventType.rechargeDueToday:
        case NotificationEventType.lineSetupIncomplete:
        case NotificationEventType.rechargeDateMissing:
        case NotificationEventType.walletLow:
          indicatorColor = AppColors.warning;
          icon = Icons.warning_amber_rounded;
          break;
        case NotificationEventType.rechargeFailed:
        case NotificationEventType.rechargeBlockedFunds:
        case NotificationEventType.lineCritical:
          indicatorColor = AppColors.healthRed;
          icon = Icons.error_outline_rounded;
          break;
      }
    } else {
      switch (item.category) {
        case 'top_up_success':
          indicatorColor = AppColors.success;
          icon = Icons.check_circle_rounded;
          break;
        case 'top_up_failed':
        case 'wallet_depleted':
        case 'line_critical':
          indicatorColor = AppColors.healthRed;
          icon = Icons.error_outline_rounded;
          break;
        case 'wallet_low':
        case 'line_entering_grace':
          indicatorColor = AppColors.warning;
          icon = Icons.warning_amber_rounded;
          break;
        case 'geo_fence_triggered':
        case 'welcome_home_ready':
          indicatorColor = AppColors.info;
          icon = Icons.explore_rounded;
          break;
        case 'referral_reward':
          indicatorColor = const Color(0xFFEC4899);
          icon = Icons.card_giftcard_rounded;
          break;
        case 'system':
        default:
          indicatorColor = AppColors.primary;
          icon = Icons.settings_suggest_rounded;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          decoration: BoxDecoration(
            color: AppColors.healthRed.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.delete_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        onDismissed: (_) async {
          await HapticHelper.mediumImpact();
          ref
              .read(notificationsControllerProvider.notifier)
              .deleteNotification(item.id);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isRead
                  ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                  : indicatorColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await HapticHelper.lightTick();
              ref
                  .read(notificationsControllerProvider.notifier)
                  .markAsRead(item.id);
              final payload = NotificationTapPayload(
                notificationId: item.id,
                simLineId: item.simLineId,
                actionUrl: item.actionUrl,
                eventType: item.eventType,
                target: item.target,
              );
              final destination =
                  NotificationNavigationService.resolveDestination(payload);
              if (destination != '/notifications' && context.mounted) {
                context.push(destination);
              }
            },
            child: Stack(
              children: [
                // Left glowing indicator bar
                Positioned(
                  left: 0,
                  top: 16,
                  bottom: 16,
                  width: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: indicatorColor.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category icon frame
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: indicatorColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: indicatorColor, size: 22),
                      ),
                      const SizedBox(width: 14),

                      // Title & Body
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: AppTextStyles.titleMedium.copyWith(
                                      color: item.isRead
                                          ? (isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight)
                                          : context.onSurfaceColor,
                                      fontWeight: item.isRead
                                          ? FontWeight.w500
                                          : FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTimeAgo(item.createdAt),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isDark
                                        ? AppColors.textTertiaryDark
                                        : AppColors.textTertiaryLight,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.body,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: item.isRead
                                    ? (isDark
                                          ? AppColors.textTertiaryDark
                                          : AppColors.textTertiaryLight)
                                    : (isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Unread Blue dot
                if (!item.isRead)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primaryLight
                            : AppColors.lightPrimaryMid,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? AppColors.primary
                                : AppColors.lightPrimary,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return '';
    final difference = DateTime.now().difference(time);
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _confirmClearAll(BuildContext context) {
    final isDark = context.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: Text(
          'Clear all alerts?',
          style: AppTextStyles.titleLarge.copyWith(
            color: context.onSurfaceColor,
          ),
        ),
        content: Text(
          'This will permanently delete all notifications from your account timeline history.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
            onPressed: () async {
              await HapticHelper.lightTick();
              Navigator.pop(ctx);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.healthRed
                  : const Color(0xFFBA1A1A),
            ),
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () async {
              await HapticHelper.mediumImpact();
              ref.read(notificationsControllerProvider.notifier).clearAll();
              Navigator.pop(ctx);
              await HapticHelper.successFeedback();
            },
          ),
        ],
      ),
    );
  }
}
