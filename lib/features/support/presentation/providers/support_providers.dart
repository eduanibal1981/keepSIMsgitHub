import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/support_ticket_model.dart';
import '../../data/models/ticket_message_model.dart';
import '../../data/repositories/support_repository_impl.dart';

part 'support_providers.g.dart';

@riverpod
class SupportTicketsNotifier extends _$SupportTicketsNotifier {
  @override
  FutureOr<List<SupportTicket>> build() async {
    return ref.read(supportRepositoryProvider).getTickets();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(supportRepositoryProvider).getTickets();
    });
  }

  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    String? simLineId,
    required String initialMessage,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final ticket = await ref.read(supportRepositoryProvider).createTicket(
          subject: subject,
          category: category,
          simLineId: simLineId,
          initialMessage: initialMessage,
          attachments: attachments,
        );
    refresh();
    return ticket;
  }

  Future<void> closeTicket(String ticketId) async {
    await ref.read(supportRepositoryProvider).closeTicket(ticketId);
    refresh();
  }
}

@riverpod
Stream<List<TicketMessage>> ticketMessagesStream(
    Ref ref, String ticketId) {
  return ref.read(supportRepositoryProvider).subscribeToMessages(ticketId);
}

@riverpod
Future<SupportTicket> supportTicketDetail(
    Ref ref, String ticketId) async {
  return ref.read(supportRepositoryProvider).getTicketById(ticketId);
}
