/// SIM Shield — "Roam or eSIM?" calculator (G5)
///
/// C8 already knows what country the user is standing in, and already fires a
/// notification that lands on `/esim`. This is the screen that makes that
/// trigger mean something: what *your own carrier* charges to roam here, next
/// to what an eSIM costs, for the trip you are actually taking.
///
/// Three rules this screen does not bend:
///
///  1. **The roaming number is always labelled an estimate, with its source.**
///     The call to action here is "buy our eSIM". An unqualified competitor
///     price on that screen would be marketing dressed as information. Every
///     seeded tariff is a published figure that was never confirmed with the
///     carrier, and the footer says exactly that, with the date and a link.
///  2. **Roaming is allowed to win.** `roaming_cheaper` renders as a normal
///     outcome with the same weight as `esim_cheaper`. Jazz sells 1 GB in the
///     UAE for $3.59; hiding that would make every other number untrustworthy.
///  3. **No saving is claimed unless the eSIM covers the trip.** The live
///     catalogue is 1 GB / 7 day bundles only, so a 10 GB ask returns
///     `esim_partial` — the best available bundle is shown, the comparison is
///     not.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/presentation/widgets/esim_checkout_sheet.dart';
import 'package:keep_sims/features/roam_calculator/data/models/roam_quote_model.dart';
import 'package:keep_sims/features/roam_calculator/presentation/providers/roam_quote_provider.dart';

class RoamCalculatorScreen extends ConsumerStatefulWidget {
  const RoamCalculatorScreen({super.key, this.initialCountryCode});

  /// Normally `profiles.last_country`, i.e. whatever C8 detected.
  final String? initialCountryCode;

  @override
  ConsumerState<RoamCalculatorScreen> createState() =>
      _RoamCalculatorScreenState();
}

class _RoamCalculatorScreenState extends ConsumerState<RoamCalculatorScreen> {
  static const List<int> _dayChoices = <int>[1, 3, 5, 7, 14, 30];
  static const List<int> _dataChoices = <int>[500, 1000, 3000, 5000, 10000];

  late RoamQuoteInput _input;

  @override
  void initState() {
    super.initState();
    _input = RoamQuoteInput(
      countryCode: (widget.initialCountryCode ?? '').toUpperCase(),
      days: 7,
      dataMb: 1000,
    );
  }

  static String countryFlag(String code) {
    if (code.length != 2) return '🌐';
    final String upper = code.toUpperCase();
    return String.fromCharCode(upper.codeUnitAt(0) - 0x41 + 0x1F1E6) +
        String.fromCharCode(upper.codeUnitAt(1) - 0x41 + 0x1F1E6);
  }

