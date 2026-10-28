import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import '../../data/repositories/esim_controls_repository_impl.dart';
import '../../domain/repositories/esim_controls_repository.dart';
import '../../domain/entities/esim_controls.dart';

final esimControlsRepositoryProvider = Provider<EsimControlsRepository>(
  (ref) => EsimControlsRepositoryImpl(Supabase.instance.client),
);
final esimControlsProvider = FutureProvider.autoDispose
    .family<EsimControlSnapshot, String>((ref, id) async {
      final auth = ref.watch(authControllerProvider);
      final owner = auth.isLoading || auth.hasError ? null : auth.value?.id;
      if (owner == null) throw Exception('Sign in to manage your eSIM.');
      final snapshot = await ref.watch(esimControlsRepositoryProvider).load(id);
      if (!ref.mounted ||
          ref.read(authControllerProvider).value?.id != owner ||
          snapshot.ownerId != owner) {
        throw Exception('Profile unavailable.');
      }
      return snapshot;
    });
final esimControlsActionsProvider = Provider.autoDispose
    .family<EsimControlsActions, String>((ref, id) {
      ref.watch(authControllerProvider);
      return EsimControlsActions(ref, id);
    });

class EsimControlsActions {
  EsimControlsActions(this.ref, this.profileId);
  final Ref ref;
  final String profileId;
  String? get _owner {
    final auth = ref.read(authControllerProvider);
    return auth.isLoading || auth.hasError ? null : auth.value?.id;
  }

  Future<String>? _pending;
  final Map<String, String> _keys = {};
  Future<String> run(
    EsimControlSnapshot snapshot, {
    String? action,
    bool? enableAutomation,
    EsimAutomationSettings? settings,
  }) {
    if (_pending != null) return _pending!;
    _pending = _run(snapshot, action, enableAutomation, settings);
    return _pending!.whenComplete(() => _pending = null);
  }

  Future<String> _run(
    EsimControlSnapshot s,
    String? action,
    bool? enable,
    EsimAutomationSettings? settings,
  ) async {
    final owner = _owner;
    if (owner == null || owner != s.ownerId) return 'ACCOUNT_CHANGED';
    if (action != null &&
        !({
              'cancel': s.cancellationEnabled,
              'suspend': s.suspendEnabled,
              'resume': s.resumeEnabled,
            }[action] ??
            false)) {
      return 'ACTION_DISABLED';
    }
    if (enable == true && (!s.autoAvailable || settings?.valid != true)) {
      return 'AUTOMATION_UNAVAILABLE';
    }
    if (enable != false) {
      final result = await ref
          .read(paymentAuthGuardProvider)
          .confirmPayment(
            reason: enable == true
                ? 'Confirm automatic recharge limits'
                : 'Confirm eSIM service change',
          );
      if ([
        BiometricResult.cancelled,
        BiometricResult.failed,
        BiometricResult.lockedOut,
      ].contains(result)) {
        return 'CANCELLED';
      }
    }
    if (!ref.mounted || _owner != owner) {
      return 'ACCOUNT_CHANGED';
    }
    final repo = ref.read(esimControlsRepositoryProvider);
    final result = action != null
        ? await repo.control(
            profileId,
            action,
            _keys.putIfAbsent(
              '$action:${s.controls['quote_id']}',
              () => const Uuid().v4(),
            ),
            s,
          )
        : await repo.setAutomation(
            profileId,
            s.revision,
            enable ?? false,
            settings,
          );
    if (!ref.mounted || _owner != owner) {
      return 'ACCOUNT_CHANGED';
    }
    if (action != null && ['ACCEPTED', 'ADOPTED'].contains(result)) {
      _keys.remove('$action:${s.controls['quote_id']}');
    }
    ref.invalidate(esimControlsProvider(profileId));
    return result;
  }
}
