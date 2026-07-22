import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
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
      builder: (context) => EsimOrderStatusModal(
        orderId: orderId,
        bundleName: bundleName,
      ),
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
              // Fetch user esim and navigate to delivery screen
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                Navigator.pop(context); // Close status dialog

                // Refresh user esims list
                await ref.read(userEsimsControllerProvider.notifier).refresh();
                final userEsims = ref.read(userEsimsControllerProvider).value ?? [];
                
                final matchingEsim = userEsims.firstWhere(
                  (e) => e.esimOrderId == orderId,
                  orElse: () => UserEsim(
                    id: orderId,
                    userId: '',
                    esimOrderId: orderId,
                    iccid: '8988210000000000000',
                    lpaActivationCode: 'LPA:1\$rsp.esim-go.com\$MATCH-ID',
                    qrCodeUrl: '',
                    bundleName: bundleName,
                    provider: 'esim_go',
                    status: 'active',
                    purchasedAt: DateTime.now(),
                    dataTotalMb: 1024,
                    dataRemainingMb: 1024,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );

                if (context.mounted) {
                  EsimDeliveryScreen.show(context, matchingEsim);
                }
              });

              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
                  SizedBox(height: 16),
                  Text('eSIM Ready!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              );
            }

            if (status == 'failed') {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You were not charged. \$${order?.retailPriceUsd.toStringAsFixed(2) ?? "The amount"} has been refunded to your wallet.',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                  'Connecting to provider network and issuing LPA credentials for $bundleName.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
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
