import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/services/destructive_action_guard.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/widgets/glass_card.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/manual_refill_bottom_sheet.dart';
import 'package:keep_sims/features/sim_lines/domain/sim_line_health.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

import '../../../sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart';

class DashboardSimLineCard extends ConsumerWidget {
  final SimLine line;
  final int lineNumber;

  const DashboardSimLineCard({
    super.key,
    required this.line,
    required this.lineNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = line.nickname?.trim();
    final isDefaultName =
        nickname == null ||
        nickname.isEmpty ||
        nickname.toLowerCase() == 'sim line' ||
        nickname == AppLocalizations.of(context)!.simLine;
    final displayName = isDefaultName ? 'SIM $lineNumber' : nickname;
    final accent = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primary
        : const Color(0xFF009FB5);
    final notifySchedule = ref.watch(scheduledNotifyForLineProvider(line.id));
    final miniSchedule = ref.watch(scheduledMiniRefillForLineProvider(line.id));
    final customSchedule = ref.watch(
      scheduledCustomRefillForLineProvider(line.id),
    );
    final refillSchedule = customSchedule ?? miniSchedule;
    final isLight = Theme.of(context).brightness == Brightness.light;

    final bool isNotifyActive =
        notifySchedule != null &&
        notifySchedule.status == 'active' &&
        notifySchedule.isActive;
    final bool isRefillActive =
        (miniSchedule != null && miniSchedule.status == 'active') ||
        (customSchedule != null && customSchedule.status == 'active');
    final bool isPremium = line.protectionTier.toLowerCase() == 'premium';
    final bool hasProtectionActive = isPremium
        ? isRefillActive
        : isNotifyActive;
    final bool isRealLiveVerified =
        ref.watch(hasRealLiveVerificationProvider(line.id)).value ?? false;
    final carrierRule = line.carrierId != null
        ? ref.watch(carrierRuleProvider(line.carrierId!)).value
        : null;

    final int computedHealthScore = line.displayHealthScore(
      isRealLiveVerified: isRealLiveVerified,
      hasNotificationSchedule: isNotifyActive,
      carrierExpirationDays: carrierRule?.inactivityLimitDays,
    );

    Color glowColor = AppColors.healthGreen;
    if (line.protectionPaused) {
      glowColor = Colors.lightBlue;
    } else if (computedHealthScore < 30) {
      glowColor = AppColors.healthRed;
    } else if (computedHealthScore < 60) {
      glowColor = AppColors.healthAmber;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = DashboardSimCardLayout.of(
          context,
          constraints.maxWidth,
          line,
        );

        final menu = Theme(
          data: Theme.of(context).copyWith(
            popupMenuTheme: PopupMenuThemeData(
              color: isLight ? AppColors.lightCard : AppColors.darkCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isLight ? AppColors.lightBorder : AppColors.darkBorder,
                ),
              ),
            ),
          ),
          child: SizedBox(
            height: 44,
            width: 44,
            child: PopupMenuButton<String>(
              key: ValueKey('sim-menu-${line.id}'),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_horiz_rounded,
                color: isLight
                    ? AppColors.textSecondaryLight
                    : AppColors.textSecondaryDark,
                size: 20,
              ),
              onSelected: (value) async {
                if (value == 'config') {
                  context.push('/sim-lines/detail/${line.id}');
                } else if (value == 'upgrade') {
                  await HapticHelper.mediumImpact();
                  if (context.mounted) {
                    LineUpgradeSheet.show(context: context, simLine: line);
                  }
                } else if (value == 'delete') {
                  final bool confirm =
                      await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: isLight
                                ? AppColors.lightCard
                                : AppColors.darkCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isLight
                                    ? AppColors.lightBorder
                                    : AppColors.darkBorder,
                              ),
                            ),
                            title: Text(
                              'Delete SIM Line?',
                              style: AppTextStyles.titleLarge.copyWith(
                                color: isLight
                                    ? AppColors.textPrimaryLight
                                    : Colors.white,
                              ),
                            ),
                            content: Text(
                              'Are you sure you want to delete ${line.nickname ?? line.phoneNumber}? This action cannot be undone.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isLight
                                    ? AppColors.textSecondaryLight
                                    : AppColors.textSecondaryDark,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text(
                                  'Cancel',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: isLight
                                        ? AppColors.lightPrimary
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(
                                  'Delete',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: AppColors.healthRed,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ) ??
                      false;

                  if (!confirm) return;
                  if (!context.mounted) return;

                  // Deleting a line is irreversible, so it is gated on
                  // the owner being present. No grace window: this
                  // prompts every time.
                  final verified = await ref
                      .read(destructiveActionGuardProvider)
                      .confirmDestructiveAction(
                        context,
                        reason:
                            'Authenticate to delete ${line.nickname ?? line.phoneNumber}',
                        confirmationToken: destructiveConfirmationToken(
                          line.phoneNumber,
                        ),
                      );
                  if (!verified) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.deletionNotVerified,
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                    return;
                  }

                  await ref
                      .read(simLinesControllerProvider.notifier)
                      .deleteSimLine(line.id);
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'config',
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        color: isLight
                            ? AppColors.textPrimaryLight
                            : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Configuration',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isLight
                              ? AppColors.textPrimaryLight
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (line.planType != 'premium')
                  PopupMenuItem(
                    key: ValueKey('sim-upgrade-${line.id}'),
                    value: 'upgrade',
                    child: Text(AppLocalizations.of(context)!.upgrade),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        color: AppColors.healthRed,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Delete',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.healthRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        final badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isLight ? const Color(0xFFEDF6FF) : const Color(0xFF193745),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            DashboardSimCardLayout.planLabel(context, line),
            style: DashboardSimCardLayout.badgeStyle.copyWith(
              color: isLight ? const Color(0xFF009BC0) : AppColors.primaryLight,
            ),
          ),
        );
        final status = Tooltip(
          excludeFromSemantics: true,
          message: hasProtectionActive
              ? (Localizations.localeOf(context).languageCode == 'ar'
                    ? 'الحماية نشطة'
                    : 'Protection active')
              : (Localizations.localeOf(context).languageCode == 'ar'
                    ? 'الحماية غير نشطة'
                    : 'Protection inactive'),
          child: Semantics(
            label: hasProtectionActive
                ? (Localizations.localeOf(context).languageCode == 'ar'
                      ? 'الحماية نشطة'
                      : 'Protection active')
                : (Localizations.localeOf(context).languageCode == 'ar'
                      ? 'الحماية غير نشطة'
                      : 'Protection inactive'),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasProtectionActive
                    ? AppColors.success
                    : AppColors.healthRed,
                boxShadow: [
                  BoxShadow(
                    color:
                        (hasProtectionActive
                                ? AppColors.success
                                : AppColors.healthRed)
                            .withValues(alpha: .5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
        final name = Tooltip(
          message: displayName,
          child: Text(
            displayName,
            style: AppTextStyles.titleMedium.copyWith(
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
        final phone = Text(
          line.phoneNumber,
          textDirection: TextDirection.ltr,
          style: DashboardSimCardLayout.phoneStyle.copyWith(color: accent),
        );
        final header = SizedBox(
          height: layout.headerHeight,
          child: layout.stackHeader
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: layout.nameHeight,
                      child: Row(
                        children: [
                          status,
                          const SizedBox(width: 8),
                          Expanded(child: name),
                          menu,
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    phone,
                    const SizedBox(height: 6),
                    badge,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              status,
                              const SizedBox(width: 8),
                              Expanded(child: name),
                            ],
                          ),
                          const SizedBox(height: 4),
                          phone,
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    badge,
                    const SizedBox(width: 8),
                    menu,
                  ],
                ),
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            await HapticHelper.lightTick();
            if (context.mounted) context.push('/sim-lines/detail/${line.id}');
          },
          child: GlassCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            isActive: false,
            activeColor: glowColor,
            customBorder: Border.all(
              color: isLight ? const Color(0xFFE4EAF0) : AppColors.darkBorder,
            ),
            customGradient: LinearGradient(
              colors: isLight
                  ? [Colors.white, Colors.white]
                  : [const Color(0xFF17212C), const Color(0xFF17212C)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 8),
                Divider(
                  color: isLight ? AppColors.lightBorder : AppColors.darkBorder,
                  thickness: 1,
                  height: 1,
                ),
                const SizedBox(height: 8),
                _automationRow(
                  context,
                  layout,
                  AppLocalizations.of(context)!.autoNotify,
                  notifySchedule != null
                      ? _toggle(
                          value: isNotifyActive,
                          activeColor: accent,
                          onChanged: (val) async {
                            await HapticHelper.lightTick();
                            await ref
                                .read(scheduledTopupControllerProvider.notifier)
                                .toggleActive(notifySchedule.id, val);
                          },
                        )
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            await HapticHelper.lightTick();
                            if (context.mounted) {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => ScheduledTopupSheet(
                                  simLineId: line.id,
                                  simNickname:
                                      line.nickname ?? line.phoneNumber,
                                  simLine: line,
                                  existingSchedule: notifySchedule,
                                  configMode: 'notify',
                                ),
                              );
                            }
                          },
                          child: _hitArea(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color:
                                      (isLight
                                              ? AppColors.lightPrimary
                                              : AppColors.primary)
                                          .withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.dashboardSetUp,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                _automationRow(
                  context,
                  layout,
                  AppLocalizations.of(context)!.autoRefill,
                  Opacity(
                    opacity: 1.0,
                    child: refillSchedule != null
                        ? _toggle(
                            value: isPremium ? isRefillActive : false,
                            activeColor: accent,
                            onChanged: (val) async {
                              await HapticHelper.lightTick();
                              if (!context.mounted) return;
                              if (!isPremium) {
                                LineUpgradeSheet.show(
                                  context: context,
                                  simLine: line,
                                );
                                return;
                              }
                              await ref
                                  .read(
                                    scheduledTopupControllerProvider.notifier,
                                  )
                                  .toggleActive(refillSchedule.id, val);
                            },
                          )
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              await HapticHelper.lightTick();
                              if (!context.mounted) return;
                              if (!isPremium) {
                                LineUpgradeSheet.show(
                                  context: context,
                                  simLine: line,
                                );
                                return;
                              }
                              if (context.mounted) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => ScheduledTopupSheet(
                                    simLineId: line.id,
                                    simNickname:
                                        line.nickname ?? line.phoneNumber,
                                    simLine: line,
                                    existingSchedule: refillSchedule,
                                    configMode: 'refill',
                                  ),
                                );
                              }
                            },
                            child: _hitArea(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isLight
                                              ? AppColors.lightPrimary
                                              : AppColors.primary)
                                          .withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.dashboardSetUp,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    await HapticHelper.lightTick();
                    if (!context.mounted) return;
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ManualRefillBottomSheet(simLine: line),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    key: ValueKey('sim-recharge-${line.id}'),
                    constraints: BoxConstraints(
                      minHeight: layout.rechargeHeight,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .015),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: .55)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_rounded, color: accent, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            AppLocalizations.of(context)!.dashboardRecharge,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: accent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _automationRow(
    BuildContext context,
    DashboardSimCardLayout layout,
    String label,
    Widget action,
  ) {
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).brightness == Brightness.light
                  ? AppColors.textPrimaryLight
                  : Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
    return SizedBox(
      height: layout.controlHeight,
      child: layout.stackControls
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 4),
                Align(alignment: AlignmentDirectional.centerEnd, child: action),
              ],
            )
          : Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 8),
                action,
              ],
            ),
    );
  }

  static Widget _hitArea(Widget child) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    child: Center(widthFactor: 1, heightFactor: 1, child: child),
  );

