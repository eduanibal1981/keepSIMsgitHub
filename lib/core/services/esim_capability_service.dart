/// eSIM Capability Service
///
/// Uses Flutter Platform Channels to detect whether the device's hardware
/// supports eSIM (eUICC) provisioning.
///
/// - **Android (API 28+):** `EuiccManager.isEnabled()`
/// - **iOS (12.0+):** `CTCellularPlanSupportsEsim()`
///
/// Returns `false` as a safe fallback for emulators, older OS versions,
/// web, and desktop platforms.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'esim_capability_service.g.dart';

/// Platform channel name shared with native Android/iOS code.
const _kChannelName = 'com.keep_sims/esim';

/// Method name expected by the native handlers.
const _kMethodIsSupported = 'isEsimSupported';

/// Riverpod provider that caches the eSIM capability check result.
///
/// The result is evaluated once at app startup and kept alive for the
/// lifetime of the process — eSIM hardware support does not change
/// at runtime.
@Riverpod(keepAlive: true)
class EsimCapabilityService extends _$EsimCapabilityService {
  static const _channel = MethodChannel(_kChannelName);

  @override
  Future<bool> build() async {
    return _checkEsimSupport();
  }

  /// Invokes the native platform channel to query eSIM support.
  ///
  /// Returns `false` on any error (MissingPluginException on desktop/web,
  /// PlatformException on misconfigured hosts, etc.).
  Future<bool> _checkEsimSupport() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        _kMethodIsSupported,
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('eSIM capability check failed: ${e.message}');
      return false;
    } on MissingPluginException {
      // Expected on web / desktop where the channel isn't registered.
      debugPrint('eSIM platform channel not available on this platform.');
      return false;
    }
  }
}
