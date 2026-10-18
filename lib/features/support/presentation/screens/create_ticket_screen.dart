import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

import '../providers/support_providers.dart';
import '../../data/repositories/support_repository_impl.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';

class CreateTicketScreen extends ConsumerStatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String _category = 'general';
  SimLine? _selectedSimLine;
  bool _isSubmitting = false;
  final List<Map<String, dynamic>> _attachments = [];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(supportRepositoryProvider);
      final attachment = await repo.uploadFileAttachment(
        file: File(pickedFile.path),
        fileName: pickedFile.name,
      );
      setState(() {
        _attachments.add(attachment);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _attachLineLogs(SimLine line) async {
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(supportRepositoryProvider);
      final attachment = await repo.exportLineActivityLogsAttachment(
        simLineId: line.id,
        phoneNumber: line.phoneNumber,
      );
      setState(() {
        _attachments.add(attachment);
        _selectedSimLine = line;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export activity logs: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final ticket = await ref
          .read(supportTicketsProvider.notifier)
          .createTicket(
            subject: _subjectController.text.trim(),
            category: _category,
            simLineId: _selectedSimLine?.id,
            initialMessage: _messageController.text.trim(),
            attachments: _attachments,
          );

      if (mounted) {
        context.replace('/support/${ticket.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating ticket: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    final simLinesAsync = ref.watch(simLinesControllerProvider);

    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        title: Text(loc.createSupportTicket),
        elevation: 0,
        backgroundColor: context.surfaceColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Picker
              Text(
                loc.ticketCategoryLabel,
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'general',
                    child: Text(loc.ticketCategoryGeneral),
                  ),
                  DropdownMenuItem(
                    value: 'billing',
                    child: Text(loc.ticketCategoryBilling),
                  ),
                  DropdownMenuItem(
                    value: 'technical',
                    child: Text(loc.ticketCategoryTechnical),
                  ),
                  DropdownMenuItem(
                    value: 'refill_issue',
                    child: Text(loc.ticketCategoryRefillIssue),
                  ),
                  DropdownMenuItem(
                    value: 'account',
                    child: Text(loc.ticketCategoryAccount),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 16),

              // Subject Input
              Text(
                loc.ticketSubjectLabel,
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  hintText: loc.ticketSubjectHint,
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a subject';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Message Input
              Text(
                loc.ticketMessageLabel,
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: loc.ticketMessageHint,
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a message';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Attachments Header & Action Buttons
              Text(
                loc.attachedFiles,
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _pickImage,
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: Text(loc.attachImage),
                  ),
                  const SizedBox(width: 12),
                  simLinesAsync.when(
                    data: (lines) {
                      if (lines.isEmpty) return const SizedBox.shrink();
                      return PopupMenuButton<SimLine>(
                        onSelected: _attachLineLogs,
                        itemBuilder: (context) {
                          return lines.map((line) {
                            return PopupMenuItem<SimLine>(
                              value: line,
                              child: Text(
                                (line.nickname != null && line.nickname!.isNotEmpty)
                                    ? '${line.nickname} (${line.phoneNumber})'
                                    : line.phoneNumber,
                              ),
                            );
                          }).toList();
                        },
                        child: OutlinedButton.icon(
                          onPressed: null, // PopupMenuButton handles tap
                          icon: const Icon(Icons.shield_outlined, size: 18),
                          label: Text(loc.attachActivityLogs),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Attachment Chips List
              if (_attachments.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _attachments.map((att) {
                    return Chip(
                      avatar: Icon(
                        att['type'] == 'activity_log'
                            ? Icons.description
                            : Icons.image,
                        size: 16,
                      ),
                      label: Text(att['name'] ?? 'File'),
                      onDeleted: () {
                        setState(() {
                          _attachments.remove(att);
                        });
                      },
                    );
                  }).toList(),
                ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          loc.submitTicket,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
