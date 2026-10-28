import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_delivery_screen.dart';
import 'package:keep_sims/features/esim/presentation/widgets/esim_profile_card.dart';
import 'package:keep_sims/features/notifications/presentation/widgets/notification_permission_control.dart';

/// Resolve notification IDs from the signed-in owner's retail projections.
/// Push payloads never contain activation material or establish ownership.
class EsimAlertTargetScreen extends ConsumerWidget {
  const EsimAlertTargetScreen({
    super.key,
    required this.id,
    this.isOrder = false,
  });
  final String id;
  final bool isOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = ref.watch(authControllerProvider).value?.id;
    if (ownerId == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view your eSIM.')),
      );
    }
    final profiles = ref.watch(userEsimsControllerProvider);
    final orders = isOrder
        ? ref.watch(esimOrderHistoryControllerProvider)
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(isOrder ? 'eSIM order' : 'Your eSIM')),
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(userEsimsControllerProvider),
            child: const Text('Could not load your eSIM. Try again'),
          ),
        ),
        data: (owned) {
          final matches = owned
              .where(
                (p) =>
                    p.userId == ownerId &&
                    (isOrder ? p.esimOrderId == id : p.id == id),
              )
              .toList();
          final order = orders?.value
              ?.where((o) => o.id == id && o.userId == ownerId)
              .firstOrNull;
          if (isOrder && orders!.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (isOrder && orders!.hasError) {
            return Center(
              child: TextButton(
                onPressed: () =>
                    ref.invalidate(esimOrderHistoryControllerProvider),
                child: const Text('Could not load your order. Try again'),
              ),
            );
          }
          if ((isOrder && order == null) || (!isOrder && matches.isEmpty)) {
            return const Center(
              child: Text('This eSIM is unavailable for this account.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (order != null) ...[
                Text(
                  order.bundleName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  order.deliveryState == 'support_required'
                      ? 'Your order needs a support review. No refund is confirmed.'
                      : 'Order status: ${order.status}',
                ),
                if (matches.isEmpty)
                  const Text('Profile details are still being verified.'),
              ],
              for (final profile in matches)
                EsimProfileCard(
                  profile: profile,
                  onInstall: () => EsimDeliveryScreen.show(context, profile),
                  onBuyNew: () => context.push('/esim/plans'),
                ),
              const Text(
                'Recharge is not available yet. Buying a new eSIM creates a separate profile.',
              ),
              const SizedBox(height: 16),
              const NotificationPermissionControl(),
              const Text(
                'You can also review eSIM alerts in your KeepSIMs notification inbox.',
              ),
            ],
          );
        },
      ),
    );
  }
}
