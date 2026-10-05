/// SIM Shield — display-currency providers (G11)
///
/// `get_fx_display_context()` is `SECURITY INVOKER`, so there is nothing to
/// pass for identity: it reads the caller's own `profiles` row under RLS.
///
/// This provider is deliberately the *only* way the app learns its display
/// currency. Reading `profile.preferredCurrency` directly would skip the
/// server's staleness verdict and happily render a three-week-old rate as
/// though it were today's.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';

part 'fx_provider.g.dart';

/// Injectable read boundary for display context; never used by a money path.
final fxDisplayContextLoaderProvider = Provider<Future<FxContext> Function()>((
  ref,
) {
  return () async {
    final row = await Supabase.instance.client.rpc('get_fx_display_context');
    if (row == null) return const FxContext();
    return FxContext.fromJson(Map<String, dynamic>.from(row as Map));
  };
});

/// Server age is rounded to two places. Leave a minute for that rounding,
/// plus time spent fetching. Never extend a near-expiry quote via clamping.
Duration? fxRefreshDelay(FxContext context, Duration requestElapsed) {
  final age = context.ageHours;
  if (age == null ||
      !age.isFinite ||
      age < 0 ||
      !context.maxAgeHours.isFinite ||
      context.maxAgeHours <= 0) {
    return null;
  }
  final remainingMilliseconds = (context.maxAgeHours - age) * 3600000;
  if (!remainingMilliseconds.isFinite) return null;
  final remaining =
      Duration(milliseconds: remainingMilliseconds.floor()) -
      const Duration(minutes: 1) -
      requestElapsed;
  if (remaining <= Duration.zero) return null;
  // Refresh two hours before expiry, or sooner if the safe lifetime is short.
  final proactive = remaining - const Duration(hours: 2);
  if (proactive > const Duration(hours: 6)) return const Duration(hours: 6);
  return proactive > Duration.zero ? proactive : remaining;
}

/// The caller's display-currency context.
///
/// Never throws into the UI: money has to render even when this call fails, so
/// any error degrades to plain USD rather than blanking a wallet balance.
@Riverpod(keepAlive: true)
class FxController extends _$FxController {
  @override
  Future<FxContext> build() async {
    final identity = ref.watch(
      authControllerProvider.select((auth) {
        if (auth.isLoading || auth.hasError) return null;
        final profile = auth.asData?.value;
        return profile == null ? null : (profile.id, profile.preferredCurrency);
      }),
    );
    if (identity == null) return const FxContext();

    Timer? refreshTimer;
    var active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    void pause() {
      active = false;
      refreshTimer?.cancel();
    }

    final lifecycle = AppLifecycleListener(
      onHide: pause,
      onPause: pause,
      onResume: () {
        active = true;
        if (ref.mounted) ref.invalidateSelf();
      },
    );
    ref.onDispose(() {
      refreshTimer?.cancel();
      lifecycle.dispose();
    });
    void schedule(Duration delay) {
      if (!ref.mounted || !active) return;
      refreshTimer = Timer(delay, () {
        if (ref.mounted) ref.invalidateSelf();
      });
    }

    final elapsed = Stopwatch()..start();
    try {
      final context = await ref.read(fxDisplayContextLoaderProvider)();
      if (!ref.mounted) return const FxContext();
      if (context.convertsMoney) {
        final delay = fxRefreshDelay(context, elapsed.elapsed);
        if (delay == null) {
          schedule(const Duration(minutes: 5));
          return context.copyWith(
            currency: 'USD',
            rate: 1,
            symbol: r'$',
            decimalDigits: 2,
            fallbackReason: 'refresh_required',
          );
        }
        schedule(delay);
      } else {
        // Recover from a server fallback without polling in the background.
        schedule(const Duration(minutes: 5));
      }
      return context;
    } catch (_) {
      // Signed out, offline, or the RPC is unavailable. Dollars still work.
      schedule(const Duration(minutes: 5));
      return const FxContext();
    }
  }

  /// Persist a new display currency to `profiles.preferred_currency`.
  ///
  /// Writes through the same repository as the rest of the profile so the
  /// column-grant allow-list in `toClientWritableJson()` keeps applying — a
  /// direct `.update({'preferred_currency': …})` would work today and break the
  /// moment F6's grants are revisited.
  Future<bool> setDisplayCurrency(String code) async {
    final profile = ref.read(authControllerProvider).value;
    if (profile == null) return false;

    final result = await ref
        .read(profileRepositoryProvider)
        .updateProfile(profile.copyWith(preferredCurrency: code));

    switch (result) {
      case Success():
        // The profile drives the RPC's answer, so both have to be re-read —
        // and in this order, or the refreshed context is computed from the
        // stale profile.
        ref.invalidate(authControllerProvider);
        await ref.read(authControllerProvider.future);
        if (!ref.mounted) return false;
        ref.invalidateSelf();
        await future;
        return true;
      case Failure():
        return false;
    }
  }
}
