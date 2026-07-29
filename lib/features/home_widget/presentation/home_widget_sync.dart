/// SIM Shield — Home-screen widget sync (G4)
///
/// Keeps the native home-screen widgets in step with whatever the app last
/// managed to load, and routes a widget tap back into the app.
///
/// Mounted once from the app root. It watches the same providers the dashboard
/// does, so the widget is fed from the offline cache for free: when
/// `SimLinesController` falls back to `cached_sim_lines`, the widget gets the
/// cached lines, and the payload it writes then keeps rendering with the app
/// closed and the radio off.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';
import 'package:keep_sims/features/home_widget/data/home_widget_publisher.dart';
import 'package:keep_sims/features/home_widget/data/live_activity_service.dart';
import 'package:keep_sims/features/home_widget/domain/widget_snapshot.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/usage_forecast_provider.dart';

part 'home_widget_sync.g.dart';

/// Returns the payload most recently handed to the platform, or null when
/// nothing has been published (unsupported platform, or the plugin refused).
/// Exposed mainly so the state is inspectable in devtools; nothing reads it.
@Riverpod(keepAlive: true)
class HomeWidgetSync extends _$HomeWidgetSync {
  StreamSubscription<Uri?>? _tapSub;
  bool _consumedLaunchUri = false;

  /// A tap that arrived before the session did. Held rather than dropped so
  /// tapping a line on the widget still lands on that line after the login
  /// redirect, instead of dumping the user on the dashboard.
  String? _pendingRoute;

  String? _lastPublished;

  @override
  String? build() {
    final publisher = ref.watch(homeWidgetPublisherProvider);
    if (!publisher.isSupported) return null;

    _wireTaps(publisher);

    final profile = ref.watch(authControllerProvider).value;
    if (profile == null) {
      // Signing out has to clear the home screen too — otherwise the previous
      // account's lines stay legible on the device indefinitely.
      return _publish(publisher, WidgetSnapshot.signedOut(DateTime.now()));
    }

    _drainPendingRoute();

    final snapshot = buildWidgetSnapshot(
      signedIn: true,
      now: DateTime.now(),
      lines: ref.watch(simLinesControllerProvider).value ?? const [],
      esims: ref.watch(userEsimsControllerProvider).value ?? const [],
      forecasts: ref.watch(usageForecastsProvider).value ?? const [],
    );

    return _publish(publisher, snapshot);
  }

  /// Publishes unless the payload is byte-identical to the last one. Riverpod
  /// rebuilds this on every dependency change, several of which land in a burst
  /// at startup; a redraw the launcher does not need is wasted work.
  String? _publish(HomeWidgetPublisher publisher, WidgetSnapshot snapshot) {
    final String encoded = snapshot.encode();
    if (encoded == _lastPublished) return _lastPublished;
    _lastPublished = encoded;
    unawaited(publisher.publish(snapshot));
    // Read the service *before* the async gap: this provider can be recomputed
    // while the calls are still in flight, and `ref` is not usable after that.
    unawaited(
      _refreshLiveActivities(ref.read(liveActivityServiceProvider), snapshot),
    );
    return encoded;
  }

  /// Keeps any pinned iOS Live Activity in step with the same numbers.
  ///
  /// Fired blindly: updating a subject nobody pinned is a no-op natively, and
  /// off iOS the whole service is inert. Signing out unpins everything, so one
  /// account's SIMs never linger on the next person's Lock Screen.
  Future<void> _refreshLiveActivities(
    LiveActivityService service,
    WidgetSnapshot snapshot,
  ) async {
    if (!snapshot.signedIn) {
      await service.endAll();
      return;
    }
    for (final subject in snapshot.subjects) {
      await service.update(subject);
    }
  }

  void _wireTaps(HomeWidgetPublisher publisher) {
    if (_tapSub != null) return;

    _tapSub = publisher.taps.listen(_handleUri);
    ref.onDispose(() {
      _tapSub?.cancel();
      _tapSub = null;
    });

    if (!_consumedLaunchUri) {
      _consumedLaunchUri = true;
      unawaited(publisher.initialLaunchUri().then(_handleUri));
    }
  }

  void _handleUri(Uri? uri) {
    // Anything that is not one of our own widget links is dropped, not
    // followed: the launcher is an untrusted caller.
    final String? route = widgetDeepLinkToRoute(uri);
    if (route == null) return;

    if (ref.read(authControllerProvider).value == null) {
      _pendingRoute = route;
      return;
    }
    _navigate(route);
  }

  void _drainPendingRoute() {
    final String? route = _pendingRoute;
    if (route == null) return;
    _pendingRoute = null;
    // After the router has finished the post-login redirect it is about to run.
    Future.microtask(() => _navigate(route));
  }

  void _navigate(String route) {
    try {
      // `appRouterProvider` is declared as `RouterConfig<Object>`; the concrete
      // instance is a GoRouter, and only that has `go`.
      final router = ref.read(appRouterProvider);
      if (router is GoRouter) router.go(route);
    } catch (e) {
      debugPrint('[home_widget] could not open $route: $e');
    }
  }
}
