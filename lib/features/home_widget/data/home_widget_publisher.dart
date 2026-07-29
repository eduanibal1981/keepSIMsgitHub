/// SIM Shield — Home-screen widget publisher (G4)
///
/// The only place that touches the `home_widget` plugin. Everything here is
/// best-effort by design: a home-screen widget is an accessory, and no failure
/// in it — no plugin, no App Group, no launcher — may ever surface in the app
/// or break a provider that happens to be watching.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:keep_sims/features/home_widget/domain/widget_snapshot.dart';

part 'home_widget_publisher.g.dart';

/// Shared-storage key holding the JSON payload.
///
/// Read by `KeepSimsWidgetProvider.kt` (Android `HomeWidgetPreferences`) and
/// `KeepSimsWidget.swift` (iOS App Group `UserDefaults`). The name is part of
/// the contract with both — do not rename without changing them.
const String kWidgetPayloadKey = 'ks_widget_payload';

/// Must match `KeepSimsWidgetProvider`'s class name in the Android manifest.
const String kAndroidWidgetProvider = 'KeepSimsWidgetProvider';

/// Must match the `kind:` of the iOS WidgetKit widget.
const String kIosWidgetKind = 'KeepSimsWidget';

/// Must match the App Group capability on both the Runner and the widget
/// extension targets. Nothing reaches an iOS widget without it.
const String kIosAppGroupId = 'group.com.keep_sims.widget';

@Riverpod(keepAlive: true)
HomeWidgetPublisher homeWidgetPublisher(Ref ref) => const HomeWidgetPublisher();

class HomeWidgetPublisher {
  const HomeWidgetPublisher();

  /// True on the two platforms that have a home screen. Everything else — the
  /// desktop targets, and the Dart VM the tests run on — has no plugin
  /// registered, so calling through would only raise `MissingPluginException`.
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Writes [snapshot] to shared storage and asks both platforms to redraw.
  ///
  /// Returns false when nothing was published — unsupported platform, or the
  /// plugin threw. Never rethrows.
  Future<bool> publish(WidgetSnapshot snapshot) async {
    if (!isSupported) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await HomeWidget.setAppGroupId(kIosAppGroupId);
      }
      await HomeWidget.saveWidgetData<String>(
        kWidgetPayloadKey,
        snapshot.encode(),
      );
      await HomeWidget.updateWidget(
        androidName: kAndroidWidgetProvider,
        iOSName: kIosWidgetKind,
      );
      return true;
    } catch (e) {
      debugPrint('[home_widget] publish skipped: $e');
      return false;
    }
  }

  /// The URI the app was cold-started with, when that was a widget tap.
  Future<Uri?> initialLaunchUri() async {
    if (!isSupported) return null;
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      debugPrint('[home_widget] initial launch check skipped: $e');
      return null;
    }
  }

  /// Taps arriving while the app is already running.
  Stream<Uri?> get taps {
    if (!isSupported) return const Stream<Uri?>.empty();
    try {
      return HomeWidget.widgetClicked;
    } catch (e) {
      debugPrint('[home_widget] tap stream unavailable: $e');
      return const Stream<Uri?>.empty();
    }
  }
}
