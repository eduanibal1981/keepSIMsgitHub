import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/household/data/models/household_spend_model.dart';

/// G6 — family / fleet shared wallet with spend limits. These cover the places
/// where the client re-interprets the server's numbers, and the one reading
/// that would be dangerous to get backwards: a zero cap means **may not spend**,
/// not "no limit".
void main() {
  Map<String, dynamic> summaryRow({
    String memberEmail = 'member@example.com',
    String? memberName = 'Amal',
    String role = 'manager',
    String inviteStatus = 'accepted',
    double monthlyCapUsd = 25.00,
    double? perTxnCapUsd = 10.00,
    double committedUsd = 5.16,
    double inFlightUsd = 2.58,
    double spentMtdUsd = 7.74,
    double remainingUsd = 17.26,
    String? lastSpendAt = '2026-07-30T09:15:00Z',
  }) => <String, dynamic>{
    'member_row_id': 'hm-1',
    'member_id': 'u-2',
    'member_email': memberEmail,
    'member_name': memberName,
    'role': role,
    'invite_status': inviteStatus,
    'monthly_cap_usd': monthlyCapUsd,
    'per_txn_cap_usd': perTxnCapUsd,
    'committed_usd': committedUsd,
    'in_flight_usd': inFlightUsd,
    'spent_mtd_usd': spentMtdUsd,
    'remaining_usd': remainingUsd,
    'last_spend_at': lastSpendAt,
  };

  Map<String, dynamic> allowanceRow({
    double monthlyCapUsd = 25.00,
    double spentMtdUsd = 7.74,
    double remainingUsd = 17.26,
    String? ownerName = 'Goma',
    String? ownerEmail = 'owner@example.com',
  }) => <String, dynamic>{
    'owner_id': 'u-1',
    'owner_name': ownerName,
    'owner_email': ownerEmail,
    'role': 'manager',
    'monthly_cap_usd': monthlyCapUsd,
    'per_txn_cap_usd': 10.00,
    'spent_mtd_usd': spentMtdUsd,
    'remaining_usd': remainingUsd,
  };

  group('HouseholdSpendRow deserialization', () {
    test('maps the snake_case row household_spend_summary() returns', () {
      final r = HouseholdSpendRow.fromJson(summaryRow());

      expect(r.memberRowId, 'hm-1');
      expect(r.displayName, 'Amal');
      expect(r.monthlyCapUsd, 25.00);
      expect(r.committedUsd, 5.16);
      expect(r.inFlightUsd, 2.58);
      expect(r.spentMtdUsd, 7.74);
      expect(r.remainingUsd, 17.26);
      expect(r.lastSpendAt, DateTime.parse('2026-07-30T09:15:00Z'));
    });

    test('falls back to the email when the member has no profile name', () {
      expect(
        HouseholdSpendRow.fromJson(summaryRow(memberName: null)).displayName,
        'member@example.com',
      );
      expect(
        HouseholdSpendRow.fromJson(summaryRow(memberName: '')).displayName,
        'member@example.com',
      );
    });

    test('survives a never-accepted invite with no member id', () {
      final r = HouseholdSpendRow.fromJson(<String, dynamic>{
        'member_row_id': 'hm-2',
        'member_id': null,
        'member_email': 'nobody@example.com',
        'member_name': null,
        'role': 'viewer',
        'invite_status': 'pending',
        'monthly_cap_usd': 0.00,
        'per_txn_cap_usd': null,
        'committed_usd': 0.00,
        'in_flight_usd': 0.00,
        'spent_mtd_usd': 0.00,
        'remaining_usd': 0.00,
        'last_spend_at': null,
      });

      expect(r.memberId, isNull);
      expect(r.isFunded, isFalse);
      expect(r.canBeFunded, isFalse);
      expect(r.usedFraction, 0.0);
    });
  });

  group('a zero cap means MAY NOT SPEND, never "unlimited"', () {
    test('isFunded is false at exactly zero', () {
      expect(HouseholdSpendRow.fromJson(summaryRow(monthlyCapUsd: 0)).isFunded,
          isFalse);
      expect(
          HouseholdSpendRow.fromJson(summaryRow(monthlyCapUsd: 0.01)).isFunded,
          isTrue);
    });

    test('usedFraction is 0 rather than a division by zero', () {
      final r = HouseholdSpendRow.fromJson(
        summaryRow(monthlyCapUsd: 0, spentMtdUsd: 0, remainingUsd: 0),
      );
      expect(r.usedFraction, 0.0);
      expect(r.usedFraction.isNaN, isFalse);
    });

    test('an unfunded member is not reported as exhausted', () {
      // "Exhausted" is a warning state for someone who HAD money and used it.
      // Showing it for someone who was never funded would be a lie.
      final r = HouseholdSpendRow.fromJson(
        summaryRow(monthlyCapUsd: 0, remainingUsd: 0),
      );
      expect(r.isExhausted, isFalse);
    });
  });

  group('canBeFunded mirrors the server trigger', () {
    test('an accepted manager can be funded', () {
      expect(HouseholdSpendRow.fromJson(summaryRow()).canBeFunded, isTrue);
    });

    test('a viewer cannot — they cannot act on the owner lines at all', () {
      expect(
        HouseholdSpendRow.fromJson(summaryRow(role: 'viewer')).canBeFunded,
        isFalse,
      );
    });

    test('a manager whose invite is still pending cannot', () {
      expect(
        HouseholdSpendRow.fromJson(summaryRow(inviteStatus: 'pending'))
            .canBeFunded,
        isFalse,
      );
    });
  });

  group('usedFraction and isExhausted', () {
    test('is the spent share of the cap', () {
      final r = HouseholdSpendRow.fromJson(
        summaryRow(monthlyCapUsd: 20, spentMtdUsd: 5),
      );
      expect(r.usedFraction, closeTo(0.25, 1e-9));
    });

    test('clamps at 1.0 when spend somehow exceeds the cap', () {
      // The cap can be lowered after money was already spent, so spent > cap
      // is a reachable state and the bar must not overflow.
      final r = HouseholdSpendRow.fromJson(
        summaryRow(monthlyCapUsd: 5, spentMtdUsd: 12, remainingUsd: 0),
      );
      expect(r.usedFraction, 1.0);
      expect(r.isExhausted, isTrue);
    });

    test('a funded member with nothing left is exhausted', () {
      expect(
        HouseholdSpendRow.fromJson(
          summaryRow(monthlyCapUsd: 10, spentMtdUsd: 10, remainingUsd: 0),
        ).isExhausted,
        isTrue,
      );
    });
  });

  group('in-flight is reported separately from committed', () {
    test('spent = committed + in flight, as the server computes it', () {
      // The owner will otherwise compare their balance against the cap and
      // find they disagree by whatever is queued but not yet charged.
      final r = HouseholdSpendRow.fromJson(summaryRow());
      expect(r.committedUsd + r.inFlightUsd, closeTo(r.spentMtdUsd, 1e-9));
    });

    test('a member with nothing queued reports zero in flight', () {
      final r = HouseholdSpendRow.fromJson(
        summaryRow(committedUsd: 7.74, inFlightUsd: 0, spentMtdUsd: 7.74),
      );
      expect(r.inFlightUsd, 0.0);
    });
  });

  group('HouseholdAllowance — the member side', () {
    test('maps my_household_allowances() and names the owner', () {
      final a = HouseholdAllowance.fromJson(allowanceRow());
      expect(a.ownerLabel, 'Goma');
      expect(a.monthlyCapUsd, 25.00);
      expect(a.remainingUsd, 17.26);
      expect(a.isFunded, isTrue);
    });

    test('falls back to the owner email, then to a generic label', () {
      expect(
        HouseholdAllowance.fromJson(allowanceRow(ownerName: null)).ownerLabel,
        'owner@example.com',
      );
      expect(
        HouseholdAllowance.fromJson(
          allowanceRow(ownerName: null, ownerEmail: null),
        ).ownerLabel,
        'Household owner',
      );
    });

    test('an unfunded membership reports no headroom and no progress', () {
      final a = HouseholdAllowance.fromJson(
        allowanceRow(monthlyCapUsd: 0, spentMtdUsd: 0, remainingUsd: 0),
      );
      expect(a.isFunded, isFalse);
      expect(a.usedFraction, 0.0);
    });

    test('clamps the bar when the owner lowers the cap below what was spent',
        () {
      final a = HouseholdAllowance.fromJson(
        allowanceRow(monthlyCapUsd: 5, spentMtdUsd: 9, remainingUsd: 0),
      );
      expect(a.usedFraction, 1.0);
    });
  });
}
