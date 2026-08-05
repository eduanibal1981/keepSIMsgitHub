import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_self_service_model.dart';
import 'package:keep_sims/features/sim_lines/domain/carrier_rule_advice.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// The whole truth about one carrier's deactivation rules, and an opinion.
///
/// The plan cards quote a price. This says what the price is *for*: the exact
/// window the carrier reclaims a number in, whether there is a recovery period
/// after it, what a top-up has to be worth to count, how often we would refill
/// — and then, plainly, whether buying anything from us is the right move.
///
/// It is allowed to say no. On a `usage_required` carrier the verdict is "keep
/// your money", and on a long-window carrier it is "Standard is enough". A
/// screen that could only ever argue for the upgrade would not be worth opening.
class CarrierRulesSheet extends ConsumerWidget {
  const CarrierRulesSheet({
    super.key,
    required this.rule,
    required this.carrierId,
    this.carrierName,
    this.countryName,
    this.premiumYearlyTotal,
  });

  final CarrierRule rule;

  /// Needed for the operator's own self-service row. The rules themselves come
  /// from [rule], so the sheet still renders in full if that lookup is empty.
  final String carrierId;

  final String? carrierName;
  final String? countryName;

  /// The single up-front charge for a year of Premium, already computed by the
  /// caller. Null while the config providers are loading — in which case the
  /// money comparison is omitted rather than guessed at.
  final double? premiumYearlyTotal;

