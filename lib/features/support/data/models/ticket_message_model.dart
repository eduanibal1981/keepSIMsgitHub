/// SIM Shield — Ticket Message Model
///
/// Maps to `ticket_messages` table in Supabase.
/// Uses Freezed v3 with snake_case serialization.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'ticket_message_model.freezed.dart';
part 'ticket_message_model.g.dart';

@freezed
abstract class TicketMessage with _$TicketMessage {
  const TicketMessage._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory TicketMessage({
    required String id,
    required String ticketId,
    required String userId,
    required String sender, // 'user' or 'admin'
    required String message,
    @Default([]) List<Map<String, dynamic>> attachments,
    required DateTime createdAt,
  }) = _TicketMessage;

  factory TicketMessage.fromJson(Map<String, dynamic> json) =>
      _$TicketMessageFromJson(json);

  bool get isAdmin => sender == 'admin';
  bool get isUser => sender == 'user';
}
