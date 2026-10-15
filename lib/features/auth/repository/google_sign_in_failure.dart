import 'package:google_sign_in/google_sign_in.dart';
import 'package:keep_sims/core/failure.dart';

/// Android can report an OAuth registration failure as a canceled sign-in.
/// Inspect that failure before treating it as a deliberate user cancellation.
AppFailure googleSignInFailure(GoogleSignInException error) {
  final description = (error.description ?? '').toLowerCase();
  if (description.contains('account reauth failed') ||
      description.contains('unregistered_on_api_console') ||
      error.code == GoogleSignInExceptionCode.clientConfigurationError) {
    return const AppFailure.auth(
      message:
          'Google sign-in is not configured for this app build. '
          'Please contact support or sign in with email.',
    );
  }
  if (error.code == GoogleSignInExceptionCode.canceled) {
    return const AppFailure.auth(message: 'Sign-in canceled.');
  }
  return const AppFailure.auth(
    message: 'Google sign-in failed. Please try again or sign in with email.',
  );
}
