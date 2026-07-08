import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import '../controllers/support_controller.dart';

class CreateTicketScreen extends ConsumerStatefulWidget {
  final String? initialCategory;

  const CreateTicketScreen({super.key, this.initialCategory});

  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  late String _selectedCategory;
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _attachment;
  bool _isSubmitting = false;

  String _getTranslatedCategory(BuildContext context, String cat) {
    final local = AppLocalizations.of(context)!;
    switch (cat) {
      case 'Technical Support':
        return local.techSupportCategory;
      case 'Billing & Wallet':
        return local.billingWalletCategory;
      case 'SIM Lines Management':
        return local.simLinesCategory;
      case 'Feedback & Other':
        return local.feedbackOtherCategory;
      default:
        return cat;
    }
  }

  final List<String> _categories = [
    'Technical Support',
    'Billing & Wallet',
    'SIM Lines Management',
    'Feedback & Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? _categories.first;
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = _categories.first;
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _attachment = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitTicket() async {
    if (_subjectController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseFillFields),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(supportControllerProvider.notifier)
          .submitTicket(
            subject: _subjectController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _selectedCategory,
            attachment: _attachment,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.ticketSubmittedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.openTicket),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.categoryLabel,
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark
                    ? Colors.black.withValues(alpha: 0.15)
                    : const Color(0xFFEAEEF1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(_getTranslatedCategory(context, c)),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 20),

            Text(
              AppLocalizations.of(context)!.subjectLabel,
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.subjectHint,
                filled: true,
                fillColor: isDark
                    ? Colors.black.withValues(alpha: 0.15)
                    : const Color(0xFFEAEEF1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              AppLocalizations.of(context)!.descriptionLabel,
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.descriptionHint,
                filled: true,
                fillColor: isDark
                    ? Colors.black.withValues(alpha: 0.15)
                    : const Color(0xFFEAEEF1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              AppLocalizations.of(context)!.attachmentLabel,
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _attachment != null
                    ? Row(
                        children: [
                          const Icon(Icons.image, color: Colors.blueAccent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _attachment!.path.split('/').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => setState(() => _attachment = null),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_photo_alternate_rounded,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.uploadScreenshot,
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        AppLocalizations.of(context)!.submitTicketButton,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
