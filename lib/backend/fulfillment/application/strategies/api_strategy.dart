import '../../domain/entities/refill_request.dart';
import '../../domain/repositories/refill_request_repository.dart';
import '../../domain/strategies/fulfillment_strategy.dart';

class ApiFulfillmentStrategy implements IFulfillmentStrategy {
  @override
  Future<void> execute(
    RefillRequest request,
    IRefillRequestRepository repository,
  ) async {
    // 1. Mark as processing
    await repository.updateStatus(request.id, 'processing', methodUsed: 'API');

    try {
      // 2. Mocking an HTTP call to a telecom aggregator (e.g., Zendit)
      print(
        'API: Calling telecom aggregator for Refill Request ${request.id}...',
      );
      await Future.delayed(
        const Duration(seconds: 2),
      ); // Simulate network request

      // Assume success
      await repository.updateStatus(request.id, 'completed');
      print('API: Completed Refill Request ${request.id}');
    } catch (e) {
      // On failure
      await repository.updateStatus(request.id, 'failed');
      print('API: Failed Refill Request ${request.id} with error: $e');
    }
  }
}
