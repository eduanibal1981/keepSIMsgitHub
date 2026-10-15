import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/calling/data/services/device_contact_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.keep_sims/contacts');
  const picker = DeviceContactPicker();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'returns the selected number without losing its country prefix',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'pickPhoneNumber');
        return '+968 9123 4567';
      });
      expect(await picker.pickPhoneNumber(), '+968 9123 4567');
    },
  );

  test('cancellation returns no number', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await picker.pickPhoneNumber(), isNull);
  });

  test(
    'platform failure reaches the caller for manual entry fallback',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'unavailable');
      });
      await expectLater(
        picker.pickPhoneNumber(),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
