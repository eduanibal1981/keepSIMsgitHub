import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_delivery_screen.dart';

class EsimOrderStatusModal extends ConsumerWidget {
  final String orderId;
  final String bundleName;

  const EsimOrderStatusModal({
    super.key,
    required this.orderId,
    required this.bundleName,
  });

  static Future<void> show(
    BuildContext context,
    String orderId,
    String bundleName,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          EsimOrderStatusModal(orderId: orderId, bundleName: bundleName),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(esimOrderLiveProvider(orderId));
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: orderAsync.when(
          data: (order) {
            final status = order?.status ?? 'pending';

            if (status == 'completed') {
              ref.watch(userEsimsControllerProvider);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Delivery confirmed. Installation is a separate step.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await ref
                          .read(userEsimsControllerProvider.notifier)
                          .refresh();
                      if (!context.mounted) return;
                      final profiles =
                          ref.read(userEsimsControllerProvider).value ?? [];
                      final matches = profiles.where(
                        (p) =>
                            p.esimOrderId == orderId && p.hasActivationPayload,
                      );
                      if (matches.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Installation details are still being verified. Check My eSIMs shortly.',
                            ),
                          ),
                        );
                        return;
                      }
                      final navigator = Navigator.of(context);
                      final profile = matches.first;
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => EsimDeliveryScreen(esim: profile),
                        ),
                      );
                    },
                    child: const Text('View installation'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              );
            }
            if (order?.deliveryState == 'support_required' ||
                order?.deliveryState == 'reconciling') {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    order?.deliveryState == 'support_required'
                        ? 'Delivery needs support review'
                        : 'Verifying provider delivery',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your order remains recorded. Please do not place it again while the provider outcome is being checked.',
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close and check My eSIMs later'),
                  ),
                ],
              );
            }

            if (status == 'failed') {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Order Fulfillment Failed',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order?.errorMessage ?? 'An unexpected error occurred.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Check your wallet receipt or contact support for the settlement status.',
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            // Pending or Processing
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.teal),
                const SizedBox(height: 20),
                Text(
                  'Preparing Your eSIM...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Checking delivery for $bundleName. Purchasing does not mean the eSIM is installed.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Check later'),
                ),
              ],
            );
          },
          loading: () => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to server...'),
            ],
          ),
          error: (err, stack) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning, color: Colors.amber, size: 48),
              const SizedBox(height: 12),
              Text('Error: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
