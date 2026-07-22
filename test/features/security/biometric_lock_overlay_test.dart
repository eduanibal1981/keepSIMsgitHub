import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/core/services/biometric_lock_controller.dart';
import 'package:keep_sims/core/widgets/biometric_lock_overlay.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'fake_biometric_auth_service.dart';

class MemorySecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    Object? iIOSOptions,
    Object? aOptions,
    Object? mOptions,
    Object? webOptions,
    Object? macOsOptions,
    Object? windowsOptions,
    Object? linuxOptions,
    Object? iOptions,
    Object? lOptions,
    Object? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    Object? iIOSOptions,
    Object? aOptions,
    Object? mOptions,
    Object? webOptions,
    Object? macOsOptions,
    Object? windowsOptions,
    Object? linuxOptions,
    Object? iOptions,
    Object? lOptions,
    Object? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }
}

void main() {
  group('BiometricLockOverlay Widget Tests', () {
    testWidgets('renders child normally when lock is disabled',
        (WidgetTester tester) async {
      final storage = MemorySecureStorage();
      await storage.write(key: kBiometricLockStorageKey, value: 'false');
      final fakeService = FakeBiometricAuthService(isAvailable: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            biometricAuthServiceProvider.overrideWithValue(fakeService),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BiometricLockOverlay(
              child: Scaffold(
                body: Text('Protected Content'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Protected Content'), findsOneWidget);
      expect(find.text('KeepSIMs is Locked'), findsNothing);
    });

    testWidgets('shows overlay when lock is enabled and unlocks on success',
        (WidgetTester tester) async {
      final storage = MemorySecureStorage();
      await storage.write(key: kBiometricLockStorageKey, value: 'true');
      final fakeService = FakeBiometricAuthService(
        isAvailable: true,
        nextResult: BiometricResult.success,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            biometricAuthServiceProvider.overrideWithValue(fakeService),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BiometricLockOverlay(
              child: Scaffold(
                body: Text('Protected Content'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Protected Content'), findsOneWidget);
    });
  });
}
