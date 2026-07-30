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

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';

part 'fx_provider.g.dart';

/// The caller's display-currency context.
///
/// Never throws into the UI: money has to render even when this call fails, so
/// any error degrades to plain USD rather than blanking a wallet balance.
@Riverpod(keepAlive: true)
class FxController extends _$FxController {
  @override
  Future<FxContext> build() async {
    try {
      final row = await Supabase.instance.client.rpc('get_fx_display_context');
      if (row == null) return const FxContext();
      return FxContext.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      // Signed out, offline, or the RPC is unavailable. Dollars still work.
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
        ref.invalidateSelf();
        await future;
        return true;
      case Failure():
        return false;
    }
  }
}
