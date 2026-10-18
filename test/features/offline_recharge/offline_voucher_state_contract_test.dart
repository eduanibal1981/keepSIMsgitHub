import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_sims/features/offline_recharge/controller/offline_voucher_controller.dart';
import 'package:keep_sims/features/offline_recharge/model/offline_voucher_model.dart';
import 'package:keep_sims/features/offline_recharge/ui/emergency_pin_card.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

// Generated from actual SQL responses by tools/financial-tests/vouchers.mjs.
final _payloads =
    jsonDecode(
          File(
            'test/fixtures/offline_voucher_state_payloads.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

class _StateController extends OfflineVoucherStateController {
  _StateController(this.stateValue);
  final OfflineVoucherState stateValue;

  @override
  FutureOr<OfflineVoucherState> build() => stateValue;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final lifecycle in ['open', 'fulfilled', 'cancelled', 'none']) {
    final state = OfflineVoucherState.fromJson(
      _payloads[lifecycle] as Map<String, dynamic>,
    );

    test(
      '$lifecycle SQL response preserves the active-only request in cache',
      () {
        final cached = OfflineVoucherState.fromJson(
          jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
        );
        expect(cached, state);
        final line = cached.lines.single;
        expect(line.awaitingStock, isTrue);
        expect(line.canProvision, isFalse);
        if (lifecycle == 'open') {
          expect(line.request?.dueAt, DateTime.utc(2026, 11, 1, 12));
          expect(line.request?.reason, 'no_stock');
        } else {
          expect(line.request, isNull);
        }
      },
    );

    testWidgets('$lifecycle shows a deadline only for an active request', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            offlineVoucherStateControllerProvider.overrideWith(
              () => _StateController(state),
            ),
            storedVoucherProvider(
              state.lines.single.simLineId,
            ).overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: EmergencyPinCard(
                simLineId: state.lines.single.simLineId,
                phoneNumber: state.lines.single.phoneNumber,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final localizations = AppLocalizations.of(
        tester.element(find.byType(EmergencyPinCard)),
      )!;
      if (lifecycle == 'open') {
        final date = state.lines.single.request!.dueAt!.toLocal();
        expect(
          find.text(
            localizations.voucherPreparingBodyBy('${date.day}/${date.month}'),
          ),
          findsOneWidget,
        );
        expect(find.text(localizations.voucherPreparingBody), findsNothing);
      } else {
        expect(find.text(localizations.voucherPreparingBody), findsOneWidget);
        expect(find.textContaining('expected by'), findsNothing);
      }
      expect(find.text(localizations.voucherCollectAction), findsNothing);
    });
  }

  test(
    'revealed grant remains an obligation rather than a new stock request',
    () {
      final state = OfflineVoucherState.fromJson(
        _payloads['revealed'] as Map<String, dynamic>,
      );
      final line = state.lines.single;
      expect(line.grant!.isOutstanding, isTrue);
      expect(line.awaitingStock, isFalse);
      expect(line.canProvision, isFalse);
      expect(jsonEncode(state.toJson()), isNot(contains('pin_encrypted')));
    },
  );
}
