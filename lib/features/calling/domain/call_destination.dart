import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// A resolved destination is independent of the tariff and outbound caller ID.
class CallDestination {
  final String? e164;
  final String? countryIso;
  final String? displayNumber;
  final bool needsCountry;
  final String? error;

  const CallDestination({
    this.e164,
    this.countryIso,
    this.displayNumber,
    this.needsCountry = false,
    this.error,
  });

  bool get isValid => e164 != null;

  static String normalizeDigits(String raw) => String.fromCharCodes(
    raw.runes.map((r) {
      if (r >= 0x660 && r <= 0x669) return r - 0x660 + 0x30;
      if (r >= 0x6f0 && r <= 0x6f9) return r - 0x6f0 + 0x30;
      return r;
    }),
  );

  static CallDestination resolve(String raw, {String? countryIso}) {
    final input = normalizeDigits(raw).trim();
    if (input.isEmpty) return const CallDestination();
    // Reject service codes, extensions and malformed input instead of silently
    // merging their digits into another destination.
    if (!RegExp(r'^\+?[0-9\s().\-]+$').hasMatch(input)) {
      return const CallDestination(
        error: 'Enter a phone number without extensions or service codes.',
      );
    }
    final clean = input.replaceAll(RegExp(r'[\s().\-]'), '');
    if (clean.startsWith('00')) {
      return const CallDestination(
        error:
            'Use + followed by the country code for an international number.',
      );
    }
    final international = clean.startsWith('+');
    final region = IsoCode.values
        .where((c) => c.name == countryIso?.toUpperCase())
        .firstOrNull;
    if (!international && region == null) {
      return const CallDestination(needsCountry: true);
    }
    try {
      final number = PhoneNumber.parse(
        clean,
        callerCountry: international ? null : region,
        destinationCountry: international ? null : region,
      );
      if (!number.isValid() ||
          (!international && number.isoCode != region) ||
          !RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(number.international)) {
        return const CallDestination(
          error: 'Check the phone number and its country code.',
        );
      }
      return CallDestination(
        e164: number.international,
        countryIso: number.isoCode.name,
        displayNumber:
            '+${number.countryCode} ${number.formatNsn(format: NsnFormat.international)}',
      );
    } catch (_) {
      return const CallDestination(
        error: 'Check the phone number and its country code.',
      );
    }
  }
}
