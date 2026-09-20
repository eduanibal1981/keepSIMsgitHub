/// KeepSIMs — Visual Voicemail Inbox Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/calling/data/models/voicemail_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';

final voicemailsProvider = FutureProvider.autoDispose<List<VoicemailMessage>>((ref) async {
  return ref.watch(callingRepositoryProvider).getVoicemails();
});

class VoicemailInboxScreen extends ConsumerStatefulWidget {
  const VoicemailInboxScreen({super.key});

  @override
  ConsumerState<VoicemailInboxScreen> createState() => _VoicemailInboxScreenState();
}

class _VoicemailInboxScreenState extends ConsumerState<VoicemailInboxScreen> {
  String? _expandedVoicemailId;
  String? _currentlyPlayingId;

  void _togglePlay(String id) {
    setState(() {
      if (_currentlyPlayingId == id) {
        _currentlyPlayingId = null;
      } else {
        _currentlyPlayingId = id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final voicemailsAsync = ref.watch(voicemailsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D141C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D141C),
        elevation: 0,
        title: const Text(
          'AI Voicemail Inbox',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: voicemailsAsync.when(
        data: (messages) {
          if (messages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.voicemail, size: 48, color: Colors.purpleAccent),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Voicemails Yet',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When callers leave a message on your Virtual DID, KeepSIMs AI transcribes and organizes them here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: messages.length,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final message = messages[index];
              final isExpanded = _expandedVoicemailId == message.id;
              final isPlaying = _currentlyPlayingId == message.id;

              return InkWell(
                onTap: () {
                  setState(() {
                    _expandedVoicemailId = isExpanded ? null : message.id;
                  });
                  if (!message.isRead) {
                    ref.read(callingRepositoryProvider).markVoicemailRead(message.id);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: !message.isRead
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : Colors.white12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (!message.isRead) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              message.callerName?.isNotEmpty == true
                                  ? message.callerName!
                                  : message.callerNumber,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            message.durationDisplay,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message.transcript ?? 'Audio message recorded',
                        maxLines: isExpanded ? 10 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      if (isExpanded) ...[
                        const Divider(color: Colors.white12, height: 24),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: AppColors.primary,
                                size: 36,
                              ),
                              onPressed: () => _togglePlay(message.id),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: LinearProgressIndicator(
                                value: 0.0,
                                backgroundColor: Colors.white12,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              message.durationDisplay,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Text('Error loading voicemails: $err', style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }
}
