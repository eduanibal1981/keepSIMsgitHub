/// Active Return Trip Info Provider
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/active_return_trip_info.dart';
import '../../data/repositories/return_trip_repository_impl.dart';

part 'active_return_trip_provider.g.dart';

@riverpod
Future<ActiveReturnTripInfo?> activeReturnTripInfo(
  Ref ref,
  String simLineId,
) async {
  final repo = ref.watch(returnTripRepositoryProvider);
  return repo.getActiveReturnTripInfo(simLineId);
}

@riverpod
Future<List<ActiveReturnTripInfo>> returnTripHistory(
  Ref ref,
  String simLineId,
) async {
  final repo = ref.watch(returnTripRepositoryProvider);
  return repo.getReturnTripHistory(simLineId);
}
