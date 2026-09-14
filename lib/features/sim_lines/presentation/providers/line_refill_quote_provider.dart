import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/domain/line_refill_quote.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/api_offers_providers.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/usage_forecast_provider.dart';

part 'line_refill_quote_provider.g.dart';

/// Provides a tier-aware quote for a specific SIM line and base cost.
@riverpod
Future<LineRefillQuote> lineRefillQuote(
  Ref ref, {
  required SimLine line,
  required double baseCostUsd,
  String? offerId,
  int? offerValue,
}) async {
  final rules = await ref.watch(refillFeeRulesProvider.future);
  return calculateLineRefillQuote(
    simLineId: line.id,
    offerId: offerId,
    offerValue: offerValue,
    effectiveTier: line.effectiveTier,
    baseCostUsd: baseCostUsd,
    rules: rules,
  );
}

/// Provides a suggested tier-aware quote for the line's usage forecast.
///
/// Combines:
/// 1. The line's usage forecast (suggestedOfferId, suggestedAmountUsd, suggestedFrequencyDays).
/// 2. The line's offer catalog to resolve the exact supplier base price of the suggested offer.
/// 3. The line's effective tier and published fee rules.
@riverpod
Future<LineRefillQuote?> suggestedLineRefillQuote(
  Ref ref,
  SimLine line,
) async {
  final forecast = await ref.watch(usageForecastForLineProvider(line.id).future);
  if (forecast == null) return null;

  final rules = await ref.watch(refillFeeRulesProvider.future);

  double? baseCost;
  String? resolvedOfferId = forecast.suggestedOfferId;
  int? resolvedOfferValue;

  try {
    final offers = await ref.watch(lineRefillOffersProvider(line.id).future);
    if (offers.isNotEmpty) {
      Map<String, dynamic>? matched;
      if (resolvedOfferId != null) {
        matched = offers.cast<Map<String, dynamic>?>().firstWhere(
          (o) => o?['offerId']?.toString() == resolvedOfferId,
          orElse: () => null,
        );
      }
      matched ??= offers.cast<Map<String, dynamic>?>().firstWhere(
        (o) => o?['priceType'] != 'RANGE',
        orElse: () => offers.first,
      );

      if (matched != null) {
        resolvedOfferId = matched['offerId']?.toString();
        if (matched['priceType'] != 'RANGE' && matched['baseCostUsd'] != null) {
          baseCost = (matched['baseCostUsd'] as num).toDouble();
        }
      }
    }
  } catch (_) {
    // Fall back to forecast amount if catalogue is temporarily unavailable
  }

  baseCost ??= forecast.suggestedAmountUsd;
  if (baseCost == null || baseCost <= 0) return null;

  return calculateLineRefillQuote(
    simLineId: line.id,
    offerId: resolvedOfferId,
    offerValue: resolvedOfferValue,
    effectiveTier: line.effectiveTier,
    baseCostUsd: baseCost,
    rules: rules,
  );
}
