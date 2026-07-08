import '../../domain/entities/refill_request.dart';
import '../../domain/repositories/refill_request_repository.dart';
import '../../domain/strategies/fulfillment_strategy.dart';

class ManualFulfillmentStrategy implements IFulfillmentStrategy {
  @override
  Future<void> execute(
    RefillRequest request,
    IRefillRequestRepository repository,
  ) async {
    // Flag the request for manual operator intervention
    await repository.updateStatus(
      request.id,
      'pending_manual_action',
      methodUsed: 'MANUAL',
    );
  }
}
