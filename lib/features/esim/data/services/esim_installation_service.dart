import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_activation_payload.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_installation_policy.dart';

final esimInstallationServiceProvider = Provider<EsimInstallationService>(
  (ref) => EsimInstallationService(),
);

class EsimInstallationService {
  EsimInstallationService({Future<bool> Function(Uri)? launch})
    : _launch = launch ?? _launchExternal;
  final Future<bool> Function(Uri) _launch;
  static const _channel = MethodChannel('com.keep_sims/esim');
  static Future<bool> _launchExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<EsimInstallationEnvironment> environment() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return EsimInstallationEnvironment(
        platform: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? EsimInstallPlatform.android
            : EsimInstallPlatform.other,
      );
    }
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'installationEnvironment',
      );
      return EsimInstallationEnvironment(
        platform: EsimInstallPlatform.ios,
        major: data?['major'] is int ? data!['major'] as int : 0,
        minor: data?['minor'] is int ? data!['minor'] as int : 0,
        physicalDevice: data?['physical_device'] == true,
      );
    } catch (_) {
      // Platform exceptions may embed the sensitive URL. Never log them.
      return const EsimInstallationEnvironment(
        platform: EsimInstallPlatform.ios,
      );
    }
  }

  Future<EsimInstallLaunchResult> openApple(
    EsimActivationPayload payload,
    EsimInstallationEnvironment environment,
  ) async {
    if (!environment.supportsAppleLink) {
      return EsimInstallLaunchResult.unavailable;
    }
    try {
      return await _launch(payload.appleInstallUri)
          ? EsimInstallLaunchResult.opened
          : EsimInstallLaunchResult.failed;
    } catch (_) {
      return EsimInstallLaunchResult.failed;
    }
  }
}
