import 'package:flutter/services.dart';

/// Opens the system picker and receives only the selected phone number.
class DeviceContactPicker {
  const DeviceContactPicker();

  static const _channel = MethodChannel('com.keep_sims/contacts');

  /// Returns null when the user cancels; unsupported platforms throw.
  Future<String?> pickPhoneNumber() =>
      _channel.invokeMethod<String>('pickPhoneNumber');
}
