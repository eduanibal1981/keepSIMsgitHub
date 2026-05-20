/// SIM Shield — Core Result Type
///
/// Dart 3 sealed class for functional error handling.
/// MUST NOT use Freezed — uses native sealed classes per ARCHITECTURE_RULES.
library;

import 'package:keep_sims/core/failure.dart';

/// Sealed result type wrapping either [Success] or [Failure].
sealed class Result<T> {
  const Result();
}

/// Represents a successful operation with [data].
final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

/// Represents a failed operation with an [error].
final class Failure<T> extends Result<T> {
  final AppFailure error;
  const Failure(this.error);
}
