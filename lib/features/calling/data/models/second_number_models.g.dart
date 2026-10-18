// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'second_number_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SecondNumberMessage _$SecondNumberMessageFromJson(Map<String, dynamic> json) =>
    _SecondNumberMessage(
      id: json['id'] as String,
      didId: json['did_id'] as String,
      senderNumber: json['sender_number'] as String,
      recipientNumber: json['recipient_number'] as String,
      body: json['body'] as String,
      extractedOtp: json['extracted_otp'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      receivedAt: DateTime.parse(json['received_at'] as String),
    );

Map<String, dynamic> _$SecondNumberMessageToJson(
  _SecondNumberMessage instance,
) => <String, dynamic>{
  'id': instance.id,
  'did_id': instance.didId,
  'sender_number': instance.senderNumber,
  'recipient_number': instance.recipientNumber,
  'body': instance.body,
  'extracted_otp': instance.extractedOtp,
  'is_read': instance.isRead,
  'received_at': instance.receivedAt.toIso8601String(),
};

_SecondNumberOrder _$SecondNumberOrderFromJson(Map<String, dynamic> json) =>
    _SecondNumberOrder(
      id: json['id'] as String,
      state: json['state'] as String,
      phoneNumber: json['phone_number'] as String,
      didId: json['did_id'] as String?,
    );

Map<String, dynamic> _$SecondNumberOrderToJson(_SecondNumberOrder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'state': instance.state,
      'phone_number': instance.phoneNumber,
      'did_id': instance.didId,
    };
