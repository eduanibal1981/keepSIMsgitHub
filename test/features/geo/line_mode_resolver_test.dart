import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/geo/domain/line_mode_resolver.dart';

void main() {
  group('resolveLineMode', () {
    test('a line whose country the user is not in is Travel Mode', () {
      // The live bug, as found: profile home EG, user in OM, line in SA. The
      // old code compared the detected country against the *profile* home and
      // called this Home Mode.
      final decision = resolveLineMode(
        detectedIso: 'OM',
        lineCountryIso: 'SA',
        isHomeMode: true,
        protectionPaused: true,
        requiresProtectionAtHome: false,
      );

      expect(decision, isNotNull);
      expect(decision!.isHomeMode, isFalse);
      expect(decision.protectionPaused, isFalse);
    });

    test('a line whose country the user is in is Home Mode and pauses', () {
      final decision = resolveLineMode(
        detectedIso: 'OM',
        lineCountryIso: 'OM',
        isHomeMode: false,
        protectionPaused: false,
        requiresProtectionAtHome: false,
      );

      expect(decision!.isHomeMode, isTrue);
      expect(decision.protectionPaused, isTrue);
    });

    test('requiresProtectionAtHome keeps protection running while home', () {
      // B5: a resident's dormant second SIM dies if its refills stop.
      final decision = resolveLineMode(
        detectedIso: 'EG',
        lineCountryIso: 'EG',
        isHomeMode: false,
        protectionPaused: false,
        requiresProtectionAtHome: true,
      );

      expect(decision!.isHomeMode, isTrue);
      expect(decision.protectionPaused, isFalse);
    });

    test('writes nothing when the stored row already agrees', () {
      expect(
        resolveLineMode(
          detectedIso: 'OM',
          lineCountryIso: 'SA',
          isHomeMode: false,
          protectionPaused: false,
          requiresProtectionAtHome: false,
        ),
        isNull,
      );
    });

    test('still corrects protection_paused when only it disagrees', () {
      // is_home_mode is already right, but the pause is stale — e.g. the line
      // was frozen by hand and the shield opt-out turned on afterwards.
      final decision = resolveLineMode(
        detectedIso: 'OM',
        lineCountryIso: 'SA',
        isHomeMode: false,
        protectionPaused: true,
        requiresProtectionAtHome: false,
      );

      expect(decision!.isHomeMode, isFalse);
      expect(decision.protectionPaused, isFalse);
    });

    test('an unresolved location changes nothing', () {
      // detect-country answering "US" for a private IP must not flip a
      // paying line's protection.
      for (final iso in <String?>[null, '', 'XX ', 'UNDEFINED']) {
        expect(
          resolveLineMode(
            detectedIso: iso,
            lineCountryIso: 'SA',
            isHomeMode: true,
            protectionPaused: true,
            requiresProtectionAtHome: false,
          ),
          isNull,
          reason: 'detectedIso "$iso" should be treated as no detection',
        );
      }
    });

    test('a line with no country on file changes nothing', () {
      expect(
        resolveLineMode(
          detectedIso: 'OM',
          lineCountryIso: null,
          isHomeMode: true,
          protectionPaused: true,
          requiresProtectionAtHome: false,
        ),
        isNull,
      );
    });

    test('comparison ignores case and surrounding whitespace', () {
      expect(
        resolveLineMode(
          detectedIso: ' om ',
          lineCountryIso: 'OM',
          isHomeMode: true,
          protectionPaused: true,
          requiresProtectionAtHome: false,
        ),
        isNull,
        reason: 'om == OM, and the row already says home+paused',
      );
    });
    test('user in Oman creating an Egyptian SIM line resolves to Travel Mode', () {
      // User is located in Oman (OM), but creates/has a line in Egypt (EG).
      // Since the line country (EG) != user location (OM), it must resolve to Travel Mode
      // and protection must NOT be paused.
      final decision = resolveLineMode(
        detectedIso: 'OM',
        lineCountryIso: 'EG',
        isHomeMode: true,
        protectionPaused: true,
        requiresProtectionAtHome: false,
      );

      expect(decision, isNotNull);
      expect(decision!.isHomeMode, isFalse);
      expect(decision.protectionPaused, isFalse);
    });
  });
}