  @override
  Widget build(BuildContext context) {
    final quoteAsync = ref.watch(roamQuoteProvider(_input));
    final carriersAsync = ref.watch(roamCarriersProvider(_input.countryCode));

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_rounded, color: context.onSurfaceColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Roam or eSIM?',
          style: AppTextStyles.headlineMedium.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: <Widget>[
          _destinationHeader(),
          const SizedBox(height: 20),
          _chipRow(
            label: 'How long?',
            values: _dayChoices,
            selected: _input.days,
            format: (int v) => v == 1 ? '1 day' : '$v days',
            onTap: (int v) => setState(() => _input = _input.copyWith(days: v)),
          ),
          const SizedBox(height: 16),
          _chipRow(
            label: 'How much data?',
            values: _dataChoices,
            selected: _input.dataMb,
            format: RoamQuote.formatMb,
            onTap: (int v) =>
                setState(() => _input = _input.copyWith(dataMb: v)),
          ),
          const SizedBox(height: 20),
          carriersAsync.when(
            data: _carrierPicker,
            loading: () => const SizedBox(height: 48),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          quoteAsync.when(
            data: (RoamQuote? q) =>
                q == null ? _emptyState() : _comparison(context, q),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object e, _) => _errorState(e),
          ),
        ],
      ),
    );
  }

  // ── Inputs ────────────────────────────────────────────────────────────────

  Widget _destinationHeader() {
    final String code = _input.countryCode;
    return Row(
      children: <Widget>[
        Text(countryFlag(code), style: const TextStyle(fontSize: 34)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Destination',
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.onSurfaceColor.withValues(alpha: 0.6)),
              ),
              Text(
                code.isEmpty ? 'Not detected yet' : code,
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chipRow({
    required String label,
    required List<int> values,
    required int selected,
    required String Function(int) format,
    required void Function(int) onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.bodySmall
              .copyWith(color: context.onSurfaceColor.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((int v) {
            final bool isOn = v == selected;
            return ChoiceChip(
              label: Text(format(v)),
              selected: isOn,
              onSelected: (_) {
                HapticHelper.lightTick();
                onTap(v);
              },
            );
          }).toList(growable: false),
        ),
      ],
    );
  }

  /// Carriers with no tariff on file stay visible but unselectable — a missing
  /// corridor is information ("we don't know what Omantel charges"), and hiding
  /// the line would read as "you don't have that SIM".
  Widget _carrierPicker(List<RoamCarrierOption> options) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Roaming on',
          style: AppTextStyles.bodySmall
              .copyWith(color: context.onSurfaceColor.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((RoamCarrierOption o) {
            final bool isOn = _input.carrierId == o.carrierId;
            return ChoiceChip(
              label: Text(
                o.isHome ? '${o.carrierName} · home' : o.carrierName,
              ),
              avatar: o.hasRate
                  ? null
                  : Icon(Icons.help_outline_rounded,
                      size: 16,
                      color: context.onSurfaceColor.withValues(alpha: 0.5)),
              selected: isOn,
              onSelected: o.hasRate
                  ? (bool on) {
                      HapticHelper.lightTick();
                      setState(() {
                        _input = on
                            ? _input.copyWith(carrierId: o.carrierId)
                            : _input.copyWith(clearCarrier: true);
                      });
                    }
                  : null,
            );
          }).toList(growable: false),
        ),
      ],
    );
  }

  // ── Output ────────────────────────────────────────────────────────────────

  Widget _comparison(BuildContext context, RoamQuote q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _verdictBanner(q),
        const SizedBox(height: 16),
        // Same trap as the household invite dialog: this Column rides in a
        // ListView, so the Row's height is unbounded and `stretch` would hand
        // its children a tight infinite constraint. IntrinsicHeight bounds it.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _roamingCard(q)),
              const SizedBox(width: 12),
              Expanded(child: _esimCard(q)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (q.hasEsim) _callToAction(context, q),
        if (q.hasRoaming) ...<Widget>[
          const SizedBox(height: 16),
          _provenanceFooter(q),
        ],
      ],
    );
  }

  Widget _verdictBanner(RoamQuote q) {
    late final String headline;
    late final String detail;
    late final Color tint;
    late final IconData icon;

    switch (q.verdict) {
      case 'esim_cheaper':
        final double saved = q.savingsUsd ?? 0;
        final double? pct = q.savingsPercent;
        headline = 'Save \$${saved.toStringAsFixed(2)} with an eSIM';
        detail = pct == null
            ? '${q.tripDays} days in ${q.destinationCountryName}'
            : "That's ${pct.toStringAsFixed(0)}% less than roaming for "
                '${q.tripDays} ${q.tripDays == 1 ? 'day' : 'days'}.';
        tint = AppColors.success;
        icon = Icons.savings_rounded;
      case 'roaming_cheaper':
        headline = 'Your carrier is cheaper here';
        detail =
            '${q.roamingCarrierName} works out cheaper than any eSIM we sell for '
            'this trip. Keep roaming.';
        tint = AppColors.info;
        icon = Icons.check_circle_outline_rounded;
      case 'tie':
        headline = 'Line ball';
        detail = 'Roaming and an eSIM cost the same for this trip.';
        tint = AppColors.info;
        icon = Icons.balance_rounded;
      case 'esim_partial':
        headline = 'No eSIM that big yet';
        detail =
            'The largest we can put together for ${q.destinationCountryName} is '
            '${q.esimDetailLine}, short of ${RoamQuote.formatMb(q.tripDataMb)} '
            'over ${q.tripDays} days — so this is not a like-for-like price.';
        tint = AppColors.warning;
        icon = Icons.rule_rounded;
      case 'no_esim':
        headline = 'No eSIM for ${q.destinationCountryName}';
        detail =
            'We have no bundle covering this country yet. The roaming estimate '
            'is still worth knowing.';
        tint = AppColors.warning;
        icon = Icons.public_off_rounded;
      case 'no_roaming_rate':
        headline = 'No roaming tariff on file';
        detail =
            "We don't have a published rate for your carriers in "
            '${q.destinationCountryName}, so there is nothing to compare '
            'against. Check with your carrier before you travel.';
        tint = AppColors.warning;
        icon = Icons.help_outline_rounded;
      default: // 'no_data'
        headline = 'Nothing to compare yet';
        detail =
            'We have neither a roaming tariff for your carriers nor an eSIM for '
            '${q.destinationCountryName}.';
        tint = AppColors.warning;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  headline,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.onSurfaceColor.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roamingCard(RoamQuote q) => _priceCard(
        title: 'Roaming',
        subtitle: q.hasRoaming
            ? '${q.roamingCarrierName} · ${q.roamingHomeCountry}'
            : 'No rate on file',
        price: q.roamingTotalUsd,
        detail: q.hasRoaming ? q.roamingDetailLine : null,
        badge: q.roamingScope == 'worldwide' ? 'Worldwide pass' : null,
        highlighted: q.verdict == 'roaming_cheaper',
        tint: AppColors.warning,
      );

  Widget _esimCard(RoamQuote q) => _priceCard(
        title: 'KeepSIMs eSIM',
        subtitle: q.hasEsim ? q.esimBundleName : 'Not available here',
        price: q.esimTotalUsd,
        detail: q.hasEsim ? q.esimDetailLine : null,
        badge: q.hasEsim && !q.esimCoversTrip ? 'Smaller than your trip' : null,
        highlighted: q.verdict == 'esim_cheaper',
        tint: AppColors.primary,
      );

  Widget _priceCard({
    required String title,
    required String? subtitle,
    required double? price,
    required String? detail,
    required String? badge,
    required bool highlighted,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? tint
              : context.onSurfaceColor.withValues(alpha: 0.12),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: tint,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            price == null ? '—' : '\$${price.toStringAsFixed(2)}',
            style: AppTextStyles.headlineMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (subtitle != null)
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.7),
              ),
            ),
          if (detail != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              detail,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.55),
              ),
            ),
          ],
          if (badge != null) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: AppTextStyles.labelSmall.copyWith(color: tint),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The checkout sheet buys exactly one bundle — it has no quantity control.
  /// So a quote that needs more than one sends the user to the plans screen
  /// instead of to a sheet that would silently buy a third of the trip.
  Widget _callToAction(BuildContext context, RoamQuote q) {
    final int qty = q.esimQuantity ?? 1;
    final bool singleBundle = qty == 1;

    return FilledButton.icon(
      onPressed: () {
        HapticHelper.mediumImpact();
        if (singleBundle) {
          EsimCheckoutSheet.show(
            context,
            EsimPlan(
              id: q.esimOfferId!,
              name: q.esimBundleName ?? q.esimOfferId!,
              dataAmountMB: q.esimDataMb ?? 0,
              durationDays: q.esimDurationDays ?? 0,
              priceUsd: q.esimUnitPriceUsd ?? 0,
              providerName: 'esim_go',
              supportedCountries: <String>[q.destinationCountryCode],
            ),
          );
        } else {
          context.push(AppRoutes.esimPlans);
        }
      },
      icon: Icon(singleBundle
          ? Icons.shopping_bag_outlined
          : Icons.arrow_forward_rounded),
      label: Text(
        singleBundle
            ? 'Get this eSIM — \$${(q.esimTotalUsd ?? 0).toStringAsFixed(2)}'
            : 'See eSIMs for ${q.destinationCountryName} ($qty needed)',
      ),
    );
  }

  /// Not decoration. Every roaming figure is a published price that was never
  /// confirmed with the carrier, and this screen is trying to sell the
  /// alternative — so the caveat, the date and the source travel with it.
  Widget _provenanceFooter(RoamQuote q) {
    final String? url = q.roamingSourceUrl;
    final DateTime? asOf = q.roamingPricedAsOf;
    final String date = asOf == null
        ? 'an undated source'
        : '${asOf.year}-${asOf.month.toString().padLeft(2, '0')}-${asOf.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          q.roamingIsEstimate
              ? 'Roaming estimate only. Taken from ${q.roamingCarrierName}’s '
                  'published price on $date and converted to USD; taxes and '
                  'fair-use limits may change it. Confirm with your carrier '
                  'before you travel.'
              : 'Roaming price confirmed with ${q.roamingCarrierName} on $date.',
          style: AppTextStyles.bodySmall.copyWith(
            color: context.onSurfaceColor.withValues(alpha: 0.55),
          ),
        ),
        if (url != null && url.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
            ),
            onPressed: () => launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text("See the carrier's own page"),
          ),
        ],
      ],
    );
  }

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: <Widget>[
            Icon(Icons.travel_explore_rounded,
                size: 48, color: context.onSurfaceColor.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'Turn on Travel Mode and open the app where you are — we detect '
              'the country from your connection, with no location permission.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );

  Widget _errorState(Object e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'Could not work out a comparison right now.\n$e',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
        ),
      );
}
