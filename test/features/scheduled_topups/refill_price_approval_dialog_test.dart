import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/scheduled_topups/model/refill_approval_quote.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/refill_price_approval_dialog.dart';

void main() {
  testWidgets(
    'waits for the current price and approves 7.31, never the stale 3.50',
    (tester) async {
      final loaded = Completer<Result<RefillApprovalQuote>>();
      final submitted = Completer<Result<void>>();
      final approvals = <RefillApprovalQuote>[];
      await tester.pumpWidget(
        MaterialApp(
          home: RefillPriceApprovalDialog(
            loadQuote: () => loaded.future,
            approveQuote: (quote) {
              approvals.add(quote);
              return submitted.future;
            },
          ),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Approve \$3.50'), findsNothing);
      expect(approvals, isEmpty);
      loaded.complete(
        Success(
          RefillApprovalQuote(
            id: 'fresh',
            totalUsd: 7.31,
            targetValue: 20,
            targetCurrency: 'SAR',
            expiresAt: DateTime.now().add(const Duration(minutes: 1)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Approve \$7.31'), findsOneWidget);
      expect(find.text('Total from wallet: \$7.31 USD'), findsOneWidget);
      expect(find.textContaining('Base cost'), findsNothing);
      expect(
        find.textContaining('future automatic refills stays unchanged'),
        findsOneWidget,
      );
      await tester.tap(find.text('Approve \$7.31'));
      await tester.pump();
      expect(approvals.single.totalUsd, 7.31);
      expect(approvals.single.id, 'fresh');
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'an expired price requires a fresh check and cannot be approved',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RefillPriceApprovalDialog(
            loadQuote: () async => Success(
              RefillApprovalQuote(
                id: 'expired',
                totalUsd: 7.31,
                expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
              ),
            ),
            approveQuote: (_) async {
              calls++;
              return const Success(null);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve \$7.31'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Check Price Again'), findsOneWidget);
    },
  );
}
