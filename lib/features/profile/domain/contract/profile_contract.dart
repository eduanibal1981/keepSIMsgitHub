/// SIM Shield — Profile Contract
///
/// Pure Dart abstract interface defining profile actions.
library;

import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';

abstract interface class ProfileContract {
  /// Fetch a user profile from the database by ID.
  Future<Result<UserProfile>> getProfile(String id);

  /// Update an existing user profile in the database.
  Future<Result<UserProfile>> updateProfile(UserProfile profile);
}
