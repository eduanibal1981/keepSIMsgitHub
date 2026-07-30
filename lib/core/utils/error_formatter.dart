import 'package:flutter/widgets.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

/// Central utility for parsing and formatting user-facing error messages,
/// specifically handling rate limit (KS429 / HTTP 429) responses and the G10
/// device-risk refusal (KS451 / `DEVICE_BLOCKED`).
class RateLimitErrorFormatter {
  /// Formats an error into a localized, user-friendly message.
  static String format(Object? error, BuildContext context) {
    if (error == null) return '';
    final message = error.toString();
    final l = AppLocalizations.of(context);

    // G10: never echo the raw reason. "accounts_on_device" tells the person who
    // triggered it exactly which threshold to stay under next time.
    if (isDeviceBlocked(message)) {
      return l?.deviceBlockedMessage ??
          'A security check on this device stopped this payment. If this is a '
              'mistake, contact support and we will sort it out.';
    }

    final seconds = parseRateLimitSeconds(message);
    if (seconds != null) {
      return l?.rateLimitExceeded(seconds.toString()) ??
          'Too many requests. Please wait $seconds seconds before trying again.';
    }

    return message.replaceAll(RegExp(r'^Exception:\s*'), '');
  }

  /// True when an error came from the G10 device risk guard, in either of the
  /// two shapes the server uses: the raised `KS451` (message
  /// `DEVICE_BLOCKED:<reason>`) or the jsonb `code: 'DEVICE_BLOCKED'`.
  static bool isDeviceBlocked(String errorStr) =>
      errorStr.contains('DEVICE_BLOCKED') || errorStr.contains('KS451');

  /// Parses rate limit retry seconds from exception strings or response payloads.
  /// Supports:
  /// - `RATE_LIMITED:<bucket>:<seconds>`
  /// - `Rate limit exceeded: RATE_LIMITED:...`
  /// - `retry_after:<seconds>` or `retry_after_seconds:<seconds>`
  /// - Generic HTTP 429 status code
  static int? parseRateLimitSeconds(String errorStr) {
    // 1. Matches RATE_LIMITED:<bucket>:<seconds>
    final rateLimitedMatch = RegExp(
      r'RATE_LIMITED:[a-zA-Z0-9_]+:(\d+)',
      caseSensitive: false,
    ).firstMatch(errorStr);
    if (rateLimitedMatch != null) {
      return int.tryParse(rateLimitedMatch.group(1)!);
    }

    // 2. Matches "rate limit exceeded... <seconds>" or "COOLDOWN_ACTIVE... <seconds>"
    final rateLimitGeneralMatch = RegExp(
      r'(?:rate limit exceeded|COOLDOWN_ACTIVE).*?\b(\d+)\b',
      caseSensitive: false,
    ).firstMatch(errorStr);
    if (rateLimitGeneralMatch != null) {
      return int.tryParse(rateLimitGeneralMatch.group(1)!);
    }

    // 3. Matches retry_after or retry_after_seconds in JSON or headers
    final retryAfterMatch = RegExp(
      r'retry_after(?:_seconds)?["\s:=]+(\d+)',
      caseSensitive: false,
    ).firstMatch(errorStr);
    if (retryAfterMatch != null) {
      return int.tryParse(retryAfterMatch.group(1)!);
    }

    // 4. Matches HTTP 429 or status 429 without explicit seconds
    if (errorStr.contains('429') || errorStr.toLowerCase().contains('too many requests')) {
      return 60;
    }

    return null;
  }
}
