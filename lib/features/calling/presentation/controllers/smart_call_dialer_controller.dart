/// Call draft, country-aware destination and current server quote.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/domain/call_destination.dart';

class SmartCallDialerState {
  final String rawNumber;
  final String? selectedCountryIso;
  final String? suggestedCountryIso;
  final CallRate? selectedRate;
  final CallPreviewResult? previewResult;
  final bool isPreviewLoading;
  final String? previewError;
  final String? previewNotice;
  final bool isGatewaySelected;
  final bool identityExplicitlySelected;
  final String? selectedCallerIdId;
  final String? effectiveCallerId;
  final int revision;

  const SmartCallDialerState({
    this.rawNumber = '',
    this.selectedCountryIso,
    this.suggestedCountryIso,
    this.selectedRate,
    this.previewResult,
    this.isPreviewLoading = false,
    this.previewError,
    this.previewNotice,
    this.isGatewaySelected = true,
    this.identityExplicitlySelected = false,
    this.selectedCallerIdId,
    this.effectiveCallerId,
    this.revision = 0,
  });

  SmartCallDialerState copyWith({
    String? rawNumber,
    String? selectedCountryIso,
    bool clearCountry = false,
    String? suggestedCountryIso,
    CallRate? selectedRate,
    bool clearSelectedRate = false,
    CallPreviewResult? previewResult,
    bool clearPreviewResult = false,
    bool? isPreviewLoading,
    String? previewError,
    String? previewNotice,
    bool clearPreviewError = false,
    bool? isGatewaySelected,
    bool? identityExplicitlySelected,
    String? selectedCallerIdId,
    bool clearCallerId = false,
    String? effectiveCallerId,
    int? revision,
  }) => SmartCallDialerState(
    rawNumber: rawNumber ?? this.rawNumber,
    selectedCountryIso: clearCountry
        ? null
        : selectedCountryIso ?? this.selectedCountryIso,
    suggestedCountryIso: suggestedCountryIso ?? this.suggestedCountryIso,
    selectedRate: clearSelectedRate ? null : selectedRate ?? this.selectedRate,
    previewResult: clearPreviewResult
        ? null
        : previewResult ?? this.previewResult,
    isPreviewLoading: isPreviewLoading ?? this.isPreviewLoading,
    previewError: clearPreviewError ? null : previewError ?? this.previewError,
    previewNotice: clearPreviewError
        ? null
        : previewNotice ?? this.previewNotice,
    isGatewaySelected: isGatewaySelected ?? this.isGatewaySelected,
    identityExplicitlySelected:
        identityExplicitlySelected ?? this.identityExplicitlySelected,
    selectedCallerIdId: clearCallerId
        ? null
        : selectedCallerIdId ?? this.selectedCallerIdId,
    effectiveCallerId: clearCallerId
        ? null
        : effectiveCallerId ?? this.effectiveCallerId,
    revision: revision ?? this.revision,
  );

  CallDestination get destination =>
      CallDestination.resolve(rawNumber, countryIso: selectedCountryIso);
  String get formattedDestination => destination.e164 ?? '';
  double get effectiveRatePerMinute => previewResult?.rate?.ratePerMinute ?? 0;
  double get effectiveRatePerSecond => effectiveRatePerMinute / 60;
  bool get hasSufficientBalance =>
      previewResult != null &&
      previewResult!.availableBalance.isFinite &&
      previewResult!.availableBalance >=
          (previewResult!.rate?.ratePerMinute ?? double.infinity);

  bool get canCall =>
      destination.isValid &&
      !isPreviewLoading &&
      previewError == null &&
      previewResult?.eligible == true &&
      previewResult?.rate != null &&
      previewResult!.rate!.ratePerMinute.isFinite &&
      previewResult!.rate!.ratePerMinute > 0 &&
      previewResult!.connectionFee.isFinite &&
      previewResult!.connectionFee >= 0 &&
      previewResult!.billingIncrementSeconds > 0 &&
      hasSufficientBalance &&
      previewResult!.effectiveCallerId.isNotEmpty &&
      (isGatewaySelected
          ? previewResult!.callerIdType == 'gateway'
          : selectedCallerIdId != null &&
                previewResult!.effectiveCallerId == effectiveCallerId);
}

/// Snapshot of exactly the destination and identity reviewed by the user.
class ReviewedCall {
  final String destinationNumber;
  final String? callerIdId;
  final bool explicitGateway;
  final CallPreviewResult quote;
  const ReviewedCall({
    required this.destinationNumber,
    this.callerIdId,
    required this.explicitGateway,
    required this.quote,
  });
}

class SmartCallDialerNotifier extends Notifier<SmartCallDialerState> {
  Timer? _debounceTimer;
  int _requestEpoch = 0;
  bool _disposed = false;

