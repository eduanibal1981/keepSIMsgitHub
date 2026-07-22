/// eSIM Management Screen
///
/// A premium screen for managing eSIM profiles on the device.
/// Detects device eSIM capability and provides profile management.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/core/services/esim_capability_service.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class EsimScreen extends ConsumerWidget {
  const EsimScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esimCapability = ref.watch(esimCapabilityServiceProvider);
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.esimManagerTitle,
          style: AppTextStyles.headlineMedium.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: context.onSurfaceColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: esimCapability.when(
          data: (isSupported) => _buildContent(context, isDark, isSupported),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _buildContent(context, isDark, false),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, bool isSupported) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero eSIM Card ───────────────────────────────────────
          _buildEsimHeroCard(context, isDark, isSupported),
          const SizedBox(height: 28),

          if (isSupported) ...[
            // ── Quick Actions ───────────────────────────────────────
            _buildSectionTitle(context, 'eSIM Actions'),
            const SizedBox(height: 14),
            _buildActionTile(
              context,
              isDark: isDark,
              icon: Icons.travel_explore_rounded,
              title: l10n.esimPlansTitle,
              subtitle: l10n.searchDestinationHint,
              color: const Color(0xFF8B5CF6),
              onTap: () async {
                await HapticHelper.lightTick();
                if (context.mounted) {
                  context.push(AppRoutes.esimPlans);
                }
              },
            ),
            const SizedBox(height: 10),
            _buildActionTile(
              context,
              isDark: isDark,
              icon: Icons.add_circle_outline_rounded,
              title: 'Add eSIM Profile',
              subtitle: 'Scan QR code or enter activation details',
              color: AppColors.primary,
              onTap: () async {
                await HapticHelper.lightTick();
                if (context.mounted) {
                  _showComingSoonSheet(context, isDark);
                }
              },
            ),
            const SizedBox(height: 10),
            _buildActionTile(
              context,
              isDark: isDark,
              icon: Icons.swap_horiz_rounded,
              title: 'Transfer eSIM',
              subtitle: 'Move an existing eSIM to this device',
              color: AppColors.secondary,
              onTap: () async {
                await HapticHelper.lightTick();
                if (context.mounted) {
                  _showComingSoonSheet(context, isDark);
                }
              },
            ),
            const SizedBox(height: 28),

            // ── Installed eSIM Profiles ─────────────────────────────
            _buildSectionTitle(context, 'My eSIMs'),
            const SizedBox(height: 14),
            _buildEmptyProfilesCard(context, isDark),
          ] else ...[
            // ── Device Not Supported ────────────────────────────────
            _buildNotSupportedInfo(context, isDark),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Hero Card ───────────────────────────────────────────────────
  Widget _buildEsimHeroCard(
    BuildContext context,
    bool isDark,
    bool isSupported,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isSupported
            ? const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1), Color(0xFF4CD7F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)]
                    : [const Color(0xFFE0E0E0), const Color(0xFFBDBDBD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: isSupported
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/esim.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'eSIM',
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSupported
                          ? 'Your device supports eSIM'
                          : 'eSIM not available',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSupported
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSupported
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSupported ? 'Ready' : 'N/A',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isSupported) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Browse travel data plans for 150+ countries with instant digital activation.',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: AppTextStyles.headlineSmall.copyWith(
        color: context.onSurfaceColor,
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: color.withValues(alpha: 0.08),
        highlightColor: color.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: context.onSurfaceColor.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.onSurfaceColor.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyProfilesCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sim_card_outlined,
              color: Color(0xFF6366F1),
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Active eSIMs Yet',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Browse and buy eSIM travel packages to view your active data passes here.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: context.onSurfaceColor.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotSupportedInfo(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.deviceIncompatibleNotice,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showComingSoonSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Coming Soon in C9b', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              )
            ],
          ),
        );
      },
    );
  }
}
