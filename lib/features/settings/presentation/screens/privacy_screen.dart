import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/settings/presentation/controllers/privacy_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  final _deleteConfirmController = TextEditingController();

  @override
  void dispose() {
    _deleteConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final privacyState = ref.watch(privacyControllerProvider);
    final deletionRecordAsync = ref.watch(accountDeletionRecordProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.dataAndPrivacy),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: privacyState.when(
        data: (trackingConsent) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  context,
                  AppLocalizations.of(context)!.legalPolicies,
                ),
                _buildPolicyCard(context, isDark),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  context,
                  AppLocalizations.of(context)!.dataPreferences,
                ),
                _buildConsentCard(context, trackingConsent, isDark),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  context,
                  AppLocalizations.of(context)!.yourData,
                ),
                _buildExportCard(context, isDark),
                const SizedBox(height: 36),
                deletionRecordAsync.when(
                  data: (record) {
                    if (record != null) {
                      return _buildScheduledDeletionCard(context, record, isDark);
                    }
                    return _buildDangerZone(context, isDark);
                  },
                  loading: () => _buildDangerZone(context, isDark),
                  error: (_, __) => _buildDangerZone(context, isDark),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            AppLocalizations.of(context)!.errorLoadingPrefs(error.toString()),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: AppTextStyles.titleMedium.copyWith(
          color: context.onSurfaceColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPolicyCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.legalPoliciesDesc,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              final url = Uri.parse('https://keepsims.com/privacy');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.privacyPolicyLoaded,
                      ),
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              AppLocalizations.of(context)!.readPrivacyPolicy,
              style: AppTextStyles.bodyMedium.copyWith(
                color: const Color(0xFF6366F1),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard(BuildContext context, bool consent, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.lightBorder,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          AppLocalizations.of(context)!.analyticsTracking,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: context.onSurfaceColor,
          ),
        ),
        subtitle: Text(
          AppLocalizations.of(context)!.analyticsTrackingDesc,
          style: AppTextStyles.bodySmall.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            height: 1.4,
          ),
        ),
        value: consent,
        activeThumbColor: const Color(0xFF10B981),
        onChanged: (value) {
          ref
              .read(privacyControllerProvider.notifier)
              .toggleTrackingConsent(value);
        },
      ),
    );
  }

  Widget _buildExportCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.lightBorder,
        ),
      ),
      child: ListTile(
        title: Text(
          AppLocalizations.of(context)!.exportMyData,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: context.onSurfaceColor,
          ),
        ),
        subtitle: Text(
          AppLocalizations.of(context)!.exportMyDataDesc,
          style: AppTextStyles.bodySmall.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        trailing: const Icon(Icons.download_rounded, color: Color(0xFF3B82F6)),
        onTap: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.preparingDataExport),
            ),
          );
          try {
            await ref.read(privacyControllerProvider.notifier).exportData();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.exportFailed(e.toString()),
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildScheduledDeletionCard(
    BuildContext context,
    Map<String, dynamic> record,
    bool isDark,
  ) {
    final purgeDateStr = record['scheduled_purge_at'] as String? ?? '';
    final purgeDateFormatted = purgeDateStr.length >= 10
        ? purgeDateStr.substring(0, 10)
        : purgeDateStr;
    final l = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.accountScheduledForDeletion,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l.deletionScheduledNotice(purgeDateFormatted),
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                try {
                  await ref
                      .read(privacyControllerProvider.notifier)
                      .cancelAccountDeletion();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account deletion request cancelled.'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orangeAccent,
                side: const BorderSide(color: Colors.orangeAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(l.cancelAccountDeletion),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.dangerZone,
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.deleteAccountWarning,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showDeleteConfirmation(context, isDark),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(AppLocalizations.of(context)!.deleteAccount),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, bool isDark) {
    _deleteConfirmController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        title: Text(
          AppLocalizations.of(context)!.deleteAccount,
          style: const TextStyle(color: Colors.redAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.deleteAccountIrreversible,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.typeDeleteToConfirm,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _deleteConfirmController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.deleteWord,
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
              ),
              onChanged: (val) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _deleteConfirmController,
            builder: (context, value, child) {
              final canDelete =
                  value.text == AppLocalizations.of(context)!.deleteWord;
              return ElevatedButton(
                onPressed: canDelete
                    ? () async {
                        Navigator.pop(ctx);
                        _performDeletion();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: Text(
                  AppLocalizations.of(context)!.confirmDeleteButton,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _performDeletion() async {
    // 1. PaymentAuthGuard (Biometric / Passcode confirmation)
    final authResult = await ref.read(paymentAuthGuardProvider.notifier).authenticate(
      reason: 'Confirm account deletion',
    );
    if (authResult == BiometricResult.cancelled || authResult == BiometricResult.failed) {
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(privacyControllerProvider.notifier).deleteAccount(forfeitDust: true);
      if (mounted) {
        Navigator.pop(context); // pop loading
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
