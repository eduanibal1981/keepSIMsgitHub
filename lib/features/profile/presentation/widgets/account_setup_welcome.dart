import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';

class AccountSetupWelcome extends StatelessWidget {
  const AccountSetupWelcome({
    super.key,
    required this.agreedToTerms,
    required this.onAgreementChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool agreedToTerms;
  final ValueChanged<bool> onAgreementChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorderSoft;
    final accent = isDark ? AppColors.secondary : AppColors.lightSecondary;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const ValueKey('onboarding-welcome-scroll'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/launcher-foreground.png',
                  key: const ValueKey('onboarding-brand-artwork'),
                  height: (constraints.maxHeight * 0.22).clamp(112.0, 176.0),
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.verified_user_outlined,
                    size: 112,
                    color: context.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome to KeepSIMs',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep your numbers connected, wherever life takes you.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: secondaryText,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, color: accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your privacy matters',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: context.onSurfaceColor,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'We use your account and SIM details to provide protection, '
                  'refills, and alerts. Read how the service works and how '
                  'your data is handled.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: secondaryText,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: border),
                _PolicyLink(
                  title: 'Terms of Service',
                  icon: Icons.description_outlined,
                  onTap: onOpenTerms,
                ),
                Divider(height: 1, color: border),
                _PolicyLink(
                  title: 'Privacy Policy',
                  icon: Icons.lock_outline_rounded,
                  onTap: onOpenPrivacy,
                ),
                Divider(height: 1, color: border),
                const SizedBox(height: 16),
                Material(
                  color: context.primaryColor.withValues(
                    alpha: agreedToTerms ? 0.09 : 0.04,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: agreedToTerms ? context.primaryColor : border,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CheckboxListTile(
                    key: const ValueKey('onboarding-terms-checkbox'),
                    value: agreedToTerms,
                    onChanged: (value) => onAgreementChanged(value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsetsDirectional.only(
                      start: 4,
                      end: 12,
                      top: 6,
                      bottom: 6,
                    ),
                    activeColor: context.primaryColor,
                    checkColor: isDark ? AppColors.darkBg : Colors.white,
                    title: Text(
                      'I agree to the Terms of Service and Privacy Policy.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
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
}

class _PolicyLink extends StatelessWidget {
  const _PolicyLink({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minLeadingWidth: 22,
    horizontalTitleGap: 10,
    leading: Icon(icon, size: 22, color: context.primaryColor),
    title: Text(
      title,
      style: AppTextStyles.titleMedium.copyWith(
        color: context.onSurfaceColor,
        letterSpacing: 0,
      ),
    ),
    trailing: Icon(
      Icons.open_in_new_rounded,
      size: 18,
      color: context.primaryColor,
    ),
    onTap: onTap,
  );
}
