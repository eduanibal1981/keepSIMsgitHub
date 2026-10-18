/// Return Trip Repository Interface
library;

import '../entities/return_trip.dart';
import '../entities/return_trip_package.dart';
import '../entities/active_return_trip_info.dart';

abstract class ReturnTripRepository {
  /// Fetches curated return trip packages for a given SIM line, with tier-aware pricing
  Future<List<ReturnTripPackage>> getPackagesForLine(String simLineId);

  /// Gets the active return trip for a SIM line, if any
  Future<ReturnTrip?> getActiveTripForLine(String simLineId);

  /// Gets the enriched active return trip with its package and instructions
  Future<ActiveReturnTripInfo?> getActiveReturnTripInfo(String simLineId);

  /// Gets all return trip preparations (past, active, cancelled) for a SIM line
  Future<List<ActiveReturnTripInfo>> getReturnTripHistory(String simLineId);

  /// Saves or updates a return trip
  Future<ReturnTrip> saveReturnTrip({
    required String simLineId,
    required String destinationCountryId,
    required DateTime arrivalDate,
    required String status,
    String? chosenPackageType,
    String? chosenPackageId,
    double? expectedPriceUsd,
    String? notes,
  });

  /// Cancels a return trip
  Future<void> cancelTrip(String tripId);

  /// Updates only the arrival date of an active return trip without affecting the package
  Future<void> updateArrivalDate(String tripId, DateTime newArrivalDate);
}
