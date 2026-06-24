import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import '../../data/models/support_ticket.dart';

class TicketDetailsScreen extends ConsumerWidget {
  final SupportTicket ticket;

  const TicketDetailsScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClosed = ticket.status == 'closed' || ticket.status == 'resolved';

    return Scaffold(
      appBar: AppBar(title: const Text('Ticket Details'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isClosed
                        ? Colors.grey.withOpacity(0.15)
                        : AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ticket.status.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isClosed ? Colors.grey : AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (ticket.createdAt != null)
                  Text(
                    DateFormat(
                      'MMM dd, yyyy • HH:mm',
                    ).format(ticket.createdAt!),
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Category: ${ticket.category}',
              style: AppTextStyles.labelSmall.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ticket.subject,
              style: AppTextStyles.headlineMedium.copyWith(
                color:
                    Theme.of(context).textTheme.bodyLarge?.color ??
                    Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              'Description',
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ticket.description,
              style: AppTextStyles.bodyMedium.copyWith(
                color:
                    Theme.of(context).textTheme.bodyLarge?.color ??
                    Colors.black,
                height: 1.5,
              ),
            ),
            if (ticket.attachmentUrl != null &&
                ticket.attachmentUrl!.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                'Attachment',
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  ticket.attachmentUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    width: double.infinity,
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
