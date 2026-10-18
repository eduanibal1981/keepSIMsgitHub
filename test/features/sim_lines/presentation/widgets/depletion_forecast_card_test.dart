import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/usage_forecast_model.dart';
import 'package:keep_sims/features/sim_lines/domain/line_refill_quote.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/usage_forecast_provider.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/line_refill_quote_provider.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/depletion_forecast_card.dart';

void main() {
  testWidgets(
    'DepletionForecastCard displays tier-aware total (\$0.70 for Free tier) instead of raw base (\$0.25)',
    (tester) async {
      final testLine = SimLine(
        id: 'line-egypt-1',
        userId: 'user-1',
        phoneNumber: '+201095352101',
        planType: 'free',
        protectionTier: 'basic',
        lastTopupAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );

      final testForecast = UsageForecast(
        id: 'fc-1',
        userId: 'user-1',
        simLineId: 'line-egypt-1',
        subjectKind: 'sim_line',
        method: 'carrier_rule',
        confidence: 'medium',
        predictedDepletionAt: DateTime.now().toUtc().add(
          const Duration(days: 75),
        ),
        daysRemaining: 75,
        suggestedFrequencyDays: 76,
        suggestedAmountUsd: 0.25,
        suggestedOfferId: 'vodafone_8_egp',
      );

      const testQuote = LineRefillQuote(
        simLineId: 'line-egypt-1',
        offerId: 'vodafone_8_egp',
        effectiveTier: 'free',
        totalUsd: 0.70,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usageForecastForLineProvider(
              'line-egypt-1',
            ).overrideWith((ref) => Future.value(testForecast)),
            suggestedLineRefillQuoteProvider(
              testLine,
            ).overrideWith((ref) => Future.value(testQuote)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DepletionForecastCard(
                line: testLine,
                isPremium: false,
                carrierDays: 76,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify card content
      expect(find.text('Suggested schedule'), findsOneWidget);
      expect(find.text('A refill of \$0.70, every 76 days'), findsOneWidget);
      expect(find.text('Use it'), findsOneWidget);
    },
  );

  testWidgets('DepletionForecastCard is hidden when line.lastTopupAt is null', (
    tester,
  ) async {
    const testLine = SimLine(
      id: 'line-egypt-1',
      userId: 'user-1',
      phoneNumber: '+201095352101',
      planType: 'free',
      protectionTier: 'basic',
      lastTopupAt: null,
    );

    final testForecast = UsageForecast(
      id: 'fc-1',
      userId: 'user-1',
      simLineId: 'line-egypt-1',
      subjectKind: 'sim_line',
      method: 'carrier_rule',
      confidence: 'medium',
      predictedDepletionAt: DateTime.now().toUtc().add(
        const Duration(days: 75),
      ),
      daysRemaining: 75,
      suggestedFrequencyDays: 76,
      suggestedAmountUsd: 0.25,
      suggestedOfferId: 'vodafone_8_egp',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usageForecastForLineProvider(
            'line-egypt-1',
          ).overrideWith((ref) => Future.value(testForecast)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DepletionForecastCard(line: testLine, isPremium: false),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify card is hidden because no recharge recorded
    expect(find.text('Suggested schedule'), findsNothing);
    expect(find.text('Runs out in 75 days'), findsNothing);
    expect(find.byType(Container), findsNothing);
  });

  testWidgets(
    'DepletionForecastCard is hidden when existingRefillSchedule is present',
    (tester) async {
      final testLine = SimLine(
        id: 'line-egypt-1',
        userId: 'user-1',
        phoneNumber: '+201095352101',
        planType: 'free',
        protectionTier: 'basic',
        lastTopupAt: DateTime.now().toUtc().subtract(const Duration(days: 5)),
      );

      final testForecast = UsageForecast(
        id: 'fc-1',
        userId: 'user-1',
        simLineId: 'line-egypt-1',
        subjectKind: 'sim_line',
        method: 'carrier_rule',
        confidence: 'medium',
        predictedDepletionAt: DateTime.now().toUtc().add(
          const Duration(days: 75),
        ),
        daysRemaining: 75,
        suggestedFrequencyDays: 76,
        suggestedAmountUsd: 0.25,
        suggestedOfferId: 'vodafone_8_egp',
      );

      final existingSchedule = ScheduledTopup(
        id: 'sched-1',
        simLineId: 'line-egypt-1',
        userId: 'user-1',
        amount: 0.70,
        frequencyDays: 76,
        scheduleType: 'refill_custom',
        nextExecutionAt: DateTime.now().toUtc().add(const Duration(days: 76)),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usageForecastForLineProvider(
              'line-egypt-1',
            ).overrideWith((ref) => Future.value(testForecast)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DepletionForecastCard(
                line: testLine,
                isPremium: false,
                existingRefillSchedule: existingSchedule,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify card is hidden
      expect(find.text('Suggested schedule'), findsNothing);
      expect(find.text('Runs out in 75 days'), findsNothing);
      expect(find.byType(DepletionForecastCard), findsOneWidget);
      // Finds only SizedBox.shrink inside
      expect(find.byType(Container), findsNothing);
    },
  );
}
