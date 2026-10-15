import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/controllers/smart_call_dialer_controller.dart';

class FakeCallingRepository implements CallingRepository {
  Future<CallPreviewResult> Function({
    required String destinationNumber,
    String? callerIdId,
    bool explicitGateway,
    String? simLineId,
  })?
  onPreviewCall;

  @override
  Future<CallPreviewResult> previewCall({
    required String destinationNumber,
    String? callerIdId,
    bool explicitGateway = false,
    String? simLineId,
  }) async {
    if (onPreviewCall != null) {
      return onPreviewCall!(
        destinationNumber: destinationNumber,
        callerIdId: callerIdId,
        explicitGateway: explicitGateway,
        simLineId: simLineId,
      );
    }
    return CallPreviewResult(
      eligible: true,
      policyCode: 'ALLOW',
      policyReason: 'Eligible',
      requestedCallerId: explicitGateway
          ? '+17543180369'
          : (callerIdId != null ? '+96893990492' : '+17543180369'),
      effectiveCallerId: explicitGateway
          ? '+17543180369'
          : (callerIdId != null ? '+96893990492' : '+17543180369'),
      callerIdType: explicitGateway ? 'gateway' : 'verified_personal',
      walletBalance: 10.0,
      gatewayNumber: '+17543180369',
      rate: const CallRate(
        id: 'rate-om-01',
        countryCode: 'OM',
        countryName: 'Oman',
        phonePrefix: '+968',
        costPerMinute: 0.08,
        ratePerMinute: 0.12,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const mockRateOM = CallRate(
    id: 'rate-om-01',
    countryCode: 'OM',
    countryName: 'Oman',
    phonePrefix: '+968',
    costPerMinute: 0.08,
    ratePerMinute: 0.12,
  );

  const mockRateEG = CallRate(
    id: 'rate-eg-01',
    countryCode: 'EG',
    countryName: 'Egypt',
    phonePrefix: '+20',
    costPerMinute: 0.06,
    ratePerMinute: 0.09,
  );

  late FakeCallingRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeCallingRepository();
    container = ProviderContainer(
      overrides: [
        callRatesProvider.overrideWith((ref) async => [mockRateOM, mockRateEG]),
        callingRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SmartCallDialerNotifier Unit Tests', () {
    test(
      '1. Initial state has empty number, gateway selected, and no quote',
      () {
        final state = container.read(smartCallDialerProvider);

        expect(state.rawNumber, isEmpty);
        expect(state.selectedRate, isNull);
        expect(state.previewResult, isNull);
        expect(state.isPreviewLoading, isFalse);
        expect(state.isGatewaySelected, isTrue);
        expect(state.formattedDestination, isEmpty);
        expect(state.effectiveRatePerMinute, equals(0.0));
        expect(state.effectiveRatePerSecond, equals(0.0));
      },
    );

    test('2. Typing number triggers debounced server preview quote', () async {
      final notifier = container.read(smartCallDialerProvider.notifier);

      // Type valid Oman destination
      notifier.setNumber('+96879761061');
      var state = container.read(smartCallDialerProvider);
      expect(state.rawNumber, equals('+96879761061'));
      expect(state.isPreviewLoading, isTrue);
      expect(state.previewResult, isNull);

      // Wait for 300ms debounce + execute
      await Future.delayed(const Duration(milliseconds: 350));

      state = container.read(smartCallDialerProvider);
      expect(state.isPreviewLoading, isFalse);
      expect(state.previewResult, isNotNull);
      expect(state.previewResult!.rate?.countryCode, equals('OM'));
      expect(state.effectiveRatePerMinute, equals(0.12));
      expect(state.effectiveRatePerSecond, closeTo(0.002, 0.0001));
    });

    test(
      '3. Quote race protection: stale Quote A arriving after Quote B is discarded',
      () async {
        final notifier = container.read(smartCallDialerProvider.notifier);

        final completerA = Completer<CallPreviewResult>();
        final completerB = Completer<CallPreviewResult>();

        fakeRepository.onPreviewCall =
            ({
              required String destinationNumber,
              String? callerIdId,
              bool explicitGateway = true,
              String? simLineId,
            }) {
              if (destinationNumber.contains('968')) {
                // First destination (Oman)
                return completerA.future;
              } else {
                // Second destination (Egypt)
                return completerB.future;
              }
            };

        // 1. Enter first number (Oman)
        notifier.setNumber('+96879761061');
        await Future.delayed(const Duration(milliseconds: 320));

        // 2. Quickly replace with second number (Egypt)
        notifier.setNumber('+201012345678');
        await Future.delayed(const Duration(milliseconds: 320));

        // 3. Resolve Request B FIRST (Egypt rate: $0.09)
        completerB.complete(
          const CallPreviewResult(
            eligible: true,
            policyCode: 'ALLOW',
            policyReason: 'Eligible',
            requestedCallerId: '+17543180369',
            effectiveCallerId: '+17543180369',
            callerIdType: 'gateway',
            walletBalance: 10.0,
            gatewayNumber: '+17543180369',
            rate: mockRateEG,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 20));

        var state = container.read(smartCallDialerProvider);
        expect(state.previewResult?.rate?.countryCode, equals('EG'));
        expect(state.effectiveRatePerMinute, equals(0.09));

        // 4. Stale Request A resolves LATER (Oman rate: $0.12)
        completerA.complete(
          const CallPreviewResult(
            eligible: true,
            policyCode: 'ALLOW',
            policyReason: 'Eligible',
            requestedCallerId: '+17543180369',
            effectiveCallerId: '+17543180369',
            callerIdType: 'gateway',
            walletBalance: 10.0,
            gatewayNumber: '+17543180369',
            rate: mockRateOM,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 20));

        // Verify state is NOT overwritten by stale Request A
        state = container.read(smartCallDialerProvider);
        expect(state.previewResult?.rate?.countryCode, equals('EG'));
        expect(state.effectiveRatePerMinute, equals(0.09));
        expect(state.formattedDestination, equals('+201012345678'));
      },
    );

    test(
      '4. Caller identity change immediately invalidates quote and refreshes',
      () async {
        final notifier = container.read(smartCallDialerProvider.notifier);

        notifier.setNumber('+96879761061');
        await Future.delayed(const Duration(milliseconds: 350));

        var state = container.read(smartCallDialerProvider);
        expect(state.previewResult, isNotNull);
        expect(state.isGatewaySelected, isTrue);

        // Switch identity to personal verified line
        notifier.selectIdentity(
          isGateway: false,
          callerIdId: 'cid-verified-01',
          phoneNumber: '+96893990492',
        );

        // Verify quote is cleared immediately
        state = container.read(smartCallDialerProvider);
        expect(state.isGatewaySelected, isFalse);
        expect(state.selectedCallerIdId, equals('cid-verified-01'));
        expect(state.effectiveCallerId, equals('+96893990492'));
        expect(state.previewResult, isNull);
        expect(state.isPreviewLoading, isTrue);

        // Await refreshed quote
        await Future.delayed(const Duration(milliseconds: 350));
        state = container.read(smartCallDialerProvider);
        expect(state.previewResult, isNotNull);
        expect(state.previewResult?.effectiveCallerId, equals('+96893990492'));
      },
    );

    test('5. Selecting country rate prepends prefix when number is empty', () {
      final notifier = container.read(smartCallDialerProvider.notifier);

      notifier.selectCountryRate(mockRateOM);
      var state = container.read(smartCallDialerProvider);
      expect(state.rawNumber, equals('+968'));
      expect(state.selectedCountryIso, 'OM');

      notifier.appendDigit('7');
      notifier.appendDigit('9');
      state = container.read(smartCallDialerProvider);
      expect(state.rawNumber, equals('+96879'));
      expect(state.formattedDestination, isEmpty);
      expect(state.previewResult, isNull);
    });

    test('6. Clear resets input and cancels pending preview', () async {
      final notifier = container.read(smartCallDialerProvider.notifier);

      notifier.setNumber('+96879761061');
      notifier.clear();

      final state = container.read(smartCallDialerProvider);
      expect(state.rawNumber, isEmpty);
      expect(state.previewResult, isNull);
      expect(state.formattedDestination, isEmpty);

      // Wait beyond debounce to confirm no preview executed
      await Future.delayed(const Duration(milliseconds: 350));
      expect(container.read(smartCallDialerProvider).previewResult, isNull);
    });

    test('7. Preview error surfaces in state without crashing', () async {
      fakeRepository.onPreviewCall =
          ({
            required String destinationNumber,
            String? callerIdId,
            bool explicitGateway = true,
            String? simLineId,
          }) async {
            throw Exception('Rate lookup failed: destination unsupported');
          };

      final notifier = container.read(smartCallDialerProvider.notifier);
      notifier.setNumber('+96879761061');

      await Future.delayed(const Duration(milliseconds: 350));

      final state = container.read(smartCallDialerProvider);
      expect(state.isPreviewLoading, isFalse);
      expect(state.previewResult, isNull);
      expect(state.previewError, contains('Could not check'));
    });
  });
}
