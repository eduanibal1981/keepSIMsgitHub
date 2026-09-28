/// National Phone Number Validator & Carrier Network Resolver.
///
/// Provides instant client-side format validation and carrier network detection
/// according to national telecommunications numbering plans.
library;

class CarrierLookupResult {
  final bool isValidFormat;
  final String? detectedCarrierName;
  final String carrierStatus; // 'active', 'inactive', 'unsupported'
  final String message;

  const CarrierLookupResult({
    required this.isValidFormat,
    this.detectedCarrierName,
    required this.carrierStatus,
    required this.message,
  });

  bool get isRecognized => isValidFormat && detectedCarrierName != null;
}

class PhoneNumberValidator {
  const PhoneNumberValidator._();

  /// Resolve international dialing code for a known country ISO code.
  static String? getDialingCodeForIso(String? countryIsoCode) {
    final iso = countryIsoCode?.toUpperCase();
    switch (iso) {
      case 'OM': return '968';
      case 'SA': return '966';
      case 'AE': return '971';
      case 'EG': return '20';
      case 'KW': return '965';
      case 'BH': return '973';
      case 'QA': return '974';
      case 'JO': return '962';
      case 'GB': return '44';
      case 'US':
      case 'CA': return '1';
      default: return null;
    }
  }

  /// Expected national significant number (NSN) digit length for a given country.
  static int? getExpectedLength({String? countryIsoCode, String? dialingCode}) {
    final iso = countryIsoCode?.toUpperCase();
    final code = dialingCode?.replaceAll(RegExp(r'[^\d]'), '') ?? getDialingCodeForIso(iso);

    if (iso == 'OM' || code == '968') return 8; // Oman
    if (iso == 'SA' || code == '966') return 9; // Saudi Arabia
    if (iso == 'AE' || code == '971') return 9; // UAE
    if (iso == 'EG' || code == '20') return 10; // Egypt
    if (iso == 'KW' || code == '965') return 8; // Kuwait
    if (iso == 'BH' || code == '973') return 8; // Bahrain
    if (iso == 'QA' || code == '974') return 8; // Qatar
    if (iso == 'JO' || code == '962') return 9; // Jordan
    if (iso == 'GB' || code == '44') return 10; // UK
    if (iso == 'US' || iso == 'CA' || code == '1') return 10; // US / Canada
    return null;
  }

