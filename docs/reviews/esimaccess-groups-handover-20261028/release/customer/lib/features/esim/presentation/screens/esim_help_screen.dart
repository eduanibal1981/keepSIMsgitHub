import 'package:flutter/material.dart';

class EsimHelpScreen extends StatelessWidget {
  const EsimHelpScreen({super.key});
  static Future<void> show(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const EsimHelpScreen()));
  static const topics = <String, String>{
    'Unable to install':
        'Open Installation & recovery on the exact eSIM. Use a compatible unlocked device and a stable connection. Keep the QR and activation code private. Do not delete an installed profile while troubleshooting; recovery can depend on the original device.',
    'Usage appears delayed':
        'Provider readings can be delayed. Last-known usage and its observation time remain visible. Refresh requests a backend check; unknown usage does not mean you have zero data.',
    'No recharge choices':
        'Recharge depends on the exact installed profile, its current state and compatible packages. A new eSIM purchase creates a separate profile. Day Pass extensions add days and do not restore today’s speed or allowance.',
    'Order or provider outcome pending':
        'A pending request may already have reached the provider. Check order history or contact support with the order ID. Do not buy again to resolve an uncertain result. Reserved funds stay protected until a result is verified.',
    'Cancellation or refund pending':
        'Only eligible unused profiles can be cancelled. Review the exact refund and original payer destination before confirming. Supplier cancellation and your wallet refund are separate confirmations; pending credit is not money already returned.',
    'Pause automatic recharge':
        'Use Service & auto recharge on the profile. Pausing prevents future submissions. A request already submitted remains pending until confirmed. Review your exact package, per-charge maximum, UTC monthly cap and end date before opting in again.',
    'Suspend versus expiry':
        'Suspension stops data service. Validity may continue to run. Resume does not extend expiry. Pausing automatic recharge is a separate control from suspending service.',
    'Traveller groups and partial delivery':
        'Each traveller receives a distinct profile with separate allowance, installation and status. The purchaser owns the profiles and pays each charge. A delivered member does not prove the others were issued. Keep pending members and their funds under review; retries of the same request adopt existing work.',
    'Supplier outage or account funding':
        'If an action is unavailable, keep the last confirmed state and check again later or contact support. Missing supplier health or funding information is unknown. Adding money to your wallet cannot resolve a supplier outage or prove an uncertain order failed.',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('eSIM help')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final topic in topics.entries)
          ExpansionTile(
            title: Text(topic.key),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(topic.value),
              ),
            ],
          ),
      ],
    ),
  );
}
