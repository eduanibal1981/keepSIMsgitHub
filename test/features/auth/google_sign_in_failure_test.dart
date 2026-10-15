import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:keep_sims/features/auth/repository/google_sign_in_failure.dart';

void main() {
  test(
    'account reauth failure is visible even when Google reports canceled',
    () {
      final failure = googleSignInFailure(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: '[16] Account reauth failed.',
        ),
      );
      expect(failure.message, contains('not configured'));
      expect(failure.message, isNot('Sign-in canceled.'));
    },
  );

  test('explicit configuration failure explains the problem', () {
    final failure = googleSignInFailure(
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      ),
    );
    expect(failure.message, contains('not configured'));
  });

  test('ordinary user cancellation remains quiet', () {
    final failure = googleSignInFailure(
      const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
    );
    expect(failure.message, 'Sign-in canceled.');
  });

  test('other failures use a safe message without exposing SDK details', () {
    final failure = googleSignInFailure(
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'private provider details',
      ),
    );
    expect(failure.message, contains('Please try again'));
    expect(failure.message, isNot(contains('private provider details')));
  });
}
