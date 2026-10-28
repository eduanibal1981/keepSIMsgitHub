import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/esim_controls.dart';
import '../controllers/esim_controls_controller.dart';
import '../controllers/esim_recharge_controller.dart';

class EsimControlsScreen extends ConsumerStatefulWidget {
  const EsimControlsScreen({super.key, required this.profileId});
  final String profileId;
  static Future<void> show(BuildContext context, String id) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: .94,
          child: EsimControlsScreen(profileId: id),
        ),
      );
  @override
  ConsumerState<EsimControlsScreen> createState() => _EsimControlsScreenState();
}

class _EsimControlsScreenState extends ConsumerState<EsimControlsScreen> {
  final _max = TextEditingController(),
      _cap = TextEditingController(),
      _threshold = TextEditingController(text: '20'),
      _hours = TextEditingController(text: '6'),
      _days = TextEditingController(text: '7'),
      _end = TextEditingController();
  String? _package;
  bool _daily = false, _busy = false;
  @override
  void dispose() {
    for (final c in [_max, _cap, _threshold, _hours, _days, _end]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(
    EsimControlSnapshot s, {
    String? action,
    bool? enable,
    EsimAutomationSettings? settings,
  }) async {
    if (_busy) return;
    if (action != null || enable == true) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            enable == true ? 'Authorize automatic recharge' : 'Confirm $action',
          ),
          content: Text(
            enable == true
                ? 'Package: ${settings!.packageId}\nMaximum: USD ${(settings.maxCents / 100).toStringAsFixed(2)} per recharge\nMonthly cap: USD ${(settings.monthlyCents / 100).toStringAsFixed(2)} (UTC calendar month)\nTrigger: ${settings.daily ? '${settings.threshold} hours before expiry; adds ${settings.days} days' : '${settings.threshold}% reported data remaining'}\nMinimum interval: ${settings.intervalHours} hours\nEnds: ${settings.endsAt?.toLocal() ?? 'Until paused'}\nExisting pending charges count toward your cap.'
                : action == 'cancel'
                ? 'Cancel this unused profile. The displayed refunds go to each original payer’s wallet once cancellation and supplier credit are verified. A pending refund is not a completed credit.'
                : 'This changes data service. Validity may continue to run. Automatic recharge will be paused.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(esimControlsActionsProvider(widget.profileId))
          .run(s, action: action, enableAutomation: enable, settings: settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.replaceAll('_', ' ').toLowerCase())),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to confirm the outcome. Refresh before retrying.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget field(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(esimControlsProvider(widget.profileId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('eSIM controls'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.invalidate(esimControlsProvider(widget.profileId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: snapshot.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('Profile unavailable. Sign in again or refresh.'),
        ),
        data: (s) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Service: ${s.controls['profile_state'] ?? 'Unknown'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Suspension stops data service. Validity may continue to run.',
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: !_busy && s.suspendEnabled
                      ? () => _run(s, action: 'suspend')
                      : null,
                  child: const Text('Suspend data service'),
                ),
                OutlinedButton(
                  onPressed: !_busy && s.resumeEnabled
                      ? () => _run(s, action: 'resume')
                      : null,
                  child: const Text('Resume data service'),
                ),
              ],
            ),
            const Divider(),
            const Text('Unused eSIM cancellation'),
            Text(s.cancellationReason.replaceAll('_', ' ').toLowerCase()),
            for (final r in s.refunds)
              Text(
                'USD ${r['amount']} → original payer ${r['payer_id']} wallet',
              ),
            FilledButton(
              onPressed: !_busy && s.cancellationEnabled
                  ? () => _run(s, action: 'cancel')
                  : null,
              child: const Text('Review cancellation & refund'),
            ),
            for (final op in s.operations)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${op['action']}: ${op['state']}'),
                subtitle: Text('${op['error_code'] ?? 'Recorded operation'}'),
              ),
            const Divider(),
            const Text('Automatic recharge'),
            Text(
              s.autoEnabled
                  ? 'Enabled for ${s.consent?['package_id']}'
                  : 'Paused',
            ),
            Text(
              'Cap exposure: USD ${s.automation['exposure'] ?? 'Unknown'} • UTC calendar month',
            ),
            if (s.consent?['stop_reason'] != null)
              Text('Paused: ${s.consent!['stop_reason']}'),
            const Text(
              'Pausing stops future submissions. An already submitted recharge remains pending until its outcome is verified.',
            ),
            OutlinedButton(
              onPressed: !_busy && s.autoEnabled
                  ? () => _run(s, enable: false)
                  : null,
              child: const Text('Pause automatic recharge'),
            ),
            if (!s.autoAvailable)
              const Text('Automatic recharge is currently unavailable.'),
            if (s.autoAvailable) ...[
              ref
                  .watch(esimRechargeDiscoveryProvider(widget.profileId))
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) =>
                        const Text('Compatible packages unavailable.'),
                    data: (d) => DropdownButtonFormField<String>(
                      initialValue: _package,
                      decoration: const InputDecoration(
                        labelText: 'Exact compatible package',
                      ),
                      items: d.offers
                          .map(
                            (o) => DropdownMenuItem(
                              value: o.id,
                              child: Text(
                                o.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        final o = d.offers.firstWhere((o) => o.id == id);
                        setState(() {
                          _package = id;
                          _daily = o.dataType != 1;
                          _threshold.text = _daily ? '24' : '20';
                        });
                      },
                    ),
                  ),
              field(_max, 'Maximum USD per recharge'),
              field(_cap, 'Monthly USD cap'),
              field(
                _threshold,
                _daily
                    ? 'Hours before expiry (1–168)'
                    : 'Remaining reported data % (1–50)',
              ),
              field(_hours, 'Minimum hours between recharges (1–720)'),
              if (_daily) ...[
                field(_days, 'Extension days (1–365)'),
                const Text(
                  'An extension adds days. It does not restore today’s speed or allowance.',
                ),
              ],
              TextField(
                controller: _end,
                decoration: const InputDecoration(
                  labelText: 'Optional end date (YYYY-MM-DD, local midnight)',
                ),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        final max = EsimAutomationSettings.parseCents(
                              _max.text,
                            ),
                            cap = EsimAutomationSettings.parseCents(_cap.text);
                        final settings = EsimAutomationSettings(
                          packageId: _package ?? '',
                          daily: _daily,
                          maxCents: max ?? 0,
                          monthlyCents: cap ?? 0,
                          threshold: int.tryParse(_threshold.text) ?? 0,
                          intervalHours: int.tryParse(_hours.text) ?? 0,
                          days: _daily ? int.tryParse(_days.text) : null,
                          endsAt: _end.text.isEmpty
                              ? null
                              : EsimAutomationSettings.parseLocalEnd(_end.text),
                        );
                        if (!settings.valid ||
                            (_end.text.isNotEmpty && settings.endsAt == null)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Check your package, limits and end date.',
                              ),
                            ),
                          );
                          return;
                        }
                        _run(s, enable: true, settings: settings);
                      },
                child: const Text('Review & enable automatic recharge'),
              ),
            ],
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
