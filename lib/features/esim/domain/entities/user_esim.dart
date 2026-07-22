import 'package:freezed_annotation/freezed_annotation.dart';

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
    required DateTime purchasedAt,
    DateTime? firstActivatedAt,
    DateTime? expiresAt,
    DateTime? lastSyncedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserEsim;

  factory UserEsim.fromJson(Map<String, dynamic> json) =>
      _$UserEsimFromJson(json);

  String get lpaString => lpaActivationCode;

  String get smdpAddress {
    if (lpaActivationCode.contains('\$')) {
      final parts = lpaActivationCode.split('\$');
      if (parts.length >= 2) return parts[1];
    }
    return 'rsp.esim-go.com';
  }

  String get matchingId {
    if (lpaActivationCode.contains('\$')) {
      final parts = lpaActivationCode.split('\$');
      if (parts.length >= 3) return parts[2];
    }
    return iccid;
  }
}
