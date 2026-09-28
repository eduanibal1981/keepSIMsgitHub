import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/data/models/voicemail_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/controllers/voicemail_playback_controller.dart';
import 'package:keep_sims/features/calling/presentation/screens/voicemail_inbox_screen.dart';

class _FakeCallingRepository implements CallingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> markVoicemailRead(String voicemailId) async {}

  @override
  Future<List<VoicemailMessage>> getVoicemails({int limit = 50}) async => [];
}

void main() {
  group('VoicemailInboxScreen & Playback Controller Tests', () {
    test('VoicemailPlaybackNotifier speed cycling works', () {
      final container = ProviderContainer();
      final notifier =
          container.read(voicemailPlaybackControllerProvider.notifier);
      expect(
        container.read(voicemailPlaybackControllerProvider).playbackSpeed,
        equals(1.0),
      );

      notifier.cyclePlaybackSpeed();
      expect(
        container.read(voicemailPlaybackControllerProvider).playbackSpeed,
        equals(1.25),
      );

      notifier.cyclePlaybackSpeed();
      expect(
        container.read(voicemailPlaybackControllerProvider).playbackSpeed,
        equals(1.5),
      );

      notifier.cyclePlaybackSpeed();
      expect(
        container.read(voicemailPlaybackControllerProvider).playbackSpeed,
        equals(2.0),
      );

      notifier.cyclePlaybackSpeed();
      expect(
        container.read(voicemailPlaybackControllerProvider).playbackSpeed,
        equals(1.0),
      );

      container.dispose();
    });

    testWidgets(
        'VoicemailInboxScreen renders message and expands genuine audio controls',
        (tester) async {
      final mockVoicemail = VoicemailMessage(
        id: 'vm-test-01',
        callerNumber: '+96891234567',
        callerName: 'Ahmed Al-Harthi',
        audioUrl: 'https://example.com/recording.mp3',
        durationSeconds: 42,
        transcript: 'Hello, please call me back when you get a chance.',
        language: 'en',
        status: 'transcribed',
        isRead: false,
        createdAt: DateTime(2026, 9, 23, 14, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voicemailsProvider.overrideWith((ref) async => [mockVoicemail]),
            callingRepositoryProvider.overrideWithValue(_FakeCallingRepository()),
          ],
          child: const MaterialApp(
            home: VoicemailInboxScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header & unread indicator
      expect(find.text('KeepSIMs Smart Calling'), findsOneWidget);
      expect(find.text('Voicemail Inbox'), findsOneWidget);
      expect(find.text('1 New'), findsOneWidget);

      // Verify collapsed message card
      expect(find.text('Ahmed Al-Harthi'), findsOneWidget);
      expect(find.text('00:42'), findsOneWidget);
      expect(
        find.text('Hello, please call me back when you get a chance.'),
        findsOneWidget,
      );

      // Tap message to expand
      await tester.tap(find.text('Ahmed Al-Harthi'));
      await tester.pumpAndSettle();

      // Verify expanded detail view: TRANSCRIPT, Call Back button, audio player slider
      expect(find.text('TRANSCRIPT'), findsOneWidget);
      expect(find.text('Call Back (+96891234567)'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // AI Summary should NOT be visible because no genuine AI summary was provided
      expect(find.text('AI SUMMARY'), findsNothing);
    });

    testWidgets(
        'VoicemailInboxScreen displays AI summary only when genuine data is present',
        (tester) async {
      final mockVoicemailWithAi = VoicemailMessage(
        id: 'vm-test-02',
        callerNumber: '+12025550192',
        callerName: 'Bank of America',
        audioUrl: 'https://example.com/bank.mp3',
        durationSeconds: 30,
        transcript: 'Your card ending in 1234 was approved.',
        language: 'en',
        status: 'transcribed',
        isRead: true,
        createdAt: DateTime(2026, 9, 23, 15, 0),
        aiSummary: 'Card authorization notification from Bank of America.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voicemailsProvider
                .overrideWith((ref) async => [mockVoicemailWithAi]),
            callingRepositoryProvider.overrideWithValue(_FakeCallingRepository()),
          ],
          child: const MaterialApp(
            home: VoicemailInboxScreen(initialVoicemailId: 'vm-test-02'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify AI SUMMARY is displayed because genuine field is non-null
      expect(find.text('AI SUMMARY'), findsOneWidget);
      expect(
        find.text('Card authorization notification from Bank of America.'),
        findsOneWidget,
      );
    });
  });
}
