import '../../data/models/household_member_model.dart';

abstract class HouseholdRepository {
  Future<List<HouseholdMember>> getHouseholdMembers();
  Future<List<HouseholdMember>> getHouseholdInvitations();
  Future<List<HouseholdMember>> getMyMemberships();
  Future<HouseholdMember> inviteMember(String email, String role);
  Future<void> respondToInvite(String inviteId, bool accept);
  Future<void> removeMember(String id);
  Future<void> leaveHousehold(String id);
}
