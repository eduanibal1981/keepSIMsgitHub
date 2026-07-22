import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/domain/repositories/esim_repository.dart';

class EsimGoRepositoryImpl implements EsimRepository {
  final SupabaseClient _supabase;

  EsimGoRepositoryImpl({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<EsimPlan>> getPlans(String countryIsoCode) async {
    try {
      final String upperIso = countryIsoCode.trim().toUpperCase();

      final response = await _supabase
          .from('esim_offers')
          .select()
          .order('retail_price_usd', ascending: true);

      final List<dynamic> data = response as List<dynamic>;

      final plans = data.map((json) {
        final Map<String, dynamic> map = json as Map<String, dynamic>;
        final List<String> countries = (map['countries'] as List<dynamic>?)
                ?.map((e) => e.toString().toUpperCase())
                .toList() ??
            [];
        final List<String> roaming = (map['roaming_enabled'] as List<dynamic>?)
                ?.map((e) => e.toString().toUpperCase())
                .toList() ??
            [];

        return EsimPlan(
          id: (map['bundle_name'] as String?) ?? (map['id'] as String? ?? ''),
          name: (map['description'] as String?)?.isNotEmpty == true
              ? map['description'] as String
              : (map['bundle_name'] as String? ?? ''),
          dataAmountMB: (map['data_amount_mb'] as num?)?.toInt() ?? 0,
          durationDays: (map['duration_days'] as num?)?.toInt() ?? 0,
          priceUsd: (map['retail_price_usd'] as num?)?.toDouble() ?? 0.0,
          providerName: (map['provider'] as String?) ?? 'eSIM Go',
          description: map['description'] as String?,
          supportedCountries: countries,
          roamingEnabled: roaming,
          imageUrl: map['image_url'] as String?,
        );
      }).where((plan) {
        if (upperIso.isEmpty) return true;
        // Include plans that match the destination in supportedCountries or roamingEnabled
        return plan.supportedCountries.contains(upperIso) ||
            plan.roamingEnabled.contains(upperIso);
      }).toList();

      return plans;
    } catch (e) {
      throw Exception('Failed to fetch eSIM plans from database: $e');
    }
  }

  @override
  Future<bool> validatePlanPurchase(String planId, {int quantity = 1}) async {
    // Dry run validation for C9a
    return true;
  }
}
