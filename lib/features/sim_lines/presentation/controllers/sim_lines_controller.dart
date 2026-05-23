import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/controller/dashboard_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';

part 'sim_lines_controller.g.dart';

@Riverpod(keepAlive: true)
class SimLinesController extends _$SimLinesController {
  @override
  FutureOr<List<SimLine>> build() async {
    final authProfile = ref.watch(authControllerProvider);
    final profileValue = authProfile.valueOrNull;
    if (profileValue == null) {
      return const [];
    }

    final repo = ref.watch(simLinesRepositoryProvider);
    return repo.getSimLines();
  }

  Future<void> addSimLine({
    required String phoneNumber,
    String? nickname,
    required String avatarIcon,
    String? countryId,
    String? carrierId,
    required String protectionTier,
  }) async {
    final userId = ref.read(authControllerProvider).valueOrNull?.id;
    if (userId == null)
      throw Exception('Cannot add SIM line: User is not authenticated.');

    final previousList = state.valueOrNull ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);

      final newLine = SimLine(
        id: '',
        userId: userId,
        phoneNumber: phoneNumber,
        nickname: nickname,
        avatarIcon: avatarIcon,
        countryId: countryId,
        carrierId: carrierId,
        protectionTier: protectionTier,
      );

      final added = await repo.addSimLine(newLine);
      ref.invalidate(dashboardControllerProvider);

      return [added, ...previousList];
    });
  }

  Future<void> updateSimLine(SimLine line) async {
    final previousList = state.valueOrNull ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);
      final updated = await repo.updateSimLine(line);
      ref.invalidate(dashboardControllerProvider);

      return previousList
          .map((item) => item.id == line.id ? updated : item)
          .toList();
    });
  }

  Future<void> deleteSimLine(String id) async {
    final previousList = state.valueOrNull ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);
      await repo.deleteSimLine(id);
      ref.invalidate(dashboardControllerProvider);

      return previousList.where((item) => item.id != id).toList();
    });
  }

  Future<void> deleteActivityLog(String id, String simLineId) async {
    final previousList = state.valueOrNull ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);
      await repo.deleteLineActivityLog(id);
      ref.invalidate(simLineActivityLogsProvider(simLineId));
      return previousList;
    });
  }

  Future<void> cleanMockLogs(String simLineId) async {
    final previousList = state.valueOrNull ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);
      await repo.cleanMockLogs(simLineId);
      ref.invalidate(simLineActivityLogsProvider(simLineId));
      ref.invalidate(topupExecutionsForLineProvider(simLineId));
      ref.invalidate(dashboardControllerProvider);
      return previousList;
    });
  }
}

@riverpod
Future<List<Country>> supportedCountries(SupportedCountriesRef ref) {
  return ref.watch(simLinesRepositoryProvider).getSupportedCountries();
}

@riverpod
Future<List<Carrier>> carriersForCountry(
  CarriersForCountryRef ref,
  String countryId,
) {
  return ref.watch(simLinesRepositoryProvider).getCarriersForCountry(countryId);
}

@riverpod
FutureOr<List<LineActivityLog>> simLineActivityLogs(
  SimLineActivityLogsRef ref,
  String simLineId,
) {
  return ref.watch(simLinesRepositoryProvider).getLineActivityLogs(simLineId);
}
