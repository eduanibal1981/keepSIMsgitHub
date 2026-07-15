import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';

abstract class EsimRepository {
  /// Fetches a list of available eSIM plans for a given country ISO code.
  Future<List<EsimPlan>> getPlans(String countryIsoCode);

  /// Validates a plan purchase without charging the account (Sandbox testing)
  Future<bool> validatePlanPurchase(String planId, {int quantity = 1});
  // Future<EsimProfile> getEsimProfile(String iccid);
}
