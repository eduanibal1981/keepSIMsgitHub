import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/controllers/smart_call_dialer_controller.dart';

CallPreviewResult quote({
  double price = .095,
  String identity = '+17543180369',
  bool gateway = true,
  bool eligible = true,
  double balance = 10,
  double fee = 0,
  int increment = 1,
}) => CallPreviewResult(
  eligible: eligible,
  policyCode: eligible ? 'approved' : 'self_dial_conflict',
  policyReason: '',
  requestedCallerId: identity,
  effectiveCallerId: identity,
  callerIdType: gateway ? 'gateway' : 'verified_number',
  walletBalance: balance,
  gatewayNumber: '+17543180369',
  connectionFee: fee,
  billingIncrementSeconds: increment,
  rate: CallRate(
    id: 'test',
    countryCode: 'EG',
    countryName: 'Egypt',
    phonePrefix: '+',
    costPerMinute: 0,
    ratePerMinute: price,
  ),
);

class ReviewRepository implements CallingRepository {
  final requests = <({String number, String? id, bool gateway})>[];
  Future<CallPreviewResult> Function()? respond;
  @override
  Future<CallPreviewResult> previewCall({
    required String destinationNumber,
    String? callerIdId,
    bool explicitGateway = false,
    String? simLineId,
  }) {
    requests.add((
      number: destinationNumber,
      id: callerIdId,
      gateway: explicitGateway,
    ));
    return respond?.call() ?? Future.value(quote());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ReviewRepository repository;
  late ProviderContainer container;
  late SmartCallDialerNotifier draft;
  setUp(() {
    repository = ReviewRepository();
    container = ProviderContainer(
      overrides: [callingRepositoryProvider.overrideWithValue(repository)],
    );
    draft = container.read(smartCallDialerProvider.notifier);
  });
  tearDown(() => container.dispose());

  test(
    'national destination cannot quote until country is confirmed',
    () async {
      draft.setNumber('01012345678');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(repository.requests, isEmpty);
      expect(container.read(smartCallDialerProvider).canCall, isFalse);
      draft.selectCountry('EG');
      await draft.refreshPreview();
      expect(repository.requests.single.number, '+201012345678');
      // Tariff phonePrefix '+' never replaces the selected country.
      expect(
        container.read(smartCallDialerProvider).formattedDestination,
        '+201012345678',
      );
      expect(container.read(smartCallDialerProvider).selectedCountryIso, 'EG');
    },
  );
  test('a new local contact requires a new country confirmation', () async {
    draft.setNumber('01012345678');
    draft.selectCountry('EG');
    await draft.refreshPreview();
    draft.setNumber('92312854');
    expect(
      container.read(smartCallDialerProvider).destination.needsCountry,
      isTrue,
    );
    expect(container.read(smartCallDialerProvider).previewResult, isNull);
  });
  test(
    'old response is rejected during the next input debounce window',
    () async {
      final pending = Completer<CallPreviewResult>();
      repository.respond = () => pending.future;
      draft.setNumber('+201012345678');
      final request = draft.refreshPreview();
      draft.setNumber('+96892312854');
      pending.complete(quote());
      await request;
      expect(container.read(smartCallDialerProvider).previewResult, isNull);
      expect(
        container.read(smartCallDialerProvider).formattedDestination,
        '+96892312854',
      );
    },
  );
  test('clear cannot be undone by a pending quote', () async {
    final pending = Completer<CallPreviewResult>();
    repository.respond = () => pending.future;
    draft.setNumber('+201012345678');
    final request = draft.refreshPreview();
    draft.clear();
    pending.complete(quote());
    await request;
    expect(container.read(smartCallDialerProvider).previewResult, isNull);
    expect(container.read(smartCallDialerProvider).isPreviewLoading, isFalse);
  });
  test('old identity response cannot restore the previous quote', () async {
    final pending = Completer<CallPreviewResult>();
    repository.respond = () => pending.future;
    draft.setNumber('+201012345678');
    final request = draft.refreshPreview();
    draft.selectIdentity(
      isGateway: false,
      callerIdId: 'chosen-id',
      phoneNumber: '+96891234567',
    );
    pending.complete(quote());
    await request;
    expect(container.read(smartCallDialerProvider).previewResult, isNull);
  });
  test(
    'personal ID snapshot agrees with preview; gateway clears personal ID',
    () async {
      draft.setNumber('+201012345678');
      draft.selectIdentity(
        isGateway: false,
        callerIdId: 'chosen-id',
        phoneNumber: '+96891234567',
      );
      repository.respond = () async =>
          quote(identity: '+96891234567', gateway: false);
      await draft.refreshPreview();
      final result = await draft.confirmReviewedCall();
      expect(result?.callerIdId, 'chosen-id');
      expect(result?.explicitGateway, isFalse);
      expect(result?.quote.effectiveCallerId, '+96891234567');
      expect(repository.requests.last.id, 'chosen-id');
      draft.selectIdentity(isGateway: true);
      expect(
        container.read(smartCallDialerProvider).selectedCallerIdId,
        isNull,
      );
      expect(container.read(smartCallDialerProvider).effectiveCallerId, isNull);
    },
  );
  test('changed quote is displayed and requires another Call tap', () async {
    draft.setNumber('+201012345678');
    await draft.refreshPreview();
    repository.respond = () async => quote(price: .15, fee: .02, increment: 60);
    expect(await draft.confirmReviewedCall(), isNull);
    final updated = container.read(smartCallDialerProvider);
    expect(updated.previewResult?.rate?.ratePerMinute, .15);
    expect(updated.previewNotice, contains('changed'));
    expect(updated.canCall, isTrue);
    expect(await draft.confirmReviewedCall(), isNotNull);
  });
  test('changed effective identity requires updated review', () async {
    draft.setNumber('+201012345678');
    await draft.refreshPreview();
    repository.respond = () async => quote(identity: '+17543180370');
    expect(await draft.confirmReviewedCall(), isNull);
    expect(
      container.read(smartCallDialerProvider).previewResult?.effectiveCallerId,
      '+17543180370',
    );
  });
  test(
    'ineligible, low-balance, malformed and zero-price quotes cannot call',
    () async {
      draft.setNumber('+201012345678');
      for (final value in [
        quote(eligible: false),
        quote(balance: 0),
        quote(price: 0),
        quote(price: double.nan),
        quote(fee: double.nan),
        quote(increment: 0),
      ]) {
        repository.respond = () async => value;
        await draft.refreshPreview();
        expect(container.read(smartCallDialerProvider).canCall, isFalse);
        expect(await draft.confirmReviewedCall(), isNull);
      }
    },
  );
  test(
    'editing during final refresh cannot submit the old destination',
    () async {
      draft.setNumber('+201012345678');
      await draft.refreshPreview();
      final pending = Completer<CallPreviewResult>();
      repository.respond = () => pending.future;
      final confirmation = draft.confirmReviewedCall();
      draft.setNumber('92312854');
      pending.complete(quote());
      expect(await confirmation, isNull);
    },
  );
}
