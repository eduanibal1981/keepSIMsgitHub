/// SIM Shield — Auth Session Manager
///
/// Provides mutex-protected token refresh, proactive session freshness verification,
/// and transparent retry interceptors for Supabase PostgREST queries.
library;

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized session freshness and token recovery service.
abstract final class AuthSessionManager {
  static Future<bool>? _inFlightRefresh;

  /// Checks if the current session is expired or expiring within [buffer].
  static bool isSessionExpiredOrExpiring(
    SupabaseClient client, [
    Duration buffer = const Duration(minutes: 2),
  ]) {
    final session = client.auth.currentSession;
    if (session == null) return false;
    if (session.isExpired) return true;

    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      return expiry.isBefore(DateTime.now().add(buffer));
    }
    return false;
  }

  /// Ensures that the active session has a valid, fresh access token.
  ///
  /// Guarantees that only ONE token refresh request is dispatched to Supabase Gotrue
  /// at a time, eliminating token rotation race conditions and token reuse rejections.
  ///
  /// Returns `true` if a valid session is active, or `false` if unauthenticated or
  /// refresh failed. If the refresh token is permanently dead or revoked, signs out.
  static Future<bool> ensureFreshSession(
    SupabaseClient client, {
    bool force = false,
  }) async {
    final session = client.auth.currentSession;
    if (session == null) return false;

    if (!force && !isSessionExpiredOrExpiring(client)) {
      return true;
    }

    if (_inFlightRefresh != null) {
      return await _inFlightRefresh!;
    }

    final completer = Completer<bool>();
    _inFlightRefresh = completer.future;

    try {
      final response = await client.auth.refreshSession();
      final success = response.session != null;
      completer.complete(success);
      return success;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      // If refresh token is revoked, invalid or not found, the session is dead
      if (msg.contains('refresh') ||
          msg.contains('invalid') ||
          msg.contains('not found') ||
          msg.contains('revoked') ||
          msg.contains('expired')) {
        try {
          await client.auth.signOut();
        } catch (_) {}
      }
      completer.complete(false);
      return false;
    } catch (e) {
      // Network or other transient failure; keep session without signing out
      completer.complete(false);
      return false;
    } finally {
      _inFlightRefresh = null;
    }
  }

  /// Wraps an async Supabase database or function operation.
  ///
  /// 1. Pre-checks session freshness before calling [action].
  /// 2. If [action] throws an error indicating an expired JWT (PostgrestException,
  ///    FunctionException, or message matching `JWT expired`), forces a token refresh
  ///    and retries [action] once.
  static Future<T> withAuthRecovery<T>(
    SupabaseClient client,
    Future<T> Function() action,
  ) async {
    // Proactively refresh if session is expired or expiring soon
    await ensureFreshSession(client);

    try {
      return await action();
    } catch (e) {
      if (isJwtExpiredError(e)) {
        final refreshed = await ensureFreshSession(client, force: true);
        if (refreshed) {
          return await action();
        }
      }
      rethrow;
    }
  }

  /// Determines whether an exception represents an expired JWT or auth token failure.
  static bool isJwtExpiredError(Object e) {
    if (e is PostgrestException) {
      final msg = e.message.toLowerCase();
      final code = e.code?.toLowerCase() ?? '';
      return msg.contains('jwt') ||
          msg.contains('token') ||
          code == 'pgrst301' ||
          code == '401';
    }
    if (e is FunctionException) {
      final msg = (e.reasonPhrase ?? '').toLowerCase();
      final details = e.details?.toString().toLowerCase() ?? '';
      return msg.contains('jwt') || details.contains('jwt');
    }
    final errStr = e.toString().toLowerCase();
    return errStr.contains('jwt expired') || errStr.contains('token expired');
  }
}

/// Lifecycle observer that auto-refreshes stale sessions whenever the app returns from background.
class AuthSessionLifecycleObserver with WidgetsBindingObserver {
  final SupabaseClient _client;

  AuthSessionLifecycleObserver(this._client);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AuthSessionManager.ensureFreshSession(_client));
    }
  }
}
