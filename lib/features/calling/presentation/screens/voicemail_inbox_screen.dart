/// KeepSIMs — Visual Voicemail Inbox Screen
///
/// Features:
/// 1. Real visual voicemail list with caller, date, unread indicator, and duration
/// 2. Genuine audio playback via `VoicemailPlaybackNotifier` (video_player)
/// 3. Scrubbable progress bar and playback speed toggle
/// 4. Full transcript display and honest processing statuses
/// 5. Conditional AI sections (only rendered when backed by genuine stored data)
/// 6. One-tap "Call Back" via KeepSIMs Smart Call
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/calling/data/models/voicemail_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/controllers/voicemail_playback_controller.dart';

final voicemailsProvider =
    FutureProvider.autoDispose<List<VoicemailMessage>>((ref) async {
  return ref.watch(callingRepositoryProvider).getVoicemails();
});

class VoicemailInboxScreen extends ConsumerStatefulWidget {
  final String? initialVoicemailId;

  const VoicemailInboxScreen({super.key, this.initialVoicemailId});

  @override
  ConsumerState<VoicemailInboxScreen> createState() =>
      _VoicemailInboxScreenState();
}

class _VoicemailInboxScreenState extends ConsumerState<VoicemailInboxScreen> {
  String? _expandedVoicemailId;

