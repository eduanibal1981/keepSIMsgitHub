/// SIM Shield — Price Watch Screen (G2)
///
/// Lists everything the nightly `refresh_offer_price_watch()` job is tracking
/// for this user: one auto row per country/carrier they hold a SIM line on,
/// plus any eSIM destinations they started watching from the plans screen.
///
/// Two things this screen is careful about:
///   * A watch with `promo` consent off is silent. `detect_offer_price_drops()`
///     writes no notification at all without an enabled alert_settings row, so
///     the banner at the top is not decoration — without it the whole list is
///     a lie.
///   * Auto rows get a switch, user rows get a delete. Deleting an auto row
///     would look like it worked and then reappear on the next nightly sync,
///     because the job recreates one for every active line.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/price_watch/data/models/offer_price_watch_model.dart';
import 'package:keep_sims/features/price_watch/presentation/providers/price_watch_provider.dart';

class PriceWatchScreen extends ConsumerWidget {
  const PriceWatchScreen({super.key});

  /// Mirrors the server default in `system_configs.PRICE_DROP_THRESHOLD_PERCENT`.
  /// Display only — the server is what actually decides.
  static const double kDefaultThreshold = 10.0;

  static String countryFlag(String code) {
    if (code.length != 2) return '🌐';
    final upper = code.toUpperCase();
    return String.fromCharCode(upper.codeUnitAt(0) - 0x41 + 0x1F1E6) +
        String.fromCharCode(upper.codeUnitAt(1) - 0x41 + 0x1F1E6);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchesAsync = ref.watch(priceWatchesProvider);
    final consentAsync = ref.watch(promoConsentProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: context.onSurfaceColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Price watch',
          style: AppTextStyles.headlineMedium.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: watchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _message(
          context,
          Icons.error_outline_rounded,
          'Could not load your price watches',
          '$err',
        ),
        data: (watches) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _explainer(context),
              const SizedBox(height: 12),
              if (consentAsync.value == false) ...[
                _consentBanner(context, ref),
                const SizedBox(height: 12),
              ],
              if (watches.isEmpty)
                _message(
                  context,
                  Icons.notifications_none_rounded,
                  'Nothing watched yet',
                  'Add a SIM line, or tap the bell on an eSIM destination, and '
                      'it will appear here.',
                )
              else ...[
                ...watches.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _watchTile(context, ref, w),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _explainer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_down_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'We check these prices every night and tell you when one drops by '
              'more than ${kDefaultThreshold.toStringAsFixed(0)}%. eSIM prices '
              'are compared per gigabyte; top-ups are compared offer by offer.',
              style: AppTextStyles.caption.copyWith(
                color: context.onSurfaceColor,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The whole feature is inert without this, so it is a call to action rather
  /// than a note.
  Widget _consentBanner(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_off_rounded,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Price alerts are switched off',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'These alerts arrive under “Offers & Promotions”, which stays off '
            'until you turn it on. We will keep tracking the prices either way.',
            style: AppTextStyles.caption.copyWith(
              color: context.onSurfaceColor.withValues(alpha: 0.75),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await HapticHelper.mediumImpact();
                await ref
                    .read(priceWatchControllerProvider.notifier)
                    .enablePromoConsent();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Turn on price alerts',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _watchTile(BuildContext context, WidgetRef ref, OfferPriceWatch w) {
    final double? change = w.changePercent;
    final bool dropped = change != null && change > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDarkMode
              ? AppColors.darkBorder
              : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(countryFlag(w.countryCode),
                  style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.subjectLabel,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      w.isEsim ? 'eSIM data' : 'Top-ups',
                      style: AppTextStyles.caption.copyWith(
                        color: context.onSurfaceColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: w.isActive,
                onChanged: (v) async {
                  await HapticHelper.lightTick();
                  await ref
                      .read(priceWatchControllerProvider.notifier)
                      .setActive(w.id, v);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _priceLine(context, w, change, dropped)),
              if (!w.isAuto)
                IconButton(
                  tooltip: 'Stop watching',
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 20,
                      color: context.onSurfaceColor.withValues(alpha: 0.6)),
                  onPressed: () async {
                    await HapticHelper.lightTick();
                    await ref
                        .read(priceWatchControllerProvider.notifier)
                        .remove(w.id);
                  },
                ),
            ],
          ),
          if (w.isAuto)
            Text(
              'Added automatically because you have a SIM line here.',
              style: AppTextStyles.caption.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  Widget _priceLine(
    BuildContext context,
    OfferPriceWatch w,
    double? change,
    bool dropped,
  ) {
    // A watch on a country/carrier the catalog does not cover produces no
    // metric at all. Saying so beats rendering "$0.00".
    if (!w.hasPrice) {
      return Text(
        w.lastCheckedAt == null
            ? 'Checking tonight…'
            : 'No offers cached for this one yet',
        style: AppTextStyles.caption.copyWith(
          color: context.onSurfaceColor.withValues(alpha: 0.55),
        ),
      );
    }

    final String now =
        '\$${w.lastBestUsd!.toStringAsFixed(2)}${w.unitSuffix}';

    return Row(
      children: [
        Text(
          now,
          style: AppTextStyles.titleMedium.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        if (change != null && change.abs() >= 0.05)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (dropped ? AppColors.success : AppColors.healthRed)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${dropped ? '↓' : '↑'} ${change.abs().toStringAsFixed(1)}%',
              style: AppTextStyles.caption.copyWith(
                color: dropped ? AppColors.success : AppColors.healthRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          Text(
            'no change',
            style: AppTextStyles.caption.copyWith(
              color: context.onSurfaceColor.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }

  Widget _message(
    BuildContext context,
    IconData icon,
    String title,
    String body,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 48, color: context.onSurfaceColor.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium.copyWith(
              color: context.onSurfaceColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.onSurfaceColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
