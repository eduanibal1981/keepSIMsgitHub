import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_config.freezed.dart';
part 'system_config.g.dart';

@freezed
abstract class SystemConfig with _$SystemConfig {
  const factory SystemConfig({
    @JsonKey(name: 'config_key') required String configKey,
    @JsonKey(name: 'config_value') required String configValue,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _SystemConfig;

  factory SystemConfig.fromJson(Map<String, dynamic> json) =>
      _$SystemConfigFromJson(json);
}
