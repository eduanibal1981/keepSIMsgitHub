import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_line_detail_controller.dart';
import 'package:keep_sims/core/widgets/glass_card.dart';
import 'package:keep_sims/core/widgets/glass_toggle_switch.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/number_verification_dialog.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/manual_refill_bottom_sheet.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/premium_refill_config_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class SimLineDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const SimLineDetailScreen({super.key, required this.id});

  @override
  ConsumerState<SimLineDetailScreen> createState() =>
      _SimLineDetailScreenState();
}

class _SimLineDetailScreenState extends ConsumerState<SimLineDetailScreen> {
  bool _isToggling = false;
  late bool _isShared;
  late bool _isViewer;
  dynamic _membership;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(simLineDetailControllerProvider(widget.id));
    final countriesState = ref.watch(supportedCountriesProvider);
    final user = ref.watch(authControllerProvider).value;
    final simLine = detailAsync.value?.simLine;
    final householdState = ref.watch(householdControllerProvider).value;

    _isShared = simLine != null && simLine.userId != user?.id;
    _membership = _isShared
        ? householdState?.memberships.firstWhereOrNull(
            (m) => m.ownerId == simLine!.userId,
          )
        : null;
    _isViewer =
        _isShared && (_membership == null || _membership.role == 'viewer');

    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: context.onSurfaceColor,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context)!.protectionConsole,
          style: AppTextStyles.headlineMedium.copyWith(
            color: context.onSurfaceColor,
          ),
        ),
        actions: [
          if (simLine != null && simLine.userId == user?.id)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              tooltip: AppLocalizations.of(context)!.deleteProtectionTooltip,
              onPressed: () async {
                await HapticHelper.mediumImpact();
                if (context.mounted) {
                  _showDeleteConfirmation(context, simLine);
                }
              },
            ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            tooltip: AppLocalizations.of(context)!.refreshTooltip,
            onPressed: () async {
              await HapticHelper.lightTick();
              ref.invalidate(simLineDetailControllerProvider(widget.id));
            },
          ),
        ],
      ),
      body: () {
        final detailState = detailAsync.value;
        if (detailState != null) {
          final countries = countriesState.value ?? [];
          final country = countries.isEmpty
              ? null
              : countries.firstWhere(
                  (c) => c.id == detailState.simLine.countryId,
                  orElse: () => countries.first,
                );

          bool isHomeCountry = false;
          if (user?.homeCountryCode != null && country != null) {
            isHomeCountry =
                user!.homeCountryCode!.toUpperCase() ==
                country.isoCode.toUpperCase();
          }

          final isPremium =
              detailState.simLine.protectionTier.toLowerCase() == 'premium';
          final line = detailState.simLine;
          final fallbackRefillSchedule =
              detailState.customRefillSchedule ??
              detailState.miniRefillSchedule;
          final hasProtectionActive = isPremium
              ? (fallbackRefillSchedule != null &&
                    fallbackRefillSchedule.status == 'active')
              : (detailState.notifySchedule != null &&
                    detailState.notifySchedule!.status == 'active');
          final isVerified = line.status == 'active';
          final recentRefill =
              line.lastTopupAt != null &&
              DateTime.now().difference(line.lastTopupAt!).inDays <= 80;

          final score = line.isHomeMode
              ? 100
              : (!isPremium
                    ? (hasProtectionActive ? 100 : 0)
                    : ((hasProtectionActive ? 50 : 0) +
                          (isVerified ? 25 : 0) +
                          (recentRefill ? 25 : 0)));

          final String tier = (user != null && user.isPowerUser)
              ? 'premium'
              : line.protectionTier.toLowerCase();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildHeaderCard(context, detailState, country, score),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Critical Risk Alert Banner (conditional)
                      _buildCriticalRiskAlert(
                        context,
                        detailState,
                        isPremium,
                        tier,
                        isVerified,
                        score,
                      ),
                      if (score < 30 && !line.isHomeMode)
                        const SizedBox(height: 20),

                      // 2. Protection Layers configuration (renamed from AutoRefillSection)
                      _buildProtectionLayersSection(context, detailState),
                      const SizedBox(height: 20),

                      // 3. Quick Actions 2x2 grid (Manual Refill, Recharge Friend, Test SIM, Home mode)
                      _buildQuickActionsGrid(
                        context,
                        line,
                        country,
                        isPremium,
                        tier,
                        isVerified,
                      ),
                      const SizedBox(height: 20),

                      // Cosmetic Downward Scroll Arrow
                      Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                          ),
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Historical Refill Executions
                      _buildExecutionsSection(context, detailState),
                      const SizedBox(height: 20),

                      // 5. Activity Event Timeline Logs
                      _buildTimelineSection(context, detailState),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        if (detailAsync.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final err = detailAsync.error ?? Exception('Unknown error');
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 54,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.failedToLoadDetails,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(
                    simLineDetailControllerProvider(widget.id),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.retryConnection,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }(),
    );
  }

  // ── 1. Header Card UI ──────────────────────────────────────────────────────
  Widget _buildHeaderCard(
    BuildContext context,
    SimLineDetailState detail,
    dynamic country,
    int score,
  ) {
    final line = detail.simLine;
    final bool isPremium = line.protectionTier.toLowerCase() == 'premium';
    final isDark = context.isDarkMode;

    String flag = '🌐';
    if (country != null) {
      flag = country.flagEmoji as String;
    }

    IconData getIcon(String iconStr) {
      switch (iconStr) {
        case 'phone':
          return Icons.phone_android;
        case 'person':
          return Icons.person;
        case 'home':
          return Icons.home_outlined;
        default:
          return Icons.sim_card;
      }
    }

    Color scoreColor;
    if (line.isHomeMode) {
      scoreColor = Colors.lightBlue;
    } else if (score >= 60) {
      scoreColor = AppColors.healthGreen;
    } else if (score >= 30) {
      scoreColor = AppColors.healthAmber;
    } else {
      scoreColor = AppColors.healthRed;
    }

    final healthRing = SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100.0,
            strokeWidth: 5,
            backgroundColor: isDark
                ? AppColors.darkBorder
                : const Color(0xFFEAEEF1),
            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: AppTextStyles.titleLarge.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              Text(
                AppLocalizations.of(context)!.healthLabel,
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.darkCardGradient
            : LinearGradient(
                colors: [Colors.white, context.scaffoldBackgroundColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.primary : AppColors.lightPrimary)
                .withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar Icon & Country Flag overlay (optimized smaller size to prevent overflow)
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : const Color(0xFFEAEEF1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Icon(
                  getIcon(line.avatarIcon),
                  color: isDark
                      ? AppColors.primaryLight
                      : AppColors.lightPrimary,
                  size: 22,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(flag, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Info Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      (line.nickname != null &&
                              line.nickname!.trim().isNotEmpty)
                          ? line.nickname!.trim()
                          : AppLocalizations.of(context)!.mySimCardDefault,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_isShared)
                      GestureDetector(
                        onTap: () async {
                          await HapticHelper.lightTick();
                          if (context.mounted) {
                            _showEditNicknameDialog(context, line);
                          }
                        },
                        child: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    _buildTierBadge(
                      isPremium ? 'premium' : line.protectionTier,
                    ),
                    if (!isPremium)
                      GestureDetector(
                        onTap: () async {
                          await HapticHelper.mediumImpact();
                          if (context.mounted) {
                            LineUpgradeSheet.show(
                              context: context,
                              simLine: line,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amberAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.rocket_launch_rounded,
                                color: isDark
                                    ? Colors.amberAccent
                                    : Colors.orange.shade700,
                                size: 10,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppLocalizations.of(context)!.upLabel,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.amberAccent
                                      : Colors.orange.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  line.phoneNumber,
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (country != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    country.name as String,
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.primaryLight
                          : AppColors.lightPrimary,
                    ),
                  ),
                ],
                if (_isShared) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        color: isDark
                            ? AppColors.primaryLight
                            : AppColors.lightPrimary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.sharedByFamily(
                          _membership?.ownerName ?? 'Family Member',
                          _isViewer ? 'Viewer' : 'Manager',
                        ),
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.primaryLight
                              : AppColors.lightPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          healthRing,
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: context.onSurfaceColor.withValues(alpha: 0.5),
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildCriticalRiskAlert(
    BuildContext context,
    SimLineDetailState detail,
    bool isPremium,
    String tier,
    bool isVerified,
    int score,
  ) {
    if (score >= 30 || detail.simLine.isHomeMode) {
      return const SizedBox.shrink();
    }

    final isDark = context.isDarkMode;
    final line = detail.simLine;

    final fallbackRefillSchedule =
        detail.customRefillSchedule ?? detail.miniRefillSchedule;
    final hasProtectionActive = isPremium
        ? (fallbackRefillSchedule != null &&
              fallbackRefillSchedule.status == 'active')
        : (detail.notifySchedule != null &&
              detail.notifySchedule!.status == 'active');

    final recentRefill =
        line.lastTopupAt != null &&
        DateTime.now().difference(line.lastTopupAt!).inDays <= 80;

    final List<String> missingReasons = [];
    if (!isPremium) {
      if (!hasProtectionActive) {
        missingReasons.add(AppLocalizations.of(context)!.missingAlertsDesc);
      }
    } else {
      if (!hasProtectionActive) {
        missingReasons.add(AppLocalizations.of(context)!.missingAutoRefillDesc);
      }
      if (!isVerified) {
        missingReasons.add(
          AppLocalizations.of(context)!.missingVerificationDesc,
        );
      }
      if (!recentRefill) {
        missingReasons.add(
          AppLocalizations.of(context)!.missingRecentRefillDesc,
        );
      }
    }

    if (missingReasons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.criticalRisk,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.simDeactivationRisk,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...missingReasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(
    BuildContext context,
    SimLine line,
    dynamic country,
    bool isPremium,
    String tier,
    bool isVerified,
  ) {
    final isDark = context.isDarkMode;
    final String homeCountryName = country?.name ?? 'Home';
    final userProfile = ref.read(authControllerProvider).value;
    final bool isBasic = tier == 'basic';

    final List<Widget> activeTiles = [];

    if (!_isViewer) {
      activeTiles.add(
        _buildQuickActionTile(
          context: context,
          title: AppLocalizations.of(context)!.manualRefillLabel,
          subtitle: AppLocalizations.of(context)!.chargeFromWalletNow,
          icon: Icons.bolt_rounded,
          iconColor: Colors.amber,
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => ManualRefillBottomSheet(simLine: line),
            );
          },
        ),
      );
    }

    activeTiles.add(
      _buildQuickActionTile(
        context: context,
        title: AppLocalizations.of(context)!.rechargeFromFriend,
        subtitle: isBasic
            ? AppLocalizations.of(context)!.requestViaTelegram
            : AppLocalizations.of(context)!.shareViaWaTg,
        icon: Icons.people_rounded,
        iconColor: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
        onTap: () => _showP2PRequestDialog(context, line, isBasic),
      ),
    );

    if (!_isViewer) {
      String testSubtitle = AppLocalizations.of(context)!.verifyLineReachable;
      if (tier == 'standard' && isVerified) {
        testSubtitle = AppLocalizations.of(context)!.checkCompleted1x;
      }
      activeTiles.add(
        _buildQuickActionTile(
          context: context,
          title: AppLocalizations.of(context)!.testSimActivity,
          subtitle: testSubtitle,
          icon: Icons.radar,
          iconColor: AppColors.success,
          onTap: () {
            if (tier == 'basic') {
              LineUpgradeSheet.show(context: context, simLine: line);
            } else if (tier == 'standard' && isVerified) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.starterPlan1xCompleted,
                  ),
                  showCloseIcon: true,
                  duration: const Duration(seconds: 6),
                  action: SnackBarAction(
                    label: AppLocalizations.of(context)!.upgrade,
                    textColor: Colors.amber,
                    onPressed: () =>
                        LineUpgradeSheet.show(context: context, simLine: line),
                  ),
                ),
              );
            } else {
              _handleVerifyLineActivity(context, line);
            }
          },
        ),
      );
    }

    bool isHomeCountry = false;
    if (userProfile?.homeCountryCode != null && country != null) {
      isHomeCountry =
          userProfile!.homeCountryCode!.toUpperCase() ==
          country.isoCode.toUpperCase();
    }

    if (isHomeCountry && !_isViewer) {
      activeTiles.add(
        _buildQuickActionTile(
          context: context,
          title: line.isHomeMode
              ? AppLocalizations.of(context)!.leaveCountry(homeCountryName)
              : AppLocalizations.of(
                  context,
                )!.backToCountryMode(homeCountryName),
          subtitle: line.isHomeMode
              ? AppLocalizations.of(context)!.resumeProtectionLayers
              : AppLocalizations.of(context)!.pauseWhileVisitingHome,
          icon: Icons.home_rounded,
          iconColor: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
          onTap: () {
            ref
                .read(simLinesControllerProvider.notifier)
                .toggleHomeMode(line.id, !line.isHomeMode);
          },
        ),
      );
    }

    // Layout logic: chunks of 2
    final List<Widget> rows = [];
    for (int i = 0; i < activeTiles.length; i += 2) {
      if (i + 1 < activeTiles.length) {
        rows.add(
          Row(
            children: [
              Expanded(child: activeTiles[i]),
              const SizedBox(width: 12),
              Expanded(child: activeTiles[i + 1]),
            ],
          ),
        );
      } else {
        rows.add(activeTiles[i]);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(AppLocalizations.of(context)!.quickActionsLabel),
        const SizedBox(height: 8),
        ...rows.map(
          (r) => Padding(padding: const EdgeInsets.only(bottom: 12), child: r),
        ),
      ],
    );
  }

  Widget _buildQuickActionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = context.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showP2PRequestDialog(BuildContext context, SimLine line, bool isBasic) {
    final isDark = context.isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.rechargeFromFriendTitle,
              style: AppTextStyles.headlineSmall.copyWith(
                color: context.onSurfaceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.selectPlatformShare,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 20),
            // WhatsApp Button
            if (!isBasic)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await HapticHelper.lightTick();
                    if (!context.mounted) return;
                    final phone = line.phoneNumber;
                    final templateText = AppLocalizations.of(
                      context,
                    )!.rechargeRequestTemplate(phone);
                    final waUrl =
                        'https://wa.me/?text=${Uri.encodeComponent(templateText)}';
                    final uri = Uri.parse(waUrl);
                    _launchUrlHelper(context, uri, 'WhatsApp');
                  },
                  icon: const Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF25D366),
                    size: 18,
                  ),
                  label: Text(
                    AppLocalizations.of(context)!.requestViaWhatsApp,
                    style: const TextStyle(
                      color: Color(0xFF25D366),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: const Color(0xFF25D366).withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
              )
            else
              // Greyed out WhatsApp for basic
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    HapticHelper.mediumImpact();
                    LineUpgradeSheet.show(context: context, simLine: line);
                  },
                  icon: const Icon(
                    Icons.chat_rounded,
                    color: Colors.grey,
                    size: 18,
                  ),
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${AppLocalizations.of(context)!.requestViaWhatsApp} ',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.amber.shade700,
                        size: 14,
                      ),
                    ],
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // Telegram Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await HapticHelper.lightTick();
                  if (!context.mounted) return;
                  final phone = line.phoneNumber;
                  final templateText = AppLocalizations.of(
                    context,
                  )!.rechargeRequestTemplate(phone);
                  final tgAppUri = Uri.parse(
                    'tg://msg?text=${Uri.encodeComponent(templateText)}',
                  );
                  final tgWebUri = Uri.parse(
                    'https://t.me/share/url?url=https://keepsims.com&text=${Uri.encodeComponent(templateText)}',
                  );
                  _launchTelegramHelper(context, tgAppUri, tgWebUri);
                },
                icon: const Icon(
                  Icons.telegram_rounded,
                  color: Color(0xFF0088CC),
                  size: 18,
                ),
                label: Text(
                  AppLocalizations.of(context)!.requestViaTelegram,
                  style: const TextStyle(
                    color: Color(0xFF0088CC),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0088CC).withValues(alpha: 0.12),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: const Color(0xFF0088CC).withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchUrlHelper(
    BuildContext context,
    Uri uri,
    String platformName,
  ) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                )!.couldNotLaunchLink(platformName, e.toString()),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _launchTelegramHelper(
    BuildContext context,
    Uri tgAppUri,
    Uri tgWebUri,
  ) async {
    try {
      final launched = await launchUrl(
        tgAppUri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!launched) {
        await launchUrl(tgWebUri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(tgWebUri, mode: LaunchMode.platformDefault);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                )!.couldNotLaunchTelegram(e.toString()),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildProtectionLayersSection(
    BuildContext context,
    SimLineDetailState detail,
  ) {
    final line = detail.simLine;
    final isPremium = line.protectionTier.toLowerCase() == 'premium';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(AppLocalizations.of(context)!.protectionLayersLabel),
        const SizedBox(height: 8),
        _buildAutoNotifyDetailPanel(context, line, detail.notifySchedule),
        const SizedBox(height: 12),
        _buildAutoRefillDetailPanel(
          context,
          line,
          detail.miniRefillSchedule,
          detail.customRefillSchedule,
          isPremium,
        ),
      ],
    );
  }

  Widget _buildTierBadge(String tier) {
    Color getTierColor() {
      switch (tier.toLowerCase()) {
        case 'premium':
          return const Color(0xFFF59E0B);
        case 'standard':
          return AppColors.primary;
        default:
          return Colors.grey;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: getTierColor().withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: getTierColor().withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        tier.toUpperCase(),
        style: TextStyle(
          color: getTierColor(),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAutoNotifyDetailPanel(
    BuildContext context,
    SimLine line,
    ScheduledTopup? schedule,
  ) {
    final isConfigured = schedule != null;
    final isDark = context.isDarkMode;

    if (!isConfigured) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        isActive: false,
        activeColor: AppColors.healthRed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.healthRed,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.autoNotifyDisabled,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.noActiveAlertSchedule,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            if (_isViewer)
              Text(
                AppLocalizations.of(context)!.askOwnerConfigureAlerts,
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () =>
                    _openScheduleSheet(context, line, null, 'notify'),
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  AppLocalizations.of(context)!.configureAutoNotify,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('MMM dd, yyyy');
    final isPausedByHome = line.isHomeMode;
    final displayActive = schedule.isActive && !isPausedByHome;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      isActive: displayActive,
      activeColor: AppColors.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.autoNotifySchedule,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (displayActive
                                  ? AppColors.secondary
                                  : AppColors.warning)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            (displayActive
                                    ? AppColors.secondary
                                    : AppColors.warning)
                                .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      displayActive
                          ? AppLocalizations.of(context)!.activeLabel
                          : (isPausedByHome
                                ? AppLocalizations.of(context)!.pausedHomeMode
                                : AppLocalizations.of(context)!.pausedLabel),
                      style: TextStyle(
                        color: displayActive
                            ? AppColors.secondary
                            : AppColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassToggleSwitch(
                    value: displayActive,
                    activeColor: AppColors.secondary,
                    onChanged: _isViewer || _isToggling || isPausedByHome
                        ? null
                        : (val) =>
                              _handleToggleSchedule(context, schedule.id, val),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildScheduleRowItem(
            context,
            AppLocalizations.of(context)!.renewalCheckInterval,
            schedule.frequencyDays == 0
                ? AppLocalizations.of(context)!.everyHour
                : AppLocalizations.of(
                    context,
                  )!.everyNDays(schedule.frequencyDays),
            Icons.repeat,
          ),
          const SizedBox(height: 12),
          _buildScheduleRowItem(
            context,
            AppLocalizations.of(context)!.nextAlertCheck,
            isPausedByHome
                ? AppLocalizations.of(context)!.pausedHomeMode
                : dateFormat.format(schedule.nextExecutionAt),
            Icons.date_range,
            valueColor: isPausedByHome ? AppColors.warning : null,
          ),
          if (!_isViewer) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14.0),
              child: Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                height: 1,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _openScheduleSheet(context, line, schedule, 'notify'),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: context.onSurfaceColor,
                    ),
                    label: Text(
                      AppLocalizations.of(context)!.editNotificationConfig,
                      style: TextStyle(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  onPressed: () => _showDeleteScheduleConfirmation(
                    context,
                    schedule.id,
                    false,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.error.withValues(alpha: 0.08),
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutoRefillDetailPanel(
    BuildContext context,
    SimLine line,
    ScheduledTopup? miniSchedule,
    ScheduledTopup? customSchedule,
    bool isPremium,
  ) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final isDark = context.isDarkMode;

    // Premium Mini Refill Toggle Card
    final isMiniActive = miniSchedule?.isActive ?? false;
    final includedNextRefillDate = miniSchedule != null
        ? dateFormat.format(miniSchedule.nextExecutionAt)
        : 'Unknown';

    final includedCardGradient = isDark
        ? const LinearGradient(
            colors: [Color(0x22FFD700), Color(0x05FF8C00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xCCF1F8E9), Color(0x99DCEDC8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final includedCardBorder = Border.all(
      color: isDark ? const Color(0x55FFD700) : const Color(0xFF9CCC65),
      width: 1.5,
    );

    final includedCard = GestureDetector(
      onTap: _isViewer || !isPremium || miniSchedule == null
          ? null
          : () {
              HapticHelper.mediumImpact();
              PremiumRefillConfigSheet.show(
                context: context,
                simLineId: line.id,
                simNickname: line.nickname ?? line.phoneNumber,
              );
            },
      child: GlassCard(
        customGradient: includedCardGradient,
        customBorder: includedCardBorder,
        padding: const EdgeInsets.all(20),
        isActive: false,
        activeColor: isMiniActive
            ? AppColors.success
            : AppColors.textTertiaryDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.premiumKeepAliveRefill,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isPremium) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.active,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (miniSchedule != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.onSurfaceColor.withValues(alpha: 0.5),
                    ),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isMiniActive
                  ? AppLocalizations.of(
                      context,
                    )!.autoRefillIncludedText(includedNextRefillDate)
                  : AppLocalizations.of(context)!.premiumKeepAliveDisabled,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );

    // Custom Auto-Refill Card
    final isConfigured = customSchedule != null;
    final isPausedByHome = line.isHomeMode;
    final displayActive =
        customSchedule != null && customSchedule.isActive && !isPausedByHome;

    if (!isConfigured) {
      final unconfiguredCard = GlassCard(
        padding: const EdgeInsets.all(20),
        isActive: false,
        activeColor: AppColors.primaryLight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.primaryLight,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.customAutoRefill,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.addAdditionalScheduledRecharge,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            if (_isViewer)
              Text(
                AppLocalizations.of(context)!.askOwnerConfigureRefill,
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  if (!isPremium) {
                    HapticHelper.mediumImpact();
                    LineUpgradeSheet.show(context: context, simLine: line);
                    return;
                  }
                  _openScheduleSheet(context, line, null, 'refill');
                },
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: Text(
                  AppLocalizations.of(context)!.configureCustomAutoRefill,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      );
      return Column(
        children: [includedCard, const SizedBox(height: 20), unconfiguredCard],
      );
    }

    final customConfiguredCard = GlassCard(
      padding: const EdgeInsets.all(20),
      isActive: displayActive,
      activeColor: AppColors.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.customAutoRefill,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (displayActive
                                  ? AppColors.secondary
                                  : AppColors.warning)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            (displayActive
                                    ? AppColors.secondary
                                    : AppColors.warning)
                                .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      displayActive
                          ? AppLocalizations.of(context)!.activeLabel
                          : (isPausedByHome
                                ? AppLocalizations.of(context)!.pausedHomeMode
                                : AppLocalizations.of(context)!.pausedLabel),
                      style: TextStyle(
                        color: displayActive
                            ? AppColors.secondary
                            : AppColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassToggleSwitch(
                    value: displayActive && isPremium,
                    activeColor: AppColors.secondary,
                    onChanged: _isViewer || _isToggling || isPausedByHome
                        ? null
                        : (val) {
                            if (!isPremium) {
                              HapticHelper.mediumImpact();
                              LineUpgradeSheet.show(
                                context: context,
                                simLine: line,
                              );
                              return;
                            }
                            _handleToggleSchedule(
                              context,
                              customSchedule.id,
                              val,
                            );
                          },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildScheduleRowItem(
            context,
            AppLocalizations.of(context)!.rechargeAmount,
            '\$${customSchedule.amount.toStringAsFixed(2)} ${customSchedule.currency}',
            Icons.monetization_on_outlined,
          ),
          const SizedBox(height: 12),
          _buildScheduleRowItem(
            context,
            AppLocalizations.of(context)!.refillInterval,
            customSchedule.frequencyDays == 0
                ? AppLocalizations.of(context)!.everyHour
                : AppLocalizations.of(
                    context,
                  )!.everyNDays(customSchedule.frequencyDays),
            Icons.repeat,
          ),
          const SizedBox(height: 12),
          _buildScheduleRowItem(
            context,
            AppLocalizations.of(context)!.nextRefillDue,
            isPausedByHome
                ? AppLocalizations.of(context)!.pausedHomeMode
                : dateFormat.format(customSchedule.nextExecutionAt),
            Icons.date_range,
            valueColor: isPausedByHome ? AppColors.warning : null,
          ),
          if (customSchedule.retryCount > 0) ...[
            const SizedBox(height: 12),
            _buildScheduleRowItem(
              context,
              AppLocalizations.of(context)!.failedRefillAttempts,
              AppLocalizations.of(
                context,
              )!.retriesCount(customSchedule.retryCount),
              Icons.warning_amber_rounded,
              valueColor: AppColors.healthRed,
            ),
          ],
          if (!_isViewer) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14.0),
              child: Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                height: 1,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (!isPremium) {
                        HapticHelper.mediumImpact();
                        LineUpgradeSheet.show(context: context, simLine: line);
                        return;
                      }
                      _openScheduleSheet(
                        context,
                        line,
                        customSchedule,
                        'refill',
                      );
                    },
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: context.onSurfaceColor,
                    ),
                    label: Text(
                      AppLocalizations.of(context)!.editRefillAmount,
                      style: TextStyle(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  onPressed: () => _showDeleteScheduleConfirmation(
                    context,
                    customSchedule.id,
                    true,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.error.withValues(alpha: 0.08),
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return Column(
      children: [
        includedCard,
        const SizedBox(height: 20),
        customConfiguredCard,
      ],
    );
  }

  Widget _buildScheduleRowItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    final isDark = context.isDarkMode;
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark
              ? AppColors.textTertiaryDark
              : AppColors.textTertiaryLight,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: valueColor ?? context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── 4. Refill Executions History ───────────────────────────────────────────
  Widget _buildExecutionsSection(
    BuildContext context,
    SimLineDetailState detail,
  ) {
    final isPremium = detail.simLine.protectionTier.toLowerCase() == 'premium';
    final isDark = context.isDarkMode;

    if (!isPremium) {
      return const SizedBox.shrink();
    }

    final list = detail.executions
        .where((ex) {
          final txId = ex.reloadlyTransactionId;
          if (txId != null && txId.toUpperCase().contains('MOCK')) {
            return false;
          }
          return true;
        })
        .take(5)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPremium
                ? AppLocalizations.of(context)!.refillExecutionsHistory
                : AppLocalizations.of(context)!.renewalExecutionsHistory,
            style: AppTextStyles.titleLarge.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                isPremium
                    ? AppLocalizations.of(context)!.noHistoricalTopup
                    : AppLocalizations.of(context)!.noHistoricalRenewal,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (context, index) => Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                height: 16,
              ),
              itemBuilder: (context, index) {
                final ex = list[index];
                final isSuccess = ex.status == 'success';
                final targetDate = ex.executedAt ?? ex.executionTime ?? ex.createdAt ?? DateTime.now();
                final dateStr = DateFormat(
                  'MMM dd, yyyy HH:mm',
                ).format(targetDate);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isSuccess ? AppColors.success : AppColors.error)
                            .withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuccess
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: isSuccess ? AppColors.success : AppColors.error,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Detail info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '\$${ex.amount.toStringAsFixed(2)} ${ex.currency}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: context.onSurfaceColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isSuccess
                                              ? AppColors.success
                                              : AppColors.error)
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ex.status.toUpperCase(),
                                  style: TextStyle(
                                    color: isSuccess
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: AppTextStyles.caption.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                          ),
                          if (ex.reloadlyTransactionId != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Tx ID: ${ex.reloadlyTransactionId}',
                              style: AppTextStyles.caption.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                          if (!isSuccess && ex.failureReason != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reason: ${ex.failureReason}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.error,
                                    ),
                                  ),
                                  if (!_isViewer) ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 28,
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _handleRetryFailedTopup(
                                              context,
                                              ex.id,
                                            ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.error,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.retryConnection,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          if (list.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticHelper.lightTick();
                  context.goNamed(
                    'simLineExecutions',
                    pathParameters: {'id': detail.simLine.id},
                  );
                },
                icon: Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: isDark
                      ? AppColors.primaryLight
                      : AppColors.lightPrimary,
                ),
                label: Text(
                  AppLocalizations.of(context)!.viewAllHistory,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.primaryLight
                        : AppColors.lightPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 5. Activity Logs Timeline UI ───────────────────────────────────────────
  Widget _buildTimelineSection(
    BuildContext context,
    SimLineDetailState detail,
  ) {
    final isDark = context.isDarkMode;
    final list = detail.activityLogs
        .where((log) {
          if (log.metadata['is_mock'] == true ||
              log.metadata['is_mock'] == 'true' ||
              (log.description != null &&
                  log.description!.toUpperCase().contains('MOCK'))) {
            return false;
          }
          return true;
        })
        .take(13)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.securityActivityLogs,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (list.isNotEmpty && !_isViewer)
                TextButton.icon(
                  onPressed: () => _handleCleanMockLogs(context),
                  icon: Icon(
                    Icons.cleaning_services,
                    size: 14,
                    color: isDark
                        ? AppColors.primaryLight
                        : AppColors.lightPrimary,
                  ),
                  label: Text(
                    AppLocalizations.of(context)!.clearLogs,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.primaryLight
                          : AppColors.lightPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                AppLocalizations.of(context)!.noActivityLogsRecorded,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final log = list[index];
                final isLast = index == list.length - 1;

                Color iconColor = isDark
                    ? AppColors.primaryLight
                    : AppColors.lightPrimary;
                IconData iconData = Icons.info_outline;

                if (log.eventType == 'topup_success') {
                  iconColor = AppColors.success;
                  iconData = Icons.check_circle_outline;
                } else if (log.eventType == 'topup_failed') {
                  iconColor = AppColors.error;
                  iconData = Icons.error_outline;
                } else if (log.eventType == 'health_update') {
                  iconColor = isDark
                      ? AppColors.secondary
                      : AppColors.lightSecondary;
                  iconData = Icons.shield_outlined;
                } else if (log.eventType == 'created') {
                  iconColor = isDark
                      ? AppColors.primaryLight
                      : AppColors.lightPrimary;
                  iconData = Icons.add_box_outlined;
                }

                final dateStr = DateFormat(
                  'MMM dd, yyyy HH:mm',
                ).format(log.createdAt);

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Timeline connecting indicators
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: iconColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(iconData, color: iconColor, size: 16),
                          ),
                          Expanded(
                            child: isLast
                                ? const SizedBox(height: 20)
                                : Container(
                                    width: 2,
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Text Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.description ?? '',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: context.onSurfaceColor,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: AppTextStyles.caption.copyWith(
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      // Actions
                      if (!_isViewer)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                              size: 18,
                            ),
                            onPressed: () =>
                                _handleDeleteActivityLog(context, log.id),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Action Handlers ────────────────────────────────────────────────────────
  void _openScheduleSheet(
    BuildContext context,
    SimLine line,
    ScheduledTopup? existingSchedule,
    String configMode,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduledTopupSheet(
        simLineId: line.id,
        simNickname: line.nickname ?? line.phoneNumber,
        existingSchedule: existingSchedule,
        configMode: configMode,
      ),
    );
  }

  Future<void> _handleToggleSchedule(
    BuildContext context,
    String scheduleId,
    bool isActive,
  ) async {
    setState(() {
      _isToggling = true;
    });

    try {
      final result = await ref
          .read(scheduledTopupControllerProvider.notifier)
          .toggleActive(scheduleId, isActive);
      if (result is Success<ScheduledTopup>) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                )!.autoRenewalStatusUpdated(isActive ? 'enabled' : 'paused'),
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else if (result is Failure<ScheduledTopup>) {
        throw Exception(result.error.message);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.failedToUpdateSchedule(e.toString()),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isToggling = false;
        });
      }
    }
  }



  void _showDeleteScheduleConfirmation(
    BuildContext context,
    String scheduleId,
    bool isPremium,
  ) {
    final isDark = context.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)!.removeScheduleTitle,
              style: AppTextStyles.headlineSmall.copyWith(
                color: context.onSurfaceColor,
              ),
            ),
          ],
        ),
        content: Text(
          isPremium
              ? AppLocalizations.of(context)!.confirmDeleteAutoRefill
              : AppLocalizations.of(context)!.confirmDeleteAutoRenewal,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Since they are now two completely separate database records,
                // deleting either Auto-Notify or Auto-Refill simply removes its specific record completely!
                final result = await ref
                    .read(scheduledTopupControllerProvider.notifier)
                    .removeSchedule(scheduleId);
                if (result is Success<void>) {
                  ref.invalidate(simLineDetailControllerProvider(widget.id));
                  ref.invalidate(simLinesControllerProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isPremium
                              ? AppLocalizations.of(context)!.autoRefillRemoved
                              : AppLocalizations.of(
                                  context,
                                )!.autoRenewalRemoved,
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } else if (result is Failure<void>) {
                  throw Exception(result.error.message);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(
                          context,
                        )!.failedToDeleteSchedule(e.toString()),
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(
              AppLocalizations.of(context)!.deleteButton,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRetryFailedTopup(
    BuildContext context,
    String executionId,
  ) async {
    try {
      final result = await ref
          .read(simLineDetailControllerProvider(widget.id).notifier)
          .retryFailedTopup(executionId);
      if (context.mounted) {
        if (result is Success<void>) {
          final detailState = ref
              .read(simLineDetailControllerProvider(widget.id))
              .value;
          final isPremium =
              detailState?.simLine.protectionTier.toLowerCase() == 'premium';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isPremium
                    ? AppLocalizations.of(context)!.refillRetrySuccess
                    : AppLocalizations.of(context)!.renewalRetrySuccess,
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (result is Failure<void>) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.retryFailed(result.error.message),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.retryExecutionError(e.toString()),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteActivityLog(
    BuildContext context,
    String logId,
  ) async {
    try {
      await ref
          .read(simLineDetailControllerProvider(widget.id).notifier)
          .deleteActivityLog(logId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.activityLogDeleted),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.failedToDeleteActivityLog(e.toString()),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleCleanMockLogs(BuildContext context) async {
    try {
      await ref
          .read(simLineDetailControllerProvider(widget.id).notifier)
          .clearAllActivityLogs();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.activityLogsCleared),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.failedToClearActivityLogs(e.toString()),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _handleVerifyLineActivity(BuildContext context, SimLine simLine) {
    HapticHelper.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NumberVerificationDialog(
        simLineId: simLine.id,
        phoneNumber: simLine.phoneNumber,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, SimLine line) {
    final isDark = context.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)!.removeProtectionTitle,
              style: AppTextStyles.headlineSmall.copyWith(
                color: context.onSurfaceColor,
              ),
            ),
          ],
        ),
        content: Text(
          AppLocalizations.of(
            context,
          )!.confirmRemoveProtectionDesc(line.nickname ?? line.phoneNumber),
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Dismiss the confirm dialog

              final goRouter = GoRouter.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              // Instantly navigate back to the Home Page to prevent this screen
              // from rebuilding with a "SIM Line not found" error when the deletion completes.
              goRouter.go(AppRoutes.home);

              try {
                await ref
                    .read(simLinesControllerProvider.notifier)
                    .deleteSimLine(line.id);

                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)!.simLineProtectionRemoved,
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(
                        context,
                      )!.failedToDeleteSimLine(e.toString()),
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(
              AppLocalizations.of(context)!.deleteButton,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNicknameDialog(BuildContext context, SimLine line) {
    final isDark = context.isDarkMode;
    final controller = TextEditingController(text: line.nickname ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  color: isDark
                      ? AppColors.primaryLight
                      : AppColors.lightPrimary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.editSimNameTitle,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: context.onSurfaceColor,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.enterNicknameInstruction,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: context.onSurfaceColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.nicknameExampleHint,
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurface
                        : const Color(0xFFEAEEF1),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.primary
                            : AppColors.lightPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context)!.cancel,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() {
                          isSaving = true;
                        });
                        try {
                          final updatedLine = line.copyWith(
                            nickname: controller.text.trim().isNotEmpty
                                ? controller.text.trim()
                                : null,
                          );

                          await ref
                              .read(simLinesControllerProvider.notifier)
                              .updateSimLine(updatedLine);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.simNameUpdatedSuccess,
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setState(() {
                              isSaving = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.failedToUpdateSimName(e.toString()),
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        AppLocalizations.of(context)!.saveButton,
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
