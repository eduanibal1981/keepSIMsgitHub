import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/esim/data/services/esim_installation_service.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_activation_payload.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_installation_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.keep_sims/esim');
  const supported = EsimInstallationEnvironment(
    platform: EsimInstallPlatform.ios,
    major: 17,
    minor: 4,
    physicalDevice: true,
  );
  final payload = EsimActivationPayload.tryParse(
    r'LPA:1$fixture.invalid$private-code',
  )!;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'native OS response is used rather than guessing from the device name',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'installationEnvironment');
            return {'major': 17, 'minor': 4, 'physical_device': true};
          });
      expect(
        (await EsimInstallationService().environment()).supportsAppleLink,
        true,
      );
    },
  );
  test(
    'missing native method and simulators fail closed to QR/manual fallback',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        (await EsimInstallationService().environment()).supportsAppleLink,
        false,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => {'major': 18, 'minor': 0, 'physical_device': false},
          );
      expect(
        (await EsimInstallationService().environment()).supportsAppleLink,
        false,
      );
    },
  );
  test('Android performs no Apple native call', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw StateError('Do not invoke Apple channel'),
        );
    final env = await EsimInstallationService().environment();
    expect(env.platform, EsimInstallPlatform.android);
    expect(env.supportsAppleLink, false);
  });
  test(
    'only the constructed Apple URL is handed to the launcher after explicit action',
    () async {
      final urls = <Uri>[];
      final service = EsimInstallationService(
        launch: (uri) async {
          urls.add(uri);
          return true;
        },
      );
      expect(urls, isEmpty);
      expect(
        await service.openApple(payload, supported),
        EsimInstallLaunchResult.opened,
      );
      expect(urls.single.host, 'esimsetup.apple.com');
      expect(urls.single.queryParameters['carddata'], payload.value);
    },
  );
  test('unsupported OS does not launch or contact any server', () async {
    var launches = 0;
    final service = EsimInstallationService(
      launch: (uri) async {
        launches++;
        return true;
      },
    );
    expect(
      await service.openApple(
        payload,
        const EsimInstallationEnvironment(
          platform: EsimInstallPlatform.ios,
          major: 17,
          minor: 3,
          physicalDevice: true,
        ),
      ),
      EsimInstallLaunchResult.unavailable,
    );
    expect(launches, 0);
  });
  test(
    'launch failures return safe status without propagating credential-bearing plugin errors',
    () async {
      final service = EsimInstallationService(
        launch: (uri) async =>
            throw PlatformException(code: 'FAILED', message: uri.toString()),
      );
      expect(
        await service.openApple(payload, supported),
        EsimInstallLaunchResult.failed,
      );
      expect(
        await EsimInstallationService(
          launch: (_) async => false,
        ).openApple(payload, supported),
        EsimInstallLaunchResult.failed,
      );
    },
  );
}
