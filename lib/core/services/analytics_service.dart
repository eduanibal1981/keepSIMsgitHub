import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

/// Basic screen-view and recharge-funnel analytics service.
/// Gated strictly on the user_consents / analytics_tracking_consent_enabled flag.
class AnalyticsService {
  static const String _kTrackingConsentKey = 'analytics_tracking_consent_enabled';

  Future<bool> _hasConsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kTrackingConsentKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Track a screen view event
  Future<void> logScreenView(String screenName) async {
    if (!await _hasConsent()) return;
    debugPrint('[Analytics] Screen View: $screenName');
  }

  /// Track a step in the recharge funnel
  Future<void> logRechargeFunnelStep(String stepName, {Map<String, dynamic>? parameters}) async {
    if (!await _hasConsent()) return;
    debugPrint('[Analytics] Recharge Funnel [$stepName] params: $parameters');
  }
}