  static Widget _toggle({
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) => DashboardSimToggle(
    value: value,
    onChanged: onChanged,
    activeColor: activeColor,
  );
}

/// Measures the same text and hit regions used by the card. The carousel uses
/// the tallest page so swiping never clips a different tier or schedule state.
class DashboardSimCardLayout {
  final bool stackHeader;
  final bool stackControls;
  final double headerHeight;
  final double nameHeight;
  final double actionsHeight;
  final double controlHeight;
  final double rechargeHeight;

  const DashboardSimCardLayout({
    required this.stackHeader,
    required this.stackControls,
    required this.headerHeight,
    required this.nameHeight,
    required this.actionsHeight,
    required this.controlHeight,
    required this.rechargeHeight,
  });

  static TextStyle get phoneStyle => AppTextStyles.titleMedium.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );

  static TextStyle get badgeStyle => AppTextStyles.caption.copyWith(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
  );
  static String planLabel(BuildContext context, SimLine line) {
    final l10n = AppLocalizations.of(context)!;
    return switch (line.planType.toLowerCase()) {
      'standard' => l10n.dashboardStandard,
      'premium' => l10n.dashboardPremium,
      _ =>
        line.planType.isEmpty
            ? ''
            : line.planType[0].toUpperCase() + line.planType.substring(1),
    };
  }

