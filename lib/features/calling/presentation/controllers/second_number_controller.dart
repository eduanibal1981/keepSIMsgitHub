import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../contract/second_number_contract.dart';
import '../../data/models/second_number_models.dart';
import '../../data/models/virtual_did_model.dart';
import '../../data/models/available_virtual_number_model.dart';
import '../../data/repositories/calling_repository.dart';

final secondNumberRepositoryProvider = Provider<SecondNumberContract>(
  (ref) => ref.watch(callingRepositoryProvider),
);
final virtualDidsProvider = FutureProvider.autoDispose<List<VirtualDidNumber>>(
  (ref) => ref.watch(secondNumberRepositoryProvider).getVirtualDids(),
);
final secondNumberCountriesProvider =
    FutureProvider.autoDispose<List<SecondNumberCountry>>(
      (ref) =>
          ref.watch(secondNumberRepositoryProvider).getSecondNumberCountries(),
    );
final pendingSecondNumbersProvider =
    FutureProvider.autoDispose<List<SecondNumberOrder>>(
      (ref) => ref
          .watch(secondNumberRepositoryProvider)
          .getPendingSecondNumberOrders(),
    );
final didMessagesProvider = StreamProvider.autoDispose
    .family<List<SecondNumberMessage>, String>(
      (ref, id) =>
          ref.watch(secondNumberRepositoryProvider).watchDidMessages(id),
    );
final secondNumberInventoryProvider = FutureProvider.autoDispose
    .family<List<AvailableVirtualNumber>, String>(
      (ref, country) => ref
          .watch(secondNumberRepositoryProvider)
          .searchAvailableNumbers(countryCode: country),
    );
final secondNumberPurchaseProvider =
    AsyncNotifierProvider.autoDispose<SecondNumberPurchase, SecondNumberOrder?>(
      SecondNumberPurchase.new,
    );
final secondNumberActionsProvider =
    AsyncNotifierProvider.autoDispose<SecondNumberActions, void>(
      SecondNumberActions.new,
    );

class SecondNumberActions extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> _run(Future<void> Function() action) async {
    final operation = ref.keepAlive();
    state = const AsyncLoading();
    try {
      final result = await AsyncValue.guard(action);
      if (!ref.mounted) return false;
      state = result;
      if (!state.hasError) {
        ref.invalidate(virtualDidsProvider);
        ref.invalidate(pendingSecondNumbersProvider);
      }
      return !state.hasError;
    } finally {
      operation.close();
    }
  }

  Future<bool> autoRenew(String id, bool enabled) => _run(
    () => ref
        .read(secondNumberRepositoryProvider)
        .setSecondNumberRenewal(id, enabled),
  );
  Future<bool> release(String id) => _run(
    () => ref.read(secondNumberRepositoryProvider).releaseSecondNumber(id),
  );
  Future<bool> readMessage(String id) => _run(
    () => ref.read(secondNumberRepositoryProvider).markDidMessageRead(id),
  );
}

class SecondNumberPurchase extends AsyncNotifier<SecondNumberOrder?> {
  @override
  Future<SecondNumberOrder?> build() async => null;

  Future<void> purchase(String quoteId, bool autoRenew) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(secondNumberRepositoryProvider)
          .purchaseSecondNumber(quoteId: quoteId, autoRenew: autoRenew),
    );
    if (!ref.mounted) return;
    state = result;
    ref.invalidate(virtualDidsProvider);
    ref.invalidate(pendingSecondNumbersProvider);
  }

  Future<void> refresh(String id) async {
    final result = await AsyncValue.guard(
      () => ref.read(secondNumberRepositoryProvider).getSecondNumberOrder(id),
    );
    if (!ref.mounted) return;
    state = result;
    ref.invalidate(virtualDidsProvider);
    ref.invalidate(pendingSecondNumbersProvider);
  }
}
