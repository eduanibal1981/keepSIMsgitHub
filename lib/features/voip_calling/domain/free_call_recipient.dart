class ContactLookupResult {
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final String phone;
  final bool isOnline;
  final bool isSelf;

  const ContactLookupResult({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.phone,
    required this.isOnline,
    this.isSelf = false,
  });

  factory ContactLookupResult.fromJson(Map<String, dynamic> json) =>
      ContactLookupResult(
        userId: json['user_id'] as String? ?? '',
        fullName: json['full_name'] as String? ?? 'KeepSIMs User',
        avatarUrl: json['avatar_url'] as String?,
        phone: json['phone'] as String? ?? '',
        isOnline: json['is_online'] as bool? ?? false,
        isSelf: json['is_self'] as bool? ?? false,
      );
}

enum FreeRecipientStatus {
  found,
  notFound,
  self,
  ambiguous,
  unverified,
  unavailable,
}

class FreeRecipientResolution {
  final FreeRecipientStatus status;
  final ContactLookupResult? recipient;
  const FreeRecipientResolution(this.status, [this.recipient]);

  factory FreeRecipientResolution.parse(
    dynamic json, {
    String? phone,
    String? userId,
  }) {
    if (json is! Map || (phone != null && json['phone'] != phone)) {
      throw const FormatException('Invalid recipient response');
    }
    final status = switch (json['status']) {
      'found' => FreeRecipientStatus.found,
      'not_found' => FreeRecipientStatus.notFound,
      'self' => FreeRecipientStatus.self,
      'ambiguous' => FreeRecipientStatus.ambiguous,
      'unverified' => FreeRecipientStatus.unverified,
      'unavailable' => FreeRecipientStatus.unavailable,
      _ => throw const FormatException('Recipient lookup unavailable'),
    };
    if (status != FreeRecipientStatus.found) {
      return FreeRecipientResolution(status);
    }
    if (json['recipient'] is! Map) {
      throw const FormatException('Recipient missing');
    }
    final recipient = ContactLookupResult.fromJson(
      Map<String, dynamic>.from(json['recipient'] as Map),
    );
    if (recipient.userId.isEmpty ||
        recipient.isSelf ||
        (phone != null && recipient.phone != phone) ||
        (userId != null && recipient.userId != userId)) {
      throw const FormatException('Recipient mismatch');
    }
    return FreeRecipientResolution(status, recipient);
  }
}

/// Only server-validated known account IDs bypass phone resolution.
class FreeCallSelection {
  final String rawNumber;
  final String? countryIso;
  final String? knownUserId;
  const FreeCallSelection({
    this.rawNumber = '',
    this.countryIso,
    this.knownUserId,
  });
}
