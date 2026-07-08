import '../entities/refill_request.dart';

abstract class IRefillRequestRepository {
  /// Fetches a refill request by its ID.
  Future<RefillRequest?> getById(String id);

  /// Updates the status and optionally the fulfillment method of a request.
  Future<void> updateStatus(String id, String status, {String? methodUsed});

  /// Streams active pending refill requests (used by the dashboard/router).
  Stream<List<RefillRequest>> streamPendingRequests();
}
