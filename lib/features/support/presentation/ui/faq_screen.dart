import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQs & Troubleshooting'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frequently Asked Questions',
              style: AppTextStyles.headlineMedium.copyWith(
                color:
                    Theme.of(context).textTheme.bodyLarge?.color ??
                    Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildFaqItem(
              context,
              'How do I add a new SIM?',
              'You can add a new SIM line by navigating to the SIM Lines tab and tapping the "+" button in the top right corner.',
              isDark,
            ),
            _buildFaqItem(
              context,
              'What payment methods are supported?',
              'We currently support credit cards, debit cards, and Apple Pay/Google Pay via our secure payment processor.',
              isDark,
            ),
            _buildFaqItem(
              context,
              'How does offline refill work?',
              'If you have a Premium subscription, you can securely refill your SIM using SMS-based offline top-ups even without internet access.',
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(
    BuildContext context,
    String question,
    String answer,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: AppTextStyles.titleMedium.copyWith(
            color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            answer,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
