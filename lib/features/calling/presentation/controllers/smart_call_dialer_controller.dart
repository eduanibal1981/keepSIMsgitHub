/// KeepSIMs — Smart Call Dialer Controller
///
/// Manages dialer input state, debounced server quote preview,
/// identity selection (Cloud Gateway vs Personal Line), and quote invalidation.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';

class SmartCallDialerState {
  final String rawNumber;
  final CallRate? selectedRate;
  final CallPreviewResult? previewResult;
  final bool isPreviewLoading;
  final String? previewError;
  final bool isGatewaySelected;
  final String? selectedCallerIdId;
  final String? effectiveCallerId;

  const SmartCallDialerState({
    this.rawNumber = '',
    this.selectedRate,
    this.previewResult,
    this.isPreviewLoading = false,
    this.previewError,
    this.isGatewaySelected = true,
    this.selectedCallerIdId,
    this.effectiveCallerId,
  });

  SmartCallDialerState copyWith({
    String? rawNumber,
    CallRate? selectedRate,
    bool clearSelectedRate = false,
    CallPreviewResult? previewResult,
    bool clearPreviewResult = false,
    bool? isPreviewLoading,
    String? previewError,
    bool clearPreviewError = false,
    bool? isGatewaySelected,
    String? selectedCallerIdId,
    String? effectiveCallerId,
  }) {
    return SmartCallDialerState(
      rawNumber: rawNumber ?? this.rawNumber,
      selectedRate:
          clearSelectedRate ? null : (selectedRate ?? this.selectedRate),
      previewResult:
          clearPreviewResult ? null : (previewResult ?? this.previewResult),
      isPreviewLoading: isPreviewLoading ?? this.isPreviewLoading,
      previewError:
          clearPreviewError ? null : (previewError ?? this.previewError),
      isGatewaySelected: isGatewaySelected ?? this.isGatewaySelected,
      selectedCallerIdId: selectedCallerIdId ?? this.selectedCallerIdId,
      effectiveCallerId: effectiveCallerId ?? this.effectiveCallerId,
    );
  }

  /// Normalized dialable destination phone number in E.164
  String get formattedDestination {
    final clean = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.startsWith('+')) return clean;

    if (selectedRate != null) {
      final national = clean.startsWith('0') ? clean.substring(1) : clean;
      final prefix = selectedRate!.phonePrefix.startsWith('+')
          ? selectedRate!.phonePrefix
          : '+${selectedRate!.phonePrefix}';
      return '$prefix$national';
    }

    return clean.isNotEmpty ? '+$clean' : '';
  }

  /// Authoritative rate per minute to display
  double get effectiveRatePerMinute {
    if (previewResult?.rate != null && previewResult!.rate!.ratePerMinute > 0) {
      return previewResult!.rate!.ratePerMinute;
    }
    return selectedRate?.ratePerMinute ?? 0.0;
  }

  /// Authoritative rate per second
  double get effectiveRatePerSecond => effectiveRatePerMinute / 60.0;
}

class SmartCallDialerNotifier extends Notifier<SmartCallDialerState> {
  Timer? _debounceTimer;
  int _latestRequestId = 0;

  @override
  SmartCallDialerState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const SmartCallDialerState();
  }

  /// Set the raw input number and schedule debounced quote preview
  void setNumber(String number) {
    _debounceTimer?.cancel();
    state = state.copyWith(
      rawNumber: number,
      clearPreviewResult: true,
      clearPreviewError: true,
    );

    _detectRatePrefix(number);
    _schedulePreview();
  }

  /// Append digit from dialpad
  void appendDigit(String digit) {
    setNumber(state.rawNumber + digit);
  }

  /// Delete last character
  void deleteDigit() {
    if (state.rawNumber.isNotEmpty) {
      setNumber(state.rawNumber.substring(0, state.rawNumber.length - 1));
    }
  }

  /// Clear entire input
  void clear() {
    _debounceTimer?.cancel();
    state = state.copyWith(
      rawNumber: '',
      clearPreviewResult: true,
      clearPreviewError: true,
    );
  }

  /// Explicitly select a country rate (e.g. from picker or quick chips)
  void selectCountryRate(CallRate rate) {
    // If input is empty, prefix with country code
    if (state.rawNumber.isEmpty) {
      setNumber(rate.phonePrefix);
    } else if (!state.rawNumber.startsWith('+')) {
      // Keep existing national digits
      setNumber(rate.phonePrefix + state.rawNumber);
    }
    state = state.copyWith(selectedRate: rate);
    _schedulePreview();
  }

  /// Select identity: Cloud Gateway or verified Personal Line
  void selectIdentity({
    required bool isGateway,
    String? callerIdId,
    String? phoneNumber,
  }) {
    state = state.copyWith(
      isGatewaySelected: isGateway,
      selectedCallerIdId: callerIdId,
      effectiveCallerId: phoneNumber,
      clearPreviewResult: true, // Invalidate obsolete quote immediately
    );
    _schedulePreview();
  }

  void _detectRatePrefix(String number) {
    if (number.isEmpty) return;
    final rates = ref.read(callRatesProvider).asData?.value ?? [];
    if (rates.isEmpty) return;

    final clean = number.replaceAll('+', '');
    CallRate? matched;
    int maxLen = 0;

    for (final r in rates) {
      final prefixClean = r.phonePrefix.replaceAll('+', '');
      if (clean.startsWith(prefixClean) && prefixClean.length > maxLen) {
        matched = r;
        maxLen = prefixClean.length;
      }
    }

    if (matched != null && state.selectedRate?.id != matched.id) {
      state = state.copyWith(selectedRate: matched);
    }
  }

  void _schedulePreview() {
    _debounceTimer?.cancel();
    final dest = state.formattedDestination;
    if (dest.length < 7) {
      state = state.copyWith(
        clearPreviewResult: true,
        clearPreviewError: true,
        isPreviewLoading: false,
      );
      return;
    }

    state = state.copyWith(isPreviewLoading: true, clearPreviewError: true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executePreview(dest);
    });
  }

  Future<void> _executePreview(String dest) async {
    final requestId = ++_latestRequestId;

    try {
      final repository = ref.read(callingRepositoryProvider);
      final preview = await repository.previewCall(
        destinationNumber: dest,
        callerIdId: state.selectedCallerIdId,
        explicitGateway: state.isGatewaySelected,
      );

      // Stale response protection
      if (requestId == _latestRequestId) {
        state = state.copyWith(
          previewResult: preview,
          selectedRate: preview.rate ?? state.selectedRate,
          isPreviewLoading: false,
        );
      }
    } catch (e) {
      if (requestId == _latestRequestId) {
        state = state.copyWith(
          previewError: e.toString().replaceFirst('Exception: ', ''),
          isPreviewLoading: false,
        );
      }
    }
  }
}

final smartCallDialerProvider =
    NotifierProvider<SmartCallDialerNotifier, SmartCallDialerState>(
      SmartCallDialerNotifier.new,
    );
