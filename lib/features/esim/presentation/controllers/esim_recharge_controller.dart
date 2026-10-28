import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_recharge.dart';

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
