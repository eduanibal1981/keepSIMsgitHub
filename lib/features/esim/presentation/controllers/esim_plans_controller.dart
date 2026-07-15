import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';

part 'esim_plans_controller.g.dart';

@riverpod
class EsimPlansController extends _$EsimPlansController {
  @override
  FutureOr<List<EsimPlan>> build(String countryIsoCode) async {
    return _fetchPlans(countryIsoCode);
  }

  Future<List<EsimPlan>> _fetchPlans(String countryIsoCode) async {
    final repository = ref.read(esimRepositoryProvider);
    return repository.getPlans(countryIsoCode);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPlans(countryIsoCode));
  }
}
