import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import '../../data/models/virtual_did_model.dart';
import '../controllers/second_number_controller.dart';
import '../widgets/buy_virtual_number_sheet.dart';
import 'second_number_sms_screen.dart';

class SecondNumberOverview extends ConsumerStatefulWidget {
  final String? initialDidId;
  final void Function(VirtualDidNumber) onForwardSetup;
  const SecondNumberOverview({
    super.key,
    this.initialDidId,
    required this.onForwardSetup,
  });
  @override
  ConsumerState<SecondNumberOverview> createState() =>
      _SecondNumberOverviewState();
}

class _SecondNumberOverviewState extends ConsumerState<SecondNumberOverview>
    with WidgetsBindingObserver {
  bool _openedLink = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    ref.invalidate(virtualDidsProvider);
    ref.invalidate(pendingSecondNumbersProvider);
    ref.invalidate(secondNumberCountriesProvider);
  }

  void _inbox(VirtualDidNumber did) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => SecondNumberSmsScreen(did: did)),
  );
  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.snCopied)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final numbers = ref.watch(virtualDidsProvider);
    final pending = ref.watch(pendingSecondNumbersProvider);
    final countries = ref.watch(secondNumberCountriesProvider);
    final noCoverage = !countries.hasError && countries.value?.isEmpty == true;
    final money = NumberFormat.simpleCurrency(
      name: 'USD',
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.snMyNumbers)),
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
          // Keep failures in the providers so pull-to-refresh renders the
          // normal retry state instead of throwing out of the gesture.
          await Future.wait([
            ref
                .read(virtualDidsProvider.future)
                .then<void>((_) {}, onError: (_, _) {}),
            ref
                .read(pendingSecondNumbersProvider.future)
                .then<void>((_) {}, onError: (_, _) {}),
            ref
                .read(secondNumberCountriesProvider.future)
                .then<void>((_) {}, onError: (_, _) {}),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(l.snSubtitle, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 22),
            numbers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Column(
                children: [
                  Text(l.snError),
                  TextButton(onPressed: _refresh, child: Text(l.snRetry)),
                ],
              ),
              data: (items) {
                if (!_openedLink && widget.initialDidId != null) {
                  final matches = items.where(
                    (d) => d.id == widget.initialDidId && d.supportsSms,
                  );
                  if (matches.isNotEmpty) {
                    _openedLink = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _inbox(matches.first);
                    });
                  }
                }
                if (items.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            noCoverage
                                ? Icons.schedule
                                : Icons.sim_card_outlined,
                            size: 42,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            noCoverage ? l.snNoCoverage : l.snEmpty,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: items.map((did) {
                    final releasing = did.status == 'release_pending';
                    final grace = did.status == 'suspended';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  did.flagEmoji,
                                  style: const TextStyle(fontSize: 26),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    did.countryName,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    releasing
                                        ? l.snReleasePending
                                        : grace
                                        ? l.snGrace
                                        : l.snActive,
                                    style: TextStyle(
                                      color: grace
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    did.phoneNumber,
                                    textDirection: TextDirection.ltr,
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _copy(did.phoneNumber),
                                  icon: const Icon(Icons.copy_outlined),
                                  tooltip: l.snCopyNumber,
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (did.supportsSms)
                                  const Chip(
                                    label: Text('SMS'),
                                    avatar: Icon(Icons.sms_outlined, size: 16),
                                  ),
                                if (did.supportsVoice)
                                  Chip(
                                    label: Text(l.snCalls),
                                    avatar: const Icon(
                                      Icons.phone_outlined,
                                      size: 16,
                                    ),
                                  ),
                                if (did.numberType == 'mobile')
                                  Chip(label: Text(l.snMobile)),
                                if (did.numberType == 'local')
                                  Chip(label: Text(l.snLocal)),
                              ],
                            ),
                            const Divider(height: 28),
                            Text(
                              !did.lifecycleManaged
                                  ? l.snRenewalReview
                                  : grace && did.graceExpiresAt != null
                                  ? '${l.snGrace}\n${date.format(did.graceExpiresAt!.toLocal())}'
                                  : '${did.autoRenew ? l.snRenewal : l.snPaidUntil}: ${date.format(did.renewsAt.toLocal())}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${money.format(did.monthlyFeeUsd)} · ${l.snEveryDays(did.billingPeriodDays)}',
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (did.supportsSms)
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () => _inbox(did),
                                      icon: const Icon(Icons.inbox_outlined),
                                      label: Text(
                                        '${l.snOpenInbox}${did.unreadSmsCount > 0 ? ' (${did.unreadSmsCount})' : ''}',
                                      ),
                                    ),
                                  ),
                                if (!did.supportsSms) const Spacer(),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  onPressed: () => _manage(did),
                                  icon: const Icon(Icons.tune),
                                  tooltip: l.snManage,
                                ),
                              ],
                            ),
                            if ((did.supportsVoice ||
                                    (!did.supportsSms &&
                                        did.numberType == 'unknown')) &&
                                did.status == 'active')
                              TextButton(
                                onPressed: () => widget.onForwardSetup(did),
                                child: Text(l.snForwardSetup),
                              ),
                            if (grace)
                              TextButton(
                                onPressed: () => context.push(AppRoutes.wallet),
                                child: Text(l.snTopUp),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            ...?pending.value?.map(
              (order) => Card(
                child: ListTile(
                  leading: const Icon(Icons.hourglass_top),
                  title: Text(
                    order.phoneNumber,
                    textDirection: TextDirection.ltr,
                  ),
                  subtitle: Text(l.snSetupPending),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: l.snRefresh,
                    onPressed: _refresh,
                  ),
                ),
              ),
            ),
            if (!numbers.hasError && (pending.hasError || countries.hasError))
              Column(
                children: [
                  Text(l.snError),
                  TextButton(onPressed: _refresh, child: Text(l.snRetry)),
                ],
              ),
            if (noCoverage && numbers.value?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l.snNoCoverage),
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed:
                  countries.value?.isNotEmpty == true &&
                      !countries.hasError &&
                      !countries.isLoading &&
                      !numbers.hasError
                  ? () async {
                      await BuyVirtualNumberSheet.show(context);
                      if (mounted) _refresh();
                    }
                  : null,
              icon: const Icon(Icons.add),
              label: Text(l.snGetNumber),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.snPrivateNotifications,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l.snVerification, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _manage(VirtualDidNumber did) async {
    final l = AppLocalizations.of(context)!;
    var autoRenew = did.autoRenew;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) => StatefulBuilder(
          builder: (context, setSheetState) {
            final busy = ref.watch(secondNumberActionsProvider).isLoading;
            return Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.snManage,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    did.phoneNumber,
                    textDirection: TextDirection.ltr,
                  ),
                  if (!did.lifecycleManaged) Text(l.snRenewalReview),
                  if (did.lifecycleManaged && did.status != 'release_pending')
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.snAutoRenew),
                      value: autoRenew,
                      onChanged: busy
                          ? null
                          : (value) async {
                              final ok = await ref
                                  .read(secondNumberActionsProvider.notifier)
                                  .autoRenew(did.id, value);
                              if (ok && context.mounted) {
                                setSheetState(() => autoRenew = value);
                              }
                            },
                    ),
                  if (ref.watch(secondNumberActionsProvider).hasError)
                    Text(
                      l.snError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: busy || did.status == 'release_pending'
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: Text(l.snRelease),
                                content: Text(l.snReleaseConfirm),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: Text(l.snCancel),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: Text(l.snRelease),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !context.mounted) return;
                            final ok = await ref
                                .read(secondNumberActionsProvider.notifier)
                                .release(did.id);
                            if (ok && sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          },
                    child: Text(l.snRelease),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
