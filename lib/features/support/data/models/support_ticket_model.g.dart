// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_ticket_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SupportTicket _$SupportTicketFromJson(Map<String, dynamic> json) =>
    _SupportTicket(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      simLineId: json['sim_line_id'] as String?,
      subject: json['subject'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      status: json['status'] as String,
      priority: json['priority'] as String? ?? 'medium',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$SupportTicketToJson(_SupportTicket instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'sim_line_id': instance.simLineId,
      'subject': instance.subject,
      'description': instance.description,
      'category': instance.category,
      'status': instance.status,
      'priority': instance.priority,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
