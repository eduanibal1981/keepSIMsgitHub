import 'package:flutter/widgets.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

/// Central utility for parsing and formatting user-facing error messages,
/// specifically handling rate limit (KS429 / HTTP 429) responses.
class RateLimitErrorFormatter {
  /// Formats an error into a localized, user-friendly message.
  static String format(Object? error, BuildContext context) {
    if (error == null) return '';
    final message = error.toString();
    final l = AppLocalizations.of(context);

    final seconds = parseRateLimitSeconds(message);
    if (seconds != null) {
      return l?.rateLimitExceeded(seconds.toString()) ??
          'Too many requests. Please wait $seconds seconds before trying again.';
    }

    return message.replaceAll(RegExp(r'^Exception:\s*'), '');
  }

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
