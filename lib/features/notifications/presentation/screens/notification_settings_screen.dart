import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/notifications/data/models/alert_setting_model.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:url_launcher/url_launcher.dart';

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
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertSettingsAsync = ref.watch(alertSettingsControllerProvider);
    final userPrefsAsync = ref.watch(userPreferencesControllerProvider);
    final channelsAsync = ref.watch(notificationChannelsControllerProvider);
    final userAsync = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimaryDark,
          ),
          onPressed: () async {
            await HapticHelper.lightTick();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Alert Settings',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimaryDark,
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
            _buildSectionHeader('Quiet Hours & Schedule'),
            userPrefsAsync.when(
              data: (prefs) => _buildQuietHoursCard(context, ref, prefs),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Alert Delivery Channels
            _buildSectionHeader('Alert Delivery Channels'),
            channelsAsync.when(
              data: (channels) => _buildAlertDeliveryChannels(context, ref, channels, userAsync.valueOrNull?.id),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Incident Channels (Alert settings per category)
            _buildSectionHeader('Incident Channels'),
            alertSettingsAsync.when(
              data: (settings) => _buildIncidentChannels(ref, settings),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textTertiaryDark,
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          // Quiet Hours Toggle Row
          SwitchListTile(
            value: isQuietHoursActive,
            activeThumbColor: AppColors.secondary,
            activeTrackColor: AppColors.secondary.withValues(alpha: 0.2),
            inactiveThumbColor: AppColors.textTertiaryDark,
            inactiveTrackColor: AppColors.darkBorder,
            title: Row(
              children: [
                const Icon(
                  Icons.nights_stay_rounded,
                  color: AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Do Not Disturb (Quiet Hours)',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Mute push notifications during specified sleep hours.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryDark,
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
            const Divider(color: AppColors.darkBorder, height: 1),
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

          const Divider(color: AppColors.darkBorder, height: 1),

          // Weekly Digest Preference Row
          SwitchListTile(
            value: prefs.weeklyDigestEnabled,
            activeThumbColor: AppColors.primaryLight,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.2),
            inactiveThumbColor: AppColors.textTertiaryDark,
            inactiveTrackColor: AppColors.darkBorder,
            title: Row(
              children: [
                const Icon(
                  Icons.summarize_rounded,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Weekly Summary Digest',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Compiled status report of all SIM cards every Sunday at 9:00 AM.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
            onChanged: (active) async {
              await HapticHelper.mediumImpact();
              ref
                  .read(userPreferencesControllerProvider.notifier)
                  .toggleWeeklyDigest(active);
            },
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
    return InkWell(
      onTap: () async {
        await HapticHelper.lightTick();
        final currentTod = _parseTimeOfDay(timeStr);
        final selectedTime = await showTimePicker(
          context: context,
          initialTime: currentTod,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: AppColors.darkSurface,
                  onSurface: AppColors.textPrimaryDark,
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
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiaryDark,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDisplayTime(timeStr),
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppColors.textSecondaryDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentChannels(WidgetRef ref, List<AlertSetting> settings) {
    if (settings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No channels initialized.',
            style: TextStyle(color: AppColors.textTertiaryDark),
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
        final metadata =
            _meta[item.category] ??
            _CategoryMeta(
              name: item.category,
              description: 'General notification alerts.',
              icon: Icons.notifications_rounded,
              color: AppColors.primary,
            );

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isEnabled
                  ? AppColors.darkBorder
                  : AppColors.darkBorder.withValues(alpha: 0.5),
            ),
          ),
          child: SwitchListTile(
            value: item.isEnabled,
            activeThumbColor: metadata.color,
            activeTrackColor: metadata.color.withValues(alpha: 0.2),
            inactiveThumbColor: AppColors.textTertiaryDark,
            inactiveTrackColor: AppColors.darkBorder,
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: item.isEnabled
                        ? metadata.color.withValues(alpha: 0.1)
                        : AppColors.darkBorder,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    metadata.icon,
                    color: item.isEnabled
                        ? metadata.color
                        : AppColors.textTertiaryDark,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    metadata.name,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: item.isEnabled
                          ? AppColors.textPrimaryDark
                          : AppColors.textSecondaryDark,
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
                  color: AppColors.textSecondaryDark,
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
        );
      },
    );
  }

  // --- TimeOfDay Parsers ---
  TimeOfDay _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty)
      return const TimeOfDay(hour: 22, minute: 0);
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
    String? userId,
  ) {
    if (channels.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No alert delivery channels configured.',
            style: TextStyle(color: AppColors.textTertiaryDark),
          ),
        ),
      );
    }

    // Sort channels so they are displayed in a clean, consistent order
    // Order: push, email, whatsapp, telegram, webhook
    final order = {'push': 1, 'email': 2, 'whatsapp': 3, 'telegram': 4, 'webhook': 5};
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

  const ChannelConfigCard({
    super.key,
    required this.channel,
    required this.userId,
  });

  @override
  ConsumerState<ChannelConfigCard> createState() => _ChannelConfigCardState();
}

class _ChannelConfigCardState extends ConsumerState<ChannelConfigCard> {
  late TextEditingController _textController;
  late bool _isEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.channel['is_enabled'] ?? false;
    final config = widget.channel['config'] as Map<String, dynamic>? ?? {};
    final type = widget.channel['channel_type'] as String;
    String initialText = '';
    if (type == 'email') {
      initialText = config['email'] ?? '';
    } else if (type == 'whatsapp') {
      initialText = config['phone'] ?? '';
    } else if (type == 'webhook') {
      initialText = config['webhook_url'] ?? '';
    }
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
        currentText = config['email'] ?? '';
      } else if (type == 'whatsapp') {
        currentText = config['phone'] ?? '';
      } else if (type == 'webhook') {
        currentText = config['webhook_url'] ?? '';
      }
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
    final currentConfig = Map<String, dynamic>.from(widget.channel['config'] ?? {});
    
    if (type == 'email') {
      currentConfig['email'] = _textController.text.trim();
    } else if (type == 'whatsapp') {
      currentConfig['phone'] = _textController.text.trim();
    } else if (type == 'webhook') {
      currentConfig['webhook_url'] = _textController.text.trim();
    }

    await ref.read(notificationChannelsControllerProvider.notifier).updateChannelConfig(type, currentConfig);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getChannelName(type)} settings updated.'),
          backgroundColor: AppColors.secondary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getChannelName(String type) {
    switch (type) {
      case 'push':
        return 'Push Notifications';
      case 'email':
        return 'Email Alerts';
      case 'whatsapp':
        return 'WhatsApp Alerts';
      case 'telegram':
        return 'Telegram Bot';
      case 'webhook':
        return 'Emergency Webhooks';
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
      case 'webhook':
        return Icons.webhook_rounded;
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
      case 'webhook':
        return const Color(0xFFC084FC); 
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.channel['channel_type'] as String;
    final config = widget.channel['config'] as Map<String, dynamic>? ?? {};
    final name = _getChannelName(type);
    final icon = _getChannelIcon(type);
    final color = _getChannelColor(type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Switch
          SwitchListTile(
            value: _isEnabled,
            activeThumbColor: color,
            activeTrackColor: color.withOpacity(0.2),
            inactiveThumbColor: AppColors.textTertiaryDark,
            inactiveTrackColor: AppColors.darkBorder,
            title: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Text(
                  name,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _getChannelDescription(type),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ),
            onChanged: (val) async {
              await HapticHelper.mediumImpact();
              setState(() => _isEnabled = val);
              await ref.read(notificationChannelsControllerProvider.notifier).toggleChannel(type, val);
            },
          ),
          
          if (_isEnabled && type != 'push') ...[
            const Divider(color: AppColors.darkBorder, height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (type == 'telegram') ...[
                    _buildTelegramContent(config)
                  ] else ...[
                    _buildTextField(type),
                    const SizedBox(height: 12),
                    _buildSaveButton(),
                  ],
                  if (type == 'email') ...[
                    const SizedBox(height: 10),
                    _buildInfoBadge(
                      "Resend Free Plan Guarded: Capped to deactivation triggers only. No promotional spam.",
                      const Color(0xFF38BDF8),
                    ),
                  ] else if (type == 'whatsapp') ...[
                    const SizedBox(height: 10),
                    _buildInfoBadge(
                      "Direct Meta Cloud Capped: Maximum 1 message per top-up schedule, sent ONLY if auto-refill is not active or fails.",
                      const Color(0xFF4ADE80),
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

  String _getChannelDescription(String type) {
    switch (type) {
      case 'push':
        return 'Aggressive native notifications on this device.';
      case 'email':
        return 'Critical deactivation alerts sent via Resend.';
      case 'whatsapp':
        return 'Refill failure alerts pushed directly to WhatsApp.';
      case 'telegram':
        return 'Bound interactive Telegram bot chat notifications.';
      case 'webhook':
        return 'Post JSON alerts to custom REST API endpoints.';
      default:
        return 'Alert delivery route configuration.';
    }
  }

  Widget _buildTextField(String type) {
    String label = '';
    String hint = '';
    IconData prefixIcon = Icons.edit;
    TextInputType keyboardType = TextInputType.text;

    if (type == 'email') {
      label = 'Notification Email Address';
      hint = 'e.g. user@domain.com';
      prefixIcon = Icons.alternate_email_rounded;
      keyboardType = TextInputType.emailAddress;
    } else if (type == 'whatsapp') {
      label = 'WhatsApp Number (Int\'l Format)';
      hint = 'e.g. +96891234567';
      prefixIcon = Icons.phone_rounded;
      keyboardType = TextInputType.phone;
    } else if (type == 'webhook') {
      label = 'Emergency Endpoint Webhook URL';
      hint = 'e.g. https://api.domain.com/alert';
      prefixIcon = Icons.link_rounded;
      keyboardType = TextInputType.url;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _textController,
          keyboardType: keyboardType,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimaryDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiaryDark),
            prefixIcon: Icon(prefixIcon, color: AppColors.textSecondaryDark, size: 18),
            filled: true,
            fillColor: AppColors.darkCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.darkBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveConfig,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                'Save Settings',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildTelegramContent(Map<String, dynamic> config) {
    final chatId = config['chat_id'];
    final isBound = chatId != null && chatId.toString().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBound ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                color: isBound ? AppColors.success : AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isBound ? 'Status: Bound (Chat ID: $chatId)' : 'Status: Unbound',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isBound ? AppColors.success : AppColors.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'To receive free, interactive Telegram alerts, link our Telegram Bot with your account.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await HapticHelper.lightTick();
                final userId = widget.userId;
                if (userId == null) return;
                final botUrl = 'https://t.me/KeepSimsShieldBot?start=bind_$userId';
                final uri = Uri.parse(botUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.telegram, color: Colors.white, size: 20),
              label: const Text(
                'Link Telegram Bot',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
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
