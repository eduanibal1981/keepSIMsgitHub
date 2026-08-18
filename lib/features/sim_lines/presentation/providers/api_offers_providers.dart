import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:collection/collection.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/domain/plan_payment.dart';

part 'api_offers_providers.g.dart';

/// I1: the offers a SIM line can actually buy.
///
/// Prefer this over [apiOffers] anywhere a line id exists. [apiOffers] switches
/// on `carriers.api_provider` in Dart and so can only ever see one supplier —
/// and it saw the wrong one for DTOne, listing offers that
/// `request_instant_refill` was guaranteed to refuse. `list_refill_offers`
/// unions every enabled supplier and applies the same ranking the purchase RPC
/// re-applies, so what is listed is what can be bought.
@riverpod
Future<List<Map<String, dynamic>>> lineRefillOffers(
  Ref ref,
  String simLineId,
) {
  return ref.watch(simLinesRepositoryProvider).fetchLineRefillOffers(simLineId);
}

/// Country+carrier lookup for the add-line flow, which has no SIM line id yet.
/// Resolves only the carrier's default supplier — see [lineRefillOffers].
@riverpod
Future<List<Map<String, dynamic>>> apiOffers(
  Ref ref,
  String countryId,
  String carrierId,
) async {
  final carriers = await ref.watch(carriersForCountryProvider(countryId).future);
  final carrier = carriers.firstWhereOrNull((c) => c.id == carrierId);

  if (carrier == null) {
    throw Exception('Carrier not found');
  }

  // A MANUAL or SCRIPT carrier has no online catalogue to list.
  if (carrier.fulfillmentGateway != null &&
      carrier.fulfillmentGateway != 'API') {
    return [];
  }

  // I1: the per-provider switch that used to live here was dead weight and one
  // live bug. `fetchZenditOffers` has been provider-aware since C3b-2 — it reads
  // `carriers.api_provider` and picks `dt_carrier` vs `zen_carrier` itself — so
  // three of the four branches either duplicated it or, for `ding`/`reloadly`,
  // returned a hardcoded empty list that would have silently swallowed a real
  // catalogue the moment those codes were populated.
  return ref.watch(offersForCarrierProvider(countryId, carrierId).future);
}

/// Offers for a country+carrier via the carrier's default supplier.
///
/// Named for what it does, not for a supplier: the underlying repository call
/// resolves the provider from `carriers.api_provider`.
@riverpod
Future<List<Map<String, dynamic>>> offersForCarrier(
  Ref ref,
  String countryId,
  String carrierId,
) {
  return ref
      .watch(simLinesRepositoryProvider)
      .fetchZenditOffers(countryId, carrierId);
}

class QuotedPlanPriceParams {
  final String? simLineId;
  final String plan;
  final String gateway;
  final String? carrierRuleId;

  const QuotedPlanPriceParams({
    this.simLineId,
    this.plan = 'premium',
    this.gateway = 'paypal',
    this.carrierRuleId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuotedPlanPriceParams &&
          runtimeType == other.runtimeType &&
          simLineId == other.simLineId &&
          plan == other.plan &&
          gateway == other.gateway &&
          carrierRuleId == other.carrierRuleId;

  @override
  int get hashCode =>
      Object.hash(simLineId, plan, gateway, carrierRuleId);
}

/// Fetches the authoritative server-quoted plan price for a plan via `quote_plan_price` RPC.
final quotedPlanPriceProvider =
    FutureProvider.family<double?, QuotedPlanPriceParams>((ref, params) async {
  return PlanPayment.fetchQuotedPlanPrice(
    simLineId: params.simLineId,
    plan: params.plan,
    gateway: params.gateway,
    carrierRuleId: params.carrierRuleId,
  );
});

