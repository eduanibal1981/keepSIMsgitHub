/// Where eSIM offers come from.
///
/// Displays connected eSIM suppliers (eSIM Access, Zendit, eSIM Go, DTOne),
/// active status, live inventory counts, wholesale rate comparisons, sync telemetry,
/// and catalogue synchronization triggers.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:keep_sims_admin/core/admin/admin_providers.dart';
import 'package:keep_sims_admin/core/admin/admin_widgets.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  bool _syncingAll = false;

  Future<void> _syncAllCatalogues() async {
    setState(() => _syncingAll = true);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      final res = await ref.read(adminApiProvider).syncEsimCatalogue(
        note: 'manual catalogue sync triggered from eSIM sources screen',
      );
      ref.invalidate(esimSuppliersProvider);
      ref.invalidate(overviewProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            res['success'] == true
                ? 'Catalogue sync queued across all active suppliers. Watch sync status below.'
                : 'Catalogue sync request sent.',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Catalogue sync failed: $e'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(esimSuppliersProvider);
    final diagnostics = ref.watch(esimCatalogueDiagnosticsProvider);
    final esimRuntime = ref.watch(esimRuntimeStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('eSIM sources'),
        actions: [
          FilledButton.tonalIcon(
            onPressed: _syncingAll ? null : _syncAllCatalogues,
            icon: _syncingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 18),
            label: const Text('Sync all sources'),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh screen',
            onPressed: () {
              ref.invalidate(esimSuppliersProvider);
              ref.invalidate(esimCatalogueDiagnosticsProvider);
              ref.invalidate(esimRuntimeStatusProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add source'),
      ),
      body: AsyncPanel<List<Map<String, dynamic>>>(
        value: suppliers,
        onRetry: () => ref.invalidate(esimSuppliersProvider),
        builder: (rows) {
          final activeRows = rows.where((r) => r['is_active'] == true).toList();
          final totalOffers = activeRows.fold<int>(
            0,
            (acc, r) => acc + ((r['live_offers'] as num?)?.toInt() ?? 0),
          );

          final countrySet = <String>{};
          for (final r in activeRows) {
            final list = r['countries_supported'] as List?;
            if (list != null) {
              for (final c in list) {
                if (c != null) countrySet.add(c.toString());
              }
            }
          }

          num? lowestGbRate;
          for (final r in activeRows) {
            final rate = r['cheapest_usd_per_gb'] as num?;
            if (rate != null) {
              if (lowestGbRate == null || rate < lowestGbRate) {
                lowestGbRate = rate;
              }
            }
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SuppliersSummaryHeader(
                activeCount: activeRows.length,
                totalCount: rows.length,
                totalBundles: totalOffers,
                uniqueCountries: countrySet.length,
                cheapestGbRate: lowestGbRate,
                onSyncAll: _syncingAll ? null : _syncAllCatalogues,
                isSyncing: _syncingAll,
              ),
              const SizedBox(height: 16),
              diagnostics.when(
                data: (d) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'eSIM Access catalogue facts: ${d['enriched_offers']} / ${d['active_offers']} enriched\n'
                      'Unknown type: ${d['unknown_type']} · Activation: ${d['unknown_activation']} · Recharge: ${d['unknown_recharge']}\n'
                      'Last checked: ${d['last_observed_at'] ?? 'Not provided'}',
                    ),
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) =>
                    const Text('Catalogue fact diagnostics unavailable'),
              ),
              esimRuntime.when(
                data: (status) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'eSIM delivery safeguards\nNew sales: ${status['new_sales_enabled'] == true ? 'Enabled' : 'Gated'}\n'
                      'Orders: ${status['orders']}\nEvents: ${status['events']}\n'
                      'Worker checked: ${status['last_worker_seen_at'] ?? 'Not provided'}',
                    ),
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('eSIM recovery status unavailable'),
              ),
              for (final s in rows) _SupplierCard(supplier: s),
            ],
          );
        },
      ),
    );
  }
}

class _SuppliersSummaryHeader extends StatelessWidget {
  const _SuppliersSummaryHeader({
    required this.activeCount,
    required this.totalCount,
    required this.totalBundles,
    required this.uniqueCountries,
    required this.cheapestGbRate,
    required this.onSyncAll,
    required this.isSyncing,
  });

