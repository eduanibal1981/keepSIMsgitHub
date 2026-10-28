import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims_admin/core/admin/admin_widgets.dart';
import 'package:keep_sims_admin/features/auth/controller/auth_controller.dart';
import 'package:keep_sims_admin/features/control/providers/esim_operation_provider.dart';

class EsimOperationInspector extends ConsumerStatefulWidget {
  const EsimOperationInspector({super.key});
  @override
  ConsumerState<EsimOperationInspector> createState() =>
      _EsimOperationInspectorState();
}

class _EsimOperationInspectorState
    extends ConsumerState<EsimOperationInspector> {
  final _input = TextEditingController();
  String? _id;
  bool get valid => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(_input.text.trim());
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider), owner = auth.value?.id;
    final permitted = owner != null && !auth.isLoading && !auth.hasError;
    final result = permitted && _id != null
        ? ref.watch(
            esimOperationTimelineProvider((owner: owner, orderId: _id!)),
          )
        : null;
    return AdminCard(
      title: 'eSIM operation timeline',
      icon: Icons.receipt_long_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Inspect submission, reservation and settlement evidence. Unknown provider outcomes require reconciliation; they do not authorize another purchase or a refund.',
          ),
          TextField(
            controller: _input,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'eSIM order ID'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: permitted && valid
                ? () => setState(() => _id = _input.text.trim())
                : null,
            child: const Text('Inspect operation'),
          ),
          if (!permitted)
            const Text(
              'Sign in with support permissions to inspect an operation.',
            ),
          if (result != null)
            result.when(
              skipLoadingOnRefresh: false,
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text(
                'Operation unavailable or access denied. Check the order ID and support permissions.',
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final field in [
                    'kind',
                    'status',
                    'delivery_state',
                    'finance_kind',
                    'settlement_state',
                    'submitted_at',
                    'receipt_at',
                    'error_code',
                    'attempts',
                    'next_check_at',
                  ])
                    Text(
                      '${field.replaceAll('_', ' ')}: ${data[field] ?? 'Not recorded'}',
                    ),
                  Text(
                    'Reservation linked: ${data['has_hold'] == true ? 'Yes' : 'No'}',
                  ),
                  Text(
                    'Settlement recorded: ${data['has_settlement'] == true ? 'Yes' : 'No'}',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
