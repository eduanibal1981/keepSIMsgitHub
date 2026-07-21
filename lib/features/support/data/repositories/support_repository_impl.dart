import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_ticket_model.dart';
import '../models/ticket_message_model.dart';
import '../../domain/repositories/support_repository.dart';

part 'support_repository_impl.g.dart';

@riverpod
SupportRepository supportRepository(Ref ref) {
  return SupportRepositoryImpl(supabase: Supabase.instance.client);
}

class SupportRepositoryImpl implements SupportRepository {
  final SupabaseClient _supabase;

  SupportRepositoryImpl({required SupabaseClient supabase})
      : _supabase = supabase;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  @override
  Future<List<SupportTicket>> getTickets() async {
    try {
      final response = await _supabase
          .from('support_tickets')
          .select()
          .order('updated_at', ascending: false);

      return (response as List)
          .map((json) => SupportTicket.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch support tickets: ${e.message}');
    }
  }

  @override
  Future<SupportTicket> getTicketById(String ticketId) async {
    try {
      final response = await _supabase
          .from('support_tickets')
          .select()
          .eq('id', ticketId)
          .single();

      return SupportTicket.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch ticket: ${e.message}');
    }
  }

  @override
  Future<List<TicketMessage>> getTicketMessages(String ticketId) async {
    try {
      final response = await _supabase
          .from('ticket_messages')
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => TicketMessage.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch ticket messages: ${e.message}');
    }
  }

  @override
  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    String? simLineId,
    required String initialMessage,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // 1. Insert support ticket
      final ticketResponse = await _supabase
          .from('support_tickets')
          .insert({
            'user_id': userId,
            'sim_line_id': simLineId,
            'subject': subject,
            'category': category,
            'status': 'open',
            'priority': 'medium',
          })
          .select()
          .single();

      final ticket = SupportTicket.fromJson(ticketResponse);

      // 2. Insert initial message
      await _supabase.from('ticket_messages').insert({
        'ticket_id': ticket.id,
        'user_id': userId,
        'sender': 'user',
        'message': initialMessage,
        'attachments': attachments,
      });

      return ticket;
    } on PostgrestException catch (e) {
      throw Exception('Failed to create ticket: ${e.message}');
    }
  }

  @override
  Future<TicketMessage> sendMessage({
    required String ticketId,
    required String message,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final response = await _supabase
          .from('ticket_messages')
          .insert({
            'ticket_id': ticketId,
            'user_id': userId,
            'sender': 'user',
            'message': message,
            'attachments': attachments,
          })
          .select()
          .single();

      return TicketMessage.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to send message: ${e.message}');
    }
  }

  @override
  Future<void> closeTicket(String ticketId) async {
    try {
      await _supabase
          .from('support_tickets')
          .update({'status': 'closed', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', ticketId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to close ticket: ${e.message}');
    }
  }

  @override
  Stream<List<TicketMessage>> subscribeToMessages(String ticketId) {
    final controller = StreamController<List<TicketMessage>>();

    // Initial fetch
    getTicketMessages(ticketId).then((initialList) {
      if (!controller.isClosed) controller.add(initialList);
    }).catchError((err) {
      if (!controller.isClosed) controller.addError(err);
    });

    final channel = _supabase.channel('public:ticket_messages:$ticketId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ticket_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ticket_id',
            value: ticketId,
          ),
          callback: (payload) async {
            try {
              final updatedList = await getTicketMessages(ticketId);
              if (!controller.isClosed) controller.add(updatedList);
            } catch (e) {
              if (!controller.isClosed) controller.addError(e);
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<Map<String, dynamic>> uploadFileAttachment({
    required File file,
    required String fileName,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '$userId/${timestamp}_$sanitizeName';

      final fileBytes = await file.readAsBytes();
      await _supabase.storage.from('ticket-attachments').uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      final signedUrl = await _supabase.storage
          .from('ticket-attachments')
          .createSignedUrl(path, 60 * 60 * 24 * 7); // 7 days valid signed URL

      return {
        'name': fileName,
        'path': path,
        'url': signedUrl,
        'type': fileName.endsWith('.txt') ? 'document' : 'image',
      };
    } catch (e) {
      throw Exception('Failed to upload attachment: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> exportLineActivityLogsAttachment({
    required String simLineId,
    required String phoneNumber,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // Fetch C6 activity logs (capped 50)
      final response = await _supabase
          .from('line_activity_log')
          .select()
          .eq('sim_line_id', simLineId)
          .order('created_at', ascending: false)
          .limit(50);

      final logs = response as List;
      final buffer = StringBuffer();
      buffer.writeln('=== SIM Shield — Activity Logs Export ===');
      buffer.writeln('SIM Line ID: $simLineId');
      buffer.writeln('Phone Number: $phoneNumber');
      buffer.writeln('Exported At: ${DateTime.now().toIso8601String()}');
      buffer.writeln('Total Log Entries: ${logs.length}');
      buffer.writeln('--------------------------------------------------');

      for (final item in logs) {
        final date = item['created_at'];
        final eventType = item['event_type'];
        final desc = item['description'] ?? '';
        final metadata = jsonEncode(item['metadata'] ?? {});
        buffer.writeln('[$date] [$eventType] $desc | Metadata: $metadata');
      }

      final logContent = buffer.toString();
      final bytes = utf8.encode(logContent);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'activity_logs_${phoneNumber.replaceAll('+', '')}.txt';
      final path = '$userId/${timestamp}_$fileName';

      await _supabase.storage.from('ticket-attachments').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'text/plain; charset=utf-8',
              cacheControl: '3600',
              upsert: true,
            ),
          );

      final signedUrl = await _supabase.storage
          .from('ticket-attachments')
          .createSignedUrl(path, 60 * 60 * 24 * 7);

      return {
        'name': 'Activity Logs ($phoneNumber)',
        'path': path,
        'url': signedUrl,
        'type': 'activity_log',
      };
    } catch (e) {
      throw Exception('Failed to export activity logs: $e');
    }
  }
}
