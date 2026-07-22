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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchUserEsims());
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