  double get height =>
      26 + headerHeight + 17 + 2 * controlHeight + 8 + rechargeHeight;

  factory DashboardSimCardLayout.of(
    BuildContext context,
    double width,
    SimLine line,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final inner = math.max(1.0, width - 34);
    Size measure(
      String text,
      TextStyle style, {
      double maxWidth = double.infinity,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.localeOf(context),
      )..layout(maxWidth: maxWidth);
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final badge = measure(planLabel(context, line), badgeStyle);
    final phone = measure(line.phoneNumber, phoneStyle);
    final trailing = badge.width + 20 + 16 + 44;
    final stackHeader = inner - trailing < math.max(phone.width, 8 + 8 + 24);
    final name = measure(
      'Mgأ',
      AppTextStyles.titleMedium.copyWith(
        fontSize: 18,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
    );
    final nameHeight = math.max(44.0, name.height);
    final actionsHeight = badge.height + 8;
    final headerHeight = stackHeader
        ? nameHeight +
              4 +
              measure(line.phoneNumber, phoneStyle, maxWidth: inner).height +
              6 +
              actionsHeight
        : math.max(
            44.0,
            math.max(actionsHeight, name.height + 4 + phone.height),
          );
    final configure = measure(
      l10n.dashboardSetUp,
      AppTextStyles.labelSmall.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
    final actionWidth = math.max(48.0, configure.width + 26);
    final actionHeight = math.max(44.0, configure.height + 18);
    final labelStyle = AppTextStyles.bodyMedium.copyWith(
      fontWeight: FontWeight.w500,
    );
    final labelWidth = math.max(
      measure(l10n.autoNotify, labelStyle).width,
      measure(l10n.autoRefill, labelStyle).width,
    );
    final stackControls = labelWidth + 8 + actionWidth > inner;
    final labelHeight = math.max(
      measure(
        l10n.autoNotify,
        labelStyle,
        maxWidth: stackControls ? inner : inner - actionWidth - 8,
      ).height,
      measure(
        l10n.autoRefill,
        labelStyle,
        maxWidth: stackControls ? inner : inner - actionWidth - 8,
      ).height,
    );
    final rechargeHeight = math.max(
      44.0,
      measure(
            l10n.dashboardRecharge,
            AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            maxWidth: math.max(1, inner - 22),
          ).height +
          22,
    );
    return DashboardSimCardLayout(
      stackHeader: stackHeader,
      stackControls: stackControls,
      headerHeight: headerHeight.ceilToDouble(),
      nameHeight: nameHeight.ceilToDouble(),
      actionsHeight: actionsHeight.ceilToDouble(),
      controlHeight:
          (stackControls
                  ? labelHeight + 4 + actionHeight
                  : math.max(actionHeight, labelHeight))
              .ceilToDouble(),
      rechargeHeight: rechargeHeight.ceilToDouble(),
    );
  }
}

/// Dashboard-only switch appearance; the shared glass switch is unchanged.
class DashboardSimToggle extends StatelessWidget {
  const DashboardSimToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: 48,
        height: 44,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 24,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: value
                  ? activeColor
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
