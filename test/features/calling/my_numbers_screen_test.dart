import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/data/models/carrier_divert_model.dart';
import 'package:keep_sims/features/calling/data/models/virtual_did_model.dart';
import 'package:keep_sims/features/calling/presentation/screens/my_numbers_screen.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/features/wallet/model/wallet_model.dart';

void main() {
  final mockDid = VirtualDidNumber(
    id: 'did-us-01',
    phoneNumber: '+12025550192',
    countryCode: 'US',
    countryName: 'United States',
    status: 'active',
    monthlyFeeUsd: 1.15,
    forwardMode: 'app',
    renewsAt: DateTime.now().add(const Duration(days: 30)),
    createdAt: DateTime.now(),
  );

  final mockCarriers = [
    const CarrierDivertRule(
      carrierId: 'c-stc',
      carrierName: 'STC Saudi',
      countryCode: 'SA',
      countryName: 'Saudi Arabia',
      flagEmoji: '🇸🇦',
      dialingCode: '+966',
      cfuFormat: '**21*{number}#',
      cfuCancel: '##21#',
      cfuStatus: '*#21#',
      cancelAll: '##002#',
      specialNotes: 'STC Saudi standard GSM forwarding.',
    ),
    const CarrierDivertRule(
      carrierId: 'c-jio',
      carrierName: 'Jio',
      countryCode: 'IN',
      countryName: 'India',
      flagEmoji: '🇮🇳',
      dialingCode: '+91',
      cfuFormat: '*401*{number}',
      cfuCancel: '*402',
      cfuStatus: '*401',
      cancelAll: '*413',
      specialNotes: 'Reliance Jio VoLTE Star Codes.',
    ),
    const CarrierDivertRule(
      carrierId: 'c-du',
      carrierName: 'du',
      countryCode: 'AE',
      countryName: 'United Arab Emirates',
      flagEmoji: '🇦🇪',
      dialingCode: '+971',
      cfuFormat: '**21*{number}#',
      cfuCancel: '##21#',
      cfuStatus: '*#21#',
      cancelAll: '##002#',
    ),
  ];

  testWidgets('MyNumbersScreen renders header, numbers list, Add Number, and Smart Call Setup matching Image 2', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          virtualDidsProvider.overrideWith((ref) async => [mockDid]),
          carrierDivertRulesProvider.overrideWith((ref) async => mockCarriers),
          simLinesControllerProvider.overrideWith(() => _FakeSimLinesController([])),
          walletControllerProvider.overrideWith(() => _FakeWalletController()),
        ],
        child: const MaterialApp(
          home: MyNumbersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Header matching Image 2
    expect(find.text('KeepSIMs'), findsOneWidget);
    expect(find.text('Smart Calling'), findsOneWidget);
    expect(find.text('Zero-Roaming Cloud Calling & DID Sandbox'), findsOneWidget);

    // 2. Verify Provisioned Virtual Numbers & Add Number button
    expect(find.text('Provisioned Virtual Numbers'), findsOneWidget);
    expect(find.text('Add Number'), findsOneWidget);
    expect(find.text('Use your KeepSIMs numbers for inbound calls anywhere in the world.'), findsOneWidget);

    // 3. Verify Virtual Number Card
    expect(find.text('US Cloud Gateway'), findsOneWidget);
    expect(find.text('+1 (202) 555-0192'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Inbound Action'), findsOneWidget);
    expect(find.text('Ring In-App'), findsOneWidget);

    // 4. Verify Smart Call Setup Card
    expect(find.text('KeepSIMs Smart Call Setup'), findsOneWidget);
    expect(find.text('Zero-Roaming'), findsOneWidget);
    expect(find.text('Home Operator'), findsOneWidget);
    expect(find.text('Select your current mobile operator.'), findsOneWidget);

    // 5. Verify MMI Code for default STC Saudi
    expect(find.text('Dial this MMI code on your domestic SIM'), findsOneWidget);
    expect(find.text('Copy Code'), findsOneWidget);
    expect(find.text('**21*+12025550192#'), findsOneWidget);
    expect(find.text('##21#'), findsOneWidget);

    // 6. Verify "How it works:" section
    expect(find.text('How it works:'), findsOneWidget);
    expect(find.text('Calls to your home number route to KeepSIMs cloud.'), findsOneWidget);
    expect(find.text('The app rings over Wi-Fi or travel eSIM data.'), findsOneWidget);
    expect(find.text('You avoid roaming fees and keep your number reachable.'), findsOneWidget);
  });

  testWidgets('MyNumbersScreen updates MMI code when selecting Reliance Jio', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          virtualDidsProvider.overrideWith((ref) async => [mockDid]),
          carrierDivertRulesProvider.overrideWith((ref) async => mockCarriers),
          simLinesControllerProvider.overrideWith(() => _FakeSimLinesController([])),
          walletControllerProvider.overrideWith(() => _FakeWalletController()),
        ],
        child: const MaterialApp(
          home: MyNumbersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Default is STC Saudi
    expect(find.text('**21*+12025550192#'), findsOneWidget);

    // Tap Home Operator dropdown
    await tester.tap(find.text('🇸🇦 STC Saudi'));
    await tester.pumpAndSettle();

    // Select Jio
    await tester.tap(find.text('🇮🇳 Jio').last);
    await tester.pumpAndSettle();

    // Verify Jio specific VoLTE Star Code format *401* and cancel code *402
    expect(find.text('*401*+12025550192'), findsOneWidget);
    expect(find.text('*402'), findsOneWidget);
    expect(find.text('Reliance Jio VoLTE Star Codes.'), findsOneWidget);
  });

  testWidgets('MyNumbersScreen does not overflow on narrow mobile screens (360x800)', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          virtualDidsProvider.overrideWith((ref) async => [mockDid]),
          carrierDivertRulesProvider.overrideWith((ref) async => mockCarriers),
          simLinesControllerProvider.overrideWith(() => _FakeSimLinesController([])),
          walletControllerProvider.overrideWith(() => _FakeWalletController()),
        ],
        child: const MaterialApp(
          home: MyNumbersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final mmiTitleFinder = find.text('Dial this MMI code on your domestic SIM');
    await tester.scrollUntilVisible(mmiTitleFinder, 100);
    expect(mmiTitleFinder, findsOneWidget);
    expect(find.text('Copy Code'), findsOneWidget);
  });
}

class _FakeSimLinesController extends SimLinesController {
  final List<SimLine> initialLines;
  _FakeSimLinesController(this.initialLines);

  @override
  Future<List<SimLine>> build() async => initialLines;
}

class _FakeWalletController extends WalletController {
  @override
  Future<WalletState> build() async {
    return const WalletState(
      wallet: Wallet(
        id: 'w-01',
        userId: 'u-01',
        balance: 15.00,
        currency: 'USD',
      ),
      transactions: [],
    );
  }
}
