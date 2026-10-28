import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/wallet/contract/wallet_contract.dart';
import 'package:keep_sims/features/sim_lines/domain/plan_payment.dart';

class _Summary extends Fake implements WalletContract {
  _Summary(this.value);
  final Result<Map<String, dynamic>> value;
  @override
  Future<Result<Map<String, dynamic>>> getWalletSummary() async => value;
}

void main() {
  Future<Future<double> Function()> mount(
    WidgetTester tester,
    Result<Map<String, dynamic>> value,
  ) async {
    late WidgetRef saved;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(_Summary(value)),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (_, ref, _) {
              saved = ref;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return () => PlanPayment.availableWalletBalance(saved);
  }

  testWidgets(
    'checkout prerequisite reads available funds instead of the posted balance',
    (tester) async {
      final read = await mount(
        tester,
        const Success({'posted_balance': 12.66, 'available_balance': 7.54}),
      );
      expect(await read(), 7.54);
    },
  );
  testWidgets('missing negative and non-finite available funds fail closed', (
    tester,
  ) async {
    for (final amount in [null, -1, double.nan, double.infinity]) {
      await tester.pumpWidget(const SizedBox());
      final read = await mount(
        tester,
        Success({'posted_balance': 100, 'available_balance': amount}),
      );
      await expectLater(read(), throwsStateError);
    }
  });
  testWidgets('summary failure is unavailable rather than an empty wallet', (
    tester,
  ) async {
    final read = await mount(tester, const Failure(AppFailure.network()));
    await expectLater(read(), throwsStateError);
  });
}
