"""Read-only checks against the working-tree baseline and tracked money paths."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

root = Path.cwd()
baseline = json.loads((root / 'output/multi-currency-v2/baseline-working-tree.json').read_text())
changed_originals = [path for path, digest in baseline.items()
                     if hashlib.sha256((root / path).read_bytes()).hexdigest().upper() != digest]
allowed_overlap = {
    'lib/features/settings/presentation/screens/preferences_screen.dart',
    'lib/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart',
    'lib/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart',
    'lib/features/wallet/ui/wallet_screen.dart',
}
other_changed_originals = sorted(set(changed_originals) - allowed_overlap)
assert not any(path.startswith(('supabase/', 'servers/')) for path in changed_originals)

def git(*args):
    return subprocess.check_output(['git', *args], text=True, encoding='utf-8')

assert not git('status', '--porcelain', '--', 'servers').strip()
for path in ['lib/features/wallet/controller/wallet_controller.dart',
             'lib/features/calling/data/models/call_rate_model.dart',
             'lib/features/esim/domain/entities/compare_offer.dart']:
    assert not git('diff', '--', path).strip(), path

def tokens(source):
    pattern = r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"|//[^\n]*|/\*[\s\S]*?\*/|\S"
    result = [t for t in re.findall(pattern, source) if not t.startswith(('//', '/*'))]
    return [t for i, t in enumerate(result)
            if not (t == ',' and i + 1 < len(result) and result[i + 1] in ')]}')]

def unchanged_methods(path, start, end):
    before = git('show', f'HEAD:{path}')
    after = (root / path).read_text(encoding='utf-8')
    assert tokens(before[before.index(start):before.index(end, before.index(start))]) == tokens(after[after.index(start):after.index(end, after.index(start))]), path

unchanged_methods('lib/features/payments/presentation/screens/paypal_checkout_screen.dart',
                  '  void _onAmountSelected', '  Widget build')
unchanged_methods('lib/features/wallet/ui/gift_credit_sheet.dart',
                  '  Future<void> _submit()', '  double? _suggestedAmount')
unchanged_methods('lib/features/wallet/ui/refund_funds_sheet.dart',
                  '  Future<void> _fetchQuote()', '  Widget build')

result = {
    'backend_and_schema_baseline_unchanged': True,
    'servers_clean': True,
    'paypal_checkout_and_capture_tokens_unchanged': True,
    'gift_and_refund_submission_tokens_unchanged': True,
    'other_changed_preexisting_files_unedited_by_this_task': other_changed_originals,
    'overlapping_ui_files': sorted(set(changed_originals) & allowed_overlap),
}
(root / 'output/multi-currency-v2/boundary-verification.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
