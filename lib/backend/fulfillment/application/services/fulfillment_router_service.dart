import '../../domain/entities/refill_request.dart';
import '../../domain/repositories/refill_request_repository.dart';
import '../../domain/repositories/system_config_repository.dart';
import 'fulfillment_strategy_factory.dart';

class FulfillmentRouterService {
  final IRefillRequestRepository _refillRepo;
  final ISystemConfigRepository _configRepo;

  FulfillmentRouterService(this._refillRepo, this._configRepo);

  /// Processes a single incoming refill request.
  Future<void> routeRequest(RefillRequest request) async {
    // 1. Mark as routing (acknowledgement)
    await _refillRepo.updateStatus(request.id, 'routing');

    try {
      // 2. Fetch the current ACTIVE_FULFILLMENT_METHOD config
      final config = await _configRepo.getConfig('ACTIVE_FULFILLMENT_METHOD');
      final activeMethod = config?.configValue ?? 'MANUAL'; // Default fallback

      print(
        'Router: Routing request ${request.id} using method: $activeMethod',
      );

      // 3. Resolve strategy and execute
      final strategy = FulfillmentStrategyFactory.getStrategy(activeMethod);
      await strategy.execute(request, _refillRepo);
    } catch (e) {
      print('Router: Failed to route request ${request.id} with error: $e');
      await _refillRepo.updateStatus(request.id, 'failed');
    }
  }
}
