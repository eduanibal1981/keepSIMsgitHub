import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import '../../domain/entities/esim_plan.dart';
import '../../domain/entities/esim_group.dart';
import '../controllers/esim_group_controller.dart';

class EsimGroupCheckoutScreen extends ConsumerStatefulWidget {
  const EsimGroupCheckoutScreen({super.key, required this.plan});
  final EsimPlan plan;
  static Future<void> show(BuildContext context, EsimPlan plan) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: .94,
          child: EsimGroupCheckoutScreen(plan: plan),
        ),
      );
  @override
  ConsumerState<EsimGroupCheckoutScreen> createState() =>
      _EsimGroupCheckoutScreenState();
}

class _EsimGroupCheckoutScreenState
    extends ConsumerState<EsimGroupCheckoutScreen> {
  final _group = TextEditingController(text: 'Travel group');
  final _labels = List.generate(
    3,
    (i) => TextEditingController(text: 'Traveller ${i + 1}'),
  );
  final _days = List.generate(3, (_) => TextEditingController(text: '1'));
  int _count = 2;
  bool _busy = false, _uncertain = false;
  String? _notice, _quoteOwner, _batch, _sessionOwner;
  EsimGroupQuote? _quote;
  String _key = const Uuid().v4();
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _quote != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _group.dispose();
    for (final c in [..._labels, ..._days]) {
      c.dispose();
    }
    super.dispose();
  }

  void edited() {
    setState(() {
      _quote = null;
      _quoteOwner = null;
      _key = const Uuid().v4();
    });
  }

  Future<void> review() async {
    if (_busy || _uncertain) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(esimGroupActionsProvider)
          .review(
            _group.text,
            List.generate(
              _count,
              (i) => EsimTravellerIntent(
                widget.plan.id,
                _labels[i].text,
                days: widget.plan.facts.isDaily
                    ? int.tryParse(_days[i].text) ?? 0
                    : null,
              ),
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _quote = result;
        _quoteOwner = result.owner;
        _notice = result.status == 'QUOTED'
            ? null
            : result.status.replaceAll('_', ' ').toLowerCase();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _notice = 'Could not load the group quote. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> accept(EsimGroupQuote quote) async {
    if (_busy) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm separate traveller eSIMs'),
        content: Text(
          '${quote.members.map((m) => '${m['traveller_label']}: USD ${m['retail_total']}').join('\n')}\n\nTotal ${quote.totalLabel}\nEach traveller receives a separate profile and allowance. Funds remain reserved while each outcome is confirmed. Partial delivery is shown per traveller.',
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
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(esimGroupActionsProvider)
          .accept(quote, _key);
      if (!mounted) {
        return;
      }
      setState(() {
        _uncertain = result['status'] == 'OUTCOME_UNKNOWN';
        _batch = result['batch_id'] as String?;
        _notice = _uncertain
            ? 'The response is uncertain. Retry this same request or check group orders before making another purchase.'
            : result['status'] == 'ACCEPTED' || result['status'] == 'ADOPTED'
            ? 'Group request recorded. Track each traveller in My eSIMs.'
            : result['status']?.toString().replaceAll('_', ' ').toLowerCase();
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider), owner = auth.value?.id;
    ref.watch(esimGroupActionsProvider);
    final current =
        !auth.isLoading &&
            !auth.hasError &&
            owner != null &&
            owner == _quoteOwner
        ? _quote
        : null;
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
      return Scaffold(
        appBar: AppBar(title: const Text('Buy for travellers')),
        body: const Center(
          child: Text('Sign in again to manage traveller purchases.'),
        ),
      );
    }
    final available =
        ref.watch(esimOrganizationProvider).value?.maxMembers ?? 3;
    _count = _count.clamp(1, available);
    return Scaffold(
      appBar: AppBar(title: const Text('Buy for travellers')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.plan.name, style: Theme.of(context).textTheme.titleLarge),
          const Text(
            'Each profile has its own allowance and installation. The purchaser manages payment and refunds. Labels stay private in your account.',
          ),
          TextField(
            controller: _group,
            maxLength: 60,
            enabled: !_busy && !_uncertain && _batch == null,
            onChanged: (_) => edited(),
            decoration: const InputDecoration(labelText: 'Group label'),
          ),
          DropdownButtonFormField<int>(
            initialValue: _count,
            decoration: const InputDecoration(labelText: 'Travellers'),
            items: List.generate(
              available,
              (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
            ),
            onChanged: _busy || _uncertain || _batch != null
                ? null
                : (n) {
                    _count = n ?? 1;
                    edited();
                  },
          ),
          for (var i = 0; i < _count; i++) ...[
            TextField(
              controller: _labels[i],
              maxLength: 60,
              enabled: !_busy && !_uncertain && _batch == null,
              onChanged: (_) => edited(),
              decoration: InputDecoration(
                labelText: 'Traveller ${i + 1} label',
              ),
            ),
            if (widget.plan.facts.isDaily)
              TextField(
                controller: _days[i],
                keyboardType: TextInputType.number,
                enabled: !_busy && !_uncertain && _batch == null,
                onChanged: (_) => edited(),
                decoration: const InputDecoration(
                  labelText: 'Day Pass duration (1–365 whole days)',
                ),
              ),
          ],
          OutlinedButton(
            onPressed: _busy || _uncertain || _batch != null ? null : review,
            child: const Text('Review server total'),
          ),
          if (current != null && current.complete) ...[
            for (final member in current.members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${member['traveller_label']} • ${member['title']}',
                ),
                subtitle: Text(
                  '${member['period_count'] ?? member['duration_value'] ?? 'Not provided'} ${member['duration_unit'] == 'HOUR'
                      ? 'hours'
                      : member['duration_unit'] == 'DAY'
                      ? 'days'
                      : ''} • USD ${member['retail_total']}',
                ),
              ),
            Text(
              'Total ${current.totalLabel}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              current.expired
                  ? 'Quote expired. Review the current total again.'
                  : 'Review expires at ${current.expiresAt!.toLocal()}',
            ),
            if (!current.enabled)
              const Text(
                'Group purchasing is currently unavailable, or your available wallet balance does not cover the total.',
              ),
            FilledButton(
              onPressed:
                  !_busy &&
                      _batch == null &&
                      current.enabled &&
                      (!current.expired || _uncertain)
                  ? () => accept(current)
                  : null,
              child: Text(
                _uncertain
                    ? 'Retry the same group request'
                    : 'Confirm group purchase',
              ),
            ),
          ],
          if (_notice != null) Text(_notice!),
          if (_batch != null)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Return to My eSIMs'),
            ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
