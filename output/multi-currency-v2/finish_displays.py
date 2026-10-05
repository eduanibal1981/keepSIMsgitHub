from pathlib import Path
import json
exec(Path('output/multi-currency-v2/apply_displays.py').read_text().split("display('lib/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart'")[0])

def onboarding(text):
    text = money_import(text)
    text = replace_once(text, "import 'dart:async';", "import 'dart:async';\nimport 'package:keep_sims/core/fx/fx_provider.dart';")
    text = replace_once(text, "String _selectedCurrency = 'USD';", "String _selectedCurrency = 'USD';\n  bool _isSavingCurrency = false;")
    start = text.index('  final List<Map<String, String>> _currencies = [')
    end = text.index('  ];', start) + 4
    seeds = text[start:end].replace('  final List<Map<String, String>> _currencies = [', '  static const _seedCurrencies = <Map<String, String>>[')
    seeds = seeds.replace("{'code': 'USD',", "{'code': 'OMR', 'name': 'Omani Rial (OMR)'},\n    {'code': 'USD',", 1)
    getter = '''
  List<Map<String, String>> get _currencies {
    final state = ref.watch(fxControllerProvider);
    final available = !state.isLoading && !state.hasError
        ? state.asData?.value.available ?? const []
        : const [];
    final options = available.isEmpty
        ? _seedCurrencies.toList()
        : available.map((option) => <String, String>{
            'code': option.code, 'name': '${option.name} (${option.code})',
          }).toList();
    if (!options.any((option) => option['code'] == _selectedCurrency)) {
      options.add({'code': _selectedCurrency, 'name': _selectedCurrency});
    }
    return options;
  }
'''
    text = text[:start] + seeds + getter + text[end:]
    text = replace_once(text, 'Future<void> _nextPage() async {', 'Future<void> _nextPage() async {\n    if (_isSavingCurrency) return;')
    anchor = '\n    if (_currentPage == 2) {'
    pos = text.index(anchor, text.index('Future<void> _nextPage()'))
    save = '''
    if (_currentPage == 1) {
      setState(() => _isSavingCurrency = true);
      var saved = false;
      try {
        saved = await ref.read(fxControllerProvider.notifier)
            .setDisplayCurrency(_selectedCurrency);
      } catch (_) {
        saved = false;
      } finally {
        if (mounted) setState(() => _isSavingCurrency = false);
      }
      if (!mounted) return;
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.fxCurrencySaveFailed),
          backgroundColor: AppColors.error,
        ));
        return;
      }
    }
'''
    text = text[:pos] + save + text[pos:]
    text = replace_once(text, 'Widget _buildFooter(bool isLoading) {', 'Widget _buildFooter(bool isLoading) {\n    isLoading = isLoading || _isSavingCurrency;')
    text = replace_once(text, 'onChanged: (val) {\n                  if (val != null) {\n                    setState(() {\n                      _selectedCurrency = val;', 'onChanged: _isSavingCurrency ? null : (val) {\n                  if (val != null) {\n                    setState(() {\n                      _selectedCurrency = val;')
    text = replace_once(text, 'preferredCurrency: _selectedCurrency,\n            isPowerUser:', 'preferredCurrency: _selectedCurrency,\n            isPowerUser:')
    text = replace_once(text, 'if (mounted && result is Failure<UserProfile>) {', 'ref.invalidate(fxControllerProvider);\n\n      if (mounted && result is Failure<UserProfile>) {')
    text = wrap_text(text, 'billingRate,', '''if (isStandard) ApproxLocalText(_baseServiceFeeUsd)
          else if (isPremium && premiumRule != null && !isPremiumLoading && !CarrierActivityNotice.blocksPremium(premiumRule))
            ApproxLocalText(_premiumYearlyTotalSync(premiumRule))''')
    text = wrap_text(text, 'priceStr,', 'if (!isFree) ApproxLocalText(_baseServiceFeeUsd, textAlign: TextAlign.end)')
    text = replace_once(text, 'priceStr,', 'priceStr,')
    # Existing premium detail label is a base fee plus separately shown refill.
    text = wrap_text(text, "'+ ${_premiumRefillPriceSync(premiumRule).toStringAsFixed(2)}", 'ApproxLocalText(_premiumRefillPriceSync(premiumRule), textAlign: TextAlign.end)')
    return text
edit('lib/features/profile/presentation/ui/onboarding_screen.dart', onboarding)

def upsell(text):
    text = money_import(text)
    text = text.replace("import 'package:go_router/go_router.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:keep_sims/core/providers/app_config_provider.dart';\nimport 'package:keep_sims/l10n/app_localizations.dart';")
    text = replace_once(text, 'extends StatelessWidget', 'extends ConsumerWidget')
    text = replace_once(text, 'Widget build(BuildContext context) {', 'Widget build(BuildContext context, WidgetRef ref) {\n    final baseFee = ref.watch(baseServiceFeeUsdProvider).value ?? kDefaultBaseServiceFeeUsd;')
    text = replace_once(text, '// Feature Highlights Section', '''// The configured annual protection component, not a total refill quote.
          Text('${AppLocalizations.of(context)?.fxAnnualProtectionFee ?? 'Annual protection fee'}: ${Money.usd(baseFee)}', style: TextStyle(color: accentColor, fontWeight: FontWeight.w600)),
          ApproxLocalText(baseFee, style: TextStyle(color: accentColor.withValues(alpha: 0.8), fontSize: 12)),
          const FxChargeNotice(style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 12),

          // Feature Highlights Section''')
    return text