  @override
  SmartCallDialerState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _requestEpoch++;
      _debounceTimer?.cancel();
    });
    return const SmartCallDialerState();
  }

  void _invalidate() {
    _requestEpoch++;
    _debounceTimer?.cancel();
    state = state.copyWith(
      revision: state.revision + 1,
      clearPreviewResult: true,
      clearSelectedRate: true,
      clearPreviewError: true,
      isPreviewLoading: false,
    );
  }

  /// New contacts/pasted numbers must never inherit an earlier country choice.
  /// Editing digits of the same draft can explicitly retain that choice.
  void setNumber(String number, {bool preserveCountry = false}) {
    _invalidate();
    state = state.copyWith(rawNumber: number, clearCountry: !preserveCountry);
    _schedulePreview();
  }

  void clear() => setNumber('');

  void selectCountry(String iso) {
    _invalidate();
    state = state.copyWith(selectedCountryIso: iso, suggestedCountryIso: iso);
    _schedulePreview();
  }

  void selectIdentity({
    required bool isGateway,
    bool userSelected = true,
    String? callerIdId,
    String? phoneNumber,
  }) {
    _invalidate();
    state = state.copyWith(
      isGatewaySelected: isGateway,
      identityExplicitlySelected:
          userSelected || state.identityExplicitlySelected,
      selectedCallerIdId: callerIdId,
      effectiveCallerId: phoneNumber,
      clearCallerId: isGateway,
    );
    _schedulePreview();
  }

  void _schedulePreview() {
    if (!state.destination.isValid ||
        (!state.isGatewaySelected && state.selectedCallerIdId == null)) {
      return;
    }
    state = state.copyWith(isPreviewLoading: true);
    final draft = state;
    final epoch = _requestEpoch;
    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      () => _executePreview(draft, epoch),
    );
  }

  Future<CallPreviewResult?> _executePreview(
    SmartCallDialerState draft,
    int epoch,
  ) async {
    try {
      final preview = await ref
          .read(callingRepositoryProvider)
          .previewCall(
            destinationNumber: draft.formattedDestination,
            callerIdId: draft.isGatewaySelected
                ? null
                : draft.selectedCallerIdId,
            explicitGateway: draft.isGatewaySelected,
          )
          .timeout(const Duration(seconds: 20));
      if (_disposed || epoch != _requestEpoch) return null;
      state = state.copyWith(
        previewResult: preview,
        selectedRate: preview.rate,
        clearSelectedRate: preview.rate == null,
        isPreviewLoading: false,
      );
      return preview;
    } catch (_) {
      if (!_disposed && epoch == _requestEpoch) {
        state = state.copyWith(
          previewError: 'Could not check the call rate. Please try again.',
          isPreviewLoading: false,
        );
      }
      return null;
    }
  }

  Future<CallPreviewResult?> refreshPreview() async {
    _invalidate();
    if (!state.destination.isValid ||
        (!state.isGatewaySelected && state.selectedCallerIdId == null)) {
      return null;
    }
    state = state.copyWith(isPreviewLoading: true);
    return _executePreview(state, _requestEpoch);
  }

  /// Recheck immediately before submission. A changed price or effective
  /// identity is shown for review and requires another explicit Call tap.
  Future<ReviewedCall?> confirmReviewedCall() async {
    if (!state.canCall) return null;
    final reviewed = state;
    final quote = await refreshPreview();
    if (quote == null ||
        !state.canCall ||
        state.revision != reviewed.revision + 1 ||
        state.formattedDestination != reviewed.formattedDestination ||
        state.selectedCallerIdId != reviewed.selectedCallerIdId ||
        state.isGatewaySelected != reviewed.isGatewaySelected) {
      return null;
    }
    final previous = reviewed.previewResult!;
    if (quote.effectiveCallerId != previous.effectiveCallerId ||
        quote.callerIdType != previous.callerIdType ||
        quote.rate?.ratePerMinute != previous.rate?.ratePerMinute ||
        quote.connectionFee != previous.connectionFee ||
        quote.billingIncrementSeconds != previous.billingIncrementSeconds) {
      state = state.copyWith(
        previewNotice:
            'Call details changed. Review the updated details and tap Call again.',
      );
      // The updated quote remains visible and eligible for explicit confirmation.
      return null;
    }
    return ReviewedCall(
      destinationNumber: reviewed.formattedDestination,
      callerIdId: reviewed.isGatewaySelected
          ? null
          : reviewed.selectedCallerIdId,
      explicitGateway: reviewed.isGatewaySelected,
      quote: quote,
    );
  }
}

final smartCallDialerProvider =
    NotifierProvider<SmartCallDialerNotifier, SmartCallDialerState>(
      SmartCallDialerNotifier.new,
    );
