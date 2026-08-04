import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/dashboard/presentation/providers/promo_provider.dart';

/// I3 — the in-app half of a carrier-targeted campaign.
///
/// This is the surface that makes the feature work at all. The push half goes
/// out under the `promo` notification category, which is **opt-in and enabled
/// by nobody** — so an admin who only had push would be shouting into a void.
/// The card is a pull: the user opens the app and sees the offer for the
/// carrier they actually hold a line on.
///
/// Renders nothing at all when there is no live campaign, so it costs a
/// dashboard with no promos exactly one `SizedBox.shrink()`.
class PromoBanner extends ConsumerWidget {
  const PromoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promos = ref.watch(activePromosProvider).value ?? const [];
    if (promos.isEmpty) return const SizedBox.shrink();

    // One at a time. A stack of adverts on the home screen of a money app
    // reads as spam, and the server already returns them newest-first.
    final promo = promos.first;
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.14),
            AppColors.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  promo.carrierName == null
                      ? 'Offer'
                      : 'Offer for ${promo.carrierName}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              // Dismissal is permanent for this user — that is the whole point
              // of a promo they did not ask for.
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                tooltip: 'Dismiss',
                onPressed: () async {
                  await HapticHelper.lightTick();
                  await ref
                      .read(promoDismissalProvider.notifier)
                      .dismiss(promo.id);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            promo.title,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            promo.body,
            style: AppTextStyles.bodyMedium.copyWith(
              height: 1.4,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          if (promo.actionUrl != null && promo.actionUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                ),
                onPressed: () async {
                  await HapticHelper.lightTick();
                  if (!context.mounted) return;
                  // In-app routes only. An arbitrary external URL from a
                  // campaign row would be an open redirect on the home screen.
                  final url = promo.actionUrl!;
                  if (url.startsWith('/')) context.push(url);
                },
                child: Text(promo.ctaLabel ?? 'See the offer'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
