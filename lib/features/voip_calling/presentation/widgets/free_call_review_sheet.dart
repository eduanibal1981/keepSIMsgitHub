import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/calling/domain/call_destination.dart';
import 'package:keep_sims/features/calling/presentation/controllers/smart_call_dialer_controller.dart';
import 'package:keep_sims/features/calling/presentation/widgets/call_review_sheet.dart';
import 'package:keep_sims/features/calling/presentation/widgets/destination_country_picker.dart';
import 'package:keep_sims/features/voip_calling/data/repositories/voip_calling_repository.dart';
import 'package:keep_sims/features/voip_calling/data/services/free_call_invitation_service.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/free_call_review_controller.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';

final freeCallMicrophoneProvider =
    Provider<Future<PermissionStatus> Function()>(
      (ref) =>
          () => Permission.microphone.request(),
    );

class FreeCallReviewOutcome {
  final ContactLookupResult? recipient;
  final String? callerId;
  final String? paidNumber;
  const FreeCallReviewOutcome({this.recipient, this.callerId, this.paidNumber});
}

class FreeCallReviewSheet extends ConsumerStatefulWidget {
  final FreeCallSelection selection;
  final String? suggestedCountryIso;
  const FreeCallReviewSheet({
    super.key,
    required this.selection,
    this.suggestedCountryIso,
  });

  static Future<void> showAndCall(
    BuildContext context,
    WidgetRef ref, {
    required FreeCallSelection selection,
    String? suggestedCountryIso,
  }) async {
    if (ref.read(voipCallingControllerProvider).isActive) {
      context.push(AppRoutes.voipCall);
      return;
    }
    FocusScope.of(context).unfocus();
    final outcome = await showModalBottomSheet<FreeCallReviewOutcome>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FreeCallReviewSheet(
        selection: selection,
        suggestedCountryIso: suggestedCountryIso,
      ),
    );
    if (outcome == null || !context.mounted) return;
    if (outcome.paidNumber != null) {
      ref.read(smartCallDialerProvider.notifier).setNumber(outcome.paidNumber!);
      await CallReviewSheet.showAndCall(context, ref);
      return;
    }
    final recipient = outcome.recipient;
    if (recipient == null ||
        outcome.callerId == null ||
        ref.read(freeCallAccountProvider) != outcome.callerId ||
        ref.read(voipCallingRepositoryProvider).currentUserId !=
            outcome.callerId ||
        recipient.userId == outcome.callerId) {
      return;
    }
    unawaited(
      ref
          .read(voipCallingControllerProvider.notifier)
          .startCall(
            calleeId: recipient.userId,
            calleeName: recipient.fullName,
            calleeAvatar: recipient.avatarUrl,
            calleePhone: recipient.phone,
          ),
    );
    if (context.mounted) context.push(AppRoutes.voipCall);
  }

  @override
  ConsumerState<FreeCallReviewSheet> createState() =>
      _FreeCallReviewSheetState();
}

