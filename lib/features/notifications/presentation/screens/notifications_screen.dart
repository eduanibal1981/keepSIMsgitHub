import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/notifications/data/models/notification_model.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/core/widgets/shimmer_loading.dart';
import 'package:keep_sims/core/widgets/empty_state.dart';
import 'package:keep_sims/core/widgets/error_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/whatsapp_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isSimulatorExpanded = false;

  // Simulator State variables
  String _selectedCategory = 'top_up_success';
  String? _selectedSimLineId;
  int _selectedDelayMinutes = 0;
  bool _sendLocalWhatsApp = false;
  late final TextEditingController _whatsappPhoneController;

  final Map<String, String> _simulatorCategories = {
    'top_up_success': 'Top-up Successful',
    'top_up_failed': 'Top-up Failed (Critical)',
    'wallet_low': 'Low Wallet Warning',
    'wallet_depleted': 'Wallet Depleted',
    'line_critical': 'SIM Grace Warning (Critical)',
    'line_entering_grace': 'Entering Grace Period',
    'referral_reward': 'Referral Reward Received',
    'system': 'General System Update',
  };

  @override
  void initState() {
    super.initState();
    _whatsappPhoneController = TextEditingController(text: '96891234567');
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticHelper.lightTick();
      }
    });
  }

  @override
  void dispose() {
    _whatsappPhoneController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsControllerProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Alerts',
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.textPrimaryDark,
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
          // Expand Simulator Button
          IconButton(
            icon: Icon(
              _isSimulatorExpanded
                  ? Icons.terminal_rounded
                  : Icons.terminal_outlined,
              color: _isSimulatorExpanded
                  ? AppColors.secondary
                  : AppColors.textSecondaryDark,
            ),
            tooltip: 'Toggle Alert Simulator',
            onPressed: () async {
              await HapticHelper.lightTick();
              setState(() {
                _isSimulatorExpanded = !_isSimulatorExpanded;
              });
            },
          ),
          // Settings button
          IconButton(
            icon: const Icon(
              Icons.tune_rounded,
              color: AppColors.textSecondaryDark,
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
          // Live Alert Simulator Dashboard
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildSimulatorDashboard(context),
            crossFadeState: _isSimulatorExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),

          // Tab Bar selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              labelColor: AppColors.textPrimaryDark,
              unselectedLabelColor: AppColors.textTertiaryDark,
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

  Widget _buildSimulatorDashboard(BuildContext context) {
    final simLinesAsync = ref.watch(simLinesControllerProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.terminal_rounded,
                color: AppColors.secondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Live Incident Simulator',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dropdown for categories
          Text(
            'Select Incident Template',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                dropdownColor: AppColors.darkBg,
                icon: const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.primaryLight,
                ),
                items: _simulatorCategories.entries.map((e) {
                  return DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) async {
                  if (val != null) {
                    await HapticHelper.lightTick();
                    setState(() {
                      _selectedCategory = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Dropdown for target SIM card
          Text(
            'Link to SIM Card (Optional)',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 6),
          simLinesAsync.maybeWhen(
            data: (lines) {
              if (lines.isEmpty) {
                return Text(
                  'No SIM lines added yet.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiaryDark,
                  ),
                );
              }

              // Pre-select first line if null
              if (_selectedSimLineId == null && lines.isNotEmpty) {
                _selectedSimLineId = lines.first.id;
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSimLineId,
                    isExpanded: true,
                    dropdownColor: AppColors.darkBg,
                    icon: const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AppColors.primaryLight,
                    ),
                    items: lines.map((l) {
                      return DropdownMenuItem<String>(
                        value: l.id,
                        child: Text(
                          '${l.nickname ?? "SIM Card"} (${l.phoneNumber})',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimaryDark,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) async {
                      await HapticHelper.lightTick();
                      setState(() {
                        _selectedSimLineId = val;
                        if (val != null) {
                          final match = lines.firstWhere((l) => l.id == val);
                          _whatsappPhoneController.text = match.phoneNumber;
                        }
                      });
                    },
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // Delivery delay selector
          const SizedBox(height: 12),
          Text(
            'Delivery Timing',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedDelayMinutes,
                isExpanded: true,
                dropdownColor: AppColors.darkBg,
                icon: const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
                items: const [
                  DropdownMenuItem<int>(
                    value: 0,
                    child: Text('Instant Delivery (1-2 seconds)'),
                  ),
                  DropdownMenuItem<int>(
                    value: 1,
                    child: Text('Delayed: 1 Minute (Quick background test)'),
                  ),
                  DropdownMenuItem<int>(
                    value: 10,
                    child: Text('Delayed: 10 Minutes (Lock screen test)'),
                  ),
                ],
                onChanged: (val) async {
                  if (val != null) {
                    await HapticHelper.lightTick();
                    setState(() {
                      _selectedDelayMinutes = val;
                    });
                  }
                },
              ),
            ),
          ),

          // Local WhatsApp Server test toggle
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _sendLocalWhatsApp 
                    ? AppColors.primary.withValues(alpha: 0.3) 
                    : AppColors.darkBorder,
              ),
            ),
            child: Theme(
              data: ThemeData(
                unselectedWidgetColor: AppColors.textTertiaryDark,
              ),
              child: CheckboxListTile(
                title: Text(
                  'Trigger Local WhatsApp Server Alert',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Sends alert via your local server.js to WhatsApp',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                value: _sendLocalWhatsApp,
                activeColor: AppColors.primary,
                checkColor: Colors.white,
                onChanged: (val) async {
                  await HapticHelper.lightTick();
                  setState(() {
                    _sendLocalWhatsApp = val ?? false;
                  });
                },
              ),
            ),
          ),

          if (_sendLocalWhatsApp) ...[
            const SizedBox(height: 12),
            Text(
              'WhatsApp Recipient Phone Number',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _whatsappPhoneController,
              keyboardType: TextInputType.phone,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimaryDark,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 96891234567',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiaryDark,
                ),
                filled: true,
                fillColor: AppColors.darkCard,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                prefixIcon: const Icon(
                  Icons.phone_iphone_rounded,
                  color: AppColors.textSecondaryDark,
                  size: 20,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Trigger Button
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () async {
                await HapticHelper.mediumImpact();
                _triggerSimulatedAlert();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Inject simulated incident'),
            ),
          ),
        ],
      ),
    );
  }

  void _triggerSimulatedAlert() {
    String title = '';
    String body = '';

    switch (_selectedCategory) {
      case 'top_up_success':
        title = 'Renewal Successful';
        body =
            'Auto-refill of \$15.00 executed successfully. Your SIM validity has been extended by 30 days.';
        break;
      case 'top_up_failed':
        title = 'Renewal Failed (Critical)';
        body =
            'Immediate attention required! Auto-refill of \$10.00 failed due to insufficient wallet funds.';
        break;
      case 'wallet_low':
        title = 'Low Wallet Balance';
        body =
            'Your primary wallet balance is \$8.50, which is below your \$10.00 threshold limit.';
        break;
      case 'wallet_depleted':
        title = 'Wallet Depleted';
        body =
            'Your wallet has reached \$0.00. Automatic renewals are now suspended until you add funds.';
        break;
      case 'line_critical':
        title = 'SIM Approaching Expiry';
        body =
            'Your SIM card validity expires in 48 hours. Auto-renewal has been queued for immediate backup rescue.';
        break;
      case 'line_entering_grace':
        title = 'Entering Grace Period';
        body =
            'Your prepaid SIM card has entered carrier grace period. Please perform a top-up immediately to avoid deactivation.';
        break;
      case 'referral_reward':
        title = 'Referral Credit Awarded';
        body =
            'Congratulations! Your friend successfully joined. \$2.00 has been credited to your primary wallet.';
        break;
      case 'system':
      default:
        title = 'System Maintenance Completed';
        body =
            'Carrier rule engines updated for expat carrier nodes. All deactivation thresholds updated successfully.';
        break;
    }

    ref
        .read(notificationsControllerProvider.notifier)
        .simulateMockNotification(
          category: _selectedCategory,
          title: title,
          body: body,
          simLineId: _selectedSimLineId,
          delayMinutes: _selectedDelayMinutes,
        );

    if (_sendLocalWhatsApp) {
      final phone = _whatsappPhoneController.text.trim();
      if (phone.isNotEmpty) {
        WhatsAppService.sendMessage(
          phone: phone,
          message: '$title: $body',
        ).then((sent) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(sent 
                  ? 'WhatsApp mock alert sent successfully!' 
                  : 'Failed to send WhatsApp mock alert (check server.js!)'),
                backgroundColor: sent ? AppColors.success : AppColors.healthRed,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    }

    HapticHelper.successFeedback();

    final message = _selectedDelayMinutes > 0
        ? 'Scheduled mock alert "$title" to deliver in $_selectedDelayMinutes min!'
        : 'Simulated alert "$title" injected successfully!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateView(
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
    if (list.isEmpty) {
      return EmptyStateView(
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
                    foregroundColor: AppColors.primaryLight,
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
    Color indicatorColor = AppColors.primary;
    IconData icon = Icons.notifications_rounded;

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
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isRead
                  ? AppColors.darkBorder
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
              if (item.simLineId != null) {
                context.push('/sim-lines/detail/${item.simLineId}');
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
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textPrimaryDark,
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
                                    color: AppColors.textTertiaryDark,
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
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textSecondaryDark,
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
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: Text(
          'Clear all alerts?',
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.textPrimaryDark,
          ),
        ),
        content: Text(
          'This will permanently delete all notifications from your account timeline history.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
        actions: [
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textTertiaryDark),
            ),
            onPressed: () async {
              await HapticHelper.lightTick();
              Navigator.pop(ctx);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.healthRed,
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
