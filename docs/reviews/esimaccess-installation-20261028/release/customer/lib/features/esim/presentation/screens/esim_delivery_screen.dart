import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_installation_policy.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_installation_controller.dart';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';

class EsimDeliveryScreen extends ConsumerStatefulWidget {
  const EsimDeliveryScreen({super.key, required this.esim});
  final UserEsim esim;
  static Future<void> show(BuildContext context, UserEsim esim) =>
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EsimDeliveryScreen(esim: esim)),
      );
  @override
  ConsumerState<EsimDeliveryScreen> createState() => _EsimDeliveryScreenState();
}

class _EsimDeliveryScreenState extends ConsumerState<EsimDeliveryScreen> {
  bool _sameDevice = false, _busy = false;
  String? _notice;

  @override
  void didUpdateWidget(covariant EsimDeliveryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.esim.id != widget.esim.id) {
      _sameDevice = false;
      _notice = null;
    }
  }

  bool _mayReveal(UserEsim profile) =>
      ref.read(authControllerProvider).value?.id == profile.userId &&
      EsimInstallationPolicy.forProfile(
        profile,
      ).mayReveal(sameDeviceConfirmed: _sameDevice);

  Future<void> _copy(UserEsim profile, String label, String value) async {
    if (!_mayReveal(profile)) return;
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted) {
        setState(
          () => _notice = '$label copied. Keep installation details private.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notice = 'Could not copy. Enter the details manually.');
      }
    }
  }

  Future<void> _open(UserEsim profile) async {
    if (_busy || !_mayReveal(profile)) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    final outcome = await ref
        .read(esimInstallationControllerProvider)
        .openApple(profile, sameDeviceConfirmed: _sameDevice);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = switch (outcome) {
        EsimInstallLaunchResult.opened =>
          'Apple setup was opened. Complete the phone’s prompts. Returning to KeepSIMs does not confirm installation; refresh the profile afterward.',
        EsimInstallLaunchResult.unavailable =>
          'Apple setup is unavailable here. Use the QR code or manual instructions on a supported device.',
        EsimInstallLaunchResult.failed =>
          'Could not open Apple setup. Use the QR code or manual entry below.',
      };
    });
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    await ref.read(userEsimsControllerProvider.notifier).refresh();
    if (mounted) {
      setState(() {
        _busy = false;
        _sameDevice = false;
        _notice =
            'Refresh requested. Provider updates can take time; a request does not confirm installation.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(authControllerProvider).value?.id;
    if (owner == null || owner != widget.esim.userId) {
      return _unavailable(
        'Sign in to the owning account to view installation details.',
      );
    }
    final saved = ref.watch(userEsimsControllerProvider);
    final current = saved.value
        ?.where((p) => p.id == widget.esim.id && p.userId == owner)
        .firstOrNull;
    if (saved.hasValue && current == null) {
      return _unavailable('This eSIM is unavailable for this account.');
    }
    // The already-loaded owner snapshot remains renderable when offline. Never
    // persist credentials in preferences or send QR contents to an image service.
    final profile = current ?? widget.esim;
    final policy = EsimInstallationPolicy.forProfile(profile);
    final reveal = policy.mayReveal(sameDeviceConfirmed: _sameDevice);
    final environment = ref.watch(esimInstallationEnvironmentProvider).value;
    final payload = reveal ? profile.activationPayload : null;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('eSIM installation & recovery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(profile.bundleName, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Installation: ${profile.installationLabel}'),
          Text(policy.message, key: const ValueKey('installation-policy')),
          const SizedBox(height: 16),
          _section('Before you install', [
            Text(
              profile.facts.activationLabel == 'Not provided'
                  ? 'Activation trigger: not provided. Contact KeepSIMs support if you need to control when validity starts.'
                  : profile.facts.activationLabel,
            ),
            Text(
              profile.activationDeadlineAt == null
                  ? 'Activation deadline: not confirmed.'
                  : 'Activation deadline: ${MaterialLocalizations.of(context).formatMediumDate(profile.activationDeadlineAt!.toLocal())}',
            ),
            const Text(
              'Check eSIM support and carrier unlock in your phone settings. Model, market and carrier restrictions can apply.',
            ),
            const Text(
              'Keep your primary SIM for calls and SMS. Select this travel eSIM for mobile data; disable automatic data switching where available to avoid using your primary SIM for data.',
            ),
            const Text(
              'Displaying an already-loaded QR code works offline. Installation and recovery require an internet connection, such as Wi-Fi.',
            ),
          ]),
          if (policy.state == EsimInstallationState.sameDeviceRecovery)
            CheckboxListTile(
              value: _sameDevice,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _sameDevice = value == true),
              title: const Text(
                'This is the same device on which this eSIM was originally installed.',
              ),
              subtitle: const Text(
                'The original code is for same-device recovery only. KeepSIMs cannot verify the device match for you.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
          if (payload != null) ...[
            if (environment?.supportsAppleLink == true) ...[
              FilledButton.icon(
                onPressed: _busy ? null : () => _open(profile),
                icon: const Icon(Icons.phone_iphone),
                label: Text(
                  policy.state == EsimInstallationState.sameDeviceRecovery
                      ? 'Open Apple setup for recovery'
                      : 'Open Apple eSIM setup',
                ),
              ),
              const Text(
                'Requires an unlocked, eSIM-capable iPhone with iOS 17.4 or later and internet access. Opening setup does not mark this eSIM installed.',
              ),
            ] else
              const Text(
                'Use QR or manual entry below. Apple setup links are available on supported iPhones with iOS 17.4 or later.',
              ),
            const SizedBox(height: 16),
            _section('QR installation', [
              const Text(
                'Show this screen on a second device for the phone that will use the eSIM to scan. A phone cannot scan its own display with its camera.',
              ),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: payload.value,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const Text(
                'Generated on this device from your loaded activation details. Never share the code; sharing is not a device transfer or family data sharing.',
              ),
            ]),
            _section('Manual entry', [
              _copyTile(profile, 'SM-DP+ address', payload.smdpAddress),
              _copyTile(
                profile,
                'Activation code (matching ID)',
                payload.matchingId,
              ),
              TextButton(
                onPressed: () =>
                    _copy(profile, 'Complete activation string', payload.value),
                child: const Text(
                  'Copy complete activation string if requested',
                ),
              ),
            ]),
          ],
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_notice!, key: const ValueKey('installation-notice')),
            ),
          _section('Phone setup', [
            if (environment?.platform != EsimInstallPlatform.android)
              const Text(
                'iPhone: Settings > Cellular or Mobile Service > Add eSIM > Use QR Code. For manual entry, choose Enter Details Manually and enter the SM-DP+ address and activation code.',
              ),
            if (environment?.platform != EsimInstallPlatform.ios)
              const Text(
                'Android: Settings > Network & internet > SIMs > Add eSIM. On Samsung, try Settings > Connections > SIM manager > Add eSIM. Menu names vary by model. Choose QR scanning or manual entry.',
              ),
            const Text(
              'After setup, enable the travel eSIM and select it for mobile data. Follow the supplied plan instructions for data roaming on this eSIM; keep data roaming off on your primary SIM.',
            ),
            Text(
              'Plan APN: ${profile.facts.text('apn') ?? 'Not provided. Leave automatic settings in place and contact support if data does not connect.'}',
            ),
            if (profile.facts.text('help_text') case final help?)
              Text('Plan instructions: ${_safeHelp(help)}'),
          ]),
          _section('Connection and recovery help', [
            const Text(
              'If the profile is installed, check that it is enabled, selected for mobile data, and within its coverage and validity. Check the supplied APN and roaming instructions. Do not delete an installed profile as a troubleshooting step.',
            ),
            const Text(
              'A deleted eSIM may be recoverable on its original device after a fresh status check. Expired, suspended, unknown or unverified profiles need support review. Do not use the code on another device; a shared code does not transfer the eSIM.',
            ),
            OutlinedButton(
              onPressed: _busy ? null : _refresh,
              child: const Text('Refresh profile status'),
            ),
            TextButton(
              onPressed: () => context.push('/support'),
              child: const Text('Contact KeepSIMs support'),
            ),
          ]),
        ],
      ),
    );
  }

  String _safeHelp(String value) {
    final clean = value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');
    return clean.length > 1500 ? clean.substring(0, 1500) : clean;
  }

  Widget _unavailable(String message) => Scaffold(
    appBar: AppBar(title: const Text('eSIM installation')),
    body: Center(
      child: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
    ),
  );
  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final child in children)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: child),
        ],
      ),
    ),
  );
  Widget _copyTile(UserEsim profile, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      SelectableText(value),
      TextButton.icon(
        onPressed: () => _copy(profile, label, value),
        icon: const Icon(Icons.copy),
        label: Text('Copy $label'),
      ),
    ],
  );
}
