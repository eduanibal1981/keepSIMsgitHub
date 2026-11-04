import 'package:keep_sims/features/calling/domain/call_destination.dart';

enum FreeCallIdentifierType { id, phone, email }

/// Complete identifiers only. Local recent filtering never uses this resolver.
class FreeCallIdentifier {
  final FreeCallIdentifierType type;
  final String value;
  const FreeCallIdentifier(this.type, this.value);

  static FreeCallIdentifier? parse(String input) {
    final raw = input.trim();
    final id = raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (RegExp(
      r'^K[A-Z]{2}[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{8}$',
    ).hasMatch(id)) {
      return FreeCallIdentifier(
        FreeCallIdentifierType.id,
        '${id.substring(0, 3)}-${id.substring(3)}',
      );
    }
    if (raw.length <= 254 &&
        RegExp(r'^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$').hasMatch(raw)) {
      // Match Auth's case-insensitive email convention. No provider-specific
      // dot removal, plus-tag stripping or fuzzy matching.
      return FreeCallIdentifier(
        FreeCallIdentifierType.email,
        raw.toLowerCase(),
      );
    }
    if (CallDestination.normalizeDigits(raw).startsWith('+')) {
      final phone = CallDestination.resolve(raw).e164;
      if (phone != null) {
        return FreeCallIdentifier(FreeCallIdentifierType.phone, phone);
      }
    }
    return null;
  }
}

class FreeCallIdentity {
  final String publicId;
  final bool discoverById;
  final bool discoverByEmail;
  final bool emailVerified;
  final List<FreeCallPhoneConsent> phones;
  final List<FreeCallBlockedAccount> blocked;
  const FreeCallIdentity({
    required this.publicId,
    this.discoverById = true,
    this.discoverByEmail = false,
    this.emailVerified = false,
    this.phones = const [],
    this.blocked = const [],
  });

  factory FreeCallIdentity.fromJson(Map<String, dynamic> json) {
    final id = json['public_id'] as String? ?? '';
    if (FreeCallIdentifier.parse(id)?.type != FreeCallIdentifierType.id) {
      throw const FormatException('Calling identity unavailable');
    }
    return FreeCallIdentity(
      publicId: id,
      discoverById: json['discover_by_id'] == true,
      discoverByEmail: json['discover_by_email'] == true,
      emailVerified: json['email_verified'] == true,
      phones: [
        for (final p in json['phones'] as List? ?? [])
          FreeCallPhoneConsent(p['phone'] as String, p['enabled'] == true),
      ],
      blocked: [
        for (final b in json['blocked'] as List? ?? [])
          FreeCallBlockedAccount(
            b['user_id'] as String,
            b['full_name'] as String,
          ),
      ],
    );
  }
}

class FreeCallPhoneConsent {
  final String phone;
  final bool enabled;
  const FreeCallPhoneConsent(this.phone, this.enabled);
}

class FreeCallBlockedAccount {
  final String userId;
  final String name;
  const FreeCallBlockedAccount(this.userId, this.name);
}
