import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/domain/call_destination.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/controllers/smart_call_dialer_controller.dart';
import 'package:keep_sims/features/calling/presentation/widgets/destination_country_picker.dart';
import 'package:keep_sims/features/calling/presentation/widgets/verify_caller_id_sheet.dart';

/// Shared pre-call review for selected contacts, the manual dialer and redial.
class CallReviewSheet extends ConsumerStatefulWidget {
  final String? suggestedCountryIso;
  const CallReviewSheet({super.key, this.suggestedCountryIso});

  static Future<ReviewedCall?> show(
    BuildContext context, {
    String? suggestedCountryIso,
  }) {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<ReviewedCall>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CallReviewSheet(suggestedCountryIso: suggestedCountryIso),
    );
  }

  /// UI dispatch only: controller/repository retain call creation and pricing.
  static Future<void> showAndCall(
    BuildContext context,
    WidgetRef ref, {
    String? suggestedCountryIso,
  }) async {
    final call = await show(context, suggestedCountryIso: suggestedCountryIso);
    if (call == null || !context.mounted) return;
    final controller = ref.read(callingControllerProvider.notifier);
    // startCall locks its active state synchronously against repeated attempts.
    unawaited(
      controller.startCall(
        destinationNumber: call.destinationNumber,
        callerIdId: call.callerIdId,
        explicitGateway: call.explicitGateway,
        userCallbackNumber: call.quote.effectiveCallerId,
        rate: call.quote.rate,
      ),
    );
    if (context.mounted) context.push(AppRoutes.callingActive);
  }

  @override
  ConsumerState<CallReviewSheet> createState() => _CallReviewSheetState();
}

