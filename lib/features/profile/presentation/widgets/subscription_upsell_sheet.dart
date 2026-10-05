import 'package:flutter/material.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';

class SubscriptionUpsellSheet extends ConsumerWidget {
  final String title;
  final String description;
  final String requiredPlan;
  final List<String> highlights;

  const SubscriptionUpsellSheet({
    super.key,
    required this.title,
    required this.description,
    required this.requiredPlan,
    required this.highlights,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String description,
    required String requiredPlan,
    required List<String> highlights,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SubscriptionUpsellSheet(
        title: title,
        description: description,
        requiredPlan: requiredPlan,
        highlights: highlights,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseFee =
        ref.watch(baseServiceFeeUsdProvider).value ?? kDefaultBaseServiceFeeUsd;
    final bool isPremium = requiredPlan.toLowerCase() == 'premium';
    final Color accentColor = isPremium
        ? Colors.purpleAccent
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border(
          top: BorderSide(
            color: accentColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag Handle
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Glowing Locked Shield Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.08),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.lock_person_rounded,
              color: accentColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 10),

          // Description
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // The configured annual protection component, not a total refill quote.
          Text(
            '${AppLocalizations.of(context)?.fxAnnualProtectionFee ?? 'Annual protection fee'}: ${Money.usd(baseFee)}',
            style: TextStyle(color: accentColor, fontWeight: FontWeight.w600),
          ),
          ApproxLocalText(
            baseFee,
            style: TextStyle(
              color: accentColor.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const FxChargeNotice(
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 12),

          // Feature Highlights Section
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.darkCard.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'UNLOCKS WITH ${requiredPlan.toUpperCase()}',
                      style: AppTextStyles.caption.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...highlights.map(
                  (feat) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_rounded, color: accentColor, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            feat,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
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
          const SizedBox(height: 28),

          // CTA Buttons
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () async {
                await HapticHelper.mediumImpact();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: accentColor.withValues(alpha: 0.3),
              ),
              child: Text(
                'Upgrade to $requiredPlan',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe Later',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
