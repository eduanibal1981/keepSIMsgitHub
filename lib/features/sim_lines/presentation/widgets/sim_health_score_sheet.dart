import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/domain/sim_line_health.dart';

/// Modal bottom sheet displaying the detailed breakdown of the SIM Health score.
///
/// Shows which of the 4 protection pillars (25 points each, up to 100 max)
/// the line has achieved (with a green checkmark) and which are not achieved
/// (with a prominent light-red font label).
class SimHealthScoreSheet extends StatelessWidget {
  final SimLine line;
  final List<HealthScorePillar> pillars;
  final int score;
  final String? tier;
  final String? countryName;
  final VoidCallback? onVerify;
  final VoidCallback? onConfigureNotify;
  final VoidCallback? onConfigureRefill;
  final VoidCallback? onUpdateRecharge;

  const SimHealthScoreSheet({
    super.key,
    required this.line,
    required this.pillars,
    required this.score,
    this.tier,
    this.countryName,
    this.onVerify,
    this.onConfigureNotify,
    this.onConfigureRefill,
    this.onUpdateRecharge,
  });

  /// Displays the [SimHealthScoreSheet] modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required SimLine line,
    required List<HealthScorePillar> pillars,
    required int score,
    String? tier,
    String? countryName,
    VoidCallback? onVerify,
    VoidCallback? onConfigureNotify,
    VoidCallback? onConfigureRefill,
    VoidCallback? onUpdateRecharge,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SimHealthScoreSheet(
        line: line,
        pillars: pillars,
        score: score,
        tier: tier,
        countryName: countryName,
        onVerify: onVerify,
        onConfigureNotify: onConfigureNotify,
        onConfigureRefill: onConfigureRefill,
        onUpdateRecharge: onUpdateRecharge,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    Color scoreColor;
    String scoreStatusLabel;
    if (score >= 75) {
      scoreColor = AppColors.healthGreen;
      scoreStatusLabel = 'Strong Protection';
    } else if (score >= 50) {
      scoreColor = AppColors.healthAmber;
      scoreStatusLabel = 'Moderate Protection';
    } else {
      scoreColor = AppColors.healthRed;
      scoreStatusLabel = 'Critical Attention Needed';
    }

    final String displayTier = (tier == null || tier!.isEmpty)
        ? 'Standard'
        : (tier![0].toUpperCase() + tier!.substring(1));
    final String locationText = countryName != null && countryName!.isNotEmpty
        ? '$displayTier · $countryName'
        : displayTier;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141C28) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: scoreColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SIM Health Breakdown',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: context.onSurfaceColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          locationText,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Score Summary Card
                    _buildScoreSummaryCard(
                      context: context,
                      isDark: isDark,
                      score: score,
                      scoreColor: scoreColor,
                      statusLabel: scoreStatusLabel,
                    ),
                    const SizedBox(height: 20),

                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PROTECTION PILLARS (3)',
                          style: AppTextStyles.caption.copyWith(
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : const Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '100 pts total',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : const Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // List of 3 Pillars
                    ...pillars.map((pillar) {
                      VoidCallback? action;
                      switch (pillar.type) {
                        case HealthScorePillarType.realLiveVerification:
                          action = onVerify;
                          break;
                        case HealthScorePillarType.autoNotify:
                          action = onConfigureNotify;
                          break;
                        case HealthScorePillarType.recentRecharge:
                          action = onUpdateRecharge;
                          break;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPillarCard(
                          context: context,
                          isDark: isDark,
                          pillar: pillar,
                          onAction: action,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Footer Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    foregroundColor: context.onSurfaceColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: context.onSurfaceColor,
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

  /// Builds the top hero card showing the overall score, circular indicator, and description.
  Widget _buildScoreSummaryCard({
    required BuildContext context,
    required bool isDark,
    required int score,
    required Color scoreColor,
    required String statusLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2433) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF28364B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          // Circular Health Indicator
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100.0,
                  strokeWidth: 5.5,
                  backgroundColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'HEALTH',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Score summary labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$score',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w900,
                        color: context.onSurfaceColor,
                        fontSize: 22,
                      ),
                    ),
                    Text(
                      ' / 100 pts',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Three core safeguards protect your line: Real Live Verification (25 pts), Auto-Notify Alerts (25 pts), and Active Recharge Window (50 pts).',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single pillar card showing achieved (green check) or non-achieved (light-red font label).
  Widget _buildPillarCard({
    required BuildContext context,
    required bool isDark,
    required HealthScorePillar pillar,
    required VoidCallback? onAction,
  }) {
    final bool achieved = pillar.isAchieved;

    // Green styling for achieved items
    const Color greenAccent = Color(0xFF10B981);
    final Color greenBg = const Color(0xFF10B981).withValues(alpha: 0.12);
    final Color greenBorder = const Color(0xFF10B981).withValues(alpha: 0.35);

    // Light-red styling for non-achieved items (high readability on both dark and light modes)
    final Color lightRedFont = isDark
        ? const Color(0xFFFF8A80) // Soft glowing light red for dark mode
        : const Color(0xFFE53935); // Vivid light red for crisp light mode contrast
    final Color lightRedBg = lightRedFont.withValues(alpha: 0.12);
    final Color lightRedBorder = lightRedFont.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182234) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: achieved
              ? (isDark ? const Color(0xFF1E3A34) : const Color(0xFFD1FAE5))
              : (isDark ? const Color(0xFF3B2428) : const Color(0xFFFFE4E6)),
          width: 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon + Title + Status Label
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pillar icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: achieved ? greenBg : lightRedBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: achieved ? greenBorder : lightRedBorder,
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  pillar.icon,
                  color: achieved ? greenAccent : lightRedFont,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              // Pillar title & points
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pillar.title,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.onSurfaceColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pillar.earnedPoints} / ${pillar.maxPoints} pts',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: achieved ? greenAccent : lightRedFont,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge (Check green OR Light Red font label)
              if (achieved)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: greenBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: greenBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: greenAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+${pillar.earnedPoints} pts',
                        style: const TextStyle(
                          color: greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: lightRedBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: lightRedBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: lightRedFont,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Not achieved',
                        style: TextStyle(
                          color: lightRedFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: Description text
          Text(
            pillar.description,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? (achieved ? AppColors.textSecondaryDark : const Color(0xFFF87171))
                  : (achieved ? const Color(0xFF475569) : const Color(0xFFDC2626)),
              fontSize: 12,
              height: 1.35,
            ),
          ),

          // Row 3: Action button (if not achieved and action is available)
          if (!achieved && onAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  onAction();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? lightRedFont.withValues(alpha: 0.15)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: lightRedFont.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pillar.actionLabel,
                        style: TextStyle(
                          color: lightRedFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: lightRedFont,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
