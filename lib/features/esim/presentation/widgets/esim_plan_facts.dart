import 'package:flutter/material.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_catalogue_details.dart';

/// Same retail facts in details and checkout, with no supplier/wholesale payload.
class EsimPlanFacts extends StatelessWidget {
  const EsimPlanFacts({
    super.key,
    required this.facts,
    required this.countries,
  });
  final EsimCatalogueDetails facts;
  final List<String> countries;

  @override
  Widget build(BuildContext context) {
    String timeLabel(String key) {
      final parsed = DateTime.tryParse(facts.text(key) ?? '');
      if (parsed == null) return 'Not provided';
      final local = parsed.toLocal();
      final material = MaterialLocalizations.of(context);
      return '${material.formatMediumDate(local)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
    }

    final rows = <(String, String)>[
      ('Plan type', facts.typeLabel),
      ('Coverage', countries.isEmpty ? 'Not provided' : countries.join(', ')),
      ('Supported networks', facts.networksLabel),
      ('Allowance policy', facts.policyLabel),
      ('Activation', facts.activationLabel),
      ('Unused activation deadline', facts.unusedValidityLabel),
      ('Recharge', facts.rechargeLabel),
      ('APN', facts.text('apn') ?? 'Not provided'),
      ('Help', facts.text('help_text') ?? 'Not provided'),
      ('Provider update', timeLabel('source_updated_at')),
      ('Catalogue checked', timeLabel('observed_at')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.$1, style: Theme.of(context).textTheme.labelMedium),
                Text(row.$2, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }
}
