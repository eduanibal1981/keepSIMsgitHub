import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import '../../domain/entities/esim_group.dart';
import '../../domain/repositories/esim_group_repository.dart';
import '../../data/repositories/esim_group_repository_impl.dart';
import 'user_esims_controller.dart';

final esimGroupRepositoryProvider = Provider<EsimGroupRepository>(
  (ref) => EsimGroupRepositoryImpl(Supabase.instance.client),
);
final esimOrganizationProvider = StreamProvider.autoDispose<EsimOrganization>((
  ref,
) async* {
  final auth = ref.watch(authControllerProvider), owner = auth.value?.id;
  if (auth.isLoading || auth.hasError || owner == null) {
    yield const EsimOrganization({});
    return;
  }
  final repo = ref.watch(esimGroupRepositoryProvider);
  String? previous;
  Timer? timer;
  Completer<void>? waiting;
  ref.onDispose(() {
    timer?.cancel();
    if (waiting?.isCompleted == false) {
      waiting!.complete();
    }
  });
  while (ref.mounted) {
    final result = await repo.organization();
    if (!ref.mounted ||
        ref.read(authControllerProvider).value?.id != owner ||
        result.owner != owner) {
      return;
    }
    final fingerprint = result.batches.toString();
    if (previous != null && previous != fingerprint) {
      ref.invalidate(userEsimsControllerProvider);
      ref.invalidate(walletControllerProvider);
      ref.invalidate(esimOrderHistoryControllerProvider);
    }
    previous = fingerprint;
    yield result;
    if (!result.pending) {
      return;
    }
    waiting = Completer<void>();
    timer = Timer(const Duration(seconds: 4), () => waiting?.complete());
    await waiting.future;
  }
});
final esimGroupActionsProvider = Provider.autoDispose((ref) {
  ref.watch(authControllerProvider);
  return EsimGroupActions(ref);
});

class EsimGroupActions {
  EsimGroupActions(this.ref);
  final Ref ref;
  final Set<String> _attempted = {};
  Future<Map<String, dynamic>>? _pending;
  String? get owner {
    final auth = ref.read(authControllerProvider);
    return auth.isLoading || auth.hasError ? null : auth.value?.id;
  }

  Future<EsimGroupQuote> review(
    String group,
    List<EsimTravellerIntent> members,
  ) async {
    final before = owner;
    if (before == null ||
        group.length > 60 ||
        members.isEmpty ||
        members.length > 3 ||
        members.any((m) => !m.valid)) {
      return const EsimGroupQuote({'status': 'INVALID_REQUEST'});
    }
    final result = await ref
        .read(esimGroupRepositoryProvider)
        .quote(group, members);
    if (!ref.mounted ||
        owner != before ||
        (result.status == 'QUOTED' &&
            (result.owner != before || result.payer != before))) {
      return const EsimGroupQuote({'status': 'ACCOUNT_CHANGED'});
    }
    return result;
  }

  Future<Map<String, dynamic>> accept(EsimGroupQuote q, String key) {
    if (_pending != null) {
      return _pending!;
    }
    _pending = _accept(q, key);
    return _pending!.whenComplete(() => _pending = null);
  }

  Future<Map<String, dynamic>> _accept(EsimGroupQuote q, String key) async {
    final before = owner;
    if (before == null || q.owner != before || q.payer != before) {
      return {'status': 'ACCOUNT_CHANGED'};
    }
    if (!q.enabled || (!_attempted.contains(q.id) && q.expired)) {
      return {'status': 'QUOTE_UNAVAILABLE'};
    }
    final result = await ref
        .read(paymentAuthGuardProvider)
        .confirmPayment(
          reason:
              'Confirm ${q.totalLabel} for ${q.members.length} separate eSIMs',
        );
    if ([
      BiometricResult.cancelled,
      BiometricResult.failed,
      BiometricResult.lockedOut,
    ].contains(result)) {
      return {'status': 'CANCELLED'};
    }
    if (!ref.mounted || owner != before) {
      return {'status': 'ACCOUNT_CHANGED'};
    }
    if (q.expired && !_attempted.contains(q.id)) {
      return {'status': 'STALE_QUOTE'};
    }
    _attempted.add(q.id!);
    Map<String, dynamic> accepted;
    try {
      accepted = await ref
          .read(esimGroupRepositoryProvider)
          .accept(q.id!, q.acceptanceKey!, key);
    } catch (_) {
      accepted = {'status': 'OUTCOME_UNKNOWN'};
    }
    if (!ref.mounted || owner != before) {
      return {'status': 'ACCOUNT_CHANGED'};
    }
    ref.invalidate(esimOrganizationProvider);
    ref.invalidate(walletControllerProvider);
    ref.invalidate(esimOrderHistoryControllerProvider);
    ref.invalidate(userEsimsControllerProvider);
    return accepted;
  }

  Future<String> label(String id, String traveller, String group) async {
    final before = owner;
    if (before == null) {
      return 'ACCOUNT_CHANGED';
    }
    final result = await ref
        .read(esimGroupRepositoryProvider)
        .label(id, traveller, group);
    if (!ref.mounted || owner != before) {
      return 'ACCOUNT_CHANGED';
    }
    ref.invalidate(esimOrganizationProvider);
    return result;
  }
}
