import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

@freezed
abstract class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required String category,
    required String title,
    required String body,
    @JsonKey(name: 'is_read') @Default(false) bool isRead,
    @JsonKey(name: 'action_url') String? actionUrl,
    @JsonKey(name: 'sim_line_id') String? simLineId,
    @JsonKey(name: 'delivered_via') @Default([]) List<String> deliveredVia,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'schema_version') @Default(1) int schemaVersion,
    @JsonKey(name: 'event_type') String? eventType,
    @JsonKey(name: 'source_event_key') String? sourceEventKey,
    @JsonKey(name: 'occurred_at') DateTime? occurredAt,
    @JsonKey(name: 'scheduled_at') DateTime? scheduledAt,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'template_version') @Default(1) int templateVersion,
    @JsonKey(name: 'template_data') @Default({}) Map<String, dynamic> templateData,
    @JsonKey(name: 'target') Map<String, dynamic>? target,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}
