import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/esim/domain/repositories/esim_repository.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_go_repository_impl.dart';

part 'esim_provider_factory.g.dart';

/// Provides the correct EsimRepository implementation.
/// Currently defaults to EsimGoRepositoryImpl, but can be expanded
/// to select different providers based on country or user preferences.
@riverpod
EsimRepository esimRepository(Ref ref) {
  return EsimGoRepositoryImpl();
}
