import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/household_member_model.dart';
import '../../domain/repositories/household_repository.dart';

part 'household_repository_impl.g.dart';

@riverpod
HouseholdRepository householdRepository(Ref ref) {
  return HouseholdRepositoryImpl(supabase: Supabase.instance.client);
}

/// H8 note on why the writes here are RPCs and not table calls.
///
/// `household_members` grants `authenticated` column-level UPDATE on every
/// column, and the old member policy scoped rows but not columns — so a member
/// owned their own row and could set `role='manager'`, which is the gate on
/// spending the OWNER's wallet. The member-side write policies are gone now;
/// accept/decline/leave have no direct path to the table by design. Invites go
/// through an RPC too, because the duplicate check was a client-side race and
/// because the invitee needs a notification row they alone can read.
class HouseholdRepositoryImpl implements HouseholdRepository {
  final SupabaseClient _supabase;

  HouseholdRepositoryImpl({required SupabaseClient supabase})
    : _supabase = supabase;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  @override
  Future<List<HouseholdMember>> getHouseholdMembers() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('household_members')
          .select('*, profiles:member_id(full_name, avatar_url)')
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final profile = json['profiles'] as Map<String, dynamic>?;
        return HouseholdMember.fromJson({
          ...json,
          'member_name': profile?['full_name'],
          'member_avatar': profile?['avatar_url'],
        });
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch household members: ${e.message}');
    }
  }

  /// Invitations addressed to me.
  ///
  /// Deliberately NOT filtered on `member_email` any more. The row is visible
  /// when it matches `member_id` OR the JWT email, and an invite sent before
  /// the invitee registered only ever matches on email — filtering client-side
  /// on a locally-held email string is how that case got lost before. RLS is
  /// the filter; the only thing to exclude here is my own outgoing invites,
  /// which the owner policy also makes visible to me.
  @override
  Future<List<HouseholdMember>> getHouseholdInvitations() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('household_members')
          .select('*, profiles:owner_id(full_name)')
          .eq('invite_status', 'pending')
          .neq('owner_id', userId)
          .order('invited_at', ascending: false);

      return (response as List).map((json) {
        final ownerProfile = json['profiles'] as Map<String, dynamic>?;
        return HouseholdMember.fromJson({
          ...json,
          'owner_name': ownerProfile?['full_name'],
        });
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch household invitations: ${e.message}');
    }
  }

  @override
  Future<List<HouseholdMember>> getMyMemberships() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('household_members')
          .select('*, profiles:owner_id(full_name)')
          .eq('member_id', userId)
          .eq('invite_status', 'accepted')
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final ownerProfile = json['profiles'] as Map<String, dynamic>?;
        return HouseholdMember.fromJson({
          ...json,
          'owner_name': ownerProfile?['full_name'],
        });
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch household memberships: ${e.message}');
    }
  }

  @override
  Future<HouseholdActionResult> inviteMember(String email, String role) =>
      _rpc('invite_household_member', {
        'p_email': email.trim(),
        'p_role': role,
      });

  @override
  Future<HouseholdActionResult> respondToInvite(String inviteId, bool accept) =>
      _rpc('respond_to_household_invite', {
        'p_invite_id': inviteId,
        'p_accept': accept,
      });

  @override
  Future<HouseholdActionResult> leaveHousehold(String id) =>
      _rpc('leave_household', {'p_membership_id': id});

  /// Owner-side removal. Still a direct DELETE — the owner policy is correctly
  /// scoped — but `.select()` is what turns "RLS matched nothing" into a
  /// reportable failure instead of a success toast over an unchanged table.
  @override
  Future<HouseholdActionResult> removeMember(String id) async {
    try {
      final rows = await _supabase
          .from('household_members')
          .delete()
          .eq('id', id)
          .select('id');

      if ((rows as List).isEmpty) {
        return HouseholdActionResult.failure(
          'That member is no longer in your household.',
          code: 'NOT_FOUND',
        );
      }
      return const HouseholdActionResult(success: true);
    } on PostgrestException catch (e) {
      return HouseholdActionResult.failure(e.message, code: 'DB_ERROR');
    }
  }

  Future<HouseholdActionResult> _rpc(
    String fn,
    Map<String, dynamic> params,
  ) async {
    try {
      final res = await _supabase.rpc(fn, params: params);
      return HouseholdActionResult.fromRpc(res);
    } on PostgrestException catch (e) {
      return HouseholdActionResult.failure(e.message, code: 'DB_ERROR');
    }
  }
}
