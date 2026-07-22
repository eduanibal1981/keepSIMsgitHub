import 'package:keep_sims/features/esim/domain/entities/esim_order.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';

abstract class EsimRepository {
  /// Fetches a list of available eSIM plans for a given country ISO code.
  Future<List<EsimPlan>> getPlans(String countryIsoCode);

  /// Validates a plan purchase without charging the account (Sandbox testing)
  Future<bool> validatePlanPurchase(String planId, {int quantity = 1});

  /// Requests a real eSIM purchase from user wallet via RPC
  Future<String> requestPurchase(String offerId, {int quantity = 1});

  /// Fetches all active & archived eSIMs owned by the user
  Future<List<UserEsim>> getUserEsims();

  /// Fetches user's eSIM order history
  Future<List<EsimOrder>> getOrderHistory();

  /// Streams realtime status updates for a specific order
  Stream<EsimOrder?> watchOrder(String orderId);
}
