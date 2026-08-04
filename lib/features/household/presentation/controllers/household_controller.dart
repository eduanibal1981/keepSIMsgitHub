import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/household_member_model.dart';
import '../../data/repositories/household_repository_impl.dart';
import '../../domain/repositories/household_repository.dart';

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
  FutureOr<HouseholdState> build() => _load();

  Future<HouseholdState> _load() async {
    final repo = ref.read(householdRepositoryProvider);
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

  /// Re-read without dropping to [AsyncLoading].
  ///
  /// The old code set `AsyncLoading()` before every mutation, which replaced
  /// the whole screen with a shimmer for the round trip — accepting one invite
  /// made the member list, the tab bar content and the allowance banner all
  /// blink. Riverpod keeps the previous value on an in-place refresh, so the
  /// list stays on screen and only the row that changed moves.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  Future<HouseholdActionResult> _mutate(
    Future<HouseholdActionResult> Function(HouseholdRepository repo) action,
  ) async {
    final result = await action(ref.read(householdRepositoryProvider));
    if (result.success) await refresh();
    return result;
  }

  Future<HouseholdActionResult> sendInvite(String email, String role) =>
      _mutate((repo) => repo.inviteMember(email, role));

  Future<HouseholdActionResult> acceptInvite(String inviteId) =>
      _mutate((repo) => repo.respondToInvite(inviteId, true));

  Future<HouseholdActionResult> declineInvite(String inviteId) =>
      _mutate((repo) => repo.respondToInvite(inviteId, false));

  Future<HouseholdActionResult> removeMember(String memberId) =>
      _mutate((repo) => repo.removeMember(memberId));

  Future<HouseholdActionResult> leaveHousehold(String membershipId) =>
      _mutate((repo) => repo.leaveHousehold(membershipId));
}
