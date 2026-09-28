import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
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
      'OM': 'Oman',
      'SA': 'Saudi Arabia',
      'KW': 'Kuwait',
      'QA': 'Qatar',
      'BH': 'Bahrain',
      'JO': 'Jordan',
      'PH': 'Philippines',
      'PK': 'Pakistan',
    };

    final currentIso = _detectedIso ?? lastCountryCode ?? homeCountryCode;
    final supportedCountries = ref.watch(supportedCountriesProvider).value ?? [];
    final matchingCountry = supportedCountries
        .where((c) => c.isoCode.trim().toUpperCase() == currentIso.toUpperCase())
        .firstOrNull;
    final currentCountry = _detectedCountry ??
        matchingCountry?.name ??
        (countryNames[currentIso] ?? currentIso);

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

        // The function answers "US" when it cannot resolve the IP at all
        // (loopback, private range, ipapi.co down). That is indistinguishable
        // from a real US user unless it says so, and acting on it would flip
        // every line's protection on a failed lookup — so a detection that did
        // not resolve is treated as no detection.
        final resolved = data['resolved'] as bool? ?? true;

        if (detectedIso != null && detectedIso.isNotEmpty && resolved) {
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

          // Runs on every resolved detection, not only on `status == 'updated'`.
          // 'noop' means the country matches what the profile already stored,
          // and 'suppressed' means the flap guard silenced a *notification* —
          // neither says anything about whether the lines agree. Keying the
          // sync on 'updated' would leave a user who was already abroad when
          // this shipped stuck in the wrong mode forever, which is exactly the
          // state the Saudi line was found in.
          await _syncLineModes(detectedIso);

          ref.invalidateSelf();
        } else if (!resolved) {
          _logs.add('📍 Location could not be resolved — modes left unchanged.');
        }
      }
    } catch (_) {
      // Silent no-op on network / location check failure
    }
  }

  /// Brings every line's `is_home_mode` / `protection_paused` into line with
  /// where the user actually is.
  ///
  /// This is the step the B3 code path documented and no code performed:
  /// `detect-country` wrote `profiles.last_country` and posted a notification,
  /// and nothing ever touched `sim_lines`. The only writers were two UI
  /// switches, so a line kept whatever the user last tapped — a Saudi line sat
  /// in Home Mode, protection paused, while its owner was in Oman.
  Future<void> _syncLineModes(String detectedIso) async {
    // Location-based line protection pause is retired.
    // Lines remain protected regardless of country location.
    return;
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

  /// The country the user is in right now, best-effort.
  ///
  /// Detection first, then the last country the server recorded. The profile's
  /// home country is *not* a fallback: it answers "where does this user live",
  /// which is a different question, and using it here is what made a Saudi line
  /// look local to a user in Oman.
  String? _currentIso() {
    final detected = _detectedIso?.trim().toUpperCase();
    if (detected != null && detected.length == 2) return detected;
    final last = ref
        .read(authControllerProvider)
        .value
        ?.lastCountry
        ?.trim()
        .toUpperCase();
    if (last != null && last.length == 2) return last;
    return null;
  }

  /// The line's country, or null when it has none on file — never a guess.
  ///
  /// The old `orElse` here returned *any* country that wasn't the user's home
  /// one, so a line whose `country_id` didn't match the loaded list was read as
  /// foreign and frozen on that basis alone.
  String? _lineIso(List<Country> countries, String? countryId) {
    if (countryId == null) return null;
    for (final c in countries) {
      if (c.id == countryId) return c.isoCode.trim().toUpperCase();
    }
    return null;
  }

  /// Freezes every line for a country the user is *not* in.
  ///
  /// "International" means away from the user's current location, not away from
  /// `profiles.home_country_code` — an Omani line is local while the user is in
  /// Oman, whatever their profile says.
  Future<void> freezeAllInternationalLines() async {
    final lines = ref.read(simLinesControllerProvider).value ?? [];
    final countries = ref.read(supportedCountriesProvider).value ?? [];
    final currentIso = _currentIso();

    if (currentIso == null) {
      _logs.add('⚠️ Freeze skipped: current country unknown.');
      return;
    }

    _logs.add('❄️ Freeze Request: Pausing all international lines...');

    for (final line in lines) {
      final lineIso = _lineIso(countries, line.countryId);
      if (lineIso == null) {
        _logs.add('❔ Skipped: Line ${line.phoneNumber} has no country on file.');
        continue;
      }

      // Lines flagged requiresProtectionAtHome must never be auto-frozen —
      // a resident's dormant second SIM dies if its refills stop (B5).
      if (line.requiresProtectionAtHome) {
        _logs.add(
          '🛡️ Kept protected: Line ${line.phoneNumber} (always-protected).',
        );
        continue;
      }
      if (lineIso != currentIso && line.status == 'active') {
        await ref
            .read(simLinesControllerProvider.notifier)
            .freezeLine(line.id, true);
        _logs.add('⏸️ Frozen: Line ${line.phoneNumber} ($lineIso).');
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
    final currentIso = _currentIso();

    if (currentIso == null) {
      _logs.add('⚠️ Resume skipped: current country unknown.');
      return;
    }

    _logs.add('🔥 Resume Request: Reactivating international renewals...');

    for (final line in lines) {
      final lineIso = _lineIso(countries, line.countryId);
      if (lineIso == null) {
        _logs.add('❔ Skipped: Line ${line.phoneNumber} has no country on file.');
        continue;
      }
      if (lineIso != currentIso && line.status == 'paused') {
        await ref
            .read(simLinesControllerProvider.notifier)
            .freezeLine(line.id, false);
        _logs.add('▶️ Resumed: Line ${line.phoneNumber} ($lineIso).');
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
