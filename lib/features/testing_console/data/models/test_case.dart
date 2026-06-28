import 'package:freezed_annotation/freezed_annotation.dart';

part 'test_case.freezed.dart';
part 'test_case.g.dart';

@freezed
abstract class TestCase with _$TestCase {
  const factory TestCase({
    required String id,
    @JsonKey(name: 'feature_group') required String featureGroup,
    @JsonKey(name: 'test_name') required String testName,
    @Default('pending') String status,
    @JsonKey(name: 'ai_task_request') String? aiTaskRequest,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _TestCase;

  factory TestCase.fromJson(Map<String, dynamic> json) => _$TestCaseFromJson(json);
}
