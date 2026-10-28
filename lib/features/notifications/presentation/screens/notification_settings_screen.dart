import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/notifications/data/models/alert_setting_model.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/notifications/presentation/widgets/alert_preferences_dashboard.dart';
import 'package:keep_sims/features/notifications/presentation/widgets/notification_permission_control.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_permission_controller.dart';
import 'package:keep_sims/features/notifications/data/models/channel_destination.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  // Helpers to map categories to labels, descriptions, and icons
  static final Map<String, _CategoryMeta> _meta = {
    'esim_updates': _CategoryMeta(
      name: 'eSIM status and validity',
      description: 'Installation readiness, activation, expiry and order results. In-app and push alerts only.',
      icon: Icons.sim_card_rounded,
      color: AppColors.info,
    ),
    'esim_low_data': _CategoryMeta(
      name: 'eSIM low data',
      description: 'Warn me when my eSIM data allowance is running low. In-app and push alerts only.',
      icon: Icons.data_usage_rounded,
      color: AppColors.warning,
    ),
    'top_up_success': _CategoryMeta(
      name: 'Top-up Successful',
      description:
          'Notify me when an automatic SIM validity extension is completed successfully.',
      icon: Icons.check_circle_rounded,
      color: AppColors.success,
    ),
    'top_up_failed': _CategoryMeta(
      name: 'Top-up Failed (Critical)',
      description:
          'Critical alerts when automatic top-ups fail due to carrier or wallet issues.',
      icon: Icons.error_outline_rounded,
      color: AppColors.healthRed,
    ),
    'wallet_low': _CategoryMeta(
      name: 'Low Wallet Balance',
      description:
          'Warn me when primary balance drops below the safety threshold.',
      icon: Icons.warning_amber_rounded,
      color: AppColors.warning,
    ),
    'wallet_depleted': _CategoryMeta(
      name: 'Wallet Depleted',
      description:
          'Suspended alerts when wallet balance is fully exhausted and renewals halt.',
      icon: Icons.dangerous_rounded,
      color: AppColors.healthRed,
    ),
    'line_critical': _CategoryMeta(
      name: 'Validity Expiry Warning',
      description:
          'Warn me when a SIM validity window is ending within 48 hours.',
      icon: Icons.timelapse_rounded,
      color: AppColors.healthRed,
    ),
    'line_entering_grace': _CategoryMeta(
      name: 'Entering Grace Period',
      description:
          'Notify me when carrier deactivation grace periods are detected.',
      icon: Icons.hourglass_bottom_rounded,
      color: AppColors.warning,
    ),
    'geo_fence_triggered': _CategoryMeta(
      name: 'Location / Roaming Alerts',
      description:
          'Alerts when carrier switches roaming clusters or network nodes.',
      icon: Icons.explore_rounded,
      color: AppColors.info,
    ),
    'welcome_home_ready': _CategoryMeta(
      name: 'Welcome Home Sync',
      description:
          'Alerts when home-country network node triggers automated syncs.',
      icon: Icons.home_work_rounded,
      color: AppColors.info,
    ),
    'referral_reward': _CategoryMeta(
      name: 'Referral & Rewards',
      description:
          'Notify me when friend referrals deposit promotional balances into my wallet.',
      icon: Icons.card_giftcard_rounded,
      color: const Color(0xFFEC4899),
    ),
    'system': _CategoryMeta(
      name: 'General System Updates',
      description:
          'Vital engine updates, maintenance, and platform announcements.',
      icon: Icons.settings_suggest_rounded,
      color: AppColors.primary,
    ),
    'wallet_credit': _CategoryMeta(
      name: 'Wallet Credited',
      description: 'Notify me when a deposit lands in my wallet.',
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.success,
    ),
    'promo': _CategoryMeta(
      name: 'Offers & Promotions',
      description:
          'Occasional news about deals and new features. Stays off until you turn it on.',
      icon: Icons.local_offer_rounded,
      color: const Color(0xFFF59E0B),
    ),
    'support': _CategoryMeta(
      name: 'Support & Tickets',
      description:
          'Notify me when support replies to my tickets or updates ticket status.',
      icon: Icons.headset_mic_rounded,
      color: AppColors.info,
    ),
    // I8b. Its own row rather than folded into 'system': this is the one alert
    // that regularly tells the user to buy from someone other than us, and
    // muting it must not also mute maintenance notices.
    'carrier_action': _CategoryMeta(
      name: 'Carrier Action Needed',
      description:
          'Tell me when a line needs something only I can do — using the SIM, '
          'or topping it up in my operator\'s own app.',
      icon: Icons.storefront_rounded,
      color: AppColors.warning,
    ),
  };

  /// Channels a user can switch per category. telegram and whatsapp stay on the
  /// global switches above — they carry their own config and tier gating, and
  /// the dispatcher intersects both lists anyway.
  static const List<String> _perCategoryChannels = ['push', 'email'];

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: context.scaffoldBackgroundColor,
    appBar: AppBar(
      backgroundColor: context.scaffoldBackgroundColor,
      title: const Text(
        'Alert preferences',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
    ),
    body: AlertPreferencesDashboard(
      onChannel: (type) => showChannelSheet(context, type),
      onTiming: (weekly) => _openSheet(
        context,
        weekly ? 'Weekly summary' : 'Quiet hours',
        Consumer(
          builder: (context, ref, _) {
            return ref
                .watch(userPreferencesControllerProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Column(
                    children: [
                      const Text('Your settings could not be saved or loaded.'),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(userPreferencesControllerProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                  data: (prefs) => _buildQuietHoursCard(
                    context,
                    ref,
                    prefs,
                    weeklyOnly: weekly,
                  ),
                );
          },
        ),
      ),
      onAlertTypes: () => _openSheet(
        context,
        'Alert types & price watches',
        Consumer(
          builder: (context, ref, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ref
                    .watch(alertSettingsControllerProvider)
                    .when(
                      data: (settings) => _buildIncidentChannels(
                        context,
                        ref,
                        settings,
                        ref
                                .watch(notificationChannelsControllerProvider)
                                .value ??
                            [],
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) =>
                          const Text('Could not load alert types.'),
                    ),
                _buildSectionHeader(context, 'Price watch'),
                _buildPriceWatchEntry(context),
              ],
            );
          },
        ),
      ),
    ),
  );

  /// Shared editor, also opened directly from the per-SIM auto-notify sheet.
  static Future<void> showChannelSheet(BuildContext context, String type) =>
      _openSheet(
        context,
        switch (type) {
          'push' => 'Push notifications',
          'email' => 'Email alerts',
          'whatsapp' => 'WhatsApp alerts',
          _ => 'Telegram bot',
        },
        Consumer(
          builder: (context, ref, _) {
            return ref
                .watch(notificationChannelsControllerProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Text(
                    'Could not load this channel. Close and try again.',
                  ),
                  data: (rows) {
                    final matching = rows.where(
                      (row) => row['channel_type'] == type,
                    );
                    if (matching.isEmpty) {
                      return const Text(
                        'Channel unavailable. Reload your preferences.',
                      );
                    }
                    return ChannelConfigCard(
                      key: ValueKey(type),
                      channel: matching.first,
                      userId: ref.watch(authControllerProvider).value?.id,
                      isNested: true,
                    );
                  },
                );
          },
        ),
      );
  static Future<void> _openSheet(
    BuildContext context,
    String title,
    Widget content,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.cardColor,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: content,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildPriceWatchEntry(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ListTile(
        onTap: () => context.push(AppRoutes.esimPriceWatch),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.trending_down_rounded,
            color: Color(0xFFF59E0B),
            size: 20,
          ),
        ),
        title: Text(
          'Countries and carriers you watch',
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Price drops are sent under Offers & Promotions above.',
          style: AppTextStyles.caption.copyWith(
            color: context.onSurfaceColor.withValues(alpha: 0.6),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: context.onSurfaceColor.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = context.isDarkMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelMedium.copyWith(
          color: isDark
              ? AppColors.textTertiaryDark
              : AppColors.textTertiaryLight,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQuietHoursCard(
    BuildContext context,
    WidgetRef ref,
    dynamic prefs, {
    bool weeklyOnly = false,
  }) {
    final startVal = prefs.quietHoursStart;
    final endVal = prefs.quietHoursEnd;
    final isQuietHoursActive = startVal != null && endVal != null;
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          if (!weeklyOnly)
            SwitchListTile(
              value: isQuietHoursActive,
              activeThumbColor: context.colorScheme.secondary,
              activeTrackColor: context.colorScheme.secondary.withValues(
                alpha: 0.2,
              ),
              inactiveThumbColor: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
              inactiveTrackColor: isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
              title: Row(
                children: [
                  Icon(
                    Icons.nights_stay_rounded,
                    color: context.colorScheme.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pause routine alerts',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: context.onSurfaceColor,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.dndDesc,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              onChanged: (active) async {
                await HapticHelper.mediumImpact();
                if (active) {
                  // Enable defaults: 10:00 PM to 7:00 AM
                  await ref
                      .read(userPreferencesControllerProvider.notifier)
                      .updateQuietHours('22:00:00', '07:00:00');
                } else {
                  // Clear times to disable
                  await ref
                      .read(userPreferencesControllerProvider.notifier)
                      .updateQuietHours(null, null);
                }
              },
            ),

          if (!weeklyOnly && isQuietHoursActive) ...[
            Divider(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              height: 1,
            ),
            // Time Pickers Row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTimePickerButton(
                      context,
                      label: 'Start Time',
                      timeStr: startVal,
                      onTimeSelected: (newTime) {
                        ref
                            .read(userPreferencesControllerProvider.notifier)
                            .updateQuietHours(newTime, endVal);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimePickerButton(
                      context,
                      label: 'End Time',
                      timeStr: endVal,
                      onTimeSelected: (newTime) {
                        ref
                            .read(userPreferencesControllerProvider.notifier)
                            .updateQuietHours(startVal, newTime);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          Divider(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            height: 1,
          ),

          if (weeklyOnly)
            SwitchListTile(
              value: prefs.weeklyDigestEnabled,
              activeThumbColor: context.primaryColor,
              activeTrackColor: context.primaryColor.withValues(alpha: 0.2),
              inactiveThumbColor: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
              inactiveTrackColor: isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
              title: Row(
                children: [
                  Icon(
                    Icons.summarize_rounded,
                    color: isDark
                        ? AppColors.primaryLight
                        : context.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Enable weekly summary',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: context.onSurfaceColor,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                'Email a SIM status summary every Sunday at 9:00 AM in your saved notification time zone. Only eligible Standard and Premium SIMs are included.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              onChanged: (active) async {
                await HapticHelper.mediumImpact();
                ref
                    .read(userPreferencesControllerProvider.notifier)
                    .toggleWeeklyDigest(active);
              },
            ),
          if (weeklyOnly &&
              prefs.weeklyDigestEnabled &&
              ref.watch(weeklyDigestConsentProvider).value == false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextButton.icon(
                onPressed: () => ref
                    .read(userPreferencesControllerProvider.notifier)
                    .toggleWeeklyDigest(true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm weekly digest to start summaries'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimePickerButton(
    BuildContext context, {
    required String label,
    required String? timeStr,
    required ValueChanged<String> onTimeSelected,
  }) {
    final isDark = context.isDarkMode;
    return InkWell(
      onTap: () async {
        await HapticHelper.lightTick();
        if (!context.mounted) return;
        final currentTod = _parseTimeOfDay(timeStr);
        final selectedTime = await showTimePicker(
          context: context,
          initialTime: currentTod,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: isDark
                    ? const ColorScheme.dark(
                        primary: AppColors.primary,
                        onPrimary: Colors.white,
                        surface: AppColors.darkSurface,
                        onSurface: AppColors.textPrimaryDark,
                      )
                    : ColorScheme.light(
                        primary: context.primaryColor,
                        onPrimary: Colors.white,
                        surface: AppColors.lightSurface,
                        onSurface: AppColors.textPrimaryLight,
                      ),
              ),
              child: child!,
            );
          },
        );

        if (selectedTime != null) {
          onTimeSelected(_formatTimeOfDay(selectedTime));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDisplayTime(timeStr),
                  style: AppTextStyles.titleMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _CategoryMeta _getLocalizedMeta(
    BuildContext context,
    String categoryKey,
    _CategoryMeta defaultMeta,
  ) {
    final local = AppLocalizations.of(context)!;
    switch (categoryKey) {
      case 'top_up_success':
        return _CategoryMeta(
          name: local.topUpSuccessTitle,
          description: local.topUpSuccessDesc,
          icon: defaultMeta.icon,
          color: defaultMeta.color,
        );
      case 'top_up_failed':
        return _CategoryMeta(
          name: local.topUpFailedTitle,
          description: local.topUpFailedDesc,
          icon: defaultMeta.icon,
          color: defaultMeta.color,
        );
      case 'wallet_low':
        return _CategoryMeta(
          name: local.walletLowTitle,
          description: local.walletLowDesc,
          icon: defaultMeta.icon,
          color: defaultMeta.color,
        );
      case 'wallet_depleted':
        return _CategoryMeta(
          name: local.walletDepletedTitle,
          description: local.walletDepletedDesc,
          icon: defaultMeta.icon,
          color: defaultMeta.color,
        );
      case 'line_critical':
        return _CategoryMeta(
          name: local.lineCriticalTitle,
          description: local.lineCriticalDesc,
          icon: defaultMeta.icon,
          color: defaultMeta.color,
        );
      case 'line_entering_grace':
        return _CategoryMeta(
          name: local.lineEnteringGraceTitle,
          description: local.lineEnteringGraceDesc,
          icon: defaultMeta.icon,
          color: defaultMeta.color,
        );
      case 'geo_fence_triggered':
        return _CategoryMeta(
          name: local.geoFenceTriggeredTitle,
          description: local.geoFenceTriggeredDesc,
          icon: defaultMeta.icon,
          color: defaultMeta.color,
        );
      case 'welcome_home_ready':
        return _CategoryMeta(
          name: local.welcomeHomeReadyTitle,
          description: local.welcomeHomeReadyDesc,
          icon: defaultMeta.icon,
          color: defaultMeta.color,
        );
      case 'referral_reward':
        return _CategoryMeta(
          name: local.referralRewardTitle,
          description: local.referralRewardDesc,
          icon: defaultMeta.icon,
          color: defaultMeta.color,
        );
      case 'system':
        return _CategoryMeta(
          name: local.systemUpdatesTitle,
          description: local.systemUpdatesDesc,
          icon: defaultMeta.icon,
          color: defaultMeta.color,
        );
      case 'wallet_credit':
        return _CategoryMeta(
          name: local.walletCreditTitle,
          description: local.walletCreditDesc,
          icon: defaultMeta.icon,
          color: defaultMeta.color,
        );
      case 'promo':
        return _CategoryMeta(
          name: local.promoTitle,
          description: local.promoDesc,
          icon: defaultMeta.icon,
          color: defaultMeta.color,
        );
      case 'carrier_action':
        return _CategoryMeta(
          name: local.carrierActionTitle,
          description: local.carrierActionDesc,
          icon: defaultMeta.icon,
          color: defaultMeta.color,
        );
      default:
        return defaultMeta;
    }
  }

  Widget _buildIncidentChannels(
    BuildContext context,
    WidgetRef ref,
    List<AlertSetting> settings,
    List<Map<String, dynamic>> channels,
  ) {
    final isDark = context.isDarkMode;
    final globallyEnabled = {
      for (final c in channels)
        if (c['is_enabled'] == true) c['channel_type'] as String,
    };
    if (settings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No channels initialized.',
            style: TextStyle(
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: settings.length,
      itemBuilder: (context, index) {
        final item = settings[index];
        final rawMetadata =
            _meta[item.category] ??
            _CategoryMeta(
              name: item.category,
              description: 'General notification alerts.',
              icon: Icons.notifications_rounded,
              color: AppColors.primary,
            );
        final metadata = _getLocalizedMeta(context, item.category, rawMetadata);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isEnabled
                  ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                  : (isDark
                        ? AppColors.darkBorder.withValues(alpha: 0.5)
                        : AppColors.lightBorder.withValues(alpha: 0.5)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                value: item.isEnabled,
                activeThumbColor: metadata.color,
                activeTrackColor: metadata.color.withValues(alpha: 0.2),
                inactiveThumbColor: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
                inactiveTrackColor: isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
                title: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: item.isEnabled
                            ? metadata.color.withValues(alpha: 0.1)
                            : (isDark
                                  ? AppColors.darkBorder
                                  : Colors.black.withValues(alpha: 0.04)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        metadata.icon,
                        color: item.isEnabled
                            ? metadata.color
                            : (isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        metadata.name,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: item.isEnabled
                              ? context.onSurfaceColor
                              : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    metadata.description,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      height: 1.3,
                    ),
                  ),
                ),
                onChanged: (val) async {
                  await HapticHelper.mediumImpact();
                  ref
                      .read(alertSettingsControllerProvider.notifier)
                      .toggleCategory(item.category, val);
                },
              ),
              if (item.isEnabled)
                _buildCategoryChannels(context, ref, item, globallyEnabled),
            ],
          ),
        );
      },
    );
  }

  /// Per-category delivery routes (C2). These only narrow: a channel also has
  /// to be enabled globally above, which is why one that is off globally is
  /// shown dimmed rather than hidden — hiding it would make the category look
  /// like it had fewer routes than it does.
  Widget _buildCategoryChannels(
    BuildContext context,
    WidgetRef ref,
    AlertSetting item,
    Set<String> globallyEnabled,
  ) {
    final local = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(
            local.deliverVia,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
              fontWeight: FontWeight.bold,
            ),
          ),
          ...(item.category.startsWith('esim_') ? ['push'] : _perCategoryChannels).map((channel) {
            final selected = item.channels.contains(channel);
            final offGlobally = !globallyEnabled.contains(channel);
            final label = channel == 'push'
                ? local.channelPushShort
                : local.channelEmailShort;

            final chip = FilterChip(
              selected: selected,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: selected
                      ? context.primaryColor
                      : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  fontWeight: FontWeight.bold,
                  decoration: offGlobally && selected
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              selectedColor: context.primaryColor.withValues(alpha: 0.15),
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightBg,
              side: BorderSide(
                color: selected
                    ? context.primaryColor.withValues(alpha: 0.5)
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              onSelected: (val) async {
                await HapticHelper.lightTick();
                ref
                    .read(alertSettingsControllerProvider.notifier)
                    .toggleChannelForCategory(item.category, channel, val);
              },
            );

            return offGlobally
                ? Tooltip(message: local.channelOffGlobally, child: chip)
                : chip;
          }),
        ],
      ),
    );
  }

  // --- TimeOfDay Parsers ---
  TimeOfDay _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) {
      return const TimeOfDay(hour: 22, minute: 0);
    }
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 22, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  String _formatDisplayTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'Not Set';
    final tod = _parseTimeOfDay(timeStr);
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Config Card for Alert Delivery Channels
// ─────────────────────────────────────────────────────────────────────────────
class ChannelConfigCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> channel;
  final String? userId;
  final bool isNested;

  const ChannelConfigCard({
    super.key,
    required this.channel,
    required this.userId,
    this.isNested = false,
  });

  @override
  ConsumerState<ChannelConfigCard> createState() => _ChannelConfigCardState();
}

class _ChannelConfigCardState extends ConsumerState<ChannelConfigCard> {
  late TextEditingController _textController;
  late bool _isEnabled;
  bool _isSaving = false;
  bool _isSendingTestPush = false;
  bool _isLinkingTelegram = false;
  bool _isToggling = false;
  bool _isDirty = false;
  String? _accountEmail;
  String? _currentEmail;
  String? _pendingEmail;
  bool _emailStatusLoaded = false;
  bool _emailStatusFailed = false;
  bool _isLoadingEmailStatus = false;
  bool _accountEmailVerified = false;
  bool _emailIsVerified = false;
  bool _emailIsAlternate = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.channel['is_enabled'] ?? false;
    final config = widget.channel['config'] as Map<String, dynamic>? ?? {};
    final type = widget.channel['channel_type'] as String;
    String initialText = '';
    if (type == 'email') {
      final authUser = Supabase.instance.client.auth.currentUser;
      final userEmail =
          authUser?.email ?? ref.read(authControllerProvider).value?.email;
      _accountEmail = userEmail;
      _accountEmailVerified = authUser?.emailConfirmedAt != null;
      _currentEmail = userEmail;
      _emailIsVerified = _accountEmailVerified;
      initialText = userEmail ?? '';
      _verificationCodeController = TextEditingController();
      _loadEmailStatus();
    } else if (type == 'whatsapp') {
      initialText = channelDestination(type, config);
    } /* else if (type == 'webhook') {
      initialText = config['webhook_url'] ?? '';
    } */
    _textController = TextEditingController(text: initialText);
  }

  @override
  void didUpdateWidget(covariant ChannelConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel) {
      _isEnabled = widget.channel['is_enabled'] ?? false;
      final config = widget.channel['config'] as Map<String, dynamic>? ?? {};
      final type = widget.channel['channel_type'] as String;
      String currentText = '';
      if (type == 'email') {
        currentText = _pendingEmail ?? _currentEmail ?? _accountEmail ?? '';
      } else if (type == 'whatsapp') {
        currentText = channelDestination(type, config);
      } /* else if (type == 'webhook') {
        currentText = config['webhook_url'] ?? '';
      } */
      if (!_isDirty && _textController.text != currentText) {
        _textController.text = currentText;
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    if ((widget.channel['channel_type'] as String) == 'email') {
      _verificationCodeController.dispose();
    }
    super.dispose();
  }

  late final TextEditingController _verificationCodeController;

  Future<void> _loadEmailStatus() async {
    if (_isLoadingEmailStatus) return;
    setState(() {
      _isLoadingEmailStatus = true;
    });

    final authUser = Supabase.instance.client.auth.currentUser;
    final userEmail =
        authUser?.email ?? ref.read(authControllerProvider).value?.email;
    if (userEmail != null) {
      _accountEmail = userEmail;
      _accountEmailVerified = authUser?.emailConfirmedAt != null;
    }

    try {
      final result = await Supabase.instance.client.functions.invoke(
        'notification-email-verification',
        body: const {'action': 'status'},
      ).timeout(const Duration(seconds: 5));

      if (result.status == 200 && result.data is Map) {
        final data = Map<String, dynamic>.from(result.data as Map);
        if (!mounted) return;
        setState(() {
          _accountEmail = data['account_email'] as String? ?? _accountEmail;
          _accountEmailVerified =
              data['account_email_verified'] == true || _accountEmailVerified;
          _currentEmail = data['current_email'] as String? ?? _accountEmail;
          _pendingEmail = data['pending_email'] as String?;
          _emailIsAlternate = data['alternate_email'] is String;
          _emailIsVerified = _currentEmail != null &&
              (_emailIsAlternate || _accountEmailVerified);
          _emailStatusLoaded = true;
          _emailStatusFailed = false;
          _isLoadingEmailStatus = false;
          if (!_isDirty) {
            _textController.text =
                _pendingEmail ?? _currentEmail ?? _accountEmail ?? '';
          }
        });
        return;
      }
    } catch (_) {
      // Backend Edge Function is unreachable or timed out
    }

    if (!mounted) return;
    setState(() {
      _currentEmail = _accountEmail;
      _emailIsVerified = _accountEmailVerified;
      _emailIsAlternate = false;
      _emailStatusLoaded = true;
      _emailStatusFailed = false;
      _isLoadingEmailStatus = false;
      if (!_isDirty) {
        _textController.text = _accountEmail ?? '';
      }
    });
  }

  Future<dynamic> _callEmailVerification(Map<String, dynamic> body) async {
    final result = await Supabase.instance.client.functions.invoke(
      'notification-email-verification',
      body: body,
    );
    if (result.data is Map && (result.data as Map)['error'] != null) {
      throw StateError((result.data as Map)['error'].toString());
    }
    if (result.status >= 400) {
      throw StateError('Request failed (${result.status}).');
    }
    return result.data;
  }

  Future<void> _resendEmailCode() async {
    final email = _pendingEmail;
    if (email == null) return;
    setState(() => _isSaving = true);
    try {
      await _callEmailVerification({'action': 'request_code', 'email': email});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('A new code was sent to $email.')));
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError
          ? e.message
          : 'Could not resend the code yet. Please try again shortly.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveEmailDestination() async {
    final value = _textController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      setState(() => _validationError = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _isSaving = true;
      _validationError = null;
    });
    try {
      final isAccountEmail =
          _accountEmail != null &&
          value.toLowerCase() == _accountEmail!.toLowerCase();
      if (isAccountEmail && !_accountEmailVerified) {
        setState(() {
          _isSaving = false;
          _validationError =
              'Confirm your account email before using it for alerts.';
        });
        return;
      }
      final isPendingEmail =
          _pendingEmail != null &&
          value.toLowerCase() == _pendingEmail!.toLowerCase();
      if (isPendingEmail) {
        final code = _verificationCodeController.text.trim();
        if (!RegExp(r'^\d{8}$').hasMatch(code)) {
          setState(() {
            _isSaving = false;
            _validationError = 'Enter the 8-digit code.';
          });
          return;
        }
        await _callEmailVerification({'action': 'confirm_code', 'code': code});
        _verificationCodeController.clear();
        _currentEmail = value;
        _pendingEmail = null;
        _emailIsAlternate = !isAccountEmail;
        _emailIsVerified = true;

        final config =
            Map<String, dynamic>.from(widget.channel['config'] ?? {});
        config['email'] = value;
        config['email_address'] = value;
        await ref
            .read(notificationChannelsControllerProvider.notifier)
            .updateChannelConfig('email', config);
      } else if (isAccountEmail) {
        try {
          await _callEmailVerification({'action': 'use_account_email'});
        } catch (_) {}
        final config =
            Map<String, dynamic>.from(widget.channel['config'] ?? {});
        config['email'] = _accountEmail;
        config['email_address'] = _accountEmail;
        await ref
            .read(notificationChannelsControllerProvider.notifier)
            .updateChannelConfig('email', config);
        _currentEmail = _accountEmail;
        _pendingEmail = null;
        _emailIsAlternate = false;
        _emailIsVerified = _accountEmail != null && _accountEmailVerified;
      } else if (_currentEmail != null &&
          value.toLowerCase() == _currentEmail!.toLowerCase()) {
        setState(() {
          _isSaving = false;
          _isDirty = false;
        });
        return;
      } else {
        await _callEmailVerification({
          'action': 'request_code',
          'email': value,
        });
        _verificationCodeController.clear();
        _pendingEmail = value;
      }
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isDirty = false;
      });
      await _loadEmailStatus();
      if (!mounted) return;
      if (_pendingEmail != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification code sent to $_pendingEmail. Check your inbox.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(content: Text('Alert email verified and updated.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final message = e is StateError
          ? e.message
          : 'Could not update the alert email. Check the address and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _saveConfig() async {
    final type = widget.channel['channel_type'] as String;
    if (type == 'email') {
      await _saveEmailDestination();
      return;
    }
    final config = Map<String, dynamic>.from(widget.channel['config'] ?? {});
    var value = _textController.text.trim();
    if (type == 'whatsapp') {
      value = value.replaceAll(RegExp(r'[\s\-()]'), '');
      if (value.startsWith('00')) value = '+${value.substring(2)}';
      if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value)) {
        setState(
          () => _validationError =
              'Enter the full international number, including + and country code.',
        );
        return;
      }
      config['phone'] = value;
      config['phone_number'] = value;
    }
    setState(() {
      _isSaving = true;
      _validationError = null;
    });
    try {
      await ref
          .read(notificationChannelsControllerProvider.notifier)
          .updateChannelConfig(type, config);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isDirty = false;
        _textController.text = value;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save settings. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.channel['channel_type'] as String;
    final config = Map<String, dynamic>.from(widget.channel['config'] ?? {});
    final catalog = ref.watch(notificationChannelCatalogProvider).value?[type];
    final available = catalog?['is_globally_enabled'] != false;
    final paid = type == 'email' || type == 'whatsapp';
    final telegramLinked =
        '${config['chat_id'] ?? ''}'.trim().isNotEmpty &&
        config['binding_verified_at'] != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (paid)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'For eligible Standard and Premium SIMs.',
                style: TextStyle(color: context.colorScheme.onSurfaceVariant),
              ),
            ),
          if (!available)
            _buildInfoBadge(
              'Currently unavailable. You can still save your preference.',
              context.colorScheme.onSurfaceVariant,
            ),
          if (type != 'telegram' || telegramLinked)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Enable alerts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              value: _isEnabled,
              activeTrackColor: context.primaryColor,
              onChanged:
                  _isToggling ||
                      _isSaving ||
                      (type == 'email' && !_emailStatusLoaded)
                  ? null
                  : (value) async {
                      if (type == 'email' && value && !_emailIsVerified) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Verify an email address before enabling email alerts.',
                            ),
                          ),
                        );
                        return;
                      }
                      final previous = _isEnabled;
                      setState(() {
                        _isEnabled = value;
                        _isToggling = true;
                      });
                      try {
                        await ref
                            .read(
                              notificationChannelsControllerProvider.notifier,
                            )
                            .toggleChannel(type, value);
                      } catch (_) {
                        if (mounted) {
                          setState(() => _isEnabled = previous);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not save your preference. Please try again.',
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isToggling = false);
                      }
                    },
            ),
          const SizedBox(height: 8),
          if (type == 'push') _buildPushContent(context),
          if (type == 'telegram') _buildTelegramContent(context, config),
          if (paid) ...[
            _buildTextField(context, type),
            const SizedBox(height: 16),
            _buildSaveButton(context),
          ],
          const SizedBox(height: 16),
          _buildInfoBadge(switch (type) {
            'push' => 'Device permissions and Do Not Disturb still apply.',
            'email' => 'Email alerts warn you about critical SIM events.',
            'whatsapp' =>
              'Refill failure alerts are sent to the saved WhatsApp number.',
            _ => 'Telegram sends alerts only when linked and enabled.',
          }, context.primaryColor),
        ],
      ),
    );
  }

  Widget _buildPushContent(BuildContext context) {
    ref.watch(notificationPermissionControllerProvider);
    final isDark = context.isDarkMode;
    final playerId = OneSignal.User.pushSubscription.id;
    final isOptedIn = OneSignal.User.pushSubscription.optedIn;
    final connected = playerId != null && isOptedIn == true;
    final statusColor = connected
        ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534))
        : (isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NotificationPermissionControl(),
        const SizedBox(height: 16),
        // Status Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: connected
                ? Colors.green.withValues(alpha: isDark ? 0.15 : 0.08)
                : Colors.amber.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: connected
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.amber.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                connected
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  playerId != null
                      ? ((isOptedIn ?? false)
                            ? 'Device Subscribed & Active'
                            : 'Push subscription paused')
                      : 'Connecting to push service...',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Send Test Notification Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                (_isSendingTestPush || playerId == null || isOptedIn != true)
                ? null
                : () async {
                    setState(() => _isSendingTestPush = true);
                    try {
                      await HapticHelper.lightTick();
                      if (!mounted) return;
                      await ref
                          .read(notificationsRepositoryProvider)
                          .sendNotification(
                            category: 'system',
                            title: 'KeepSIMs Test Alert',
                            body:
                                'KeepSIMs requested a test notification for this device.',
                            channelType: 'push',
                          );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Test alert queued. Check your enabled routes and device permissions for arrival.',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green.shade700,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to send test notification: $e'),
                          backgroundColor: context.colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _isSendingTestPush = false);
                      }
                    }
                  },
            icon: _isSendingTestPush
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.notifications_active_outlined, size: 18),
            label: Text(
              _isSendingTestPush
                  ? 'Sending Test Alert...'
                  : 'Send Test Notification',
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Requests an immediate test alert. Provider acceptance does not confirm display on this device.',
          style: AppTextStyles.caption.copyWith(
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(BuildContext context, String type) {
    final isDark = context.isDarkMode;
    String label = '';
    String hint = '';
    IconData prefixIcon = Icons.edit;
    TextInputType keyboardType = TextInputType.text;

    if (type == 'email') {
      label = AppLocalizations.of(context)!.emailAddressLabel;
      hint = AppLocalizations.of(context)!.emailAddressHint;
      prefixIcon = Icons.alternate_email_rounded;
      keyboardType = TextInputType.emailAddress;
    } else if (type == 'whatsapp') {
      label = AppLocalizations.of(context)!.whatsappNumberLabel;
      hint = AppLocalizations.of(context)!.whatsappNumberHint;
      prefixIcon = Icons.phone_rounded;
      keyboardType = TextInputType.phone;
    } /* else if (type == 'webhook') {
      label = 'Emergency Endpoint Webhook URL';
      hint = 'e.g. https://api.domain.com/alert';
      prefixIcon = Icons.link_rounded;
      keyboardType = TextInputType.url;
    } */

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _textController,
          enabled: !_isSaving,
          onChanged: (_) => setState(() {
            _isDirty = true;
            _validationError = null;
          }),
          keyboardType: keyboardType,
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.onSurfaceColor,
          ),
          decoration: InputDecoration(
            hintText: hint,
            errorText: _validationError,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
            prefixIcon: Icon(
              prefixIcon,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              size: 18,
            ),
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.primaryColor),
            ),
          ),
        ),
        if (type == 'email') ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              !_emailStatusLoaded || _isLoadingEmailStatus
                  ? 'Checking your verified alert address…'
                  : _emailStatusFailed
                  ? _accountEmailVerified
                        ? 'Your account email is verified. We could not load the saved alert address details.'
                        : 'Could not load your email verification and saved alert address details. Try again.'
                  : _currentEmail != null
                  ? 'Verified destination: $_currentEmail'
                  : _accountEmail != null && !_accountEmailVerified
                  ? 'Confirm your account email before using it for alerts.'
                  : 'Verify an email address before email alerts can be sent.',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ),
          if (_emailStatusFailed)
            TextButton.icon(
              onPressed: _isLoadingEmailStatus ? null : _loadEmailStatus,
              icon: _isLoadingEmailStatus
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_isLoadingEmailStatus ? 'Checking…' : 'Retry'),
            ),
          if (_pendingEmail != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _verificationCodeController,
              enabled: !_isSaving,
              keyboardType: TextInputType.number,
              maxLength: 8,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '8-digit verification code',
                counterText: '',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            Text(
              _currentEmail != null
                  ? 'Alerts continue going to $_currentEmail until this address is verified.'
                  : 'No email alerts are sent until this address is verified.',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isSaving ? null : _resendEmailCode,
                icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                label: const Text('Resend code'),
              ),
            ),
          ],
          if (_emailIsAlternate &&
              _accountEmail != null &&
              _accountEmailVerified) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isSaving
                    ? null
                    : () {
                        _textController.text = _accountEmail!;
                        setState(() {
                          _isDirty = true;
                          _validationError = null;
                        });
                      },
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Use account email'),
              ),
            ),
          ],
        ],
        if (type == 'whatsapp') ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              AppLocalizations.of(context)!.whatsappFormatInstruction,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    final isEmail = widget.channel['channel_type'] == 'email';
    final input = _textController.text.trim();
    final isPending =
        _pendingEmail != null &&
        input.toLowerCase() == _pendingEmail!.toLowerCase();
    final isUnverifiedAccount =
        _accountEmail != null &&
        input.toLowerCase() == _accountEmail!.toLowerCase() &&
        !_accountEmailVerified;
    final emailNeedsAction = isPending
        ? RegExp(r'^\d{8}$').hasMatch(_verificationCodeController.text.trim())
        : isUnverifiedAccount
        ? false
        : _currentEmail == null ||
              input.toLowerCase() != _currentEmail!.toLowerCase();
    final canSaveEmail =
        _emailStatusLoaded && !_emailStatusFailed && emailNeedsAction;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving || _isToggling || (isEmail && !canSaveEmail)
            ? null
            : _saveConfig,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                isEmail
                    ? _emailStatusFailed
                          ? 'Alert address details unavailable'
                          : isPending
                          ? 'Verify code'
                          : isUnverifiedAccount
                          ? 'Confirm account email'
                          : input.isEmpty || !emailNeedsAction
                          ? 'Email verified'
                          : input.toLowerCase() == _accountEmail?.toLowerCase()
                          ? 'Use account email'
                          : 'Send verification code'
                    : AppLocalizations.of(context)!.saveSettings,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildTelegramContent(
    BuildContext context,
    Map<String, dynamic> config,
  ) {
    final chatId = config['chat_id'];
    final isBound =
        chatId != null &&
        chatId.toString().isNotEmpty &&
        config['binding_verified_at'] != null;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBound
                    ? Icons.check_circle_rounded
                    : Icons.pending_actions_rounded,
                color: isBound ? AppColors.success : AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isBound
                    ? AppLocalizations.of(
                        context,
                      )!.telegramStatusBound(chatId.toString())
                    : AppLocalizations.of(context)!.telegramStatusUnbound,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isBound ? AppColors.success : AppColors.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.telegramLinkInstructions,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLinkingTelegram || widget.userId == null
                  ? null
                  : () async {
                      setState(() => _isLinkingTelegram = true);
                      final userId = widget.userId;
                      if (userId == null) return;
                      try {
                        await HapticHelper.lightTick();
                        if (!mounted) return;
                        final result = await Supabase.instance.client.rpc(
                          'create_telegram_bind_token',
                        );
                        if (!mounted) return;
                        final token = result is Map ? result['token'] : null;
                        if (result is! Map ||
                            result['success'] != true ||
                            token is! String ||
                            !RegExp(r'^[0-9a-f]{32}$').hasMatch(token)) {
                          throw StateError(
                            'Could not create a secure Telegram link',
                          );
                        }
                        final uri = Uri.parse(
                          'https://t.me/KeepSIMsBot?start=bind_$token',
                        );
                        if (await canLaunchUrl(uri)) {
                          if (!mounted) return;
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          throw StateError('Could not open Telegram');
                        }
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Telegram link unavailable: $error'),
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _isLinkingTelegram = false);
                      }
                    },
              icon: const Icon(Icons.telegram, color: Colors.white, size: 20),
              label: Text(
                AppLocalizations.of(context)!.linkTelegramBot,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                height: 1.4,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryMeta {
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  _CategoryMeta({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}
