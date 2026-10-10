import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import '../contract/password_recovery_contract.dart';

/// Uses the Auth REST API so recovery tokens stay in memory and never enter
/// the app's persisted session or the SDK's shared browser BroadcastChannel.
class PasswordRecoveryRepository implements PasswordRecoveryContract {
  PasswordRecoveryRepository({
    required Uri authUrl,
    required String apiKey,
    http.Client? client,
  }) : _authUrl = authUrl,
       _apiKey = apiKey,
       _client = client ?? http.Client();

  final Uri _authUrl;
  final String _apiKey;
  final http.Client _client;
  String? _requestedEmail;
  Session? _verifiedSession;

  @override
  Future<Result<void>> sendCode(String email) => _run(() async {
    _verifiedSession = null;
    final normalizedEmail = email.trim().toLowerCase();
    await _request('POST', 'recover', body: {'email': normalizedEmail});
    _requestedEmail = normalizedEmail;
  });

  @override
  Future<Result<void>> verifyCode(String email, String code) => _run(() async {
    _verifiedSession = null;
    final normalizedEmail = email.trim().toLowerCase();
    if (_requestedEmail != normalizedEmail) {
      throw const AuthException('Request a reset code for this email first.');
    }
    final response = await _request(
      'POST',
      'verify',
      body: {
        'email': normalizedEmail,
        'token': code.trim(),
        'type': 'recovery',
      },
    );
    final session =
        AuthResponse.fromJson(response).session ??
        (response['session'] is Map<String, dynamic>
            ? Session.fromJson(response['session'] as Map<String, dynamic>)
            : null);
    if (session == null ||
        session.accessToken.isEmpty ||
        session.user.email?.toLowerCase() != normalizedEmail) {
      throw const AuthException(
        'Unable to verify this code. Request a new one.',
      );
    }
    _verifiedSession = session;
  });

  @override
  Future<Result<void>> resetPassword(String password) => _run(() async {
    final session = _verifiedSession;
    if (session == null || session.isExpired) {
      throw const AuthException(
        'Your reset session has expired. Please request a new code.',
      );
    }
    await _request(
      'PUT',
      'user',
      token: session.accessToken,
      body: {'password': password},
    );
    _verifiedSession = null;
    _requestedEmail = null;
    // A failed sign-out must not report that a successful password change failed.
    // The token is discarded regardless and is never persisted by this client.
    try {
      await _request(
        'POST',
        'logout',
        token: session.accessToken,
        query: {'scope': 'local'},
      );
    } catch (_) {
      // The user will sign in again with their new password.
    }
  });

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Map<String, String>? query,
  }) async {
    final uri = _authUrl.replace(
      path: '${_authUrl.path.replaceFirst(RegExp(r'/$'), '')}/$path',
      queryParameters: query,
    );
    final request = http.Request(method, uri)
      ..headers.addAll({
        'apikey': _apiKey,
        'Authorization': 'Bearer ${token ?? _apiKey}',
        'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);
    final response = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 20));
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawErrorCode = data['error_code'] ?? data['code'];
      final errorCode = rawErrorCode?.toString();
      final msg = (data['msg'] ?? data['message'] ?? data['error_description'])
          ?.toString();
      final isOtpExpired =
          errorCode == 'otp_expired' ||
          (msg != null && msg.toLowerCase().contains('expired')) ||
          (msg != null &&
              msg.toLowerCase().contains('invalid') &&
              response.statusCode == 403);
      final isRateLimit =
          response.statusCode == 429 ||
          errorCode == 'over_request_rate_limit' ||
          errorCode == 'over_email_send_rate_limit';
      final isSessionExpired = response.statusCode == 401 && token != null;

      final message = isOtpExpired
          ? 'This code is invalid or has expired. Please try again or request a new code.'
          : isRateLimit
          ? 'Too many requests. Please wait a minute before trying again.'
          : isSessionExpired
          ? 'Your reset session has expired. Please request a new code.'
          : msg ?? 'Unable to reset your password. Please try again.';
      throw AuthException(message);
    }
    return data;
  }

  Future<Result<void>> _run(Future<void> Function() operation) async {
    try {
      await operation();
      return const Success(null);
    } on AuthException catch (error) {
      return Failure(AppFailure.auth(message: error.message));
    } on http.ClientException catch (_) {
      return const Failure(AppFailure.network());
    } on TimeoutException catch (_) {
      return const Failure(
        AppFailure.network(message: 'The request timed out. Please try again.'),
      );
    } catch (_) {
      return const Failure(
        AppFailure.unknown(message: 'Something went wrong. Please try again.'),
      );
    }
  }

  void dispose() {
    _verifiedSession = null;
    _requestedEmail = null;
    _client.close();
  }
}
