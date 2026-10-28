import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims_admin/core/admin/admin_widgets.dart';
import 'package:keep_sims_admin/features/auth/controller/auth_controller.dart';
import '../../providers/esim_support_provider.dart';

class EsimSupportPanel extends ConsumerStatefulWidget {
  const EsimSupportPanel({super.key});
  @override
  ConsumerState<EsimSupportPanel> createState() => _EsimSupportPanelState();
}

class _EsimSupportPanelState extends ConsumerState<EsimSupportPanel> {
  final _query = TextEditingController(), _reason = TextEditingController();
  String _search = '';
  bool _busy = false;
  @override
  void dispose() {
    _query.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (_busy || _reason.text.trim().length < 8) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action unavailable or permission denied.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider), owner = auth.value?.id;
    final data = owner != null && !auth.isLoading && !auth.hasError
        ? ref.watch(esimSupportProvider((owner: owner, query: _search)))
        : null;
    return AdminCard(
      title: 'eSIM support',
      icon: Icons.sim_card_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Search by profile ID, owner ID or final four ICCID digits. Leave blank for unresolved work. Credentials and full ICCIDs are excluded.',
          ),
          TextField(
            controller: _query,
            decoration: const InputDecoration(
              labelText: 'Profile / owner ID / last four digits',
            ),
          ),
          OutlinedButton(
            onPressed: () => setState(() => _search = _query.text.trim()),
            child: const Text('Search eSIM profiles'),
          ),
          TextField(
            controller: _reason,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Support reason (8–500 characters)',
            ),
            maxLength: 500,
          ),
          if (data != null)
            data.when(
              skipLoadingOnRefresh: false,
              loading: () => const LinearProgressIndicator(),
              error: (_, _) =>
                  const Text('Support data unavailable or access denied.'),
              data: (result) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Account funding: ${result['funding_health']} • Credentials: ${result['credential_health']}',
                  ),
                  Text(
                    'Catalogue observed: ${result['catalogue_last_sync'] ?? 'Unknown'}',
                  ),
                  Text('Runtime: ${result['runtime']}'),
                  for (final row in (result['profiles'] as List? ?? []))
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SelectableText(
                              'Profile ${row['id']} • ICCID …${row['iccid_suffix']}',
                            ),
                            Text(
                              '${row['profile_state']} / ${row['installation_state']} / ${row['bundle_state']}',
                            ),
                            Text(
                              'Last observation: ${row['last_observation_at'] ?? 'Unknown'} • Usage: ${row['usage_observed_at'] ?? 'Unknown'}',
                            ),
                            Text('Controls: ${row['controls']}'),
                            Text('Operations: ${row['operations']}'),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final action in [
                                  'refresh',
                                  'reconcile',
                                  'escalate',
                                ])
                                  OutlinedButton(
                                    onPressed:
                                        !_busy &&
                                            _reason.text.trim().length >= 8
                                        ? () => run(
                                            () => ref
                                                .read(
                                                  esimSupportActionsProvider,
                                                )
                                                .run(
                                                  '${row['id']}',
                                                  action,
                                                  _reason.text.trim(),
                                                ),
                                          )
                                        : null,
                                    child: Text(action),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Text(
                    'Pause new actions; submitted work continues read-only reconciliation.',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final cap in [
                        'cancel',
                        'service_controls',
                        'automation',
                      ])
                        OutlinedButton(
                          onPressed: !_busy && _reason.text.trim().length >= 8
                              ? () => run(
                                  () => ref
                                      .read(esimSupportActionsProvider)
                                      .pause(cap, _reason.text.trim()),
                                )
                              : null,
                          child: Text('Pause $cap'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
