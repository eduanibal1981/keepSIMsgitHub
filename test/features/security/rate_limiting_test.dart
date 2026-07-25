import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/utils/error_formatter.dart';

void main() {
  group('RateLimitErrorFormatter - Rate Limit Parsing Tests (Session D2)', () {
    test('parses RATE_LIMITED:<bucket>:<seconds> format from Postgres KS429 exception', () {
      const errorStr = 'PostgrestException(message: Rate limit exceeded: RATE_LIMITED:esim_purchase:45, code: KS429)';
      final seconds = RateLimitErrorFormatter.parseRateLimitSeconds(errorStr);
      expect(seconds, equals(45));
    });

    test('parses rate limit exceeded with generic number', () {
      const errorStr = 'Rate limit exceeded: RATE_LIMITED:topup_line:10';
      final seconds = RateLimitErrorFormatter.parseRateLimitSeconds(errorStr);
      expect(seconds, equals(10));
    });

    test('parses JSON retry_after / retry_after_seconds from HTTP 429 response', () {
      const jsonStr = '{"code":"rate_limited","bucket":"detect_country","retry_after":30}';
      final seconds = RateLimitErrorFormatter.parseRateLimitSeconds(jsonStr);
      expect(seconds, equals(30));
    });

    test('defaults to 60s for generic 429 / too many requests without explicit seconds', () {
      const genericError = 'HTTP 429 Too Many Requests';
      final seconds = RateLimitErrorFormatter.parseRateLimitSeconds(genericError);
      expect(seconds, equals(60));
    });

    test('returns null for non-rate-limit errors', () {
      const otherError = 'PostgrestException(message: Insufficient wallet balance, code: 23514)';
      final seconds = RateLimitErrorFormatter.parseRateLimitSeconds(otherError);
      expect(seconds, isNull);
    });
  });
}
