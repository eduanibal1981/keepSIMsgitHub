import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import '../model/geo_state.dart';

part 'geo_controller.g.dart';

@riverpod
class GeoController extends _$GeoController {
  String? _simulatedIso;
  String? _simulatedCountry;
  bool _showFreezePrompt = false;
  bool _showResumePrompt = false;

  final List<String> _logs = [
    '🛡️ Geolocation Shield active and running in background.',
  ];

  @override
  GeoState build() {
    final authProfile = ref.watch(authControllerProvider).valueOrNull;
    final userPrefs = ref.watch(userPreferencesControllerProvider).valueOrNull;

    final homeCountryCode = authProfile?.homeCountryCode ?? 'US';
    final travelMode = userPrefs?.travelModeEnabled ?? false;

    final countryNames = {
      'US': 'United States',
      'GB': 'United Kingdom',
      'AE': 'United Arab Emirates',
      'SG': 'Singapore',
      'JP': 'Japan',
      'IN': 'India',
    };

    final currentIso = _simulatedIso ?? homeCountryCode;
    final currentCountry = _simulatedCountry ?? (countryNames[currentIso] ?? 'Home Country');

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

  /// Board simulated flight to target country triggers instant geofence crossing.
  Future<void> simulateTravelTo(String isoCode, String countryName) async {
    final authProfile = ref.read(authControllerProvider).valueOrNull;
    final homeCountryCode = authProfile?.homeCountryCode ?? 'US';

    _simulatedIso = isoCode;
    _simulatedCountry = countryName;

    final isHome = isoCode == homeCountryCode;

    if (isHome) {
      _showFreezePrompt = true;
      _showResumePrompt = false;
      _logs.add('🏡 Border Simulator: Landed in Home Country ($countryName).');
      _logs.add('📢 Recommendation: Expats back home can freeze active international lines.');
      
      try {
        await ref.read(notificationsRepositoryProvider).simulateNotification(
          'welcome_home_ready',
          'Welcome Home! 🏡',
          'Landed in $countryName. Freeze active international renewals to protect your wallet balance.',
        );
      } catch (_) {}
    } else {
      _showFreezePrompt = false;
      _showResumePrompt = true;
      _logs.add('✈️ Border Simulator: Departed to $countryName ($isoCode).');
      _logs.add('📢 Recommendation: Boarding gates detected. Auto-resume renewals.');

      try {
        await ref.read(notificationsRepositoryProvider).simulateNotification(
          'geo_fence_triggered',
          'Travel Detected! ✈️',
          'Arrived in $countryName. Resume international lines to ensure uninterrupted coverage.',
        );
      } catch (_) {}
    }

    ref.invalidateSelf();
  }

  /// Toggles global travel mode switch.
  Future<void> toggleTravelMode(bool enabled) async {
    _logs.add(enabled ? '🚀 Travel Mode activated.' : '🛑 Travel Mode deactivated.');
    await ref.read(userPreferencesControllerProvider.notifier).toggleTravelMode(enabled);
    ref.invalidateSelf();
  }

  /// Performs bulk updates to freeze all international SIM lines.
  Future<void> freezeAllInternationalLines() async {
    final lines = ref.read(simLinesControllerProvider).valueOrNull ?? [];
    final countries = ref.read(supportedCountriesProvider).valueOrNull ?? [];
    final homeCountryCode = ref.read(authControllerProvider).valueOrNull?.homeCountryCode ?? 'US';

    _logs.add('❄️ Freeze Request: Pausing all international lines...');
    
    for (final line in lines) {
      final country = countries.firstWhere(
        (c) => c.id == line.countryId,
        orElse: () => countries.firstWhere((c) => c.isoCode != homeCountryCode), // fallback
      );
      if (country.isoCode != homeCountryCode && line.status == 'active') {
        await ref.read(simLinesControllerProvider.notifier).updateSimLine(
          line.copyWith(status: 'paused'),
        );
        _logs.add('⏸️ Paused: Line ${line.phoneNumber} (${country.name}).');
      }
    }

    _showFreezePrompt = false;
    _logs.add('✅ Success: Shield paused renewals successfully.');
    ref.invalidateSelf();
  }

  /// Performs bulk updates to resume all paused international SIM renewals.
  Future<void> resumeAllInternationalLines() async {
    final lines = ref.read(simLinesControllerProvider).valueOrNull ?? [];
    final countries = ref.read(supportedCountriesProvider).valueOrNull ?? [];
    final homeCountryCode = ref.read(authControllerProvider).valueOrNull?.homeCountryCode ?? 'US';

    _logs.add('🔥 Resume Request: Reactivating international renewals...');
    
    for (final line in lines) {
      final country = countries.firstWhere(
        (c) => c.id == line.countryId,
        orElse: () => countries.firstWhere((c) => c.isoCode != homeCountryCode),
      );
      if (country.isoCode != homeCountryCode && line.status == 'paused') {
        await ref.read(simLinesControllerProvider.notifier).updateSimLine(
          line.copyWith(status: 'active'),
        );
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
