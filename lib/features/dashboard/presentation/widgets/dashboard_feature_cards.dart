import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

/// Two calling shortcuts and a full-width travel data shortcut.
class DashboardFeatureCards extends StatelessWidget {
  const DashboardFeatureCards({
    super.key,
    required this.onSmartCall,
    required this.onVirtualNumbers,
    required this.onEsims,
  });
  final VoidCallback onSmartCall;
  final VoidCallback onVirtualNumbers;
  final VoidCallback onEsims;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final smart = _FeatureCard(
      title: l10n.smartCall,
      subtitle: l10n.dashboardExploreSmartCall,
      icon: const _OutgoingCallIcon(),
      accent: const Color(0xFF009FB5),
      onTap: onSmartCall,
    );
    final number = _FeatureCard(
      title: l10n.virtualNumbers,
      subtitle: l10n.dashboardSecondNumberBenefit,
      icon: const _SecondNumberIcon(),
      accent: const Color(0xFF00BE86),
      onTap: onVirtualNumbers,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
        return Column(
          children: [
            if (stack) ...[
              smart,
              const SizedBox(height: 8),
              number,
            ] else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: smart),
                    const SizedBox(width: 8),
                    Expanded(child: number),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _FeatureCard(
              title: l10n.dashboardWorldwideEsims,
              subtitle: l10n.dashboardExploreGlobalOffers,
              icon: const Icon(Icons.language_rounded),
              accent: const Color(0xFF8051DB),
              onTap: onEsims,
              horizontal: true,
            ),
          ],
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.horizontal = false,
  });
  final String title;
  final String subtitle;
  final Widget icon;
  final Color accent;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? Color.lerp(accent, Colors.white, .3)! : accent;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: dark ? Colors.white : const Color(0xFF0D1324),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 12,
            letterSpacing: -.2,
            height: 1.3,
            color: dark ? AppColors.textSecondaryDark : const Color(0xFF748095),
          ),
        ),
      ],
    );
    final badge = ExcludeSemantics(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? .16 : .09),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: IconTheme(
          data: IconThemeData(size: 28, color: color),
          child: icon,
        ),
      ),
    );
    final chevron = Icon(
      Icons.chevron_right_rounded,
      size: 22,
      color: dark ? AppColors.textSecondaryDark : const Color(0xFF7E889B),
      textDirection: Directionality.of(context),
    );
    return Semantics(
      button: true,
      child: Material(
        color: dark ? const Color(0xFF17212C) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: dark ? AppColors.darkBorder : const Color(0xFFE5EAF0),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: horizontal
                ? Row(
                    children: [
                      badge,
                      const SizedBox(width: 14),
                      Expanded(child: text),
                      const SizedBox(width: 8),
                      chevron,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [badge, const Spacer(), chevron]),
                      const SizedBox(height: 8),
                      text,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _OutgoingCallIcon extends StatelessWidget {
  const _OutgoingCallIcon();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 32,
    height: 32,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          bottom: 0,
          child: Icon(Icons.call_rounded, size: 26),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Icon(Icons.north_east_rounded, size: 18),
        ),
      ],
    ),
  );
}

class _SecondNumberIcon extends StatelessWidget {
  const _SecondNumberIcon();
  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color!;
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 22,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(
                Icons.call_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 20,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
              child: const Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
