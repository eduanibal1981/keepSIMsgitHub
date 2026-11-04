import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/calling/domain/call_destination.dart';
import 'package:keep_sims/features/voip_calling/domain/free_call_identity.dart';
import 'package:keep_sims/features/voip_calling/data/repositories/voip_calling_repository.dart';

final freeCallAccountProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider).asData?.value?.id,
);

final freeCallReviewProvider = NotifierProvider.autoDispose
    .family<FreeCallReviewController, FreeCallReviewState, FreeCallSelection>(
      FreeCallReviewController.new,
    );

class FreeCallReviewState {
  final String rawNumber;
  final String? countryIso;
  final String? knownUserId;
  final FreeCallIdentifier? identifier;
  final FreeRecipientResolution? resolution;
  final bool checking;
  final bool failed;
  final int revision;
  const FreeCallReviewState({
    this.rawNumber = '',
    this.countryIso,
    this.knownUserId,
    this.identifier,
    this.resolution,
    this.checking = false,
    this.failed = false,
    this.revision = 0,
  });
  CallDestination get destination =>
      CallDestination.resolve(rawNumber, countryIso: countryIso);
  ContactLookupResult? get recipient => resolution?.recipient;
  bool get canCall => !checking && !failed && recipient != null;
  bool get isAlias =>
      identifier != null && identifier!.type != FreeCallIdentifierType.phone;
  bool get canInvite =>
      !checking &&
      !failed &&
      destination.isValid &&
      resolution?.status == FreeRecipientStatus.notFound;
}

class FreeCallReviewController extends Notifier<FreeCallReviewState> {
  final FreeCallSelection selection;
  FreeCallReviewController(this.selection);
  int _epoch = 0;
  bool _disposed = false;
  String? _caller;

  @override
  FreeCallReviewState build() {
    _caller = ref.watch(freeCallAccountProvider);
    _epoch++;
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _epoch++;
    });
    final epoch = _epoch;
    unawaited(
      Future.microtask(() {
        if (!_disposed && epoch == _epoch) resolve();
      }),
    );
    return FreeCallReviewState(
      rawNumber: selection.identifier?.value ?? selection.rawNumber,
      identifier: selection.identifier,
      countryIso: selection.countryIso,
      knownUserId: selection.knownUserId,
    );
  }

  void setNumber(String value) {
    _epoch++;
    state = FreeCallReviewState(rawNumber: value, revision: state.revision + 1);
  }

  Future<void> confirmCountry(String iso) async {
    _epoch++;
    state = FreeCallReviewState(
      rawNumber: state.rawNumber,
      countryIso: iso,
      revision: state.revision + 1,
    );
    await resolve();
  }

  bool _current(int epoch, String caller) =>
      !_disposed &&
      epoch == _epoch &&
      _caller == caller &&
      ref.read(voipCallingRepositoryProvider).currentUserId == caller;

  Future<void> resolve() async {
    final epoch = ++_epoch;
    final snapshot = state;
    final caller = _caller;
    final phone = snapshot.destination.e164;
    if (caller == null ||
        (phone == null &&
            snapshot.knownUserId == null &&
            snapshot.identifier == null)) {
      return;
    }
    state = FreeCallReviewState(
      rawNumber: snapshot.rawNumber,
      countryIso: snapshot.countryIso,
      knownUserId: snapshot.knownUserId,
      identifier: snapshot.identifier,
      checking: true,
      revision: snapshot.revision + 1,
    );
    final revision = state.revision;
    try {
      final repository = ref.read(voipCallingRepositoryProvider);
      final result =
          await (snapshot.identifier != null
                  ? repository.resolveIdentifier(snapshot.identifier!)
                  : repository.resolveFreeCallRecipient(
                      phone: snapshot.knownUserId == null ? phone : null,
                      userId: snapshot.knownUserId,
                    ))
              .timeout(const Duration(seconds: 15));
      if (!_current(epoch, caller)) return;
      final safe = result.recipient?.userId == caller
          ? const FreeRecipientResolution(FreeRecipientStatus.self)
          : result;
      state = FreeCallReviewState(
        rawNumber: snapshot.rawNumber,
        countryIso: snapshot.countryIso,
        knownUserId: snapshot.knownUserId,
        identifier: snapshot.identifier,
        resolution: safe,
        revision: revision,
      );
    } catch (_) {
      if (!_current(epoch, caller)) return;
      state = FreeCallReviewState(
        rawNumber: snapshot.rawNumber,
        countryIso: snapshot.countryIso,
        knownUserId: snapshot.knownUserId,
        identifier: snapshot.identifier,
        failed: true,
        revision: revision,
      );
    }
  }

  /// Recheck after permissions; a changed identity needs a new explicit tap.
  Future<ContactLookupResult?> prepareCall() async {
    final reviewedId = state.recipient?.userId;
    if (!state.canCall || reviewedId == null) return null;
    await resolve();
    if (!state.canCall || state.recipient?.userId != reviewedId) return null;
    return state.recipient;
  }
}
