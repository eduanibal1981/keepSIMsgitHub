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
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  // Helpers to map categories to labels, descriptions, and icons
  static final Map<String, _CategoryMeta> _meta = {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final alertSettingsAsync = ref.watch(alertSettingsControllerProvider);
    final userPrefsAsync = ref.watch(userPreferencesControllerProvider);
    final channelsAsync = ref.watch(notificationChannelsControllerProvider);
    final userAsync = ref.watch(authControllerProvider);
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.onSurfaceColor),
          onPressed: () async {
            await HapticHelper.lightTick();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          AppLocalizations.of(context)!.alertSettingsTitle,
          style: AppTextStyles.headlineMedium.copyWith(
            color: context.onSurfaceColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Do Not Disturb / Quiet Hours Preferences Card
            _buildSectionHeader(
              context,
              AppLocalizations.of(context)!.quietHoursSchedule,
            ),
            userPrefsAsync.when(
              data: (prefs) => _buildQuietHoursCard(context, ref, prefs),
              loading: () => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: context.primaryColor),
                ),
              ),
              error: (err, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Alert Delivery Channels Highlighted Container
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: isDark ? 0.08 : 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: isDark ? 0.3 : 0.25),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.alertChannels,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.orange.shade700,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: Colors.orange.shade700,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppLocalizations.of(context)!.mostImportant,
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  channelsAsync.when(
                    data: (channels) => _buildAlertDeliveryChannels(
                      context,
                      ref,
                      channels,
                      userAsync.value?.id,
                      isNested: true,
                    ),
                    loading: () => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                    error: (err, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Incident Channels (Alert settings per category)
            _buildSectionHeader(
              context,
              AppLocalizations.of(context)!.incidentChannelsTitle,
            ),
            alertSettingsAsync.when(
              data: (settings) => _buildIncidentChannels(
                context,
                ref,
                settings,
                channelsAsync.value ?? const [],
              ),
              loading: () => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: context.primaryColor),
                ),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Failed to load alert channels.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.healthRed,
                  ),
                ),
              ),
            ),

            // What the `promo` toggle above actually delivers today (G2).
            // Without this the category reads as abstract "marketing", and the
            // price watches are the only thing that currently uses it.
            _buildSectionHeader(context, 'Price watch'),
            _buildPriceWatchEntry(context),
          ],
        ),
      ),
    );
  }

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
          child: const Icon(Icons.trending_down_rounded,
              color: Color(0xFFF59E0B), size: 20),
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
        trailing: Icon(Icons.chevron_right_rounded,
            color: context.onSurfaceColor.withValues(alpha: 0.4)),
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
    dynamic prefs,
  ) {
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
          // Quiet Hours Toggle Row
          SwitchListTile(
            value: isQuietHoursActive,
            activeThumbColor: context.colorScheme.secondary,
            activeTrackColor: context.colorScheme.secondary.withValues(alpha: 0.2),
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
                  AppLocalizations.of(context)!.doNotDisturb,
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

          if (isQuietHoursActive) ...[
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

          // Weekly Digest Preference Row
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
                  color: isDark ? AppColors.primaryLight : context.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.weeklySummaryDigest,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: context.onSurfaceColor,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              AppLocalizations.of(context)!.weeklyDigestDesc,
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
          if (prefs.weeklyDigestEnabled &&
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
          ..._perCategoryChannels.map((channel) {
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

  Widget _buildAlertDeliveryChannels(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> channels,
    String? userId, {
    bool isNested = false,
  }) {
    final isDark = context.isDarkMode;
    if (channels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            AppLocalizations.of(context)!.noAlertChannelsConfigured,
            style: TextStyle(
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ),
      );
    }

    // Sort channels so they are displayed in a clean, consistent order
    // Order: push, email, whatsapp, telegram (webhook temporarily disabled)
    // final order = {'push': 1, 'email': 2, 'whatsapp': 3, 'telegram': 4, 'webhook': 5};
    final order = {'push': 1, 'email': 2, 'whatsapp': 3, 'telegram': 4};
    final sortedChannels = List<Map<String, dynamic>>.from(channels)
      ..sort((a, b) {
        final aOrder = order[a['channel_type']] ?? 99;
        final bOrder = order[b['channel_type']] ?? 99;
        return aOrder.compareTo(bOrder);
      });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedChannels.length,
      itemBuilder: (context, index) {
        final channel = sortedChannels[index];
        return ChannelConfigCard(
          channel: channel,
          userId: userId,
          isNested: isNested,
        );
      },
    );
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

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.channel['is_enabled'] ?? false;
    final config = widget.channel['config'] as Map<String, dynamic>? ?? {};
    final type = widget.channel['channel_type'] as String;
    String initialText = '';
    if (type == 'email') {
      final configEmail = ((config['email'] ?? config['email_address']) as String?)?.trim();
      final userEmail = ref.read(authControllerProvider).value?.email;
      initialText = (configEmail != null && configEmail.isNotEmpty)
          ? configEmail
          : (userEmail ?? '');
    } else if (type == 'whatsapp') {
      initialText = ((config['phone'] ?? config['phone_number']) as String?) ?? '';
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
        final configEmail = ((config['email'] ?? config['email_address']) as String?)?.trim();
        final userEmail = ref.read(authControllerProvider).value?.email;
        currentText = (configEmail != null && configEmail.isNotEmpty)
            ? configEmail
            : (userEmail ?? '');
      } else if (type == 'whatsapp') {
        currentText = ((config['phone'] ?? config['phone_number']) as String?) ?? '';
      } /* else if (type == 'webhook') {
        currentText = config['webhook_url'] ?? '';
      } */
      if (_textController.text != currentText) {
        _textController.text = currentText;
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    final type = widget.channel['channel_type'] as String;
    final currentConfig = Map<String, dynamic>.from(
      widget.channel['config'] ?? {},
    );

    if (type == 'email') {
      final emailVal = _textController.text.trim();
      currentConfig['email'] = emailVal;
      currentConfig['email_address'] = emailVal;
    } else if (type == 'whatsapp') {
      String val = _textController.text.trim();
      val = val.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (val.startsWith('00')) {
        val = '+${val.substring(2)}';
      }
      if (!val.startsWith('+') && val.isNotEmpty) {
        if (val.length <= 9) {
          final profile = ref.read(authControllerProvider).value;
          final homeCode = profile?.homeCountryCode;
          final countries = ref.read(supportedCountriesProvider).value ?? [];
          String homeDial = '+20';
          if (countries.isNotEmpty) {
            try {
              homeDial = countries
                  .firstWhere((c) => c.isoCode == homeCode)
                  .dialingCode;
            } catch (_) {}
          }
          if (val.startsWith('0')) {
            val = val.substring(1);
          }
          val = '$homeDial$val';
        } else {
          val = '+$val';
        }
      }
      _textController.text = val;
      currentConfig['phone'] = val;
      currentConfig['phone_number'] = val;
    } /* else if (type == 'webhook') {
      currentConfig['webhook_url'] = _textController.text.trim();
    } */

    final messenger = ScaffoldMessenger.of(context);
    final localizations = AppLocalizations.of(context);
    final channelName = _getChannelName(context, type);
    final secondaryColor = context.colorScheme.secondary;

    try {
      await ref
          .read(notificationChannelsControllerProvider.notifier)
          .updateChannelConfig(type, currentConfig);
      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              localizations?.channelSettingsUpdated(channelName) ??
                  'Settings updated for $channelName',
            ),
            backgroundColor: secondaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update settings: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _getChannelName(BuildContext context, String type) {
    switch (type) {
      case 'push':
        return AppLocalizations.of(context)!.pushNotifications;
      case 'email':
        return AppLocalizations.of(context)!.emailAlerts;
      case 'whatsapp':
        return AppLocalizations.of(context)!.whatsappAlerts;
      case 'telegram':
        return AppLocalizations.of(context)!.telegramBot;
      /* case 'webhook':
        return 'Emergency Webhooks'; */
      default:
        return type.toUpperCase();
    }
  }

  IconData _getChannelIcon(String type) {
    switch (type) {
      case 'push':
        return Icons.notifications_active_rounded;
      case 'email':
        return Icons.email_rounded;
      case 'whatsapp':
        return Icons.chat_bubble_outline_rounded;
      case 'telegram':
        return Icons.telegram_rounded;
      /* case 'webhook':
        return Icons.webhook_rounded; */
      default:
        return Icons.device_unknown_rounded;
    }
  }

  Color _getChannelColor(String type) {
    switch (type) {
      case 'push':
        return AppColors.primaryLight;
      case 'email':
        return const Color(0xFF38BDF8);
      case 'whatsapp':
        return const Color(0xFF4ADE80);
      case 'telegram':
        return const Color(0xFF22D3EE);
      /* case 'webhook':
        return const Color(0xFFC084FC); */
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.channel['channel_type'] as String;
    final config = widget.channel['config'] as Map<String, dynamic>? ?? {};
    final name = _getChannelName(context, type);
    final icon = _getChannelIcon(type);
    final color = _getChannelColor(type);

    final catalogMap = ref.watch(notificationChannelCatalogProvider).value ?? {};
    final catalogEntry = catalogMap[type];
    final bool isGloballyEnabled = catalogEntry != null ? (catalogEntry['is_globally_enabled'] == true) : true;

    final simLines = ref.watch(simLinesControllerProvider).value ?? [];
    final requiredTier = '${catalogEntry?['min_tier'] ?? ((type == 'push' || type == 'telegram') ? 'basic' : 'standard')}'.toLowerCase();
    final bool isPaidChannel = type == 'whatsapp' || type == 'email' || requiredTier != 'basic';

    int tierRank(String tier) => switch (tier.toLowerCase()) {
      'premium' => 2,
      'standard' => 1,
      _ => 0,
    };
    final eligibleLines = simLines.where((line) {
      final canonicalTier = line.planType.trim().isNotEmpty
          ? line.planType.trim().toLowerCase()
          : (line.protectionTier.trim().isNotEmpty
              ? line.protectionTier.trim().toLowerCase()
              : 'basic');
      final isExpired = line.planExpiresAt != null &&
          line.planExpiresAt!.isBefore(DateTime.now());
      return tierRank(canonicalTier) >= tierRank(requiredTier) && !isExpired;
    }).toList();
    final bool hasEligibleLine = eligibleLines.isNotEmpty;
    final isDark = context.isDarkMode;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: widget.isNested ? 12 : 16,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Switch
          SwitchListTile(
            value: _isEnabled,
            activeThumbColor: color,
            activeTrackColor: color.withValues(alpha: 0.2),
            inactiveThumbColor: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
            inactiveTrackColor: isDark
                ? AppColors.darkBorder
                : AppColors.lightBorder,
            title: Row(
              children: [
                Icon(
                  icon,
                  color: !isGloballyEnabled ? AppColors.textTertiaryDark : color,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: !isGloballyEnabled
                          ? (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight)
                          : context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isGloballyEnabled) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'Temporarily unavailable',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
                if (isPaidChannel) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Standard & Premium',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                _buildAvailabilityBadge(type, _isEnabled, config),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !isGloballyEnabled
                        ? 'This channel is currently paused by platform administrators. Your preference will be saved and respected once resumed.'
                        : _getChannelDescription(context, type),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  if (isPaidChannel) ...[
                    const SizedBox(height: 4),
                    Text(
                      hasEligibleLine
                          ? 'Available for your eligible Standard & Premium SIM lines when enabled.'
                          : 'You can enable this now. Alerts are sent only for SIMs with an active Standard or Premium subscription.',
                      style: AppTextStyles.caption.copyWith(
                        color: hasEligibleLine
                            ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
                            : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            onChanged: (val) async {
              final messenger = ScaffoldMessenger.of(context);
              await HapticHelper.mediumImpact();
              final previousVal = _isEnabled;
              setState(() => _isEnabled = val);
              if (type == 'email' && val) {
                final currentText = _textController.text.trim();
                if (currentText.isEmpty) {
                  final userEmail = ref.read(authControllerProvider).value?.email;
                  if (userEmail != null && userEmail.isNotEmpty) {
                    _textController.text = userEmail;
                  }
                }
              }
              try {
                await ref
                    .read(notificationChannelsControllerProvider.notifier)
                    .toggleChannel(type, val);
              } catch (e) {
                if (mounted) {
                  setState(() => _isEnabled = previousVal);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to update $name: $e'),
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
          ),

          if (_isEnabled) ...[
            Divider(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              height: 1,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (type == 'push') ...[
                    _buildPushContent(context),
                  ] else if (type == 'telegram') ...[
                    _buildTelegramContent(context, config),
                  ] else ...[
                    _buildTextField(context, type),
                    const SizedBox(height: 12),
                    _buildSaveButton(context),
                  ],
                  if (type == 'email') ...[
                    const SizedBox(height: 10),
                    _buildInfoBadge(
                      AppLocalizations.of(context)!.emailFreePlanGuarded,
                      const Color(0xFF38BDF8),
                    ),
                  ] else if (type == 'whatsapp') ...[
                    const SizedBox(height: 10),
                    _buildInfoBadge(
                      'WhatsApp alerts are dispatched for active Standard and Premium SIM lines through the verified country route.',
                      const Color(0xFF4ADE80),
                    ),
                  ],
                  if (isPaidChannel && !hasEligibleLine) ...[
                    const SizedBox(height: 10),
                    _buildInfoBadge(
                      'Preference saved: Delivery will activate automatically when you upgrade any of your SIM lines to Standard or Premium.',
                      Colors.amber,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPushContent(BuildContext context) {
    final isDark = context.isDarkMode;
    final playerId = OneSignal.User.pushSubscription.id;
    final isOptedIn = OneSignal.User.pushSubscription.optedIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (playerId != null)
                ? Colors.green.withValues(alpha: isDark ? 0.15 : 0.08)
                : Colors.amber.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (playerId != null)
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.amber.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                playerId != null ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 16,
                color: playerId != null ? Colors.green : Colors.amber,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  playerId != null
                      ? ((isOptedIn ?? false) ? 'Device Subscribed & Active' : 'Push Permission Pending')
                      : 'Connecting to push service...',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: playerId != null ? Colors.green : Colors.amber,
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
            onPressed: (_isSendingTestPush || playerId == null)
                ? null
                : () async {
                    await HapticHelper.lightTick();
                    setState(() => _isSendingTestPush = true);
                    try {
                      await ref.read(notificationsRepositoryProvider).sendNotification(
                        category: 'system',
                        title: 'KeepSIMs Test Alert',
                        body: 'KeepSIMs requested a test notification for this device.',
                        channelType: 'push',
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Test alert queued. Check your enabled routes and device permissions for arrival.'),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green.shade700,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              _isSendingTestPush ? 'Sending Test Alert...' : 'Send Test Notification',
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
            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityBadge(
    String type,
    bool isEnabled,
    Map<String, dynamic> config,
  ) {
    if (!isEnabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Off',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      );
    }

    bool needsSetup = false;
    if (type == 'email') {
      final email = (config['email'] as String?)?.trim();
      final userEmail = ref.read(authControllerProvider).value?.email;
      final effectiveEmail = (email != null && email.isNotEmpty) ? email : userEmail;
      needsSetup = effectiveEmail == null || effectiveEmail.trim().isEmpty;
    } else if (type == 'whatsapp') {
      final phone = (config['phone'] ?? config['phone_number']) as String?;
      needsSetup = phone == null || phone.trim().isEmpty;
    } else if (type == 'telegram') {
      final chatId = config['chat_id'] as String?;
      needsSetup = chatId == null || chatId.trim().isEmpty || config['binding_verified_at'] == null;
    }

    if (needsSetup) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'Setup required',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Enabled',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.success,
        ),
      ),
    );
  }

  String _getChannelDescription(BuildContext context, String type) {
    switch (type) {
      case 'push':
        return AppLocalizations.of(context)!.pushNotificationsDesc;
      case 'email':
        return AppLocalizations.of(context)!.emailAlertsDesc;
      case 'whatsapp':
        return AppLocalizations.of(context)!.whatsappAlertsDesc;
      case 'telegram':
        return AppLocalizations.of(context)!.telegramBotDesc;
      /* case 'webhook':
        return 'Post JSON alerts to custom REST API endpoints.'; */
      default:
        return 'Alert delivery route configuration.';
    }
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
          keyboardType: keyboardType,
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.onSurfaceColor,
          ),
          decoration: InputDecoration(
            hintText: hint,
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
              'Connected to your account email by default. You can change it above to receive alerts at a different address.',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 11,
              ),
            ),
          ),
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
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveConfig,
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
                AppLocalizations.of(context)!.saveSettings,
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
    final isBound = chatId != null && chatId.toString().isNotEmpty && config['binding_verified_at'] != null;
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
              onPressed: () async {
                await HapticHelper.lightTick();
                final userId = widget.userId;
                if (userId == null) return;
                try {
                  final result = await Supabase.instance.client.rpc('create_telegram_bind_token');
                  final token = result is Map ? result['token'] : null;
                  if (result is! Map || result['success'] != true ||
                      token is! String || !RegExp(r'^[0-9a-f]{32}$').hasMatch(token)) {
                    throw StateError('Could not create a secure Telegram link');
                  }
                  final uri = Uri.parse('https://t.me/KeepSIMsBot?start=bind_$token');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    throw StateError('Could not open Telegram');
                  }
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Telegram link unavailable: $error')),
                  );
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
                backgroundColor: const Color(0xFF22D3EE),
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
                color: AppColors.textSecondaryDark,
                height: 1.3,
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
