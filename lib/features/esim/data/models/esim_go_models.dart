import 'package:freezed_annotation/freezed_annotation.dart';

part 'esim_go_models.freezed.dart';
part 'esim_go_models.g.dart';

@freezed
abstract class EsimGoBundleDto with _$EsimGoBundleDto {
  const factory EsimGoBundleDto({
    required String name,
    required String description,
    required int dataAmount,
    required int duration,
    required double price,
    @Default([]) List<EsimGoCountryDto> countries,
    @Default([]) List<EsimGoCountryDto> roamingEnabled,
  }) = _EsimGoBundleDto;

  factory EsimGoBundleDto.fromJson(Map<String, dynamic> json) => _$EsimGoBundleDtoFromJson(json);
}

@freezed
abstract class EsimGoCountryDto with _$EsimGoCountryDto {
  const factory EsimGoCountryDto({
    required String iso,
    String? name,
  }) = _EsimGoCountryDto;

  factory EsimGoCountryDto.fromJson(Map<String, dynamic> json) => _$EsimGoCountryDtoFromJson(json);
}

@freezed
abstract class EsimGoOrderRequestDto with _$EsimGoOrderRequestDto {
  @JsonSerializable(explicitToJson: true)
  const factory EsimGoOrderRequestDto({
    required String type,
    required bool assign,
    @JsonKey(name: 'Order') required List<EsimGoOrderItemDto> order,
  }) = _EsimGoOrderRequestDto;

  factory EsimGoOrderRequestDto.fromJson(Map<String, dynamic> json) => _$EsimGoOrderRequestDtoFromJson(json);
}

@freezed
abstract class EsimGoOrderItemDto with _$EsimGoOrderItemDto {
  const factory EsimGoOrderItemDto({
    required String type,
    required String item,
    required int quantity,
  }) = _EsimGoOrderItemDto;

  factory EsimGoOrderItemDto.fromJson(Map<String, dynamic> json) => _$EsimGoOrderItemDtoFromJson(json);
}

@freezed
abstract class EsimGoOrderResponseDto with _$EsimGoOrderResponseDto {
  const factory EsimGoOrderResponseDto({
    String? orderReference,
    double? total,
    String? currency,
  }) = _EsimGoOrderResponseDto;

  factory EsimGoOrderResponseDto.fromJson(Map<String, dynamic> json) => _$EsimGoOrderResponseDtoFromJson(json);
}
