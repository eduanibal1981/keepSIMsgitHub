import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/offline_recharge/model/offline_refill_model.dart';

void main() {
  group('PendingOfflineRefill', () {
    test('round-trips through JSON exactly as the local cache stores it', () {
      final original = PendingOfflineRefill(
        id: 'ofr_123',
        channel: OfflineChannel.whatsapp,
        simLineId: 'line-1',
        phoneNumber: '+201012345678',
        amount: 5.0,
        status: PendingRefillStatus.sent,
        launchedAt: DateTime.parse('2026-07-18T10:00:00.000Z'),
      );

      // LocalCacheService serialises with toJson() and reads back with fromJson().
      final restored = PendingOfflineRefill.fromJson(original.toJson());

      expect(restored, original);
      expect(restored.channel, 'whatsapp');
      expect(restored.status, 'sent');
      expect(restored.executionId, isNull);
    });

    test('preserves a reconciled execution id + terminal status', () {
      final confirmed = PendingOfflineRefill(
        id: 'ofr_9',
        channel: OfflineChannel.missedCall,
        simLineId: 'line-2',
        phoneNumber: '+201000000000',
        amount: 10.0,
        status: PendingRefillStatus.confirmed,
        launchedAt: DateTime.parse('2026-07-18T10:00:00.000Z'),
        executionId: 'exec-abc',
      );

      final restored = PendingOfflineRefill.fromJson(confirmed.toJson());
      expect(restored.executionId, 'exec-abc');
      expect(restored.channel, 'missed_call');
    });
  });

  group('PendingRefillStatus.isTerminal', () {
    test('sent and processing are still reconciling', () {
      expect(PendingRefillStatus.isTerminal(PendingRefillStatus.sent), isFalse);
      expect(
        PendingRefillStatus.isTerminal(PendingRefillStatus.processing),
        isFalse,
      );
    });

    test('confirmed, failed and timed-out are final', () {
      expect(
        PendingRefillStatus.isTerminal(PendingRefillStatus.confirmed),
        isTrue,
      );
      expect(
        PendingRefillStatus.isTerminal(PendingRefillStatus.failed),
        isTrue,
      );
      expect(
        PendingRefillStatus.isTerminal(PendingRefillStatus.timedOut),
        isTrue,
      );
    });
  });
}
