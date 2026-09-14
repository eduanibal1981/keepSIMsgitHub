import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import '../../domain/entities/return_trip_package.dart';
import '../controllers/return_trip_wizard_controller.dart';

class WizardStepPackageSelection extends StatelessWidget {
  final String countryName;
  final String userTier; // 'premium', 'standard', 'free'
  final ReturnTripWizardState state;
  final ReturnTripWizardController controller;

  const WizardStepPackageSelection({
    super.key,
    required this.countryName,
    required this.userTier,
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return state.packages.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: Color(0xFF0284C7)),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
              const SizedBox(height: 12),
              Text(
                'Could not load packages for $countryName',
                style: AppTextStyles.titleMedium.copyWith(color: context.onSurfaceColor),
              ),
              const SizedBox(height: 6),
              Text(
                err.toString(),
                style: AppTextStyles.caption.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => controller.retryLoadPackages(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Loading Packages'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (allPackages) {
        // Filter packages based on eSIM support
        // If device does NOT support eSIM, exclusively show physical SIM / USSD packs
        final availablePackages = state.hasEsimSupport
            ? allPackages
            : allPackages.where((p) => p.packageType != 'esim').toList();

        if (availablePackages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No return data packages currently available for $countryName.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ),
          );
        }

        final selected = (state.selectedPackage != null &&
                availablePackages.any((p) => p.id == state.selectedPackage!.id))
            ? state.selectedPackage!
            : availablePackages.first;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tier Benefit Banner
              _buildTierDiscountBanner(context, isDark),
              const SizedBox(height: 16),

              Text(
                state.hasEsimSupport
                    ? 'Recommended Packages (eSIM & Local SIM)'
                    : 'Local Carrier Data Packages ($countryName)',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.onSurfaceColor,
                ),
              ),
              const SizedBox(height: 10),

              // Package Cards List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: availablePackages.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final pkg = availablePackages[index];
                  final isSelected = selected.id == pkg.id;
                  return _buildPackageCard(context, pkg, isSelected, isDark);
                },
              ),
              const SizedBox(height: 20),

              // Price Breakdown Card
              _buildPriceBreakdownCard(context, selected, isDark),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTierDiscountBanner(BuildContext context, bool isDark) {
    final normTier = userTier.toLowerCase();
    final bool isPremium = normTier == 'premium';
    final bool isStandard = normTier == 'standard';

    String title;
    String subtitle;
    Color accentColor;

    if (isPremium) {
      title = 'Premium Benefit: 100% App Fee Discount';
      subtitle = 'As a Premium member, you pay \$0 app fee on all return data packs!';
      accentColor = const Color(0xFFF59E0B); // Amber
    } else if (isStandard) {
      title = 'Standard Benefit: 50% App Fee Discount';
      subtitle = 'You receive a 50% discount on the app fee. Upgrade to Premium for \$0 fee.';
      accentColor = const Color(0xFF38BDF8); // Sky blue
    } else {
      title = 'Free Plan: Standard Pricing';
      subtitle = 'Full retail pricing applies. Upgrade to Premium anytime to enjoy \$0 app fee.';
      accentColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium ? Icons.workspace_premium_rounded : Icons.star_rounded,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(
    BuildContext context,
    ReturnTripPackage pkg,
    bool isSelected,
    bool isDark,
  ) {
    return InkWell(
      onTap: () {
        HapticHelper.lightTick();
        controller.selectPackage(pkg);
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF182234) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0284C7)
                : (isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: pkg.isEsim
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFF0284C7).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    pkg.isEsim ? Icons.sim_card_download_rounded : Icons.cell_tower_rounded,
                    color: pkg.isEsim ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (pkg.badgeLabel != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: pkg.isEsim
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                pkg.badgeLabel!,
                                style: TextStyle(
                                  color: pkg.isEsim
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            pkg.isEsim ? 'Instant eSIM' : (pkg.carrierName ?? 'Carrier Pack'),
                            style: AppTextStyles.caption.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pkg.title,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.onSurfaceColor,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Effective Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${pkg.effectivePriceUsd.toStringAsFixed(2)}',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                        fontSize: 17,
                      ),
                    ),
                    if (pkg.discountUsd > 0)
                      Text(
                        '\$${pkg.retailPriceUsd.toStringAsFixed(2)}',
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildInfoTag(
                  icon: Icons.data_usage_rounded,
                  label: pkg.formattedAllowance,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildInfoTag(
                  icon: Icons.schedule_rounded,
                  label: pkg.formattedDuration,
                  isDark: isDark,
                ),
                if (pkg.ussdRechargeCode != null) ...[
                  const SizedBox(width: 8),
                  _buildInfoTag(
                    icon: Icons.dialpad_rounded,
                    label: pkg.ussdRechargeCode!,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTag({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard(
    BuildContext context,
    ReturnTripPackage pkg,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182234) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Breakdown',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: context.onSurfaceColor,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow('Package Base Price', '\$${pkg.supplierCostUsd.toStringAsFixed(2)}', isDark),
          const SizedBox(height: 6),
          _buildBreakdownRow(
            'KeepSIMs App Fee',
            '\$${(pkg.retailPriceUsd - pkg.supplierCostUsd).toStringAsFixed(2)}',
            isDark,
          ),
          if (pkg.discountUsd > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${userTier.toUpperCase()} App Fee Discount',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  '-\$${pkg.discountUsd.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              color: isDark ? const Color(0xFF263348) : const Color(0xFFF1F5F9),
              height: 1,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total You Pay',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.onSurfaceColor,
                ),
              ),
              Text(
                '\$${pkg.effectivePriceUsd.toStringAsFixed(2)}',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            fontSize: 12.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}
