/// Return Trip Wizard State and Controller
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/return_trip.dart';
import '../../domain/entities/return_trip_package.dart';
import '../../data/repositories/return_trip_repository_impl.dart';
import 'package:keep_sims/core/services/esim_capability_service.dart';
import 'active_return_trip_provider.dart';

part 'return_trip_wizard_controller.g.dart';

class ReturnTripWizardState {
  final String simLineId;
  final int currentStep; // 0: Date, 1: Connectivity Check, 2: Package, 3: Confirmation
  final DateTime? arrivalDate;
  final bool isAlreadyArrived;
  final bool isCheckingEsim;
  final bool hasEsimSupport;
  final AsyncValue<List<ReturnTripPackage>> packages;
  final ReturnTripPackage? selectedPackage;
  final bool isSubmitting;
  final ReturnTrip? confirmedTrip;
  final String? errorMessage;

  const ReturnTripWizardState({
    required this.simLineId,
    this.currentStep = 0,
    this.arrivalDate,
    this.isAlreadyArrived = false,
    this.isCheckingEsim = false,
    this.hasEsimSupport = false,
    this.packages = const AsyncLoading(),
    this.selectedPackage,
    this.isSubmitting = false,
    this.confirmedTrip,
    this.errorMessage,
  });

  ReturnTripWizardState copyWith({
    String? simLineId,
    int? currentStep,
    DateTime? arrivalDate,
    bool? isAlreadyArrived,
    bool? isCheckingEsim,
    bool? hasEsimSupport,
    AsyncValue<List<ReturnTripPackage>>? packages,
    ReturnTripPackage? selectedPackage,
    bool? isSubmitting,
    ReturnTrip? confirmedTrip,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReturnTripWizardState(
      simLineId: simLineId ?? this.simLineId,
      currentStep: currentStep ?? this.currentStep,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      isAlreadyArrived: isAlreadyArrived ?? this.isAlreadyArrived,
      isCheckingEsim: isCheckingEsim ?? this.isCheckingEsim,
      hasEsimSupport: hasEsimSupport ?? this.hasEsimSupport,
      packages: packages ?? this.packages,
      selectedPackage: selectedPackage ?? this.selectedPackage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      confirmedTrip: confirmedTrip ?? this.confirmedTrip,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

@riverpod
class ReturnTripWizardController extends _$ReturnTripWizardController {
  @override
  ReturnTripWizardState build(String simLineId) {
    // Start initial loading of packages and existing trip
    Future.microtask(() => _initialize(simLineId));

    return ReturnTripWizardState(
      simLineId: simLineId,
      arrivalDate: DateTime.now().add(const Duration(days: 7)),
    );
  }

  Future<void> _initialize(String simLineId) async {
    final repo = ref.read(returnTripRepositoryProvider);

    // 1. Fetch packages
    try {
      final pkgs = await repo.getPackagesForLine(simLineId);
      final existingTrip = await repo.getActiveTripForLine(simLineId);

      // Check hardware capability
      final isSupported = await ref.read(esimCapabilityServiceProvider.future).catchError((_) => false);

      ReturnTripPackage? preselected;
      if (existingTrip?.chosenPackageId != null) {
        preselected = pkgs.where((p) => p.id == existingTrip!.chosenPackageId).firstOrNull;
      }
      if (preselected == null) {
        if (isSupported) {
          preselected = pkgs.firstOrNull;
        } else {
          // If no eSIM hardware, preselect the top physical SIM package
          preselected = pkgs.where((p) => !p.isEsim).firstOrNull ?? pkgs.firstOrNull;
        }
      }

      state = state.copyWith(
        packages: AsyncData(pkgs),
        hasEsimSupport: isSupported,
        arrivalDate: existingTrip?.arrivalDate ?? state.arrivalDate,
        selectedPackage: preselected,
        confirmedTrip: existingTrip,
        clearError: true,
      );
    } catch (e, st) {
      state = state.copyWith(
        packages: AsyncError(e, st),
        errorMessage: 'Failed to load packages: $e',
      );
    }
  }

  Future<void> retryLoadPackages() async {
    state = state.copyWith(packages: const AsyncLoading(), clearError: true);
    await _initialize(state.simLineId);
  }

  void setArrivalDate(DateTime date, {bool alreadyArrived = false}) {
    state = state.copyWith(
      arrivalDate: date,
      isAlreadyArrived: alreadyArrived,
      clearError: true,
    );
  }

  Future<void> runConnectivityCheck() async {
    state = state.copyWith(isCheckingEsim: true, clearError: true);
    
    // Simulate smooth scanning cadence for rich UX
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final isSupported = await ref.read(esimCapabilityServiceProvider.future);
      ReturnTripPackage? currentSelected = state.selectedPackage;
      if (!isSupported && currentSelected != null && currentSelected.isEsim) {
        final pkgs = state.packages.value ?? [];
        currentSelected = pkgs.where((p) => !p.isEsim).firstOrNull;
      }
      state = state.copyWith(
        hasEsimSupport: isSupported,
        selectedPackage: currentSelected,
        isCheckingEsim: false,
      );
    } catch (_) {
      final pkgs = state.packages.value ?? [];
      state = state.copyWith(
        hasEsimSupport: false,
        selectedPackage: pkgs.where((p) => !p.isEsim).firstOrNull,
        isCheckingEsim: false,
      );
    }
  }

  void selectPackage(ReturnTripPackage pkg) {
    state = state.copyWith(
      selectedPackage: pkg,
      clearError: true,
    );
  }

  void nextStep() {
    if (state.currentStep < 3) {
      final next = state.currentStep + 1;
      state = state.copyWith(currentStep: next);
      if (next == 1) {
        runConnectivityCheck();
      }
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void goToStep(int step) {
    if (step >= 0 && step <= 3) {
      state = state.copyWith(currentStep: step);
      if (step == 1) {
        runConnectivityCheck();
      }
    }
  }

  Future<bool> confirmTrip({
    required String destinationCountryId,
  }) async {
    if (state.arrivalDate == null) {
      state = state.copyWith(errorMessage: 'Please select an arrival date');
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final repo = ref.read(returnTripRepositoryProvider);
      final trip = await repo.saveReturnTrip(
        simLineId: state.simLineId,
        destinationCountryId: destinationCountryId,
        arrivalDate: state.arrivalDate!,
        status: 'data_ready',
        chosenPackageType: state.selectedPackage?.packageType,
        chosenPackageId: state.selectedPackage?.id,
        notes: state.isAlreadyArrived ? 'Arrived prior to configuration' : null,
      );

      ref.invalidate(activeReturnTripInfoProvider(state.simLineId));

      state = state.copyWith(
        isSubmitting: false,
        confirmedTrip: trip,
        currentStep: 3, // Move to Confirmation Step
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to confirm trip: $e',
      );
      return false;
    }
  }
}
