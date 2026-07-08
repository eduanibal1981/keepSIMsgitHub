import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/widgets/error_state.dart';
import '../controllers/support_controller.dart';
import 'package:intl/intl.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsState = ref.watch(supportControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/support/create'),
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Open Ticket',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ticketsState.when(
        data: (tickets) {
          if (tickets.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final isClosed =
                  ticket.status == 'closed' || ticket.status == 'resolved';
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  onTap: () =>
                      context.push('/support/${ticket.id}', extra: ticket),
                  title: Text(
                    ticket.subject,
                    style: AppTextStyles.titleMedium.copyWith(
                      color:
                          Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Category: ${ticket.category}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created: ${ticket.createdAt != null ? DateFormat('MMM dd, yyyy').format(ticket.createdAt!) : ''}',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isClosed
                          ? Colors.grey.withValues(alpha: 0.15)
                          : AppColors.success.withValues(alpha: 0.15),
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
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorStateView(
          errorMessage: 'Failed to load tickets',
          errorDetails: error.toString(),
          onRetry: () => ref.invalidate(supportControllerProvider),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.support_agent_rounded,
            size: 64,
            color:
                Theme.of(context).iconTheme.color?.withValues(alpha: 0.2) ??
                Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No tickets found',
            style: AppTextStyles.titleLarge.copyWith(
              color:
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a ticket if you need assistance',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
