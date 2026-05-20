import 'package:freezed_annotation/freezed_annotation.dart';

part 'alert_setting_model.freezed.dart';
part 'alert_setting_model.g.dart';

@freezed
abstract class AlertSetting with _$AlertSetting {
  const factory AlertSetting({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required String category,
    @JsonKey(name: 'is_enabled') @Default(true) bool isEnabled,
    @Default(['push']) List<String> channels,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _AlertSetting;

  factory AlertSetting.fromJson(Map<String, dynamic> json) =>
      _$AlertSettingFromJson(json);
}
