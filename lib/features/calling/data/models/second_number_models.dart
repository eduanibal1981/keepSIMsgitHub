import 'package:freezed_annotation/freezed_annotation.dart';

part 'second_number_models.freezed.dart';
part 'second_number_models.g.dart';

@freezed
abstract class SecondNumberMessage with _$SecondNumberMessage {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory SecondNumberMessage({
    required String id,
    required String didId,
    required String senderNumber,
    required String recipientNumber,
    required String body,
    String? extractedOtp,
    @Default(false) bool isRead,
    required DateTime receivedAt,
  }) = _SecondNumberMessage;
  factory SecondNumberMessage.fromJson(Map<String, dynamic> json) =>
      _$SecondNumberMessageFromJson(json);
}

@freezed
abstract class SecondNumberOrder with _$SecondNumberOrder {
  const SecondNumberOrder._();
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory SecondNumberOrder({
    required String id,
    required String state,
    required String phoneNumber,
    String? didId,
  }) = _SecondNumberOrder;
  factory SecondNumberOrder.fromJson(Map<String, dynamic> json) =>
      _$SecondNumberOrderFromJson(json);
  bool get isPending => !['active', 'failed'].contains(state);
}

class SecondNumberCountry {
  final String code;
  final String name;
  const SecondNumberCountry(this.code, this.name);
}

class SecondNumberFailure implements Exception {
  final String message;
  const SecondNumberFailure(this.message);
  @override
  String toString() => message;
}

class SecondNumberNotEnabled extends SecondNumberFailure {
  const SecondNumberNotEnabled() : super('Second Number is not enabled yet.');
}
