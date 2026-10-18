import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:keep_sims/features/calling/contract/second_number_contract.dart';
import 'package:keep_sims/features/calling/data/models/available_virtual_number_model.dart';
import 'package:keep_sims/features/calling/data/models/second_number_models.dart';
import 'package:keep_sims/features/calling/data/models/virtual_did_model.dart';
import 'package:keep_sims/features/calling/presentation/controllers/second_number_controller.dart';
import 'package:keep_sims/features/calling/presentation/screens/my_numbers_screen.dart';

class _Numbers implements SecondNumberContract {
  bool fail = false;
  bool empty = false;
  bool pendingFail = false;
  bool coverageEnabled = false;
  bool released = false;
  bool renewed = false;
  final reads = <String>[];
  final updates = StreamController<List<SecondNumberMessage>>.broadcast();
  VirtualDidNumber get number => VirtualDidNumber(
    id: 'did-1',
    phoneNumber: '+447700900123',
    countryCode: 'GB',
    countryName: 'United Kingdom',
    status: released ? 'release_pending' : 'active',
    monthlyFeeUsd: 4.99,
    forwardMode: 'voicemail',
    renewsAt: DateTime(2026, 11, 17),
    createdAt: DateTime(2026, 10, 17),
    lifecycleManaged: true,
    supportsSms: true,
    numberType: 'mobile',
    unreadSmsCount: reads.isEmpty ? 2 : 1,
    autoRenew: renewed,
  );
  SecondNumberMessage get message => SecondNumberMessage(
    id: 'message-1',
    didId: 'did-1',
    senderNumber: 'Example',
    recipientNumber: number.phoneNumber,
    body: 'Your code is 482910.',
    extractedOtp: '482910',
    receivedAt: DateTime(2026, 10, 17, 10, 42),
  );
  @override
  Future<List<VirtualDidNumber>> getVirtualDids() async {
    if (fail) throw const SecondNumberFailure('offline');
    return empty ? [] : [number];
  }

  @override
  Future<List<SecondNumberCountry>> getSecondNumberCountries() async =>
      coverageEnabled ? [const SecondNumberCountry('US', 'United States')] : [];
  @override
  Future<List<SecondNumberOrder>> getPendingSecondNumberOrders() async {
    if (pendingFail) throw const SecondNumberFailure('offline');
    return [];
  }

  @override
  Future<List<AvailableVirtualNumber>> searchAvailableNumbers({
    required String countryCode,
    int limit = 15,
    String? areaCode,
  }) async => [];
  @override
  Future<SecondNumberOrder> purchaseSecondNumber({
    required String quoteId,
    required bool autoRenew,
  }) async => throw UnimplementedError();
  @override
  Future<SecondNumberOrder> getSecondNumberOrder(String id) async =>
      throw UnimplementedError();
  @override
  Stream<List<SecondNumberMessage>> watchDidMessages(String didId) async* {
    yield [message];
    yield* updates.stream;
  }

  @override
  Future<void> markDidMessageRead(String id) async {
    reads.add(id);
  }

  @override
  Future<void> setSecondNumberRenewal(String id, bool enabled) async {
    renewed = enabled;
  }

  @override
  Future<void> releaseSecondNumber(String id) async {
    released = true;
  }
}

Widget _app(
  _Numbers repo, {
  Locale locale = const Locale('en'),
  String? didId,
}) => ProviderScope(
  overrides: [secondNumberRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan)),
    home: MyNumbersScreen(initialDidId: didId),
  ),
);

void main() {
  testWidgets('unreleased coverage shows validation state with no retry loop', (
    tester,
  ) async {
    final repo = _Numbers()..empty = true;
    addTearDown(repo.updates.close);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('US and UK coverage and prices are being validated'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Refresh status'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Get Second Number'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('enabled coverage makes number selection available', (
    tester,
  ) async {
    final repo = _Numbers()..coverageEnabled = true;
    addTearDown(repo.updates.close);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Get Second Number'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      find.textContaining('US and UK coverage and prices are being validated'),
      findsNothing,
    );
  });
  testWidgets(
    'pending order failure explains retry while retaining existing numbers',
    (tester) async {
      final repo = _Numbers()..pendingFail = true;
      addTearDown(repo.updates.close);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      expect(find.text('+447700900123'), findsOneWidget);
      expect(
        find.text('Second Number is temporarily unavailable. Please retry.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    },
  );
  testWidgets(
    'number-first card shows verified SMS capabilities, unread count and clear billing period',
    (tester) async {
      final repo = _Numbers();
      addTearDown(repo.updates.close);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      expect(find.text('My Second Numbers'), findsOneWidget);
      expect(find.text('+447700900123'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('Calls'), findsNothing);
      expect(find.text('Open inbox (2)'), findsOneWidget);
      expect(find.textContaining('Every 30 days'), findsOneWidget);
      expect(find.textContaining('WhatsApp ready'), findsNothing);
    },
  );
  testWidgets(
    'inbox receives updates, marks opened messages and copies a candidate code',
    (tester) async {
      final repo = _Numbers();
      addTearDown(repo.updates.close);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open inbox (2)'));
      await tester.pumpAndSettle();
      repo.updates.add([
        repo.message.copyWith(id: 'message-2', body: 'A new message arrived.'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('A new message arrived.'), findsOneWidget);
      await tester.tap(find.text('Example'));
      await tester.pumpAndSettle();
      expect(repo.reads, ['message-2']);
      await tester.tap(find.text('Copy code'));
      await tester.pumpAndSettle();
      expect(copied, '482910');
    },
  );
  testWidgets(
    'release requires confirmation and retains release-pending status',
    (tester) async {
      final repo = _Numbers();
      addTearDown(repo.updates.close);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Manage number'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Release this number'));
      await tester.pumpAndSettle();
      expect(repo.released, false);
      expect(find.textContaining('assigned to someone else'), findsOneWidget);
      await tester.tap(find.text('Release this number').last);
      await tester.pumpAndSettle();
      expect(repo.released, true);
      expect(find.text('Release pending'), findsOneWidget);
    },
  );
  testWidgets('connection failure is shown rather than an empty list', (
    tester,
  ) async {
    final repo = _Numbers()..fail = true;
    addTearDown(repo.updates.close);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(
      find.text('Second Number is temporarily unavailable. Please retry.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text('Get a dedicated number to receive messages in KeepSIMs.'),
      findsNothing,
    );
  });
  testWidgets(
    'Arabic layout fits a 320px screen and number-specific links open its inbox',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Numbers();
      addTearDown(repo.updates.close);
      await tester.pumpWidget(_app(repo, locale: const Locale('ar')));
      await tester.pumpAndSettle();
      expect(find.text('أرقامي الثانية'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(_app(repo, didId: 'did-1'));
      await tester.pumpAndSettle();
      expect(find.text('Messages'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
