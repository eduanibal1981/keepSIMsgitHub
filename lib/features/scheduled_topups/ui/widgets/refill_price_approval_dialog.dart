import 'package:flutter/material.dart';
import 'package:keep_sims/core/result.dart';
import '../../model/refill_approval_quote.dart';

/// Supplier checking and approval share one dialog so both history screens behave alike.
class RefillPriceApprovalDialog extends StatefulWidget {
  final Future<Result<RefillApprovalQuote>> Function() loadQuote;
  final Future<Result<void>> Function(RefillApprovalQuote) approveQuote;

  const RefillPriceApprovalDialog({
    super.key,
    required this.loadQuote,
    required this.approveQuote,
  });

  @override
  State<RefillPriceApprovalDialog> createState() =>
      _RefillPriceApprovalDialogState();
}

class _RefillPriceApprovalDialogState extends State<RefillPriceApprovalDialog> {
  RefillApprovalQuote? _quote;
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _quote = null;
    });
    final result = await widget.loadQuote();
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case Success(data: final quote):
          _quote = quote;
        case Failure(error: final error):
          _error = error.message;
      }
    });
  }

  Future<void> _approve() async {
    final quote = _quote;
    if (_submitting || quote == null) return;
    if (!quote.expiresAt.isAfter(DateTime.now())) {
      setState(() {
        _quote = null;
        _error = 'This price quote expired. Check the current price again.';
      });
      return;
    }
    setState(() => _submitting = true);
    final result = await widget.approveQuote(quote);
    if (!mounted) return;
    switch (result) {
      case Success():
        Navigator.of(context).pop(true);
      case Failure(error: final error):
        setState(() {
          _submitting = false;
          _quote = null;
          _error = error.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        title: const Text('Review Current Refill Price'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Checking the current supplier price… No money is being charged.',
                ),
              ],
              if (_error != null) Text(_error!),
              if (quote != null) ...[
                if (quote.targetValue != null && quote.targetCurrency != null)
                  Text(
                    'Recharge: ${quote.targetValue} ${quote.targetCurrency}',
                  ),
                Text(
                  'Total from wallet: \$${quote.totalUsd.toStringAsFixed(2)} USD',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Includes a \$${quote.feeUsd.toStringAsFixed(2)} service fee.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Approve this refill to run now. Your limit for future automatic refills stays unchanged. If this price increases before purchase, we will ask you again.',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          if (!_loading && quote == null)
            FilledButton(
              onPressed: _load,
              child: const Text('Check Price Again'),
            ),
          if (quote != null)
            FilledButton(
              onPressed: _submitting ? null : _approve,
              child: Text(
                _submitting
                    ? 'Submitting…'
                    : 'Approve \$${quote.totalUsd.toStringAsFixed(2)}',
              ),
            ),
        ],
      ),
    );
  }
}
