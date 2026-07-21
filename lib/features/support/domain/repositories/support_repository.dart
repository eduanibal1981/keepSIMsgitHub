import 'dart:io';
import '../../data/models/support_ticket_model.dart';
import '../../data/models/ticket_message_model.dart';

abstract class SupportRepository {
  Future<List<SupportTicket>> getTickets();
  Future<SupportTicket> getTicketById(String ticketId);
  Future<List<TicketMessage>> getTicketMessages(String ticketId);

  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    String? simLineId,
    required String initialMessage,
    List<Map<String, dynamic>> attachments = const [],
  });

  Future<TicketMessage> sendMessage({
    required String ticketId,
    required String message,
    List<Map<String, dynamic>> attachments = const [],
  });

  Future<void> closeTicket(String ticketId);

  Stream<List<TicketMessage>> subscribeToMessages(String ticketId);

  Future<Map<String, dynamic>> uploadFileAttachment({
    required File file,
    required String fileName,
  });

  Future<Map<String, dynamic>> exportLineActivityLogsAttachment({
    required String simLineId,
    required String phoneNumber,
  });
}