class _FreeCallReviewSheetState extends ConsumerState<FreeCallReviewSheet> {
  late final TextEditingController _number;
  bool _editing = false;
  bool _submitting = false;
  bool _inviting = false;
  bool _settings = false;
  bool _returnedFromInvite = false;
  String? _pendingCountry;
  String? _message;
  bool _channelUnavailable = false;
  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String en, String ar) => _ar ? ar : en;
  FreeCallReviewController get _controller =>
      ref.read(freeCallReviewProvider(widget.selection).notifier);

  @override
  void initState() {
    super.initState();
    _number = TextEditingController(text: widget.selection.rawNumber);
    _pendingCountry = widget.selection.countryIso ?? widget.suggestedCountryIso;
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _call() async {
    final draft = ref.read(freeCallReviewProvider(widget.selection));
    if (_submitting || !draft.canCall) return;
    final caller = ref.read(freeCallAccountProvider);
    final revision = draft.revision;
    setState(() {
      _submitting = true;
      _message = null;
      _settings = false;
    });
    try {
      if (ref.read(voipCallingControllerProvider).isActive) {
        if (mounted) Navigator.pop(context, const FreeCallReviewOutcome());
        return;
      }
      final permission = await ref.read(freeCallMicrophoneProvider)();
      if (!mounted) return;
      final current = ref.read(freeCallReviewProvider(widget.selection));
      if (current.revision != revision ||
          ref.read(freeCallAccountProvider) != caller) {
        return;
      }
      if (!permission.isGranted) {
        setState(() {
          _settings = permission.isPermanentlyDenied;
          _message = _t(
            'Allow microphone access to make this call.',
            'اسمح باستخدام الميكروفون لإجراء المكالمة.',
          );
        });
        return;
      }
      final recipient = await _controller.prepareCall();
      if (!mounted || ref.read(freeCallAccountProvider) != caller) return;
      if (recipient == null) {
        setState(
          () => _message = _t(
            'Review the updated recipient, then tap Call free again.',
            'راجع المستلم المحدّث ثم اضغط اتصال مجاني مرة أخرى.',
          ),
        );
        return;
      }
      if (ref.read(voipCallingControllerProvider).isActive) return;
      Navigator.pop(
        context,
        FreeCallReviewOutcome(recipient: recipient, callerId: caller),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = _t(
            'Couldn’t start the call. Please try again.',
            'تعذر بدء المكالمة. حاول مرة أخرى.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _invite(FreeCallInviteChannel channel) async {
    final draft = ref.read(freeCallReviewProvider(widget.selection));
    if (_inviting || !draft.canInvite) return;
    setState(() {
      _inviting = true;
      _message = null;
      _channelUnavailable = false;
    });
    final opened = await ref
        .read(freeCallInvitationServiceProvider)
        .compose(channel, draft.destination.e164!, arabic: _ar);
    if (!mounted) return;
    setState(() {
      _inviting = false;
      _returnedFromInvite = opened;
      _channelUnavailable = !opened;
      _message = opened
          ? null
          : _t(
              '${channel == FreeCallInviteChannel.whatsapp ? 'WhatsApp' : 'Messages'} is unavailable on this device. Try the other option or share the invitation.',
              'تطبيق ${channel == FreeCallInviteChannel.whatsapp ? 'واتساب' : 'الرسائل'} غير متاح. جرّب الخيار الآخر أو شارك الدعوة.',
            );
    });
  }

  Future<void> _share() async {
    final draft = ref.read(freeCallReviewProvider(widget.selection));
    if (!draft.canInvite) return;
    final box = context.findRenderObject() as RenderBox?;
    try {
      await Share.share(
        ref.read(freeCallInvitationServiceProvider).message(arabic: _ar),
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = _t(
            'Sharing is unavailable on this device.',
            'المشاركة غير متاحة على هذا الجهاز.',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(freeCallReviewProvider(widget.selection));
    final profile = ref.watch(authControllerProvider).asData?.value;
    final destination = draft.destination;
    final recipient = draft.recipient;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = theme.brightness == Brightness.dark
        ? const Color(0xFF48DEAA)
        : const Color(0xFF00745B);
    final busy = _submitting || _inviting;
    final needsCountry = draft.knownUserId == null && destination.needsCountry;
    String? status;
    if (draft.checking) {
      status = _t(
        'Checking KeepSIMs account…',
        'جارٍ التحقق من حساب KeepSIMs…',
      );
    } else if (draft.failed) {
      status = _t(
        'Couldn’t check this number. Please try again.',
        'تعذر التحقق من هذا الرقم. حاول مرة أخرى.',
      );
    } else {
      status = switch (draft.resolution?.status) {
        FreeRecipientStatus.notFound => _t(
          'No KeepSIMs account found for this number. Invite them to install the app and sign in.',
          'لم يتم العثور على حساب KeepSIMs لهذا الرقم. ادعُهم لتثبيت التطبيق وتسجيل الدخول.',
        ),
        FreeRecipientStatus.self => _t(
          'This belongs to your account. Choose a different KeepSIMs user.',
          'هذا الرقم يتبع حسابك. اختر مستخدماً آخر على KeepSIMs.',
        ),
        FreeRecipientStatus.ambiguous || FreeRecipientStatus.unverified => _t(
          'Couldn’t confirm one KeepSIMs account for this number. Choose a known contact or edit the number.',
          'تعذر تأكيد حساب KeepSIMs واحد لهذا الرقم. اختر جهة اتصال معروفة أو عدّل الرقم.',
        ),
        FreeRecipientStatus.unavailable => _t(
          'This KeepSIMs contact is unavailable. Choose another contact.',
          'جهة الاتصال هذه غير متاحة على KeepSIMs. اختر جهة أخرى.',
        ),
        _ => null,
      };
    }
    Widget phone(String value) => Text(
      value,
      textDirection: TextDirection.ltr,
      style: theme.textTheme.bodyLarge,
      key: const Key('free-review-number'),
    );
    Widget button(
      String label,
      VoidCallback? action, {
      IconData? icon,
      bool primary = false,
      Key? key,
    }) => SizedBox(
      width: double.infinity,
      child: primary
          ? FilledButton.icon(
              key: key,
              onPressed: action,
              icon: Icon(icon ?? Icons.call),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: theme.brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          : OutlinedButton.icon(
              key: key,
              onPressed: action,
              icon: Icon(icon ?? Icons.message_outlined),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
    );
    return PopScope(
      canPop: !busy,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _t('Free Call', 'اتصال مجاني'),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: _t('Close', 'إغلاق'),
                        onPressed: busy ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: accent.withValues(alpha: .12),
                        foregroundColor: accent,
                        child: const Icon(Icons.person_outline),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipient?.fullName ??
                                  _t('Selected number', 'الرقم المحدد'),
                              style: theme.textTheme.titleLarge,
                            ),
                            if (recipient != null)
                              Text(
                                _t('On KeepSIMs', 'على KeepSIMs'),
                                style: TextStyle(color: accent),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: phone(
                          destination.displayNumber ??
                              (draft.rawNumber.isNotEmpty
                                  ? draft.rawNumber
                                  : _t(
                                      'KeepSIMs contact',
                                      'جهة اتصال KeepSIMs',
                                    )),
                        ),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                setState(() {
                                  _editing = !_editing;
                                  _message = null;
                                  _channelUnavailable = false;
                                  _number.text = draft.rawNumber;
                                });
                              },
                        child: Text(_t('Edit', 'تعديل')),
                      ),
                    ],
                  ),
                  Text(
                    _t(
                      'Both of you need the KeepSIMs app for free calls.',
                      'يجب أن يكون تطبيق KeepSIMs لدى كليكما لإجراء مكالمات مجانية.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    key: const Key('free-app-requirement'),
                  ),
                  const SizedBox(height: 14),
                  if (_editing) ...[
                    TextField(
                      controller: _number,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: _t('Phone number', 'رقم الهاتف'),
                      ),
                      onChanged: _controller.setNumber,
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _editing = false);
                        unawaited(_controller.resolve());
                      },
                      child: Text(_t('Done', 'تم')),
                    ),
                  ] else ...[
                    if (needsCountry) ...[
                      Text(
                        _t(
                          'Choose the country this number belongs to.',
                          'اختر البلد الذي يتبعه هذا الرقم.',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final iso = await pickDestinationCountry(
                                  context,
                                  suggestedIso: _pendingCountry,
                                );
                                if (mounted && iso != null) {
                                  setState(() => _pendingCountry = iso);
                                }
                              },
                        icon: const Icon(Icons.public),
                        label: Text(
                          _pendingCountry == null
                              ? _t('Choose country', 'اختر البلد')
                              : destinationCountryLabel(
                                  context,
                                  _pendingCountry,
                                ),
                        ),
                      ),
                      if (_pendingCountry != null) ...[
                        phone(
                          CallDestination.resolve(
                                draft.rawNumber,
                                countryIso: _pendingCountry,
                              ).displayNumber ??
                              draft.rawNumber,
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _controller.confirmCountry(
                                  _pendingCountry!,
                                ),
                          child: Text(
                            '${_t('Use', 'استخدام')} ${destinationCountryLabel(context, _pendingCountry)}',
                          ),
                        ),
                      ],
                    ],
                    if (destination.error != null && draft.knownUserId == null)
                      Text(
                        _t(
                          destination.error!,
                          'تحقق من رقم الهاتف ورمز البلد.',
                        ),
                        style: TextStyle(color: colors.error),
                      ),
                    if (status != null)
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(status),
                        ),
                      ),
                    if (draft.canCall) ...[
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(_t('Calling as', 'الاتصال باسم')),
                        subtitle: Text(
                          profile?.fullName ??
                              _t(
                                'Your KeepSIMs profile',
                                'ملفك الشخصي على KeepSIMs',
                              ),
                        ),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _t(
                                'Uses Wi-Fi or mobile data',
                                'يستخدم شبكة Wi-Fi أو بيانات الهاتف',
                              ),
                            ),
                          ),
                          Text(
                            _t('Free', 'مجاني'),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      button(
                        _t('Call free', 'اتصال مجاني'),
                        busy ? null : _call,
                        primary: true,
                        key: const Key('free-review-call'),
                      ),
                    ],
                    if (draft.canInvite) ...[
                      button(
                        _t('Invite via WhatsApp', 'دعوة عبر واتساب'),
                        busy
                            ? null
                            : () => _invite(FreeCallInviteChannel.whatsapp),
                        icon: Icons.chat_bubble_outline,
                        primary: true,
                        key: const Key('free-invite-whatsapp'),
                      ),
                      const SizedBox(height: 10),
                      button(
                        _t('Invite via SMS', 'دعوة عبر الرسائل النصية'),
                        busy ? null : () => _invite(FreeCallInviteChannel.sms),
                        key: const Key('free-invite-sms'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.pop(
                                context,
                                FreeCallReviewOutcome(
                                  paidNumber: destination.e164,
                                ),
                              ),
                        child: Text(
                          _t('See paid call rate', 'عرض سعر المكالمة المدفوعة'),
                        ),
                      ),
                      if (_returnedFromInvite || !_inviting)
                        TextButton(
                          onPressed: busy ? null : () => _controller.resolve(),
                          child: Text(_t('Check again', 'تحقق مرة أخرى')),
                        ),
                    ],
                    if (draft.failed ||
                        draft.resolution?.status ==
                            FreeRecipientStatus.unavailable)
                      TextButton(
                        onPressed: busy ? null : () => _controller.resolve(),
                        child: Text(_t('Retry', 'إعادة المحاولة')),
                      ),
                  ],
                  if (_message != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _message!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  if (_settings)
                    TextButton(
                      onPressed: busy ? null : () => openAppSettings(),
                      child: Text(_t('Open settings', 'فتح الإعدادات')),
                    ),
                  if (_channelUnavailable && draft.canInvite)
                    TextButton(
                      onPressed: busy ? null : _share,
                      child: Text(_t('Share invitation', 'مشاركة الدعوة')),
                    ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
