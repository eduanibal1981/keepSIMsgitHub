import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_order.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';

part 'user_esims_controller.g.dart';

@riverpod
class UserEsimsController extends _$UserEsimsController {
  @override
  FutureOr<List<UserEsim>> build() async {
    final owner = ref.watch(authControllerProvider).value?.id;
    if (owner == null) return const [];
    final repository = ref.read(esimRepositoryProvider);
    return (await repository.getUserEsims())
        .where((p) => p.userId == owner)
        .toList();
  }

  Future<void> refresh() async {
    final owner = ref.read(authControllerProvider).value?.id;
    if (owner == null) return;
    final keepAlive = ref.keepAlive();
    final previous = state.value;
    try {
      final repository = ref.read(esimRepositoryProvider);
      final profiles = await repository.getUserEsims(requestRefresh: true);
      if (ref.mounted && ref.read(authControllerProvider).value?.id == owner) {
        state = AsyncData(profiles.where((p) => p.userId == owner).toList());
      }
    } catch (error, stack) {
      if (ref.mounted && ref.read(authControllerProvider).value?.id == owner) {
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
    final owner = ref.watch(authControllerProvider).value?.id;
    if (owner == null) return const [];
    final repository = ref.read(esimRepositoryProvider);
    return (await repository.getOrderHistory())
        .where((o) => o.userId == owner)
        .toList();
  }

  Future<void> refresh() async {
    final owner = ref.read(authControllerProvider).value?.id;
    if (owner == null) return;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      final repository = ref.read(esimRepositoryProvider);
      return (await repository.getOrderHistory())
          .where((o) => o.userId == owner)
          .toList();
    });
    if (ref.mounted && ref.read(authControllerProvider).value?.id == owner) {
      state = result;
    }
  }
}

@riverpod
Stream<EsimOrder?> esimOrderLive(Ref ref, String orderId) {
  final owner = ref.watch(authControllerProvider).value?.id;
  if (owner == null) return Stream.value(null);
  final repository = ref.read(esimRepositoryProvider);
  return repository
      .watchOrder(orderId)
      .map((o) => o?.userId == owner ? o : null);
}
