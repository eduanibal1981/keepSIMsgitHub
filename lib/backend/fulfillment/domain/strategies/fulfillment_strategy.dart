import '../entities/refill_request.dart';
import '../repositories/refill_request_repository.dart';

abstract class IFulfillmentStrategy {
  /// Executes the fulfillment logic for a specific request.
  /// Needs access to the repository to update statuses.
  Future<void> execute(
    RefillRequest request,
    IRefillRequestRepository repository,
  );
}
