/// SIM Shield — Live Activity bridge (G4)
///
/// Pins one SIM's remaining data or validity to the iOS Lock Screen and
/// Dynamic Island. Backed by `LiveActivityBridge.swift` over the
/// `com.keep_sims/live_activity` MethodChannel.
///
/// Every method is a safe no-op off iOS, so callers never have to branch on
/// the platform. [update] and [end] may be fired blindly: ending or updating an
/// activity that was never started does nothing on the native side.
///
/// **⚠️ Unverified.** The Swift half has never been compiled — this project has
/// no Mac and no Apple Developer account (owner checklist #2), and the widget
/// extension target does not exist in `Runner.xcodeproj` yet. On Android and in
/// tests this file is inert by construction; on iOS it is a first draft.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:keep_sims/features/home_widget/domain/widget_snapshot.dart';

part 'live_activity_service.g.dart';

@Riverpod(keepAlive: true)
LiveActivityService liveActivityService(Ref ref) => const LiveActivityService();

class LiveActivityService {
  const LiveActivityService();

  static const MethodChannel _channel = MethodChannel(
    'com.keep_sims/live_activity',
  );

  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// True only when the platform can show a Live Activity *and* the user has
  /// not turned them off for this app in Settings.
  Future<bool> isSupported() async {
    if (!_isIos) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (e) {
      debugPrint('[live_activity] support check skipped: $e');
      return false;
    }
  }

  /// Pins [subject] to the Lock Screen. Starting one that is already pinned
  /// updates it rather than stacking a duplicate.
  Future<bool> start(WidgetSubject subject) => _invoke('start', subject);

  /// Refreshes a pinned subject. Cheap and safe to call on every publish.
  Future<bool> update(WidgetSubject subject) => _invoke('update', subject);

  /// Unpins one subject.
  Future<bool> end(String subjectId) async {
    if (!_isIos) return false;
    return _send('end', {'subjectId': subjectId});
  }

  /// Unpins everything — what sign-out calls, so one account's SIMs never stay
  /// on the next person's Lock Screen.
  Future<bool> endAll() async {
    if (!_isIos) return false;
    return _send('endAll', const {});
  }

  Future<bool> _invoke(String method, WidgetSubject subject) async {
    if (!_isIos) return false;
    return _send(method, {
      'subjectId': subject.id,
      'kind': subject.kind.name,
      'title': subject.title,
      'subtitle': subject.subtitle,
      'metric': subject.metric,
      'metricLabel': subject.metricLabel,
      'percent': subject.percent,
      'severity': subject.severity.name,
      'depletesAtMs': subject.depletesAt?.toUtc().millisecondsSinceEpoch
          .toDouble(),
    });
  }

  Future<bool> _send(String method, Map<String, dynamic> args) async {
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } catch (e) {
      debugPrint('[live_activity] $method skipped: $e');
      return false;
    }
  }
}
