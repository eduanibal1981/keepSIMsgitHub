import 'package:keep_sims/features/topup/data/models/top_up_result.dart';

abstract class ITopUpRepository {
  Future<TopUpResult> executeRecharge({
    required String phoneNumber,
    required String countryCode,
    required double amount,
  });
}
