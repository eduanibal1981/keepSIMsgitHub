import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/household_member_model.dart';
import '../../data/repositories/household_repository_impl.dart';

part 'household_controller.g.dart';

class HouseholdState {
  final List<HouseholdMember> members;
  final List<HouseholdMember> invitations;
  final List<HouseholdMember> memberships;

  const HouseholdState({
    required this.members,
    required this.invitations,
    required this.memberships,
  });

  HouseholdState copyWith({
    List<HouseholdMember>? members,
    List<HouseholdMember>? invitations,
    List<HouseholdMember>? memberships,
  }) {
    return HouseholdState(
      members: members ?? this.members,
      invitations: invitations ?? this.invitations,
      memberships: memberships ?? this.memberships,
    );
  }
}

@riverpod
class HouseholdController extends _$HouseholdController {
  @override
  FutureOr<HouseholdState> build() async {
    final repo = ref.watch(householdRepositoryProvider);
    
    final results = await Future.wait([
      repo.getHouseholdMembers(),
      repo.getHouseholdInvitations(),
      repo.getMyMemberships(),
    ]);

    return HouseholdState(
      members: results[0],
      invitations: results[1],
      memberships: results[2],
    );
  }

  Future<void> sendInvite(String email, String role) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(householdRepositoryProvider);
      await repo.inviteMember(email, role);
      
      final results = await Future.wait([
        repo.getHouseholdMembers(),
        repo.getHouseholdInvitations(),
        repo.getMyMemberships(),
      ]);

      return HouseholdState(
        members: results[0],
        invitations: results[1],
        memberships: results[2],
      );
    });
  }

  Future<void> acceptInvite(String inviteId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(householdRepositoryProvider);
      await repo.respondToInvite(inviteId, true);
      
      final results = await Future.wait([
        repo.getHouseholdMembers(),
        repo.getHouseholdInvitations(),
        repo.getMyMemberships(),
      ]);

      return HouseholdState(
        members: results[0],
        invitations: results[1],
        memberships: results[2],
      );
    });
  }

  Future<void> declineInvite(String inviteId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(householdRepositoryProvider);
      await repo.respondToInvite(inviteId, false);
      
      final results = await Future.wait([
        repo.getHouseholdMembers(),
        repo.getHouseholdInvitations(),
        repo.getMyMemberships(),
      ]);

      return HouseholdState(
        members: results[0],
        invitations: results[1],
        memberships: results[2],
      );
    });
  }

  Future<void> removeMember(String memberId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(householdRepositoryProvider);
      await repo.removeMember(memberId);
      
      final results = await Future.wait([
        repo.getHouseholdMembers(),
        repo.getHouseholdInvitations(),
        repo.getMyMemberships(),
      ]);

      return HouseholdState(
        members: results[0],
        invitations: results[1],
        memberships: results[2],
      );
    });
  }

  Future<void> leaveHousehold(String membershipId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(householdRepositoryProvider);
      await repo.leaveHousehold(membershipId);
      
      final results = await Future.wait([
        repo.getHouseholdMembers(),
        repo.getHouseholdInvitations(),
        repo.getMyMemberships(),
      ]);

      return HouseholdState(
        members: results[0],
        invitations: results[1],
        memberships: results[2],
      );
    });
  }
}
