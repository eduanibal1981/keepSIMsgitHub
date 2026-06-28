// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_case.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TestCase _$TestCaseFromJson(Map<String, dynamic> json) => _TestCase(
  id: json['id'] as String,
  featureGroup: json['feature_group'] as String,
  testName: json['test_name'] as String,
  status: json['status'] as String? ?? 'pending',
  aiTaskRequest: json['ai_task_request'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$TestCaseToJson(_TestCase instance) => <String, dynamic>{
  'id': instance.id,
  'feature_group': instance.featureGroup,
  'test_name': instance.testName,
  'status': instance.status,
  'ai_task_request': instance.aiTaskRequest,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
