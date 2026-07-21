import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

import '../providers/support_providers.dart';
import '../../data/repositories/support_repository_impl.dart';
import '../../data/models/ticket_message_model.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  final String ticketId;

  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  final List<Map<String, dynamic>> _attachments = [];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isSending = true);
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
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await ref.read(supportRepositoryProvider).sendMessage(
            ticketId: widget.ticketId,
            message: text,
            attachments: List.from(_attachments),
          );

      _messageController.clear();
      setState(() {
        _attachments.clear();
      });

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _closeTicket() async {
    try {
      await ref
          .read(supportTicketsProvider.notifier)
          .closeTicket(widget.ticketId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket closed successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error closing ticket: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    final ticketDetailAsync = ref.watch(supportTicketDetailProvider(widget.ticketId));
    final messagesStreamAsync = ref.watch(ticketMessagesStreamProvider(widget.ticketId));

    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        title: Text(loc.supportTicketsTitle),
        elevation: 0,
        backgroundColor: context.surfaceColor,
        actions: [
          ticketDetailAsync.when(
            data: (ticket) {
              if (ticket.isClosed) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: _closeTicket,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text(loc.closeTicketButton),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: ticketDetailAsync.when(
        data: (ticket) {
          return Column(
            children: [
              // Ticket Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ticket.subject,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: context.onSurfaceColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: ticket.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Category: ${ticket.category.toUpperCase()} • Created: ${DateFormat('MMM dd, yyyy').format(ticket.createdAt)}',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),

              // Messages Stream List
              Expanded(
                child: messagesStreamAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const Center(child: Text('No messages yet.'));
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return _MessageBubble(message: msg);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
              ),

              // Closed Banner or Reply Input Bar
              if (ticket.isClosed)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  child: Text(
                    loc.ticketClosedNotice,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                _buildInputBar(loc, isDark),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Failed to load ticket: $err')),
      ),
    );
  }

  Widget _buildInputBar(AppLocalizations loc, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_attachments.isNotEmpty)
              Container(
                height: 40,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _attachments.map((att) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        label: Text(att['name'] ?? 'File', style: const TextStyle(fontSize: 12)),
                        onDeleted: () {
                          setState(() {
                            _attachments.remove(att);
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.attach_file,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  onPressed: _isSending ? null : _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: loc.typeMessageHint,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.send,
                          color: isDark
                              ? AppColors.primaryLight
                              : AppColors.lightPrimary,
                        ),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    Color color = AppColors.info;
    String label = loc.ticketStatusOpen;

    if (status == 'pending') {
      color = AppColors.warning;
      label = loc.ticketStatusPending;
    } else if (status == 'resolved') {
      color = AppColors.success;
      label = loc.ticketStatusResolved;
    } else if (status == 'closed') {
      color = AppColors.textSecondaryLight;
      label = loc.ticketStatusClosed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final TicketMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final isUser = message.isUser;
    final timeStr = DateFormat('HH:mm').format(message.createdAt);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.all(12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? (isDark ? AppColors.primaryLight : AppColors.lightPrimary)
              : (isDark ? AppColors.darkSurface : Colors.grey.shade200),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.headset_mic_outlined,
                    size: 14,
                    color: isDark ? AppColors.secondary : AppColors.lightSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Support Team',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.secondary : AppColors.lightSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message.message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isUser
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),

            // Attachments Preview
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: message.attachments.map((att) {
                  final url = att['url']?.toString();
                  final name = att['name']?.toString() ?? 'Attachment';
                  final isLog = att['type'] == 'activity_log' || name.endsWith('.txt');

                  return InkWell(
                    onTap: () async {
                      if (url != null) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.15)
                            : (isDark ? Colors.black26 : Colors.white),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLog ? Icons.description_outlined : Icons.image_outlined,
                            size: 16,
                            color: isUser
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 12,
                                color: isUser
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.black87),
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: isUser
                      ? Colors.white70
                      : (isDark ? Colors.white38 : Colors.black45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
