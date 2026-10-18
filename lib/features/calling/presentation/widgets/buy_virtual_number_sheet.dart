import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:keep_sims/features/calling/data/models/available_virtual_number_model.dart';
import 'package:keep_sims/features/calling/data/models/virtual_did_model.dart';
import 'package:keep_sims/features/calling/presentation/controllers/second_number_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';

class BuyVirtualNumberSheet extends ConsumerStatefulWidget {
  const BuyVirtualNumberSheet({super.key});
  static Future<VirtualDidNumber?> show(BuildContext context) =>
      showModalBottomSheet<VirtualDidNumber>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const BuyVirtualNumberSheet(),
      );
  @override
  ConsumerState<BuyVirtualNumberSheet> createState() =>
      _BuyVirtualNumberSheetState();
}

class _BuyVirtualNumberSheetState extends ConsumerState<BuyVirtualNumberSheet> {
  String? _country;
  AvailableVirtualNumber? _selected;
  bool _autoRenew = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final money = NumberFormat.simpleCurrency(
      name: 'USD',
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    final countries = ref.watch(secondNumberCountriesProvider);
    final purchase = ref.watch(secondNumberPurchaseProvider);
    final order = purchase.value;
    final selected = _selected;
    final wallet = ref.watch(walletControllerProvider).value;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order != null
                      ? l.snSetupPending
                      : selected == null
                      ? l.snGetNumber
                      : l.snReview,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: l.snCancel,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (order != null) ...[
            SelectableText(
              order.phoneNumber,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              order.state == 'failed'
                  ? l.snPurchaseFailed
                  : order.state == 'active'
                  ? l.snActive
                  : l.snPurchasePending,
            ),
            const SizedBox(height: 18),
            if (order.isPending)
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(secondNumberPurchaseProvider.notifier)
                    .refresh(order.id),
                icon: const Icon(Icons.refresh),
                label: Text(l.snCheckStatus),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.snMyNumbers),
            ),
          ] else if (selected != null) ...[
            TextButton.icon(
              onPressed: purchase.isLoading
                  ? null
                  : () => setState(() => _selected = null),
              icon: const Icon(Icons.arrow_back),
              label: Text(l.snChooseNumber),
            ),
            SelectableText(
              selected.phoneNumber,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _cost(l.snSetupFee, money.format(selected.setupFeeUsd)),
            const Divider(),
            _cost(
              l.snTotal,
              money.format(selected.totalMonthlyUsd + selected.setupFeeUsd),
            ),
            Text(
              '${money.format(selected.totalMonthlyUsd)} · ${l.snEveryDays(selected.billingPeriodDays)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (wallet != null)
              _cost(l.snWalletBalance, money.format(wallet.wallet.balance)),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l.snAutoRenew),
              value: _autoRenew,
              onChanged: purchase.isLoading
                  ? null
                  : (value) => setState(() => _autoRenew = value),
            ),
            Text(l.snUsage, style: theme.textTheme.titleSmall),
            Text(selected.usageTerms),
            const SizedBox(height: 14),
            Text(l.snVerification, style: theme.textTheme.bodySmall),
            const SizedBox(height: 18),
            if (purchase.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l.snError,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (selected.quoteExpiresAt?.isAfter(DateTime.now()) != true) ...[
              Text(l.snQuoteExpired),
              OutlinedButton(
                onPressed: () {
                  ref.invalidate(secondNumberInventoryProvider(_country!));
                  setState(() => _selected = null);
                },
                child: Text(l.snRefresh),
              ),
            ] else
              FilledButton(
                onPressed: purchase.isLoading
                    ? null
                    : () => ref
                          .read(secondNumberPurchaseProvider.notifier)
                          .purchase(selected.quoteId!, _autoRenew),
                child: purchase.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        '${l.snActivate} · ${money.format(selected.totalMonthlyUsd + selected.setupFeeUsd)}',
                      ),
              ),
          ] else ...[
            Text(l.snReceiveOnly, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            countries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _retry(
                l.snError,
                () => ref.invalidate(secondNumberCountriesProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(l.snNoCoverage),
                  );
                }
                final country = _country ?? items.first.code;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: country,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l.snChooseCountry),
                      items: items
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.code,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _country = value),
                    ),
                    const SizedBox(height: 16),
                    ref
                        .watch(secondNumberInventoryProvider(country))
                        .when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, _) => _retry(
                            l.snError,
                            () => ref.invalidate(
                              secondNumberInventoryProvider(country),
                            ),
                          ),
                          data: (numbers) => numbers.isEmpty
                              ? Text(l.snNoStock)
                              : Column(
                                  children: numbers
                                      .map(
                                        (item) => Card(
                                          child: ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 8,
                                                ),
                                            title: Text(
                                              item.formattedNumber,
                                              textDirection: TextDirection.ltr,
                                            ),
                                            subtitle: Text(
                                              'SMS · ${money.format(item.totalMonthlyUsd)} · ${l.snEveryDays(item.billingPeriodDays)}',
                                            ),
                                            trailing: const Icon(
                                              Icons.chevron_right,
                                            ),
                                            onTap: item.quoteId == null
                                                ? null
                                                : () => setState(() {
                                                    _country = country;
                                                    _selected = item;
                                                  }),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text(l.snVerification, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _cost(String label, String amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(amount),
      ],
    ),
  );
  Widget _retry(String message, VoidCallback action) => Column(
    children: [
      Text(message),
      TextButton(
        onPressed: action,
        child: Text(AppLocalizations.of(context)!.snRetry),
      ),
    ],
  );
}
