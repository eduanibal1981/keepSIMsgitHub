import 'dart:convert';

/// Represents physical device network interface availability.
enum NetworkInterfaceType {
  none,
  cellular,
  wifi,
  other;

  String get label {
    switch (this) {
      case NetworkInterfaceType.cellular:
        return 'Cellular';
      case NetworkInterfaceType.wifi:
        return 'Wi-Fi';
      case NetworkInterfaceType.none:
        return 'No Interface';
      case NetworkInterfaceType.other:
        return 'Connected';
    }
  }
}

/// Fine-grained reachability status to the authorized KeepSIMs API backend.
enum KeepSimsReachability {
  unknown,
  checking,
  reachable,
  unreachable,
  serviceError;

  bool get isReachable => this == KeepSimsReachability.reachable;
  bool get isChecking => this == KeepSimsReachability.checking;

  String get userMessage {
    switch (this) {
      case KeepSimsReachability.reachable:
        return 'KeepSIMs service is reachable';
      case KeepSimsReachability.checking:
        return 'Checking connection to KeepSIMs...';
      case KeepSimsReachability.unreachable:
        return 'KeepSIMs is currently unreachable';
      case KeepSimsReachability.serviceError:
        return 'KeepSIMs returned a temporary service error';
      case KeepSimsReachability.unknown:
        return 'Connection status unknown';
    }
  }
}

/// Recovery allowance / entitlement status granted by the backend.
enum RecoveryEntitlement {
  none,
  sponsoredAccess,
  generalDataAllowance,
  expired,
  unknown;

  String get label {
    switch (this) {
      case RecoveryEntitlement.sponsoredAccess:
        return 'Zero-Rated KeepSIMs Access';
      case RecoveryEntitlement.generalDataAllowance:
        return 'Emergency General Data Active';
      case RecoveryEntitlement.expired:
        return 'Allowance Expired';
      case RecoveryEntitlement.none:
        return 'No Active Allowance';
      case RecoveryEntitlement.unknown:
        return 'Unknown';
    }
  }
}

/// Local lifecycle state of the backup recovery eSIM profile on this handset.
enum RecoveryProvisioningState {
  notPrepared,
  pendingInstallation,
  installationReported,
  verified,
  failed;

  String get label {
    switch (this) {
      case RecoveryProvisioningState.notPrepared:
        return 'Backup Profile Not Prepared';
      case RecoveryProvisioningState.pendingInstallation:
        return 'Ready to Install';
      case RecoveryProvisioningState.installationReported:
        return 'Installed (Reported)';
      case RecoveryProvisioningState.verified:
        return 'Active & Verified';
      case RecoveryProvisioningState.failed:
        return 'Installation Failed';
    }
  }
}

/// Complete recovery state model preserved in local cache and updated by reachability probes.
class RecoveryStateModel {
  final NetworkInterfaceType interfaceType;
  final KeepSimsReachability reachability;
  final RecoveryEntitlement entitlement;
  final RecoveryProvisioningState provisioningState;
  final String? profileReference;
  final String? esimReference;
  final String? iccid;
  final String? activationCode; // LPA:1$...
  final String? smdpAddress;
  final String? matchingId;
  final int remainingMb;
  final int totalMb;
  final DateTime? expiresAt;
  final DateTime? lastCheckedAt;
  final bool isMock;
  final String? errorMessage;

  const RecoveryStateModel({
    this.interfaceType = NetworkInterfaceType.none,
    this.reachability = KeepSimsReachability.unknown,
    this.entitlement = RecoveryEntitlement.unknown,
    this.provisioningState = RecoveryProvisioningState.notPrepared,
    this.profileReference,
    this.esimReference,
    this.iccid,
    this.activationCode,
    this.smdpAddress,
    this.matchingId,
    this.remainingMb = 0,
    this.totalMb = 0,
    this.expiresAt,
    this.lastCheckedAt,
    this.isMock = true,
    this.errorMessage,
  });

  bool get hasBackupEsim =>
      activationCode != null && activationCode!.isNotEmpty;

  RecoveryStateModel copyWith({
    NetworkInterfaceType? interfaceType,
    KeepSimsReachability? reachability,
    RecoveryEntitlement? entitlement,
    RecoveryProvisioningState? provisioningState,
    String? profileReference,
    String? esimReference,
    String? iccid,
    String? activationCode,
    String? smdpAddress,
    String? matchingId,
    int? remainingMb,
    int? totalMb,
    DateTime? expiresAt,
    DateTime? lastCheckedAt,
    bool? isMock,
    String? errorMessage,
  }) {
    return RecoveryStateModel(
      interfaceType: interfaceType ?? this.interfaceType,
      reachability: reachability ?? this.reachability,
      entitlement: entitlement ?? this.entitlement,
      provisioningState: provisioningState ?? this.provisioningState,
      profileReference: profileReference ?? this.profileReference,
      esimReference: esimReference ?? this.esimReference,
      iccid: iccid ?? this.iccid,
      activationCode: activationCode ?? this.activationCode,
      smdpAddress: smdpAddress ?? this.smdpAddress,
      matchingId: matchingId ?? this.matchingId,
      remainingMb: remainingMb ?? this.remainingMb,
      totalMb: totalMb ?? this.totalMb,
      expiresAt: expiresAt ?? this.expiresAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      isMock: isMock ?? this.isMock,
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'interface_type': interfaceType.name,
      'reachability': reachability.name,
      'entitlement': entitlement.name,
      'provisioning_state': provisioningState.name,
      'profile_reference': profileReference,
      'esim_reference': esimReference,
      'iccid': iccid,
      'activation_code': activationCode,
      'smdp_address': smdpAddress,
      'matching_id': matchingId,
      'remaining_mb': remainingMb,
      'total_mb': totalMb,
      'expires_at': expiresAt?.toIso8601String(),
      'last_checked_at': lastCheckedAt?.toIso8601String(),
      'is_mock': isMock,
      'error_message': errorMessage,
    };
  }

  factory RecoveryStateModel.fromJson(Map<String, dynamic> json) {
    return RecoveryStateModel(
      interfaceType: NetworkInterfaceType.values.firstWhere(
        (e) => e.name == json['interface_type'],
        orElse: () => NetworkInterfaceType.none,
      ),
      reachability: KeepSimsReachability.values.firstWhere(
        (e) => e.name == json['reachability'],
        orElse: () => KeepSimsReachability.unknown,
      ),
      entitlement: RecoveryEntitlement.values.firstWhere(
        (e) => e.name == json['entitlement'],
        orElse: () => RecoveryEntitlement.unknown,
      ),
      provisioningState: RecoveryProvisioningState.values.firstWhere(
        (e) => e.name == json['provisioning_state'],
        orElse: () => RecoveryProvisioningState.notPrepared,
      ),
      profileReference: json['profile_reference'] as String?,
      esimReference: json['esim_reference'] as String?,
      iccid: json['iccid'] as String?,
      activationCode: json['activation_code'] as String?,
      smdpAddress: json['smdp_address'] as String?,
      matchingId: json['matching_id'] as String?,
      remainingMb: (json['remaining_mb'] as num?)?.toInt() ?? 0,
      totalMb: (json['total_mb'] as num?)?.toInt() ?? 0,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      lastCheckedAt: json['last_checked_at'] != null
          ? DateTime.tryParse(json['last_checked_at'] as String)
          : null,
      isMock: json['is_mock'] as bool? ?? true,
      errorMessage: json['error_message'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  static RecoveryStateModel? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return RecoveryStateModel.fromJson(map);
      }
    } catch (_) {}
    return null;
  }
}
