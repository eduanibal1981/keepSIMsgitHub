import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/offline_recharge/model/offline_voucher_model.dart';

/// Unit tests for the on-device voucher.
///
/// The interesting behaviour is all about what happens with the radio off:
/// a reveal must be durable before any network call, the dial code must only
/// exist when an operator verified it, and a reported flag must never be lost
/// across a re-provision.

StoredVoucher voucher({
  String grantId = 'g1',
  String simLineId = 'line-1',
  String pin = '1234-5678',
  String? template,
  DateTime? expiresAt,
  DateTime? revealedAt,
  bool reported = false,
}) => StoredVoucher(
  grantId: grantId,
  simLineId: simLineId,
  pin: pin,
  faceValueUsd: 2.50,
  amountDueUsd: 2.50,
  instructions: 'Dial the recharge code and enter this PIN.',
  redeemUssdTemplate: template,
  expiresAt: expiresAt,
  revealedAt: revealedAt,
  reported: reported,
);

void main() {
  group('StoredVoucher.redeemCode', () {
    test('substitutes the PIN into a verified template', () {
      final v = voucher(template: '*102*{PIN}#', pin: '1234-5678');
      expect(v.redeemCode, '*102*12345678#');
    });

    test('strips spaces and dashes so the dialler gets digits', () {
      final v = voucher(template: '*123*{PIN}#', pin: '1111 2222 3333');
      expect(v.redeemCode, '*123*111122223333#');
    });

    test('is null with no template — an unverified code is never invented', () {
      // The subscriber is offline with no credit. A wrong USSD string cannot be
      // corrected, and a wrong one is worse than instructions alone.
      expect(voucher(template: null).redeemCode, isNull);
      expect(voucher(template: '').redeemCode, isNull);
    });
  });

  group('reveal state', () {
    test('a fresh voucher is sealed and owes no report', () {
      final v = voucher();
      expect(v.isRevealed, isFalse);
      expect(v.needsReport, isFalse);
    });

    test('revealed but unreported is the state the retry loop lives on', () {
      final v = voucher(revealedAt: DateTime(2026, 8, 11));
      expect(v.isRevealed, isTrue);
      expect(v.needsReport, isTrue);
    });

    test('reported clears the obligation without clearing the reveal', () {
      final v = voucher(revealedAt: DateTime(2026, 8, 11), reported: true);
      expect(v.isRevealed, isTrue);
      expect(v.needsReport, isFalse);
    });
  });

  group('expiry', () {
    test('no expiry is not expired', () {
      expect(voucher().isExpired, isFalse);
    });

    test('a past expiry is expired', () {
      final v = voucher(
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(v.isExpired, isTrue);
    });

    test('a future expiry is not', () {
      final v = voucher(
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(v.isExpired, isFalse);
    });
  });

  group('JSON round trip', () {
    test('survives the keystore', () {
      final v = voucher(
        template: '*102*{PIN}#',
        expiresAt: DateTime.utc(2027, 1, 1),
        revealedAt: DateTime.utc(2026, 8, 11, 9, 30),
        reported: true,
      ).copyWith(serial: 'SN-9', storedAt: DateTime.utc(2026, 8, 10));

      final back = StoredVoucher.fromJson(v.toJson());
      expect(back, v);
      expect(back.pin, '1234-5678');
      expect(back.redeemCode, '*102*12345678#');
    });
  });

  group('VoucherLineState', () {
    VoucherLineState line({
      bool entitled = true,
      VoucherGrant? grant,
      bool stock = true,
      VoucherRequest? request,
    }) => VoucherLineState(
      simLineId: 'line-1',
      phoneNumber: '+96555512345',
      entitled: entitled,
      grant: grant,
      stockAvailable: stock,
      request: request,
    );

    test('can provision when entitled, unencumbered and stocked', () {
      expect(line().canProvision, isTrue);
    });

    test('cannot provision without entitlement', () {
      expect(line(entitled: false).canProvision, isFalse);
    });

    test('cannot provision while holding a voucher', () {
      final held = line(
        grant: const VoucherGrant(id: 'g1', status: 'provisioned'),
      );
      expect(held.canProvision, isFalse);
      expect(held.grant!.isSealed, isTrue);
      expect(held.grant!.isOutstanding, isFalse);
    });

    test('an unsettled voucher is outstanding, not sealed', () {
      final owing = line(
        grant: const VoucherGrant(
          id: 'g1',
          status: 'revealed',
          amountDueUsd: 2.5,
        ),
      );
      expect(owing.grant!.isOutstanding, isTrue);
      expect(owing.canProvision, isFalse);
    });

    test('awaitingStock separates "we owe them" from "they owe us"', () {
      // The two no-PIN states have opposite remedies, so they must not collapse
      // into one "unavailable".
      expect(line(stock: false).awaitingStock, isTrue);
      expect(line(stock: true).awaitingStock, isFalse);
      expect(line(entitled: false, stock: false).awaitingStock, isFalse);
    });
  });

  group('OfflineVoucherState', () {
    test('parses the RPC payload shape', () {
      final state = OfflineVoucherState.fromJson({
        'enabled': true,
        'outstanding_total_usd': 2.5,
        'lines': [
          {
            'sim_line_id': 'line-1',
            'phone_number': '+96555512345',
            'nickname': 'Mum',
            'carrier_id': 'c1',
            'carrier_name': 'Zain',
            'entitled': true,
            'stock_available': false,
            'grant': {
              'id': 'g1',
              'status': 'revealed',
              'amount_due_usd': 2.5,
              'face_value_usd': 2.5,
            },
            'request': {'due_at': '2026-08-18T00:00:00Z', 'reason': 'no_stock'},
          },
        ],
      });

      expect(state.enabled, isTrue);
      expect(state.outstandingTotalUsd, 2.5);
      expect(state.lines, hasLength(1));

      final l = state.forLine('line-1')!;
      expect(l.carrierName, 'Zain');
      expect(l.grant!.isOutstanding, isTrue);
      expect(l.request!.dueAt, DateTime.utc(2026, 8, 18));
      expect(state.forLine('nope'), isNull);
    });

    test('an empty payload is a valid, switched-off state', () {
      final state = OfflineVoucherState.fromJson({});
      expect(state.enabled, isFalse);
      expect(state.lines, isEmpty);
      expect(state.outstandingTotalUsd, 0);
    });
  });
}
