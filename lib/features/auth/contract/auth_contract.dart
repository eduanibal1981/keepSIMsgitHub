/// SIM Shield — Auth Contract
///
/// Defines all authentication operations.
/// Returns `Result<T>` for every method — no implementation here.
library;

import 'package:keep_sims/core/result.dart';
import '../model/auth_model.dart';

/// Abstract interface for authentication operations.
abstract interface class AuthContract {
  /// Sign in with Google (native on mobile, OAuth on web).
  Future<Result<UserProfile>> signInWithGoogle();

  /// Sign in with Email and Password.
  Future<Result<UserProfile>> signInWithEmailAndPassword(
    String email,
    String password,
  );

  /// Sign up with Email and Password.
  Future<Result<void>> signUpWithEmailAndPassword(
    String email,
    String password,
  );

  /// Resend confirmation email.
  Future<Result<void>> resendConfirmationEmail(String email);

  /// Verify OTP for email signup.
  Future<Result<void>> verifyOTP(String email, String token);

  /// Sign out the current user.
  Future<Result<void>> signOut();

  /// Get the currently authenticated user's profile.
  Future<Result<UserProfile>> getCurrentProfile();

  /// Check if a user session exists.
  bool get isAuthenticated;

  /// Stream of auth state changes (user ID or null).
  Stream<String?> get authStateChanges;
}