  @override
  void initState() {
    super.initState();
    if (widget.initialVoicemailId != null) {
      _expandedVoicemailId = widget.initialVoicemailId;
    }
  }


  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final voicemailsAsync = ref.watch(voicemailsProvider);
    final playbackState = ref.watch(voicemailPlaybackControllerProvider);
    final playbackNotifier =
        ref.read(voicemailPlaybackControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KeepSIMs Smart Calling',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              'Voicemail Inbox',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          voicemailsAsync.maybeWhen(
            data: (messages) {
              final unreadCount = messages.where((m) => !m.isRead).length;
              if (unreadCount == 0) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$unreadCount New',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: voicemailsAsync.when(
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
                        child: const Icon(
                          Icons.voicemail_rounded,
                          size: 48,
                          color: Colors.purpleAccent,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No Voicemail Messages',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'When callers leave a voicemail on your KeepSIMs numbers, they will appear here with audio playback and transcripts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: messages.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final message = messages[index];
                final isExpanded = _expandedVoicemailId == message.id;
                final isCurrentPlaying =
                    playbackState.activeVoicemailId == message.id;

                final callerTitle = message.callerName?.isNotEmpty == true
                    ? message.callerName!
                    : message.callerNumber;

                final formattedDate =
                    DateFormat.yMMMd().add_jm().format(message.createdAt);

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: !message.isRead
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : isExpanded
                              ? const Color(0xFF818CF8).withValues(alpha: 0.4)
                              : AppColors.darkBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Collapsed Card Tap Target
                      InkWell(
                        onTap: () {
                          HapticHelper.lightTick();
                          setState(() {
                            _expandedVoicemailId =
                                isExpanded ? null : message.id;
                          });
                          if (!message.isRead) {
                            ref
                                .read(callingRepositoryProvider)
                                .markVoicemailRead(message.id);
                            ref.invalidate(voicemailsProvider);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              // Unread indicator dot
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

                              // Avatar
                              CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    Colors.purpleAccent.withValues(alpha: 0.15),
                                child: Text(
                                  callerTitle.isNotEmpty
                                      ? callerTitle[0].toUpperCase()
                                      : 'V',
                                  style: const TextStyle(
                                    color: Colors.purpleAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Caller & Preview
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            callerTitle,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: !message.isRead
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          message.durationDisplay,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                      ),
                                    ),
                                    if (!isExpanded &&
                                        message.transcript != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        message.transcript!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: Colors.white38,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Expanded Detail View (Image 5)
                      if (isExpanded) ...[
                        const Divider(color: Colors.white12, height: 1),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Real Audio Player Controls
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        // Play / Pause Button
                                        if (isCurrentPlaying &&
                                            playbackState.isBuffering)
                                          const SizedBox(
                                            width: 36,
                                            height: 36,
                                            child: Padding(
                                              padding: EdgeInsets.all(8),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          )
                                        else
                                          IconButton(
                                            icon: Icon(
                                              isCurrentPlaying &&
                                                      playbackState.isPlaying
                                                  ? Icons.pause_circle_filled_rounded
                                                  : Icons.play_circle_filled_rounded,
                                              color: AppColors.primary,
                                              size: 38,
                                            ),
                                            onPressed: () {
                                              playbackNotifier.togglePlay(
                                                voicemailId: message.id,
                                                audioUrl: message.audioUrl,
                                                fallbackDurationSeconds:
                                                    message.durationSeconds,
                                              );
                                            },
                                          ),
                                        const SizedBox(width: 4),

                                        // Scrubbable Progress Bar
                                        Expanded(
                                          child: SliderTheme(
                                            data:
                                                SliderTheme.of(context).copyWith(
                                              trackHeight: 4,
                                              activeTrackColor:
                                                  AppColors.primary,
                                              inactiveTrackColor: Colors.white12,
                                              thumbColor: AppColors.primary,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                enabledThumbRadius: 6,
                                              ),
                                              overlayShape:
                                                  const RoundSliderOverlayShape(
                                                overlayRadius: 12,
                                              ),
                                            ),
                                            child: Slider(
                                              value: isCurrentPlaying &&
                                                      playbackState.duration >
                                                          Duration.zero
                                                  ? (playbackState
                                                              .position
                                                              .inMilliseconds /
                                                          playbackState
                                                              .duration
                                                              .inMilliseconds)
                                                      .clamp(0.0, 1.0)
                                                  : 0.0,
                                              onChanged: (fraction) {
                                                if (isCurrentPlaying &&
                                                    playbackState.duration >
                                                        Duration.zero) {
                                                  final targetMs = (fraction *
                                                          playbackState
                                                              .duration
                                                              .inMilliseconds)
                                                      .round();
                                                  playbackNotifier.seek(
                                                    Duration(
                                                      milliseconds: targetMs,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ),

                                        // Playback Speed Toggle
                                        InkWell(
                                          onTap: isCurrentPlaying
                                              ? () => playbackNotifier
                                                  .cyclePlaybackSpeed()
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white10,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isCurrentPlaying
                                                  ? '${playbackState.playbackSpeed.toStringAsFixed(playbackState.playbackSpeed % 1 == 0 ? 0 : 2)}x'
                                                  : '1x',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            isCurrentPlaying
                                                ? _formatDuration(
                                                    playbackState.position,
                                                  )
                                                : '00:00',
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 10,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          Text(
                                            isCurrentPlaying &&
                                                    playbackState.duration >
                                                        Duration.zero
                                                ? _formatDuration(
                                                    playbackState.duration,
                                                  )
                                                : message.durationDisplay,
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 10,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCurrentPlaying &&
                                        playbackState.errorMessage != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        playbackState.errorMessage!,
                                        style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Transcript Section
                              const Text(
                                'TRANSCRIPT',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  message.transcript?.isNotEmpty == true
                                      ? message.transcript!
                                      : 'No transcript available for this recording.',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                              ),

                              // Optional Genuine AI Sections (Truthful Disclose: Only if present)
                              if (message.aiSummary != null &&
                                  message.aiSummary!.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const Text(
                                  'AI SUMMARY',
                                  style: TextStyle(
                                    color: Color(0xFF818CF8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF818CF8)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF818CF8)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    message.aiSummary!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],

                              if (message.translation != null &&
                                  message.translation!.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const Text(
                                  'TRANSLATION',
                                  style: TextStyle(
                                    color: Colors.purpleAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.purpleAccent
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.purpleAccent
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    message.translation!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 14),

                              // Call Back Action Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF22C55E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.phone_forwarded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Call Back (${message.callerNumber})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  onPressed: () {
                                    context.go(
                                      '${AppRoutes.calling}?number=${Uri.encodeComponent(message.callerNumber)}',
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading voicemails: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(voicemailsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
