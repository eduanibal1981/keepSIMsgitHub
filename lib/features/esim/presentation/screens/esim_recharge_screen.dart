import 'package:keep_sims/features/esim/presentation/widgets/esim_daily_quote_panel.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_recharge.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_recharge_controller.dart';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';

class EsimRechargeScreen extends ConsumerStatefulWidget {
  const EsimRechargeScreen({super.key, required this.profileId});
  final String profileId;
  static Future<void> show(BuildContext context, String profileId) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EsimRechargeScreen(profileId: profileId),
        ),
      );
  @override
  ConsumerState<EsimRechargeScreen> createState() => _EsimRechargeScreenState();
}

class _EsimRechargeScreenState extends ConsumerState<EsimRechargeScreen> {
  EsimRechargeSelection? _selection;
  bool _submitting = false;
  String? _notice, _acceptedOrder;
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

  void _refresh() {
    setState(() {
      _selection = null;
      _acceptedOrder = null;
    });
    ref.invalidate(esimRechargeDiscoveryProvider(widget.profileId));
  }

  Future<void> _accept(EsimRechargeQuote quote, String profileName) async {
    if (_submitting || _acceptedOrder != null) return;
    setState(() => _submitting = true);
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm this recharge'),
          content: Text(
            'Recharge $profileName with ${quote.offer!.title} for USD ${quote.offer!.total.toStringAsFixed(2)}?\n\nThis reserves the reviewed amount in your wallet. Funds stay reserved while an uncertain provider result is reconciled. Your installed eSIM and activation code stay the same.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm recharge'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      final result = await ref.read(esimMoneyActionsProvider).accept(quote);
      if (!mounted) return;
      setState(() {
        if (result.accepted) {
          _acceptedOrder = result.orderId;
          _notice =
              'Recharge request recorded. Review the receipt below for its verified outcome.';
        } else if (result.status != 'CANCELLED') {
          _notice = rechargeStatusMessage(result.status);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice =
              'Could not confirm the response. Check operation history before trying again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(authControllerProvider).value?.id;
    final profiles = ref.watch(userEsimsControllerProvider);
    final profile = profiles.value
        ?.where((p) => p.id == widget.profileId && p.userId == owner)
        .firstOrNull;
    // Loaded data from a previous account never authorizes profile or quote display.
    if (owner == null || profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recharge')),
        body: Center(
          child: Text(
            profiles.isLoading
                ? 'Loading your eSIM…'
                : 'This eSIM is unavailable for this account.',
          ),
        ),
      );
    }
    final discovery = ref.watch(
      esimRechargeDiscoveryProvider(widget.profileId),
    );
    final selected = _selection;
    ref.watch(esimMoneyActionsProvider);
    final history = ref.watch(esimOperationHistoryProvider(widget.profileId));
    final quote = selected == null
        ? null
        : ref.watch(esimRechargeQuoteProvider(selected));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recharge this eSIM'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh offers',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            profile.bundleName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Explore compatible recharge offers for this eSIM profile.',
          ),
          Text(
            quote?.value?.acceptanceEnabled == true
                ? 'Review a quote, then explicitly confirm a recharge for this same eSIM. Browsing and quotes do not charge your wallet.'
                : 'Preview only. Recharge payments are not enabled yet. Browsing and quotes do not charge your wallet.',
          ),
          const SizedBox(height: 16),
          discovery.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text(
              'Could not load recharge information. Please refresh.',
            ),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(data.message),
                if (data.status == 'PROFILE_REFRESH_REQUIRED' ||
                    data.status == 'CAPABILITY_UNVERIFIED')
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(userEsimsControllerProvider.notifier)
                          .refresh();
                      if (mounted) _refresh();
                    },
                    child: const Text('Refresh profile status'),
                  ),
                if (data.status == 'READY')
                  for (final offer in data.offers)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              offer.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${offer.allowanceLabel} • ${offer.durationLabel}',
                            ),
                            Text(offer.effectLabel),
                            Text(offer.behaviorLabel),
                            Text(
                              offer.dataType == 1
                                  ? 'USD ${offer.total.toStringAsFixed(2)} • wallet-funded total'
                                  : 'Choose days for a verified full total',
                            ),
                            const Text(
                              'Final allowance and expiry remain provisional until supplier confirmation.',
                            ),
                            if (offer.quoteSupported && data.version != null)
                              OutlinedButton(
                                onPressed: () => setState(
                                  () => _selection = (
                                    profileId: widget.profileId,
                                    packageId: offer.id,
                                    version: data.version!,
                                    total: offer.total,
                                  ),
                                ),
                                child: const Text('Preview quote'),
                              )
                            else if (offer.dataType >= 2 &&
                                data.version != null)
                              EsimDailyQuotePanel(
                                key: ValueKey('daily-${offer.id}'),
                                packageId: offer.id,
                                profileId: widget.profileId,
                                offerVersion: data.version,
                              ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
          if (quote != null)
            quote.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) =>
                  const Text('Could not load a quote. Please refresh.'),
              data: (q) {
                if (q.status != 'QUOTED') {
                  return Text(rechargeStatusMessage(q.status));
                }
                if (q.ownerId != owner ||
                    q.payerId != owner ||
                    q.profileId != profile.id) {
                  return const SizedBox.shrink();
                }
                if (q.expired) {
                  return const Text(
                    'This quote expired. Refresh and request a new quote.',
                  );
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Quote: USD ${q.offer!.total.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(q.balanceLabel),
                        if (q.availableBalance != null)
                          Text(
                            'Available: USD ${q.availableBalance!.toStringAsFixed(2)}',
                          ),
                        Text(
                          'Expires ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(q.expiresAt!.toLocal()))}',
                        ),
                        const Text(
                          'No additional wallet funding fee. This quote reserves no funds.',
                        ),
                        if (!q.acceptanceEnabled)
                          const Text(
                            'Payment is unavailable until recharge is enabled.',
                          )
                        else if (q.balanceState == 'sufficient' &&
                            _acceptedOrder == null)
                          FilledButton(
                            onPressed: _submitting
                                ? null
                                : () => _accept(q, profile.bundleName),
                            child: Text(
                              _submitting
                                  ? 'Confirming…'
                                  : 'Confirm recharge • USD ${q.offer!.total.toStringAsFixed(2)}',
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (_notice != null)
            Text(_notice!, key: const ValueKey('esim-recharge-notice')),
          const SizedBox(height: 16),
          Text(
            'Operation history',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          history.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text(
              'Could not load operation history. Refresh before submitting another request.',
            ),
            data: (rows) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rows.isEmpty)
                  const Text('No operations recorded for this profile.'),
                for (final row in rows)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('${row.label} • ${row.amountLabel}'),
                          Text(row.packageId),
                          if (row.durationDays != null)
                            Text('Selected duration: ${row.durationDays} days'),
                          SelectableText('Receipt ID: ${row.id}'),
                          Text(row.statusLabel),
                          Text(row.financialLabel),
                          if (row.confirmedExpiry != null)
                            Text(
                              'Confirmed expiry: ${MaterialLocalizations.of(context).formatMediumDate(row.confirmedExpiry!.toLocal())}',
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
