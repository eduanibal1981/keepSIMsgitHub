import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';

class EsimDeliveryScreen extends StatelessWidget {
  final UserEsim esim;

  const EsimDeliveryScreen({super.key, required this.esim});

  static Future<void> show(BuildContext context, UserEsim esim) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EsimDeliveryScreen(esim: esim),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('eSIM Installation & QR'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bundle Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.teal, Color(0xFF004D40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esim.bundleName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Purchased ${esim.purchasedAt.toLocal().toString().split(" ")[0]}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // QR Code Section Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      'Scan QR Code to Install',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan this code from another device or print it out.',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Client-Side Generated QR Code (Offline Capable)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.teal.shade200, width: 2),
                      ),
                      child: QrImageView(
                        data: esim.lpaString,
                        version: QrVersions.auto,
                        size: 220.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Chip(
                      avatar: const Icon(Icons.wifi_off, size: 16, color: Colors.teal),
                      label: const Text(
                        'Renders Offline',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.teal.withOpacity(0.1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Manual Activation Details Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual Setup Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // SM-DP+ Address
                    _buildCopyableTile(
                      context: context,
                      label: 'SM-DP+ Address',
                      value: esim.smdpAddress,
                      icon: Icons.dns,
                    ),
                    const Divider(),

                    // Activation Code (Matching ID)
                    _buildCopyableTile(
                      context: context,
                      label: 'Activation Code (Matching ID)',
                      value: esim.matchingId,
                      icon: Icons.vpn_key,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Platform Install Guides
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.help_outline, color: Colors.teal),
                        const SizedBox(width: 8),
                        Text(
                          'How to Install',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInstallStep(
                      stepNumber: '1',
                      title: 'iOS (iPhone)',
                      description:
                          'Go to Settings > Cellular > Add eSIM > Use QR Code.',
                    ),
                    const SizedBox(height: 8),
                    _buildInstallStep(
                      stepNumber: '2',
                      title: 'Android',
                      description:
                          'Go to Settings > Network & Internet > SIMs > Add eSIM > Scan QR Code.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyableTile({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.teal),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy, color: Colors.teal),
        onPressed: () => _copyToClipboard(context, label, value),
      ),
    );
  }

  Widget _buildInstallStep({
    required String stepNumber,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Colors.teal.withOpacity(0.2),
          child: Text(
            stepNumber,
            style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}
