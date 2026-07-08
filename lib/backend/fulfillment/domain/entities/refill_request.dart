import 'package:freezed_annotation/freezed_annotation.dart';

part 'refill_request.freezed.dart';
part 'refill_request.g.dart';

@freezed
abstract class RefillRequest with _$RefillRequest {
  const factory RefillRequest({
    required String id,
    @JsonKey(name: 'corporate_line_id') required String corporateLineId,
    required String source,
    required double amount,
    required String status,
    @JsonKey(name: 'fulfillment_method_used') String? fulfillmentMethodUsed,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _RefillRequest;

  factory RefillRequest.fromJson(Map<String, dynamic> json) =>
      _$RefillRequestFromJson(json);
}
