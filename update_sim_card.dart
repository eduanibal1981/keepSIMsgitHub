import 'dart:io';

void main() {
  final file = File('lib/features/sim_lines/presentation/widgets/sim_line_card.dart');
  final content = file.readAsStringSync();
  
  final startStr = 'Widget _buildAutoRefillSection(';
  final startIndex = content.indexOf(startStr);
  
  if (startIndex == -1) {
    print("Could not find start string");
    return;
  }
  
  // Find the end of the method. The method ends right before the closing brace of the class.
  // We can just find `  }\n}` at the end of the file, or use a custom parser.
  // Actually, we can just replace the whole file from `Widget _buildAutoRefillSection` to the end of the file.
  final newMethod = '''
  Widget _buildAutoRefillSection(
    BuildContext context,
    WidgetRef ref,
    SimLine line,
    ScheduledTopup? schedule,
    bool isPremium,
  ) {
    if (!isPremium) {
      // Locked for Free/Standard
      return GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: context.isDarkMode
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-Refill: Locked 🔒',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.onSurfaceColor.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Available on Premium Plan. Upgrade now to fully automate SIM renewal.',
                    style: AppTextStyles.caption.copyWith(
                      color: context.onSurfaceColor.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                await HapticHelper.mediumImpact();
                SubscriptionUpsellSheet.show(
                  context: context,
                  title: 'Auto-Refill Locked 🔒',
                  description:
                      'Auto-Refill executes automatically with secure top-up and is exclusive to Premium users. Upgrade now to fully automate SIM renewal!',
                  requiredPlan: 'Premium Plan',
                  highlights: [
                    'Unlimited high-speed SIM protection lines',
                    'Zero-click Automated Auto-Refill executing balance updates',
                    'Direct balance API synchronization & validation',
                  ],
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Unlock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('MMM dd, yyyy');
    
    final includedNextRefillDate = line.validityExpiresAt != null 
        ? dateFormat.format(line.validityExpiresAt!.subtract(const Duration(days: 5)))
        : 'Unknown';

    final includedCard = GlassCard(
      padding: const EdgeInsets.all(12),
      isActive: false,
      activeColor: line.isPremiumAutoRefillActive ? AppColors.success : AppColors.textTertiaryDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Premium Keep-Alive Refill',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              Switch(
                value: line.isPremiumAutoRefillActive,
                onChanged: (val) {
                  ref.read(simLinesControllerProvider.notifier).updateSimLine(
                    line.copyWith(isPremiumAutoRefillActive: val),
                  );
                },
                activeColor: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            line.isPremiumAutoRefillActive 
                ? 'Auto-refill included - ~3.5 USD (telecom, VAT included) every 85 days, next refill on \$includedNextRefillDate'
                : 'Premium keep-alive refill is currently disabled.',
            style: AppTextStyles.caption.copyWith(color: context.onSurfaceColor.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );

    final bool isConfigured = schedule != null;
    final bool isPaused = schedule != null && !schedule.isActive;

    final cardColor = !isConfigured
        ? AppColors.textTertiaryDark
        : (isPaused ? AppColors.warning : AppColors.secondary);
    final statusIcon = !isConfigured
        ? Icons.add_circle_outline_rounded
        : (isPaused ? Icons.pause_circle_outline_rounded : Icons.verified_user);

    final statusText = !isConfigured
        ? 'Custom Auto-Refill'
        : (isPaused ? 'Custom Auto-Refill: Paused' : 'Custom Auto-Refill: Active');

    final subtitleText = !isConfigured
        ? 'Add an additional scheduled recharge amount.'
        : (isPaused
              ? 'Custom automatic refills are suspended'
              : '\\\$\${schedule.amount.toStringAsFixed(2)} USD refill every \${schedule.frequencyDays} days');

    final customCard = GlassCard(
      padding: const EdgeInsets.all(12),
      isActive: false,
      activeColor: cardColor,
      child: Column(
        children: [
          Row(
            children: [
              Icon(statusIcon, color: cardColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: AppTextStyles.caption.copyWith(
                        color: context.onSurfaceColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isConfigured
                      ? Icons.edit_rounded
                      : Icons.add_circle_outline_rounded,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ScheduledTopupSheet(
                      simLineId: line.id,
                      simNickname: line.nickname ?? line.phoneNumber,
                      existingSchedule: schedule,
                      configMode: 'refill',
                    ),
                  );
                },
                tooltip: isConfigured
                    ? 'Edit Custom Auto-Refill'
                    : 'Add Custom Auto-Refill',
              ),
            ],
          ),
          if (isConfigured) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaused
                            ? 'Resume renewal to enable'
                            : 'Next Custom Auto-Refill:',
                        style: AppTextStyles.caption.copyWith(
                          color: context.onSurfaceColor.withValues(alpha: 0.4),
                          fontSize: 10,
                        ),
                      ),
                      if (!isPaused) ...[
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(schedule.nextExecutionAt),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: context.onSurfaceColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return Column(
      children: [
        includedCard,
        const SizedBox(height: 12),
        customCard,
      ],
    );
  }
}
''';
  
  final newContent = content.substring(0, startIndex) + newMethod;
  file.writeAsStringSync(newContent);
  print("Updated _buildAutoRefillSection in sim_line_card.dart");
}
