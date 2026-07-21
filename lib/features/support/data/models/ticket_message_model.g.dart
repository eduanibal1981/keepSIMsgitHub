// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TicketMessage _$TicketMessageFromJson(Map<String, dynamic> json) =>
    _TicketMessage(
      id: json['id'] as String,
      ticketId: json['ticket_id'] as String,
      userId: json['user_id'] as String,
      sender: json['sender'] as String,
      message: json['message'] as String,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$TicketMessageToJson(_TicketMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ticket_id': instance.ticketId,
      'user_id': instance.userId,
      'sender': instance.sender,
      'message': instance.message,
      'attachments': instance.attachments,
      'created_at': instance.createdAt.toIso8601String(),
    };
