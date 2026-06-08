import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/providers.dart';
import '../model/offline_refill_model.dart';

part 'offline_refill_controller.g.dart';

@riverpod
class OfflineRefillController extends _$OfflineRefillController {
  @override
  FutureOr<OfflineRefillSettings> build() async {
    final repo = ref.watch(offlineRefillRepositoryProvider);
    final result = await repo.getSettings();
    
    return switch (result) {
      Success(data: final settings) => settings,
      Failure(error: final e) => throw Exception(e.message),
    };
  }

  Future<bool> saveSettings(OfflineRefillSettings settings) async {
    state = const AsyncLoading<OfflineRefillSettings>().copyWithPrevious(state);
    
    final repo = ref.read(offlineRefillRepositoryProvider);
    final result = await repo.saveSettings(settings);
    
    switch (result) {
      case Success(data: final updated):
        state = AsyncData(updated);
        ref.invalidateSelf();
        return true;
      case Failure(error: final f):
        state = AsyncValue.error(f.message, StackTrace.current);
        return false;
    }
  }
}

@riverpod
Future<List<CarrierUssdSuggestion>> carrierUssdSuggestions(
  CarrierUssdSuggestionsRef ref,
  String carrierId,
) async {
  final repo = ref.watch(offlineRefillRepositoryProvider);
  final result = await repo.getUssdSuggestions(carrierId);
  
  return switch (result) {
    Success(data: final list) => list,
    Failure(error: final e) => throw Exception(e.message),
  };
}
