import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';

part 'currency_formatter.g.dart';

@riverpod
class CurrencyCodeController extends _$CurrencyCodeController {
  static const _currencyCodeKey = 'app_currency_code';

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider).requireValue;
    final savedCurrency = prefs.getString(_currencyCodeKey);
    // Default to USD if none selected
    return savedCurrency ?? 'USD';
  }

  Future<void> setCurrencyCode(String newCurrencyCode) async {
    final prefs = ref.read(sharedPreferencesProvider).requireValue;
    await prefs.setString(_currencyCodeKey, newCurrencyCode);
    state = newCurrencyCode;
  }
}

class CurrencyFormatter {
  /// Formats the given [amount] based on the provided [currencyCode] (e.g. 'USD', 'EUR', 'AED').
  /// The [locale] argument specifies formatting rules (e.g. comma vs period for decimals),
  /// but we typically let it default to the system locale or the app locale.
  static String format(double amount, {required String currencyCode, String? locale}) {
    final format = NumberFormat.simpleCurrency(
      locale: locale,
      name: currencyCode,
    );
    return format.format(amount);
  }
}
