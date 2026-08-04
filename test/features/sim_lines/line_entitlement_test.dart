import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';

/// I2 — entitlement is read off the LINE, and `plan_type` beats
/// `protection_tier`.
///
/// The production shape these tests exist for: 4 lines carry
/// `plan_type = 'premium'`, but 3 of them still carry
/// `protection_tier = 'standard'` because nothing in the payment path writes
/// that older column. Every UI gate that asked `protection_tier == 'premium'`
/// therefore withheld premium features from 3 of 4 paying lines, and every gate
/// that asked `profiles.subscription_tier == 'premium'` withheld them from all
/// four, because no account has ever had that value.
SimLine _line({required String plan, required String protection}) => SimLine(
      id: 'line-1',
      userId: 'user-1',
      phoneNumber: '+201000000000',
      planType: plan,
      protectionTier: protection,
    );

void main() {
  group('SimLineEntitlement.effectiveTier', () {
    test('plan_type premium wins even when protection_tier is stale', () {
      // The exact production row shape: 3 of 4 premium lines look like this.
      final line = _line(plan: 'premium', protection: 'standard');
      expect(line.effectiveTier, 'premium');
      expect(line.isPremiumPlan, isTrue);
      expect(line.isPaidPlan, isTrue);
    });

    test('protection_tier premium still counts, so nothing is taken away', () {
      final line = _line(plan: 'free', protection: 'premium');
      expect(line.effectiveTier, 'premium');
      expect(line.isPremiumPlan, isTrue);
    });

    test('standard is paid but not premium', () {
      final line = _line(plan: 'standard', protection: 'standard');
      expect(line.effectiveTier, 'standard');
      expect(line.isPremiumPlan, isFalse);
      expect(line.isPaidPlan, isTrue);
    });

    test('a free line on the legacy basic protection tier is free', () {
      final line = _line(plan: 'free', protection: 'basic');
      expect(line.effectiveTier, 'free');
      expect(line.isPremiumPlan, isFalse);
      expect(line.isPaidPlan, isFalse);
    });

    test('free plan with a standard protection tier is still paid-tier', () {
      // This row exists in production. `protection_tier` widens, never narrows,
      // so the user keeps the channels they can see today.
      final line = _line(plan: 'free', protection: 'standard');
      expect(line.effectiveTier, 'standard');
      expect(line.isPaidPlan, isTrue);
    });

    test('casing and stray whitespace do not change the answer', () {
      final line = _line(plan: '  PREMIUM ', protection: 'Standard');
      expect(line.effectiveTier, 'premium');
    });

    test('an unrecognised plan value falls back to free, not to premium', () {
      // Fail closed: a typo in the column must not hand out paid features.
      final line = _line(plan: 'platinum', protection: 'basic');
      expect(line.effectiveTier, 'free');
      expect(line.isPaidPlan, isFalse);
    });
  });
}
