import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/provider_badge.dart';

void main() {
  group('ProviderInfo mapping & abbreviations', () {
    test('resolves DTone correctly', () {
      final info = ProviderInfo.fromCode('dtone');
      expect(info, isNotNull);
      expect(info!.name, 'DTone');
      expect(info.abbreviation, 'DT');
      expect(info.displayNameWithAbbr, 'DTone (DT)');
      expect(info.abbreviationWithParens, '(DT)');

      // Variations
      expect(ProviderInfo.fromCode('DT')?.displayNameWithAbbr, 'DTone (DT)');
      expect(ProviderInfo.fromCode('dt_carrier')?.displayNameWithAbbr, 'DTone (DT)');
    });

    test('resolves dingConnect correctly', () {
      final info = ProviderInfo.fromCode('ding');
      expect(info, isNotNull);
      expect(info!.name, 'dingConnect');
      expect(info.abbreviation, 'DC');
      expect(info.displayNameWithAbbr, 'dingConnect (DC)');
      expect(info.abbreviationWithParens, '(DC)');

      // Variations
      expect(ProviderInfo.fromCode('dingconnect')?.displayNameWithAbbr, 'dingConnect (DC)');
      expect(ProviderInfo.fromCode('dc')?.displayNameWithAbbr, 'dingConnect (DC)');
    });

    test('resolves Zendit correctly', () {
      final info = ProviderInfo.fromCode('zendit');
      expect(info, isNotNull);
      expect(info!.name, 'Zendit');
      expect(info.abbreviation, 'Z');
      expect(info.displayNameWithAbbr, 'Zendit (Z)');
      expect(info.abbreviationWithParens, '(Z)');

      // Variations
      expect(ProviderInfo.fromCode('zen_carrier')?.displayNameWithAbbr, 'Zendit (Z)');
      expect(ProviderInfo.fromCode('z')?.displayNameWithAbbr, 'Zendit (Z)');
    });

    test('resolves Reloadly correctly', () {
      final info = ProviderInfo.fromCode('reloadly');
      expect(info, isNotNull);
      expect(info!.name, 'Reloadly');
      expect(info.abbreviation, 'R');
      expect(info.displayNameWithAbbr, 'Reloadly (R)');
      expect(info.abbreviationWithParens, '(R)');

      // Variations
      expect(ProviderInfo.fromCode('r')?.displayNameWithAbbr, 'Reloadly (R)');
    });

    test('returns null for null or empty string', () {
      expect(ProviderInfo.fromCode(null), isNull);
      expect(ProviderInfo.fromCode(''), isNull);
      expect(ProviderInfo.fromCode('   '), isNull);
    });

    test('handles fallback unknown provider', () {
      final info = ProviderInfo.fromCode('custom_provider');
      expect(info, isNotNull);
      expect(info!.name, 'custom_provider');
      expect(info.abbreviation, 'CU');
      expect(info.displayNameWithAbbr, 'custom_provider (CU)');
    });
  });

  group('ProviderBadge Widget', () {
    testWidgets('renders full provider name and abbreviation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProviderBadge(
              provider: 'dtone',
              showFullName: true,
            ),
          ),
        ),
      );

      expect(find.text('DTone (DT)'), findsOneWidget);
    });

    testWidgets('renders short abbreviation when showFullName is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProviderBadge(
              provider: 'zendit',
              showFullName: false,
            ),
          ),
        ),
      );

      expect(find.text('(Z)'), findsOneWidget);
    });

    testWidgets('renders empty widget for null provider', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProviderBadge(
              provider: null,
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsNothing);
    });
  });
}
