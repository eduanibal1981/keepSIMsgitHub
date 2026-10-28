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
    setState(() => _selection = null);
    ref.invalidate(esimRechargeDiscoveryProvider(widget.profileId));
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
            'Explore compatible recharge offers for this installed profile.',
          ),
          const Text(
            'Preview only. Recharge payments are not enabled yet. Browsing and quotes do not charge your wallet.',
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
                              'USD ${offer.total.toStringAsFixed(2)} • wallet-funded total',
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
                            else
                              const Text(
                                'Daily-extension quotes will be available later.',
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
                        const Text(
                          'Payment is unavailable until recharge is enabled.',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
