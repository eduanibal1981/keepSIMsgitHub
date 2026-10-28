import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims_admin/core/admin/admin_providers.dart';
import 'package:keep_sims_admin/features/auth/controller/auth_controller.dart';

typedef EsimGroupKey = ({String owner, String groupId});
final esimGroupTimelineProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, EsimGroupKey>((ref, key) async {
      final auth = ref.watch(authControllerProvider);
      if (auth.isLoading || auth.hasError || auth.value?.id != key.owner) {
        throw Exception('Session changed');
      }
      final result = await ref.read(adminApiProvider).esimGroup(key.groupId);
      if (!ref.mounted ||
          ref.read(authControllerProvider).value?.id != key.owner) {
        throw Exception('Session changed');
      }
      return result;
    });

final esimGroupActionsProvider = Provider.autoDispose((ref) {
  ref.watch(authControllerProvider);
  return EsimGroupSupportActions(ref);
});

class EsimGroupSupportActions {
  EsimGroupSupportActions(this.ref);
  final Ref ref;
  Future<void> pause(String reason) async {
    final owner = ref.read(authControllerProvider).value?.id;
    if (owner == null) {
      throw Exception('Session changed');
    }
    await ref.read(adminApiProvider).pauseEsimGroups(reason);
    if (ref.mounted && ref.read(authControllerProvider).value?.id == owner) {
      ref.invalidate(esimGroupTimelineProvider);
    }
  }
}
