import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import '../../data/models/support_ticket.dart';

part 'support_controller.g.dart';

@riverpod
class SupportController extends _$SupportController {
  @override
  FutureOr<List<SupportTicket>> build() async {
    final result = await ref.watch(supportRepositoryProvider).getUserTickets();
    return switch (result) {
      Success(data: final tickets) => tickets,
      Failure(error: final failure) => throw Exception(failure.message),
    };
  }

  Future<void> submitTicket({
    required String subject,
    required String description,
    required String category,
    File? attachment,
  }) async {
    final previousState = state;
    state = const AsyncLoading();

    final result = await ref
        .read(supportRepositoryProvider)
        .createTicket(
          subject: subject,
          description: description,
          category: category,
          attachment: attachment,
        );

    switch (result) {
      case Success(data: final newTicket):
        if (previousState.hasValue) {
          state = AsyncData([newTicket, ...previousState.value!]);
        } else {
          state = AsyncData([newTicket]);
        }
      case Failure(error: final failure):
        state = previousState;
        throw Exception(failure.message);
    }
  }
}
