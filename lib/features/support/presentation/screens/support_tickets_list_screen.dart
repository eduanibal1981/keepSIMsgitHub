import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

import '../providers/support_providers.dart';
import '../../data/models/support_ticket_model.dart';

class SupportTicketsListScreen extends ConsumerWidget {
  const SupportTicketsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    final ticketsAsync = ref.watch(supportTicketsProvider);

    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        title: Text(loc.supportTicketsTitle),
        elevation: 0,
        backgroundColor: context.surfaceColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/support/new'),
        backgroundColor:
            isDark ? AppColors.primaryLight : AppColors.lightPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          loc.createSupportTicket,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(supportTicketsProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.supportTicketsSubtitle,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 20),
              ticketsAsync.when(
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.support_agent_outlined,
                              size: 64,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              loc.supportTicketsEmpty,
                              style: AppTextStyles.titleMedium.copyWith(
                                color: context.onSurfaceColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tickets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final ticket = tickets[index];
                      return _TicketCard(ticket: ticket);
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text(
                      'Error loading tickets: $err',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;

  const _TicketCard({required this.ticket});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.info;
      case 'pending':
        return AppColors.warning;
      case 'resolved':
      case 'closed':
        return AppColors.success;
      default:
        return AppColors.textSecondaryLight;
    }
  }

  String _getStatusText(BuildContext context, String status) {
    final loc = AppLocalizations.of(context)!;
    switch (status) {
      case 'open':
        return loc.ticketStatusOpen;
      case 'pending':
        return loc.ticketStatusPending;
      case 'resolved':
        return loc.ticketStatusResolved;
      case 'closed':
        return loc.ticketStatusClosed;
      default:
        return status;
    }
  }

  String _getCategoryText(BuildContext context, String category) {
    final loc = AppLocalizations.of(context)!;
    switch (category) {
      case 'general':
        return loc.ticketCategoryGeneral;
      case 'billing':
        return loc.ticketCategoryBilling;
      case 'technical':
        return loc.ticketCategoryTechnical;
      case 'refill_issue':
        return loc.ticketCategoryRefillIssue;
      case 'account':
        return loc.ticketCategoryAccount;
      case 'feedback':
        return 'Feedback & Improvement';
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final statusColor = _getStatusColor(ticket.status);
    final dateStr = DateFormat('MMM dd, yyyy HH:mm').format(ticket.updatedAt);

    return Card(
      elevation: 0,
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => context.push('/support/${ticket.id}'),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ticket.subject,
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _getStatusText(context, ticket.status),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Row(
            children: [
              Text(
                _getCategoryText(context, ticket.category),
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDark
              ? AppColors.textTertiaryDark
              : AppColors.textTertiaryLight,
        ),
      ),
    );
  }
}
