import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import '../model/geo_state.dart';

part 'geo_controller.g.dart';

@riverpod
class GeoController extends _$GeoController {
  String? _detectedIso;
  String? _detectedCountry;
  bool _showFreezePrompt = false;
  bool _showResumePrompt = false;

  final List<String> _logs = [];

  @override
  GeoState build() {
    final authProfile = ref.watch(authControllerProvider).value;
    final userPrefs = ref.watch(userPreferencesControllerProvider).value;

    final homeCountryCode = authProfile?.homeCountryCode ?? 'US';
    final lastCountryCode = authProfile?.lastCountry;
    final travelMode = userPrefs?.travelModeEnabled ?? false;

    final countryNames = {
      'US': 'United States',
      'GB': 'United Kingdom',
      'AE': 'United Arab Emirates',
      'SG': 'Singapore',
      'JP': 'Japan',
      'IN': 'India',
      'DE': 'Germany',
      'FR': 'France',
      'EG': 'Egypt',
      'LK': 'Sri Lanka',
      'TR': 'Turkey',
      'ES': 'Spain',
      'NP': 'Nepal',
      'BD': 'Bangladesh',
    };

    final currentIso = _detectedIso ?? lastCountryCode ?? homeCountryCode;
    final currentCountry = _detectedCountry ?? (countryNames[currentIso] ?? currentIso);

    final isHome = currentIso == homeCountryCode;

    return GeoState(
      currentCountry: currentCountry,
      currentIsoCode: currentIso,
      travelModeEnabled: travelMode,
      promptFreeze: isHome && _showFreezePrompt,
      promptResume: !isHome && _showResumePrompt,
      logs: List.unmodifiable(_logs),
      isProcessing: false,
    );
  }

  /// Triggers IP-based country detection via detect-country Edge Function on app open / resume.
  Future<void> checkCurrentLocationOnAppOpen() async {
    try {
      final response = await Supabase.instance.client.functions.invoke('detect-country');
      if (response.status == 200 && response.data != null) {
        final Map<String, dynamic> data = response.data is String
            ? jsonDecode(response.data as String)
            : (response.data as Map<String, dynamic>);

        final status = data['status'] as String?;
        final detectedIso = data['detected_country'] as String?;

        if (detectedIso != null && detectedIso.isNotEmpty) {
          _detectedIso = detectedIso;
          _logs.add('📍 Location checked via IP: $detectedIso ($status)');

          final authProfile = ref.read(authControllerProvider).value;
          final homeCountryCode = authProfile?.homeCountryCode ?? 'US';

          if (status == 'updated') {
            if (detectedIso == homeCountryCode) {
              _showFreezePrompt = true;
              _showResumePrompt = false;
            } else {
              _showFreezePrompt = false;
              _showResumePrompt = true;
            }
            ref.invalidate(authControllerProvider);
          }

          ref.invalidateSelf();
        }
      }
    } catch (_) {
      // Silent no-op on network / location check failure
    }
  }

  /// Toggles global travel mode switch.
  Future<void> toggleTravelMode(bool enabled) async {
    _logs.add(
      enabled ? '🚀 Travel Mode activated.' : '🛑 Travel Mode deactivated.',
    );
    await ref
        .read(userPreferencesControllerProvider.notifier)
        .toggleTravelMode(enabled);
    if (enabled) {
      await checkCurrentLocationOnAppOpen();
    }
    ref.invalidateSelf();
  }

  /// Performs bulk updates to freeze all international SIM lines (fixing cosmetic freeze).
  Future<void> freezeAllInternationalLines() async {
    final lines = ref.read(simLinesControllerProvider).value ?? [];
    final countries = ref.read(supportedCountriesProvider).value ?? [];
    final homeCountryCode =
        ref.read(authControllerProvider).value?.homeCountryCode ?? 'US';

    _logs.add('❄️ Freeze Request: Pausing all international lines...');

    for (final line in lines) {
      final country = countries.firstWhere(
        (c) => c.id == line.countryId,
        orElse: () => countries.firstWhere(
          (c) => c.isoCode != homeCountryCode,
        ),
      );

      // Lines flagged requiresProtectionAtHome must never be auto-frozen —
      // a resident's dormant second SIM dies if its refills stop (B5).
      if (line.requiresProtectionAtHome) {
        _logs.add(
          '🛡️ Kept protected: Line ${line.phoneNumber} (always-protected).',
        );
        continue;
      }
      if (country.isoCode != homeCountryCode && line.status == 'active') {
        await ref
            .read(simLinesControllerProvider.notifier)
            .freezeLine(line.id, true);
        _logs.add('⏸️ Frozen: Line ${line.phoneNumber} (${country.name}).');
      }
    }

    _showFreezePrompt = false;
    _logs.add('✅ Success: Shield paused renewals successfully.');
    ref.invalidateSelf();
  }

  /// Performs bulk updates to resume all paused international SIM renewals.
  Future<void> resumeAllInternationalLines() async {
    final lines = ref.read(simLinesControllerProvider).value ?? [];
    final countries = ref.read(supportedCountriesProvider).value ?? [];
    final homeCountryCode =
        ref.read(authControllerProvider).value?.homeCountryCode ?? 'US';

    _logs.add('🔥 Resume Request: Reactivating international renewals...');

    for (final line in lines) {
      final country = countries.firstWhere(
        (c) => c.id == line.countryId,
        orElse: () => countries.firstWhere((c) => c.isoCode != homeCountryCode),
      );
      if (country.isoCode != homeCountryCode && line.status == 'paused') {
        await ref
            .read(simLinesControllerProvider.notifier)
            .freezeLine(line.id, false);
        _logs.add('▶️ Resumed: Line ${line.phoneNumber} (${country.name}).');
      }
    }

    _showResumePrompt = false;
    _logs.add('✅ Success: Renewals are now active.');
    ref.invalidateSelf();
  }

  /// Discards freeze dialog recommendation banner.
  void dismissFreezePrompt() {
    _showFreezePrompt = false;
    _logs.add('🙈 Recommendation dismissed.');
    ref.invalidateSelf();
  }

  /// Discards resume dialog recommendation banner.
  void dismissResumePrompt() {
    _showResumePrompt = false;
    _logs.add('🙈 Recommendation dismissed.');
    ref.invalidateSelf();
  }
}
