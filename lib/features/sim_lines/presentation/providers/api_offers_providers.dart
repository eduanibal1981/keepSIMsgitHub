import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:collection/collection.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';

part 'api_offers_providers.g.dart';

@riverpod
Future<List<Map<String, dynamic>>> apiOffers(
  Ref ref,
  String countryId,
  String carrierId,
) async {
  // 1. Fetch carriers to find the current carrier's config
  final carriers = await ref.watch(carriersForCountryProvider(countryId).future);
  final carrier = carriers.firstWhereOrNull((c) => c.id == carrierId);

  if (carrier == null) {
    throw Exception('Carrier not found');
  }

  // Handle gateway logic
  if (carrier.fulfillmentGateway != null && carrier.fulfillmentGateway != 'API') {
    // If it's manual or tasker script, we might not have API offers, or we could return custom amounts.
    // For now, we will throw or return empty if we only expect API offers here.
    return [];
  }

  // 2. Delegate to the correct provider based on apiProvider
  final providerName = carrier.apiProvider?.toLowerCase() ?? 'zendit';

  switch (providerName) {
    case 'zendit':
      return ref.watch(zenditOffersProvider(countryId, carrierId).future);
    case 'dtconnect':
    case 'dtone':
      return ref.watch(dtconnectOffersProvider(countryId, carrierId).future);
    case 'ding':
      return ref.watch(dingOffersProvider(countryId, carrierId).future);
    case 'reloadly':
      return ref.watch(reloadlyOffersProvider(countryId, carrierId).future);
    default:
      // Fallback to zendit if unknown
      return ref.watch(zenditOffersProvider(countryId, carrierId).future);
  }
}

@riverpod
Future<List<Map<String, dynamic>>> zenditOffers(
  Ref ref,
  String countryId,
  String carrierId,
) {
  return ref.watch(simLinesRepositoryProvider).fetchZenditOffers(countryId, carrierId);
}

@riverpod
Future<List<Map<String, dynamic>>> dingOffers(
  Ref ref,
  String countryId,
  String carrierId,
) async {
  // TODO: Implement Ding fetching
  return [];
}

@riverpod
Future<List<Map<String, dynamic>>> dtconnectOffers(
  Ref ref,
  String countryId,
  String carrierId,
) {
  return ref.watch(simLinesRepositoryProvider).fetchZenditOffers(countryId, carrierId);
}

@riverpod
Future<List<Map<String, dynamic>>> reloadlyOffers(
  Ref ref,
  String countryId,
  String carrierId,
) async {
  // TODO: Implement Reloadly fetching
  return [];
}
