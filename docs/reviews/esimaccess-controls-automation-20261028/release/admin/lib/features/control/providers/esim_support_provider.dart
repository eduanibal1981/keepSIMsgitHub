import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims_admin/core/admin/admin_providers.dart';
import 'package:keep_sims_admin/features/auth/controller/auth_controller.dart';

typedef EsimSupportKey = ({String owner, String query});
final esimSupportProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, EsimSupportKey>((ref, key) async {
      final owner = ref.watch(authControllerProvider).value?.id;
      if (owner != key.owner) throw Exception('Session changed');
      final result = await ref.read(adminApiProvider).esimSupport(key.query);
      if (!ref.mounted || ref.read(authControllerProvider).value?.id != owner) {
        throw Exception('Session changed');
      }
      return result;
    });
final esimSupportActionsProvider = Provider.autoDispose((ref) {
  ref.watch(authControllerProvider);
  return EsimSupportActions(ref);
});

class EsimSupportActions {
  EsimSupportActions(this.ref);
  final Ref ref;
  Future<void> run(String id, String action, String reason) async {
    final owner = ref.read(authControllerProvider).value?.id;
    if (owner == null) throw Exception('Session changed');
    await ref.read(adminApiProvider).esimSupportAction(id, action, reason);
    if (ref.mounted && ref.read(authControllerProvider).value?.id == owner) {
      ref.invalidate(esimSupportProvider);
    }
  }

  Future<void> pause(String capability, String reason) async {
    if (ref.read(authControllerProvider).value?.id == null) {
      throw Exception('Session changed');
    }
    await ref.read(adminApiProvider).pauseEsimCapability(capability, reason);
    if (ref.mounted) ref.invalidate(esimSupportProvider);
  }
}
