import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims_admin/core/admin/admin_providers.dart';
import 'package:keep_sims_admin/features/auth/controller/auth_controller.dart';

typedef EsimOperationKey = ({String owner, String orderId});
final esimOperationTimelineProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, EsimOperationKey>((ref, key) async {
      final auth = ref.watch(authControllerProvider);
      if (auth.isLoading || auth.hasError || auth.value?.id != key.owner) {
        throw Exception('Session changed');
      }
      final result = await ref
          .read(adminApiProvider)
          .esimOperationTimeline(key.orderId);
      if (!ref.mounted ||
          ref.read(authControllerProvider).value?.id != key.owner) {
        throw Exception('Session changed');
      }
      return result;
    });
