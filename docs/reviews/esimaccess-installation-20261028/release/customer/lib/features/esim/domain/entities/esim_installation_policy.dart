import 'user_esim.dart';

enum EsimInstallationState { ready, installed, sameDeviceRecovery, unavailable }

class EsimInstallationPolicy {
  const EsimInstallationPolicy(this.state, this.message);
  final EsimInstallationState state;
  final String message;

  factory EsimInstallationPolicy.forProfile(UserEsim profile, {DateTime? now}) {
    final clock = (now ?? DateTime.now()).toUtc();
    if (profile.provider != 'esimaccess') {
      return const EsimInstallationPolicy(
        EsimInstallationState.unavailable,
        'Installation support is unavailable for this profile provider. Contact KeepSIMs support.',
      );
    }
    if (profile.isTerminal ||
        ['expired', 'cancelled'].contains(profile.bundleState)) {
      return const EsimInstallationPolicy(
        EsimInstallationState.unavailable,
        'This profile is expired, cancelled or revoked. Installation is unavailable; contact KeepSIMs support if the status is unexpected.',
      );
    }
    if (profile.expiresAt != null &&
        !profile.expiresAt!.toUtc().isAfter(clock)) {
      return const EsimInstallationPolicy(
        EsimInstallationState.unavailable,
        'The confirmed validity end has passed. Refresh the profile or contact KeepSIMs support before installing.',
      );
    }
    if ([
      'downloaded',
      'installed',
      'enabled',
      'disabled',
    ].contains(profile.installationState)) {
      return const EsimInstallationPolicy(
        EsimInstallationState.installed,
        'This eSIM has already been downloaded or installed. Use your phone’s SIM settings to enable it. Do not delete it to fix a connection issue.',
      );
    }
    if (!profile.hasActivationPayload) {
      return const EsimInstallationPolicy(
        EsimInstallationState.unavailable,
        'Installation details are awaiting provider verification. No usable activation code is available yet.',
      );
    }
    if (profile.installationState == 'deleted') {
      final observed = profile.lastObservationAt?.toUtc();
      final fresh =
          observed != null &&
          !observed.isBefore(clock.subtract(const Duration(hours: 6))) &&
          !observed.isAfter(clock.add(const Duration(minutes: 5)));
      if (!fresh ||
          profile.profileState != 'active' ||
          profile.bundleState != 'active' ||
          profile.expiresAt == null ||
          profile.usageErrorCode != null) {
        return const EsimInstallationPolicy(
          EsimInstallationState.unavailable,
          'Deletion is reported, but current recovery eligibility is not confirmed. Refresh the profile and contact KeepSIMs support. Do not try the code on another device.',
        );
      }
      return const EsimInstallationPolicy(
        EsimInstallationState.sameDeviceRecovery,
        'Deletion is reported for a currently valid profile. You may try its original code on the same device only. Provider approval can still be required.',
      );
    }
    if (profile.activationDeadlineAt != null &&
        !profile.activationDeadlineAt!.toUtc().isAfter(clock)) {
      return const EsimInstallationPolicy(
        EsimInstallationState.unavailable,
        'The confirmed activation deadline has passed. Refresh the profile or contact KeepSIMs support.',
      );
    }
    if (profile.installationState == 'released' &&
        profile.profileState == 'issued') {
      return const EsimInstallationPolicy(
        EsimInstallationState.ready,
        'Install only on the phone that will use this eSIM. Check the activation trigger below before continuing.',
      );
    }
    return const EsimInstallationPolicy(
      EsimInstallationState.unavailable,
      'Installation state is not confirmed. Refresh the profile or contact KeepSIMs support before installing.',
    );
  }

  bool mayReveal({bool sameDeviceConfirmed = false}) =>
      state == EsimInstallationState.ready ||
      (state == EsimInstallationState.sameDeviceRecovery &&
          sameDeviceConfirmed);
}

enum EsimInstallPlatform { ios, android, other }

class EsimInstallationEnvironment {
  const EsimInstallationEnvironment({
    required this.platform,
    this.major = 0,
    this.minor = 0,
    this.physicalDevice = false,
  });
  final EsimInstallPlatform platform;
  final int major, minor;
  final bool physicalDevice;

  bool get supportsAppleLink =>
      platform == EsimInstallPlatform.ios &&
      physicalDevice &&
      (major > 17 || (major == 17 && minor >= 4));
}

enum EsimInstallLaunchResult { opened, unavailable, failed }
