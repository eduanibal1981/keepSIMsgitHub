import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/esim_group_controller.dart';

class EsimGroupPanel extends ConsumerWidget {
  const EsimGroupPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(esimOrganizationProvider)
      .when(
        skipLoadingOnRefresh: false,
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(esimOrganizationProvider),
          child: const Text('Retry traveller labels & group orders'),
        ),
        data: (org) => org.batches.isEmpty
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Traveller group orders',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final batch in org.batches)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('${batch['group_label']} • ${batch['state']}'),
                            SelectableText('Group order ${batch['batch_id']}'),
                            Text(
                              'Reviewed total: USD ${batch['retail_total']}',
                            ),
                            for (final m in (batch['members'] as List? ?? []))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${m['traveller_label']} • ${m['delivery_state']}',
                                ),
                                subtitle: Text(
                                  'Separate eSIM • reserved USD ${m['reserved_amount']} • charged USD ${m['charged_amount']} • released USD ${m['released_amount']} • refunded USD ${m['refunded_amount']}${m['refund_pending'] == true ? ' • Refund pending' : ''}',
                                ),
                              ),
                            const Text(
                              'Partial delivery does not confirm missing profiles or release their reserved funds.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: () => ref.invalidate(esimOrganizationProvider),
                    child: const Text('Refresh group orders'),
                  ),
                ],
              ),
      );
}

class EsimLabelEditor extends ConsumerStatefulWidget {
  const EsimLabelEditor({
    super.key,
    required this.profileId,
    this.label = '',
    this.group = '',
  });
  final String profileId, label, group;
  static Future<void> show(
    BuildContext context,
    String id,
    Map<String, dynamic>? label,
  ) => showDialog<void>(
    context: context,
    builder: (_) => EsimLabelEditor(
      profileId: id,
      label: label?['traveller_label'] as String? ?? '',
      group: label?['group_label'] as String? ?? '',
    ),
  );
  @override
  ConsumerState<EsimLabelEditor> createState() => _EsimLabelEditorState();
}

class _EsimLabelEditorState extends ConsumerState<EsimLabelEditor> {
  late final _label = TextEditingController(text: widget.label),
      _group = TextEditingController(text: widget.group);
  bool busy = false;
  String? notice;
  String? _sessionOwner;
  @override
  void dispose() {
    _label.dispose();
    _group.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider), owner = auth.value?.id;
    if (_sessionOwner == null &&
        owner != null &&
        !auth.isLoading &&
        !auth.hasError) {
      _sessionOwner = owner;
    }
    if (auth.isLoading ||
        auth.hasError ||
        owner == null ||
        owner != _sessionOwner) {
      return AlertDialog(
        title: const Text('Session changed'),
        content: const Text('Sign in again to edit traveller labels.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }
    ref.watch(esimGroupActionsProvider);
    return AlertDialog(
      title: const Text('Private traveller labels'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Labels organize separate profiles in your account. They do not transfer ownership or share data.',
          ),
          TextField(
            controller: _label,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Traveller'),
          ),
          TextField(
            controller: _group,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Group'),
          ),
          if (notice != null) Text(notice!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    final r = await ref
                        .read(esimGroupActionsProvider)
                        .label(widget.profileId, _label.text, _group.text);
                    if (!context.mounted) {
                      return;
                    }
                    if (r == 'SAVED') {
                      Navigator.pop(context);
                    } else {
                      setState(
                        () => notice = r.replaceAll('_', ' ').toLowerCase(),
                      );
                    }
                  } catch (_) {
                    if (mounted) {
                      setState(() => notice = 'Could not save labels.');
                    }
                  } finally {
                    if (mounted) {
                      setState(() => busy = false);
                    }
                  }
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
