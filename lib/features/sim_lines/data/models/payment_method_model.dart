import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_method_model.freezed.dart';
part 'payment_method_model.g.dart';

@freezed
abstract class PaymentMethod with _$PaymentMethod {
  const PaymentMethod._();

  const factory PaymentMethod({
    required String code,
    required String name,
    @JsonKey(name: 'fee_percentage') required double feePercentage,
    @JsonKey(name: 'fee_fixed') required double feeFixed,
    @JsonKey(name: 'is_active') required bool isActive,
  }) = _PaymentMethod;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodFromJson(json);
}
