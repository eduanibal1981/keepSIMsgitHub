/// One row of the eSIM comparison.
///
/// The card's job is to make the rail obvious at a glance. A user scanning a
/// ranked list must never be surprised that tapping sent them to another
/// company's checkout, so the distinction is carried three ways — a badge, the
/// button verb, and an arrow glyph — rather than resting on any one of them.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class CompareOfferCard extends StatelessWidget {
  const CompareOfferCard({
    super.key,
    required this.offer,
    required this.onPressed,
    this.isBestValue = false,
  });

  final CompareOffer offer;
  final VoidCallback onPressed;
  final bool isBestValue;

  static String countryFlag(String code) {
    if (code.length != 2) return '🌐';
    final a = code.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final b = code.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(a) + String.fromCharCode(b);
  }

  /// Displays the tier / FUP speed for unlimited or DayPass plans.
  String? get _speedLabel {
    if (!offer.isUnlimited) return null;
    if (offer.speedTierRaw != null && offer.speedTierRaw!.startsWith('high-')) {
      return offer.speedTierRaw;
    }
    switch (offer.speedTier) {
      case OfferSpeedTier.lite:
        return 'Lite';
      case OfferSpeedTier.essential:
        return 'Essential';
      case OfferSpeedTier.plus:
        return 'Plus';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    final isPartner = offer.isAffiliate;

    return Material(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isBestValue
                  ? const Color(0xFF10B981)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isBestValue ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sourceRow(context, l10n, isPartner),
              const SizedBox(height: 12),
              _specsAndPrice(context, l10n),
              if (offer.couponCode != null && offer.couponCode!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _couponRow(context, l10n),
              ],
              const SizedBox(height: 14),
              _cta(context, l10n, isPartner),
            ],
          ),
        ),
      ),
    );
  }

  // ── Who is selling this, and on which rail ──────────────────────────────
  Widget _sourceRow(
      BuildContext context, AppLocalizations l10n, bool isPartner) {
    final primaryCountry =
        offer.countries.isNotEmpty ? offer.countries.first : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      offer.sourceName,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (offer.typeTag != null) ...[
                    const SizedBox(width: 8),
                    _tagBadge(offer.typeTag!),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (primaryCountry != null)
                    Text(countryFlag(primaryCountry),
                        style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      offer.countryCount > 1
                          ? '${offer.countryCount} ${l10n.compareCountriesSuffix}'
                          : (primaryCountry ?? ''),
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: context.onSurfaceColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _railBadge(context, l10n, isPartner),
            if (isBestValue) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.bestValueBadge,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _railBadge(
      BuildContext context, AppLocalizations l10n, bool isPartner) {
    final colour = isPartner ? const Color(0xFF8B5CF6) : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPartner ? Icons.open_in_new_rounded : Icons.bolt_rounded,
            size: 12,
            color: colour,
          ),
          const SizedBox(width: 4),
          Text(
            isPartner ? l10n.comparePartnerSite : l10n.compareBuyInApp,
            style: AppTextStyles.labelSmall.copyWith(
              color: colour,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagBadge(String tag) {
    final isDayPass = tag == 'DayPass';
    final bg = isDayPass
        ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
        : const Color(0xFF0EA5E9).withValues(alpha: 0.12);
    final border = isDayPass
        ? const Color(0xFFF59E0B).withValues(alpha: 0.40)
        : const Color(0xFF0EA5E9).withValues(alpha: 0.40);
    final fg = isDayPass ? const Color(0xFFD97706) : const Color(0xFF0284C7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDayPass ? Icons.wb_sunny_outlined : Icons.inventory_2_outlined,
            size: 10,
            color: fg,
          ),
          const SizedBox(width: 3.5),
          Text(
            tag,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: fg,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Data / validity / price ─────────────────────────────────────────────
  Widget _specsAndPrice(BuildContext context, AppLocalizations l10n) {
    final speed = _speedLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _spec(context, l10n.compareDataLabel, offer.formattedData,
            trailing: speed),
        const SizedBox(width: 20),
        _spec(context, l10n.compareValidityLabel,
            '${offer.durationDays} ${l10n.compareDaysSuffix}'),
        const Spacer(),
        _price(context, l10n),
      ],
    );
  }

  Widget _spec(BuildContext context, String label, String value,
      {String? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: context.onSurfaceColor.withValues(alpha: 0.5),
            fontSize: 9,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              value,
              style: AppTextStyles.bodyLarge.copyWith(
                color: context.onSurfaceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trailing,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _price(BuildContext context, AppLocalizations l10n) {
    // A hand-entered partner price past its check-by date is not quoted. The
    // offer still shows — the partner may well be the best deal — but we do
    // not print a number about someone else's shop that we can no longer
    // stand behind.
    if (!offer.canQuotePrice) {
      return Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l10n.comparePriceAtPartner,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (offer.listPriceUsd != null && offer.listPriceUsd! > offer.priceUsd)
          Text(
            '\$${offer.listPriceUsd!.toStringAsFixed(2)}',
            style: AppTextStyles.caption.copyWith(
              color: context.onSurfaceColor.withValues(alpha: 0.45),
              decoration: TextDecoration.lineThrough,
            ),
          ),
        Text(
          '\$${offer.priceUsd.toStringAsFixed(2)}',
          style: AppTextStyles.headlineSmall.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        // G11: secondary, approximate, never on a commit control.
        ApproxLocalText(offer.priceUsd, textAlign: TextAlign.end),
        // NULL for unlimited, and it stays absent rather than rendering
        // "$0.00 / GB" — the server sends NULL precisely so this cannot lie.
        if (offer.pricePerGbUsd != null)
          Text(
            '\$${offer.pricePerGbUsd!.toStringAsFixed(2)} ${l10n.perGb}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  // ── Discount code ───────────────────────────────────────────────────────
  Widget _couponRow(BuildContext context, AppLocalizations l10n) {
    final code = offer.couponCode!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined,
              size: 15, color: Color(0xFF059669)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              offer.couponDescription?.isNotEmpty == true
                  ? offer.couponDescription!
                  : code,
              style: AppTextStyles.caption.copyWith(
                color: context.onSurfaceColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: () async {
              await HapticHelper.lightTick();
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.compareCouponCopied(code))),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                    color: const Color(0xFF059669).withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: const Color(0xFF059669),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded,
                      size: 12, color: Color(0xFF059669)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Call to action ──────────────────────────────────────────────────────
  Widget _cta(BuildContext context, AppLocalizations l10n, bool isPartner) {
    return SizedBox(
      width: double.infinity,
      child: isPartner
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(l10n.compareViewDeal),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                '${l10n.buyPlanButton} • \$${offer.priceUsd.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
    );
  }
}
