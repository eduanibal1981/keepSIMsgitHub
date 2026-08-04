import '../../data/models/household_member_model.dart';

/// Outcome of a household mutation.
///
/// H8: every write on `household_members` that a member can perform now goes
/// through a `SECURITY DEFINER` RPC that returns an envelope instead of
/// raising. Refusals therefore arrive as a sentence the UI can show verbatim,
/// and — the reason this type exists at all — a call that legitimately changed
/// nothing is no longer indistinguishable from success.
class HouseholdActionResult {
  const HouseholdActionResult({required this.success, this.code, this.message});

  final bool success;
  final String? code;
  final String? message;

  factory HouseholdActionResult.fromRpc(dynamic res) {
    if (res is! Map) {
      return const HouseholdActionResult(success: false, code: 'MALFORMED');
    }
    final map = Map<String, dynamic>.from(res);
    return HouseholdActionResult(
      success: map['success'] == true,
      code: map['code'] as String?,
      message: map['error'] as String?,
    );
  }

  factory HouseholdActionResult.failure(String message, {String? code}) =>
      HouseholdActionResult(success: false, code: code, message: message);
}

abstract class HouseholdRepository {
  Future<List<HouseholdMember>> getHouseholdMembers();
  Future<List<HouseholdMember>> getHouseholdInvitations();
  Future<List<HouseholdMember>> getMyMemberships();

  Future<HouseholdActionResult> inviteMember(String email, String role);
  Future<HouseholdActionResult> respondToInvite(String inviteId, bool accept);
  Future<HouseholdActionResult> removeMember(String id);
  Future<HouseholdActionResult> leaveHousehold(String id);
}
