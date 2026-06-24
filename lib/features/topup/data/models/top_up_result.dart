import 'package:freezed_annotation/freezed_annotation.dart';

part 'top_up_result.freezed.dart';
part 'top_up_result.g.dart';

@freezed
abstract class TopUpResult with _$TopUpResult {
  const factory TopUpResult({
    required bool success,
    required String transactionId,
    String? errorMessage,
    double? amountToppedUp,
    String? localBenefit,
  }) = _TopUpResult;

  factory TopUpResult.fromJson(Map<String, dynamic> json) =>
      _$TopUpResultFromJson(json);
}
