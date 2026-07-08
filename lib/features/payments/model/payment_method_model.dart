/// SIM Shield — Payment Method Model
///
/// Maps to `payment_methods` table in Supabase.
/// Uses Freezed for immutability and snake_case serialization.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_method_model.freezed.dart';
part 'payment_method_model.g.dart';

@freezed
abstract class PaymentMethod with _$PaymentMethod {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory PaymentMethod({
    String? id,
    required String userId,
    @Default('card') String type,
    String? provider,
    String? label,
    String? token,
    @Default(false) bool isDefault,
    String? lastFour,
    int? expiryMonth,
    int? expiryYear,
    DateTime? createdAt,
  }) = _PaymentMethod;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodFromJson(json);
}
