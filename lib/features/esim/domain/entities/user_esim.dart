import 'package:freezed_annotation/freezed_annotation.dart';
import 'esim_catalogue_details.dart';
import 'esim_activation_payload.dart';
part 'user_esim.freezed.dart';
part 'user_esim.g.dart';

@freezed
abstract class UserEsim with _$UserEsim {
  const UserEsim._();
  const factory UserEsim({
    required String id,
    required String userId,
    required String esimOrderId,
    required String iccid,
    required String lpaActivationCode,
    required String qrCodeUrl,
    required String bundleName,
    required String provider,
    required String status,
    required int dataRemainingMb,
    required int dataTotalMb,
    DateTime? purchasedAt,
    DateTime? firstActivatedAt,
    DateTime? expiresAt,
    DateTime? lastSyncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default(false) bool issuanceVerified,
    @Default('unknown') String profileState,
    @Default('unknown') String installationState,
    @Default('unknown') String bundleState,
    @Default('unknown') String activationTrigger,
    int? dataTotalBytes,
    int? dataUsedBytes,
    int? dataRemainingBytes,
    DateTime? usageObservedAt,
    DateTime? lastObservationAt,
    DateTime? lastUsageAttemptAt,
    DateTime? activationDeadlineAt,
    String? usageErrorCode,
    Map<String, dynamic>? catalogueDetails,
  }) = _UserEsim;
  factory UserEsim.fromJson(Map<String, dynamic> json) =>
      _$UserEsimFromJson(json);

  /// One deliberate mapper for the deployed projection and captured legacy names.
  factory UserEsim.fromRecord(Map<String, dynamic> map) {
    String value(String key) => map[key]?.toString() ?? '';
    DateTime? date(String key) => DateTime.tryParse(value(key));
    int? number(String key) =>
        map[key] is num ? (map[key] as num).toInt() : int.tryParse(value(key));
    return UserEsim(
      id: value('id'),
      userId: value('user_id'),
      esimOrderId: (map['order_id'] ?? map['esim_order_id'])?.toString() ?? '',
      iccid: value('iccid'),
      lpaActivationCode:
          (map['lpa_string'] ?? map['lpa_activation_code'])?.toString() ?? '',
      qrCodeUrl: value('qr_code_url'),
      bundleName: value('bundle_name'),
      provider: value('provider'),
      status: value('status'),
      dataRemainingMb: number('data_remaining_mb') ?? 0,
      dataTotalMb: number('data_total_mb') ?? 0,
      purchasedAt: date('purchased_at'),
      firstActivatedAt: date('first_activated_at'),
      expiresAt: date('expires_at'),
      lastSyncedAt: date('last_usage_check') ?? date('last_synced_at'),
      createdAt: date('created_at'),
      updatedAt: date('updated_at'),
      issuanceVerified: map['issuance_verified'] == true,
      profileState: map['profile_state'] as String? ?? 'unknown',
      installationState: map['installation_state'] as String? ?? 'unknown',
      bundleState: map['bundle_state'] as String? ?? 'unknown',
      activationTrigger: map['activation_trigger'] as String? ?? 'unknown',
      dataTotalBytes: number('data_total_bytes'),
      dataUsedBytes: number('data_used_bytes'),
      dataRemainingBytes: number('data_remaining_bytes'),
      usageObservedAt: date('usage_observed_at'),
      lastObservationAt: date('last_observation_at'),
      lastUsageAttemptAt: date('last_usage_attempt_at'),
      activationDeadlineAt: date('activation_deadline_at'),
      usageErrorCode: map['usage_error_code'] as String?,
      catalogueDetails: map['catalogue_details'] is Map
          ? Map<String, dynamic>.from(map['catalogue_details'] as Map)
          : null,
    );
  }
  @override
  String toString() => 'UserEsim(id: $id, state: $profileState)';
  String get lpaString => lpaActivationCode;
  EsimActivationPayload? get activationPayload =>
      issuanceVerified ? EsimActivationPayload.tryParse(lpaString) : null;
  String get smdpAddress => activationPayload?.smdpAddress ?? '';
  String get matchingId => activationPayload?.matchingId ?? '';
  bool get hasActivationPayload => activationPayload != null;
  bool get hasKnownUsage =>
      dataRemainingBytes != null && dataTotalBytes != null;
  bool get isTerminal =>
      ['expired', 'cancelled', 'revoked'].contains(profileState);
  bool get usageIsStale =>
      usageErrorCode != null ||
      lastSyncedAt == null ||
      DateTime.now().toUtc().difference(lastSyncedAt!.toUtc()) >
          const Duration(hours: 4) ||
      (usageObservedAt != null &&
          DateTime.now().toUtc().difference(usageObservedAt!.toUtc()) >
              const Duration(hours: 6));
  String get statusLabel => switch (profileState) {
    'issued' => installationState == 'released' ? 'Ready to install' : 'Issued',
    'active' => 'Active',
    'suspended' => 'Suspended',
    'expired' => 'Expired',
    'cancelled' => 'Cancelled',
    'revoked' => 'Revoked',
    _ => 'Not verified',
  };
  String get installationLabel => switch (installationState) {
    'released' => 'Not installed',
    'downloaded' => 'Downloaded',
    'installed' || 'enabled' => 'Installed',
    'disabled' => 'Disabled on device',
    'deleted' => 'Deleted from device',
    _ => 'Not provided',
  };
  EsimCatalogueDetails get facts => EsimCatalogueDetails({
    ...?catalogueDetails,
    'activation_trigger': activationTrigger,
  });
  String get usageLabel => hasKnownUsage
      ? '${EsimCatalogueDetails.formatBytes(dataRemainingBytes!)} / ${EsimCatalogueDetails.formatBytes(dataTotalBytes!)}'
      : 'Usage not provided';
}
