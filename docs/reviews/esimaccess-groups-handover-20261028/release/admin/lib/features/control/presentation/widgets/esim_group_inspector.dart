import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims_admin/core/admin/admin_widgets.dart';
import 'package:keep_sims_admin/features/auth/controller/auth_controller.dart';
import '../../providers/esim_group_provider.dart';

class EsimGroupInspector extends ConsumerStatefulWidget {
  const EsimGroupInspector({super.key});
  @override
  ConsumerState<EsimGroupInspector> createState() => _EsimGroupInspectorState();
}

class _EsimGroupInspectorState extends ConsumerState<EsimGroupInspector> {
  final _input = TextEditingController(), _reason = TextEditingController();
  bool busy = false;
  String? notice;
  String? _id;
  @override
  void dispose() {
    _input.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider), owner = auth.value?.id;
    final valid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(_input.text.trim());
    final permitted = owner != null && !auth.isLoading && !auth.hasError;
    final result = permitted && _id != null
        ? ref.watch(esimGroupTimelineProvider((owner: owner, groupId: _id!)))
        : null;
    return AdminCard(
      title: 'eSIM group order',
      icon: Icons.groups_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Inspect each child order and its original payer settlement. Traveller labels and activation details remain private. Unresolved members are not permission to reissue or refund.',
          ),
          TextField(
            controller: _input,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Group order ID'),
          ),
          OutlinedButton(
            onPressed: permitted && valid
                ? () => setState(() => _id = _input.text.trim())
                : null,
            child: const Text('Inspect group order'),
          ),
          TextField(
            controller: _reason,
            onChanged: (_) => setState(() {}),
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Reason to pause new group orders',
            ),
          ),
          OutlinedButton(
            onPressed: permitted && !busy && _reason.text.trim().length >= 8
                ? () async {
                    setState(() => busy = true);
                    try {
                      await ref
                          .read(esimGroupActionsProvider)
                          .pause(_reason.text.trim());
                      if (mounted) {
                        setState(
                          () => notice =
                              'New group orders paused; submitted children continue reconciliation.',
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => notice = 'Pause unavailable or access denied.',
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => busy = false);
                      }
                    }
                  }
                : null,
            child: const Text('Pause new group orders'),
          ),
          if (notice != null) Text(notice!),
          if (result != null)
            result.when(
              skipLoadingOnRefresh: false,
              loading: () => const LinearProgressIndicator(),
              error: (_, _) =>
                  const Text('Group unavailable or access denied.'),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('State: ${data['state'] ?? data['status']}'),
                  Text(
                    'Original payer: ${data['payer_id'] ?? 'Unknown'} • Total USD ${data['retail_total'] ?? 'Unknown'}',
                  ),
                  for (final m in data['members'] as List? ?? [])
                    SelectableText(
                      'Member ${m['member_index']} • Order ${m['order_id']}\n${m['delivery_state']} / ${m['settlement_state']}\nReserved ${m['reserved_amount']} • Charged ${m['charged_amount']} • Released ${m['released_amount']} • Refunded ${m['refunded_amount']} • Refund pending ${m['refund_pending']}',
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
