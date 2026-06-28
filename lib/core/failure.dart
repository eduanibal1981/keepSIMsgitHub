/// SIM Shield — Core Failure Types
///
/// Freezed union representing all possible error types in the app.
/// Every failure variant has a [message] field accessible via the mixin.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

@freezed
sealed class AppFailure with _$AppFailure {
  /// A server-side or Supabase error.
  const factory AppFailure.server({required String message}) = ServerFailure;

  /// A network connectivity error.
  const factory AppFailure.network({
    @Default('No internet connection. Please check your network.')
    String message,
  }) = NetworkFailure;

  /// Requested resource was not found.
  const factory AppFailure.notFound({
    @Default('The requested item was not found.') String message,
  }) = NotFoundFailure;

  /// Validation error (e.g. duplicate entry).
  const factory AppFailure.validation({required String message}) =
      ValidationFailure;

  /// Authentication/authorization failure.
  const factory AppFailure.auth({
    @Default('Authentication failed. Please sign in again.') String message,
  }) = AuthFailure;

  /// An unknown/unhandled error.
  const factory AppFailure.unknown({
    @Default('An unexpected error occurred.') String message,
  }) = UnknownFailure;
}

/// An exception that presents a clean, user-friendly message without the "Exception:" prefix.
class UserFriendlyException implements Exception {
  final String message;

  const UserFriendlyException(this.message);

  @override
  String toString() => message;
}
