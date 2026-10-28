import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_catalogue_details.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/presentation/widgets/esim_plan_facts.dart';

void main() {
  for (final type in [
    'total',
    'daily_throttled',
    'daily_cutoff',
    'daily_unlimited',
    'unknown',
  ]) {
    test(
      '$type preserves the exact allowance through comparison and checkout',
      () {
        final details = {'plan_type': type, 'allowance_bytes': '2147483648'};
        final offer = CompareOffer.fromRpc({
          'source_code': 'esimaccess',
          'data_amount_mb': 2048,
          'is_unlimited': type == 'daily_unlimited',
          'catalogue_details': details,
        });
        final plan = EsimPlan(
          id: 'fixture',
          name: 'Plan',
          dataAmountMB: offer.dataAmountMb,
          durationDays: 7,
          priceUsd: 4.4,
          providerName: 'KeepSIMs',
          isUnlimited: offer.isUnlimited,
          catalogueDetails: offer.catalogueDetails,
        );
        expect(plan.formattedData, offer.formattedData);
        expect(
          offer.formattedData,
          type == 'daily_unlimited'
              ? 'Unlimited/day'
              : type.startsWith('daily_')
              ? '2 GB/day'
              : '2 GB',
        );
        expect(offer.exactSpeedDetail, isNot(contains('384')));
        expect(EsimPlan.fromJson(plan.toJson()), plan);
      },
    );
  }

  test('missing facts never infer unlimited or daily behavior from names', () {
    final offer = CompareOffer.fromRpc({
      'source_code': 'esimaccess',
      'title': 'Unlimited FUP DayPass',
    });
    expect(offer.formattedData, 'Not provided');
    expect(offer.typeTag, 'Not provided');
    expect(offer.exactSpeedDetail, 'Not provided');
    expect(offer.formattedDuration, 'Not provided');
    final facts = offer.facts;
    expect(facts.activationLabel, 'Not provided');
    expect(facts.unusedValidityLabel, 'Not provided');
    expect(facts.rechargeLabel, 'Not provided');
    expect(facts.networksLabel, 'Not provided');
    expect(
      CompareOffer.fromRpc({'catalogue_details': 'invalid'}).facts.planType,
      'unknown',
    );
  });

  test('FUP and activation are supplied facts, not generic promises', () {
    const facts = EsimCatalogueDetails({
      'plan_type': 'daily_throttled',
      'fup_text': 'Up to 512 Kbps',
      'activation_trigger': 'installation',
      'unused_validity_value': 30,
      'unused_validity_unit': 'DAY',
      'duration_value': 36,
      'duration_unit': 'HOUR',
      'topup_support': 'daily_extension',
      'networks': [
        {
          'country_code': 'OM',
          'operators': [
            {'name': 'Omantel', 'network_type': '4G/5G'},
          ],
        },
      ],
    });
    expect(facts.policyLabel, contains('Up to 512 Kbps'));
    expect(facts.activationLabel, 'Validity starts on first installation');
    expect(facts.durationLabel(2), '36 hours');
    expect(facts.unusedValidityLabel, 'Activate within 30 days of purchase');
    expect(facts.networksLabel, 'OM: Omantel (4G/5G)');
    expect(facts.rechargeLabel, contains('not available yet'));
    expect(
      const EsimCatalogueDetails({'plan_type': 'daily_cutoff'}).policyLabel,
      contains('Data stops'),
    );
  });

  test(
    'plan type participates in filter equality, clearing and active count',
    () {
      const all = CompareFilters();
      final cutoff = all.copyWith(planTypes: ['daily_cutoff']);
      expect(cutoff.activeCount, 1);
      expect(cutoff, isNot(all));
      expect(cutoff.copyWith(planTypes: null), all);
      expect(cutoff.copyWith().planTypes, ['daily_cutoff']);
    },
  );

  testWidgets(
    'long exact network lists and unknown values fit a narrow detail viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EsimPlanFacts(
                facts: EsimCatalogueDetails({}),
                countries: ['OM', 'AE', 'SA'],
              ),
            ),
          ),
        ),
      );
      expect(find.text('OM, AE, SA'), findsOneWidget);
      expect(find.text('Not provided'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
