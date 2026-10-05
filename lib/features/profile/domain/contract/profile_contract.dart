/// SIM Shield — Profile Contract
///
/// Pure Dart abstract interface defining profile actions.
library;

import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/profile/domain/models/notification_email_status.dart';

abstract interface class ProfileContract {
  /// Fetch a user profile from the database by ID.
  Future<Result<UserProfile>> getProfile(String id);

  /// Update an existing user profile in the database.
  Future<Result<UserProfile>> updateProfile(UserProfile profile);

  Future<Result<UserProfile>> updateProfileDetails(UserProfile profile);

  Future<Result<NotificationEmailStatus>> getNotificationEmailStatus();
}
