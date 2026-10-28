import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_daily_selection.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_recharge.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_daily_controller.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_recharge_controller.dart';

class EsimDailyQuotePanel extends ConsumerStatefulWidget {
  const EsimDailyQuotePanel({
    super.key,
    required this.packageId,
    this.profileId,
    this.offerVersion,
    this.onAccepted,
  });
  final String packageId;
  final String? profileId, offerVersion;
  final void Function(String orderId)? onAccepted;
  @override
  ConsumerState<EsimDailyQuotePanel> createState() =>
      _EsimDailyQuotePanelState();
}

class _EsimDailyQuotePanelState extends ConsumerState<EsimDailyQuotePanel> {
  String _days = '1';
  EsimDailySelection? _selection;
  String? _selectionOwner, _notice;
  bool _busy = false;
  final _requestKey = const Uuid().v4();
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _selection != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _accept(EsimRechargeQuote quote) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            widget.profileId == null
                ? 'Confirm Day Pass purchase'
                : 'Confirm day extension',
          ),
          content: Text(
            '${quote.offer!.duration} days • USD ${quote.offer!.total.toStringAsFixed(2)}\n\n${widget.profileId == null ? 'A separate new eSIM will be prepared.' : 'This extends validity on the same eSIM. It does not refill today’s high-speed allowance or undo slowing.'}\n\nThe reviewed total is reserved while the outcome is confirmed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      final result = await ref
          .read(esimMoneyActionsProvider)
          .accept(quote, requestKey: _requestKey);
      if (!mounted) return;
      setState(
        () => _notice = result.accepted
            ? 'Request recorded. Track its confirmed outcome in order history.'
            : rechargeStatusMessage(result.status),
      );
      if (result.accepted) widget.onAccepted?.call(result.orderId!);
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice =
              'Could not confirm the response. Check order history before trying again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(authControllerProvider).value?.id;
    final days = int.tryParse(_days);
    final valid = days != null && days >= 1 && days <= 365;
    final selected = owner != null && owner == _selectionOwner
        ? _selection
        : null;
    final result = selected == null
        ? null
        : ref.watch(esimDailyQuoteProvider(selected));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.profileId == null
              ? 'Choose Day Pass duration'
              : 'Extend this Day Pass',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text('Daily reset time: Not provided'),
        if (widget.profileId != null)
          const Text(
            'Adds validity days only. Today’s high-speed allowance and any slowing stay unchanged.',
          ),
        TextFormField(
          initialValue: _days,
          key: const ValueKey('esim-daily-days'),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Number of days (1–365)',
            errorText: valid ? null : 'Enter a whole number from 1 to 365',
          ),
          enabled: !_busy,
          onChanged: (v) => setState(() {
            _days = v;
            _selection = null;
            _notice = null;
          }),
        ),
        OutlinedButton(
          onPressed: !valid || owner == null || _busy
              ? null
              : () => setState(() {
                  _selectionOwner = owner;
                  _selection = EsimDailySelection(
                    packageId: widget.packageId,
                    days: days,
                    profileId: widget.profileId,
                    offerVersion: widget.offerVersion,
                  );
                  ref.invalidate(esimDailyQuoteProvider(_selection!));
                }),
          child: const Text('Get total quote'),
        ),
        if (result != null)
          result.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text('Could not load the total. Try again.'),
            data: (quote) {
              if (quote.status != 'QUOTED') {
                return Text(rechargeStatusMessage(quote.status));
              }
              if (quote.expired) {
                return const Text(
                  'Quote expired. Request a new total before confirming.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${quote.offer!.duration} days • Total USD ${quote.offer!.total.toStringAsFixed(2)}',
                    key: const ValueKey('esim-daily-total'),
                  ),
                  Text(quote.offer!.allowanceLabel),
                  Text(quote.offer!.behaviorLabel),
                  Text(quote.balanceLabel),
                  Text('Quote expires: ${quote.expiresAt!.toLocal()}'),
                  const Text(
                    'Final expiry awaits service confirmation. Browsing does not charge your wallet.',
                  ),
                  if (!quote.acceptanceEnabled)
                    const Text('Preview only. Payments are not enabled yet.'),
                  FilledButton(
                    onPressed:
                        _busy ||
                            !quote.acceptanceEnabled ||
                            quote.balanceState != 'sufficient'
                        ? null
                        : () => _accept(quote),
                    child: Text(
                      _busy ? 'Processing…' : 'Confirm reviewed total',
                    ),
                  ),
                ],
              );
            },
          ),
        if (_notice != null) Text(_notice!),
      ],
    );
  }
}
