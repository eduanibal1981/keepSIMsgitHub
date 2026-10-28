import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_recharge.dart';
import 'dart:async';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';

final esimRechargeDiscoveryProvider = FutureProvider.autoDispose
    .family<EsimRechargeDiscovery, String>((ref, profileId) async {
      final owner = ref.watch(authControllerProvider).value?.id;
      if (owner == null) {
        return const EsimRechargeDiscovery(status: 'PROFILE_UNAVAILABLE');
      }
      final repository = ref.watch(esimRepositoryProvider);
      for (var attempt = 0; attempt < 26; attempt++) {
        final result = await repository.discoverTopups(profileId);
        if (!ref.mounted ||
            ref.read(authControllerProvider).value?.id != owner) {
          return const EsimRechargeDiscovery(status: 'PROFILE_UNAVAILABLE');
        }
        if (result.status != 'PENDING' || attempt == 25) return result;
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!ref.mounted) {
          return const EsimRechargeDiscovery(status: 'PROFILE_UNAVAILABLE');
        }
      }
      return const EsimRechargeDiscovery(status: 'PENDING');
    });

typedef EsimRechargeSelection = ({
  String profileId,
  String packageId,
  String version,
  double total,
});
final esimRechargeQuoteProvider = FutureProvider.autoDispose
    .family<EsimRechargeQuote, EsimRechargeSelection>((ref, selection) async {
      final owner = ref.watch(authControllerProvider).value?.id;
      if (owner == null) {
        return const EsimRechargeQuote(status: 'QUOTE_UNAVAILABLE');
      }
      final result = await ref
          .watch(esimRepositoryProvider)
          .quoteTopup(
            selection.profileId,
            selection.packageId,
            selection.version,
            selection.total,
          );
      if (!ref.mounted ||
          ref.read(authControllerProvider).value?.id != owner ||
          (result.status == 'QUOTED' &&
              (result.ownerId != owner ||
                  result.payerId != owner ||
                  result.profileId != selection.profileId))) {
        return const EsimRechargeQuote(status: 'QUOTE_UNAVAILABLE');
      }
      return result;
    });

final esimOperationHistoryProvider = StreamProvider.autoDispose
    .family<List<EsimOperation>, String>((ref, id) async* {
      final owner = ref.watch(authControllerProvider).value?.id;
      if (owner == null) {
        yield const [];
        return;
      }
      final repo = ref.watch(esimRepositoryProvider);
      Timer? timer;
      Completer<void>? waiting;
      String? previous;
      ref.onDispose(() {
        timer?.cancel();
        if (waiting?.isCompleted == false) waiting!.complete();
      });
      while (ref.mounted) {
        final rows = await repo.getOperationHistory(id);
        if (!ref.mounted ||
            ref.read(authControllerProvider).value?.id != owner) {
          return;
        }
        final fingerprint = rows
            .map((r) => '${r.id}:${r.status}:${r.financialState}')
            .join('|');
        if (previous != null && fingerprint != previous) {
          ref.invalidate(userEsimsControllerProvider);
          ref.invalidate(walletControllerProvider);
        }
        previous = fingerprint;
        yield rows;
        waiting = Completer<void>();
        timer = Timer(const Duration(seconds: 3), () => waiting?.complete());
        await waiting.future;
      }
    });

final esimMoneyActionsProvider = Provider.autoDispose<EsimMoneyActions>((ref) {
  ref.watch(authControllerProvider);
  return EsimMoneyActions(ref);
});

class EsimMoneyActions {
  EsimMoneyActions(this.ref);
  final Ref ref;
  Future<EsimOperationAcceptance>? _pending;
  Future<EsimOperationAcceptance> accept(
    EsimRechargeQuote quote, {
    String? requestKey,
  }) {
    if (_pending != null) return _pending!;
    final future = _accept(quote, requestKey);
    _pending = future;
    return future.whenComplete(() => _pending = null);
  }

  Future<bool> _confirm(String owner, String reason) async {
    final result = await ref
        .read(paymentAuthGuardProvider)
        .confirmPayment(reason: reason);
    return ref.mounted &&
        ref.read(authControllerProvider).value?.id == owner &&
        ![
          BiometricResult.cancelled,
          BiometricResult.failed,
          BiometricResult.lockedOut,
        ].contains(result);
  }

  Future<EsimOperationAcceptance> _accept(
    EsimRechargeQuote quote,
    String? requestKey,
  ) async {
    final owner = ref.read(authControllerProvider).value?.id;
    if (owner == null || quote.ownerId != owner || quote.payerId != owner) {
      return const EsimOperationAcceptance('QUOTE_UNAVAILABLE');
    }
    if (quote.expired) return const EsimOperationAcceptance('STALE_QUOTE');
    if (!quote.acceptanceEnabled) {
      return const EsimOperationAcceptance('RECHARGE_DISABLED');
    }
    if (quote.balanceState != 'sufficient') {
      return const EsimOperationAcceptance('BALANCE_UNAVAILABLE');
    }
    if (quote.id == null || quote.acceptanceKey == null) {
      return const EsimOperationAcceptance('QUOTE_UNAVAILABLE');
    }
    if (!await _confirm(
      owner,
      quote.action == 'daily_purchase'
          ? 'Confirm this new Day Pass purchase'
          : 'Confirm this existing-profile eSIM recharge',
    )) {
      return const EsimOperationAcceptance('CANCELLED');
    }
    if (quote.expired) return const EsimOperationAcceptance('STALE_QUOTE');
    final repository = ref.read(esimRepositoryProvider);
    final result = quote.action == 'daily_purchase'
        ? (requestKey == null
              ? const EsimOperationAcceptance('QUOTE_UNAVAILABLE')
              : await repository.acceptDailyPurchase(
                  quote.id!,
                  quote.acceptanceKey!,
                  requestKey,
                ))
        : await repository.acceptTopup(quote.id!, quote.acceptanceKey!);
    if (!ref.mounted || ref.read(authControllerProvider).value?.id != owner) {
      return const EsimOperationAcceptance('ACCOUNT_CHANGED');
    }
    ref.invalidate(walletControllerProvider);
    if (quote.profileId != null) {
      ref.invalidate(esimOperationHistoryProvider(quote.profileId!));
    }
    return result;
  }

  Future<String?> purchase(String offerId, String key, double total) async {
    final owner = ref.read(authControllerProvider).value?.id;
    if (owner == null) throw Exception('Sign in again before purchasing.');
    if (!await _confirm(owner, 'Confirm this new eSIM purchase')) return null;
    final id = await ref
        .read(esimRepositoryProvider)
        .requestPurchaseIntent(
          offerId,
          requestKey: key,
          reviewedTotal: total,
          expectedUserId: owner,
        );
    if (!ref.mounted || ref.read(authControllerProvider).value?.id != owner) {
      return null;
    }
    return id;
  }
}
