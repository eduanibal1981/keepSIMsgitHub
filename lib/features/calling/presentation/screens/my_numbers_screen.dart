/// KeepSIMs — My Virtual DID Numbers Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/calling/data/models/virtual_did_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/widgets/roaming_forwarding_wizard_sheet.dart';
import 'package:keep_sims/features/calling/presentation/widgets/calling_mode_switcher.dart';

final virtualDidsProvider = FutureProvider.autoDispose<List<VirtualDidNumber>>((ref) async {
  return ref.watch(callingRepositoryProvider).getVirtualDids();
});

class MyNumbersScreen extends ConsumerWidget {
  const MyNumbersScreen({super.key});

  void _showForwardingOptions(BuildContext context, WidgetRef ref, VirtualDidNumber did) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Route Inbound Calls To:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.phone_iphone, color: AppColors.primary),
              title: const Text('KeepSIMs In-App (VoIP)', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Rings inside this app over data/Wi-Fi (Free)', style: TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: did.forwardMode == 'app' ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(callingRepositoryProvider).updateDidForwarding(
                  didId: did.id,
                  forwardMode: 'app',
                );
                ref.invalidate(virtualDidsProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.voicemail, color: Colors.purpleAccent),
              title: const Text('Direct to AI Voicemail', style: TextStyle(color: Colors.white)),
              subtitle: const Text('AI receptionist answers and transcribes messages', style: TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: did.forwardMode == 'voicemail' ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(callingRepositoryProvider).updateDidForwarding(
                  didId: did.id,
                  forwardMode: 'voicemail',
                );
                ref.invalidate(virtualDidsProvider);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final didsAsync = ref.watch(virtualDidsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D141C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D141C),
        elevation: 0,
        title: const Text(
          'Virtual Numbers & Roaming',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const CallingModeSwitcher(activeMode: CallingMode.myNumbers),
            Expanded(
              child: didsAsync.when(
        data: (dids) {
          if (dids.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.dialer_sip, size: 48, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Virtual Numbers Yet',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A KeepSIMs Virtual Inbound DID lets you receive all your home carrier calls anywhere in the world without paying roaming fees.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: dids.length,
            separatorBuilder: (_, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final did = dids[index];
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(did.flagEmoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                did.phoneNumber,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              Text(
                                did.countryName,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Routing Mode:',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              did.forwardModeDisplay,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.tune, size: 16, color: AppColors.primary),
                          label: const Text('Change', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                          onPressed: () => _showForwardingOptions(context, ref, did),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.flight_takeoff, size: 18, color: AppColors.primary),
                        label: const Text(
                          'Zero-Roaming Forwarding Wizard',
                          style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => RoamingForwardingWizardSheet.show(context, did),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Text('Error loading numbers: $err', style: const TextStyle(color: AppColors.error)),
        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
