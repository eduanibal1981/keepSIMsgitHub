import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

enum FreeCallInviteChannel { whatsapp, sms }

final freeCallInvitationServiceProvider = Provider(
  (ref) => FreeCallInvitationService(),
);

class FreeCallInvitationService {
  final Future<bool> Function(Uri) _launcher;
  FreeCallInvitationService({Future<bool> Function(Uri)? launcher})
    : _launcher = launcher ?? _launch;
  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
  static const _native = MethodChannel('com.keep_sims/invitations');
  // Supply a real store/test download URL when one is available. The old
  // marketing page contains placeholder store buttons, so don't send it as a
  // working download link.
  static const downloadUrl = String.fromEnvironment(
    'FREE_CALL_APP_DOWNLOAD_URL',
  );

  String message({bool arabic = false}) {
    final text = arabic
        ? 'انضم إليّ على KeepSIMs للمكالمات المجانية بين التطبيقين. ثبّت التطبيق وسجّل الدخول.'
        : 'Join me on KeepSIMs for free app-to-app calls. Install the app and sign in.';
    final url = Uri.tryParse(downloadUrl);
    return url != null && url.scheme == 'https' && url.host.isNotEmpty
        ? '$text\n$url'
        : text;
  }

  Future<bool> compose(
    FreeCallInviteChannel channel,
    String number, {
    bool arabic = false,
  }) async {
    if (!RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(number)) return false;
    final body = message(arabic: arabic);
    try {
      if (channel == FreeCallInviteChannel.sms) {
        if (kIsWeb ||
            (defaultTargetPlatform != TargetPlatform.android &&
                defaultTargetPlatform != TargetPlatform.iOS)) {
          return false;
        }
        return await _native.invokeMethod<bool>('composeSms', {
              'phone': number,
              'body': body,
            }) ??
            false;
      }
      // Prefer the installed app. A missing handler is shown to the caller;
      // no browser, alternate channel, or message send happens implicitly.
      final uri = Uri(
        scheme: 'whatsapp',
        host: 'send',
        query: 'phone=${number.substring(1)}&text=${Uri.encodeComponent(body)}',
      );
      return await _launcher(uri);
    } catch (_) {
      return false;
    }
  }
}
