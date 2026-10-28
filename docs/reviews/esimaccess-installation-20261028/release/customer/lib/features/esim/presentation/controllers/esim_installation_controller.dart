import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/data/services/esim_installation_service.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_installation_policy.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'user_esims_controller.dart';

final esimInstallationEnvironmentProvider =
    FutureProvider<EsimInstallationEnvironment>(
      (ref) => ref.watch(esimInstallationServiceProvider).environment(),
    );
final esimInstallationControllerProvider = Provider(
  (ref) => EsimInstallationController(ref),
);

class EsimInstallationController {
  EsimInstallationController(this.ref);
  final Ref ref;

  UserEsim? _current(UserEsim snapshot) {
    final owner = ref.read(authControllerProvider).value?.id;
    if (owner == null || snapshot.userId != owner) return null;
    final saved = ref.read(userEsimsControllerProvider);
    return saved.hasValue
        ? saved.value
              ?.where((p) => p.id == snapshot.id && p.userId == owner)
              .firstOrNull
        : snapshot;
  }

  Future<EsimInstallLaunchResult> openApple(
    UserEsim profile, {
    bool sameDeviceConfirmed = false,
  }) async {
    bool permitted() {
      final current = _current(profile);
      return current != null &&
          EsimInstallationPolicy.forProfile(
            current,
          ).mayReveal(sameDeviceConfirmed: sameDeviceConfirmed);
    }

    if (!permitted()) return EsimInstallLaunchResult.unavailable;
    final environment = await ref.read(
      esimInstallationEnvironmentProvider.future,
    );
    if (!ref.mounted || !permitted()) {
      return EsimInstallLaunchResult.unavailable;
    }
    final payload = _current(profile)?.activationPayload;
    if (payload == null) return EsimInstallLaunchResult.unavailable;
    return ref
        .read(esimInstallationServiceProvider)
        .openApple(payload, environment);
  }
}
