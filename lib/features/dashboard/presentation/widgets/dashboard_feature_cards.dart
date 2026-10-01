import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

/// Compact service shortcuts; the entire card is the tap target.
class DashboardFeatureCards extends StatelessWidget {
  const DashboardFeatureCards({
    super.key,
    required this.onSmartCall,
    required this.onEsims,
  });

  final VoidCallback onSmartCall;
  final VoidCallback onEsims;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _FeatureCard(
              title: l10n.smartCall,
              subtitle: l10n.dashboardExploreSmartCall,
              icon: Icons.call_rounded,
              accent: const Color(0xFF008DA9),
              tint: const Color(0xFFEFFBFF),
              darkTint: const Color(0xFF152D38),
              onTap: onSmartCall,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _FeatureCard(
              title: l10n.dashboardWorldwideEsims,
              subtitle: l10n.dashboardExploreGlobalOffers,
              icon: Icons.language_rounded,
              accent: const Color(0xFF7151D9),
              tint: const Color(0xFFF5F2FF),
              darkTint: const Color(0xFF252139),
              onTap: onEsims,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.tint,
    required this.darkTint,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color tint;
  final Color darkTint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Color.lerp(accent, Colors.white, 0.45)! : accent;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: iconColor.withValues(alpha: 0.2)),
    );

    return Semantics(
      button: true,
      child: Material(
        color: isDark ? darkTint : tint,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 21),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.dashboardNewFeature,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: iconColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: iconColor,
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textTertiaryLight,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
