/// The operations home: one call to `admin_overview()`, answering "is the
/// product working right now".
///
/// Every figure is a live count. Nothing here reads `wallets.total_deposited` or
/// `total_spent` — those are 0.00 for six of eight users who have real deposits
/// in the ledger, because only `credit_wallet_for_deposit` increments them and
/// most credits never went through it. A dashboard quoting them would be
/// confidently wrong.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keep_sims_admin/core/admin/admin_providers.dart';
import 'package:keep_sims_admin/core/admin/admin_widgets.dart';
import 'widgets/esim_operation_inspector.dart';
import 'package:keep_sims_admin/core/router/app_router.dart';

class OperationsScreen extends ConsumerWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider);
    final dispatchHealth = ref.watch(notificationDispatchHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(overviewProvider);
              ref.invalidate(notificationDispatchHealthProvider);
            },
          ),
        ],
      ),
      body: AsyncPanel<Map<String, dynamic>>(
        value: overview,
        onRetry: () => ref.invalidate(overviewProvider),
        builder: (d) => _Body(data: d, dispatchHealth: dispatchHealth),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data, required this.dispatchHealth});

  final Map<String, dynamic> data;
  final AsyncValue<Map<String, dynamic>> dispatchHealth;

  Map<String, dynamic> _m(String k) =>
      (data[k] as Map?)?.cast<String, dynamic>() ?? const {};

  String _n(Map<String, dynamic> m, String k) => '${m[k] ?? 0}';

  String _money(Map<String, dynamic> m, String k) {
    final v = num.tryParse('${m[k] ?? 0}') ?? 0;
    return '\$${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final users = _m('users');
    final money = _m('money');
    final queue = _m('queue');
    final routing = _m('routing');
    final catalogue = _m('catalogue');
    final notif = _m('notifications');
    final support = _m('support');
    final workers = _m('workers');
    final alerts = (data['alerts'] as List?) ?? const [];

    final stuck = int.tryParse(_n(queue, 'stuck_24h')) ?? 0;
    final inFlight = int.tryParse(_n(queue, 'in_flight')) ?? 0;
    final noProvider = int.tryParse(_n(routing, 'api_without_provider')) ?? 0;
    final noOffers = int.tryParse(_n(routing, 'carriers_without_offers')) ?? 0;
    final gaps = (notif['credential_gaps'] as List?) ?? const [];
    final esimCovered =
        int.tryParse(_n(catalogue, 'esim_covered_countries')) ?? 0;
    final esimTotal = int.tryParse(_n(catalogue, 'supported_countries')) ?? 0;
    final awaiting = int.tryParse(_n(support, 'awaiting_reply')) ?? 0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Problems first. A dashboard that makes you hunt for the bad number is
        // a dashboard nobody checks.
        if (stuck > 0)
          ProblemBanner(
            severe: true,
            message:
                '$stuck of $inFlight queued refills have been in flight for over 24 hours. '
                'Check the Fulfilment queue — a stuck execution never times out on its own.',
          ),
        if (noProvider > 0)
          ProblemBanner(
            severe: true,
            message:
                '$noProvider carrier(s) are routed to API with no provider set. '
                'Their refills are stamped with a NULL provider and no worker will ever claim them.',
          ),
        if (noOffers > 0)
          ProblemBanner(
            message:
                '$noOffers API-routed carrier(s) have nothing in the offer cache. '
                'A refill for those carriers cannot be priced.',
          ),
        if (gaps.isNotEmpty)
          ProblemBanner(
            message:
                'Notification channel(s) with no credential recorded: ${gaps.join(', ')}. '
                'They are disabled — enabling one without its secret means sends are accepted and dropped.',
          ),
        if (esimTotal > 0 && esimCovered < esimTotal)
          ProblemBanner(
            message:
                'eSIM bundles cover $esimCovered of $esimTotal supported countries. '
                'The supplier fetch is truncated — see eSIM sources.',
          ),
        if (awaiting > 0)
          ProblemBanner(
            message: '$awaiting support ticket(s) are waiting on a reply.',
          ),

        AdminCard(
          title: 'Alert dispatch',
          subtitle:
              'Delivery queue health. Unknown sends need provider '
              'reconciliation; only definitively failed jobs can be retried.',
          icon: Icons.notifications_active_outlined,
          child: AsyncPanel<Map<String, dynamic>>(
            value: dispatchHealth,
            builder: (h) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    StatTile(label: 'Pending', value: '${h['pending'] ?? 0}'),
                    StatTile(
                      label: 'Failed',
                      value: '${h['failed'] ?? 0}',
                      tone: (h['failed'] ?? 0) == 0
                          ? StatTone.good
                          : StatTone.bad,
                    ),
                    StatTile(
                      label: 'Unknown',
                      value: '${h['unknown'] ?? 0}',
                      tone: (h['unknown'] ?? 0) == 0
                          ? StatTone.good
                          : StatTone.warn,
                    ),
                    StatTile(
                      label: 'Completed',
                      value: '${h['complete'] ?? 0}',
                      tone: StatTone.good,
                    ),
                  ],
                ),
                if (h['oldest_pending_at'] != null)
                  Text('Oldest pending: ${h['oldest_pending_at']}'),
                if (h['last_completed_at'] != null)
                  Text('Last completed dispatch: ${h['last_completed_at']}'),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.channels),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open channel incidents and Alert Clock'),
                ),
              ],
            ),
          ),
        ),

        AdminCard(
          title: 'Fulfilment queue',
          subtitle:
              'Non-terminal statuses are pending, pending_payment, '
              'routing and processing — a new instant refill is rewritten to '
              'routing before it is ever visible as pending.',
          icon: Icons.local_shipping_outlined,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(
                label: 'In flight',
                value: _n(queue, 'in_flight'),
                tone: inFlight > 0 ? StatTone.warn : StatTone.good,
              ),
              StatTile(
                label: 'Stuck > 24h',
                value: _n(queue, 'stuck_24h'),
                tone: stuck > 0 ? StatTone.bad : StatTone.good,
              ),
              StatTile(
                label: 'Awaiting manual',
                value: _n(queue, 'manual_waiting'),
              ),
              StatTile(
                label: 'Succeeded (7d)',
                value: _n(queue, 'success_7d'),
                tone: StatTone.good,
              ),
              StatTile(
                label: 'Failed (7d)',
                value: _n(queue, 'failed_7d'),
                tone: StatTone.bad,
              ),
            ],
          ),
        ),

        AdminCard(
          title: 'Money',
          subtitle:
              'Derived from wallet_transactions, never from the stored '
              'wallet counters.',
          icon: Icons.payments_outlined,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(
                label: 'Wallet float',
                value: _money(money, 'wallet_balance_total'),
                hint: 'held on behalf of users',
              ),
              StatTile(
                label: 'Deposited (30d)',
                value: _money(money, 'deposited_30d'),
              ),
              StatTile(label: 'Spent (30d)', value: _money(money, 'spent_30d')),
              StatTile(
                label: 'Service fee (30d)',
                value: _money(money, 'app_fee_30d'),
                tone: StatTone.good,
                hint: 'revenue on successful refills',
              ),
            ],
          ),
        ),

        AdminCard(
          title: 'Routing',
          subtitle: 'Default gateway: ${routing['default_gateway'] ?? '—'}',
          icon: Icons.alt_route,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(label: 'Carriers', value: _n(routing, 'carriers_total')),
              StatTile(label: 'via API', value: _n(routing, 'carriers_api')),
              StatTile(
                label: 'Manual / Tasker',
                value: _n(routing, 'carriers_manual'),
              ),
              StatTile(
                label: 'API, no provider',
                value: _n(routing, 'api_without_provider'),
                tone: noProvider > 0 ? StatTone.bad : StatTone.good,
              ),
              StatTile(
                label: 'API, no offers',
                value: _n(routing, 'carriers_without_offers'),
                tone: noOffers > 0 ? StatTone.warn : StatTone.good,
              ),
            ],
          ),
        ),

        AdminCard(
          title: 'Catalogue',
          icon: Icons.inventory_2_outlined,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(
                label: 'Top-up offers',
                value: _n(catalogue, 'topup_offers'),
              ),
              StatTile(
                label: 'Stale > 24h',
                value: _n(catalogue, 'topup_offers_stale'),
                tone:
                    (int.tryParse(_n(catalogue, 'topup_offers_stale')) ?? 0) > 0
                    ? StatTone.warn
                    : StatTone.good,
              ),
              StatTile(
                label: 'eSIM bundles',
                value: _n(catalogue, 'esim_bundles'),
              ),
              StatTile(
                label: 'eSIM coverage',
                value: '$esimCovered / $esimTotal',
                hint: 'supported countries',
                tone: esimCovered < esimTotal ? StatTone.warn : StatTone.good,
              ),
            ],
          ),
        ),

        AdminCard(
          title: 'Notifications',
          icon: Icons.notifications_active_outlined,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(
                label: 'Channels on',
                value:
                    '${_n(notif, 'channels_enabled')} / ${_n(notif, 'channels_total')}',
              ),
              StatTile(
                label: 'Accepted / legacy (7d)',
                value: _n(notif, 'delivered_7d'),
                hint: 'Provider acceptance or old reported delivery',
                tone: StatTone.good,
              ),
              StatTile(
                label: 'Failed (7d)',
                value: _n(notif, 'failed_7d'),
                tone: (int.tryParse(_n(notif, 'failed_7d')) ?? 0) > 0
                    ? StatTone.bad
                    : StatTone.good,
              ),
              StatTile(
                label: 'Push tokens',
                value: _n(notif, 'push_tokens'),
                hint: 'devices reachable',
              ),
            ],
          ),
        ),

        AdminCard(
          title: 'Users & support',
          icon: Icons.people_outline,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(label: 'Users', value: _n(users, 'total')),
              StatTile(label: 'New (7d)', value: _n(users, 'new_7d')),
              StatTile(
                label: 'Suspended',
                value: _n(users, 'suspended'),
                tone: (int.tryParse(_n(users, 'suspended')) ?? 0) > 0
                    ? StatTone.warn
                    : StatTone.neutral,
              ),
              StatTile(label: 'Power users', value: _n(users, 'power')),
              StatTile(label: 'Open tickets', value: _n(support, 'open')),
              StatTile(
                label: 'Awaiting reply',
                value: _n(support, 'awaiting_reply'),
                tone: awaiting > 0 ? StatTone.bad : StatTone.good,
              ),
            ],
          ),
        ),

        AdminCard(
          title: 'Background workers',
          icon: Icons.settings_backup_restore,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv(context, 'Active cron jobs', _n(workers, 'cron_jobs')),
              _kv(
                context,
                'eSIM worker heartbeat',
                '${workers['esim_heartbeat'] ?? 'never'}',
              ),
              _kv(
                context,
                'FX last refreshed',
                '${workers['fx_last_refresh'] ?? 'never'}',
              ),
            ],
          ),
        ),

        const EsimOperationInspector(),

        AdminCard(
          title: 'Recent system alerts',
          icon: Icons.campaign_outlined,
          child: alerts.isEmpty
              ? const Text('No system alerts recorded.')
              : Column(
                  children: [
                    for (final a in alerts.cast<Map<String, dynamic>>())
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.circle, size: 10),
                        title: Text('${a['message']}'),
                        subtitle: Text(
                          '${a['kind']} · ${a['created_at']}'.replaceAll(
                            'T',
                            ' ',
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 220,
          child: Text(k, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: SelectableText(
            v,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}
