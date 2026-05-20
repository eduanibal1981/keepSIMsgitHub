import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/household_member_model.dart';
import '../../domain/repositories/household_repository.dart';

part 'household_repository_impl.g.dart';

@riverpod
HouseholdRepository householdRepository(HouseholdRepositoryRef ref) {
  return HouseholdRepositoryImpl(supabase: Supabase.instance.client);
}

class HouseholdRepositoryImpl implements HouseholdRepository {
  final SupabaseClient _supabase;

  HouseholdRepositoryImpl({required SupabaseClient supabase}) : _supabase = supabase;

  String? get _currentUserId => _supabase.auth.currentUser?.id;
  String? get _currentUserEmail => _supabase.auth.currentUser?.email;

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

      final data = response as List;
      return data.map((json) {
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

  @override
  Future<List<HouseholdMember>> getHouseholdInvitations() async {
    final email = _currentUserEmail;
    if (email == null) return [];

    try {
      final response = await _supabase
          .from('household_members')
          .select('*, profiles:owner_id(full_name)')
          .eq('member_email', email.toLowerCase())
          .eq('invite_status', 'pending')
          .order('invited_at', ascending: false);

      final data = response as List;
      return data.map((json) {
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

      final data = response as List;
      return data.map((json) {
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
  Future<HouseholdMember> inviteMember(String email, String role) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    if (email.toLowerCase().trim() == _currentUserEmail?.toLowerCase().trim()) {
      throw Exception('You cannot invite yourself to your own household');
    }

    try {
      // Check if already invited or member
      final checkResponse = await _supabase
          .from('household_members')
          .select()
          .eq('owner_id', userId)
          .eq('member_email', email.toLowerCase().trim());
      
      if ((checkResponse as List).isNotEmpty) {
        throw Exception('An invitation or membership already exists for this email');
      }

      final insertResponse = await _supabase
          .from('household_members')
          .insert({
            'owner_id': userId,
            'member_email': email.toLowerCase().trim(),
            'role': role,
            'invite_status': 'pending',
            'invited_at': DateTime.now().toIso8601String(),
          })
          .select('*, profiles:member_id(full_name, avatar_url)')
          .single();

      final profile = insertResponse['profiles'] as Map<String, dynamic>?;
      return HouseholdMember.fromJson({
        ...insertResponse,
        'member_name': profile?['full_name'],
        'member_avatar': profile?['avatar_url'],
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to invite member: ${e.message}');
    }
  }

  @override
  Future<void> respondToInvite(String inviteId, bool accept) async {
    try {
      await _supabase
          .from('household_members')
          .update({
            'invite_status': accept ? 'accepted' : 'declined',
            'accepted_at': accept ? DateTime.now().toIso8601String() : null,
          })
          .eq('id', inviteId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to respond to invitation: ${e.message}');
    }
  }

  @override
  Future<void> removeMember(String id) async {
    try {
      await _supabase
          .from('household_members')
          .delete()
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to remove household member: ${e.message}');
    }
  }

  @override
  Future<void> leaveHousehold(String id) async {
    try {
      await _supabase
          .from('household_members')
          .delete()
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to leave household: ${e.message}');
    }
  }
}