edit('lib/features/profile/presentation/widgets/subscription_upsell_sheet.dart', upsell)

def guard(text):
    text = replace_once(text, 'String? confirmationToken,', 'String? confirmationToken,\n    Widget? amountPreview,')
    text = replace_once(text, 'token: confirmationToken,', 'token: confirmationToken,\n            amountPreview: amountPreview,')
    text = replace_once(text, 'Text(reason, style: const TextStyle(fontSize: 14)),', 'Text(reason, style: const TextStyle(fontSize: 14)),\n              if (amountPreview != null) amountPreview,')
    text = replace_once(text, 'final String token;', 'final String token;\n  final Widget? amountPreview;')
    text = replace_once(text, 'required this.token,', 'required this.token,\n    this.amountPreview,')
    text = replace_once(text, 'Text(widget.reason, style: const TextStyle(fontSize: 14)),', 'Text(widget.reason, style: const TextStyle(fontSize: 14)),\n          if (widget.amountPreview != null) widget.amountPreview!,')
    return text
edit('lib/core/services/biometric_auth_service.dart', guard)

def upgrade(text):
    text = replace_once(text, "'Authenticate to deposit \\$${shortfall.toStringAsFixed(2)} for plan upgrade',", "'Authenticate to deposit \\$${shortfall.toStringAsFixed(2)} for plan upgrade',\n                                  amountPreview: ApproxLocalText(shortfall),")
    return text
edit('lib/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart', upgrade)

def notice(path, anchor):
    def add(text):
        text = money_import(text)
        return replace_once(text, anchor, anchor + '\n                      const FxChargeNotice(),')
    edit(path, add)
notice('lib/features/sim_lines/presentation/widgets/manual_refill_bottom_sheet.dart', 'ApproxLocalText(finalPrice),')
notice('lib/features/esim/presentation/widgets/esim_checkout_sheet.dart', "'Validity period begins automatically upon first connection to a supported network.',") if False else None

print('\n'.join(changed))

translations = {
 'en': ['{currency} amounts are approximate. Charges are in USD.', "Couldn't save your display currency. Please try again.", 'Annual protection fee'],
 'ar': ['مبالغ {currency} تقريبية. تُحتسب الرسوم بالدولار الأمريكي.', 'تعذّر حفظ عملة العرض. يرجى المحاولة مرة أخرى.', 'رسوم الحماية السنوية'],
 'es': ['Los importes en {currency} son aproximados. Los cargos son en USD.', 'No se pudo guardar la moneda de visualización. Inténtalo de nuevo.', 'Cuota anual de protección'],
 'hi': ['{currency} में राशि अनुमानित है। शुल्क USD में लिया जाता है।', 'प्रदर्शन मुद्रा सहेजी नहीं जा सकी। कृपया फिर से प्रयास करें।', 'वार्षिक सुरक्षा शुल्क'],
 'bn': ['{currency}-এর পরিমাণ আনুমানিক। চার্জ USD-তে নেওয়া হয়।', 'প্রদর্শনের মুদ্রা সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।', 'বার্ষিক সুরক্ষা ফি'],
 'ne': ['{currency} का रकम अनुमानित हुन्। शुल्क USD मा लाग्छ।', 'देखाउने मुद्रा सुरक्षित गर्न सकिएन। फेरि प्रयास गर्नुहोस्।', 'वार्षिक सुरक्षा शुल्क'],
 'si': ['{currency} අගයන් ආසන්න අගයන් වේ. අය කිරීම් USD වලින් සිදු වේ.', 'පෙන්වන මුදල් ඒකකය සුරැකිය නොහැකි විය. නැවත උත්සාහ කරන්න.', 'වාර්ෂික ආරක්ෂණ ගාස්තුව'],
 'tr': ['{currency} tutarları yaklaşık değerlerdir. Ücretler USD olarak alınır.', 'Görüntüleme para birimi kaydedilemedi. Lütfen tekrar deneyin.', 'Yıllık koruma ücreti'],
 'ur': ['{currency} کی رقم تخمینی ہے۔ چارجز USD میں لیے جاتے ہیں۔', 'ڈسپلے کرنسی محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔', 'سالانہ تحفظ کی فیس'],
}
keys = ['fxChargesInUsd', 'fxCurrencySaveFailed', 'fxAnnualProtectionFee']
for locale, values in translations.items():
    def add_arb(text, locale=locale, values=values):
        additions = dict(zip(keys, values))
        if locale == 'en':
            additions['@fxChargesInUsd'] = {'description': 'Explanation for presentation-only currency estimates.', 'placeholders': {'currency': {'type': 'String'}}}
        encoded = json.dumps(additions, ensure_ascii=False, indent=2)[1:-1].strip('\n')
        return text.rstrip()[:-1].rstrip() + ',\n' + encoded + '\n}\n'
    edit('lib/l10n/app_' + locale + '.arb', add_arb)
