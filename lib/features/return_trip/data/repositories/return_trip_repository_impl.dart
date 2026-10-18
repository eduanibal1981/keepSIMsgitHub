/// Return Trip Repository Implementation
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/return_trip.dart';
import '../../domain/entities/return_trip_package.dart';
import '../../domain/entities/active_return_trip_info.dart';
import '../../domain/repositories/return_trip_repository.dart';
import '../datasources/return_trip_remote_datasource.dart';

part 'return_trip_repository_impl.g.dart';

@Riverpod(keepAlive: true)
ReturnTripRepository returnTripRepository(Ref ref) {
  return ReturnTripRepositoryImpl(
    remoteDataSource: ReturnTripRemoteDataSource(
      client: Supabase.instance.client,
    ),
  );
}

class ReturnTripRepositoryImpl implements ReturnTripRepository {
  final ReturnTripRemoteDataSource _remoteDataSource;

  ReturnTripRepositoryImpl({
    required ReturnTripRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<List<ReturnTripPackage>> getPackagesForLine(String simLineId) {
    return _remoteDataSource.getPackagesForLine(simLineId);
  }

  @override
  Future<ReturnTrip?> getActiveTripForLine(String simLineId) {
    return _remoteDataSource.getActiveTripForLine(simLineId);
  }

  @override
  Future<ActiveReturnTripInfo?> getActiveReturnTripInfo(String simLineId) {
    return _remoteDataSource.getActiveReturnTripInfo(simLineId);
  }

  @override
  Future<List<ActiveReturnTripInfo>> getReturnTripHistory(String simLineId) {
    return _remoteDataSource.getReturnTripHistory(simLineId);
  }

  @override
  Future<ReturnTrip> saveReturnTrip({
    required String simLineId,
    required String destinationCountryId,
    required DateTime arrivalDate,
    required String status,
    String? chosenPackageType,
    String? chosenPackageId,
    double? expectedPriceUsd,
    String? notes,
  }) {
    return _remoteDataSource.saveReturnTrip(
      simLineId: simLineId,
      destinationCountryId: destinationCountryId,
      arrivalDate: arrivalDate,
      status: status,
      chosenPackageType: chosenPackageType,
      chosenPackageId: chosenPackageId,
      expectedPriceUsd: expectedPriceUsd,
      notes: notes,
    );
  }

  @override
  Future<void> cancelTrip(String tripId) {
    return _remoteDataSource.cancelTrip(tripId);
  }

  @override
  Future<void> updateArrivalDate(String tripId, DateTime newArrivalDate) {
    return _remoteDataSource.updateArrivalDate(tripId, newArrivalDate);
  }
}