  final int activeCount;
  final int totalCount;
  final int totalBundles;
  final int uniqueCountries;
  final num? cheapestGbRate;
  final VoidCallback? onSyncAll;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hub_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Multi-Provider eSIM Infrastructure',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$activeCount / $totalCount Active',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(
                label: 'Total live inventory',
                value: '$totalBundles',
                hint: 'across active sources',
                tone: totalBundles > 0 ? StatTone.good : StatTone.warn,
              ),
              StatTile(
                label: 'Global country reach',
                value: '$uniqueCountries',
                hint: 'unique destinations',
                tone: uniqueCountries > 0 ? StatTone.good : StatTone.neutral,
              ),
              if (cheapestGbRate != null)
                StatTile(
                  label: 'Lowest wholesale rate',
                  value: '\$$cheapestGbRate',
                  hint: 'per GB benchmark',
                  tone: StatTone.good,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showEditor(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic>? existing,
) {
  showDialog<void>(
    context: context,
    builder: (_) => _SupplierDialog(existing: existing),
  );
}

class _SupplierCard extends ConsumerStatefulWidget {
  const _SupplierCard({required this.supplier});
  final Map<String, dynamic> supplier;

  @override
  ConsumerState<_SupplierCard> createState() => _SupplierCardState();
}

class _SupplierCardState extends ConsumerState<_SupplierCard> {
  bool _busy = false;

  Map<String, dynamic> get s => widget.supplier;

  Color _getProviderColor(String code) {
    switch (code.toLowerCase()) {
      case 'esimaccess':
        return Colors.teal;
      case 'zendit':
        return Colors.deepPurple;
      case 'esim_go':
        return Colors.blue;
      case 'dtone':
        return Colors.orange;
      default:
        return Colors.cyan;
    }
  }

  IconData _getProviderIcon(String code) {
    switch (code.toLowerCase()) {
      case 'esimaccess':
        return Icons.language;
      case 'zendit':
        return Icons.bolt_outlined;
      case 'esim_go':
        return Icons.public_outlined;
      case 'dtone':
        return Icons.phone_android_outlined;
      default:
        return Icons.cloud_download_outlined;
    }
  }

  List<String> _getProviderCapabilities(String code) {
    switch (code.toLowerCase()) {
      case 'esimaccess':
        return const [
          'Fixed Allowance',
          'Unlimited & FUP',
          'Multi-Country / GCC',
          'Direct LPA Allocation',
          'Real-time Usage API',
        ];
      case 'zendit':
        return const [
          'Fixed Data',
          'Multi-Bandwidth Subtypes',
          'Instant eSIM & Airtime',
        ];
      case 'esim_go':
        return const [
          'Standard Fixed',
          'Unlimited Tiers',
          'Long Duration Plans',
          '220+ Countries',
        ];
      case 'dtone':
        return const [
          'Global Airtime & Data Rail',
          'Telco Bundles',
        ];
      default:
        return const ['eSIM Catalogue API'];
    }
  }

  void _showCountriesDialog(BuildContext context, List countries) {
    final list = countries.map((e) => e.toString().toUpperCase()).toList()..sort();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${s['name']} — ${list.length} Supported Countries'),
        content: SizedBox(
          width: 500,
          height: 380,
          child: list.isEmpty
              ? const Center(child: Text('No country coverage data recorded yet.'))
              : SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in list)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            c,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor:
                              Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        ),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = s['is_active'] == true;
    final offers = (s['live_offers'] as num?)?.toInt() ?? 0;
    final countries = (s['countries_supported'] as List?) ?? const [];
    final override = s['markup_percent_override'];
    final providerCode = '${s['code']}'.toLowerCase();
    final brandColor = _getProviderColor(providerCode);
    final capabilities = _getProviderCapabilities(providerCode);

    return AdminCard(
      title: '${s['name']}',
      subtitle:
          '${s['code']} · priority ${s['priority']} · '
          '${override == null ? 'default markup ${s['effective_markup_percent']}%' : 'markup override $override%'}',
      icon: _getProviderIcon(providerCode),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Edit supplier details',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditor(context, ref, s),
          ),
          Switch(
            value: active,
            onChanged: _busy
                ? null
                : (v) async {
                    setState(() => _busy = true);
                    await runAdminAction(
                      context,
                      ref,
                      action: () => ref
                          .read(adminApiProvider)
                          .upsertEsimSupplier('${s['code']}', {
                            'is_active': v,
                          }),
                      success:
                          '${s['name']} ${v ? 'activated' : 'deactivated'}',
                      refresh: () {
                        ref.invalidate(esimSuppliersProvider);
                        ref.invalidate(overviewProvider);
                      },
                    );
                    if (mounted) setState(() => _busy = false);
                  },
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (active && offers == 0)
            const ProblemBanner(
              severe: true,
              message:
                  'Active but holding no offers in cache. Trigger a sync to pull inventory.',
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(
                label: 'Live bundles',
                value: '$offers',
                tone: offers > 0 ? StatTone.good : StatTone.warn,
              ),
              InkWell(
                onTap: countries.isNotEmpty
                    ? () => _showCountriesDialog(context, countries)
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: StatTile(
                  label: 'Countries listed',
                  value: '${countries.length}',
                  hint: countries.isNotEmpty ? 'tap to view all' : null,
                  tone: StatTone.neutral,
                ),
              ),
              StatTile(
                label: 'Last sync',
                value: '${s['last_sync_status'] ?? '—'}',
                hint: s['last_sync_count'] != null
                    ? '${s['last_sync_count']} offers · ${_formatTimestamp(s['last_sync_at'])}'
                    : _formatTimestamp(s['last_sync_at']),
                tone: s['last_sync_status'] == 'ok'
                    ? StatTone.good
                    : StatTone.warn,
              ),
              if (s['cheapest_usd_per_gb'] != null)
                StatTile(
                  label: 'Cheapest',
                  value: '\$${s['cheapest_usd_per_gb']}',
                  hint: 'wholesale / GB',
                  tone: StatTone.good,
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Capability chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final cap in capabilities)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: brandColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    cap,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: brandColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _link(context, 'Website', s['website_url']),
          _link(context, 'API base', s['api_base_url']),
          _link(context, 'Docs', s['docs_url']),
          _secretRow(context, 'Credential secret', s['credential_secret'] ?? '—'),
          if (s['last_sync_error'] != null)
            _row(context, 'Last error', '${s['last_sync_error']}'),
          if (s['notes'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${s['notes']}', style: theme.textTheme.bodySmall),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(Object? raw) {
    if (raw == null) return 'never';
    final str = raw.toString();
    return str.split('.').first.replaceAll('T', ' ');
  }

  Widget _row(BuildContext context, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(k, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: SelectableText(v)),
      ],
    ),
  );

  Widget _secretRow(BuildContext context, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(k, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Row(
            children: [
              SelectableText(
                v,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
              ),
              if (v != '—') ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: v));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied secret name "$v" to clipboard'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.copy, size: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _link(BuildContext context, String k, Object? url) {
    if (url == null) return _row(context, k, '—');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: InkWell(
              onTap: () => launchUrl(Uri.parse('$url')),
              child: Text(
                '$url',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierDialog extends ConsumerStatefulWidget {
  const _SupplierDialog({this.existing});
  final Map<String, dynamic>? existing;

  @override
  ConsumerState<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends ConsumerState<_SupplierDialog> {
  late final _code = TextEditingController(
    text: '${widget.existing?['code'] ?? ''}',
  );
  late final _name = TextEditingController(
    text: '${widget.existing?['name'] ?? ''}',
  );
  late final _site = TextEditingController(
    text: '${widget.existing?['website_url'] ?? ''}',
  );
  late final _api = TextEditingController(
    text: '${widget.existing?['api_base_url'] ?? ''}',
  );
  late final _docs = TextEditingController(
    text: '${widget.existing?['docs_url'] ?? ''}',
  );
  late final _secret = TextEditingController(
    text: '${widget.existing?['credential_secret'] ?? ''}',
  );
  late final _priority = TextEditingController(
    text: '${widget.existing?['priority'] ?? 100}',
  );
  late final _markup = TextEditingController(
    text: '${widget.existing?['markup_percent_override'] ?? ''}',
  );
  late final _notes = TextEditingController(
    text: '${widget.existing?['notes'] ?? ''}',
  );
  bool _busy = false;

  bool get _isNew => widget.existing == null;

  void _applyPreset(String preset) {
    switch (preset) {
      case 'esimaccess':
        _code.text = 'esimaccess';
        _name.text = 'eSIM Access';
        _site.text = 'https://www.esimaccess.com';
        _api.text = 'https://api.esimaccess.com/api/v1/open';
        _docs.text = 'https://docs.esimaccess.com';
        _secret.text = 'ESIM_ACCESS_ACCESS_CODE';
        _priority.text = '15';
        _markup.text = '30';
        _notes.text =
            'Supports global eSIM packages with fixed volume, daily FUP tiers, direct profile ordering, and real-time usage query.';
        break;
      case 'zendit':
        _code.text = 'zendit';
        _name.text = 'Zendit';
        _site.text = 'https://www.zendit.io';
        _api.text = 'https://api.zendit.io/v1';
        _docs.text = 'https://docs.zendit.io';
        _secret.text = 'ZENDIT_API_SECRET';
        _priority.text = '20';
        _markup.text = '30';
        _notes.text =
            'Live for airtime top-ups and eSIM packages with multi-subtype bandwidth tiers.';
        break;
      case 'esim_go':
        _code.text = 'esim_go';
        _name.text = 'eSIM Go';
        _site.text = 'https://www.esim-go.com';
        _api.text = 'https://api.esim-go.com/v2.4';
        _docs.text = 'https://docs.esim-go.com';
        _secret.text = 'ESIM_GO_API_KEY';
        _priority.text = '10';
        _markup.text = '30';
        _notes.text =
            'Holds standard fixed, unlimited lite/essential/plus, and long duration packages.';
        break;
      case 'dtone':
        _code.text = 'dtone';
        _name.text = 'DTOne';
        _site.text = 'https://www.dtone.com';
        _api.text = 'https://api.dtone.com/v1';
        _docs.text = 'https://docs.dtone.com';
        _secret.text = 'DTONE_API_KEY';
        _priority.text = '30';
        _markup.text = '30';
        _notes.text = 'Global top-up and mobile data rail provider.';
        break;
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      _code,
      _name,
      _site,
      _api,
      _docs,
      _secret,
      _priority,
      _markup,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'Add eSIM source' : 'Edit ${widget.existing!['name']}'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isNew) ...[
                Text(
                  'Quick Presets:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.language, size: 16, color: Colors.teal),
                      label: const Text('eSIM Access (Recommended)'),
                      onPressed: () => _applyPreset('esimaccess'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.bolt, size: 16, color: Colors.deepPurple),
                      label: const Text('Zendit'),
                      onPressed: () => _applyPreset('zendit'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.public, size: 16, color: Colors.blue),
                      label: const Text('eSIM Go'),
                      onPressed: () => _applyPreset('esim_go'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.phone_android, size: 16, color: Colors.orange),
                      label: const Text('DTOne'),
                      onPressed: () => _applyPreset('dtone'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
              ],
              TextField(
                controller: _code,
                enabled: _isNew,
                decoration: const InputDecoration(
                  labelText: 'Code',
                  helperText: 'lower-case letters, digits, underscore (e.g. esimaccess)',
                ),
              ),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _site,
                decoration: const InputDecoration(
                  labelText: 'Website',
                  hintText: 'https://…',
                ),
              ),
              TextField(
                controller: _api,
                decoration: const InputDecoration(
                  labelText: 'API base URL',
                  hintText: 'https://…',
                ),
              ),
              TextField(
                controller: _docs,
                decoration: const InputDecoration(
                  labelText: 'Docs URL',
                  hintText: 'https://…',
                ),
              ),
              TextField(
                controller: _secret,
                decoration: const InputDecoration(
                  labelText: 'Credential secret name',
                  helperText:
                      'The vault secret name holding credentials (e.g. ESIM_ACCESS_ACCESS_CODE)',
                ),
              ),
              TextField(
                controller: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  helperText: 'lower is preferred in comparison rankings',
                ),
              ),
              TextField(
                controller: _markup,
                decoration: const InputDecoration(
                  labelText: 'Markup override (%)',
                  helperText: 'blank uses default system markup',
                ),
              ),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_isNew ? 'Add source' : 'Save changes'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final patch = <String, dynamic>{
      'name': _name.text.trim(),
      'website_url': _site.text.trim(),
      'api_base_url': _api.text.trim(),
      'docs_url': _docs.text.trim(),
      'credential_secret': _secret.text.trim(),
      'priority': _priority.text.trim(),
      'markup_percent_override': _markup.text.trim(),
      'notes': _notes.text.trim(),
    };
    final ok = await runAdminAction(
      context,
      ref,
      action: () => ref
          .read(adminApiProvider)
          .upsertEsimSupplier(_code.text.trim(), patch),
      success: _isNew
          ? '${_name.text} added — inactive until you switch it on'
          : '${_name.text} saved',
      refresh: () => ref.invalidate(esimSuppliersProvider),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }
}
