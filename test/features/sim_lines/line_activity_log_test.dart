import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

void main() {
  group('LineActivityLog formatting tests', () {
    testWidgets(r'getLocalizedDescription formats single dollar sign and avoids duplicate $$',
        (tester) async {
      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              testContext = context;
              return const Placeholder();
            },
          ),
        ),
      );

      final logFailed = LineActivityLog(
        id: 'log-1',
        simLineId: 'sim-1',
        userId: 'user-1',
        eventType: 'topup_failed',
        metadata: {
          'amount': 0.52,
          'failure_reason': 'DTone purchase failed: DECLINED',
        },
        createdAt: DateTime.now(),
      );

      final descFailed = logFailed.getLocalizedDescription(testContext);
      expect(descFailed, contains(r'$0.52'));
      expect(descFailed.contains(r'$$'), isFalse);
      expect(descFailed, equals(r'Top-up of $0.52 failed: DTone purchase failed: DECLINED'));

      final logRequested = LineActivityLog(
        id: 'log-2',
        simLineId: 'sim-1',
        userId: 'user-1',
        eventType: 'topup_requested',
        metadata: {'amount': '0.52'},
        createdAt: DateTime.now(),
      );

      final descRequested = logRequested.getLocalizedDescription(testContext);
      expect(descRequested, contains(r'$0.52'));
      expect(descRequested.contains(r'$$'), isFalse);
      expect(descRequested, equals(r'Refill request submitted for $0.52'));
    });
  });
}
