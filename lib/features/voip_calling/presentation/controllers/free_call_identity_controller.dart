import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/voip_calling/data/repositories/voip_calling_repository.dart';
import 'package:keep_sims/features/voip_calling/domain/free_call_identity.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/free_call_review_controller.dart';

final freeCallIdentityProvider =
    AsyncNotifierProvider.autoDispose<
      FreeCallIdentityController,
      FreeCallIdentity
    >(FreeCallIdentityController.new);

class FreeCallIdentityController extends AsyncNotifier<FreeCallIdentity> {
  @override
  Future<FreeCallIdentity> build() async {
    final account = ref.watch(freeCallAccountProvider);
    if (account == null) throw StateError('Sign in to use Free Call');
    return ref.watch(voipCallingRepositoryProvider).getIdentity();
  }

  Future<void> setDiscovery({required bool byId, required bool byEmail}) async {
    await ref
        .read(voipCallingRepositoryProvider)
        .setDiscovery(byId: byId, byEmail: byEmail);
    if (ref.mounted) ref.invalidateSelf();
  }

  Future<void> setPhone(String phone, bool enabled) async {
    await ref
        .read(voipCallingRepositoryProvider)
        .setPhoneDiscovery(phone, enabled);
    if (ref.mounted) ref.invalidateSelf();
  }

  Future<void> setBlocked(String userId, bool blocked) async {
    await ref.read(voipCallingRepositoryProvider).setBlocked(userId, blocked);
    if (ref.mounted) ref.invalidateSelf();
  }
}
