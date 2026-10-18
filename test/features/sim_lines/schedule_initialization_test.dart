import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/sim_lines/domain/repositories/sim_lines_repository.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';

class _Repo extends Mock implements SimLinesRepository {}

class _Auth extends AuthController {
  @override
  FutureOr<UserProfile?> build() => const UserProfile(id: 'owner');
}

class _Controller extends SimLinesController {
  @override
  void schedulePostRefillCheck([String? simLineId]) {}
}

const saved = SimLine(
  id: 'saved-line',
  userId: 'owner',
  phoneNumber: '+15550001001',
  planType: 'premium',
  carrierStatus: 'active',
);
void main() {
  setUpAll(() => registerFallbackValue(saved));
  for (final upgrade in [false, true]) {
    for (final failed in [false, true]) {
      test(
        '${upgrade ? 'upgrade' : 'creation'} ${failed ? 'preserves saved line when review fails' : 'initializes one current lifecycle'}',
        () async {
          final repo = _Repo();
          when(() => repo.getSimLines()).thenAnswer(
            (_) async => upgrade ? [saved.copyWith(planType: 'free')] : [],
          );
          when(() => repo.addSimLine(any())).thenAnswer((_) async => saved);
          when(() => repo.updateSimLine(any())).thenAnswer((_) async => saved);
          when(() => repo.initializeLineSchedules(any())).thenAnswer((_) async {
            if (failed) throw StateError('Review required');
          });
          final container = ProviderContainer(
            overrides: [
              authControllerProvider.overrideWith(_Auth.new),
              simLinesRepositoryProvider.overrideWith((_) => repo),
              simLinesControllerProvider.overrideWith(_Controller.new),
            ],
          );
          addTearDown(container.dispose);
          await container.read(authControllerProvider.future);
          await container.read(simLinesControllerProvider.future);
          final controller = container.read(
            simLinesControllerProvider.notifier,
          );
          Future<void> act() async {
            if (upgrade) {
              await controller.updateSimLine(saved);
            } else {
              await controller.addSimLine(
                phoneNumber: saved.phoneNumber,
                protectionTier: 'premium',
                planType: 'premium',
              );
            }
          }

          if (failed) {
            await expectLater(
              act(),
              throwsA(isA<ScheduleInitializationException>()),
            );
          } else {
            await act();
          }
          expect(
            container.read(simLinesControllerProvider).requireValue.single,
            saved,
          );
          verify(() => repo.initializeLineSchedules('saved-line')).called(1);
        },
      );
    }
  }
}
