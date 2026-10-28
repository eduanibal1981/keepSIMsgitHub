import 'package:flutter/material.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';

class EsimProfileCard extends StatelessWidget {
  const EsimProfileCard({
    super.key,
    required this.profile,
    required this.onInstall,
    required this.onBuyNew,
  });
  final UserEsim profile;
  final VoidCallback onInstall, onBuyNew;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = profile.hasKnownUsage && profile.dataTotalBytes! > 0
        ? (profile.dataRemainingBytes! / profile.dataTotalBytes!).clamp(
            0.0,
            1.0,
          )
        : null;
    String date(DateTime value) =>
        MaterialLocalizations.of(context).formatMediumDate(value.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(profile.bundleName, style: theme.textTheme.titleMedium),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(profile.statusLabel)),
                Chip(label: Text('Installation: ${profile.installationLabel}')),
              ],
            ),
            Text(profile.usageLabel, key: const ValueKey('esim-usage')),
            if (ratio != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: ratio),
            ],
            const SizedBox(height: 8),
            Text(
              profile.usageIsStale
                  ? 'Last-known usage • refresh pending or unavailable'
                  : 'Last reported usage • provider readings may be delayed',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              profile.lastSyncedAt == null
                  ? 'Usage check time: Not provided'
                  : 'Last checked: ${date(profile.lastSyncedAt!)}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              profile.usageObservedAt == null
                  ? 'Provider observation time: Not provided'
                  : 'Provider observation: ${date(profile.usageObservedAt!)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text(profile.facts.activationLabel),
            Text(
              profile.expiresAt == null
                  ? 'Expiry not confirmed'
                  : 'Expires: ${date(profile.expiresAt!)}',
            ),
            Text(profile.facts.unusedValidityLabel),
            if (!profile.hasActivationPayload)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Installation details await provider verification.',
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: profile.hasActivationPayload ? onInstall : null,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Installation details'),
                ),
                OutlinedButton.icon(
                  onPressed: onBuyNew,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Buy a new eSIM'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
