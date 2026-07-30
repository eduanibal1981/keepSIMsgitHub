/// SIM Shield — "Your devices" (G10)
///
/// Feature suggestion #10 in doc/PRODUCTION_PLAN_REVIEW.md § 6.
///
/// Deliberately plain. It shows what the server knows about this account's app
/// installs and gives one action: sign a device out. It shows no risk score, no
/// velocity counter and no hint of which other accounts share a handset —
/// telling a user how close they are to a fraud threshold is telling an
/// attacker the same thing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/settings/presentation/controllers/devices_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

Color _secondaryText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.textSecondaryDark
    : AppColors.textSecondaryLight;

Color _primaryText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.textPrimaryDark
    : AppColors.textPrimaryLight;

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final devices = ref.watch(devicesControllerProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l.yourDevices),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(text: l.devicesLoadFailed),
        data: (list) {
          if (list.isEmpty) return _Message(text: l.devicesEmpty);
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(devicesControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: list.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l.devicesExplainer,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: _secondaryText(context),
                      ),
                    ),
                  );
                }
                return _DeviceTile(device: list[i - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(color: _secondaryText(context)),
      ),
    ),
  );
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.device});
  final RegisteredDevice device;

  IconData get _icon => switch (device.platform) {
    'android' => Icons.phone_android_rounded,
    'ios' => Icons.phone_iphone_rounded,
    'web' => Icons.language_rounded,
    _ => Icons.devices_other_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = device.label?.trim().isNotEmpty == true
        ? device.label!
        : (device.platform ?? l.devicesUnknownPlatform);

    return Opacity(
      opacity: device.isRevoked ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: device.isBlocked
                ? const Color(0xFFEF4444)
                : (isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: _secondaryText(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _primaryText(context),
                          ),
                        ),
                      ),
                      if (device.isCurrent) ...[
                        const SizedBox(width: 8),
                        _Chip(text: l.devicesThisDevice, isInfo: true),
                      ],
                      if (device.isRevoked) ...[
                        const SizedBox(width: 8),
                        _Chip(text: l.devicesSignedOut, isInfo: false),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.devicesMetaLine(
                      device.shortId,
                      device.appVersion ?? '—',
                      _relative(context, device.lastSeenAt),
                    ),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _secondaryText(context),
                    ),
                  ),
                ],
              ),
            ),
            if (!device.isRevoked && !device.isCurrent)
              TextButton(
                onPressed: () => _confirmRevoke(context, ref),
                child: Text(l.devicesSignOut),
              ),
          ],
        ),
      ),
    );
  }

  String _relative(BuildContext context, DateTime when) {
    final l = AppLocalizations.of(context)!;
    final d = DateTime.now().difference(when);
    if (d.inMinutes < 60) return l.devicesJustNow;
    if (d.inHours < 24) return l.devicesHoursAgo(d.inHours);
    return l.devicesDaysAgo(d.inDays);
  }

  Future<void> _confirmRevoke(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    HapticHelper.lightTick();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.devicesSignOutTitle),
        content: Text(l.devicesSignOutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.devicesSignOut),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(devicesControllerProvider.notifier).revoke(device.deviceId);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.isInfo});
  final String text;
  final bool isInfo;

  @override
  Widget build(BuildContext context) {
    final color = isInfo ? AppColors.primary : _secondaryText(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
