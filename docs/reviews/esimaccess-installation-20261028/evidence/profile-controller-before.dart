import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_order.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';

part 'user_esims_controller.g.dart';

@riverpod
class UserEsimsController extends _$UserEsimsController {
  @override
  FutureOr<List<UserEsim>> build() async {
    return _fetchUserEsims();
  }

  Future<List<UserEsim>> _fetchUserEsims() async {
    final repository = ref.read(esimRepositoryProvider);
    return repository.getUserEsims();
  }

  Future<void> refresh() async {
    final keepAlive = ref.keepAlive();
    final previous = state.value;
    try {
      final repository = ref.read(esimRepositoryProvider);
      final profiles = await repository.getUserEsims(requestRefresh: true);
      if (ref.mounted) state = AsyncData(profiles);
    } catch (error, stack) {
      if (ref.mounted) {
        state = previous == null
            ? AsyncError(error, stack)
            : AsyncData(
                previous
                    .map(
                      (profile) =>
                          profile.copyWith(usageErrorCode: 'REFRESH_FAILED'),
                    )
                    .toList(),
              );
      }
    } finally {
      keepAlive.close();
    }
  }
}

@riverpod
class EsimOrderHistoryController extends _$EsimOrderHistoryController {
  @override
  FutureOr<List<EsimOrder>> build() async {
    final repository = ref.read(esimRepositoryProvider);
    return repository.getOrderHistory();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      final repository = ref.read(esimRepositoryProvider);
      return repository.getOrderHistory();
    });
  }
}

@riverpod
Stream<EsimOrder?> esimOrderLive(Ref ref, String orderId) {
  final repository = ref.read(esimRepositoryProvider);
  return repository.watchOrder(orderId);
}
