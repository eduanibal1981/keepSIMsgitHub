import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'package:keep_sims/features/esim/domain/repositories/esim_repository.dart';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';
import 'esim_installation_fixtures.dart';

class _Repo extends Fake implements EsimRepository {
  List<UserEsim> rows = [installationFixture()];
  Future<List<UserEsim>>? refreshResult;
  int reads = 0;
  @override
  Future<List<UserEsim>> getUserEsims({bool requestRefresh = false}) async {
    reads++;
    return requestRefresh && refreshResult != null
        ? await refreshResult!
        : rows;
  }
}

void main() {
  ProviderContainer container(_Repo repo, {String? owner = 'fixture-owner'}) {
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => InstallationAuthFixture(owner),
        ),
        esimRepositoryProvider.overrideWithValue(repo),
      ],
    );
    c.listen(userEsimsControllerProvider, (_, _) {});
    addTearDown(c.dispose);
    return c;
  }

  test(
    'signed-out sessions do not request or retain installation profiles',
    () async {
      final repo = _Repo(), c = container(repo, owner: null);
      expect(await c.read(userEsimsControllerProvider.future), isEmpty);
      expect(repo.reads, 0);
    },
  );
  test(
    'owner changes discard previous profiles even when a repository returns cached rows',
    () async {
      final c = container(_Repo());
      expect(await c.read(userEsimsControllerProvider.future), hasLength(1));
      (c.read(authControllerProvider.notifier) as InstallationAuthFixture)
          .signInAs('other');
      await Future<void>.delayed(Duration.zero);
      expect(await c.read(userEsimsControllerProvider.future), isEmpty);
    },
  );
  test(
    'a pending old-account refresh cannot publish credentials into the next session',
    () async {
      final repo = _Repo(), ready = Completer<List<UserEsim>>();
      final c = container(repo);
      await c.read(userEsimsControllerProvider.future);
      repo.refreshResult = ready.future;
      final pending = c.read(userEsimsControllerProvider.notifier).refresh();
      (c.read(authControllerProvider.notifier) as InstallationAuthFixture)
          .signInAs('other');
      await Future<void>.delayed(Duration.zero);
      ready.complete([installationFixture()]);
      await pending;
      expect(await c.read(userEsimsControllerProvider.future), isEmpty);
    },
  );
  test(
    'offline refresh failure retains only the signed-in owner snapshot with a stale marker',
    () async {
      final repo = _Repo(), c = container(repo);
      await c.read(userEsimsControllerProvider.future);
      repo.refreshResult = Future.error(StateError('offline'));
      await c.read(userEsimsControllerProvider.notifier).refresh();
      final saved = c.read(userEsimsControllerProvider).value!.single;
      expect(saved.userId, 'fixture-owner');
      expect(saved.usageErrorCode, 'REFRESH_FAILED');
      expect(saved.hasActivationPayload, true);
    },
  );
}
