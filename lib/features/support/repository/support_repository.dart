import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import '../contract/support_contract.dart';
import '../data/models/support_ticket.dart';

class SupportRepository implements SupportContract {
  final SupabaseClient _client;

  SupportRepository(this._client);

  @override
  Future<Result<List<SupportTicket>>> getUserTickets() async {
    try {
      final response = await _client
          .from('support_tickets')
          .select()
          .order('created_at', ascending: false);

      final tickets = (response as List<dynamic>)
          .map((json) => SupportTicket.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(tickets);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<SupportTicket>> createTicket({
    required String subject,
    required String description,
    required String category,
    File? attachment,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(AppFailure.auth(message: 'Not authenticated'));
      }

      String? attachmentUrl;

      if (attachment != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${attachment.uri.pathSegments.last}';
        final uploadPath = '$userId/$fileName';

        await _client.storage
            .from('support_attachments')
            .upload(uploadPath, attachment);
        attachmentUrl = _client.storage
            .from('support_attachments')
            .getPublicUrl(uploadPath);
      }

      final response = await _client
          .from('support_tickets')
          .insert({
            'user_id': userId,
            'subject': subject,
            'description': description,
            'category': category,
            'attachment_url': ?attachmentUrl,
          })
          .select()
          .single();

      return Success(SupportTicket.fromJson(response));
    } on StorageException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }
}
