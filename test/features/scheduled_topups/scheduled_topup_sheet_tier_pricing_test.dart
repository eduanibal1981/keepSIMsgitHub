import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/usage_forecast_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/api_offers_providers.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/usage_forecast_provider.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/features/wallet/model/wallet_model.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart';

void main() {
  const testLine = SimLine(
    id: 'line-egypt-1',
    userId: 'user-1',
    phoneNumber: '+201095352101',
    planType: 'free',
    protectionTier: 'basic',
    countryId: 'c-eg',
    carrierId: 'car-voda',
  );

  final testForecast = UsageForecast(
    id: 'fc-1',
    userId: 'user-1',
    simLineId: 'line-egypt-1',
    subjectKind: 'sim_line',
    method: 'carrier_rule',
    confidence: 'medium',
    suggestedFrequencyDays: 76,
    suggestedAmountUsd: 0.25,
    suggestedOfferId: 'vodafone_8_egp',
    predictedDepletionAt: DateTime.now().toUtc().add(const Duration(days: 75)),
    daysRemaining: 75,
  );

  final fixedOffers = [
    {
      'offerId': 'vodafone_8_egp',
      'description': 'Vodafone Egypt 8 EGP',
      'retailPriceUsd': 0.70,
      'priceType': 'FIXED',
      'provider': 'DTOne',
    },
    {
      'offerId': 'vodafone_9_egp',
      'description': 'Vodafone Egypt 9 EGP',
      'retailPriceUsd': 0.72,
      'priceType': 'FIXED',
      'provider': 'DTOne',
    },
  ];

  final tierFeeRules = {
    'free': const RefillTierFeeRule(percentage: 7.0, minimum: 0.50),
    'standard': const RefillTierFeeRule(percentage: 5.0, minimum: 0.30),
    'premium': const RefillTierFeeRule(percentage: 3.0, minimum: 0.10),
  };

  testWidgets(
    'ScheduledTopupSheet preserves server retail totals and the carrier interval',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            refillFeeRulesProvider.overrideWith(
              (ref) => Future.value(tierFeeRules),
            ),
            lineRefillOffersProvider(
              'line-egypt-1',
            ).overrideWith((ref) => Future.value(fixedOffers)),
            usageForecastForLineProvider(
              'line-egypt-1',
            ).overrideWith((ref) => Future.value(testForecast)),
            simLinesControllerProvider.overrideWith(
              () => _MockSimLinesController([testLine]),
            ),
            walletControllerProvider.overrideWith(
              () => _MockWalletController(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ScheduledTopupSheet(
                simLineId: 'line-egypt-1',
                simNickname: 'My SIM Card',
                simLine: testLine,
                configMode: 'refill',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify that 8 EGP is quoted at $0.70 (0.20 base + 0.50 free fee), NOT $0.30 (premium fee)
      expect(find.text('\$0.70'), findsWidgets);
      expect(find.text('Total: \$0.70 USD'), findsOneWidget);

      // 2. Verify that 9 EGP is quoted at $0.72 (0.22 base + 0.50 free fee), NOT $0.32
      expect(find.text('\$0.72'), findsOneWidget);
      expect(find.text('Total: \$0.72 USD'), findsOneWidget);

      // 3. Verify interval options:
      // "Carrier rule · 76 days" must be present
      expect(find.text('Carrier rule · 76 days'), findsOneWidget);

      // "1 Hour" must NOT be present
      expect(find.text('1 Hour'), findsNothing);

      // Standard presets are present
      expect(find.text('7 Days'), findsOneWidget);
      expect(find.text('14 Days'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
    },
  );
}

class _MockSimLinesController extends SimLinesController {
  final List<SimLine> lines;
  _MockSimLinesController(this.lines);

  @override
  FutureOr<List<SimLine>> build() => lines;
}

class _MockWalletController extends WalletController {
  @override
  FutureOr<WalletState> build() {
    return const WalletState(
      wallet: Wallet(
        id: 'w-1',
        userId: 'user-1',
        balance: 20.0,
        currency: 'USD',
      ),
      transactions: [],
    );
  }
}