  /// Clean digits from raw phone number.
  static String extractCleanDigits(String raw) {
    return raw.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Validates format and identifies the mobile carrier network based on prefix.
  static CarrierLookupResult validateAndDetect({
    required String phoneNumber,
    String? countryIsoCode,
    String? dialingCode,
  }) {
    final iso = countryIsoCode?.toUpperCase();
    final dCode = (dialingCode?.replaceAll(RegExp(r'[^\d]'), '')) ?? getDialingCodeForIso(iso);
    var digits = extractCleanDigits(phoneNumber);

    // Strip dialing code if prefixed
    if (dCode != null && dCode.isNotEmpty && digits.startsWith(dCode)) {
      digits = digits.substring(dCode.length);
    } else if (digits.startsWith('968') && (digits.length == 11 || iso == 'OM')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('966') && (digits.length == 12 || iso == 'SA')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('971') && (digits.length == 12 || iso == 'AE')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('20') && (digits.length == 12 || iso == 'EG')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('965') && (digits.length == 11 || iso == 'KW')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('973') && (digits.length == 11 || iso == 'BH')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('974') && (digits.length == 11 || iso == 'QA')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('962') && (digits.length == 12 || iso == 'JO')) {
      digits = digits.substring(3);
    }

    // Strip leading trunk zero
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.isEmpty) {
      return const CarrierLookupResult(
        isValidFormat: false,
        carrierStatus: 'inactive',
        message: 'Please enter a phone number.',
      );
    }

    // 1. Oman (OM / +968)
    if (iso == 'OM' || dCode == '968') {
      if (digits.length != 8) {
        return CarrierLookupResult(
          isValidFormat: false,
          carrierStatus: 'inactive',
          message: 'Oman phone numbers must be exactly 8 digits (entered ${digits.length}).',
        );
      }

      // Friendi Mobile Oman: 79xxxxxx, 98xxxxxx
      if (digits.startsWith('79') || digits.startsWith('98')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'FRiENDi Mobile Oman',
          carrierStatus: 'active',
          message: 'FRiENDi mobile detected (Valid line format)',
        );
      }

      // Omantel: 90xxxxxx, 91xxxxxx, 92xxxxxx, 93xxxxxx, 99xxxxxx
      if (RegExp(r'^9[0-39]').hasMatch(digits)) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Omantel',
          carrierStatus: 'active',
          message: 'Omantel detected (Valid line format)',
        );
      }

      // Ooredoo Oman: 94xxxxxx, 95xxxxxx, 96xxxxxx, 97xxxxxx, 72xxxxxx
      if (RegExp(r'^(9[4-7]|72)').hasMatch(digits)) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Ooredoo Oman',
          carrierStatus: 'active',
          message: 'Ooredoo detected (Valid line format)',
        );
      }

      // Vodafone Oman: 71xxxxxx, 77xxxxxx
      if (digits.startsWith('71') || digits.startsWith('77')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Vodafone Oman',
          carrierStatus: 'active',
          message: 'Vodafone detected (Valid line format)',
        );
      }

      // Red Bull Mobile Oman: 78xxxxxx
      if (digits.startsWith('78')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Red Bull Mobile Oman',
          carrierStatus: 'active',
          message: 'Red Bull Mobile detected (Valid line format)',
        );
      }

      // Renna Mobile: 76xxxxxx
      if (digits.startsWith('76')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Renna Mobile',
          carrierStatus: 'active',
          message: 'Renna Mobile detected (Valid line format)',
        );
      }

      // Other 8-digit mobile range in Oman starting with 7 or 9
      if (digits.startsWith('7') || digits.startsWith('9')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: null,
          carrierStatus: 'active',
          message: 'Valid Oman line format',
        );
      }

      return const CarrierLookupResult(
        isValidFormat: false,
        carrierStatus: 'inactive',
        message: 'Invalid Oman mobile prefix (must start with 7 or 9).',
      );
    }

    // 2. Saudi Arabia (SA / +966)
    if (iso == 'SA' || dCode == '966') {
      if (digits.length != 9) {
        return CarrierLookupResult(
          isValidFormat: false,
          carrierStatus: 'inactive',
          message: 'Saudi phone numbers must be 9 digits starting with 5 (entered ${digits.length}).',
        );
      }
      if (!digits.startsWith('5')) {
        return const CarrierLookupResult(
          isValidFormat: false,
          carrierStatus: 'inactive',
          message: 'Saudi mobile numbers must begin with 5.',
        );
      }

      if (RegExp(r'^5[035]').hasMatch(digits)) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'stc',
          carrierStatus: 'active',
          message: 'stc detected (Valid line format)',
        );
      }
      if (RegExp(r'^5[46]').hasMatch(digits)) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Mobily',
          carrierStatus: 'active',
          message: 'Mobily detected (Valid line format)',
        );
      }
      if (RegExp(r'^5[89]').hasMatch(digits)) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Zain KSA',
          carrierStatus: 'active',
          message: 'Zain KSA detected (Valid line format)',
        );
      }
      if (RegExp(r'^57[012]').hasMatch(digits)) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Virgin Mobile KSA',
          carrierStatus: 'active',
          message: 'Virgin Mobile detected (Valid line format)',
        );
      }
      if (RegExp(r'^57[678]').hasMatch(digits)) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Lebara KSA',
          carrierStatus: 'active',
          message: 'Lebara KSA detected (Valid line format)',
        );
      }
      if (digits.startsWith('573')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Friendi KSA',
          carrierStatus: 'active',
          message: 'Friendi KSA detected (Valid line format)',
        );
      }
      if (digits.startsWith('574')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Salam Mobile KSA',
          carrierStatus: 'active',
          message: 'Salam Mobile detected (Valid line format)',
        );
      }
      if (digits.startsWith('575')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Red Bull Mobile KSA',
          carrierStatus: 'active',
          message: 'Red Bull Mobile detected (Valid line format)',
        );
      }

      return const CarrierLookupResult(
        isValidFormat: true,
        detectedCarrierName: null,
        carrierStatus: 'active',
        message: 'Valid Saudi line format',
      );
    }

    // 3. United Arab Emirates (AE / +971)
    if (iso == 'AE' || dCode == '971') {
      if (digits.length != 9) {
        return CarrierLookupResult(
          isValidFormat: false,
          carrierStatus: 'inactive',
          message: 'UAE mobile numbers must be 9 digits starting with 5 (entered ${digits.length}).',
        );
      }
      if (!digits.startsWith('5')) {
        return const CarrierLookupResult(
          isValidFormat: false,
          carrierStatus: 'inactive',
          message: 'UAE mobile numbers must begin with 5.',
        );
      }

      if (RegExp(r'^5[046]').hasMatch(digits)) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Etisalat (e&)',
          carrierStatus: 'active',
          message: 'Etisalat (e&) detected (Valid line format)',
        );
      }
      if (RegExp(r'^5[258]').hasMatch(digits)) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'du',
          carrierStatus: 'active',
          message: 'du detected (Valid line format)',
        );
      }
      if (digits.startsWith('53')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Virgin Mobile UAE',
          carrierStatus: 'active',
          message: 'Virgin Mobile detected (Valid line format)',
        );
      }

      return const CarrierLookupResult(
        isValidFormat: true,
        detectedCarrierName: null,
        carrierStatus: 'active',
        message: 'Valid UAE line format',
      );
    }

    // 4. Egypt (EG / +20)
    if (iso == 'EG' || dCode == '20') {
      if (digits.length != 10) {
        return CarrierLookupResult(
          isValidFormat: false,
          carrierStatus: 'inactive',
          message: 'Egypt mobile numbers must be 10 digits starting with 1 (entered ${digits.length}).',
        );
      }
      if (!digits.startsWith('1')) {
        return const CarrierLookupResult(
          isValidFormat: false,
          carrierStatus: 'inactive',
          message: 'Egypt mobile numbers must begin with 1.',
        );
      }

      if (digits.startsWith('10')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Vodafone Egypt',
          carrierStatus: 'active',
          message: 'Vodafone Egypt detected (Valid line format)',
        );
      }
      if (digits.startsWith('11')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Etisalat Misr',
          carrierStatus: 'active',
          message: 'Etisalat Misr detected (Valid line format)',
        );
      }
      if (digits.startsWith('12')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Orange Egypt',
          carrierStatus: 'active',
          message: 'Orange Egypt detected (Valid line format)',
        );
      }
      if (digits.startsWith('15')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Telecom Egypt (WE)',
          carrierStatus: 'active',
          message: 'WE Egypt detected (Valid line format)',
        );
      }

      return const CarrierLookupResult(
        isValidFormat: true,
        detectedCarrierName: null,
        carrierStatus: 'active',
        message: 'Valid Egypt line format',
      );
    }

    // 5. Kuwait (KW / +965)
    if (iso == 'KW' || dCode == '965') {
      if (digits.length != 8) {
        return CarrierLookupResult(
          isValidFormat: false,
          carrierStatus: 'inactive',
          message: 'Kuwait phone numbers must be 8 digits (entered ${digits.length}).',
        );
      }
      if (digits.startsWith('9')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Zain Kuwait',
          carrierStatus: 'active',
          message: 'Zain Kuwait detected (Valid line format)',
        );
      }
      if (digits.startsWith('6')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Ooredoo Kuwait',
          carrierStatus: 'active',
          message: 'Ooredoo Kuwait detected (Valid line format)',
        );
      }
      if (digits.startsWith('5')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'stc Kuwait',
          carrierStatus: 'active',
          message: 'stc Kuwait detected (Valid line format)',
        );
      }
      return const CarrierLookupResult(
        isValidFormat: true,
        detectedCarrierName: null,
        carrierStatus: 'active',
        message: 'Valid Kuwait line format',
      );
    }

    // 6. Bahrain (BH / +973)
    if (iso == 'BH' || dCode == '973') {
      if (digits.length != 8) {
        return CarrierLookupResult(
          isValidFormat: false,
          carrierStatus: 'inactive',
          message: 'Bahrain phone numbers must be 8 digits (entered ${digits.length}).',
        );
      }
      if (digits.startsWith('33') || digits.startsWith('34')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'stc Bahrain',
          carrierStatus: 'active',
          message: 'stc Bahrain detected (Valid line format)',
        );
      }
      if (digits.startsWith('38') || digits.startsWith('39')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Batelco',
          carrierStatus: 'active',
          message: 'Batelco detected (Valid line format)',
        );
      }
      if (digits.startsWith('36') || digits.startsWith('37')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Zain Bahrain',
          carrierStatus: 'active',
          message: 'Zain Bahrain detected (Valid line format)',
        );
      }
      return const CarrierLookupResult(
        isValidFormat: true,
        detectedCarrierName: null,
        carrierStatus: 'active',
        message: 'Valid Bahrain line format',
      );
    }

    // 7. Qatar (QA / +974)
    if (iso == 'QA' || dCode == '974') {
      if (digits.length != 8) {
        return CarrierLookupResult(
          isValidFormat: false,
          carrierStatus: 'inactive',
          message: 'Qatar phone numbers must be 8 digits (entered ${digits.length}).',
        );
      }
      if (digits.startsWith('3') || digits.startsWith('7')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Vodafone Qatar',
          carrierStatus: 'active',
          message: 'Vodafone Qatar detected (Valid line format)',
        );
      }
      if (digits.startsWith('5') || digits.startsWith('6')) {
        return const CarrierLookupResult(
          isValidFormat: true,
          detectedCarrierName: 'Ooredoo Qatar',
          carrierStatus: 'active',
          message: 'Ooredoo Qatar detected (Valid line format)',
        );
      }
      return const CarrierLookupResult(
        isValidFormat: true,
        detectedCarrierName: null,
        carrierStatus: 'active',
        message: 'Valid Qatar line format',
      );
    }

    // Generic fallback for any other country
    if (digits.length >= 6 && digits.length <= 15) {
      return const CarrierLookupResult(
        isValidFormat: true,
        detectedCarrierName: null,
        carrierStatus: 'active',
        message: 'Valid phone number format',
      );
    }

    return CarrierLookupResult(
      isValidFormat: false,
      carrierStatus: 'inactive',
      message: 'Invalid phone number length (${digits.length} digits).',
    );
  }
}
