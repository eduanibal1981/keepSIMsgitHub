import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/domain/repositories/esim_repository.dart';
import 'package:keep_sims/features/esim/data/datasources/esim_go_api_client.dart';
import 'package:keep_sims/features/esim/data/models/esim_go_models.dart';

class EsimGoRepositoryImpl implements EsimRepository {
  final EsimGoApiClient _apiClient;

  EsimGoRepositoryImpl({EsimGoApiClient? apiClient}) 
    : _apiClient = apiClient ?? EsimGoApiClient();

  @override
  Future<List<EsimPlan>> getPlans(String countryIsoCode) async {
    try {
      final bundles = await _apiClient.getCatalogue(countryIsoCode: countryIsoCode);
      
      // Filter bundles by requested country ISO and map to domain entity
      final relevantBundles = bundles.where((b) {
        final hasCountry = b.countries.any((c) => c.iso.toUpperCase() == countryIsoCode.toUpperCase());
        final hasRoaming = b.roamingEnabled.any((c) => c.iso.toUpperCase() == countryIsoCode.toUpperCase());
        return hasCountry || hasRoaming;
      }).toList();

      return relevantBundles.map((dto) => EsimPlan(
        id: dto.name,
        name: dto.description.isNotEmpty ? dto.description : dto.name,
        dataAmountMB: dto.dataAmount,
        durationDays: dto.duration,
        priceUsd: dto.price,
        providerName: 'eSIM Go',
        description: dto.description,
        supportedCountries: dto.countries.map((c) => c.iso).toList(),
      )).toList();
    } catch (e) {
      throw Exception('Failed to fetch eSIM plans: $e');
    }
  }

  @override
  Future<bool> validatePlanPurchase(String planId, {int quantity = 1}) async {
    try {
      final request = EsimGoOrderRequestDto(
        type: 'validate',
        assign: false,
        order: [
          EsimGoOrderItemDto(
            type: 'bundle',
            item: planId,
            quantity: quantity,
          ),
        ],
      );

      final response = await _apiClient.createOrder(request);
      
      // For 'validate' requests, orderReference might be null, but we'll get a total back if successful
      return response.total != null;
    } catch (e) {
      throw Exception('Validation failed for plan $planId: $e');
    }
  }
}
