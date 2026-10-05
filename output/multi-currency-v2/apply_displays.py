from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
MONEY = "import 'package:keep_sims/core/fx/money.dart';"
changed = []

def edit(path, transform):
    target = ROOT / path
    raw = target.read_bytes().decode('utf-8')
    newline = '\r\n' if '\r\n' in raw else '\n'
    text = raw.replace('\r\n', '\n')
    result = transform(text)
    if result != text:
        target.write_bytes(result.replace('\n', newline).encode('utf-8'))
        changed.append(path)

def replace_once(text, before, after):
    assert text.count(before) == 1, (before, text.count(before))
    return text.replace(before, after, 1)

def money_import(text):
    if MONEY in text: return text
    return replace_once(text, "import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\n" + MONEY)

def text_end(text, start):
    depth = 0
    quote = None
    escaped = False
    for i in range(text.index('(', start), len(text)):
        c = text[i]
        if quote:
            if escaped: escaped = False
            elif c == '\\': escaped = True
            elif c == quote: quote = None
        elif c in "'\"": quote = c
        elif c == '(': depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0: return i + 1
    raise AssertionError('Unbalanced Text')

def wrap_text(text, anchor, secondary, align='end'):
    matches = []
    for m in re.finditer(r'(?:const )?Text\(', text):
        end = text_end(text, m.start())
        if anchor in text[m.start():end]: matches.append((m.start(), end))
    assert len(matches) == 1, (anchor, len(matches))
    start, end = matches[0]
    line_start = text.rfind('\n', 0, start) + 1
    indent = re.match(r'\s*', text[line_start:start]).group()
    original = text[start:end]
    replacement = 'Column(\n' + indent + '  crossAxisAlignment: CrossAxisAlignment.' + align + ',\n' + indent + '  mainAxisSize: MainAxisSize.min,\n' + indent + '  children: [\n' + indent + '    ' + original.replace('\n', '\n    ') + ',\n' + indent + '    ' + secondary + ',\n' + indent + '  ],\n' + indent + ')'
    return text[:start] + replacement + text[end:]

def display(path, changes):
    def transform(text):
        text = money_import(text)
        for anchor, secondary, *alignment in changes:
            if secondary in text: continue
            text = wrap_text(text, anchor, secondary, alignment[0] if alignment else 'end')
        return text
    edit(path, transform)

display('lib/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart', [
    ('planKey == \'premium\' && carrierRule != null', 'ApproxLocalText(planKey == \'premium\' && carrierRule != null ? PlanPayment.premiumYearlyTotalSync(ref, carrierRule) : _baseServiceFeeUsd, textAlign: TextAlign.end)'),
])
display('lib/features/sim_lines/presentation/screens/sim_line_form_screen.dart', [
    ("'\\$${annualFee.toStringAsFixed(2)}'", 'ApproxLocalText(annualFee, textAlign: TextAlign.end)'),
    ("'\\$${firstRefill.toStringAsFixed(2)}'", 'ApproxLocalText(firstRefill, textAlign: TextAlign.end)'),
    ("'\\$${totalDue.toStringAsFixed(2)} USD'", 'ApproxLocalText(totalDue, textAlign: TextAlign.end)'),
])
display('lib/features/wallet/ui/wallet_screen.dart', [
    ('Your balance is below', 'const ApproxLocalText(10)', 'start'),
])
display('lib/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart', [
    ('finalPrice.toStringAsFixed(2)', 'ApproxLocalText(finalPrice, textAlign: TextAlign.end)'),
])
for file in ['gift_credit_sheet.dart', 'refund_funds_sheet.dart']:
    def preview(text):
        text = money_import(text)
        if 'ApproxLocalAmountPreview(_amountController)' in text: return text
        anchor = 'controller: _amountController,'
        pos = text.index(anchor)
        start = text.rfind('TextField(', 0, pos)
        end = text_end(text, start)
        assert text[end] == ','
        return text[:end+1] + '\n          ApproxLocalAmountPreview(_amountController),' + text[end+1:]
    edit('lib/features/wallet/ui/' + file, preview)

