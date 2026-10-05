from pathlib import Path
exec(Path('output/multi-currency-v2/apply_displays.py').read_text().split("display('lib/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart'")[0])

display('lib/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart', [
    ('_quote(_rangeBaseCostUsd, line: currentLine).breakdownText', 'ApproxLocalText(_rangeFinalPriceUsd)', 'start'),
])

def insert_notice(path, before, replacement):
    edit(path, lambda text: replace_once(money_import(text), before, replacement))
insert_notice('lib/features/payments/presentation/screens/paypal_checkout_screen.dart', '_buildStatusWidget(isDark, l10n, isDeposit),', 'const FxChargeNotice(),\n              _buildStatusWidget(isDark, l10n, isDeposit),')
insert_notice('lib/features/esim/presentation/widgets/esim_checkout_sheet.dart', 'if (_errorMessage != null) ...[', 'const FxChargeNotice(),\n          if (_errorMessage != null) ...[')
insert_notice('lib/features/profile/presentation/ui/onboarding_screen.dart', '// i8: same link as the add-line form.', 'const FxChargeNotice(),\n          // i8: same link as the add-line form.')

def styles(text):
    # These calling surfaces have an intentionally dark canvas in both themes.
    patterns = {
      "ApproxLocalRateText(rate.ratePerMinute, unit: '/min', minDigits: 3)": "ApproxLocalRateText(rate.ratePerMinute, unit: '/min', minDigits: 3, style: const TextStyle(color: Colors.amberAccent, fontSize: 11))",
      "ApproxLocalRateText(dialerState.effectiveRatePerMinute, unit: '/min', minDigits: 3)": "ApproxLocalRateText(dialerState.effectiveRatePerMinute, unit: '/min', minDigits: 3, style: const TextStyle(color: Colors.amberAccent, fontSize: 11))",
      "ApproxLocalRateText(dialerState.effectiveRatePerSecond, unit: '/s', maxDigits: 5)": "ApproxLocalRateText(dialerState.effectiveRatePerSecond, unit: '/s', maxDigits: 5, style: const TextStyle(color: Colors.amberAccent, fontSize: 11))",
      'ApproxLocalRateText(callState.estimatedCost, minDigits: 3)': 'ApproxLocalRateText(callState.estimatedCost, minDigits: 3, style: const TextStyle(color: Colors.amberAccent, fontSize: 11))',
      'ApproxLocalText(carrierTotalCost)': 'ApproxLocalText(carrierTotalCost, style: const TextStyle(color: Colors.white60, fontSize: 11))',
      'ApproxLocalText(keepSimsTotalCost)': 'ApproxLocalText(keepSimsTotalCost, style: const TextStyle(color: Colors.white60, fontSize: 11))',
      'ApproxLocalText(savingsResult.isPositiveSavings ? totalSavings : -totalSavings)': 'ApproxLocalText(savingsResult.isPositiveSavings ? totalSavings : -totalSavings, style: const TextStyle(color: Colors.amberAccent, fontSize: 11))',
      'ApproxLocalText(calcResult.keepSimsCost)': 'ApproxLocalText(calcResult.keepSimsCost, style: const TextStyle(color: Colors.white60, fontSize: 11))',
      'ApproxLocalText(calcResult.comparisonCost!)': 'ApproxLocalText(calcResult.comparisonCost!, style: const TextStyle(color: Colors.white60, fontSize: 11))',
      'ApproxLocalText((calcResult.savingsAmount ?? 0).abs())': 'ApproxLocalText((calcResult.savingsAmount ?? 0).abs(), style: const TextStyle(color: Colors.amberAccent, fontSize: 11))',
    }
    for before, after in patterns.items(): text = text.replace(before, after)
    return text
for path in [
 'lib/features/calling/presentation/widgets/country_rate_chip.dart',
 'lib/features/calling/presentation/widgets/destination_country_search_sheet.dart',
 'lib/features/calling/presentation/screens/calling_screen.dart',
 'lib/features/calling/presentation/screens/active_call_screen.dart',
 'lib/features/calling/presentation/widgets/rate_savings_calculator_widget.dart',
 'lib/features/calling/presentation/screens/smart_call_savings_screen.dart',
]: edit(path, styles)

print('\n'.join(changed))
