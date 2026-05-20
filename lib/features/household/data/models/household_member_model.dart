import 'package:freezed_annotation/freezed_annotation.dart';

part 'household_member_model.freezed.dart';
part 'household_member_model.g.dart';

@freezed
abstract class HouseholdMember with _$HouseholdMember {
  const factory HouseholdMember({
    required String id,
    @JsonKey(name: 'owner_id') required String ownerId,
    @JsonKey(name: 'member_email') required String memberEmail,
    @JsonKey(name: 'member_id') String? memberId,
    required String role,
    @JsonKey(name: 'invite_status') required String inviteStatus,
    @JsonKey(name: 'invited_at') required DateTime invitedAt,
    @JsonKey(name: 'accepted_at') DateTime? acceptedAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    
    // UI Helpers populated via joins
    @JsonKey(name: 'owner_name') String? ownerName,
    @JsonKey(name: 'member_name') String? memberName,
    @JsonKey(name: 'member_avatar') String? memberAvatar,
  }) = _HouseholdMember;

  factory HouseholdMember.fromJson(Map<String, dynamic> json) =>
      _$HouseholdMemberFromJson(json);
}
