/// SIM Shield — Household spend limits (G6)
///
/// Two views of the same arrangement, because the two sides can see different
/// things and RLS is right to keep it that way:
///
///   * [HouseholdSpendRow] — `household_spend_summary()`, what the OWNER sees:
///     every member, their cap, and what they have spent of the owner's wallet
///     this month.
///   * [HouseholdAllowance] — `my_household_allowances()`, what the MEMBER
///     sees: which households have funded them and how much is left. A member
///     cannot read the owner's wallet or ledger, so without this they would
///     discover their cap by hitting it.
///
/// `monthlyCapUsd == 0` is not "no limit", it is **may not spend**. That is the
/// default on every membership row and the only fail-closed reading — an owner
/// who has never set a cap has not opted into sharing their wallet.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'household_spend_model.freezed.dart';
part 'household_spend_model.g.dart';

@freezed
abstract class HouseholdSpendRow with _$HouseholdSpendRow {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory HouseholdSpendRow({
    required String memberRowId,
    String? memberId,
    required String memberEmail,
    String? memberName,
    required String role,
    required String inviteStatus,
    @Default(0.0) double monthlyCapUsd,
    double? perTxnCapUsd,

    /// Already debited from the owner's wallet this month.
    @Default(0.0) double committedUsd,

    /// Queued but not yet debited. Counts against the cap on purpose — see the
    /// migration header; without it a member could stack refills past the cap.
    @Default(0.0) double inFlightUsd,
    @Default(0.0) double spentMtdUsd,
    @Default(0.0) double remainingUsd,
    DateTime? lastSpendAt,
  }) = _HouseholdSpendRow;

  const HouseholdSpendRow._();

  factory HouseholdSpendRow.fromJson(Map<String, dynamic> json) =>
      _$HouseholdSpendRowFromJson(json);

  /// Whether this member may spend the owner's wallet at all.
  bool get isFunded => monthlyCapUsd > 0;

  /// A cap can only be attached to a manager — a viewer cannot act on the
  /// owner's lines, so funding one would be a number nobody can spend. The
  /// server enforces this with a trigger; the UI says it before they try.
  bool get canBeFunded => role == 'manager' && inviteStatus == 'accepted';

  /// 0.0–1.0 for the progress bar. Guards the zero-cap case rather than
  /// dividing by it.
  double get usedFraction {
    if (monthlyCapUsd <= 0) return 0.0;
    return (spentMtdUsd / monthlyCapUsd).clamp(0.0, 1.0);
  }

  bool get isExhausted => isFunded && remainingUsd <= 0;

  String get displayName =>
      (memberName != null && memberName!.isNotEmpty) ? memberName! : memberEmail;
}

@freezed
abstract class HouseholdAllowance with _$HouseholdAllowance {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory HouseholdAllowance({
    required String ownerId,
    String? ownerName,
    String? ownerEmail,
    required String role,
    @Default(0.0) double monthlyCapUsd,
    double? perTxnCapUsd,
    @Default(0.0) double spentMtdUsd,
    @Default(0.0) double remainingUsd,
  }) = _HouseholdAllowance;

  const HouseholdAllowance._();

  factory HouseholdAllowance.fromJson(Map<String, dynamic> json) =>
      _$HouseholdAllowanceFromJson(json);

  bool get isFunded => monthlyCapUsd > 0;

  double get usedFraction {
    if (monthlyCapUsd <= 0) return 0.0;
    return (spentMtdUsd / monthlyCapUsd).clamp(0.0, 1.0);
  }

  String get ownerLabel {
    if (ownerName != null && ownerName!.isNotEmpty) return ownerName!;
    return ownerEmail ?? 'Household owner';
  }
}
