/// eSIM Management Screen
///
/// A premium screen for managing eSIM profiles on the device.
/// Detects device eSIM capability and provides profile management.
library;

import 'esim_controls_screen.dart';

import 'package:keep_sims/features/esim/presentation/screens/esim_recharge_screen.dart';

import 'package:keep_sims/features/esim/presentation/widgets/esim_profile_card.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/core/services/esim_capability_service.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_delivery_screen.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class EsimScreen extends ConsumerStatefulWidget {
  const EsimScreen({super.key});

  @override
  ConsumerState<EsimScreen> createState() => _EsimScreenState();
}

class _EsimScreenState extends ConsumerState<EsimScreen> {
  bool _forceTestMode = false;

  @override
  Widget build(BuildContext context) {
    final esimCapability = ref.watch(esimCapabilityServiceProvider);
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;
    final uri = GoRouterState.of(context).uri;
    final isTestModeQuery = uri.queryParameters['test_mode'] == 'true';
    final bool testMode = _forceTestMode || isTestModeQuery;

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
        actions: [
          if (testMode)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6366F1),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bug_report,
                        size: 14,
                        color: Color(0xFF6366F1),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'TEST MODE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: esimCapability.when(
          data: (isSupported) => _buildContent(
            context,
            ref,
            isDark,
            isSupported || testMode,
            testMode,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              _buildContent(context, ref, isDark, testMode, testMode),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    bool isSupported,
    bool testMode,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final userEsimsAsync = ref.watch(userEsimsControllerProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(userEsimsControllerProvider.notifier).refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (testMode) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF6366F1),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Emulator Test Mode: Displaying full eSIM management structure & preview cards.',
                        style: AppTextStyles.caption.copyWith(
                          color: context.onSurfaceColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
              const SizedBox(height: 28),
            ],
            if (!isSupported) ...[
              _buildNotSupportedInfo(context, isDark),
              const SizedBox(height: 20),
            ],

            // Owned profiles remain available for QR display and recovery
            // help even when this device cannot provision an eSIM.
            // ── Installed eSIM Profiles ("My eSIMs") ────────────────
            _buildSectionTitle(context, 'My eSIMs'),
            const SizedBox(height: 14),

            userEsimsAsync.when(
              data: (esims) {
                final displayEsims = (esims.isEmpty && testMode)
                    ? _getMockEsims()
                    : esims;
                if (displayEsims.isEmpty) {
                  return _buildEmptyProfilesCard(context, isDark);
                }
                final activeEsims = displayEsims
                    .where((e) => !e.isTerminal)
                    .toList();
                final archivedEsims = displayEsims
                    .where((e) => e.isTerminal)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (activeEsims.isNotEmpty)
                      ...activeEsims.map(
                        (esim) => _buildEsimCard(context, esim, isDark),
                      ),

                    if (archivedEsims.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      ExpansionTile(
                        title: Text(
                          'Archived eSIMs (${archivedEsims.length})',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        children: archivedEsims
                            .map(
                              (esim) => _buildEsimCard(context, esim, isDark),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) {
                final displayEsims = testMode ? _getMockEsims() : <UserEsim>[];
                if (displayEsims.isNotEmpty) {
                  final activeEsims = displayEsims
                      .where((e) => !e.isTerminal)
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: activeEsims
                        .map((esim) => _buildEsimCard(context, esim, isDark))
                        .toList(),
                  );
                }
                return const Text(
                  'Could not load your eSIMs. Pull to refresh.',
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<UserEsim> _getMockEsims() {
    return [
      UserEsim(
        id: 'test-esim-1',
        userId: 'test-user',
        esimOrderId: 'order-101',
        iccid: '89860000000000000001',
        lpaActivationCode: 'LPA:1\$rsp.global-esim.com\$TESTMATCHINGCODE1',
        qrCodeUrl:
            'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=LPA:1\$rsp.global-esim.com\$TESTMATCHINGCODE1',
        bundleName: 'Global Pass 10 GB',
        provider: 'KeepSIMs Global',
        status: 'active',
        dataRemainingMb: 6553,
        dataTotalMb: 10240,
        purchasedAt: DateTime.now().subtract(const Duration(days: 3)),
        firstActivatedAt: DateTime.now().subtract(const Duration(days: 2)),
        expiresAt: DateTime.now().add(const Duration(days: 27)),
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now(),
      ),
      UserEsim(
        id: 'test-esim-2',
        userId: 'test-user',
        esimOrderId: 'order-102',
        iccid: '89860000000000000002',
        lpaActivationCode: 'LPA:1\$rsp.global-esim.com\$TESTMATCHINGCODE2',
        qrCodeUrl:
            'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=LPA:1\$rsp.global-esim.com\$TESTMATCHINGCODE2',
        bundleName: 'USA & Canada 5 GB',
        provider: 'KeepSIMs Americas',
        status: 'active',
        dataRemainingMb: 1280,
        dataTotalMb: 5120,
        purchasedAt: DateTime.now().subtract(const Duration(days: 10)),
        firstActivatedAt: DateTime.now().subtract(const Duration(days: 9)),
        expiresAt: DateTime.now().add(const Duration(days: 5)),
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  Widget _buildEsimCard(BuildContext context, UserEsim esim, bool isDark) =>
      EsimProfileCard(
        profile: esim,
        onInstall: () => EsimDeliveryScreen.show(context, esim),
        onRecharge: () => EsimRechargeScreen.show(context, esim.id),
        onControls: () => EsimControlsScreen.show(context, esim.id),
        onBuyNew: () => context.push(AppRoutes.esimPlans),
      );

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
                colors: [
                  Color(0xFF8B5CF6),
                  Color(0xFF6366F1),
                  Color(0xFF4CD7F6),
                ],
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.bug_report, size: 18),
              label: const Text(
                '🧪 Open eSIM Manager (Emulator Test Mode)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                setState(() {
                  _forceTestMode = true;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
