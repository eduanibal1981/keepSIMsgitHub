import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/domain/line_refill_quote.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/api_offers_providers.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/usage_forecast_provider.dart';
part 'line_refill_quote_provider.g.dart';

@riverpod
Future<LineRefillQuote> lineRefillQuote(
  Ref ref, {
  required SimLine line,
  required String offerId,
  int? offerValue,
}) {
  return ref
      .watch(simLinesRepositoryProvider)
      .fetchCustomerRefillQuote(
        simLineId: line.id,
        offerId: offerId,
        offerValue: offerValue,
      );
}

@riverpod
Future<LineRefillQuote?> suggestedLineRefillQuote(Ref ref, SimLine line) async {
  final forecast = await ref.watch(
    usageForecastForLineProvider(line.id).future,
  );
  if (forecast == null) return null;
  final offers = await ref.watch(lineRefillOffersProvider(line.id).future);
  final fixed = offers.where((o) => o['priceType'] != 'RANGE').toList();
  if (fixed.isEmpty) return null;
  final offer = fixed.firstWhere(
    (o) => o['offerId'] == forecast.suggestedOfferId,
    orElse: () => fixed.first,
  );
  return ref
      .watch(simLinesRepositoryProvider)
      .fetchCustomerRefillQuote(
        simLineId: line.id,
        offerId: offer['offerId'] as String,
      );
}