display('lib/features/calling/presentation/widgets/country_rate_chip.dart', [
    ('rate.ratePerMinute.toStringAsFixed(3)', "ApproxLocalRateText(rate.ratePerMinute, unit: '/min', minDigits: 3)", 'start'),
])
display('lib/features/calling/presentation/widgets/destination_country_search_sheet.dart', [
    ('rate.ratePerMinute.toStringAsFixed(3)', "ApproxLocalRateText(rate.ratePerMinute, unit: '/min', minDigits: 3)", 'start'),
])
display('lib/features/calling/presentation/screens/calling_screen.dart', [
    ('dialerState.effectiveRatePerMinute.toStringAsFixed(3)', "if (!dialerState.isPreviewLoading) ApproxLocalRateText(dialerState.effectiveRatePerMinute, unit: '/min', minDigits: 3)"),
    ('dialerState.effectiveRatePerSecond.toStringAsFixed(5)', "if (!dialerState.isPreviewLoading) ApproxLocalRateText(dialerState.effectiveRatePerSecond, unit: '/s', maxDigits: 5)"),
])
display('lib/features/calling/presentation/screens/active_call_screen.dart', [
    ('callState.estimatedCost.toStringAsFixed(3)', "if ((isConnected || callState.status == 'completed') && callState.estimatedCost > 0) ApproxLocalRateText(callState.estimatedCost, minDigits: 3)", 'start'),
])
display('lib/features/calling/presentation/widgets/rate_savings_calculator_widget.dart', [
    ('carrierTotalCost.toStringAsFixed(2)', 'ApproxLocalText(carrierTotalCost)', 'start'),
    ('keepSimsTotalCost.toStringAsFixed(2)', 'ApproxLocalText(keepSimsTotalCost)', 'start'),
    ('totalSavings.toStringAsFixed(2)', 'ApproxLocalText(savingsResult.isPositiveSavings ? totalSavings : -totalSavings)', 'start'),
])
display('lib/features/calling/presentation/screens/smart_call_savings_screen.dart', [
    ('calcResult.keepSimsCost.toStringAsFixed(2)', 'ApproxLocalText(calcResult.keepSimsCost)', 'start'),
    ('calcResult.comparisonCost!.toStringAsFixed(2)', 'if (calcResult.comparisonCost != null) ApproxLocalText(calcResult.comparisonCost!)', 'start'),
    ('You save', 'if (calcResult.hasComparison) ApproxLocalText((calcResult.savingsAmount ?? 0).abs())', 'start'),
])

def paypal(text):
    text = money_import(text)
    text = replace_once(text, 'label: Text(\'\\$${amt.toInt()}\'),', '''label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('\\$${amt.toInt()}'),
          ApproxLocalText(amt, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : context.onSurfaceColor.withValues(alpha: 0.6))),
        ],
      ),''')
    text = replace_once(text, '// Preset Amount Chips (Defect #1 fix)\n                      Row(', '// Preset Amount Chips (Defect #1 fix)\n                      Wrap(')
    text = replace_once(text, 'mainAxisAlignment: MainAxisAlignment.spaceEvenly,\n                        children: _presetAmounts', 'alignment: WrapAlignment.center,\n                        spacing: 8,\n                        runSpacing: 8,\n                        children: _presetAmounts')
    return text
edit('lib/features/payments/presentation/screens/paypal_checkout_screen.dart', paypal)

display('lib/features/esim/presentation/widgets/compare_offer_card.dart', [
    ('offer.listPriceUsd!.toStringAsFixed(2)', 'ApproxLocalText(offer.listPriceUsd!, textAlign: TextAlign.end, style: AppTextStyles.caption.copyWith(decoration: TextDecoration.lineThrough))'),
    ('offer.pricePerGbUsd!.toStringAsFixed(2)', "ApproxLocalRateText(offer.pricePerGbUsd!, unit: ' ${l10n.perGb}', minDigits: 2, textAlign: TextAlign.end)"),
])

def details(text):
    text = money_import(text)
    text = replace_once(text, "value: '\\$${offer.priceUsd.toStringAsFixed(2)}',\n            sub: 'USD',", "value: offer.canQuotePrice ? '\\$${offer.priceUsd.toStringAsFixed(2)}' : l10n.comparePriceAtPartner,\n            sub: offer.canQuotePrice ? 'USD' : '',\n            usdAmount: offer.canQuotePrice ? offer.priceUsd : null,")
    text = replace_once(text, 'required String sub,\n  }) {', 'required String sub,\n    double? usdAmount,\n  }) {')
    text = replace_once(text, 'if (sub.isNotEmpty)\n          Text(', 'if (usdAmount != null) ApproxLocalText(usdAmount, textAlign: TextAlign.center),\n        if (sub.isNotEmpty)\n          Text(')
    return text
edit('lib/features/esim/presentation/widgets/compare_offer_details_sheet.dart', details)

print('Updated display files:')
print('\n'.join(changed))
