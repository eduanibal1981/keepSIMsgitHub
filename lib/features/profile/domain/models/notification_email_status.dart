import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_email_status.freezed.dart';
part 'notification_email_status.g.dart';

/// The authenticated server's verdict on the account's alert destination.
@freezed
abstract class NotificationEmailStatus with _$NotificationEmailStatus {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NotificationEmailStatus({
    String? accountEmail,
    @Default(false) bool accountEmailVerified,
    String? currentEmail,
    String? alternateEmail,
    String? pendingEmail,
  }) = _NotificationEmailStatus;

  factory NotificationEmailStatus.fromJson(Map<String, dynamic> json) =>
      _$NotificationEmailStatusFromJson(json);
}