  static Future<void> show({
    required BuildContext context,
    required CarrierRule rule,
    required String carrierId,
    String? carrierName,
    String? countryName,
    double? premiumYearlyTotal,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CarrierRulesSheet(
        rule: rule,
        carrierId: carrierId,
        carrierName: carrierName,
        countryName: countryName,
        premiumYearlyTotal: premiumYearlyTotal,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    final operator = carrierName ?? l10n.carrierActivityFallbackOperator;
    final advice = CarrierRuleAdvice.of(
      rule,
      premiumYearlyTotal: premiumYearlyTotal,
    );
    final selfService = ref.watch(carrierSelfServiceProvider(carrierId)).value;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              l10n.carrierRulesSheetTitle,
              style: AppTextStyles.headlineMedium.copyWith(
                color: context.onSurfaceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              countryName == null ? operator : '$operator · $countryName',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),

            // The answer first — it is what the user tapped the link for.
            _verdictCard(context, l10n, advice, isDark),
            const SizedBox(height: 20),

            _sectionTitle(context, l10n.carrierRulesHowTitle(operator)),
            const SizedBox(height: 8),
            Text(
              _howItDecides(l10n, operator),
              style: _bodyStyle(context, isDark),
            ),
            // The operator's own wording, unparaphrased, same contract as
            // CarrierActivityNotice: carrier terms are not content we own.
            if (rule.activityRequirementNote != null) ...[
              const SizedBox(height: 8),
              Text(
                rule.activityRequirementNote!,
                style: AppTextStyles.caption.copyWith(
                  color: context.onSurfaceColor.withValues(alpha: 0.55),
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 20),

            _sectionTitle(context, l10n.carrierRulesNumbersTitle),
            const SizedBox(height: 10),
            ..._numberRows(context, l10n, advice, isDark),
            const SizedBox(height: 20),

            _selfServiceCard(context, ref, l10n, operator, selfService, isDark),

            if (rule.ruleSourceUrl != null) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _open(rule.ruleSourceUrl!),
                child: Row(
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: context.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.carrierRulesSourceLink,
                        style: AppTextStyles.caption.copyWith(
                          color: context.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            Text(
              l10n.carrierRulesDisclaimer,
              style: AppTextStyles.caption.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.45),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n.close,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.onSurfaceColor.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------

  String _howItDecides(AppLocalizations l10n, String operator) {
    if (rule.requiresHumanUsage) return l10n.carrierUsageRequiredBody(operator);
    if (rule.requiresQualifyingDenomination) {
      return l10n.carrierMinDenominationBody(
        operator,
        _money(rule.validityQualifyingTopupAmount ?? rule.minimumTopupAmount),
        rule.inappPricingCurrency.toUpperCase(),
      );
    }
    return l10n.carrierRechargeOkBody(operator);
  }

  Widget _verdictCard(
    BuildContext context,
    AppLocalizations l10n,
    CarrierPlanAdvice advice,
    bool isDark,
  ) {
    final (title, body, accent, icon) = switch (advice.verdict) {
      PlanVerdict.selfServiceOnly => (
        l10n.carrierVerdictSelfServiceTitle,
        l10n.carrierVerdictSelfServiceBody,
        isDark ? AppColors.error : Colors.redAccent,
        Icons.block_rounded,
      ),
      PlanVerdict.standardIsEnough => (
        l10n.carrierVerdictStandardTitle,
        l10n.carrierVerdictStandardBody,
        isDark ? Colors.lightBlueAccent : Colors.blue,
        Icons.savings_rounded,
      ),
      PlanVerdict.premiumWorthIt => (
        l10n.carrierVerdictPremiumWorthTitle,
        l10n.carrierVerdictPremiumWorthBody,
        isDark ? Colors.purpleAccent : Colors.purple,
        Icons.workspace_premium_rounded,
      ),
      PlanVerdict.premiumStronglyAdvised => (
        l10n.carrierVerdictPremiumMustTitle,
        l10n.carrierVerdictPremiumMustBody,
        isDark ? Colors.amberAccent : Colors.orange.shade800,
        Icons.priority_high_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: _bodyStyle(context, isDark)),
          if (advice.reasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...advice.reasons.map((r) {
              final text = _reasonText(l10n, advice, r);
              if (text == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Icon(
                        Icons.circle,
                        size: 5,
                        color: accent.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.onSurfaceColor.withValues(alpha: 0.8),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String? _reasonText(
    AppLocalizations l10n,
    CarrierPlanAdvice advice,
    AdviceReason reason,
  ) {
    switch (reason) {
      case AdviceReason.usageOnlyResetsClock:
        return l10n.carrierReasonUsageOnly;
      case AdviceReason.qualifyingDenomination:
        return l10n.carrierReasonQualifying(
          _money(advice.qualifyingAmount),
          advice.currency,
        );
      case AdviceReason.shortWindow:
        return l10n.carrierReasonShortWindow(advice.deactivationWindowDays);
      case AdviceReason.longWindow:
        return l10n.carrierReasonLongWindow(advice.deactivationWindowDays);
      case AdviceReason.noGracePeriod:
        return l10n.carrierReasonNoGrace;
      case AdviceReason.graceCushion:
        return l10n.carrierReasonGrace(advice.gracePeriodDays);
      case AdviceReason.automationCostsExtra:
        final self = advice.selfServiceYearlyCost;
        final premium = advice.premiumYearlyTotal;
        final extra = advice.automationCost;
        // Guarded rather than assumed: the engine only adds this reason when a
        // premium quote exists, but a caller could still hand it a rule whose
        // self-service side is unknown.
        if (self == null || premium == null || extra == null) return null;
        return l10n.carrierReasonAutomationCost(
          '${_money(self)} ${advice.currency}',
          '${_money(premium)} ${advice.currency}',
          '${_money(extra)} ${advice.currency}',
        );
    }
  }

  List<Widget> _numberRows(
    BuildContext context,
    AppLocalizations l10n,
    CarrierPlanAdvice advice,
    bool isDark,
  ) {
    final rows = <(IconData, String)>[
      (
        Icons.event_busy_rounded,
        l10n.carrierRulesWindowRow(advice.deactivationWindowDays),
      ),
      if (advice.gracePeriodDays > 0)
        (
          Icons.restore_rounded,
          l10n.carrierRulesGraceRow(advice.gracePeriodDays),
        )
      else
        (Icons.do_not_disturb_on_rounded, l10n.carrierRulesNoGraceRow),
      (
        Icons.payments_rounded,
        l10n.carrierRulesMinTopupRow(
          _money(advice.qualifyingAmount),
          advice.currency,
        ),
      ),
      // Hidden for usage_required: quoting a cadence for a carrier no cadence
      // can save reads as a promise.
      if (!advice.premiumIsPointless)
        (
          Icons.autorenew_rounded,
          l10n.carrierRulesCadenceRow(
            advice.refillIntervalDays,
            advice.refillsPerYear,
          ),
        ),
    ];

    return rows
        .map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  row.$1,
                  size: 16,
                  color: context.onSurfaceColor.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(row.$2, style: _bodyStyle(context, isDark))),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _selfServiceCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String operator,
    CarrierSelfService? selfService,
    bool isDark,
  ) {
    // Only an iOS build should be sent to the App Store; everything else,
    // including the web build, goes to Play. Guarded because Platform throws on
    // web.
    final preferIos = !kIsWeb && Platform.isIOS;
    final verifiedLink = selfService?.verifiedLink(preferIos: preferIos);
    final searchUrl =
        selfService?.storeSearchUrl(
          carrierName: carrierName ?? operator,
          preferIos: preferIos,
        ) ??
        _fallbackSearchUrl(carrierName ?? operator, preferIos: preferIos);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storefront_rounded,
                size: 18,
                color: context.onSurfaceColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.carrierSelfServiceTitle(operator),
                  style: AppTextStyles.titleMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.carrierSelfServiceBody, style: _bodyStyle(context, isDark)),
          if (countryName != null) ...[
            const SizedBox(height: 6),
            Text(
              l10n.carrierSelfServiceCountryLine(countryName!),
              style: AppTextStyles.caption.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.55),
              ),
            ),
          ],
          if (selfService?.appName != null) ...[
            const SizedBox(height: 6),
            Text(
              l10n.carrierSelfServiceAppHint(selfService!.appName!),
              style: AppTextStyles.caption.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (selfService?.note != null) ...[
            const SizedBox(height: 6),
            Text(
              selfService!.note!,
              style: AppTextStyles.caption.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.55),
                height: 1.35,
              ),
            ),
          ],

          // The caution is not decoration. carrier_self_service ships with
          // verified_at NULL on every row, and a prepaid operator's app is one
          // of the most impersonated listings in either store.
          if (verifiedLink == null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: isDark ? Colors.amberAccent : Colors.orange.shade800,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.carrierSelfServiceUnverified(operator),
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? Colors.amberAccent
                          : Colors.orange.shade800,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (verifiedLink != null)
                _action(
                  context,
                  Icons.launch_rounded,
                  l10n.carrierSelfServiceOpenApp,
                  () => _open(verifiedLink),
                )
              else
                _action(
                  context,
                  Icons.search_rounded,
                  l10n.carrierSelfServiceSearchStore,
                  () => _open(searchUrl),
                ),
              if (selfService?.isVerified == true &&
                  selfService?.webTopupUrl != null)
                _action(
                  context,
                  Icons.language_rounded,
                  l10n.carrierSelfServiceWeb,
                  () => _open(selfService!.webTopupUrl!),
                ),
            ],
          ),

          if (selfService?.ussdCode != null) ...[
            const SizedBox(height: 10),
            Text(
              l10n.carrierSelfServiceUssd(selfService!.ussdCode!),
              style: AppTextStyles.caption.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.primaryColor,
        side: BorderSide(color: context.primaryColor.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
    text.toUpperCase(),
    style: AppTextStyles.caption.copyWith(
      color: context.onSurfaceColor.withValues(alpha: 0.5),
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    ),
  );

  TextStyle _bodyStyle(BuildContext context, bool isDark) =>
      AppTextStyles.bodyMedium.copyWith(
        color: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
        height: 1.4,
      );

  static String _fallbackSearchUrl(String carrier, {required bool preferIos}) {
    final term = Uri.encodeQueryComponent(carrier);
    return preferIos
        ? 'https://apps.apple.com/search?term=$term'
        : 'https://play.google.com/store/search?q=$term&c=apps';
  }

  static String _money(double v) => v.toStringAsFixed(2);

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Failure is silent on purpose: this is an advisory link, and a snackbar
    // needs a context that may already be gone by the time the platform answers.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