class _CallReviewSheetState extends ConsumerState<CallReviewSheet> {
  bool _initializingIdentity = true;
  bool _submitting = false;
  bool _editing = false;
  bool _changingCountry = false;
  String? _pendingCountry;
  String? _message;
  final _number = TextEditingController();

  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';
  String _text(String en, String ar) => _ar ? ar : en;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(smartCallDialerProvider);
    _number.text = draft.rawNumber;
    _pendingCountry = draft.suggestedCountryIso ?? widget.suggestedCountryIso;
    unawaited(_initializeIdentity());
  }

  Future<void> _initializeIdentity() async {
    try {
      final ids = await ref
          .read(callerIdListProvider.future)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final identity = ref.read(smartCallDialerProvider);
      final selectedId = identity.selectedCallerIdId;
      final personal = ids.callerIds
          .where(
            (c) =>
                c.isVerified &&
                (c.id == selectedId ||
                    (selectedId == null &&
                        !identity.identityExplicitlySelected &&
                        (c.isDefault || c.phoneNumber == ids.activeCallerId))),
          )
          .firstOrNull;
      ref
          .read(smartCallDialerProvider.notifier)
          .selectIdentity(
            isGateway:
                personal == null ||
                (ref.read(smartCallDialerProvider).selectedCallerIdId == null &&
                    ids.isGatewayActive),
            userSelected: false,
            callerIdId: personal?.id,
            phoneNumber: personal?.phoneNumber,
          );
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = _text(
            'Could not load caller IDs. Please retry.',
            'تعذر تحميل هوية المتصل. حاول مرة أخرى.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _initializingIdentity = false);
    }
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _chooseCountry() async {
    final iso = await pickDestinationCountry(
      context,
      suggestedIso: _pendingCountry,
    );
    if (!mounted || iso == null) return;
    setState(() {
      _pendingCountry = iso;
      _changingCountry = true;
    });
  }

  Future<void> _chooseIdentity(CallerIdListResult ids) async {
    final draft = ref.read(smartCallDialerProvider);
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _text('Caller ID', 'هوية المتصل'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(_text('KeepSIMs number', 'رقم KeepSIMs')),
                subtitle: _phone(ids.defaultGatewayNumber),
                trailing: draft.isGatewaySelected
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, 'gateway'),
              ),
              ...ids.callerIds
                  .where((c) => c.isVerified)
                  .map(
                    (c) => ListTile(
                      leading: const Icon(Icons.verified_outlined),
                      title: _phone(c.phoneNumber),
                      subtitle: Text(c.label),
                      trailing:
                          !draft.isGatewaySelected &&
                              draft.selectedCallerIdId == c.id
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, c.id),
                    ),
                  ),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(_text('Verify another number', 'تحقق من رقم آخر')),
                onTap: () => Navigator.pop(context, 'verify'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == 'verify') {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const VerifyCallerIdSheet(),
      );
      return;
    }
    final personal = ids.callerIds
        .where((c) => c.id == result && c.isVerified)
        .firstOrNull;
    ref
        .read(smartCallDialerProvider.notifier)
        .selectIdentity(
          isGateway: result == 'gateway',
          callerIdId: personal?.id,
          phoneNumber: personal?.phoneNumber,
        );
    setState(() => _message = null);
  }

  Future<void> _call() async {
    if (_submitting) return;
    final beforePermission = ref.read(smartCallDialerProvider);
    final ids = ref.read(callerIdListProvider).asData?.value;
    if (!beforePermission.canCall ||
        ids == null ||
        !beforePermission.isGatewaySelected &&
            !ids.callerIds.any(
              (c) =>
                  c.id == beforePermission.selectedCallerIdId && c.isVerified,
            )) {
      return;
    }
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      if (!kIsWeb) {
        var permission = await Permission.microphone.status;
        if (!permission.isGranted) {
          permission = await Permission.microphone.request();
        }
        if (!mounted) return;
        if (!permission.isGranted) {
          setState(
            () => _message = _text(
              'Microphone access is needed to make a call.',
              'يلزم السماح بالميكروفون لإجراء مكالمة.',
            ),
          );
          if (permission.isPermanentlyDenied) {
            await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(_text('Microphone access', 'السماح بالميكروفون')),
                content: Text(
                  _text(
                    'Enable microphone access in device settings to make calls.',
                    'فعّل الميكروفون من إعدادات الجهاز لإجراء المكالمات.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(_text('Cancel', 'إلغاء')),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openAppSettings();
                    },
                    child: Text(_text('Open settings', 'فتح الإعدادات')),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }
      if (!mounted ||
          ref.read(smartCallDialerProvider).revision !=
              beforePermission.revision) {
        return;
      }
      final call = await ref
          .read(smartCallDialerProvider.notifier)
          .confirmReviewedCall();
      if (mounted && call != null) Navigator.pop(context, call);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = _text(
            'Could not prepare the call. Please retry.',
            'تعذر تجهيز المكالمة. حاول مرة أخرى.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _phone(String value, {TextStyle? style}) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(value, style: style, softWrap: true),
  );
  Widget _label(String value) => Text(
    value,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: _ar ? 0 : .8,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(smartCallDialerProvider);
    final idsAsync = ref.watch(callerIdListProvider);
    final ids = idsAsync.asData?.value;
    final destination = draft.destination;
    final quote = draft.previewResult;
    final countryForm = destination.needsCountry || _changingCountry;
    final pending = CallDestination.resolve(
      draft.rawNumber,
      countryIso: _pendingCountry,
    );
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final accent = theme.brightness == Brightness.dark
        ? AppColors.secondary
        : AppColors.lightSecondary;
    final identityValid =
        ids != null &&
        (draft.isGatewaySelected ||
            ids.callerIds.any(
              (c) => c.id == draft.selectedCallerIdId && c.isVerified,
            ));
    final selectedIdentity = ids?.callerIds
        .where((c) => c.id == draft.selectedCallerIdId)
        .firstOrNull;
    final callerNumber =
        quote?.effectiveCallerId ??
        (draft.isGatewaySelected
            ? ids?.defaultGatewayNumber
            : selectedIdentity?.phoneNumber);
    final canCall =
        draft.canCall &&
        identityValid &&
        !_submitting &&
        !_initializingIdentity &&
        !_editing &&
        !countryForm;
    final hasRate =
        quote?.rate != null &&
        !draft.isPreviewLoading &&
        !countryForm &&
        !_editing;
    final error =
        _message ??
        draft.previewError ??
        (destination.error == null
            ? null
            : _text(
                destination.error!,
                'تحقق من الرقم ورمز الدولة. استخدم + للأرقام الدولية.',
              ));

    return PopScope(
      canPop: !_submitting,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .9,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: color.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _text('Review call', 'مراجعة المكالمة'),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: _text('Close', 'إغلاق'),
                        onPressed: _submitting
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _label(_text('CALLING', 'الاتصال بـ')),
                  const SizedBox(height: 8),
                  if (_editing)
                    TextField(
                      key: const Key('review-number-input'),
                      controller: _number,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: _text('Phone number', 'رقم الهاتف'),
                      ),
                      onChanged: (v) {
                        ref.read(smartCallDialerProvider.notifier).setNumber(v);
                        setState(() {
                          _message = null;
                          _changingCountry = false;
                        });
                      },
                      onSubmitted: (_) {
                        FocusScope.of(context).unfocus();
                        setState(() => _editing = false);
                      },
                    )
                  else
                    _phone(
                      destination.displayNumber ?? draft.rawNumber,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: destination.countryIso != null && !countryForm
                            ? TextButton(
                                onPressed:
                                    _submitting ||
                                        CallDestination.normalizeDigits(
                                          draft.rawNumber,
                                        ).trim().startsWith('+')
                                    ? null
                                    : _chooseCountry,
                                style: TextButton.styleFrom(
                                  alignment: AlignmentDirectional.centerStart,
                                  padding: EdgeInsets.zero,
                                  foregroundColor: accent,
                                ),
                                child: Text(
                                  destinationCountryLabel(
                                    context,
                                    destination.countryIso,
                                  ),
                                ),
                              )
                            : TextButton(
                                onPressed: _submitting ? null : _chooseCountry,
                                style: TextButton.styleFrom(
                                  alignment: AlignmentDirectional.centerStart,
                                  padding: EdgeInsets.zero,
                                  foregroundColor: accent,
                                ),
                                child: Text(
                                  _pendingCountry == null
                                      ? _text('Choose country', 'اختر البلد')
                                      : destinationCountryLabel(
                                          context,
                                          _pendingCountry,
                                        ),
                                ),
                              ),
                      ),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  _editing = !_editing;
                                  _number.text = draft.rawNumber;
                                });
                              },
                        child: Text(
                          _editing
                              ? _text('Done', 'تم')
                              : _text('Edit', 'تعديل'),
                        ),
                      ),
                    ],
                  ),
                  if (countryForm && !_editing) ...[
                    Text(
                      _text(
                        'Choose the country this number belongs to.',
                        'اختر البلد الذي ينتمي إليه هذا الرقم.',
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (_pendingCountry != null) ...[
                      const SizedBox(height: 8),
                      if (pending.isValid)
                        _phone(
                          pending.displayNumber!,
                          style: theme.textTheme.bodyLarge,
                        )
                      else
                        Text(
                          _text(
                            'This number does not match the selected country.',
                            'هذا الرقم لا يطابق البلد المختار.',
                          ),
                          style: TextStyle(color: color.error),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: const Key('confirm-destination-country'),
                        onPressed: pending.isValid && !_submitting
                            ? () {
                                ref
                                    .read(smartCallDialerProvider.notifier)
                                    .selectCountry(_pendingCountry!);
                                setState(() => _changingCountry = false);
                              }
                            : null,
                        child: Text(
                          '${_text('Use', 'استخدام')} ${destinationCountryLabel(context, _pendingCountry)}',
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(_text('CALLER ID', 'هوية المتصل')),
                              const SizedBox(height: 6),
                              Text(
                                draft.isGatewaySelected
                                    ? _text('KeepSIMs number', 'رقم KeepSIMs')
                                    : _text(
                                        'My verified number',
                                        'رقمي المتحقق منه',
                                      ),
                                style: theme.textTheme.titleMedium,
                              ),
                              if (callerNumber != null)
                                _phone(
                                  callerNumber,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: color.onSurfaceVariant,
                                  ),
                                ),
                              if (_initializingIdentity)
                                Text(_text('Loading…', 'جارٍ التحميل…')),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: ids == null || _submitting
                              ? null
                              : () => _chooseIdentity(ids),
                          child: Text(_text('Change', 'تغيير')),
                        ),
                      ],
                    ),
                  ),
                  if (idsAsync.hasError ||
                      (ids == null && !_initializingIdentity))
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () {
                              ref.invalidate(callerIdListProvider);
                              setState(() {
                                _initializingIdentity = true;
                                _message = null;
                              });
                              unawaited(_initializeIdentity());
                            },
                      child: Text(
                        _text('Retry caller IDs', 'إعادة تحميل هوية المتصل'),
                      ),
                    ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(_text('CALL RATE', 'سعر المكالمة')),
                              const SizedBox(height: 6),
                              Text(
                                hasRate
                                    ? (quote!.billingIncrementSeconds == 1
                                          ? _text(
                                              'Billed per second',
                                              'المحاسبة بالثانية',
                                            )
                                          : '${_text('Billed every', 'المحاسبة كل')} ${quote.billingIncrementSeconds} ${_text('seconds', 'ثانية')}')
                                    : draft.isPreviewLoading
                                    ? _text(
                                        'Checking rate…',
                                        'جارٍ التحقق من السعر…',
                                      )
                                    : _text(
                                        'Confirm the number first',
                                        'أكد الرقم أولاً',
                                      ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: color.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (hasRate) ...[
                                _phone(
                                  '${_usdRate(quote!.rate!.ratePerMinute)}/min',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                ApproxLocalRateText(
                                  quote.rate!.ratePerMinute,
                                  unit: '/min',
                                  minDigits: 3,
                                ),
                              ] else
                                Text('—', style: theme.textTheme.headlineSmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasRate && quote!.connectionFee > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _text('Connection fee', 'رسوم الاتصال'),
                            ),
                          ),
                          _phone(_usdRate(quote.connectionFee)),
                        ],
                      ),
                    ),
                  if (error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(error, style: TextStyle(color: color.error)),
                    ),
                  if (draft.previewError != null)
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => ref
                                .read(smartCallDialerProvider.notifier)
                                .refreshPreview(),
                      child: Text(_text('Retry', 'إعادة المحاولة')),
                    ),
                  if (draft.previewNotice != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _text(
                          draft.previewNotice!,
                          'تغيرت تفاصيل المكالمة. راجع التفاصيل واضغط اتصال مرة أخرى.',
                        ),
                      ),
                    ),
                  if (quote != null &&
                      quote.eligible &&
                      !draft.hasSufficientBalance &&
                      !draft.isPreviewLoading) ...[
                    Text(
                      _text(
                        'Insufficient balance for this call.',
                        'الرصيد غير كافٍ لهذه المكالمة.',
                      ),
                      style: TextStyle(color: color.error),
                    ),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () {
                              final router = GoRouter.of(context);
                              Navigator.pop(context);
                              router.push(AppRoutes.wallet);
                            },
                      child: Text(_text('Add funds', 'إضافة رصيد')),
                    ),
                  ],
                  if (quote != null &&
                      !quote.eligible &&
                      !draft.isPreviewLoading) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        quote.policyReason,
                        style: TextStyle(color: color.error),
                      ),
                    ),
                    if (quote.suggestedAction == 'use_gateway' &&
                        !draft.isGatewaySelected)
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => ref
                                  .read(smartCallDialerProvider.notifier)
                                  .selectIdentity(isGateway: true),
                        child: Text(
                          _text('Use KeepSIMs number', 'استخدام رقم KeepSIMs'),
                        ),
                      ),
                    if (quote.policyCode == 'INSUFFICIENT_BALANCE' ||
                        quote.suggestedAction == 'add_funds')
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                final router = GoRouter.of(context);
                                Navigator.pop(context);
                                router.push(AppRoutes.wallet);
                              },
                        child: Text(_text('Add funds', 'إضافة رصيد')),
                      ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('review-call-button'),
                      onPressed: canCall ? _call : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: theme.brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.call),
                      label: Text(_text('Call', 'اتصال')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _usdRate(double rate) {
    if (rate > 0 && rate < .000001) return r'< $0.000001';
    final value = rate.toStringAsFixed(6).replaceFirst(RegExp(r'0{1,3}$'), '');
    return '\$$value';
  }
}
