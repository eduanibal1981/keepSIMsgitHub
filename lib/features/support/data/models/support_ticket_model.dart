/// SIM Shield — Support Ticket Model
///
/// Maps to `support_tickets` table in Supabase.
/// Uses Freezed v3 with snake_case serialization.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'support_ticket_model.freezed.dart';
part 'support_ticket_model.g.dart';

@freezed
abstract class SupportTicket with _$SupportTicket {
  const SupportTicket._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory SupportTicket({
    required String id,
    required String userId,
    String? simLineId,
    required String subject,
    String? description,
    required String category, // 'general', 'billing', 'technical', 'refill_issue', 'account'
    required String status, // 'open', 'pending', 'resolved', 'closed'
    @Default('medium') String priority, // 'low', 'medium', 'high', 'urgent'
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _SupportTicket;

  factory SupportTicket.fromJson(Map<String, dynamic> json) =>
      _$SupportTicketFromJson(json);

  bool get isOpen => status == 'open' || status == 'pending';
  bool get isClosed => status == 'closed' || status == 'resolved';
}
