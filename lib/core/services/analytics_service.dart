import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

/// Real screen-view and recharge-funnel analytics service.
/// Gated strictly on the user_consents table (analytics_consent column).
class AnalyticsService {
  Future<bool> _hasConsent() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final res = await supabase
          .from('user_consents')
          .select('analytics_consent')
          .eq('user_id', userId)
          .maybeSingle();

      if (res != null && res['analytics_consent'] != null) {
        return res['analytics_consent'] as bool;
      }
      return false;
    } catch (e) {
      debugPrint('[Analytics] Consent check error: $e');
      return false;
    }
  }

  /// Track a screen view event
  Future<void> logScreenView(String screenName) async {
    if (!await _hasConsent()) return;
    debugPrint('[Analytics] Screen View: $screenName');
    _persistEvent('screen_view', {'screen_name': screenName});
  }

  /// Track a step in the recharge funnel
  Future<void> logRechargeFunnelStep(String stepName, {Map<String, dynamic>? parameters}) async {
    if (!await _hasConsent()) return;
    debugPrint('[Analytics] Recharge Funnel [$stepName] params: $parameters');
    _persistEvent('recharge_funnel', {'step_name': stepName, ...?parameters});
  }

  Future<void> _persistEvent(String eventType, Map<String, dynamic> payload) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('security_logs').insert({
        'event_type': 'analytics_$eventType',
        'details': payload,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
}
