import 'package:freezed_annotation/freezed_annotation.dart';

part 'esim_order.freezed.dart';
part 'esim_order.g.dart';

@freezed
abstract class EsimOrder with _$EsimOrder {
  const factory EsimOrder({
    required String id,
    required String userId,
    required String provider,
    required String bundleName,
    required int quantity,
    required double retailPriceUsd,
    required String status,
    String? errorMessage,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _EsimOrder;

  factory EsimOrder.fromJson(Map<String, dynamic> json) =>
      _$EsimOrderFromJson(json);
}
